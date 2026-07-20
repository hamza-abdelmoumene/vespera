// Aurora scene overlay — soft light streaks drifting over the cover backdrop.
// The streaks are painted once (soft radial falloff, no hard edges) into an
// oversized canvas that is then drifted and breathed via compositor transforms
// — no per-frame repaint, no GPU shader, so it renders on every backend. Gated:
// when `animate` is false the whole thing is still.
import QtQuick
import Vespera

Item {
    id: root
    property color accent: "#6fe9ff"
    property color accentAlt: "#a78bfa"
    property color base: "#080c1a"  // accepted for a uniform Backdrop binding; unused
    property bool animate: true
    property real intensity: 1.0
    clip: true

    Canvas {
        id: cv
        width: parent.width * 1.35
        height: parent.height
        x: 0
        transformOrigin: Item.Center
        opacity: 0.5 * root.intensity

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width, h = height;
            function streak(cx, cy, rw, rh, col, a) {
                const g = ctx.createRadialGradient(cx, cy, 0, cx, cy, Math.max(rw, rh));
                g.addColorStop(0.0, Theme.alpha(col, a));
                g.addColorStop(0.5, Theme.alpha(col, a * 0.4));
                g.addColorStop(1.0, "transparent");
                ctx.save();
                ctx.translate(cx, cy);
                ctx.scale(rw / Math.max(rw, rh), rh / Math.max(rw, rh));
                ctx.translate(-cx, -cy);
                ctx.fillStyle = g;
                ctx.fillRect(0, 0, w, h);
                ctx.restore();
            }
            streak(w * 0.24, h * 0.30, w * 0.22, h * 0.9, root.accent, 0.55);
            streak(w * 0.52, h * 0.22, w * 0.18, h * 0.8, root.accentAlt, 0.5);
            streak(w * 0.78, h * 0.34, w * 0.24, h * 0.95, root.accent, 0.42);
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: Style
            function onChanged() { cv.requestPaint(); }
        }
        Component.onCompleted: requestPaint()

        SequentialAnimation on x {
            running: root.animate
            loops: Animation.Infinite
            NumberAnimation { to: -root.width * 0.28; duration: 14000; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0; duration: 14000; easing.type: Easing.InOutSine }
        }
        SequentialAnimation on opacity {
            running: root.animate
            loops: Animation.Infinite
            NumberAnimation { to: 0.6 * root.intensity; duration: 6000; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.34 * root.intensity; duration: 6000; easing.type: Easing.InOutSine }
        }
    }
}
