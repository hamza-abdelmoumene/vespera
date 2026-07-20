// Progress bar with click / drag-to-seek and tabular time labels. The fill is
// an accent→accentAlt light gradient with a softly glowing playhead — the same
// light language as the disc's rim arc.
import QtQuick
import Vespera

Item {
    id: root

    property real position: 0      // seconds
    property real duration: 0      // seconds
    property color accent: "#6fe9ff"
    property color accentAlt: "#b490ff"
    property color trackColor: Qt.rgba(1, 1, 1, 0.16)
    property color textColor: "#b9c6dd"

    signal seek(real seconds)

    implicitHeight: 40

    property bool dragging: false
    property real dragFrac: 0
    readonly property real frac: duration > 0 ? Math.max(0, Math.min(1, position / duration)) : 0
    readonly property real shownFrac: dragging ? dragFrac : frac

    function fmt(s) {
        if (!(s > 0)) return "0:00";
        const m = Math.floor(s / 60);
        const ss = Math.floor(s % 60);
        return m + ":" + (ss < 10 ? "0" : "") + ss;
    }

    Rectangle {
        id: bar
        anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 7 }
        height: 5
        radius: 3
        color: root.trackColor

        Rectangle {
            id: fill
            height: parent.height
            radius: 3
            width: parent.width * root.shownFrac
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: root.accent }
                GradientStop { position: 1.0; color: root.accentAlt }
            }
        }
        // playhead — layered discs approximate a soft glow without an effect pass
        Item {
            width: 22; height: 22
            y: (parent.height - height) / 2
            x: Math.max(-5, Math.min(parent.width - width + 5,
                                     parent.width * root.shownFrac - width / 2))
            opacity: root.duration > 0 ? 1 : 0
            scale: seekMa.containsMouse || root.dragging ? 1.18 : 1.0
            Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
            Rectangle { anchors.centerIn: parent; width: 22; height: 22; radius: 11
                        color: Theme.alpha(root.accent, 0.16) }
            Rectangle { anchors.centerIn: parent; width: 16; height: 16; radius: 8
                        color: Theme.alpha(root.accent, 0.28) }
            Rectangle { anchors.centerIn: parent; width: 11; height: 11; radius: 5.5
                        color: "#ffffff" }
        }
    }

    MouseArea {
        id: seekMa
        anchors.left: bar.left
        anchors.right: bar.right
        anchors.verticalCenter: bar.verticalCenter
        height: 22
        enabled: root.duration > 0
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: (m) => { root.dragging = true; root.dragFrac = Math.max(0, Math.min(1, m.x / width)); }
        onPositionChanged: (m) => { if (root.dragging) root.dragFrac = Math.max(0, Math.min(1, m.x / width)); }
        onReleased: (m) => {
            const f = Math.max(0, Math.min(1, m.x / width));
            root.dragging = false;
            if (root.duration > 0) root.seek(f * root.duration);
        }
    }

    Text {
        anchors { left: parent.left; top: bar.bottom; topMargin: 8 }
        text: root.fmt(root.dragging ? root.dragFrac * root.duration : root.position)
        color: root.textColor
        font.pixelSize: Theme.fCaption
        font.family: Style.monoFamily
    }
    Text {
        anchors { right: parent.right; top: bar.bottom; topMargin: 8 }
        text: root.fmt(root.duration)
        color: root.textColor
        font.pixelSize: Theme.fCaption
        font.family: Style.monoFamily
    }
}
