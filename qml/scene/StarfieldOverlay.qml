// Starlit scene overlay — soft twinkling stars, an occasional shooting star with
// a properly aligned trail on a clean diagonal path, and an album-tinted ringed
// planet. Floats over the dimmed cover backdrop. Gated on `animate`.
import QtQuick
import Vespera

Item {
    id: scene
    property color accent: "#6fe9ff"
    property color accentAlt: "#a78bfa"
    property color base: "#080c1a"
    property bool animate: true
    property real intensity: 1.0

    // canvas is sized to hold the whole sphere + ring so nothing clips at the edge
    readonly property real planetSize: Math.max(140, Math.min(width, height) * 0.30)

    // ---- twinkling stars ----
    Repeater {
        model: Math.round(72 * scene.intensity)
        delegate: Item {
            id: star
            required property int index
            property real px: Math.random()
            property real py: Math.random() * 0.9
            property real sz: Math.random() < 0.16 ? 2.6 : (Math.random() < 0.5 ? 1.6 : 1.1)
            property int dur: 1600 + Math.floor(Math.random() * 3000)
            x: px * scene.width
            y: py * scene.height
            width: sz; height: sz

            // soft halo on the brighter stars
            Rectangle {
                anchors.centerIn: parent
                visible: star.sz > 2
                width: star.sz * 4; height: width; radius: width / 2
                color: "#eaf2ff"
                opacity: 0.12
            }
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "#eaf2ff"
                opacity: 0.5
                SequentialAnimation on opacity {
                    running: scene.animate
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.95; duration: star.dur; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.2; duration: star.dur; easing.type: Easing.InOutSine }
                }
            }
        }
    }

    // ---- shooting star: a trail that always points back along its own path ----
    Item {
        id: shoot
        width: Math.max(120, scene.width * 0.12)
        height: 2
        rotation: 24
        transformOrigin: Item.Center
        opacity: 0
        readonly property real ang: 24 * Math.PI / 180
        property real span: scene.width * 0.34
        property real sx: 0
        property real sy: 0
        x: sx; y: sy

        Rectangle {
            anchors.fill: parent
            radius: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.75; color: Theme.alpha("#eaf2ff", 0.5) }
                GradientStop { position: 1.0; color: "#ffffff" }
            }
        }
        // bright head
        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 3; height: 3; radius: 1.5
            color: "#ffffff"
        }

        SequentialAnimation {
            running: scene.animate
            loops: Animation.Infinite
            PauseAnimation { duration: 4000 + Math.round(Math.random() * 7000) }
            ScriptAction {
                script: {
                    shoot.sx = scene.width * (0.05 + Math.random() * 0.35);
                    shoot.sy = scene.height * (0.04 + Math.random() * 0.28);
                    shoot.x = shoot.sx;
                    shoot.y = shoot.sy;
                }
            }
            ParallelAnimation {
                NumberAnimation { target: shoot; property: "x"
                                  to: shoot.sx + shoot.span * Math.cos(shoot.ang)
                                  duration: 780; easing.type: Easing.InOutSine }
                NumberAnimation { target: shoot; property: "y"
                                  to: shoot.sy + shoot.span * Math.sin(shoot.ang)
                                  duration: 780; easing.type: Easing.InOutSine }
                SequentialAnimation {
                    NumberAnimation { target: shoot; property: "opacity"; from: 0; to: 0.95; duration: 160 }
                    NumberAnimation { target: shoot; property: "opacity"; to: 0; duration: 420; easing.type: Easing.InQuad }
                }
            }
        }
    }

    // ---- ringed planet ----
    Canvas {
        id: planet
        width: scene.planetSize
        height: scene.planetSize
        anchors.right: parent.right
        anchors.top: parent.top
        // fully on-screen in the top-right (was pushed off the edge and clipped);
        // the sphere+ring both fit inside the canvas now, so nothing is cut off
        anchors.rightMargin: Math.max(24, scene.width * 0.04)
        anchors.topMargin: 56
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width, h = height, cx = w / 2, cy = h / 2, r = w * 0.30;
            const ringR = r * 1.5;

            // soft atmosphere glow
            const atm = ctx.createRadialGradient(cx, cy, r * 0.6, cx, cy, r * 1.35);
            atm.addColorStop(0.0, Theme.alpha(scene.accent, 0.22));
            atm.addColorStop(1.0, "transparent");
            ctx.fillStyle = atm;
            ctx.beginPath(); ctx.arc(cx, cy, r * 1.35, 0, Math.PI * 2); ctx.fill();

            // ring, back half
            ctx.save();
            ctx.translate(cx, cy); ctx.rotate(-22 * Math.PI / 180); ctx.scale(1, 0.3);
            ctx.beginPath(); ctx.arc(0, 0, ringR, Math.PI * 1.03, Math.PI * 1.97);
            ctx.lineWidth = r * 0.12; ctx.strokeStyle = Theme.alpha(scene.accent, 0.28); ctx.stroke();
            ctx.restore();

            // sphere
            const g = ctx.createRadialGradient(cx - r * 0.34, cy - r * 0.4, r * 0.08, cx, cy, r * 1.2);
            g.addColorStop(0.0, Qt.lighter(scene.accent, 1.3));
            g.addColorStop(0.5, scene.accent);
            g.addColorStop(1.0, Qt.darker(scene.base, 1.15));
            ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.fillStyle = g; ctx.fill();

            // ring, front half
            ctx.save();
            ctx.translate(cx, cy); ctx.rotate(-22 * Math.PI / 180); ctx.scale(1, 0.3);
            ctx.beginPath(); ctx.arc(0, 0, ringR, Math.PI * 0.03, Math.PI * 0.97);
            ctx.lineWidth = r * 0.12; ctx.strokeStyle = Theme.alpha(scene.accentAlt, 0.55); ctx.stroke();
            ctx.restore();
        }
        onWidthChanged: requestPaint()
        Connections {
            target: scene
            function onAccentChanged() { planet.requestPaint(); }
            function onAccentAltChanged() { planet.requestPaint(); }
            function onBaseChanged() { planet.requestPaint(); }
        }
        Component.onCompleted: requestPaint()
    }
}
