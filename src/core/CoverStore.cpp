#include "CoverStore.h"

#include <QMutexLocker>
#include <QPainter>
#include <QPainterPath>
#include <algorithm>
#include <cmath>

namespace vespera {

void CoverStore::setSource(const QImage &raw) {
    QMutexLocker lock(&m_mtx);
    m_cache.clear();
    m_disc = QImage();
    if (raw.isNull()) {
        m_raw = QImage();
        m_src = QImage();
    } else {
        // one moderate downscale up front; per-radius levels come from this
        m_raw = raw.convertToFormat(QImage::Format_ARGB32)
                    .scaled(256, 256, Qt::IgnoreAspectRatio, Qt::SmoothTransformation);
        regrade();
    }
    ++m_rev;
    lock.unlock();
    emit revChanged();
}

void CoverStore::setGrade(double saturation, double brightness, double lumFloor) {
    // quantise so the theme-switch blend produces a handful of steps, and the
    // per-track palette ticks (which don't move these values) produce none
    saturation = std::round(saturation * 50.0) / 50.0;
    brightness = std::round(brightness * 50.0) / 50.0;
    lumFloor = std::round(lumFloor * 50.0) / 50.0;
    QMutexLocker lock(&m_mtx);
    if (std::fabs(saturation - m_sat) < 1e-6 && std::fabs(brightness - m_bright) < 1e-6 &&
        std::fabs(lumFloor - m_floor) < 1e-6)
        return;
    m_sat = saturation;
    m_bright = brightness;
    m_floor = lumFloor;
    if (m_raw.isNull()) return;
    m_cache.clear();
    regrade();
    ++m_rev;
    lock.unlock();
    emit revChanged();
}

void CoverStore::regrade() {
    QImage img = m_raw;  // detach copy
    if (img.isNull()) { m_src = QImage(); return; }
    img.detach();
    const double sat = m_sat, bright = m_bright;
    double meanL = 0.0;
    const int w = img.width(), h = img.height();
    for (int y = 0; y < h; ++y) {
        auto *line = reinterpret_cast<QRgb *>(img.scanLine(y));
        for (int x = 0; x < w; ++x) {
            const QRgb px = line[x];
            double r = qRed(px), g = qGreen(px), b = qBlue(px);
            const double l = 0.2126 * r + 0.7152 * g + 0.0722 * b;
            r = std::clamp((l + (r - l) * sat) * bright, 0.0, 255.0);
            g = std::clamp((l + (g - l) * sat) * bright, 0.0, 255.0);
            b = std::clamp((l + (b - l) * sat) * bright, 0.0, 255.0);
            meanL += 0.2126 * r + 0.7152 * g + 0.0722 * b;
            line[x] = qRgba(int(r), int(g), int(b), qAlpha(px));
        }
    }
    meanL /= (double(w) * h * 255.0);
    // luminance floor: a near-black cover is gain-lifted so the glass has
    // something to refract. Soft-clipped so lifted highlights roll off.
    if (m_floor > 0.01 && meanL < m_floor && meanL > 1e-4) {
        const double gain = std::min(3.4, m_floor / std::max(0.02, meanL));
        for (int y = 0; y < h; ++y) {
            auto *line = reinterpret_cast<QRgb *>(img.scanLine(y));
            for (int x = 0; x < w; ++x) {
                const QRgb px = line[x];
                auto lift = [gain](int c) {
                    double v = c * gain;  // identity below the shoulder, soft roll-off above
                    if (v > 200.0) v = 200.0 + 55.0 * (1.0 - std::exp(-(v - 200.0) / 80.0));
                    return int(std::clamp(v, 0.0, 255.0));
                };
                line[x] = qRgba(lift(qRed(px)), lift(qGreen(px)), lift(qBlue(px)), qAlpha(px));
            }
        }
    }
    m_src = img;
}

QImage CoverStore::blurred(int radius) {
    QMutexLocker lock(&m_mtx);
    if (m_src.isNull()) return {};
    // heavier radius -> smaller intermediate -> softer when the Image upscales it.
    // Floor raised well above the old 10px: a window in the 1200-1600px range was
    // stretching a ~15-25px tile that far, which reads as blocky/muddy rather than
    // a soft blur once you're past maybe 15x scale. This keeps the same "downscale
    // is the blur" trick but caps the upscale ratio to something that stays smooth.
    // lower floor (was 26) lets a heavy backdrop radius produce a very small
    // source that upscales into a silky, banding-free blur — the smooth cover field
    const int n = std::clamp(int(std::lround(2600.0 / std::max(8, radius))), 14, 220);
    auto it = m_cache.constFind(n);
    if (it != m_cache.constEnd()) return it.value();
    QImage small = m_src.scaled(n, n, Qt::IgnoreAspectRatio, Qt::SmoothTransformation);
    m_cache.insert(n, small);
    return small;
}

QImage CoverStore::disc() {
    QMutexLocker lock(&m_mtx);
    if (m_raw.isNull()) return {};
    if (!m_disc.isNull()) return m_disc;
    const int s = m_raw.width();
    QImage out(s, s, QImage::Format_ARGB32_Premultiplied);
    out.fill(Qt::transparent);
    QPainter p(&out);
    p.setRenderHint(QPainter::Antialiasing, true);
    QPainterPath circle;
    circle.addEllipse(0.5, 0.5, s - 1.0, s - 1.0);
    p.setClipPath(circle);
    p.drawImage(0, 0, m_raw);
    p.end();
    m_disc = out;
    return m_disc;
}

}  // namespace vespera
