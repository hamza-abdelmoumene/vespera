// Album cover with an accent glow, hairline frame, and a geometric placeholder
// when there's no art (or it hasn't loaded yet).
import QtQuick
import Vespera

Item {
    id: root

    property url source
    property color accent: "#6fe9ff"
    property color base: "#080c1a"
    readonly property bool ready: img.status === Image.Ready && String(source) !== ""

    // soft accent halo behind the art
    Rectangle {
        anchors.centerIn: parent
        width: parent.width * 1.08
        height: parent.height * 1.08
        radius: Theme.rLg
        color: Theme.alpha(root.accent, 0.16)
        opacity: root.ready ? 1 : 0.4
        Behavior on color { ColorAnimation { duration: Theme.durMed } }
    }

    Rectangle {
        id: frame
        anchors.fill: parent
        color: Qt.darker(root.base, 1.12)
        border.color: Theme.alpha("#ffffff", 0.12)
        border.width: 1
        radius: Theme.rSm
        clip: true

        Image {
            id: img
            anchors.fill: parent
            anchors.margins: 1
            source: root.source
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            visible: root.ready
            sourceSize.width: 640
            sourceSize.height: 640
        }

        // placeholder: concentric vinyl mark
        Canvas {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) * 0.42
            height: width
            visible: !root.ready
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const c = width / 2;
                ctx.strokeStyle = Theme.alpha(root.accent, 0.55);
                ctx.lineWidth = 1.5;
                ctx.beginPath(); ctx.arc(c, c, c * 0.92, 0, Math.PI * 2); ctx.stroke();
                ctx.beginPath(); ctx.arc(c, c, c * 0.55, 0, Math.PI * 2); ctx.stroke();
                ctx.fillStyle = Theme.alpha(root.accent, 0.75);
                ctx.beginPath(); ctx.arc(c, c, c * 0.12, 0, Math.PI * 2); ctx.fill();
            }
            Component.onCompleted: requestPaint()
            onVisibleChanged: if (visible) requestPaint()
        }
    }
}
