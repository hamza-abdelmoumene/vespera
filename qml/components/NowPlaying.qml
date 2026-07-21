// Compact hero: disc, title/artist, seek and the glass transport pill, all
// as ONE block that centres itself in whatever room is available — so it
// stays balanced at any window size instead of anchoring from a fixed edge.
import QtQuick
import QtQuick.Layouts
import Vespera

Item {
    id: root
    property bool compact: true
    readonly property bool has: Player.hasPlayer

    ColumnLayout {
        id: block
        anchors.centerIn: parent
        width: Math.min(root.width - Theme.s5 * 2, 360)
        spacing: Theme.s4

        Item {
            id: discWrap
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: discSize
            Layout.preferredHeight: discSize
            readonly property real discSize: Math.max(96, Math.min(block.width * 0.86, root.height * 0.44, 260))

            // ambient bloom radiating from the art (see PlayerPane) — unclipped so
            // it spills softly around the disc into the compact hero's space
            DiscGlow {
                anchors.centerIn: parent
                width: discWrap.discSize * 2.3
                height: width
                z: -1
            }

            EclipseDisc {
                anchors.fill: parent
                arcCenter: 0
                arcSpan: Math.PI * 2   // full halo ring — the disc reads whole, matching the expanded pane
            }
        }

        Column {
            Layout.fillWidth: true
            spacing: Theme.s1
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.has ? (Player.title !== "" ? Player.title : "Unknown title")
                               : "Nothing playing"
                textFormat: Text.PlainText
                color: Style.text
                font.family: Style.displayFamily
                font.pixelSize: Theme.fDisplay
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                maximumLineCount: 1
                style: Text.Raised
                styleColor: Theme.alpha("#000000", 0.25)
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.has ? Player.artist : "Start a track in any player"
                textFormat: Text.PlainText
                color: Theme.alpha(Style.text, 0.78)
                font.family: Style.monoFamily
                font.pixelSize: Theme.fCaption
                font.letterSpacing: Theme.trackCaps
                font.capitalization: Font.AllUppercase
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        SeekBar {
            Layout.fillWidth: true
            visible: root.has
            position: Player.position
            duration: Player.length
            accent: Style.accent
            accentAlt: Style.accentAlt
            trackColor: Theme.alpha("#ffffff", 0.22)
            textColor: Theme.alpha(Style.text, 0.75)
            onSeek: (s) => Player.seekTo(s)
        }

        GlassPanel {
            Layout.alignment: Qt.AlignHCenter
            visible: root.has
            implicitWidth: pillRow.width + Theme.s5 * 2
            implicitHeight: 56
            radius: 28
            TransportBar {
                id: pillRow
                anchors.centerIn: parent
                spacing: Theme.s5
                playing: Player.playing
                accent: Style.accent
                accentAlt: Style.accentAlt
                iconColor: Style.text
                accentInk: Style.base
                canPrev: Player.canGoPrevious
                canNext: Player.canGoNext
                onPrev: Player.previous()
                onPlayPause: Player.playPause()
                onNext: Player.next()
            }
        }
    }
}
