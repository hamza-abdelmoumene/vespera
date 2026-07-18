// 10-band equalizer with a lightning sweep signature on preset changes.
// Sliders drive EqService (which renders an EasyEffects preset live).
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Vespera

ColumnLayout {
    id: root
    spacing: Theme.s3

    // lightning sweep state
    property real sweep: 0      // 0..10, position of the bolt front
    property real fade: 1       // 1 = invisible, 0 = full

    function triggerLightning() {
        fade = 0;
        sweepAnim.restart();
        fadeAnim.restart();
    }
    NumberAnimation { id: sweepAnim; target: root; property: "sweep"; from: 0; to: 10; duration: 480; easing.type: Easing.OutQuad }
    SequentialAnimation {
        id: fadeAnim
        PauseAnimation { duration: 260 }
        NumberAnimation { target: root; property: "fade"; from: 0; to: 1; duration: 1100; easing.type: Easing.InQuad }
    }

    readonly property var labels: ["31", "63", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"]

    RowLayout {
        Layout.fillWidth: true
        Text {
            text: "Equalizer"
            color: Player.accentAlt
            font.pixelSize: Theme.fTitle
            font.weight: Font.DemiBold
            Layout.fillWidth: true
        }
        Text {
            text: Eq.preset
            color: Theme.alpha(Player.text, 0.6)
            font.pixelSize: Theme.fLabel
            font.weight: Font.DemiBold
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 176

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

                    property real dist: root.sweep - index
                    property real hit: dist >= 0 && dist < 1 ? Math.sin(dist * Math.PI) : 0

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
                                NumberAnimation { duration: 320; easing.type: Easing.OutQuart }
                            }
                            onPressedChanged: if (!pressed) Eq.setBand(cell.index + 1, Math.round(value))

                            background: Rectangle {
                                x: sld.leftPadding + (sld.availableWidth - width) / 2
                                y: sld.topPadding
                                width: 8
                                height: sld.availableHeight
                                radius: 4
                                color: Theme.alpha(Player.text, 0.10)

                                Rectangle {   // fill from the bottom
                                    width: parent.width
                                    height: (1 - sld.visualPosition) * parent.height
                                    y: sld.visualPosition * parent.height
                                    radius: 4
                                    gradient: Gradient {
                                        GradientStop { position: 0.0; color: Player.accentAlt }
                                        GradientStop { position: 1.0; color: Player.accent }
                                    }
                                }
                            }

                            handle: Rectangle {
                                x: sld.leftPadding + (sld.availableWidth - width) / 2
                                y: sld.topPadding + sld.visualPosition * (sld.availableHeight - height)
                                width: 16; height: 16; radius: 8
                                color: Player.text
                                scale: 1.0 + cell.hit * 0.4 * (1 - root.fade)
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.width + 26 * cell.hit
                                    height: width
                                    radius: width / 2
                                    color: Player.accent
                                    opacity: cell.hit * 0.5 * (1 - root.fade)
                                }
                            }
                        }
                        Text {
                            text: root.labels[cell.index]
                            color: Theme.alpha(Player.text, 0.45)
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }
        }

        // fluid lightning across the slider tops
        Canvas {
            id: bolt
            anchors.fill: parent
            z: 0
            opacity: 1 - root.fade
            renderTarget: Canvas.FramebufferObject
            Timer {
                interval: 16
                running: root.fade < 1 && root.sweep > 0
                repeat: true
                onTriggered: bolt.requestPaint()
            }
            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                if (root.sweep <= 0 || root.fade >= 1) return;
                const t = Date.now() / 1000;
                const maxIdx = root.sweep;
                ctx.lineJoin = "round";
                ctx.lineCap = "round";

                const pts = [];
                for (let i = 0; i < 10; i++) {
                    const val = Eq.band(i + 1);
                    const norm = 1.0 - ((val + 12) / 24);
                    pts.push({ x: (i + 0.5) * (width / 10), y: 8 + norm * (height - 30) });
                }

                for (let s = 0; s < 4; s++) {
                    ctx.beginPath();
                    ctx.moveTo(pts[0].x, pts[0].y);
                    for (let i = 0; i < pts.length - 1; i++) {
                        if (i > maxIdx) break;
                        const p1 = pts[i], p2 = pts[i + 1];
                        let fraction = maxIdx < i + 1 ? maxIdx - i : 1.0;
                        const steps = s === 3 ? 6 : 8;
                        for (let j = 1; j <= steps; j++) {
                            let tt = j / steps;
                            if (tt > fraction) tt = fraction;
                            const cx = p1.x + (p2.x - p1.x) * tt;
                            const cy = p1.y + (p2.y - p1.y) * tt;
                            const env = Math.sin(tt * Math.PI);
                            const ampX = s === 3 ? 1.0 : (4 - s) * 4;
                            const ampY = s === 3 ? 1.0 : (4 - s) * 5;
                            const nX = Math.sin(t * (10 + s) + i + j) * Math.cos(t * 8 - i + j) * ampX * env * (1 - root.fade);
                            const nY = Math.cos(t * (9 - s) + i - j) * Math.sin(t * 7 + i - j) * ampY * env * (1 - root.fade);
                            ctx.lineTo(cx + nX, cy + nY);
                            if (tt === fraction) break;
                        }
                    }
                    if (s === 0) { ctx.lineWidth = 18; ctx.strokeStyle = Player.accentAlt; ctx.globalAlpha = 0.18; }
                    else if (s === 1) { ctx.lineWidth = 8; ctx.strokeStyle = Player.accent; ctx.globalAlpha = 0.4; }
                    else if (s === 2) { ctx.lineWidth = 3.2; ctx.strokeStyle = Qt.lighter(Player.accent, 1.3); ctx.globalAlpha = 0.85; }
                    else { ctx.lineWidth = 1.0; ctx.strokeStyle = "#ffffff"; ctx.globalAlpha = 0.12; }
                    ctx.stroke();
                }
            }
        }
    }

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
                    onPicked: { root.triggerLightning(); Eq.applyPreset(name); }
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
                    onPicked: { root.triggerLightning(); Eq.applyPreset(name); }
                }
            }
        }
    }
}
