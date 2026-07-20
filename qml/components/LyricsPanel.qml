// Synced lyrics in a glass panel — centred current line, click-to-seek,
// ±0.25s per-track offset, resync.
//
// Scrolling: the list follows the song automatically, smoothly centring the
// current line (ApplyRange + highlightMoveDuration). The moment you scroll by
// hand, auto-follow yields — your position sticks — and a "Resume" affordance
// appears. After a few idle seconds (or a tap on Resume) it eases the current
// line back to centre and resumes following.
import QtQuick
import Vespera

GlassPanel {
    id: root

    // interpolated playback position (poll cadence is coarse; advance locally)
    property real estPos: Player.position
    property double _t0: Date.now()
    function pushFollow() { if (list.following) list.currentIndex = Lyrics.indexForTime(root.estPos); }
    Connections {
        target: Player
        function onPositionChanged() { root.estPos = Player.position; root._t0 = Date.now(); root.pushFollow(); }
    }
    Timer {
        interval: 120
        running: Player.playing && root.visible && Lyrics.hasLyrics
        repeat: true
        onTriggered: { root.estPos = Player.position + (Date.now() - root._t0) / 1000; root.pushFollow(); }
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
                    color: Style.accent
                }
                Text {
                    text: "Lyrics"
                    color: Style.accent
                    font.family: Style.displayFamily
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
                    color: hasOffset && !Lyrics.loading ? "#e8c07d" : Theme.alpha(Style.text, 0.45)
                    font.family: Style.monoFamily
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
                interactive: true
                boundsBehavior: Flickable.StopAtBounds
                flickDeceleration: 3500

                // auto-follow lever: while following, currentIndex tracks the song
                // and ApplyRange keeps it centred; hand-scrolling freezes it.
                // `moving` is set only by user gestures (drag / flick / wheel), not
                // by the programmatic ApplyRange recentre, so it's the clean signal
                // that the listener took over.
                property bool following: true
                function refollow() {
                    following = true;
                    currentIndex = Lyrics.indexForTime(root.estPos);
                }
                function userTook() { following = false; idle.restart(); }
                Timer { id: idle; interval: 3400; onTriggered: list.refollow() }

                onMovingChanged: if (moving) userTook()

                onModelChanged: Qt.callLater(() => { refollow(); positionViewAtIndex(currentIndex, ListView.Center); })

                // capture-only: enter the hand-scrolled state so the Resume
                // affordance + take-over can be screenshotted.
                Timer {
                    running: captureScrolled
                    interval: 250
                    onTriggered: {
                        list.userTook();
                        list.contentY = Math.min(Math.max(0, list.contentHeight - list.height),
                                                 list.contentY + 150);
                    }
                }
                highlightRangeMode: ListView.ApplyRange
                highlightMoveDuration: 380
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
                    color: ListView.isCurrentItem ? Style.text
                         : lineMa.containsMouse ? Theme.alpha(Style.text, 0.75)
                         : Theme.alpha(Style.text, 0.34)
                    font.pixelSize: ListView.isCurrentItem ? 18 : 14
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

            // resume affordance — only while hand-scrolled away from the song
            Rectangle {
                id: resume
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.s3
                visible: Lyrics.hasLyrics && !list.following
                width: resumeRow.width + Theme.s4
                height: 28
                radius: 14
                color: Theme.alpha(Style.accent, 0.9)
                Row {
                    id: resumeRow
                    anchors.centerIn: parent
                    spacing: Theme.s1
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "↺"
                        color: Style.base
                        font.pixelSize: 14
                        font.weight: Font.Bold
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Resume"
                        color: Style.base
                        font.pixelSize: Theme.fCaption
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: list.refollow()
                }
                Behavior on opacity { NumberAnimation { duration: Theme.durMed } }
            }

            // empty / loading
            Column {
                anchors.centerIn: parent
                spacing: Theme.s2
                visible: !Lyrics.hasLyrics
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Lyrics.loading ? "◌" : "◈"
                    color: Theme.alpha(Style.text, 0.4)
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
                    color: Theme.alpha(Style.text, 0.5)
                    font.pixelSize: Theme.fLabel
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !Lyrics.loading
                    text: "click to retry"
                    color: retryMa.containsMouse ? Theme.alpha(Style.text, 0.75) : Theme.alpha(Style.text, 0.4)
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
