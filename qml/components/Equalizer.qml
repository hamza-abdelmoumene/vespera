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
    NumberAnimation { id: sweepAnim; target: root; property: "sweep"; from: 0; to: 10; duration: 640; easing.type: Easing.OutCubic }
    SequentialAnimation {
        id: fadeAnim
        PauseAnimation { duration: 300 }
        NumberAnimation { target: root; property: "fade"; from: 0; to: 1; duration: 820; easing.type: Easing.InOutQuad }
    }

    readonly property var labels: ["31", "63", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"]

    RowLayout {
        Layout.fillWidth: true
        Text {
            text: "Equalizer"
            color: Player.accentAlt
            font.pixelSize: Theme.fTitle
            font.weight: Font.DemiBold
            font.letterSpacing: Theme.trackLabel
            Layout.fillWidth: true
        }
        Text {
            text: Eq.preset
            color: Theme.alpha(Player.text, 0.6)
            font.pixelSize: Theme.fLabel
            font.weight: Font.DemiBold
            font.letterSpacing: Theme.trackCaps
            textFormat: Text.PlainText
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
                                width: sld.hovered || sld.pressed ? 9 : 8
                                height: sld.availableHeight
                                radius: width / 2
                                color: Theme.alpha(Player.text, sld.hovered || sld.pressed ? 0.14 : 0.10)
                                Behavior on width { NumberAnimation { duration: Theme.durFast } }
                                Behavior on color { ColorAnimation { duration: Theme.durFast } }

                                Rectangle {   // fill from the bottom
                                    id: fill
                                    width: parent.width
                                    height: (1 - sld.visualPosition) * parent.height
                                    y: sld.visualPosition * parent.height
                                    radius: parent.radius
                                    gradient: Gradient {
                                        GradientStop { position: 0.0; color: Player.accentAlt }
                                        GradientStop { position: 1.0; color: Player.accent }
                                    }
                                    // bright cap at the fill's "water line"
                                    Rectangle {
                                        anchors { left: parent.left; right: parent.right; top: parent.top }
                                        height: 2
                                        radius: 1
                                        color: Qt.lighter(Player.accentAlt, 1.3)
                                        opacity: 0.9
                                        visible: fill.height > 3
                                    }
                                }
                            }

                            handle: Item {
                                id: hnd
                                x: sld.leftPadding + (sld.availableWidth - width) / 2
                                y: sld.topPadding + sld.visualPosition * (sld.availableHeight - height)
                                width: 16; height: 16
                                // combined "energy": hover, press, and the sweep hit
                                readonly property real energy: sld.pressed ? 1.0 : sld.hovered ? 0.55 : 0.0
                                readonly property real glow:
                                    Math.min(1.15, hnd.energy + cell.hit * (1 - root.fade))

                                Rectangle {   // soft accent glow (drawn behind the core)
                                    anchors.centerIn: parent
                                    width: 16 + 11 + 26 * hnd.glow
                                    height: width
                                    radius: width / 2
                                    color: Player.accent
                                    opacity: 0.10 + 0.42 * Math.min(1, hnd.glow)
                                    Behavior on width { NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutCubic } }
                                    Behavior on opacity { NumberAnimation { duration: Theme.durMed } }
                                }
                                Rectangle {   // handle core
                                    anchors.centerIn: parent
                                    width: 16; height: 16; radius: 8
                                    color: Player.text
                                    scale: 1.0 + hnd.energy * 0.16 + cell.hit * 0.4 * (1 - root.fade)
                                    Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutBack } }
                                    Rectangle {   // accent pip appears while active
                                        anchors.centerIn: parent
                                        width: parent.width * 0.4; height: width; radius: width / 2
                                        color: Player.accent
                                        opacity: hnd.energy * 0.9
                                        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                                    }
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
                const upto = root.sweep;        // 0..10, revealed front of the sweep
                const life = 1 - root.fade;     // overall intensity, 1 → 0
                ctx.lineJoin = "round";
                ctx.lineCap = "round";

                // slider value points, with a whisper of shimmer so the arc breathes
                const pts = [];
                for (let i = 0; i < 10; i++) {
                    const val = Eq.band(i + 1);
                    const norm = 1.0 - ((val + 12) / 24);
                    const shimmer = Math.sin(t * 6 + i * 1.3) * 1.1 * life;
                    pts.push({ x: (i + 0.5) * (width / 10), y: 8 + norm * (height - 30) + shimmer });
                }

                // reveal a smooth polyline up to the (fractional) sweep front
                const rev = [];
                const fi = Math.floor(upto);
                for (let i = 0; i <= fi && i < pts.length; i++) rev.push(pts[i]);
                if (fi < pts.length - 1) {
                    const f = upto - fi;
                    if (f > 0) {
                        const a = pts[fi], b = pts[fi + 1];
                        rev.push({ x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f });
                    }
                }

                function tracePath() {
                    ctx.beginPath();
                    ctx.moveTo(rev[0].x, rev[0].y);
                    for (let i = 1; i < rev.length - 1; i++) {
                        const mx = (rev[i].x + rev[i + 1].x) / 2;
                        const my = (rev[i].y + rev[i + 1].y) / 2;
                        ctx.quadraticCurveTo(rev[i].x, rev[i].y, mx, my);
                    }
                    ctx.lineTo(rev[rev.length - 1].x, rev[rev.length - 1].y);
                    ctx.stroke();
                }

                if (rev.length >= 2) {
                    ctx.lineWidth = 12;  ctx.strokeStyle = Player.accent;                 ctx.globalAlpha = 0.14 * life; tracePath();
                    ctx.lineWidth = 4.5; ctx.strokeStyle = Player.accentAlt;              ctx.globalAlpha = 0.50 * life; tracePath();
                    ctx.lineWidth = 1.6; ctx.strokeStyle = Qt.lighter(Player.accent, 1.5); ctx.globalAlpha = 0.95 * life; tracePath();
                }

                // leading comet spark at the sweep front
                const front = rev.length ? rev[rev.length - 1] : pts[0];
                const sparkR = 6.5 + 2.5 * Math.sin(t * 22);
                const sg = ctx.createRadialGradient(front.x, front.y, 0, front.x, front.y, sparkR * 2.4);
                sg.addColorStop(0.0, Theme.alpha(Qt.lighter(Player.accent, 1.6), 0.9 * life));
                sg.addColorStop(0.4, Theme.alpha(Player.accent, 0.5 * life));
                sg.addColorStop(1.0, "transparent");
                ctx.globalAlpha = 1.0;
                ctx.fillStyle = sg;
                ctx.beginPath();
                ctx.arc(front.x, front.y, sparkR * 2.4, 0, Math.PI * 2);
                ctx.fill();
                ctx.fillStyle = Theme.alpha("#ffffff", 0.85 * life);
                ctx.beginPath();
                ctx.arc(front.x, front.y, 1.8, 0, Math.PI * 2);
                ctx.fill();
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
