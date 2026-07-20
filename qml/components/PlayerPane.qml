// Left pane, Ember layout (expanded): disc sits fully in view beside the
// title/artist/source stack — nothing bleeds off the window edge, nothing
// overlaps by accident. Seek, transport and the equalizer stack below in one
// ColumnLayout, so whatever the header needs simply pushes the equalizer
// down; nothing can ever physically overlap since sequential Layout items
// never share space.
import QtQuick
import QtQuick.Layouts
import Vespera

Item {
    id: root
    property bool compact: false

    // disc scales with the pane but stays a supporting element, not the hero —
    // the title/artist column is what the eye should land on first, and the
    // equalizer (not the disc) should own most of the vertical space
    readonly property real discSize: Math.min(root.height * 0.22, root.width * 0.22, 176)
    readonly property bool extras: !compact && root.width > 480
    // the equalizer's own content (header + slider area + two preset rows)
    // needs at least this much internal height, or its own bottom row clips —
    // measured, not guessed, since title wrapping and the extras-fallback pill
    // both change how much room the header block above it actually needs.
    readonly property real eqMinHeight: 320
    readonly property bool showEq: !compact && Eq.available
                                   && root.height > (headerBlock.implicitHeight + Theme.s5 * 2
                                                     + Theme.s3 * 2 + eqMinHeight)

    // compact — the eclipse-compact hero
    NowPlaying {
        anchors.fill: parent
        visible: root.compact
        compact: true
    }

    ColumnLayout {
        id: mainCol
        anchors.fill: parent
        anchors.margins: Theme.s5
        spacing: Theme.s3
        visible: !root.compact

        ColumnLayout {
            id: headerBlock
            Layout.fillWidth: true
            spacing: Theme.s3

            RowLayout {
                id: discRow
                Layout.fillWidth: true
                spacing: Theme.s5

                Item {
                    Layout.preferredWidth: root.discSize
                    Layout.preferredHeight: root.discSize
                    Layout.alignment: Qt.AlignVCenter

                    EclipseDisc {
                        anchors.fill: parent
                        arcCenter: 0
                        arcSpan: Math.PI * 2   // fully on-screen now — a full halo ring
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Theme.s2

                    Text {
                        Layout.fillWidth: true
                        text: Player.hasPlayer ? (Player.title !== "" ? Player.title : "Unknown title")
                                               : "Nothing playing"
                        textFormat: Text.PlainText
                        color: Style.text
                        font.family: Style.displayFamily
                        font.pixelSize: Math.max(24, Math.min(42, Math.round(root.width * 0.052)))
                        font.weight: Font.DemiBold
                        font.letterSpacing: Theme.trackTight
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.WordWrap
                        lineHeight: 1.04
                        style: Text.Raised
                        styleColor: Theme.alpha("#000000", 0.25)
                    }

                    Text {
                        Layout.fillWidth: true
                        text: Player.hasPlayer ? Player.artist : "Start a track in any player"
                        textFormat: Text.PlainText
                        color: Theme.alpha(Style.text, 0.78)
                        font.family: Style.monoFamily
                        font.pixelSize: Theme.fBody
                        font.letterSpacing: Theme.trackCaps
                        font.capitalization: Font.AllUppercase
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    // source chip — a small glass pill
                    GlassPanel {
                        Layout.topMargin: Theme.s1
                        visible: Player.hasPlayer && Player.playerName !== ""
                        implicitWidth: chipRow.width + Theme.s4 * 2
                        implicitHeight: 26
                        radius: 13
                        sheen: false
                        Row {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: Theme.s2
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 6; height: 6; radius: 3
                                color: Style.accent
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Player.playerName
                                textFormat: Text.PlainText
                                color: Theme.alpha(Style.text, 0.85)
                                font.family: Style.monoFamily
                                font.pixelSize: Theme.fCaption
                                font.letterSpacing: 1
                            }
                        }
                    }
                }
            }

            SeekBar {
                Layout.fillWidth: true
                Layout.topMargin: Theme.s2
                visible: Player.hasPlayer
                position: Player.position
                duration: Player.length
                accent: Style.accent
                accentAlt: Style.accentAlt
                trackColor: Theme.alpha("#ffffff", 0.22)
                textColor: Theme.alpha(Style.text, 0.75)
                onSeek: (s) => Player.seekTo(s)
            }

            // transport — one glass pill: prev / play / next · shuffle / volume / repeat
            GlassPanel {
                Layout.topMargin: Theme.s2
                Layout.alignment: Qt.AlignHCenter
                visible: Player.hasPlayer
                implicitWidth: pillRow.width + Theme.s6 * 2
                implicitHeight: 56
                radius: 28
                Row {
                    id: pillRow
                    anchors.centerIn: parent
                    spacing: Theme.s5

                    TransportBar {
                        anchors.verticalCenter: parent.verticalCenter
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

                    Rectangle {
                        visible: root.extras
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1; height: 28
                        color: Theme.alpha("#ffffff", 0.14)
                    }

                    PlaybackExtras {
                        visible: root.extras
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // narrow panes: the extras get their own pill, stacked below —
            // still just another row in this column, never an overlap
            GlassPanel {
                Layout.topMargin: Theme.s1
                Layout.alignment: Qt.AlignHCenter
                visible: Player.hasPlayer && !root.extras
                implicitWidth: extrasRow.width + Theme.s5 * 2
                implicitHeight: 42
                radius: 21
                sheen: false
                PlaybackExtras {
                    id: extrasRow
                    anchors.centerIn: parent
                }
            }

        }  // headerBlock

        // ---- equalizer — takes whatever's left, so it's genuinely big ----
        GlassPanel {
            Layout.topMargin: Theme.s3
            Layout.fillWidth: true
            Layout.fillHeight: true
            // real content minimum: header(~24) + slider area min(150) +
            // two preset rows(68) + internal spacing(24) + panel margins(48)
            Layout.minimumHeight: 320
            visible: root.showEq
            clip: true   // a safety net if a future skinny window still squeezes it

            Equalizer {
                anchors.fill: parent
                anchors.margins: Theme.s5
            }
        }
    }
}
