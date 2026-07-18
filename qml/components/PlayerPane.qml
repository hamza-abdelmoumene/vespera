// Left pane: now-playing (adaptive) + cava visualizer + equalizer.
// Compact windows collapse to the centred now-playing only.
import QtQuick
import QtQuick.Layouts
import Vespera

Item {
    id: root
    property bool compact: false
    readonly property bool extras: !compact && height > 430

    // compact — reuse the centred now-playing
    NowPlaying {
        anchors.fill: parent
        visible: root.compact
        compact: true
    }

    ColumnLayout {
        anchors.fill: parent
        visible: !root.compact
        spacing: Theme.s5

        // header: cover + metadata + seek + transport
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s5

            CoverArt {
                Layout.preferredWidth: 150
                Layout.preferredHeight: 150
                Layout.alignment: Qt.AlignTop
                source: Player.artUrl
                accent: Player.accent
                base: Player.base
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: Theme.s1

                Text {
                    Layout.fillWidth: true
                    text: Player.hasPlayer ? (Player.title !== "" ? Player.title : "Unknown title")
                                           : "Nothing playing"
                    textFormat: Text.PlainText
                    color: Player.text
                    font.pixelSize: Theme.fDisplay
                    font.weight: Font.DemiBold
                    font.letterSpacing: Theme.trackTight
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
                Text {
                    Layout.fillWidth: true
                    text: Player.hasPlayer ? Player.artist : "Start a track in any player"
                    textFormat: Text.PlainText
                    color: Theme.alpha(Player.text, 0.6)
                    font.pixelSize: Theme.fBody
                    font.letterSpacing: Theme.trackLabel
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Item { Layout.preferredHeight: Theme.s2 }

                SeekBar {
                    Layout.fillWidth: true
                    visible: Player.hasPlayer
                    position: Player.position
                    duration: Player.length
                    accent: Player.accent
                    trackColor: Theme.alpha(Player.text, 0.16)
                    textColor: Theme.alpha(Player.text, 0.7)
                    onSeek: (s) => Player.seekTo(s)
                }

                // small breath between the seek row and the transport
                Item { Layout.preferredHeight: Theme.s3 }

                TransportBar {
                    // Centre the prev / play-pause / next group under the
                    // metadata on the expanded layout (compact is already centred).
                    Layout.alignment: Qt.AlignHCenter
                    visible: Player.hasPlayer
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

        Visualizer {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 110
            visible: root.extras && Cava.available
        }

        Equalizer {
            Layout.fillWidth: true
            visible: root.extras && Eq.available
        }

        // keep the header at the top when extras are hidden
        Item { Layout.fillHeight: true; visible: !(root.extras && (Cava.available || Eq.available)) }
    }
}
