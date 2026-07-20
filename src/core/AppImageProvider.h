// App-generated textures served to QML via image://vespera/<path>.
//
//   cover/<variant>  — a synthetic, invented album cover for demo/screenshot
//                      mode. Demo mode never surfaces the user's real art (it
//                      could be explicit); this paints a clean cover matched to
//                      the demo palette so the cover-as-backdrop redesign
//                      renders in captures.
//   grain            — a tiled film-grain noise texture, layered over every
//                      theme's backdrop at a per-theme intensity.
#pragma once

#include <QImage>
#include <QLinearGradient>
#include <QPainter>
#include <QQuickImageProvider>
#include <QRadialGradient>
#include <QRandomGenerator>

#include "CoverStore.h"

namespace vespera {

class AppImageProvider : public QQuickImageProvider {
public:
    explicit AppImageProvider(CoverStore *store) : QQuickImageProvider(QQuickImageProvider::Image),
                                                   m_store(store) {}

    QImage requestImage(const QString &id, QSize *size, const QSize &requested) override {
        if (id.startsWith(QLatin1String("grain"))) return grain(size);
        if (id.startsWith(QLatin1String("blur"))) return blur(id, size);
        if (id.startsWith(QLatin1String("disc"))) {
            QImage img = m_store ? m_store->disc() : QImage();
            if (size && !img.isNull()) *size = img.size();
            return img;
        }
        return cover(id, size, requested);
    }

    // exposed so demo/screenshot mode can seed the blur store with the synthetic
    // cover matched to the demo palette.
    QImage coverImage(int variant) const {
        QSize s;
        return cover(QStringLiteral("cover/%1").arg(variant), &s, QSize(640, 640));
    }

private:
    // image://vespera/blur/<rev>/<radius> — the current cover, blurred in C++.
    QImage blur(const QString &id, QSize *size) const {
        int radius = 48;
        const int slash = id.lastIndexOf(QLatin1Char('/'));
        if (slash >= 0) radius = id.mid(slash + 1).toInt();
        QImage img = m_store ? m_store->blurred(radius > 0 ? radius : 48) : QImage();
        if (size && !img.isNull()) *size = img.size();
        return img;
    }

    // Salt-and-pepper luminance noise — black and white speckles at low alpha so,
    // layered over the backdrop, it reads as fine film grain (both crushes and
    // lifts). Intensity is controlled by the Image's opacity in QML.
    QImage grain(QSize *size) const {
        const int s = 180;
        QImage img(s, s, QImage::Format_ARGB32);
        auto *rng = QRandomGenerator::global();
        for (int y = 0; y < s; ++y) {
            auto *line = reinterpret_cast<QRgb *>(img.scanLine(y));
            for (int x = 0; x < s; ++x) {
                const double v = rng->generateDouble();
                const int a = int((v < 0.5 ? (0.5 - v) : (v - 0.5)) * 2.0 * 90.0);
                const int c = v < 0.5 ? 0 : 255;
                line[x] = qRgba(c, c, c, a);
            }
        }
        if (size) *size = img.size();
        return img;
    }

    QImage cover(const QString &id, QSize *size, const QSize &requested) const {
        const int variant = id.endsWith(QLatin1String("1")) ? 1 : 0;
        const int s = requested.width() > 0 ? qMax(requested.width(), 320) : 640;
        QImage img(s, s, QImage::Format_ARGB32_Premultiplied);

        QColor deep, mid, glowA, glowB;
        if (variant == 1) {  // Amber in the Dark — warm amber/rose
            deep = QColor(0x21, 0x0f, 0x1a);
            mid = QColor(0x7a, 0x2f, 0x3e);
            glowA = QColor(0xf6, 0xb2, 0x6b);
            glowB = QColor(0xf0, 0x7d, 0x9c);
        } else {  // Lantern Weather — cool cyan/violet dusk
            deep = QColor(0x08, 0x0c, 0x22);
            mid = QColor(0x21, 0x2b, 0x5c);
            glowA = QColor(0x6f, 0xe9, 0xff);
            glowB = QColor(0xb4, 0x90, 0xff);
        }

        QPainter p(&img);
        p.setRenderHint(QPainter::Antialiasing, true);

        QLinearGradient bg(0, 0, s, s);
        bg.setColorAt(0.0, mid);
        bg.setColorAt(1.0, deep);
        p.fillRect(img.rect(), bg);

        auto bloom = [&](qreal cx, qreal cy, qreal r, QColor c, qreal a) {
            QRadialGradient g(cx * s, cy * s, r * s);
            QColor c0 = c; c0.setAlphaF(a);
            QColor c1 = c; c1.setAlphaF(0.0);
            g.setColorAt(0.0, c0);
            g.setColorAt(1.0, c1);
            p.fillRect(img.rect(), g);
        };
        bloom(0.72, 0.24, 0.66, glowA, 0.9);
        bloom(0.24, 0.74, 0.7, glowB, 0.72);
        bloom(0.5, 0.5, 0.9, deep, 0.28);

        QRadialGradient vg(s / 2.0, s / 2.0, s * 0.75);
        vg.setColorAt(0.62, QColor(0, 0, 0, 0));
        vg.setColorAt(1.0, QColor(0, 0, 0, 120));
        p.fillRect(img.rect(), vg);
        p.end();

        if (size) *size = img.size();
        return img;
    }

    CoverStore *m_store = nullptr;
};

}  // namespace vespera
