// 10-band equalizer — big, glassy, and expressive.
//
// At rest: plain sliders, nothing else — zero idle repaint. Applying a preset
// fires "the lightning": a jagged, 4-layer glowing bolt sweeps left to right
// through the ten band positions, and each slider reacts as the bolt reaches
// it — a shockwave ring, a bright surge travelling up the fill, the handle
// flashing and blooming — then everything fades back to silence. This is a
// faithful port of the owner's own caelestia MusicPopup equalizer (the exact
// reference for "the transition effect"): ~/.config/quickshell/hud/music/
// MusicPopup.qml, eqLightning* state + lightningCanvas. Ported 1:1 onto
// vespera's Eq singleton and theme tokens — same timings, same layered-stroke
// technique, same per-slider cascade — swapping Catppuccin accents for
// Style.accent/root.warm/root.glowB so it recolours with the theme.
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Effects
import QtQuick.Layouts
import Vespera

ColumnLayout {
    id: root
    spacing: Theme.s3

    readonly property var labels: ["31", "63", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"]

    // ---- palette for the smooth sweep ----
    // The transition is a smooth glowing CURVE now, not a jagged bolt (the old
    // noisy zigzag read as a "kid's random drawing"). Colours come from the theme
    // accent/accentAlt so it's elegant, luminous light; boltHue drives the gentle
    // per-band hue shimmer, and achromatic accents (Noir) fall back to a soft
    // electric violet so the effect never goes flat grey.
    readonly property bool boltAchroma: Style.accent.hslSaturation < 0.15
    readonly property real boltHue: boltAchroma ? 0.76 : Style.accent.hslHue
    // soft, luminous accents for the per-band pulses — gentle, never harsh
    readonly property color warm: Theme.mix(Style.accentAlt, "#ffffff", 0.28)
    readonly property color glowB: Theme.mix(Style.accent, "#ffffff", 0.15)

    // the sliders' own live (Behavior-animated) positions — the sweep canvas reads
    // these every frame it repaints, so the curve threads through wherever the
    // handles actually are, mid-drag or mid-preset-animation
    property var liveBands: [Eq.band(1), Eq.band(2), Eq.band(3), Eq.band(4), Eq.band(5),
                              Eq.band(6), Eq.band(7), Eq.band(8), Eq.band(9), Eq.band(10)]
    function setLive(i, v) { liveBands[i] = v; }

    // ---- the smooth sweep: event-driven only, never idle ----
    // (property names kept from the old effect so the per-band pulse code below is
    // unchanged: progress 0..10 is the reveal front, fade 0..1 dissolves it.)
    property real lightningProgress: 0.0   // 0..10, the reveal front sweeping L→R
    property real lightningFade: 1.0       // 0 fresh .. 1 fully gone
    SequentialAnimation {
        id: lightningAnim
        running: false
        ScriptAction { script: { root.lightningFade = 0.0; root.lightningProgress = 0.0; } }
        NumberAnimation { target: root; property: "lightningProgress"; from: 0.0; to: 10.0
                           duration: 780; easing.type: Easing.InOutCubic }
        PauseAnimation { duration: 220 }
        NumberAnimation { target: root; property: "lightningFade"; from: 0.0; to: 1.0
                           duration: 760; easing.type: Easing.InOutQuad }
        ScriptAction { script: { root.lightningProgress = 0.0; } }
    }
    Connections {
        target: Eq
        function onPresetChanged() { if (Style.eqEffectOn && Eq.preset !== "Custom") lightningAnim.restart(); }
    }
    // fire the sweep on a single-band edit too, so any EQ change gets the effect
    function pulse() { if (Style.eqEffectOn) lightningAnim.restart(); }

    // ---- header ----
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.s3
        Text {
            text: "Equalizer"
            color: Style.text
            font.family: Style.displayFamily
            font.pixelSize: Theme.fTitle
            font.weight: Font.DemiBold
            font.letterSpacing: Theme.trackLabel
            Layout.fillWidth: true
        }
        Rectangle {
            implicitWidth: presetName.width + Theme.s4
            implicitHeight: 24
            radius: 12
            color: Theme.alpha(Style.accent, 0.16)
            border.width: 1
            border.color: Theme.alpha(Style.accent, 0.3)
            Text {
                id: presetName
                anchors.centerIn: parent
                text: Eq.preset
                color: Style.accent
                font.family: Style.monoFamily
                font.pixelSize: Theme.fCaption
                font.weight: Font.DemiBold
                font.letterSpacing: 1.2
                textFormat: Text.PlainText
            }
        }
    }

    // ---- sliders + effects (grows with the panel) ----
    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 150

        Row {
            id: eqRow
            anchors.fill: parent
            anchors.bottomMargin: 18
            z: 1
            Repeater {
                model: 10
                delegate: Item {
                    id: cell
                    required property int index
                    width: eqRow.width / 10
                    height: eqRow.height

                    // ---- this band's place in the sweep ----
                    readonly property real dist: root.lightningProgress - cell.index
                    readonly property real hitPulse: dist >= 0 && dist < 1.0 ? Math.sin(dist * Math.PI) : 0.0
                    property real trackPulse: 0.0
                    property real ringPulse: 0.0
                    property real flashFade: 0.0
                    property bool hasFired: false
                    onDistChanged: {
                        if (dist <= 0.05) hasFired = false;
                        else if (dist > 0.4 && !hasFired) {
                            hasFired = true;
                            trackPulseAnim.restart();
                            ringPulseAnim.restart();
                            flashFadeAnim.restart();
                        }
                    }
                    NumberAnimation { id: trackPulseAnim; target: cell; property: "trackPulse"
                                       from: 0.0; to: 1.0; duration: 900; easing.type: Easing.OutQuart }
                    NumberAnimation { id: ringPulseAnim; target: cell; property: "ringPulse"
                                       from: 1.0; to: 0.0; duration: 1300; easing.type: Easing.OutExpo }
                    NumberAnimation { id: flashFadeAnim; target: cell; property: "flashFade"
                                       from: 1.0; to: 0.0; duration: 1300; easing.type: Easing.OutSine }

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Theme.s1

                        Slider {
                            id: sld
                            Layout.fillHeight: true
                            Layout.alignment: Qt.AlignHCenter
                            orientation: Qt.Vertical
                            from: -12; to: 12; stepSize: 1
                            value: Eq.band(cell.index + 1)

                            Connections {
                                target: Eq
                                function onBandsChanged() {
                                    if (!sld.pressed) sld.value = Eq.band(cell.index + 1);
                                }
                            }
                            Behavior on value {
                                enabled: !sld.pressed
                                NumberAnimation { duration: 340; easing.type: Easing.OutQuart }
                            }
                            onValueChanged: root.setLive(cell.index, value)
                            onPressedChanged: {
                                if (!pressed) { Eq.setBand(cell.index + 1, Math.round(value)); root.pulse(); }
                            }

                            background: Rectangle {
                                id: trackBg
                                x: sld.leftPadding + (sld.availableWidth - width) / 2
                                y: sld.topPadding
                                width: 5
                                height: sld.availableHeight
                                radius: 2.5
                                color: Theme.alpha("#ffffff", 0.16)

                                // shockwave ring — fires once as the bolt passes this band.
                                // Standalone MultiEffect (not layer.effect): item layering
                                // doesn't render on the offscreen/software RHI path this app
                                // also uses for CI captures, but a sibling MultiEffect with an
                                // explicit source does — same visual, more reliable.
                                Rectangle {
                                    id: ringShape
                                    z: -1
                                    anchors.centerIn: parent
                                    width: parent.width + 14 + cell.ringPulse * 24
                                    height: parent.height + 10 + cell.ringPulse * 38
                                    radius: parent.radius + 7 + cell.ringPulse * 13
                                    color: "transparent"
                                    border.color: root.warm
                                    border.width: 1.5 + cell.ringPulse * 2.5
                                    opacity: cell.ringPulse * 0.55 * (1.0 - root.lightningFade)
                                    visible: opacity > 0.005
                                }
                                MultiEffect {
                                    anchors.fill: ringShape
                                    source: ringShape
                                    z: -2
                                    visible: ringShape.visible
                                    blurEnabled: true
                                    blurMax: 24
                                    blur: 1.0
                                }

                                // fill — a hot glowing tip at rest; a flash wash + a
                                // travelling surge bolt when the lightning hits
                                Item {
                                    width: parent.width
                                    height: (1 - sld.visualPosition) * parent.height
                                    y: sld.visualPosition * parent.height
                                    clip: true

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 2.5
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: Theme.mix(Style.accent, "#ffffff", 0.55) }
                                            GradientStop { position: 0.18; color: Style.accent }
                                            GradientStop { position: 1.0; color: Theme.mix(Style.accent, Style.accentAlt, 0.85) }
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            opacity: cell.flashFade
                                            gradient: Gradient {
                                                GradientStop { position: 0.0; color: root.warm }
                                                GradientStop { position: 0.5; color: Style.accent }
                                                GradientStop { position: 1.0; color: "transparent" }
                                            }
                                        }

                                        Rectangle {
                                            id: surgeBolt
                                            width: parent.width
                                            height: 56
                                            y: (cell.trackPulse * (parent.height + height)) - height
                                            opacity: Math.sin(cell.trackPulse * Math.PI) * 2.2 * (1.0 - root.lightningFade)
                                            visible: opacity > 0.005
                                            gradient: Gradient {
                                                GradientStop { position: 0.0; color: "transparent" }
                                                GradientStop { position: 0.2; color: Style.accent }
                                                GradientStop { position: 0.5; color: "#ffffff" }
                                                GradientStop { position: 0.8; color: root.warm }
                                                GradientStop { position: 1.0; color: "transparent" }
                                            }
                                        }
                                        MultiEffect {
                                            anchors.fill: surgeBolt
                                            source: surgeBolt
                                            visible: surgeBolt.visible
                                            shadowEnabled: true
                                            shadowColor: Style.accent
                                            shadowBlur: 1.0
                                            shadowOpacity: 1.0
                                        }
                                    }
                                }
                            }

                            handle: Rectangle {
                                x: sld.leftPadding + (sld.availableWidth - width) / 2
                                y: sld.topPadding + sld.visualPosition * (sld.availableHeight - height)
                                width: 18; height: 18; radius: 9
                                color: "#ffffff"
                                readonly property real energy: sld.pressed ? 1.0 : sld.hovered ? 0.5 : 0.0
                                scale: 1.0 + energy * 0.2 + cell.hitPulse * 0.44 * (1.0 - root.lightningFade)
                                border.width: 2
                                border.color: Style.accent
                                Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }

                                Rectangle {
                                    id: handleBloom
                                    anchors.centerIn: parent
                                    width: parent.width + 44 * cell.hitPulse
                                    height: width; radius: width / 2
                                    // a subtle, BALANCED hue shimmer across the bands
                                    // (centred on the accent, ±13°) so the cascade reads
                                    // as distinct hits sweeping across without any band
                                    // sliding into a clashing colour
                                    color: Qt.hsla((root.boltHue + (cell.index - 4.5) * 0.008 + 1.0) % 1.0, 0.94, 0.73, 1.0)
                                    opacity: cell.hitPulse * (1.0 - root.lightningFade)
                                    visible: opacity > 0.005
                                }
                                MultiEffect {
                                    anchors.fill: handleBloom
                                    source: handleBloom
                                    z: -1
                                    visible: handleBloom.visible
                                    blurEnabled: true
                                    blurMax: 24
                                    blur: 1.0
                                }
                            }
                        }
                        Text {
                            text: root.labels[cell.index]
                            color: Theme.alpha(Style.text, 0.5)
                            font.family: Style.monoFamily
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }
        }

        // ---- the smooth sweep ---- a single flowing, glowing curve traced through
        // the band tops (smooth quadratic, NO noise), revealed left→right with a
        // bright energy head at the front, then dissolved. Layered soft glow + a
        // crisp bright core reads as elegant liquid light, not a jagged scribble.
        // Event-driven; the Timer only runs during the sweep window.
        Canvas {
            id: lightningCanvas
            anchors.fill: parent
            anchors.bottomMargin: 18
            z: 0.1   // behind the sliders (eqRow z:1): the curve glows up through the tracks
            opacity: 1.0 - root.lightningFade
            renderTarget: Canvas.FramebufferObject

            Timer {
                interval: 16
                running: root.lightningFade < 1.0 && root.lightningProgress > 0.0
                repeat: true
                onTriggered: lightningCanvas.requestPaint()
            }

            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                if (root.lightningProgress <= 0.0 || root.lightningFade >= 1.0) return;

                const w = width, h = height;
                const u = Math.max(1.0, Math.min(2.2, w / 620));
                const gs = Style.glowStrength;
                const prog = Math.min(1.0, root.lightningProgress / 10.0);   // reveal 0..1
                const frontX = prog * w;

                // band tops (read live so the bolt follows the handles as they settle)
                const pts = [];
                for (let i = 0; i < 10; i++) {
                    const norm = 1.0 - ((root.liveBands[i] + 12) / 24);
                    const py = 10 + norm * (h - 30);
                    const px = (i + 0.5) * (w / 10);
                    pts.push({ x: px, y: py });
                }

                // a DESIGNED zigzag between the band anchors — two deterministic jag
                // points per segment, offset perpendicular in alternating directions.
                // Deterministic (index-based, no per-frame randomness) so it's a
                // clean, stable lightning bolt, not a scribble; the amplitudes vary
                // just enough to feel organic. Rounded joins + the soft glow layers
                // keep it smooth and professional rather than razor-jagged.
                const zig = [pts[0]];
                for (let i = 0; i < pts.length - 1; i++) {
                    const a = pts[i], b = pts[i + 1];
                    const dx = b.x - a.x, dy = b.y - a.y;
                    const L = Math.max(1, Math.hypot(dx, dy));
                    const nx = -dy / L, ny = dx / L;            // unit perpendicular
                    const a1 = (9 + ((i * 7) % 8)) * u;
                    const a2 = (9 + ((i * 5 + 3) % 8)) * u;
                    zig.push({ x: a.x + dx * 0.36 + nx * a1, y: a.y + dy * 0.36 + ny * a1 });
                    zig.push({ x: a.x + dx * 0.68 - nx * a2, y: a.y + dy * 0.68 - ny * a2 });
                    zig.push(b);
                }
                function trace() {
                    ctx.beginPath();
                    ctx.moveTo(zig[0].x, zig[0].y);
                    for (let i = 1; i < zig.length; i++) ctx.lineTo(zig[i].x, zig[i].y);
                }
                ctx.lineJoin = "round"; ctx.lineCap = "round";

                // reveal: only the swept-past portion of the bolt is drawn
                ctx.save();
                ctx.beginPath();
                ctx.rect(0, 0, frontX + 1.5, h);
                ctx.clip();

                // a gentle gradient along the bolt, accent → accentAlt
                const grad = ctx.createLinearGradient(0, 0, w, 0);
                grad.addColorStop(0.0, Style.accent);
                grad.addColorStop(1.0, Style.accentAlt);

                trace(); ctx.strokeStyle = grad; ctx.globalAlpha = 0.12 + 0.14 * gs; ctx.lineWidth = 20 * u; ctx.stroke();
                trace(); ctx.strokeStyle = grad; ctx.globalAlpha = 0.5;               ctx.lineWidth = 7 * u;  ctx.stroke();
                trace(); ctx.strokeStyle = Theme.mix(Style.accentAlt, "#ffffff", 0.72); ctx.globalAlpha = 0.95; ctx.lineWidth = 2.2 * u; ctx.stroke();
                ctx.restore();

                // bright energy head riding the front of the reveal
                if (prog < 0.998) {
                    const fi = Math.max(0, Math.min(9, prog * 10 - 0.5));
                    const lo = Math.floor(fi), frac = fi - lo, hi = Math.min(9, lo + 1);
                    const fy = pts[lo].y + (pts[hi].y - pts[lo].y) * frac;
                    const br = (18 + 12 * gs) * u;
                    const bg = ctx.createRadialGradient(frontX, fy, 0, frontX, fy, br);
                    bg.addColorStop(0.0, Theme.alpha("#ffffff", 0.95));
                    bg.addColorStop(0.35, Theme.alpha(root.warm, 0.7));
                    bg.addColorStop(1.0, "transparent");
                    ctx.globalAlpha = 1.0;
                    ctx.fillStyle = bg;
                    ctx.beginPath(); ctx.arc(frontX, fy, br, 0, Math.PI * 2); ctx.fill();
                }
                ctx.globalAlpha = 1.0;
            }
        }
        MultiEffect {
            anchors.fill: lightningCanvas
            source: lightningCanvas
            z: 0.05   // soft bloom just under the crisp curve, still behind sliders
            visible: lightningCanvas.opacity > 0.005
            shadowEnabled: true
            shadowColor: root.warm
            shadowBlur: 1.0
            shadowOpacity: 0.5
        }
    }

    // ---- presets ----
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Theme.s2
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s2
            Repeater {
                model: ["Flat", "Bass", "Treble", "Vocal"]
                delegate: PresetButton {
                    required property string modelData
                    name: modelData
                    onPicked: Eq.applyPreset(name)
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s2
            Repeater {
                model: ["Pop", "Rock", "Jazz", "Classic"]
                delegate: PresetButton {
                    required property string modelData
                    name: modelData
                    onPicked: Eq.applyPreset(name)
                }
            }
        }
    }
}
