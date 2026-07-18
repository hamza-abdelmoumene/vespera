// M1 layout: a centred now-playing column (cover · title/artist · seek ·
// transport) over the scene. Responsive reflow and the lyrics/EQ columns
// arrive in M2/M3.
import QtQuick
import Vespera

Item {
    id: root
    property bool compact: false
    readonly property bool has: Player.hasPlayer
    readonly property real coverSize: Math.max(120, Math.min(root.width * 0.55,
                                               root.height * 0.5, root.compact ? 200 : 300))

    Column {
        id: col
        anchors.centerIn: parent
        width: Math.min(parent.width - Theme.s6 * 2, root.compact ? 300 : 440)
        spacing: root.compact ? Theme.s4 : Theme.s5

        CoverArt {
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.coverSize
            height: root.coverSize
            source: Player.artUrl
            accent: Player.accent
            base: Player.base
        }

        Column {
            width: parent.width
            spacing: Theme.s1
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.has ? (Player.title !== "" ? Player.title : "Unknown title")
                               : "Nothing playing"
                textFormat: Text.PlainText
                color: Player.text
                font.pixelSize: root.compact ? Theme.fTitle : Theme.fDisplay
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                maximumLineCount: 1
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.has ? Player.artist : "Start a track in any player"
                textFormat: Text.PlainText
                color: Theme.alpha(Player.text, 0.6)
                font.pixelSize: root.compact ? Theme.fLabel : Theme.fBody
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        SeekBar {
            width: parent.width
            visible: root.has
            position: Player.position
            duration: Player.length
            accent: Player.accent
            trackColor: Theme.alpha(Player.text, 0.16)
            textColor: Theme.alpha(Player.text, 0.7)
            onSeek: (s) => Player.seekTo(s)
        }

        TransportBar {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.has
            playing: Player.playing
            accent: Player.accent
            iconColor: Player.text
            accentInk: Player.base
            canPrev: Player.canGoPrevious
            canNext: Player.canGoNext
            onPrev: Player.previous()
            onPlayPause: Player.playPause()
            onNext: Player.next()
        }
    }
}
