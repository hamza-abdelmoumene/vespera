// Composes the shared cover backdrop with the active theme's scene overlay.
// During a theme switch the outgoing and incoming scenes cross-fade (driven by
// Style.sceneMix in C++), while the cover-grade parameters blend underneath —
// so switching themes washes the whole room over, not just snaps.
import QtQuick
import Vespera

Item {
    id: root
    property url source
    property bool animate: true

    CoverBackdrop {
        anchors.fill: parent
        source: root.source
    }

    Component {
        id: auroraC
        AuroraOverlay {
            accent: Style.accent; accentAlt: Style.accentAlt; base: Style.base
            animate: root.animate && Style.sceneAnimate; intensity: Style.sceneIntensity
        }
    }
    Component {
        id: starC
        StarfieldOverlay {
            accent: Style.accent; accentAlt: Style.accentAlt; base: Style.base
            animate: root.animate && Style.sceneAnimate; intensity: Style.sceneIntensity
        }
    }
    Component {
        id: synthC
        SynthwaveOverlay {
            accent: Style.accent; accentAlt: Style.accentAlt; base: Style.base
            animate: root.animate && Style.sceneAnimate; intensity: Style.sceneIntensity
        }
    }

    function compFor(scene) {
        if (scene === "aurora") return auroraC;
        if (scene === "starfield") return starC;
        if (scene === "synthwave") return synthC;
        return null;  // "field" — no overlay, just the graded cover
    }

    // incoming / current scene
    Loader {
        anchors.fill: parent
        sourceComponent: root.compFor(Style.scene)
        opacity: Style.scene === Style.sceneFrom ? 1 : Style.sceneMix
    }
    // outgoing scene — only present mid-transition
    Loader {
        anchors.fill: parent
        active: Style.scene !== Style.sceneFrom
        sourceComponent: active ? root.compFor(Style.sceneFrom) : null
        opacity: 1 - Style.sceneMix
    }
}
