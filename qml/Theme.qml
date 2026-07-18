pragma Singleton

// Vespera design tokens. Colours are album-derived (via the Player context
// object); this holds the fixed spacing / radius / type scale and small colour
// helpers so the UI reads as one system.
import QtQuick

QtObject {
    // 8pt-ish spacing scale
    readonly property int s1: 4
    readonly property int s2: 8
    readonly property int s3: 12
    readonly property int s4: 16
    readonly property int s5: 24
    readonly property int s6: 32
    readonly property int s7: 48

    // radii
    readonly property int rSm: 6
    readonly property int rMd: 14
    readonly property int rLg: 18

    // type scale (px)
    readonly property int fCaption: 11
    readonly property int fLabel: 12
    readonly property int fBody: 14
    readonly property int fTitle: 18
    readonly property int fDisplay: 22

    readonly property string monoFamily: "monospace"

    // easings
    readonly property int durFast: 130
    readonly property int durMed: 240

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }
    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t,
                       a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t,
                       a.a + (b.a - a.a) * t);
    }
}
