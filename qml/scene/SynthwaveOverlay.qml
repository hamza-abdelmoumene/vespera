// Synthwave scene overlay — a perspective grid and a banded sun on the horizon,
// with the cover reading as the sky above. Canvas-drawn; it repaints only when
// size or palette changes (no per-frame cost), with an optional gated shimmer.
import QtQuick
import Vespera

Item {
    id: scene
    property color accent: "#ff5db2"
    property color accentAlt: "#7c5cff"
    property color base: "#140a24"
    property bool animate: true
    property real intensity: 1.0

    Canvas {
        id: cv
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width, h = height;
            const horizon = h * 0.6;
            const cx = w / 2;

            // sun — vertical gradient disc with horizontal cut bands
            const sunR = Math.min(w, h) * 0.16 * scene.intensity;
            const sunY = horizon - sunR * 0.35;
            const sg = ctx.createLinearGradient(cx, sunY - sunR, cx, sunY + sunR);
            sg.addColorStop(0.0, Qt.lighter(scene.accent, 1.25));
            sg.addColorStop(1.0, scene.accentAlt);
            ctx.save();
            ctx.beginPath();
            ctx.arc(cx, sunY, sunR, 0, Math.PI * 2);
            ctx.clip();
            ctx.fillStyle = sg;
            ctx.fillRect(cx - sunR, sunY - sunR, sunR * 2, sunR * 2);
            // cut bands in the lower half
            ctx.fillStyle = scene.base;
            for (let i = 0; i < 6; i++) {
                const by = sunY + sunR * 0.15 + i * (sunR * 0.16);
                ctx.globalAlpha = 0.9;
                ctx.fillRect(cx - sunR, by, sunR * 2, sunR * (0.05 + i * 0.014));
            }
            ctx.restore();
            ctx.globalAlpha = 1.0;

            // horizon glow line
            const hg = ctx.createLinearGradient(0, horizon - 2, 0, horizon + 2);
            hg.addColorStop(0, "transparent");
            hg.addColorStop(0.5, Theme.alpha(scene.accent, 0.9));
            hg.addColorStop(1, "transparent");
            ctx.fillStyle = hg;
            ctx.fillRect(0, horizon - 2, w, 4);

            // perspective grid below the horizon
            ctx.strokeStyle = Theme.alpha(scene.accentAlt, 0.42);
            ctx.lineWidth = 1;
            const vpY = horizon;
            // converging verticals
            const cols = 12;
            for (let i = -cols; i <= cols; i++) {
                const xTop = cx + i * (w * 0.03);
                const xBot = cx + i * (w * 0.13);
                ctx.beginPath();
                ctx.moveTo(xTop, vpY);
                ctx.lineTo(xBot, h);
                ctx.stroke();
            }
            // receding horizontals — spacing grows toward the viewer
            let y = vpY;
            let step = (h - vpY) * 0.06;
            while (y < h) {
                y += step;
                step *= 1.32;
                ctx.globalAlpha = Math.min(1, (y - vpY) / (h - vpY) + 0.15);
                ctx.beginPath();
                ctx.moveTo(0, y);
                ctx.lineTo(w, y);
                ctx.stroke();
            }
            ctx.globalAlpha = 1.0;
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: scene
            function onAccentChanged() { cv.requestPaint(); }
            function onAccentAltChanged() { cv.requestPaint(); }
            function onBaseChanged() { cv.requestPaint(); }
        }
        Component.onCompleted: requestPaint()
    }
}
