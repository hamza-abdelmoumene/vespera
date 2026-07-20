// Vespera main window — Ember look: the album cover as a warm frosted backdrop
// with floating glass panels reading over it. Responsive player | lyrics panes.
import QtQuick
import QtQuick.Layouts
import QtCore
import Vespera

Window {
    id: win
    visible: true
    width: startCompact ? 384 : 1180
    height: startCompact ? 560 : 760
    minimumWidth: 340
    minimumHeight: 400
    title: qsTr("Vespera")
    // Style.base is cross-faded in C++ (per track AND per theme), so the whole
    // window recolours in unison — no local Behavior, which would double-animate.
    color: Style.base

    property bool userCompact: startCompact
    readonly property bool compact: userCompact || width < 640
    readonly property bool showLyrics: !compact && width >= 900
    property bool pickerOpen: false

    // Per-mode geometry persistence (~/.config/vespera/vespera.conf).
    Settings {
        category: startCompact ? "compact" : "window"
        property alias x: win.x
        property alias y: win.y
        property alias width: win.width
        property alias height: win.height
    }

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

    Backdrop {
        id: scene
        anchors.fill: parent
        source: Player.artUrl
        animate: win.visible
    }
    // What the glass panels refract: GlassPanel samples the region of this item
    // behind itself (ShaderEffectSource + MultiEffect). Panels are siblings of
    // the backdrop, never its children, so the sampling can't recurse.
    readonly property Item glassSourceItem: scene

    // ambient floating notes drifting over the whole player (in front of the
    // panels, low opacity), gated on playing + the notes toggle
    FloatingNotes {
        anchors.fill: parent
        anchors.topMargin: chrome.height
        z: 6
        animate: win.visible && Player.playing && Style.notesOn && !Style.reduceMotion
    }

    // top app header — also the window's drag handle, since there's no native
    // titlebar. z:10 keeps it (and its hover tooltips) above the content row.
    Item {
        id: chrome
        z: 10
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 44

        // empty chrome space drags the window; icon hit areas below are later
        // siblings, so they win hit-testing over their own bounds
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onPressed: (m) => { if (m.button === Qt.LeftButton) win.startSystemMove(); }
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: Theme.s4
            spacing: Theme.s2
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 9; height: 9; radius: 2; rotation: 45
                color: Style.accent
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "vespera"
                color: Style.text
                font.family: Style.monoFamily
                font.pixelSize: Theme.fBody
                font.weight: Font.DemiBold
                font.letterSpacing: Theme.trackCaps
            }
        }

        Text {
            anchors.centerIn: parent
            visible: Player.hasPlayer && !win.compact
            text: Player.playerName
            textFormat: Text.PlainText
            color: Theme.alpha(Style.text, 0.5)
            font.family: Style.monoFamily
            font.pixelSize: Theme.fCaption
            font.letterSpacing: 1
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: Theme.s4
            spacing: Theme.s3

            // theme switcher — a two-tone disc (accent / accentAlt)
            ChromeIcon {
                id: themeChrome
                tip: "Themes"
                onTapped: win.pickerOpen = !win.pickerOpen
                Canvas {
                    id: themeIcon
                    anchors.centerIn: parent
                    width: 16; height: 16
                    property bool hot: themeChrome.hovered || win.pickerOpen
                    onHotChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        const c = width / 2;
                        ctx.beginPath(); ctx.arc(c, c, c - 1, -Math.PI / 2, Math.PI / 2); ctx.closePath();
                        ctx.fillStyle = Style.accent; ctx.fill();
                        ctx.beginPath(); ctx.arc(c, c, c - 1, Math.PI / 2, -Math.PI / 2); ctx.closePath();
                        ctx.fillStyle = Style.accentAlt; ctx.fill();
                        ctx.beginPath(); ctx.arc(c, c, c - 1, 0, Math.PI * 2);
                        ctx.strokeStyle = Theme.alpha(Style.text, hot ? 0.9 : 0.5);
                        ctx.lineWidth = 1.4; ctx.stroke();
                    }
                    Component.onCompleted: requestPaint()
                    Connections {
                        target: Style
                        function onChanged() { themeIcon.requestPaint(); }
                    }
                }
            }

            ChromeIcon {
                id: compactChrome
                tip: win.userCompact ? "Expand" : "Compact"
                onTapped: win.userCompact = !win.userCompact
                Rectangle {
                    anchors.centerIn: parent
                    width: win.compact ? 9 : 14
                    height: win.compact ? 9 : 14
                    radius: 2
                    color: "transparent"
                    border.width: 1.5
                    border.color: Theme.alpha(Style.text, compactChrome.hovered ? 0.9 : 0.55)
                }
            }

            ChromeIcon {
                id: minimizeChrome
                tip: "Minimize"
                onTapped: win.showMinimized()
                Rectangle {
                    anchors.centerIn: parent
                    width: 10; height: 1.5; radius: 1
                    color: Theme.alpha(Style.text, minimizeChrome.hovered ? 0.95 : 0.55)
                }
            }

            ChromeIcon {
                id: closeChrome
                tip: "Close"
                onTapped: Qt.quit()
                Canvas {
                    id: closeIcon
                    anchors.centerIn: parent
                    width: 12; height: 12
                    property bool hot: closeChrome.hovered
                    onHotChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        ctx.strokeStyle = Theme.alpha(Style.text, hot ? 0.95 : 0.55);
                        ctx.lineWidth = 1.5;
                        ctx.beginPath();
                        ctx.moveTo(1, 1); ctx.lineTo(width - 1, height - 1);
                        ctx.moveTo(width - 1, 1); ctx.lineTo(1, height - 1);
                        ctx.stroke();
                    }
                    Component.onCompleted: requestPaint()
                    Connections {
                        target: Style
                        function onChanged() { closeIcon.requestPaint(); }
                    }
                }
            }
        }
    }

    // a 22x22 chrome control: press feedback + a small hover tooltip, since
    // every chrome icon here is icon-only with no visible label
    component ChromeIcon: Item {
        id: btn
        width: 22; height: 22
        anchors.verticalCenter: parent.verticalCenter
        property string tip: ""
        readonly property alias hovered: ma.containsMouse
        default property alias content: slot.data
        signal tapped()

        scale: ma.pressed ? 0.86 : 1.0
        Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }

        Item { id: slot; anchors.fill: parent }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.tapped()
        }

        Rectangle {
            visible: btn.tip !== "" && ma.containsMouse
            anchors.top: parent.bottom
            anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            radius: Theme.rSm
            color: Theme.mix(Style.base, "#000000", 0.35)
            border.width: 1
            border.color: Theme.alpha(Style.line, 0.16)
            width: tipText.implicitWidth + Theme.s3
            height: tipText.implicitHeight + Theme.s2
            Text {
                id: tipText
                anchors.centerIn: parent
                text: btn.tip
                textFormat: Text.PlainText
                color: Style.text
                font.family: Style.monoFamily
                font.pixelSize: Theme.fCaption
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
            leftMargin: win.compact ? Theme.s2 : Theme.s4
            rightMargin: win.compact ? Theme.s2 : Theme.s4
            bottomMargin: win.compact ? Theme.s2 : Theme.s4
            topMargin: Theme.s1
        }
        spacing: Theme.s4

        PlayerPane {
            Layout.fillWidth: true
            Layout.fillHeight: true
            compact: win.compact
        }

        LyricsPanel {
            visible: win.showLyrics
            Layout.fillHeight: true
            Layout.preferredWidth: Math.max(300, Math.min(430, Math.round(win.width * 0.28)))
        }
    }

    // theme picker overlay (above everything, incl. floating notes)
    ThemePicker {
        anchors.fill: parent
        z: 20
        open: win.pickerOpen
        onRequestClose: win.pickerOpen = false
    }

    // keyboard shortcuts (match the reference popup)
    Shortcut { sequence: "Space"; onActivated: Player.playPause() }
    Shortcut { sequence: "Right"; onActivated: if (Player.canSeek) Player.seekBy(5) }
    Shortcut { sequence: "Left"; onActivated: if (Player.canSeek) Player.seekBy(-5) }
    Shortcut { sequences: ["N", "Media Next"]; onActivated: Player.next() }
    Shortcut { sequences: ["P", "Media Previous"]; onActivated: Player.previous() }
    Shortcut { sequence: "Escape"; onActivated: win.pickerOpen = false }

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
