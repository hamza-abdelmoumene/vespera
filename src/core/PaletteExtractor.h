// In-process cover-art palette extraction.
//
// Given an album cover, produce a small, consistent set of theme colours:
//   accent      — the dominant vivid colour, OKLCh-normalised for legibility
//   accentAlt   — a second, hue-distinct accent for gradients/rings
//   base        — a deep, faintly album-tinted near-black window ground
//   text        — a near-white, faintly tinted foreground
//
// No ImageMagick / external tools: quantise a downscaled copy in a coarse
// histogram, then normalise in OKLCh (see OklchColor.h).
#pragma once

#include <QColor>
#include <QImage>

namespace vespera {

struct Palette {
    QColor accent;
    QColor accentAlt;
    QColor base;
    QColor text;
    bool valid = false;
};

class PaletteExtractor {
public:
    // Neutral Observatory defaults, used when there is no art or extraction
    // fails. Navy base + cyan/mauve accents — matches the flagship scene.
    static Palette defaults();

    // Extract a palette from an image. Returns defaults() if the image is null.
    static Palette extract(const QImage &image);
};

}  // namespace vespera
