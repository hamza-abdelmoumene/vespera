// A transport control button. Icons are drawn with Canvas (no emoji, no font
// or SVG assets): geometric play / pause / next / prev glyphs.
import QtQuick
import Vespera

Item {
    id: root

    property string glyph: "play"   // play | pause | next | prev
    property color iconColor: "#eaf2ff"
    property color accent: "#6fe9ff"
    property bool primary: false
    property real iconSize: primary ? 22 : 18

    signal clicked()

    implicitWidth: primary ? 52 : 40
    implicitHeight: primary ? 52 : 40

    scale: ma.containsMouse ? 1.08 : 1.0
    Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }

    Rectangle {
        visible: root.primary
        anchors.fill: parent
        radius: width / 2
        color: root.accent
    }

    Canvas {
        id: cv
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width, h = height;
            ctx.fillStyle = root.iconColor;
            if (root.glyph === "pause") {
                const bw = w * 0.28;
                ctx.fillRect(w * 0.14, 0, bw, h);
                ctx.fillRect(w - w * 0.14 - bw, 0, bw, h);
            } else if (root.glyph === "play") {
                ctx.beginPath();
                ctx.moveTo(w * 0.18, 0);
                ctx.lineTo(w * 0.18, h);
                ctx.lineTo(w * 0.9, h / 2);
                ctx.closePath();
                ctx.fill();
            } else if (root.glyph === "next") {
                ctx.beginPath();
                ctx.moveTo(w * 0.08, 0);
                ctx.lineTo(w * 0.08, h);
                ctx.lineTo(w * 0.62, h / 2);
                ctx.closePath();
                ctx.fill();
                ctx.fillRect(w * 0.68, 0, w * 0.14, h);
            } else if (root.glyph === "prev") {
                ctx.beginPath();
                ctx.moveTo(w * 0.92, 0);
                ctx.lineTo(w * 0.92, h);
                ctx.lineTo(w * 0.38, h / 2);
                ctx.closePath();
                ctx.fill();
                ctx.fillRect(w * 0.18, 0, w * 0.14, h);
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
