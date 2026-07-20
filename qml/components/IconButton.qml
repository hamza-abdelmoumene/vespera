// Small geometric icon button for the lyrics controls (offset −/+, resync).
// Icons are Canvas-drawn — no nerd-font dependency.
import QtQuick
import Vespera

Item {
    id: root
    property string kind: "resync"   // minus | plus | resync
    property bool spinning: false
    property color color: Style.text
    signal tapped()

    implicitWidth: 28
    implicitHeight: 28
    opacity: enabled ? 1.0 : 0.35

    scale: ma.pressed ? 0.88 : 1.0
    Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        radius: Theme.rSm
        color: ma.containsMouse && root.enabled ? Theme.alpha(Style.text, 0.10) : "transparent"
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    Canvas {
        id: cv
        anchors.centerIn: parent
        width: 15
        height: 15
        property real spin: 0
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width, h = height, cx = w / 2, cy = h / 2;
            ctx.strokeStyle = root.color;
            ctx.fillStyle = root.color;
            ctx.lineWidth = 1.6;
            ctx.lineCap = "round";
            if (root.kind === "minus") {
                ctx.beginPath(); ctx.moveTo(2, cy); ctx.lineTo(w - 2, cy); ctx.stroke();
            } else if (root.kind === "plus") {
                ctx.beginPath();
                ctx.moveTo(2, cy); ctx.lineTo(w - 2, cy);
                ctx.moveTo(cx, 2); ctx.lineTo(cx, h - 2);
                ctx.stroke();
            } else { // resync — circular arrow
                ctx.save();
                ctx.translate(cx, cy);
                ctx.rotate(root.spin * Math.PI / 180);
                const r = w * 0.38;
                ctx.beginPath();
                ctx.arc(0, 0, r, -Math.PI * 0.5, Math.PI * 0.95);
                ctx.stroke();
                // arrowhead at the arc end
                const a = Math.PI * 0.95;
                const ex = r * Math.cos(a), ey = r * Math.sin(a);
                ctx.beginPath();
                ctx.moveTo(ex, ey);
                ctx.lineTo(ex - 3.5, ey - 1.0);
                ctx.lineTo(ex - 1.0, ey + 3.2);
                ctx.closePath();
                ctx.fill();
                ctx.restore();
            }
        }
        RotationAnimation on spin {
            from: 0; to: 360; duration: 1000
            loops: Animation.Infinite
            running: root.spinning
        }
        onSpinChanged: if (root.kind === "resync") requestPaint()
    }

    onKindChanged: cv.requestPaint()
    onColorChanged: cv.requestPaint()

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.tapped()
    }
}
