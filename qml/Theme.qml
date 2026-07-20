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
    readonly property int fHero: 30

    readonly property string monoFamily: "monospace"

    // letter-spacing rhythm — display type tracks tight, labels track open
    readonly property real trackTight: -0.4
    readonly property real trackLabel: 0.4
    readonly property real trackCaps: 2.0

    // motion durations (ms). Track recolour lives in C++ (~560ms) so the whole
    // palette washes in unison; these drive local micro-interactions.
    readonly property int durFast: 130
    readonly property int durMed: 240
    readonly property int durSlow: 420

    // typed parameters matter here: without them a raw hex string like
    // "#ffffff" passed in stays a plain JS string (no .r/.g/.b), and c.r/a.r
    // silently evaluate to undefined -> NaN -> Qt.rgba renders black. The
    // `: color` annotations make QML coerce string literals to real color
    // values at the call boundary, exactly where every caller in this codebase
    // passes hex literals directly (Theme.alpha("#ffffff", …), etc).
    function alpha(c: color, a: real): color {
        return Qt.rgba(c.r, c.g, c.b, a);
    }
    function mix(a: color, b: color, t: real): color {
        return Qt.rgba(a.r + (b.r - a.r) * t,
                       a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t,
                       a.a + (b.a - a.a) * t);
    }
}
