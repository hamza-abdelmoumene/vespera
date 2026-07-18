// Synced lyrics — centred current line, click-to-seek, ±0.25s per-track offset,
// resync. Highlight is interpolated between position polls for smoothness.
import QtQuick
import Vespera

Rectangle {
    id: root

    radius: Theme.rMd
    color: Theme.alpha(Player.base, 0.35)
    border.width: 1
    border.color: Theme.alpha("#ffffff", 0.08)

    // glass sheen — a hairline of light along the top edge
    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top }
        anchors.leftMargin: parent.radius
        anchors.rightMargin: parent.radius
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: Theme.alpha("#ffffff", 0.14) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // interpolated playback position (poll cadence is coarse; advance locally)
    property real estPos: Player.position
    property double _t0: Date.now()
    Connections {
        target: Player
        function onPositionChanged() { root.estPos = Player.position; root._t0 = Date.now(); }
    }
    Timer {
        interval: 120
        running: Player.playing && root.visible && Lyrics.hasLyrics
        repeat: true
        onTriggered: root.estPos = Player.position + (Date.now() - root._t0) / 1000
    }

    Column {
        anchors.fill: parent
        anchors.margins: Theme.s4
        spacing: Theme.s3

        // header
        Item {
            width: parent.width
            height: 26
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.s2
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 7; height: 7; radius: 2; rotation: 45
                    color: Player.accentAlt
                }
                Text {
                    text: "Lyrics"
                    color: Player.accentAlt
                    font.pixelSize: Theme.fTitle
                    font.weight: Font.DemiBold
                    font.letterSpacing: Theme.trackLabel
                }
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.s1
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    readonly property bool hasOffset: Math.abs(Lyrics.offset) > 0.01
                    text: Lyrics.loading ? "syncing…"
                        : hasOffset ? ((Lyrics.offset > 0 ? "+" : "") + Lyrics.offset.toFixed(2) + "s")
                        : (Lyrics.hasLyrics ? "synced" : "")
                    color: hasOffset && !Lyrics.loading ? "#e8c07d" : Theme.alpha(Player.text, 0.45)
                    font.pixelSize: Theme.fCaption
                    font.letterSpacing: 1
                    rightPadding: Theme.s2
                    MouseArea {
                        anchors.fill: parent
                        enabled: parent.hasOffset && !Lyrics.loading
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: Lyrics.offset = 0
                    }
                }
                IconButton { kind: "minus"; enabled: Lyrics.hasLyrics; onTapped: Lyrics.nudgeOffset(-0.25) }
                IconButton { kind: "plus"; enabled: Lyrics.hasLyrics; onTapped: Lyrics.nudgeOffset(0.25) }
                IconButton { kind: "resync"; spinning: Lyrics.loading; onTapped: Lyrics.refresh() }
            }
        }

        // list / empty states
        Item {
            width: parent.width
            height: parent.height - 26 - Theme.s3

            ListView {
                id: list
                anchors.fill: parent
                visible: Lyrics.hasLyrics
                model: Lyrics.lyrics
                spacing: Theme.s3
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: false

                currentIndex: {
                    model;  // re-evaluate when lyrics change
                    return Lyrics.indexForTime(root.estPos);
                }
                onModelChanged: Qt.callLater(() => positionViewAtIndex(currentIndex, ListView.Center))
                highlightRangeMode: ListView.ApplyRange
                highlightMoveDuration: 320
                preferredHighlightBegin: (height - (currentItem ? currentItem.implicitHeight : 0)) / 2
                preferredHighlightEnd: (height + (currentItem ? currentItem.implicitHeight : 0)) / 2

                delegate: Text {
                    id: line
                    required property string modelData
                    required property int index
                    width: list.width
                    text: modelData !== "" ? modelData : "· · ·"
                    textFormat: Text.PlainText
                    horizontalAlignment: Text.AlignLeft
                    color: ListView.isCurrentItem ? Player.text
                         : lineMa.containsMouse ? Theme.alpha(Player.text, 0.75)
                         : Theme.alpha(Player.text, 0.38)
                    font.pixelSize: ListView.isCurrentItem ? 17 : 14
                    font.weight: ListView.isCurrentItem ? Font.DemiBold : Font.Normal
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    Behavior on color { ColorAnimation { duration: 300 } }

                    MouseArea {
                        id: lineMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const t = Lyrics.timeForIndex(line.index);
                            if (t >= 0 && Player.canSeek) Player.seekTo(t);
                        }
                    }
                }
            }

            // soft top/bottom fades so lines dissolve toward the edges and the
            // current line reads as the focus. Fades toward shadow (not the base
            // tint, which can be lighter than the backdrop) so it works on any
            // palette. Purely decorative — no input.
            Rectangle {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: 40
                visible: Lyrics.hasLyrics
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.45) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 40
                visible: Lyrics.hasLyrics
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.45) }
                }
            }

            // empty / loading
            Column {
                anchors.centerIn: parent
                spacing: Theme.s2
                visible: !Lyrics.hasLyrics
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Lyrics.loading ? "◌" : "◈"
                    color: Theme.alpha(Player.text, 0.4)
                    font.pixelSize: 28
                    RotationAnimation on rotation {
                        from: 0; to: 360; duration: 1600
                        loops: Animation.Infinite
                        running: Lyrics.loading && root.visible
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Lyrics.loading ? "Loading lyrics…" : "No lyrics found"
                    color: Theme.alpha(Player.text, 0.5)
                    font.pixelSize: Theme.fLabel
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !Lyrics.loading
                    text: "click to retry"
                    color: retryMa.containsMouse ? Theme.alpha(Player.text, 0.75) : Theme.alpha(Player.text, 0.4)
                    font.pixelSize: Theme.fCaption
                    font.letterSpacing: 1
                }
            }
            MouseArea {
                id: retryMa
                anchors.centerIn: parent
                width: 160; height: 90
                visible: !Lyrics.hasLyrics && !Lyrics.loading
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Lyrics.refresh()
            }
        }
    }
}
