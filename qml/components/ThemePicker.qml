// Settings drawer — theme switcher + deep customisation, as a right-side glass
// drawer. Picking a theme cross-fades the whole UI (in C++). Every knob below
// overrides a look parameter and persists (XDG). Organised into labelled sections
// so "anything can be customised" without becoming a wall of sliders.
import QtQuick
import QtQuick.Controls.Basic
import Vespera

Item {
    id: root
    property bool open: false
    signal requestClose()

    // dim scrim — click outside to dismiss
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: root.open ? 0.46 : 0
        visible: opacity > 0.001
        Behavior on opacity { NumberAnimation { duration: Theme.durMed } }
        MouseArea {
            anchors.fill: parent
            enabled: root.open
            onClicked: root.requestClose()
        }
    }

    // drawer
    Rectangle {
        id: drawer
        width: Math.min(392, root.width)
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        x: root.open ? root.width - width : root.width
        Behavior on x { NumberAnimation { duration: Theme.durSlow; easing.type: Easing.OutExpo } }
        color: Qt.rgba(Style.surfaceStrong.r, Style.surfaceStrong.g, Style.surfaceStrong.b, 0.93)
        border.width: 1
        border.color: Theme.alpha(Style.line, 0.12)

        // a thin accent seam down the drawer's leading edge
        Rectangle {
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.alpha(Style.accent, 0.0) }
                GradientStop { position: 0.5; color: Theme.alpha(Style.accent, 0.5) }
                GradientStop { position: 1.0; color: Theme.alpha(Style.accentAlt, 0.0) }
            }
        }

        // keep clicks inside from dismissing
        MouseArea { anchors.fill: parent }

        // sticky header
        Item {
            id: hdr
            anchors { top: parent.top; left: parent.left; right: parent.right }
            anchors.margins: Theme.s5
            height: 26
            z: 2
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.s2
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8; height: 8; radius: 2; rotation: 45
                    color: Style.accent
                }
                Text {
                    text: "Settings"
                    color: Style.text
                    font.family: Style.displayFamily
                    font.pixelSize: Theme.fTitle
                    font.weight: Font.DemiBold
                    font.letterSpacing: Theme.trackLabel
                }
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "✕"
                color: Theme.alpha(Style.text, closeMa.containsMouse ? 0.95 : 0.5)
                font.pixelSize: Theme.fBody
                MouseArea {
                    id: closeMa
                    anchors.fill: parent
                    anchors.margins: -8
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.requestClose()
                }
            }
        }

        Flickable {
            anchors { top: hdr.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
            anchors.leftMargin: Theme.s5
            anchors.rightMargin: Theme.s5
            anchors.topMargin: Theme.s3
            contentHeight: content.height + Theme.s6
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: content
                width: parent.width
                spacing: Theme.s3

                // ---- THEME ----
                SectionHeader { label: "Theme" }
                Column {
                    width: parent.width
                    spacing: Theme.s2
                    Repeater {
                        model: Style.themes
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool active: Style.themeId === modelData.id
                            width: content.width
                            height: 60
                            radius: Theme.rMd
                            color: active ? Theme.alpha(Style.accent, 0.16)
                                          : cardMa.containsMouse ? Theme.alpha(Style.text, 0.08)
                                                                 : Theme.alpha(Style.text, 0.03)
                            border.width: 1
                            border.color: active ? Theme.alpha(Style.accent, 0.5) : Theme.alpha(Style.line, 0.08)
                            Behavior on color { ColorAnimation { duration: Theme.durFast } }
                            scale: cardMa.pressed ? 0.98 : 1.0
                            Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }

                            Row {
                                anchors.fill: parent
                                anchors.margins: Theme.s3
                                spacing: Theme.s3

                                Rectangle {
                                    id: swRect
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 38; height: 38; radius: 10
                                    clip: true
                                    readonly property var sw: Style.swatch(modelData.id)
                                    readonly property color cAccent: sw && sw.length ? sw[1] : Style.accent
                                    readonly property color cGrade: sw && sw.length ? sw[0] : Style.base
                                    readonly property color cBase: sw && sw.length ? sw[2] : Style.base
                                    gradient: Gradient {
                                        GradientStop { position: 0.0; color: swRect.cAccent }
                                        GradientStop { position: 0.55; color: swRect.cGrade }
                                        GradientStop { position: 1.0; color: swRect.cBase }
                                    }
                                    border.width: 1
                                    border.color: Theme.alpha("#ffffff", 0.14)
                                    Rectangle {
                                        anchors.right: parent.right; anchors.bottom: parent.bottom
                                        anchors.margins: 5
                                        width: 9; height: 9; radius: 5
                                        color: swRect.cAccent
                                        border.width: 1
                                        border.color: Theme.alpha("#000000", 0.25)
                                    }
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 38 - Theme.s3
                                    spacing: 2
                                    Text {
                                        text: modelData.name
                                        color: Style.text
                                        font.pixelSize: Theme.fBody
                                        font.weight: Font.DemiBold
                                    }
                                    Text {
                                        width: parent.width
                                        text: modelData.blurb
                                        color: Theme.alpha(Style.text, 0.5)
                                        font.pixelSize: Theme.fCaption
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }
                                }
                            }
                            // active tick
                            Rectangle {
                                visible: parent.active
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                anchors.rightMargin: Theme.s3
                                width: 7; height: 7; radius: 4
                                color: Style.accent
                            }
                            MouseArea {
                                id: cardMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Style.setTheme(modelData.id)
                            }
                        }
                    }
                }

                // ---- BACKDROP ----
                SectionHeader { label: "Backdrop" }
                KnobRow {
                    width: parent.width
                    label: "Cover presence"
                    value: Style.coverPresence
                    onMoved: (v) => Style.coverPresence = v
                }
                KnobRow {
                    width: parent.width
                    label: "Floating orbs"
                    value: Style.orbIntensity
                    onMoved: (v) => Style.orbIntensity = v
                }
                KnobRow {
                    width: parent.width
                    label: "Transparency"
                    // bgOpacity is floored at 0.35, so transparency maps 0..1 -> 1.0..0.35
                    value: (1 - Style.bgOpacity) / 0.65
                    onMoved: (v) => Style.bgOpacity = 1 - v * 0.65
                }
                KnobRow {
                    width: parent.width
                    label: "Vignette"
                    value: Style.vignette / 0.5
                    onMoved: (v) => Style.ovVignette = v * 0.5
                }
                KnobRow {
                    width: parent.width
                    label: "Film grain"
                    value: Style.grain / 0.25
                    onMoved: (v) => Style.ovGrain = v * 0.25
                }

                // ---- GLASS ----
                SectionHeader { label: "Glass" }
                KnobRow {
                    width: parent.width
                    label: "Frost"
                    value: Style.glassOpacity / 0.6
                    onMoved: (v) => Style.ovGlass = v * 0.6
                }
                KnobRow {
                    width: parent.width
                    label: "Blur"
                    value: Style.ovBlur >= 0 ? (Style.ovBlur - 0.3) / 1.7 : 0.41
                    onMoved: (v) => Style.ovBlur = 0.3 + v * 1.7
                }

                // ---- GLOW & COLOUR ----
                SectionHeader { label: "Glow & colour" }
                KnobRow {
                    width: parent.width
                    label: "Glow strength"
                    value: Style.glowStrength
                    onMoved: (v) => Style.glowStrength = v
                }
                KnobRow {
                    width: parent.width
                    label: "Accent shift"
                    value: (Style.accentHue + 30) / 60
                    onMoved: (v) => Style.accentHue = v * 60 - 30
                }

                // ---- MOTION ----
                SectionHeader { label: "Motion" }
                KnobRow {
                    width: parent.width
                    label: "Disc spin speed"
                    value: (Style.discSpin - 0.2) / 2.8
                    onMoved: (v) => Style.discSpin = 0.2 + v * 2.8
                }
                ToggleRow {
                    width: parent.width
                    label: "Reduce motion"
                    on: Style.reduceMotion
                    onToggled: Style.reduceMotion = !Style.reduceMotion
                }

                // ---- EQUALIZER ----
                SectionHeader { label: "Equalizer" }
                ToggleRow {
                    width: parent.width
                    label: "Transition effect"
                    on: Style.eqEffectOn
                    onToggled: Style.eqEffectOn = !Style.eqEffectOn
                }

                // ---- LYRICS ----
                SectionHeader { label: "Lyrics" }
                ToggleRow {
                    width: parent.width
                    label: "Block letters"
                    on: Style.lyricsBlockMode
                    onToggled: Style.lyricsBlockMode = !Style.lyricsBlockMode
                }
                ToggleRow {
                    width: parent.width
                    label: "Hide lyrics pane"
                    on: Style.lyricsHidden
                    onToggled: Style.lyricsHidden = !Style.lyricsHidden
                }

                // ---- TYPOGRAPHY ----
                SectionHeader { label: "Typography" }
                Item {
                    width: parent.width
                    height: 32
                    Row {
                        anchors.fill: parent
                        spacing: Theme.s2
                        Repeater {
                            model: ["Rubik", "Maple", "Mono", "Sys"]
                            delegate: Rectangle {
                                required property int index
                                required property string modelData
                                readonly property bool on: Style.fontChoice === index
                                width: (parent.width - Theme.s2 * 3) / 4
                                height: 32
                                radius: Theme.rSm
                                color: on ? Theme.alpha(Style.accent, 0.18)
                                          : fMa.containsMouse ? Theme.alpha(Style.text, 0.08)
                                                              : Theme.alpha(Style.text, 0.03)
                                border.width: 1
                                border.color: on ? Theme.alpha(Style.accent, 0.5) : Theme.alpha(Style.line, 0.08)
                                Behavior on color { ColorAnimation { duration: Theme.durFast } }
                                scale: fMa.pressed ? 0.94 : 1.0
                                Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: parent.on ? Style.accent : Theme.alpha(Style.text, 0.65)
                                    font.pixelSize: Theme.fCaption
                                    font.weight: parent.on ? Font.DemiBold : Font.Normal
                                }
                                MouseArea {
                                    id: fMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Style.fontChoice = index
                                }
                            }
                        }
                    }
                }

                // ---- EXTRAS ----
                SectionHeader { label: "Extras" }
                ToggleRow {
                    width: parent.width
                    label: "Floating music notes"
                    on: Style.notesOn
                    onToggled: Style.notesOn = !Style.notesOn
                }

                Item { width: 1; height: Theme.s2 }

                // reset all look knobs
                Rectangle {
                    width: parent.width
                    height: 38
                    radius: Theme.rSm
                    color: resetMa.containsMouse ? Theme.alpha(Style.accent, 0.14) : Theme.alpha(Style.text, 0.04)
                    border.width: 1
                    border.color: Theme.alpha(Style.line, 0.1)
                    Behavior on color { ColorAnimation { duration: Theme.durFast } }
                    Text {
                        anchors.centerIn: parent
                        text: "Reset customisation"
                        color: resetMa.containsMouse ? Style.accent : Theme.alpha(Style.text, 0.7)
                        font.pixelSize: Theme.fLabel
                        font.letterSpacing: 0.5
                    }
                    MouseArea {
                        id: resetMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Style.resetKnobs()
                    }
                }
            }
        }
    }

    // ---- little building blocks ----

    // a section label with a divider line trailing off to the right
    component SectionHeader: Item {
        property string label: ""
        width: parent ? parent.width : 0
        height: 30
        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            spacing: Theme.s3
            Text {
                text: label.toUpperCase()
                color: Theme.alpha(Style.text, 0.5)
                font.pixelSize: Theme.fCaption
                font.weight: Font.DemiBold
                font.letterSpacing: Theme.trackCaps
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x
                height: 1
                color: Theme.alpha(Style.line, 0.1)
            }
        }
    }

    // a labelled on/off switch
    component ToggleRow: Item {
        id: trow
        property string label: ""
        property bool on: false
        signal toggled()
        implicitHeight: 32
        Text {
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            text: trow.label
            color: Theme.alpha(Style.text, 0.78)
            font.pixelSize: Theme.fLabel
        }
        Rectangle {
            id: track
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            width: 42; height: 22; radius: 11
            scale: swMa.pressed ? 0.94 : 1.0
            Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
            color: trow.on ? Theme.alpha(Style.accent, 0.6) : Theme.alpha(Style.text, 0.12)
            Behavior on color { ColorAnimation { duration: Theme.durFast } }
            Rectangle {
                width: 16; height: 16; radius: 8
                color: Style.text
                y: (parent.height - height) / 2
                x: trow.on ? parent.width - width - 3 : 3
                Behavior on x { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
            }
            MouseArea {
                id: swMa
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: trow.toggled()
            }
        }
    }

    // a small labelled slider with a live value pip
    component KnobRow: Item {
        id: knob
        property string label: ""
        property real value: 0.5
        signal moved(real v)
        implicitHeight: 44
        Text {
            anchors.left: parent.left
            anchors.top: parent.top
            text: knob.label
            color: Theme.alpha(Style.text, 0.78)
            font.pixelSize: Theme.fLabel
        }
        Text {
            anchors.right: parent.right
            anchors.top: parent.top
            text: Math.round(knob.value * 100) + "%"
            color: Theme.alpha(Style.text, 0.4)
            font.family: Style.monoFamily
            font.pixelSize: Theme.fCaption
        }
        Slider {
            id: sl
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 18
            from: 0; to: 1
            value: knob.value
            onMoved: knob.moved(value)
            background: Rectangle {
                x: sl.leftPadding; y: sl.topPadding + sl.availableHeight / 2 - height / 2
                width: sl.availableWidth; height: 4; radius: 2
                color: Theme.alpha(Style.text, 0.14)
                Rectangle {
                    width: sl.visualPosition * parent.width
                    height: parent.height; radius: 2
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Style.accent }
                        GradientStop { position: 1.0; color: Style.accentAlt }
                    }
                }
            }
            handle: Rectangle {
                x: sl.leftPadding + sl.visualPosition * (sl.availableWidth - width)
                y: sl.topPadding + sl.availableHeight / 2 - height / 2
                width: 14; height: 14; radius: 7
                color: Style.text
                border.width: 1.5
                border.color: Theme.alpha(Style.accent, 0.6)
                scale: sl.pressed ? 1.15 : 1.0
                Behavior on scale { NumberAnimation { duration: Theme.durFast } }
            }
        }
    }
}
