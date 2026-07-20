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
    // a pure warm gold, barely tinted by the theme — kept saturated on purpose
    // so the bolt reads as ITS OWN thing, never blended into the ambient crest
    readonly property color warm: Theme.mix("#ffb35c", Style.accentAlt, 0.16)
    readonly property color glowB: Theme.mix("#ff7a7a", Style.accent, 0.2)

    // the sliders' own live (Behavior-animated) positions — the lightning
    // canvas reads these every frame it repaints, so the bolt threads through
    // wherever the handles actually are, mid-drag or mid-preset-animation
    property var liveBands: [Eq.band(1), Eq.band(2), Eq.band(3), Eq.band(4), Eq.band(5),
                              Eq.band(6), Eq.band(7), Eq.band(8), Eq.band(9), Eq.band(10)]
    function setLive(i, v) { liveBands[i] = v; }

    // ---- the lightning: event-driven only, never idle ----
    property real lightningProgress: 0.0   // 0..10, sweeps left to right
    property real lightningFade: 1.0       // 0 fresh .. 1 fully gone
    SequentialAnimation {
        id: lightningAnim
        running: false
        ScriptAction { script: { root.lightningFade = 0.0; root.lightningProgress = 0.0; } }
        NumberAnimation { target: root; property: "lightningProgress"; from: 0.0; to: 10.0
                           duration: 650; easing.type: Easing.OutSine }
        PauseAnimation { duration: 150 }
        NumberAnimation { target: root; property: "lightningFade"; from: 0.0; to: 1.0
                           duration: 800; easing.type: Easing.OutQuad }
        ScriptAction { script: { root.lightningProgress = 0.0; } }
    }
    Connections {
        target: Eq
        function onPresetChanged() { if (Eq.preset !== "Custom") lightningAnim.restart(); }
    }

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
                                if (!pressed) Eq.setBand(cell.index + 1, Math.round(value));
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
                                    width: parent.width + 14 + cell.ringPulse * 26
                                    height: parent.height + 10 + cell.ringPulse * 40
                                    radius: parent.radius + 8 + cell.ringPulse * 14
                                    color: "transparent"
                                    border.color: root.warm
                                    border.width: 1.5 + cell.ringPulse * 3
                                    opacity: cell.ringPulse * 0.8 * (1.0 - root.lightningFade)
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
                                            height: 44
                                            y: (cell.trackPulse * (parent.height + height)) - height
                                            opacity: Math.sin(cell.trackPulse * Math.PI) * 1.6 * (1.0 - root.lightningFade)
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
                                scale: 1.0 + energy * 0.2 + cell.hitPulse * 0.35 * (1.0 - root.lightningFade)
                                border.width: 2
                                border.color: Style.accent
                                Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }

                                Rectangle {
                                    id: handleBloom
                                    anchors.centerIn: parent
                                    width: parent.width + 30 * cell.hitPulse
                                    height: width; radius: width / 2
                                    color: root.warm
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

        // ---- the bolt itself: 4 stacked noisy strokes (wide+dim to
        // hairline+bright), redrawn every frame while active. Pure event
        // flourish — the Timer only runs during the sweep/fade window.
        Canvas {
            id: lightningCanvas
            anchors.fill: parent
            anchors.bottomMargin: 18
            z: 2
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

                const time = Date.now() / 1000;
                const maxIdx = root.lightningProgress;
                const w = width, h = height;
                ctx.lineJoin = "round"; ctx.lineCap = "round";

                const pts = [];
                for (let i = 0; i < 10; i++) {
                    const norm = 1.0 - ((root.liveBands[i] + 12) / 24);
                    const py = 10 + norm * (h - 30);
                    const px = (i + 0.5) * (w / 10);
                    pts.push({ x: px, y: py });
                }

                for (let s = 0; s < 4; s++) {
                    ctx.beginPath();
                    ctx.moveTo(pts[0].x, pts[0].y);
                    for (let i = 0; i < pts.length - 1; i++) {
                        if (i > maxIdx) break;
                        const p1 = pts[i], p2 = pts[i + 1];
                        let fraction = 1.0;
                        if (maxIdx < i + 1) fraction = maxIdx - i;

                        const steps = s === 3 ? 6 : 8;
                        for (let j = 1; j <= steps; j++) {
                            let t = j / steps;
                            if (t > fraction) t = fraction;
                            const cx = p1.x + (p2.x - p1.x) * t;
                            const cy = p1.y + (p2.y - p1.y) * t;
                            const envelope = Math.sin(t * Math.PI);
                            const noiseAmpX = s === 3 ? 1.0 : (4 - s) * 3;
                            const noiseAmpY = s === 3 ? 1.0 : (4 - s) * 4;
                            const sepWaveX = (s < 2) ? Math.sin(time * 3 + i + j + s) * 8 * envelope : 0;
                            const sepWaveY = (s < 2) ? Math.cos(time * 2.5 + i - j - s) * 10 * envelope : 0;
                            const noiseX = Math.sin(time * (10 + s) + i + j) * Math.cos(time * 8 - i + j)
                                          * noiseAmpX * envelope * (1 - root.lightningFade);
                            const noiseY = Math.cos(time * (9 - s) + i - j) * Math.sin(time * 7 + i - j)
                                          * noiseAmpY * envelope * (1 - root.lightningFade);
                            ctx.lineTo(cx + sepWaveX + noiseX, cy + sepWaveY + noiseY);
                            if (t === fraction) break;
                        }
                    }
                    if (s === 0) { ctx.lineWidth = 16; ctx.strokeStyle = root.warm; ctx.globalAlpha = 0.2; }
                    else if (s === 1) { ctx.lineWidth = 7; ctx.strokeStyle = root.glowB; ctx.globalAlpha = 0.45; }
                    else if (s === 2) { ctx.lineWidth = 3; ctx.strokeStyle = Style.accent; ctx.globalAlpha = 0.85; }
                    else { ctx.lineWidth = 1; ctx.strokeStyle = "#ffffff"; ctx.globalAlpha = 0.15; }
                    ctx.stroke();
                }
            }
        }
        MultiEffect {
            anchors.fill: lightningCanvas
            source: lightningCanvas
            z: 1.5
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
