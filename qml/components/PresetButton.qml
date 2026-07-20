// EQ preset chip. Highlights when it is the active preset.
import QtQuick
import QtQuick.Layouts
import Vespera

Rectangle {
    id: root
    property string name
    readonly property bool active: Eq.preset === name
    signal picked()

    Layout.fillWidth: true
    Layout.preferredHeight: 30
    radius: Theme.rSm
    color: active ? Theme.alpha(Style.accent, 0.18)
                  : ma.containsMouse ? Theme.alpha(Style.text, 0.09)
                                     : Theme.alpha(Style.text, 0.04)
    border.width: 1
    border.color: active ? Theme.alpha(Style.accent, 0.55) : Theme.alpha(Style.text, 0.10)
    Behavior on color { ColorAnimation { duration: 160 } }
    Behavior on border.color { ColorAnimation { duration: 160 } }

    scale: ma.pressed ? 0.95 : 1.0
    Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }

    Text {
        anchors.centerIn: parent
        text: root.name
        color: root.active ? Style.accent : Theme.alpha(Style.text, ma.containsMouse ? 0.9 : 0.65)
        font.pixelSize: Theme.fLabel
        font.weight: root.active ? Font.DemiBold : Font.Normal
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.picked()
    }
}
