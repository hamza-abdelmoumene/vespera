// Vespera main window — Observatory look, responsive player | lyrics panes.
import QtQuick
import QtQuick.Layouts
import QtCore
import Vespera

Window {
    id: win
    visible: true
    width: startCompact ? 380 : 1180
    height: startCompact ? 560 : 760
    minimumWidth: 340
    minimumHeight: 400
    title: qsTr("Vespera")
    color: Player.base

    Behavior on color { ColorAnimation { duration: 400 } }

    property bool userCompact: startCompact
    readonly property bool compact: userCompact || width < 640
    readonly property bool showLyrics: !compact && width >= 900

    // Per-mode geometry persistence (~/.config/vespera/vespera.conf).
    Settings {
        category: startCompact ? "compact" : "window"
        property alias x: win.x
        property alias y: win.y
        property alias width: win.width
        property alias height: win.height
    }

    // drive services from the active track / playback state
    function pushTrack() {
        if (Player.hasPlayer)
            Lyrics.setTrack(Player.artist, Player.title, Player.album, Player.length);
        else
            Lyrics.clearTrack();
    }
    Component.onCompleted: pushTrack()
    Connections {
        target: Player
        function onActiveChanged() { win.pushTrack(); }
    }
    Binding {
        target: Cava
        property: "active"
        value: win.visible && Player.playing
    }

    StarryScene {
        id: scene
        anchors.fill: parent
        base: Player.base
        accent: Player.accent
        accentAlt: Player.accentAlt
        animate: win.visible
    }

    // top app header
    Item {
        id: chrome
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 44

        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: Theme.s4
            spacing: Theme.s2
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 9; height: 9; radius: 2; rotation: 45
                color: Player.accent
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "vespera"
                color: Player.text
                font.pixelSize: Theme.fBody
                font.weight: Font.DemiBold
                font.letterSpacing: 2
            }
        }

        Text {
            anchors.centerIn: parent
            visible: Player.hasPlayer && !win.compact
            text: Player.playerName
            textFormat: Text.PlainText
            color: Theme.alpha(Player.text, 0.5)
            font.pixelSize: Theme.fCaption
            font.letterSpacing: 1
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: Theme.s4
            spacing: Theme.s3

            Item {
                width: 22; height: 22
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    anchors.centerIn: parent
                    width: win.compact ? 9 : 14
                    height: win.compact ? 9 : 14
                    radius: 2
                    color: "transparent"
                    border.width: 1.5
                    border.color: Theme.alpha(Player.text, cMa.containsMouse ? 0.9 : 0.55)
                }
                MouseArea {
                    id: cMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: win.userCompact = !win.userCompact
                }
            }

            Item {
                width: 22; height: 22
                anchors.verticalCenter: parent.verticalCenter
                Canvas {
                    id: closeIcon
                    anchors.centerIn: parent
                    width: 12; height: 12
                    property bool hot: xMa.containsMouse
                    onHotChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        ctx.strokeStyle = Theme.alpha(Player.text, hot ? 0.95 : 0.55);
                        ctx.lineWidth = 1.5;
                        ctx.beginPath();
                        ctx.moveTo(1, 1); ctx.lineTo(width - 1, height - 1);
                        ctx.moveTo(width - 1, 1); ctx.lineTo(1, height - 1);
                        ctx.stroke();
                    }
                    Component.onCompleted: requestPaint()
                }
                MouseArea {
                    id: xMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Qt.quit()
                }
            }
        }
    }

    // content — player pane | lyrics pane
    RowLayout {
        anchors {
            top: chrome.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            leftMargin: win.compact ? 0 : Theme.s6
            rightMargin: win.compact ? 0 : Theme.s6
            bottomMargin: win.compact ? 0 : Theme.s6
            topMargin: win.compact ? 0 : Theme.s3
        }
        spacing: Theme.s6

        PlayerPane {
            Layout.fillWidth: true
            Layout.fillHeight: true
            compact: win.compact
        }

        LyricsPanel {
            visible: win.showLyrics
            Layout.fillHeight: true
            Layout.preferredWidth: Math.max(300, Math.min(460, Math.round(win.width * 0.32)))
        }
    }

    // keyboard shortcuts (match the reference popup)
    Shortcut { sequence: "Space"; onActivated: Player.playPause() }
    Shortcut { sequence: "Right"; onActivated: if (Player.canSeek) Player.seekBy(5) }
    Shortcut { sequence: "Left"; onActivated: if (Player.canSeek) Player.seekBy(-5) }
    Shortcut { sequences: ["N", "Media Next"]; onActivated: Player.next() }
    Shortcut { sequences: ["P", "Media Previous"]; onActivated: Player.previous() }

    Connections {
        target: App
        function onToggleRequested() {
            if (win.visible) win.hide();
            else { win.show(); win.raise(); win.requestActivate(); }
        }
        function onShowRequested() { win.show(); win.raise(); win.requestActivate(); }
        function onHideRequested() { win.hide(); }
    }
}
