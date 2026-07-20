// Backend-agnostic cover blur + grade for the backdrop.
//
// The redesign paints the album cover as a heavily-blurred backdrop. Doing that
// with a GPU shader (QtQuick.Effects MultiEffect) fails on software renderers
// and in offscreen capture, and would break the distro-agnostic promise. So the
// blur is produced here in plain C++ — a smooth downscale (which is itself an
// averaging blur; upscaled by the Image with bilinear filtering it reads as a
// soft, abstract field) — and served through the app image provider. Cached per
// blur level, recomputed only when the track's art or the grade changes.
//
// The grade (saturation boost · brightness · luminance floor) is applied here
// rather than in QML because Image has no colour controls, and because the
// luminance floor needs the image statistics: a near-black album gives the
// glass panels nothing to refract, so when the graded cover's mean luminance
// falls below the floor it is gain-lifted toward it — still moody, never dead.
#pragma once

#include <QHash>
#include <QImage>
#include <QMutex>
#include <QObject>
#include <QString>

namespace vespera {

class CoverStore : public QObject {
    Q_OBJECT
    // QML binds the backdrop source to blurBase + "/" + <radius>; the rev in the
    // path busts the Image cache whenever the track's art or grade changes.
    Q_PROPERTY(QString blurBase READ blurBase NOTIFY revChanged)
    Q_PROPERTY(QString discBase READ discBase NOTIFY revChanged)

public:
    explicit CoverStore(QObject *parent = nullptr) : QObject(parent) {}

    QString blurBase() const { return QStringLiteral("image://vespera/blur/%1").arg(m_rev); }
    QString discBase() const { return QStringLiteral("image://vespera/disc/%1").arg(m_rev); }

    // Set the current cover (any size, from MPRIS art or the demo painter).
    // A null image clears the backdrop to the flat base.
    void setSource(const QImage &raw);

    // Backdrop grade, fed from the theme engine (blended values during theme
    // switches). No-ops when nothing changed beyond rounding, so the palette
    // tick stream doesn't cause rebuilds.
    void setGrade(double saturation, double brightness, double lumFloor);

    // A blurred copy for the given logical blur radius. Thread-safe (called from
    // the render thread by the image provider).
    QImage blurred(int radius);

    // The cover cropped to an antialiased circle, for the disc medallion.
    // Uses the ungraded art — the record shows the true cover.
    QImage disc();

signals:
    void revChanged();

private:
    void regrade();               // m_raw -> m_src with the grade applied (lock held)

    mutable QMutex m_mtx;
    QImage m_raw;                 // smoothed, downscaled source (<=256px), ungraded
    QImage m_src;                 // graded source the blur levels derive from
    QHash<int, QImage> m_cache;   // small-size -> blurred square
    QImage m_disc;                // cover cropped to a circle (ungraded)
    double m_sat = 1.0;
    double m_bright = 1.0;
    double m_floor = 0.0;
    int m_rev = 0;
};

}  // namespace vespera
