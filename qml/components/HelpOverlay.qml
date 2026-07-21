// First-run tutorial + in-app help. A glassy modal that walks through what Vespera
// does and how to customise it. Shown automatically on first launch (Style.
// tutorialSeen) and reopened any time from the "?" button in the header. Each page
// pairs a short, friendly explanation with a small themed illustration drawn in
// QML (crisp at any size, recolours with the theme) rather than a baked screenshot.
import QtQuick
import QtQuick.Layouts
import Vespera

Item {
    id: root
    property bool open: false
    signal requestClose()

    property int page: 0
    readonly property var pages: [
        { kind: "welcome",  title: "Welcome to Vespera",
          body: "A living music companion for every Linux desktop. It rides along with whatever you're playing — Spotify, a browser, anything with MPRIS — and makes it beautiful." },
        { kind: "themes",   title: "Your music, your colours",
          body: "The Vespera theme paints the whole app from your album art, so every track recolours the room. Prefer a fixed mood? Pick Ember, Obsidian, Aurora and more from the ◈ button, top-right." },
        { kind: "customize", title: "Customise everything",
          body: "Open Settings (the ◈ button) to tune it to taste: cover presence, floating orbs, background transparency, glass frost & blur, glow strength, accent shift, motion, and more. Every slider is live." },
        { kind: "lyrics",   title: "Sing along, your way",
          body: "Synced lyrics as a scrolling list you can click to seek — or as big ASCII block letters, karaoke style. Toggle from the Lyrics header, or hide the pane entirely to go full-width." },
        { kind: "eq",       title: "Shape the sound",
          body: "A 10-band equaliser with presets (Bass, Vocal, Rock…). Every change ripples across the bands as a smooth lightning sweep — turn the effect off in Settings if you'd rather keep it calm." },
        { kind: "shortcuts", title: "Handy shortcuts",
          body: "Space play/pause · ← / → seek · N / P next & previous · Esc close menus. Compact mode and the lyrics toggle live in the header. Press ? any time to see this again." }
    ]
    readonly property var cur: pages[page]

    // dim scrim
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: root.open ? 0.58 : 0
        visible: opacity > 0.001
        Behavior on opacity { NumberAnimation { duration: Theme.durMed } }
        MouseArea { anchors.fill: parent; enabled: root.open; onClicked: root.requestClose() }
    }

    // the card
    Item {
        anchors.centerIn: parent
        width: Math.min(560, root.width - Theme.s6 * 2)
        height: Math.min(560, root.height - Theme.s6 * 2)
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.94
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Theme.durMed } }
        Behavior on scale { NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutCubic } }

        GlassPanel {
            anchors.fill: parent
            radius: 22
            fillOpacity: Math.min(0.9, Style.glassOpacity + 0.5)
        }
        // keep clicks inside from closing
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.s6
            spacing: Theme.s4

            // skip / close
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 20
                Text {
                    anchors.right: parent.right
                    text: root.page === root.pages.length - 1 ? "" : "Skip"
                    color: Theme.alpha(Style.text, skipMa.containsMouse ? 0.9 : 0.5)
                    font.pixelSize: Theme.fCaption
                    font.letterSpacing: 1
                    MouseArea {
                        id: skipMa
                        anchors.fill: parent; anchors.margins: -8
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.requestClose()
                    }
                }
            }

            // illustration
            Item {
                id: art
                Layout.fillWidth: true
                Layout.preferredHeight: 190
                Loader {
                    anchors.centerIn: parent
                    sourceComponent: root.cur.kind === "welcome" ? illWelcome
                                   : root.cur.kind === "themes" ? illThemes
                                   : root.cur.kind === "customize" ? illCustomize
                                   : root.cur.kind === "lyrics" ? illLyrics
                                   : root.cur.kind === "eq" ? illEq
                                   : illShortcuts
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.cur.title
                color: Style.text
                font.family: Style.displayFamily
                font.pixelSize: Theme.fHero
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
            Text {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: root.cur.body
                color: Theme.alpha(Style.text, 0.72)
                font.family: Style.monoFamily
                font.pixelSize: Theme.fLabel
                lineHeight: 1.35
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                textFormat: Text.PlainText
            }

            // dots
            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: Theme.s2
                Repeater {
                    model: root.pages.length
                    Rectangle {
                        required property int index
                        width: index === root.page ? 20 : 7
                        height: 7; radius: 4
                        color: index === root.page ? Style.accent : Theme.alpha(Style.text, 0.2)
                        Behavior on width { NumberAnimation { duration: Theme.durFast } }
                        Behavior on color { ColorAnimation { duration: Theme.durFast } }
                    }
                }
            }

            // nav
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s3
                PillButton {
                    text: "Back"
                    subtle: true
                    visible: root.page > 0
                    onClicked: root.page = Math.max(0, root.page - 1)
                }
                Item { Layout.fillWidth: true }
                PillButton {
                    text: root.page === root.pages.length - 1 ? "Get started" : "Next"
                    onClicked: {
                        if (root.page === root.pages.length - 1) root.requestClose();
                        else root.page = root.page + 1;
                    }
                }
            }
        }
    }

    // ---- a small pill button ----
    component PillButton: Rectangle {
        id: pill
        property string text: ""
        property bool subtle: false
        signal clicked()
        implicitWidth: pillLabel.implicitWidth + Theme.s5 * 2
        implicitHeight: 38
        radius: 19
        color: subtle ? (pillMa.containsMouse ? Theme.alpha(Style.text, 0.12) : Theme.alpha(Style.text, 0.05))
                      : (pillMa.containsMouse ? Style.accent : Theme.alpha(Style.accent, 0.85))
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
        scale: pillMa.pressed ? 0.96 : 1.0
        Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
        Text {
            id: pillLabel
            anchors.centerIn: parent
            text: pill.text
            color: pill.subtle ? Theme.alpha(Style.text, 0.8) : Style.base
            font.family: Style.monoFamily
            font.pixelSize: Theme.fLabel
            font.weight: Font.DemiBold
            font.letterSpacing: 0.5
        }
        MouseArea {
            id: pillMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.clicked()
        }
    }

    // ---- illustrations (theme-aware, drawn in QML) ----
    Component {
        id: illWelcome
        Item {
            width: 200; height: 180
            // orbs
            Repeater {
                model: [{x: 0.2, y: 0.3, c: 0}, {x: 0.8, y: 0.35, c: 1}, {x: 0.5, y: 0.8, c: 2}]
                Rectangle {
                    required property var modelData
                    width: 120; height: 120; radius: 60
                    x: modelData.x * 200 - 60; y: modelData.y * 180 - 60
                    opacity: 0.5
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Theme.alpha(modelData.c === 0 ? Style.accent : modelData.c === 1 ? Style.accentAlt : Theme.mix(Style.accent, Style.accentAlt, 0.5), 0.6) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }
            }
            Rectangle {
                anchors.centerIn: parent
                width: 54; height: 54; radius: 14; rotation: 45
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Style.accent }
                    GradientStop { position: 1.0; color: Style.accentAlt }
                }
            }
        }
    }
    Component {
        id: illThemes
        Row {
            spacing: Theme.s3
            Repeater {
                model: (Style.themes || []).slice(0, 5)
                Rectangle {
                    required property var modelData
                    readonly property var sw: Style.swatch(modelData.id)
                    width: 46; height: 68; radius: 12
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: sw && sw.length ? sw[1] : Style.accent }
                        GradientStop { position: 1.0; color: sw && sw.length ? sw[2] : Style.base }
                    }
                    border.width: 1
                    border.color: Theme.alpha("#ffffff", 0.14)
                }
            }
        }
    }
    Component {
        id: illCustomize
        Column {
            spacing: Theme.s4
            Repeater {
                model: [0.7, 0.4, 0.85]
                Row {
                    required property var modelData
                    spacing: Theme.s3
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 180; height: 5; radius: 3
                        color: Theme.alpha(Style.text, 0.15)
                        Rectangle {
                            width: parent.width * modelData; height: parent.height; radius: 3
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: Style.accent }
                                GradientStop { position: 1.0; color: Style.accentAlt }
                            }
                        }
                        Rectangle {
                            x: parent.width * modelData - 8
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16; height: 16; radius: 8; color: Style.text
                            border.width: 1.5; border.color: Theme.alpha(Style.accent, 0.6)
                        }
                    }
                }
            }
        }
    }
    Component {
        id: illLyrics
        Column {
            spacing: 8
            Repeater {
                model: 5
                Rectangle {
                    required property int index
                    readonly property bool cur: index === 2
                    width: cur ? 150 : 110; height: cur ? 16 : 9; radius: 4
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: cur ? Style.accent : Theme.alpha(Style.text, 0.25)
                }
            }
        }
    }
    Component {
        id: illEq
        Row {
            spacing: 9
            Repeater {
                model: [0.5, 0.75, 0.6, 0.9, 0.7, 0.55, 0.8, 0.65]
                Rectangle {
                    required property var modelData
                    width: 8; height: 120; radius: 4
                    color: Theme.alpha(Style.text, 0.14)
                    Rectangle {
                        width: parent.width; height: 14; radius: 7
                        y: (1 - modelData) * (parent.height - height)
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Style.accent }
                            GradientStop { position: 1.0; color: Style.accentAlt }
                        }
                    }
                }
            }
        }
    }
    Component {
        id: illShortcuts
        Grid {
            columns: 2
            rowSpacing: Theme.s3
            columnSpacing: Theme.s4
            Repeater {
                model: [["Space", "play / pause"], ["← →", "seek"], ["N / P", "next / prev"], ["?", "help"]]
                Row {
                    required property var modelData
                    spacing: Theme.s2
                    Rectangle {
                        width: 58; height: 30; radius: 8
                        color: Theme.alpha(Style.text, 0.08)
                        border.width: 1; border.color: Theme.alpha(Style.text, 0.16)
                        Text {
                            anchors.centerIn: parent; text: modelData[0]
                            color: Style.text; font.family: Style.monoFamily
                            font.pixelSize: Theme.fCaption; font.weight: Font.DemiBold
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData[1]
                        color: Theme.alpha(Style.text, 0.6)
                        font.family: Style.monoFamily; font.pixelSize: Theme.fCaption
                    }
                }
            }
        }
    }
}
