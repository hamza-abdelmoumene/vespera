// 10-band equalizer — big, glassy, and expressive (the reference look).
//
// The gain curve threads through the ten handle positions and is ALWAYS
// there (not a transient flash) — it just smoothly re-shapes itself as the
// sliders move, whether that's a hand-drag or a preset applying. A brief,
// clean brightness pulse (no filled glow shape, no shadow blob) marks the
// moment something changes. The live cava trace above rides independently.
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
    // so the curve reads as ITS OWN thing, never blended into the ambient crest
    readonly property color warm: Theme.mix("#ffb35c", Style.accentAlt, 0.16)
    readonly property color glowB: Theme.mix("#ff7a7a", Style.accent, 0.2)

    // the sliders' own live (Behavior-animated) positions — the curve reads
    // these every frame they move, so it re-shapes in step with the handles
    // instead of jump-cutting to the new gain values
    property var liveBands: [Eq.band(1), Eq.band(2), Eq.band(3), Eq.band(4), Eq.band(5),
                              Eq.band(6), Eq.band(7), Eq.band(8), Eq.band(9), Eq.band(10)]
    function setLive(i, v) { liveBands[i] = v; gainFx.requestPaint(); }

    // a brief, localised-nowhere brightness pulse — alpha/width only, never a
    // filled shape — marking a preset apply or a released slider
    property real pulse: 0
    NumberAnimation { id: pulseAnim; target: root; property: "pulse"; from: 1; to: 0
                       duration: 700; easing.type: Easing.OutCubic }
    Connections {
        target: Eq
        function onPresetChanged() { if (Eq.preset !== "Custom") pulseAnim.restart(); }
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
            z: 1
            Repeater {
                model: 10
                delegate: Item {
                    id: cell
                    required property int index
                    width: eqRow.width / 10
                    height: eqRow.height

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
                            // every frame this animates (drag OR preset apply), the gain
                            // curve re-shapes in step — no separate "trace" animation needed
                            onValueChanged: root.setLive(cell.index, value)
                            onPressedChanged: {
                                if (!pressed) {
                                    Eq.setBand(cell.index + 1, Math.round(value));
                                    pulseAnim.restart();   // single-band edits get a brightness pulse too
                                }
                            }

                            background: Rectangle {
                                x: sld.leftPadding + (sld.availableWidth - width) / 2
                                y: sld.topPadding
                                width: 5
                                height: sld.availableHeight
                                radius: 2.5
                                color: Theme.alpha("#ffffff", 0.16)
                                Rectangle {
                                    width: parent.width
                                    height: (1 - sld.visualPosition) * parent.height
                                    y: sld.visualPosition * parent.height
                                    radius: parent.radius
                                    // a hot, glowing tip at the fill's leading edge rather than a
                                    // flat two-stop fill — reads as lit, not just coloured
                                    gradient: Gradient {
                                        GradientStop { position: 0.0; color: Theme.mix(Style.accent, "#ffffff", 0.55) }
                                        GradientStop { position: 0.18; color: Style.accent }
                                        GradientStop { position: 1.0; color: Theme.mix(Style.accent, Style.accentAlt, 0.85) }
                                    }
                                }
                            }

                            handle: Rectangle {
                                x: sld.leftPadding + (sld.availableWidth - width) / 2
                                y: sld.topPadding + sld.visualPosition * (sld.availableHeight - height)
                                width: 18; height: 18; radius: 9
                                color: "#ffffff"
                                readonly property real energy: sld.pressed ? 1.0 : sld.hovered ? 0.5 : 0.0
                                scale: 1.0 + energy * 0.2
                                border.width: 2
                                border.color: Style.accent
                                Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
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

        // ---- the gain curve: ONE line, always present, connecting the ten
        // handles — the whole signature. It re-shapes itself in step with the
        // sliders (drag or preset apply), never a separate trace-in animation.
        // The glow is a real blur of a THICK stroke sitting behind a thin
        // crisp core — that's what makes it read as a lit, soft ribbon
        // instead of a hairline (no filled glow shapes, no shadow rectangle).
        Item {
            id: gainLayer
            anchors.fill: parent
            anchors.bottomMargin: 18
            z: 2

            function curveY(f, h) {
                const p = f * 9;
                const i0 = Math.floor(p), t = p - i0, i1 = Math.min(9, i0 + 1);
                const a = root.liveBands[i0], b = root.liveBands[i1];
                const s = t * t * (3 - 2 * t);                    // smoothstep
                const v = a * (1 - s) + b * s;                    // -12..12
                const norm = (v + 12) / 24;                       // 0..1
                return (1 - norm) * (h - 12) + 6;
            }
            function buildPath(ctx, w, h) {
                const N = 90;
                const pts = [];
                for (let k = 0; k < N; k++) {
                    const f = k / (N - 1);
                    pts.push({ x: f * w, y: gainLayer.curveY(f, h) });
                }
                ctx.beginPath();
                ctx.moveTo(pts[0].x, pts[0].y);
                for (let i = 1; i < pts.length - 1; i++) {
                    const mx = (pts[i].x + pts[i + 1].x) / 2, my = (pts[i].y + pts[i + 1].y) / 2;
                    ctx.quadraticCurveTo(pts[i].x, pts[i].y, mx, my);
                }
                ctx.lineTo(pts[pts.length - 1].x, pts[pts.length - 1].y);
                return pts;
            }
            function repaint() { glowSrc.requestPaint(); gainFx.requestPaint(); }

            // the glow source — a thick, saturated stroke with nothing else on
            // it. This is what gets blurred; it never renders on screen itself.
            Canvas {
                id: glowSrc
                anchors.fill: parent
                renderTarget: Canvas.FramebufferObject
                visible: false
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const w = width, h = height;
                    const p = root.pulse;
                    gainLayer.buildPath(ctx, w, h);
                    ctx.lineJoin = "round"; ctx.lineCap = "round";
                    const lg = ctx.createLinearGradient(0, 0, w, 0);
                    lg.addColorStop(0.0, root.warm);
                    lg.addColorStop(0.5, Qt.lighter(root.warm, 1.2 + p * 0.15));
                    lg.addColorStop(1.0, root.glowB);
                    ctx.strokeStyle = lg;
                    ctx.lineWidth = 13 + p * 7;
                    ctx.globalAlpha = 0.9;
                    ctx.stroke();
                }
            }
            MultiEffect {
                anchors.fill: glowSrc
                source: glowSrc
                z: -1
                blurEnabled: true
                blur: 0.72 + root.pulse * 0.22
                blurMax: 56
                brightness: 0.16 + root.pulse * 0.14
                saturation: 0.08
            }

            // the crisp layer on top: silhouette wash + a thin bright core +
            // small dot markers at each band
            Canvas {
                id: gainFx
                anchors.fill: parent
                renderTarget: Canvas.FramebufferObject
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const w = width, h = height;
                    const p = root.pulse;   // 0 at rest .. 1 right after a change

                    const pts = gainLayer.buildPath(ctx, w, h);
                    ctx.lineJoin = "round"; ctx.lineCap = "round";

                    // soft filled wash under the line down to the floor
                    ctx.lineTo(pts[pts.length - 1].x, h);
                    ctx.lineTo(pts[0].x, h);
                    ctx.closePath();
                    const fg = ctx.createLinearGradient(0, 0, 0, h);
                    fg.addColorStop(0.0, Theme.alpha(root.warm, 0.22 + p * 0.12));
                    fg.addColorStop(1.0, Theme.alpha(root.warm, 0.0));
                    ctx.fillStyle = fg;
                    ctx.fill();

                    // thin bright core — the glow layer behind supplies the bloom
                    gainLayer.buildPath(ctx, w, h);
                    const lg = ctx.createLinearGradient(0, 0, w, 0);
                    lg.addColorStop(0.0, Qt.lighter(root.warm, 1.1));
                    lg.addColorStop(0.5, "#ffffff");
                    lg.addColorStop(1.0, Qt.lighter(root.glowB, 1.15));
                    ctx.strokeStyle = lg;
                    ctx.lineWidth = 1.8 + p * 1.0;
                    ctx.stroke();

                    // small dot markers at each band — the connect-the-dots read
                    // from the reference, a soft core that breathes with the pulse
                    for (let b = 0; b < 10; b++) {
                        const f = (b + 0.5) / 10;
                        const x = f * w, y = gainLayer.curveY(f, h);
                        const rr = 4 + p * 3;
                        const dg = ctx.createRadialGradient(x, y, 0, x, y, rr);
                        dg.addColorStop(0.0, Theme.alpha("#ffffff", 0.95));
                        dg.addColorStop(0.6, Theme.alpha("#ffffff", 0.5 + p * 0.35));
                        dg.addColorStop(1.0, "transparent");
                        ctx.fillStyle = dg;
                        ctx.fillRect(x - rr, y - rr, rr * 2, rr * 2);
                        ctx.fillStyle = Theme.alpha(root.warm, 0.9);
                        ctx.beginPath(); ctx.arc(x, y, 2, 0, Math.PI * 2); ctx.fill();
                    }
                }
                Component.onCompleted: requestPaint()
                Connections { target: Style; function onChanged() { gainLayer.repaint(); } }
            }
            Connections { target: root; function onPulseChanged() { gainLayer.repaint(); } }
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
