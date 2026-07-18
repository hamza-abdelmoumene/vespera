// Observatory backdrop — a deep-space wash, twinkling stars, an occasional
// shooting star, and an album-tinted ringed planet. Animation is gated: when
// `animate` is false the scene is fully still (for hidden windows / low power).
import QtQuick
import Vespera

Item {
    id: scene
    clip: true

    property color base: "#080c1a"
    property color accent: "#6fe9ff"
    property color accentAlt: "#a78bfa"
    property bool animate: true

    readonly property real planetSize: Math.max(110, Math.min(width, height) * 0.23)

    // base ground — recoloured centrally (C++ cross-fade), no local Behavior
    Rectangle {
        anchors.fill: parent
        color: scene.base
    }

    // top glow wash
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Theme.alpha(scene.accentAlt, 0.18) }
            GradientStop { position: 0.45; color: Theme.alpha(scene.accent, 0.05) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // Album-tinted ambient wash — a soft radial bloom low-left, behind the
    // player, plus a smaller mauve bloom up by the cover. It reads the live
    // palette so it cross-fades with every track; a slow, gated breathe keeps
    // it feeling alive without any per-frame repaint (pure GPU compositing).
    Item {
        id: aura
        anchors.fill: parent
        z: 0
        SequentialAnimation on opacity {
            running: scene.animate
            loops: Animation.Infinite
            NumberAnimation { to: 1.0; duration: 5200; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.72; duration: 5200; easing.type: Easing.InOutSine }
        }

        Canvas {
            id: bloom
            anchors.fill: parent
            renderTarget: Canvas.FramebufferObject
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const w = width, h = height;

                function radial(cx, cy, r, col, a) {
                    const g = ctx.createRadialGradient(cx, cy, 0, cx, cy, r);
                    g.addColorStop(0.0, Theme.alpha(col, a));
                    g.addColorStop(0.55, Theme.alpha(col, a * 0.35));
                    g.addColorStop(1.0, "transparent");
                    ctx.fillStyle = g;
                    ctx.fillRect(0, 0, w, h);
                }
                // primary accent bloom behind the now-playing area
                radial(w * 0.30, h * 0.60, Math.max(w, h) * 0.62, scene.accent, 0.16);
                // secondary mauve bloom near the cover / upper left
                radial(w * 0.16, h * 0.24, Math.min(w, h) * 0.85, scene.accentAlt, 0.10);
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Connections {
                target: scene
                function onAccentChanged() { bloom.requestPaint(); }
                function onAccentAltChanged() { bloom.requestPaint(); }
            }
            Component.onCompleted: requestPaint()
        }
    }

    // starfield
    Repeater {
        model: 64
        delegate: Rectangle {
            property real px: Math.random()
            property real py: Math.random() * 0.85
            property int baseDur: 1400 + Math.floor(Math.random() * 2600)
            width: Math.random() < 0.18 ? 2.4 : 1.4
            height: width
            radius: width / 2
            x: px * scene.width
            y: py * scene.height
            color: "#eaf2ff"
            opacity: 0.45
            SequentialAnimation on opacity {
                running: scene.animate
                loops: Animation.Infinite
                NumberAnimation { to: 0.9; duration: baseDur; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.18; duration: baseDur; easing.type: Easing.InOutSine }
            }
        }
    }

    // shooting star
    Rectangle {
        id: meteor
        width: 92
        height: 2
        radius: 2
        transformOrigin: Item.Center
        rotation: 20
        opacity: 0
        property real sx: scene.width * 0.16
        property real sy: scene.height * 0.22
        x: sx
        y: sy
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: "#eaf2ff" }
        }
        SequentialAnimation {
            running: scene.animate
            loops: Animation.Infinite
            PauseAnimation { duration: 5200 }
            ScriptAction {
                script: {
                    meteor.sx = scene.width * (0.10 + Math.random() * 0.5);
                    meteor.sy = scene.height * (0.06 + Math.random() * 0.30);
                    meteor.x = meteor.sx;
                    meteor.y = meteor.sy;
                }
            }
            ParallelAnimation {
                NumberAnimation { target: meteor; property: "opacity"; from: 0; to: 0.9; duration: 130 }
                NumberAnimation { target: meteor; property: "x"; to: meteor.sx + 190; duration: 720; easing.type: Easing.InQuad }
                NumberAnimation { target: meteor; property: "y"; to: meteor.sy + 64; duration: 720; easing.type: Easing.InQuad }
            }
            NumberAnimation { target: meteor; property: "opacity"; to: 0; duration: 200 }
        }
    }

    // ringed planet, half off the top-right corner
    Canvas {
        id: planet
        width: scene.planetSize
        height: scene.planetSize
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: -width * 0.30
        anchors.topMargin: -height * 0.42
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width, h = height, cx = w / 2, cy = h / 2, r = w * 0.40;
            const ringR = r * 1.9;

            // ring, back half (behind the sphere)
            ctx.save();
            ctx.translate(cx, cy);
            ctx.rotate(-24 * Math.PI / 180);
            ctx.scale(1, 0.32);
            ctx.beginPath();
            ctx.arc(0, 0, ringR, Math.PI * 1.03, Math.PI * 1.97);
            ctx.lineWidth = r * 0.13;
            ctx.strokeStyle = Theme.alpha(scene.accent, 0.30);
            ctx.stroke();
            ctx.restore();

            // sphere with an offset radial highlight
            const g = ctx.createRadialGradient(cx - r * 0.34, cy - r * 0.4, r * 0.08, cx, cy, r * 1.2);
            g.addColorStop(0.0, Qt.lighter(scene.accent, 1.3));
            g.addColorStop(0.5, scene.accent);
            g.addColorStop(1.0, Qt.darker(scene.base, 1.15));
            ctx.beginPath();
            ctx.arc(cx, cy, r, 0, Math.PI * 2);
            ctx.fillStyle = g;
            ctx.fill();

            // ring, front half (over the sphere) — brighter for depth
            ctx.save();
            ctx.translate(cx, cy);
            ctx.rotate(-24 * Math.PI / 180);
            ctx.scale(1, 0.32);
            ctx.beginPath();
            ctx.arc(0, 0, ringR, Math.PI * 0.03, Math.PI * 0.97);
            ctx.lineWidth = r * 0.13;
            ctx.strokeStyle = Theme.alpha(scene.accentAlt, 0.55);
            ctx.stroke();
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
