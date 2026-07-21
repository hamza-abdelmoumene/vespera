// Ambient bloom behind the album disc — light that reads as radiating OUT of the
// artwork into the surrounding glass, instead of a big blurred photo filling the
// whole window. Sampled from the track's dominant colour (Style.accent/accentAlt),
// it's sized larger than the disc and drawn unclipped so it spills past the disc
// cell into the pane. Pure atmosphere: repaints only on theme/track recolour or a
// resize, never per audio frame.
import QtQuick
import Vespera

Item {
    id: root

    // the light's colours — the album's dominant + its sibling, straight from the
    // palette so the bloom recolours with every track
    property color glow: Style.accent
    property color glowAlt: Style.accentAlt
    // overall strength (driven by the master glow knob so the owner can dial the
    // whole app's glow up/down); the fraction of the radius the disc itself covers
    // (so the gradient blooms brightest right at the rim and fades outward)
    property real intensity: Style.glowStrength
    property real discFraction: 0.385

    Canvas {
        id: canvas
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const c = width / 2;
            const r = width / 2;
            const df = root.discFraction;
            const i = root.intensity;
            // radiate from just inside the disc outward; the inner stops sit behind
            // the disc (mostly hidden), the mid stops light the rim, the outer fade
            // carries the colour softly into the glass around it
            const g = ctx.createRadialGradient(c, c, r * 0.04, c, c, r);
            g.addColorStop(0.0, Theme.alpha(root.glow, 0.42 * i));
            g.addColorStop(df * 0.72, Theme.alpha(root.glow, 0.30 * i));
            g.addColorStop(df, Theme.alpha(Theme.mix(root.glow, root.glowAlt, 0.28), 0.20 * i));
            g.addColorStop(df + (1.0 - df) * 0.34, Theme.alpha(root.glowAlt, 0.09 * i));
            g.addColorStop(df + (1.0 - df) * 0.66, Theme.alpha(root.glow, 0.025 * i));
            g.addColorStop(1.0, "transparent");
            ctx.fillStyle = g;
            ctx.fillRect(0, 0, width, height);
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections { target: Style; function onChanged() { canvas.requestPaint(); } }
        Component.onCompleted: requestPaint()
    }
}
