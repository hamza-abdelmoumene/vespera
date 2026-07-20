// Ambient floating music notes — geometric note glyphs drifting up over the
// cover backdrop (behind the glass panels, so they read faintly through the
// frost). Gated: they only rise while a track is playing. No emoji — the note
// characters are geometric Unicode music symbols.
import QtQuick
import Vespera

Item {
    id: root
    property bool animate: true
    property color color: Style.accent
    clip: true

    Repeater {
        model: 10
        delegate: Text {
            id: note
            required property int index
            readonly property var glyphs: ["♪", "♫", "♩", "♬"]
            text: glyphs[index % 4]
            color: root.color
            opacity: 0
            font.family: Style.monoFamily
            font.pixelSize: 13 + Math.random() * 16
            x: Math.random() * root.width
            y: root.height
            property real drift: (Math.random() - 0.5) * root.width * 0.12
            property int dur: 6000 + Math.random() * 6000

            SequentialAnimation {
                running: root.animate && root.visible
                loops: Animation.Infinite
                // staggered start so they cascade in rather than all at once
                PauseAnimation { duration: Math.round(note.index * 280 + Math.random() * 1600) }
                ScriptAction {
                    script: {
                        note.x = root.width * (0.08 + Math.random() * 0.84);
                        note.font.pixelSize = 13 + Math.random() * 16;
                        note.rotation = (Math.random() - 0.5) * 24;
                    }
                }
                ParallelAnimation {
                    NumberAnimation { target: note; property: "y"
                                      from: root.height * 0.92; to: root.height * 0.12
                                      duration: note.dur; easing.type: Easing.OutSine }
                    NumberAnimation { target: note; property: "x"; to: note.x + note.drift; duration: note.dur }
                    SequentialAnimation {
                        NumberAnimation { target: note; property: "opacity"; from: 0; to: 0.45
                                          duration: note.dur * 0.32; easing.type: Easing.OutSine }
                        NumberAnimation { target: note; property: "opacity"; to: 0
                                          duration: note.dur * 0.68; easing.type: Easing.InSine }
                    }
                }
            }
        }
    }
}
