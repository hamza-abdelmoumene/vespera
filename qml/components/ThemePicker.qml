// In-app theme switcher + customisation, as a right-side glass drawer.
// Picking a theme cross-fades the whole UI (handled in C++). The knobs override
// the active theme's backdrop parameters and persist (XDG). Live swatches come
// from Style.swatch(id), so they recolour with the current track too.
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
        opacity: root.open ? 0.42 : 0
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
        width: Math.min(360, root.width)
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        x: root.open ? root.width - width : root.width
        Behavior on x { NumberAnimation { duration: Theme.durSlow; easing.type: Easing.OutExpo } }
        color: Qt.rgba(Style.surfaceStrong.r, Style.surfaceStrong.g, Style.surfaceStrong.b, 0.9)
        border.width: 1
        border.color: Theme.alpha(Style.line, 0.12)

        // keep clicks inside from dismissing
        MouseArea { anchors.fill: parent }

        Flickable {
            anchors.fill: parent
            anchors.margins: Theme.s5
            contentHeight: content.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: content
                width: parent.width
                spacing: Theme.s4

                // header
                Item {
                    width: parent.width
                    height: 24
                    Text {
                        anchors.left: parent.left
                        text: "Themes"
                        color: Style.text
                        font.pixelSize: Theme.fTitle
                        font.weight: Font.DemiBold
                        font.letterSpacing: Theme.trackLabel
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "✕"
                        color: Theme.alpha(Style.text, closeMa.containsMouse ? 0.9 : 0.5)
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

                // theme cards
                Column {
                    width: parent.width
                    spacing: Theme.s2
                    Repeater {
                        model: Style.themes
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool active: Style.themeId === modelData.id
                            width: content.width
                            height: 62
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

                                // live swatch — accent wash over the theme ground
                                Rectangle {
                                    id: swRect
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 40; height: 40; radius: 10
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
                                    width: parent.width - 40 - Theme.s3
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

                // customise
                Item {
                    width: parent.width
                    height: 20
                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "CUSTOMIZE"
                        color: Theme.alpha(Style.text, 0.45)
                        font.pixelSize: Theme.fCaption
                        font.weight: Font.DemiBold
                        font.letterSpacing: Theme.trackCaps
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "reset"
                        color: resetMa.containsMouse ? Style.accent : Theme.alpha(Style.text, 0.5)
                        font.pixelSize: Theme.fCaption
                        font.letterSpacing: 1
                        MouseArea {
                            id: resetMa
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Style.resetKnobs()
                        }
                    }
                }

                KnobRow {
                    width: parent.width
                    label: "Background blur"
                    value: Style.ovBlur >= 0 ? (Style.ovBlur - 0.3) / 1.7 : 0.41
                    onMoved: (v) => Style.ovBlur = 0.3 + v * 1.7
                }
                KnobRow {
                    width: parent.width
                    label: "Cover presence"
                    value: Style.coverOpacity
                    onMoved: (v) => Style.ovCoverOpacity = v
                }
                KnobRow {
                    width: parent.width
                    label: "Film grain"
                    value: Style.grain / 0.25
                    onMoved: (v) => Style.ovGrain = v * 0.25
                }
                KnobRow {
                    width: parent.width
                    label: "Glass frost"
                    value: Style.glassOpacity / 0.6
                    onMoved: (v) => Style.ovGlass = v * 0.6
                }
                KnobRow {
                    width: parent.width
                    label: "Accent shift"
                    value: (Style.accentHue + 30) / 60
                    onMoved: (v) => Style.accentHue = v * 60 - 30
                }
                KnobRow {
                    width: parent.width
                    label: "Live spectrum"
                    value: Style.eqCavaIntensity
                    onMoved: (v) => Style.eqCavaIntensity = v
                }
                KnobRow {
                    width: parent.width
                    label: "Disc spin speed"
                    value: (Style.discSpin - 0.2) / 2.8
                    onMoved: (v) => Style.discSpin = 0.2 + v * 2.8
                }

                // typeface picker
                Item {
                    width: parent.width
                    height: 46
                    Text {
                        anchors.left: parent.left; anchors.top: parent.top
                        text: "Typeface"
                        color: Theme.alpha(Style.text, 0.7)
                        font.pixelSize: Theme.fLabel
                    }
                    Row {
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        spacing: Theme.s2
                        Repeater {
                            model: ["Rubik", "Maple", "Mono", "Sys"]
                            delegate: Rectangle {
                                required property int index
                                required property string modelData
                                readonly property bool on: Style.fontChoice === index
                                width: (parent.width - Theme.s2 * 3) / 4
                                height: 30
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

                ToggleRow {
                    width: parent.width
                    label: "Floating notes"
                    on: Style.notesOn
                    onToggled: Style.notesOn = !Style.notesOn
                }
                ToggleRow {
                    width: parent.width
                    label: "Reduce motion"
                    on: Style.reduceMotion
                    onToggled: Style.reduceMotion = !Style.reduceMotion
                }

                Item { width: 1; height: Theme.s3 }
            }
        }
    }

    // a labelled on/off switch used by the customise section
    component ToggleRow: Item {
        id: row
        property string label: ""
        property bool on: false
        signal toggled()
        implicitHeight: 30
        Text {
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            text: row.label
            color: Theme.alpha(Style.text, 0.7)
            font.pixelSize: Theme.fLabel
        }
        Rectangle {
            id: track
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            width: 40; height: 22; radius: 11
            scale: swMa.pressed ? 0.94 : 1.0
            Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
            color: row.on ? Theme.alpha(Style.accent, 0.55) : Theme.alpha(Style.text, 0.12)
            Behavior on color { ColorAnimation { duration: Theme.durFast } }
            Rectangle {
                width: 16; height: 16; radius: 8
                color: Style.text
                y: (parent.height - height) / 2
                x: row.on ? parent.width - width - 3 : 3
                Behavior on x { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
            }
            MouseArea {
                id: swMa
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: row.toggled()
            }
        }
    }

    // small labelled slider used by the customise section
    component KnobRow: Item {
        id: knob
        property string label: ""
        property real value: 0.5
        signal moved(real v)
        implicitHeight: 42
        Text {
            anchors.left: parent.left
            anchors.top: parent.top
            text: knob.label
            color: Theme.alpha(Style.text, 0.7)
            font.pixelSize: Theme.fLabel
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
                    color: Style.accent
                }
            }
            handle: Rectangle {
                x: sl.leftPadding + sl.visualPosition * (sl.availableWidth - width)
                y: sl.topPadding + sl.availableHeight / 2 - height / 2
                width: 14; height: 14; radius: 7
                color: Style.text
                border.width: 1.5
                border.color: Theme.alpha(Style.accent, 0.6)
            }
        }
    }
}
