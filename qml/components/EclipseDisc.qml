// THE SIGNATURE — the Eclipse. The album cover as a huge vinyl record sliding
// off the window's edge, with the live cava spectrum wrapped along its visible
// rim as an arc of light. The record turns slowly while playing (artwork is
// circular-cropped in C++ so it clips cleanly on any backend); the grooves,
// gloss and atmosphere stay fixed above it; the arc pulses to the audio and
// settles to a calm resting halo when paused. Positioning (how far off-screen
// it hangs) is the parent's job — this item is the square disc + its arc.
import QtQuick
import Vespera

Item {
    id: root

    // where the spectrum arc lives on the rim, as an angle from +x (radians,
    // y-down): 0 = facing right (expanded, disc off the left edge),
    // Math.PI / 2 = facing down (compact, disc off the top edge).
    property real arcCenter: 0
    property real arcSpan: 2.56

    property bool playing: Player.playing
    property var bars: Cava.bars
    readonly property int barCount: Cava.barCount

    readonly property real d: Math.min(width, height)
    readonly property real discD: d * 0.82   // artwork diameter; the arc owns the margin

    // ---- atmosphere — a soft accent glow hugging the rim (repaints on theme/
    // track recolour only, never per audio frame) ----
    Canvas {
        id: atmo
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const c = width / 2;
            const r = root.discD / 2;
            const gs = Style.glowStrength;
            // a tight rim halo hugging the artwork so the disc reads as the light
            // SOURCE — the broad bloom into the room is DiscGlow, behind this. Kept
            // restrained (and on the master glow knob) so it never over-glows.
            const g = ctx.createRadialGradient(c, c, r * 0.9, c, c, r * 1.2);
            g.addColorStop(0.0, "transparent");
            g.addColorStop(0.32, Theme.alpha(Style.accent, 0.22 * gs));
            g.addColorStop(0.62, Theme.alpha(Theme.mix(Style.accent, Style.accentAlt, 0.4), 0.10 * gs));
            g.addColorStop(1.0, "transparent");
            ctx.fillStyle = g;
            ctx.fillRect(0, 0, width, height);
        }
        onWidthChanged: requestPaint()
        Connections { target: Style; function onChanged() { atmo.requestPaint(); } }
        Component.onCompleted: requestPaint()
    }

    // ---- the spinning artwork ----
    Item {
        id: disc
        width: root.discD
        height: root.discD
        anchors.centerIn: parent

        RotationAnimator on rotation {
            from: 0; to: 360; duration: 42000 / Style.discSpin
            loops: Animation.Infinite
            running: root.playing && root.visible && !Style.reduceMotion
        }

        Image {
            id: art
            anchors.fill: parent
            source: Cover.discBase   // circular-cropped cover
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: false
            smooth: true
            visible: status === Image.Ready
        }
        // placeholder disc when there's no art
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            visible: art.status !== Image.Ready
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.lighter(Style.base, 1.5) }
                GradientStop { position: 1.0; color: Qt.darker(Style.base, 1.2) }
            }
        }
    }

    // ---- fixed vinyl furniture (does not spin) ----
    Item {
        anchors.centerIn: parent
        width: root.discD
        height: root.discD

        // concentric grooves + fixed top-left gloss
        Canvas {
            id: furniture
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const c = width / 2;
                ctx.strokeStyle = Qt.rgba(0, 0, 0, 0.12);
                ctx.lineWidth = 1;
                for (let r = c * 0.34; r < c * 0.97; r += Math.max(3, c * 0.042)) {
                    ctx.beginPath(); ctx.arc(c, c, r, 0, Math.PI * 2); ctx.stroke();
                }
                const g = ctx.createLinearGradient(0, 0, width * 0.7, height);
                g.addColorStop(0.0, Qt.rgba(1, 1, 1, 0.1));
                g.addColorStop(0.42, "transparent");
                ctx.save();
                ctx.beginPath(); ctx.arc(c, c, c, 0, Math.PI * 2); ctx.clip();
                ctx.fillStyle = g; ctx.fillRect(0, 0, width, height);
                ctx.restore();
            }
            onWidthChanged: requestPaint()
            Connections { target: Style; function onChanged() { furniture.requestPaint(); } }
            Component.onCompleted: requestPaint()
        }

        // bezel
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: Theme.alpha(Style.line, 0.25)
        }

        // label hole
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.085; height: width; radius: width / 2
            color: Qt.darker(Style.base, 1.3)
            border.width: 1
            border.color: Theme.alpha(Style.line, 0.3)
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.3; height: width; radius: width / 2
                color: Theme.alpha(Style.accent, 0.9)
            }
        }
    }

    // ---- the rim-arc spectrum ----
    Canvas {
        id: ring
        anchors.fill: parent
        renderTarget: Canvas.FramebufferObject
        property bool playing: root.playing
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const cx = width / 2, cy = height / 2;
            const r0 = root.discD / 2 + root.d * 0.012;
            const maxLen = (root.d - root.discD) / 2 - root.d * 0.018;
            const n = 34;
            const a0 = root.arcCenter - root.arcSpan / 2;
            ctx.lineCap = "round";
            ctx.lineWidth = Math.max(2, root.d * 0.007);
            for (let i = 0; i < n; i++) {
                const f = i / (n - 1);
                // sample the cava bars across the arc
                const bi = Math.round(f * (root.barCount - 1));
                const raw = root.playing ? (root.bars[bi] || 0) : 0;
                const rest = 9 + 6 * Math.sin(i * 0.8);  // calm resting halo
                const val = Math.max(raw, rest);
                const len = (val / 100) * maxLen + root.d * 0.008;
                const ang = a0 + f * root.arcSpan;
                const ca = Math.cos(ang), sa = Math.sin(ang);
                const col = f < 0.5 ? Style.accent : Style.accentAlt;
                ctx.strokeStyle = Theme.alpha(col, 0.45 + 0.45 * (val / 100));
                ctx.beginPath();
                ctx.moveTo(cx + ca * r0, cy + sa * r0);
                ctx.lineTo(cx + ca * (r0 + len), cy + sa * (r0 + len));
                ctx.stroke();
            }
        }
        Connections {
            target: Cava
            enabled: ring.playing && root.visible
            function onBarsChanged() { ring.requestPaint(); }
        }
        Connections { target: Style; function onChanged() { ring.requestPaint(); } }
        onPlayingChanged: requestPaint()
        Component.onCompleted: requestPaint()
    }
}
