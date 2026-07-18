// cava visualizer — 44 bars, album-tinted gradient (accentAlt → accent),
// rounded caps, 90 ms smoothing. Bars fall to the floor when paused.
import QtQuick
import Vespera

Item {
    id: root
    property var bars: Cava.bars
    property bool playing: Player.playing
    readonly property int count: Cava.barCount

    Row {
        id: row
        anchors.fill: parent
        spacing: 4
        Repeater {
            model: root.count
            delegate: Item {
                required property int index
                width: (row.width - 4 * (root.count - 1)) / root.count
                height: row.height
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    radius: Math.min(width / 2, 3)
                    height: Math.max(3, parent.height *
                            ((root.playing ? (root.bars[parent.index] || 0) : 0) / 100))
                    Behavior on height { NumberAnimation { duration: 90 } }
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Player.accentAlt }
                        GradientStop { position: 1.0; color: Theme.alpha(Player.accent, 0.55) }
                    }
                }
            }
        }
    }

    // quiet-state hint
    Column {
        anchors.centerIn: parent
        spacing: Theme.s2
        visible: !root.playing
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Player.playbackStatus === "Paused" ? "paused — press space to resume" : "nothing playing"
            color: Theme.alpha(Player.text, 0.4)
            font.pixelSize: Theme.fCaption
            font.letterSpacing: 2
        }
    }
}
