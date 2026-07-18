#include "PaletteExtractor.h"

#include <QHash>
#include <algorithm>
#include <array>
#include <cmath>
#include <vector>

#include "OklchColor.h"

namespace vespera {

namespace {

struct Bucket {
    quint64 count = 0;
    double r = 0, g = 0, b = 0;  // running sums (0..255)
    QColor mean() const {
        if (count == 0) return QColor();
        return QColor::fromRgb(int(r / count), int(g / count), int(b / count));
    }
};

// 5 bits per channel -> 32^3 possible keys; sparse map keeps it cheap.
inline quint32 keyOf(int r, int g, int b) {
    return (quint32(r >> 3) << 10) | (quint32(g >> 3) << 5) | quint32(b >> 3);
}

}  // namespace

Palette PaletteExtractor::defaults() {
    Palette p;
    p.accent = QColor(0x6f, 0xe9, 0xff);     // cyan
    p.accentAlt = QColor(0xa7, 0x8b, 0xfa);  // mauve
    p.base = QColor(0x08, 0x0c, 0x1a);       // deep navy
    p.text = QColor(0xea, 0xf2, 0xff);       // near-white, cool
    p.valid = false;
    return p;
}

Palette PaletteExtractor::extract(const QImage &image) {
    if (image.isNull()) return defaults();

    const QImage img = image
                           .scaled(48, 48, Qt::IgnoreAspectRatio, Qt::SmoothTransformation)
                           .convertToFormat(QImage::Format_ARGB32);

    QHash<quint32, Bucket> hist;
    hist.reserve(512);
    quint64 total = 0;

    for (int y = 0; y < img.height(); ++y) {
        const QRgb *line = reinterpret_cast<const QRgb *>(img.constScanLine(y));
        for (int x = 0; x < img.width(); ++x) {
            const QRgb px = line[x];
            if (qAlpha(px) < 128) continue;
            const int r = qRed(px), g = qGreen(px), b = qBlue(px);
            Bucket &bk = hist[keyOf(r, g, b)];
            bk.count++;
            bk.r += r;
            bk.g += g;
            bk.b += b;
            total++;
        }
    }

    if (total == 0) return defaults();

    // Score every bucket for accent-worthiness: weight by frequency and by
    // OKLCh chroma, and favour a mid lightness (avoid muddy darks / blown
    // highlights). Keep the plain most-frequent bucket for the base tint.
    struct Cand {
        QColor color;
        oklch::Lch lch;
        double score;
        quint64 count;
    };
    std::vector<Cand> cands;
    cands.reserve(hist.size());

    Cand dominant{QColor(), {}, -1.0, 0};

    for (auto it = hist.constBegin(); it != hist.constEnd(); ++it) {
        const Bucket &bk = it.value();
        const QColor c = bk.mean();
        if (!c.isValid()) continue;
        const oklch::Lch lch = oklch::fromColor(c);
        const double freq = double(bk.count) / double(total);

        if (bk.count > dominant.count) dominant = {c, lch, 0, bk.count};

        // lightness preference peaks around L=0.62
        const double lightPref = std::exp(-std::pow((lch.L - 0.62) / 0.30, 2.0));
        const double score = freq * (0.05 + lch.C) * (0.35 + lightPref);
        cands.push_back({c, lch, score, bk.count});
    }

    if (cands.empty()) return defaults();

    std::sort(cands.begin(), cands.end(),
              [](const Cand &a, const Cand &b) { return a.score > b.score; });

    Palette p;
    p.valid = true;

    const QColor rawAccent = cands.front().color;
    // Pull the accent into a legible, vivid-but-not-neon window.
    p.accent = oklch::normalise(rawAccent, 0.62, 0.80, 0.10, 0.17);

    // Secondary accent: the best-scoring candidate whose hue differs enough.
    const double accentHue = oklch::fromColor(p.accent).h;
    QColor rawAlt = rawAccent;
    for (const Cand &c : cands) {
        if (oklch::hueDistance(c.lch.h, accentHue) > (40.0 * M_PI / 180.0)) {
            rawAlt = c.color;
            break;
        }
    }
    p.accentAlt = oklch::normalise(rawAlt, 0.58, 0.78, 0.09, 0.16);

    // Base: deep, faintly tinted near-black taking the dominant hue.
    p.base = oklch::withHueOf(dominant.color.isValid() ? dominant.color : rawAccent,
                              0.14, std::min(oklch::fromColor(dominant.color).C, 0.045));

    // Text: near-white, faintly tinted with the accent hue.
    p.text = oklch::withHueOf(p.accent, 0.95, 0.020);

    return p;
}

}  // namespace vespera
