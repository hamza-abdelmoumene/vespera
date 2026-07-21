// The backdrop: a translucent, album-driven "room" the glass panels refract.
//
// Three quiet layers, from back to front:
//   1. a semi-transparent album-tinted ground (bgOpacity lets the compositor's
//      desktop blur show through — the "transparency" the owner wanted);
//   2. the album cover itself, HEAVILY blurred + graded — real imagery, softened
//      so it never looks blocky (this is "the cover back", cleverly: it's the
//      organic colour field, not a full-strength photo);
//   3. a few large, very soft floating orbs for gentle life, drawn with a smooth
//      gaussian falloff so there's no banding/blotchiness.
// Everything is album-reactive (Style.accent/accentAlt/base + the blurred cover),
// so the whole room recolours per track.
import QtQuick
import Vespera

Item {
    id: root
    property url source            // kept for API symmetry
    property bool animate: true
    clip: true

    readonly property real intensity: Style.orbIntensity
    readonly property real bg: Style.bgOpacity
    readonly property real minDim: Math.min(width, height)

    // 1. album-tinted ground, translucent by bgOpacity
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.alpha(Theme.mix(Style.base, Style.accent, 0.09), root.bg) }
            GradientStop { position: 0.5; color: Theme.alpha(Style.base, root.bg) }
            GradientStop { position: 1.0; color: Theme.alpha(Qt.darker(Style.base, 1.28), root.bg) }
        }
    }

    // 2. the cover, heavily blurred (tiny C++ image upscaled smoothly) + graded
    Image {
        id: cover
        anchors.fill: parent
        // heavy radius (tiny source) -> silky; the Blur knob (Style.coverBlur) nudges
        // it within a always-soft range so it never turns into a sharp photo
        source: Cover.blurBase + "/" + Math.round(96 + Style.coverBlur)
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        cache: true
        smooth: true
        mipmap: true
        visible: status === Image.Ready
        opacity: Style.coverPresence * root.bg
        Behavior on opacity { NumberAnimation { duration: Theme.durSlow; easing.type: Easing.InOutQuad } }
    }
    Rectangle {   // grade tint pulls the cover into the theme mood
        anchors.fill: parent
        color: Style.gradeColor
        opacity: Style.gradeStrength * Style.coverPresence * root.bg
    }

    // 3. floating orbs — few, large, and very soft
    property real phase: 0
    NumberAnimation on phase {
        from: 0; to: 2 * Math.PI
        duration: 108000; loops: Animation.Infinite
        running: root.animate && Style.sceneAnimate && !Style.reduceMotion
    }

    readonly property var orbs: [
        { cx: 0.17, cy: 0.16, r: 0.62, role: 0, amp: 0.045, fx: 1.0, fy: 0.7, off: 0.0, op: 0.34 },
        { cx: 0.85, cy: 0.30, r: 0.56, role: 1, amp: 0.055, fx: 0.8, fy: 1.1, off: 1.9, op: 0.30 },
        { cx: 0.52, cy: 0.82, r: 0.66, role: 2, amp: 0.05,  fx: 1.1, fy: 0.9, off: 3.4, op: 0.26 },
        { cx: 0.90, cy: 0.80, r: 0.48, role: 0, amp: 0.05,  fx: 0.9, fy: 1.2, off: 5.1, op: 0.22 }
    ]

    Repeater {
        model: root.orbs
        delegate: Item {
            id: orb
            required property var modelData

            readonly property real rad: modelData.r * root.minDim
            readonly property real dx: modelData.amp * root.width  * Math.cos(root.phase * modelData.fx + modelData.off)
            readonly property real dy: modelData.amp * root.height * Math.sin(root.phase * modelData.fy + modelData.off)
            readonly property color baseTone: modelData.role === 0 ? Style.accent
                                        : modelData.role === 1 ? Style.accentAlt
                                                               : Theme.mix(Style.accent, Style.accentAlt, 0.5)
            readonly property color tone: Theme.mix(baseTone, "#ffffff", 0.16)

            width: rad * 2; height: rad * 2
            x: modelData.cx * root.width - rad + dx
            y: modelData.cy * root.height - rad + dy

            Canvas {
                id: c
                anchors.fill: parent
                opacity: modelData.op * root.intensity * root.bg
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const cx = width / 2, cy = height / 2, r = width / 2;
                    const g = ctx.createRadialGradient(cx, cy, 0, cx, cy, r);
                    // smooth power falloff sampled at many stops => no banding, no
                    // hard edge, just a clean soft bloom
                    const N = 14;
                    for (let s = 0; s <= N; s++) {
                        const t = s / N;
                        g.addColorStop(t, Theme.alpha(orb.tone, Math.pow(1 - t, 2.4)));
                    }
                    ctx.fillStyle = g;
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, 0, Math.PI * 2);
                    ctx.fill();
                }
                onWidthChanged: requestPaint()
                Connections { target: Style; function onChanged() { c.requestPaint(); } }
                Component.onCompleted: requestPaint()
            }
        }
    }

    // vignette — soft radial edge darkening (respects transparency)
    Canvas {
        id: vig
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width, h = height;
            const g = ctx.createRadialGradient(w / 2, h / 2, Math.min(w, h) * 0.36,
                                               w / 2, h / 2, Math.max(w, h) * 0.76);
            g.addColorStop(0.0, "transparent");
            g.addColorStop(1.0, Qt.rgba(0, 0, 0, Style.vignette * root.bg));
            ctx.fillStyle = g;
            ctx.fillRect(0, 0, w, h);
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections { target: Style; function onChanged() { vig.requestPaint(); } }
    }

    // fine film grain (off unless a theme/user turns it on)
    Image {
        anchors.fill: parent
        source: "image://vespera/grain"
        fillMode: Image.Tile
        opacity: Style.grain * root.bg
        cache: true
        smooth: false
    }
}
