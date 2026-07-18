// Previous / Play-Pause / Next.
import QtQuick
import Vespera

Row {
    id: root
    spacing: Theme.s6

    property color accent: "#6fe9ff"
    property color iconColor: "#eaf2ff"
    property color accentInk: "#04121b"  // icon colour drawn on top of the accent fill
    property bool playing: false
    property bool canPrev: true
    property bool canNext: true

    signal prev()
    signal playPause()
    signal next()

    GlyphButton {
        anchors.verticalCenter: parent.verticalCenter
        glyph: "prev"
        iconColor: root.iconColor
        opacity: root.canPrev ? 1.0 : 0.35
        enabled: root.canPrev
        onClicked: root.prev()
    }
    GlyphButton {
        anchors.verticalCenter: parent.verticalCenter
        glyph: root.playing ? "pause" : "play"
        primary: true
        accent: root.accent
        iconColor: root.accentInk
        onClicked: root.playPause()
    }
    GlyphButton {
        anchors.verticalCenter: parent.verticalCenter
        glyph: "next"
        iconColor: root.iconColor
        opacity: root.canNext ? 1.0 : 0.35
        enabled: root.canNext
        onClicked: root.next()
    }
}
