// OKLab / OKLCh colour utilities — header-only, no external dependencies.
//
// Based on Björn Ottosson's public-domain OKLab reference
// (https://bottosson.github.io/posts/oklab/). Used to normalise cover-art
// accent colours to a consistent perceptual lightness/chroma window so the
// UI reads the same across wildly different album covers.
#pragma once

#include <QColor>
#include <algorithm>
#include <cmath>

namespace vespera::oklch {

struct Lch {
    double L = 0.0;  // perceptual lightness, ~0..1
    double C = 0.0;  // chroma, ~0..0.37
    double h = 0.0;  // hue, radians
};

inline double srgbToLinear(double c) {
    return (c <= 0.04045) ? c / 12.92 : std::pow((c + 0.055) / 1.055, 2.4);
}

inline double linearToSrgb(double c) {
    c = std::clamp(c, 0.0, 1.0);
    return (c <= 0.0031308) ? 12.92 * c : 1.055 * std::pow(c, 1.0 / 2.4) - 0.055;
}

// QColor (sRGB) -> OKLCh
inline Lch fromColor(const QColor &col) {
    const double r = srgbToLinear(col.redF());
    const double g = srgbToLinear(col.greenF());
    const double b = srgbToLinear(col.blueF());

    const double l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b;
    const double m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b;
    const double s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b;

    const double l_ = std::cbrt(l);
    const double m_ = std::cbrt(m);
    const double s_ = std::cbrt(s);

    const double L = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_;
    const double a = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_;
    const double bb = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_;

    Lch out;
    out.L = L;
    out.C = std::hypot(a, bb);
    out.h = std::atan2(bb, a);
    return out;
}

// OKLCh -> QColor (sRGB, gamut-clamped)
inline QColor toColor(const Lch &c, double alpha = 1.0) {
    const double a = c.C * std::cos(c.h);
    const double bb = c.C * std::sin(c.h);
    const double L = c.L;

    const double l_ = L + 0.3963377774 * a + 0.2158037573 * bb;
    const double m_ = L - 0.1055613458 * a - 0.0638541728 * bb;
    const double s_ = L - 0.0894841775 * a - 1.2914855480 * bb;

    const double l = l_ * l_ * l_;
    const double m = m_ * m_ * m_;
    const double s = s_ * s_ * s_;

    const double r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s;
    const double g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s;
    const double b = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s;

    QColor out;
    out.setRgbF(std::clamp(linearToSrgb(r), 0.0, 1.0),
                std::clamp(linearToSrgb(g), 0.0, 1.0),
                std::clamp(linearToSrgb(b), 0.0, 1.0),
                std::clamp(alpha, 0.0, 1.0));
    return out;
}

// Return a copy with lightness/chroma clamped into [loL,hiL] / [loC,hiC],
// preserving hue. This is how accents from very dark or very washed-out
// covers are pulled back to a legible, vivid-but-not-neon range.
inline QColor normalise(const QColor &col, double loL, double hiL, double loC, double hiC) {
    Lch c = fromColor(col);
    c.L = std::clamp(c.L, loL, hiL);
    c.C = std::clamp(c.C, loC, hiC);
    return toColor(c);
}

// Build a colour directly from L, C (chroma) and the hue of a reference colour.
inline QColor withHueOf(const QColor &ref, double L, double C) {
    Lch c = fromColor(ref);
    c.L = L;
    c.C = C;
    return toColor(c);
}

// Shortest angular distance between two hues (radians).
inline double hueDistance(double h1, double h2) {
    double d = std::fmod(std::fabs(h1 - h2), 2.0 * M_PI);
    return d > M_PI ? 2.0 * M_PI - d : d;
}

}  // namespace vespera::oklch
