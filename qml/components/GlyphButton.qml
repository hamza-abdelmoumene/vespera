// A transport control button — a small instrument dial, not a generic pill.
// Icons are drawn with Canvas (no emoji, no font/SVG assets): rounded-geometric
// play/pause/next/prev glyphs, continuous-curve corners instead of raw points.
// The primary (play/pause) button carries a thin tick-ring like an analog
// meter — dim at rest, warm and lit while playing. Secondary buttons keep a
// resting hairline ring so they read as real controls before hover, never
// floating icons.
import QtQuick
import Vespera

Item {
    id: root

    property string glyph: "play"   // play | pause | next | prev
    property color iconColor: "#eaf2ff"
    property color accent: "#6fe9ff"
    property color accentAlt: accent
    property bool primary: false
    property bool active: false     // true while transport is playing — lights the dial
    property real iconSize: primary ? 19 : 15

    signal clicked()

    implicitWidth: primary ? 60 : 42
    implicitHeight: primary ? 60 : 42

    scale: ma.pressed ? 0.92 : ma.containsMouse ? 1.05 : 1.0
    Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }

    // ---- secondary: resting hairline ring, brightens on hover ----
    Rectangle {
        visible: !root.primary
        anchors.fill: parent
        radius: width / 2
        color: Theme.alpha(root.iconColor, ma.containsMouse ? 0.10 : 0.0)
        border.width: 1
        border.color: Theme.alpha(root.iconColor, ma.containsMouse ? 0.42 : 0.16)
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.durFast } }
    }

    // ---- primary: tick-ring dial (instrument detail, state-driven not decorative) ----
    Canvas {
        id: dial
        visible: root.primary
        anchors.fill: parent
        property real heat: ma.containsMouse ? 1.0 : 0.75
        property bool live: root.active
        Behavior on heat { NumberAnimation { duration: Theme.durMed } }
        onHeatChanged: requestPaint()
        onLiveChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const c = width / 2;
            const rOuter = c - 1.5;
            const ticks = 10;
            for (let i = 0; i < ticks; i++) {
                const a = (i / ticks) * Math.PI * 2 - Math.PI / 2;
                const inner = rOuter - (live ? 4.5 : 3);
                const x0 = c + Math.cos(a) * inner, y0 = c + Math.sin(a) * inner;
                const x1 = c + Math.cos(a) * rOuter, y1 = c + Math.sin(a) * rOuter;
                ctx.strokeStyle = Theme.alpha(root.accent, live ? 0.6 * heat : 0.2);
                ctx.lineWidth = 1.4;
                ctx.lineCap = "round";
                ctx.beginPath(); ctx.moveTo(x0, y0); ctx.lineTo(x1, y1); ctx.stroke();
            }
        }
        Connections { target: Style; function onChanged() { if (dial.visible) dial.requestPaint(); } }
        Component.onCompleted: requestPaint()
    }

    Canvas {
        id: glow
        visible: root.primary
        anchors.centerIn: parent
        width: parent.width * 1.7
        height: width
        property real heat: ma.containsMouse ? 1.0 : 0.6
        Behavior on heat { NumberAnimation { duration: Theme.durMed } }
        onHeatChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const c = width / 2;
            const g = ctx.createRadialGradient(c, c, c * 0.34, c, c, c);
            g.addColorStop(0.0, Theme.alpha(root.accent, 0.3 * heat));
            g.addColorStop(1.0, "transparent");
            ctx.fillStyle = g;
            ctx.fillRect(0, 0, width, height);
        }
        Connections { target: Style; function onChanged() { if (glow.visible) glow.requestPaint(); } }
        Component.onCompleted: requestPaint()
    }

    Rectangle {
        visible: root.primary
        anchors.centerIn: parent
        width: parent.width - 13
        height: width
        radius: width / 2
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.lighter(root.accent, 1.1) }
            GradientStop { position: 1.0; color: Theme.mix(root.accent, root.accentAlt, 0.78) }
        }
        border.width: 1.4
        border.color: Theme.alpha("#ffffff", ma.containsMouse ? 0.55 : 0.28)
        Behavior on border.color { ColorAnimation { duration: Theme.durMed } }
    }

    Canvas {
        id: cv
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize

        // rounds every vertex of a closed polygon by the same radius — the
        // "continuous curve" tip that separates a drawn glyph from a raw
        // three-point CSS-triangle look.
        function roundedPoly(ctx, pts, r) {
            const n = pts.length;
            ctx.beginPath();
            for (let i = 0; i < n; i++) {
                const p0 = pts[(i - 1 + n) % n], p1 = pts[i], p2 = pts[(i + 1) % n];
                const a1 = Math.atan2(p0.y - p1.y, p0.x - p1.x);
                const a2 = Math.atan2(p2.y - p1.y, p2.x - p1.x);
                const d1 = Math.min(r, Math.hypot(p0.x - p1.x, p0.y - p1.y) / 2);
                const d2 = Math.min(r, Math.hypot(p2.x - p1.x, p2.y - p1.y) / 2);
                const x1 = p1.x + Math.cos(a1) * d1, y1 = p1.y + Math.sin(a1) * d1;
                const x2 = p1.x + Math.cos(a2) * d2, y2 = p1.y + Math.sin(a2) * d2;
                if (i === 0) ctx.moveTo(x1, y1); else ctx.lineTo(x1, y1);
                ctx.arcTo(p1.x, p1.y, x2, y2, r);
            }
            ctx.closePath();
        }
        function roundRect(ctx, x, y, w, h, r) {
            ctx.beginPath();
            ctx.moveTo(x + r, y);
            ctx.arcTo(x + w, y, x + w, y + h, r);
            ctx.arcTo(x + w, y + h, x, y + h, r);
            ctx.arcTo(x, y + h, x, y, r);
            ctx.arcTo(x, y, x + w, y, r);
            ctx.closePath();
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width, h = height;
            ctx.fillStyle = root.iconColor;
            if (root.glyph === "pause") {
                const bw = w * 0.26, r = bw * 0.32;
                cv.roundRect(ctx, w * 0.12, 0, bw, h, r); ctx.fill();
                cv.roundRect(ctx, w - w * 0.12 - bw, 0, bw, h, r); ctx.fill();
            } else if (root.glyph === "play") {
                cv.roundedPoly(ctx, [
                    { x: w * 0.2, y: h * 0.05 },
                    { x: w * 0.2, y: h * 0.95 },
                    { x: w * 0.9, y: h * 0.5 }
                ], w * 0.09);
                ctx.fill();
            } else if (root.glyph === "next") {
                cv.roundedPoly(ctx, [
                    { x: w * 0.06, y: h * 0.08 },
                    { x: w * 0.06, y: h * 0.92 },
                    { x: w * 0.58, y: h * 0.5 }
                ], w * 0.07);
                ctx.fill();
                cv.roundRect(ctx, w * 0.7, 0, w * 0.15, h, w * 0.05); ctx.fill();
            } else if (root.glyph === "prev") {
                cv.roundedPoly(ctx, [
                    { x: w * 0.94, y: h * 0.08 },
                    { x: w * 0.94, y: h * 0.92 },
                    { x: w * 0.42, y: h * 0.5 }
                ], w * 0.07);
                ctx.fill();
                cv.roundRect(ctx, w * 0.15, 0, w * 0.15, h, w * 0.05); ctx.fill();
            }
        }
    }

    onGlyphChanged: cv.requestPaint()
    onIconColorChanged: cv.requestPaint()

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
