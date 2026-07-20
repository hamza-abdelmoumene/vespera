// The album cover as the whole backdrop: heavily blurred (in C++, so it renders
// on every backend — GPU or software — and in offscreen capture), colour-graded
// and grained per theme, at a low transparency so it reads as atmosphere. Every
// theme sits on this layer; scene overlays float above it. All look parameters
// come from Style, so the backdrop cross-fades with both the track and the theme.
import QtQuick
import Vespera

Item {
    id: root
    property url source  // kept for API symmetry; the blurred source comes from Cover
    clip: true

    // deep ground — the cover fades into this at the edges / low opacity
    Rectangle {
        anchors.fill: parent
        color: Style.base
    }

    // the C++-blurred cover (a small smoothed image the GPU upscales into a soft
    // field). Re-fetched when the track's art changes (rev in Cover.blurBase) or
    // the blur amount changes (Style.coverBlur).
    // The blurred cover is a tiny C++-rendered image, so a synchronous load is
    // instant and avoids the blank flash you'd get async on every track change.
    Image {
        id: blurred
        anchors.fill: parent
        source: Cover.blurBase + "/" + Math.round(Style.coverBlur)
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        cache: true
        smooth: true
        visible: status === Image.Ready
        opacity: Style.coverOpacity
        Behavior on opacity { NumberAnimation { duration: Theme.durSlow; easing.type: Easing.InOutQuad } }
    }

    // colour grade — a single tint that pulls the cover into the theme's mood.
    Rectangle {
        anchors.fill: parent
        color: Style.gradeColor
        opacity: Style.gradeStrength
    }

    // vignette — radial edge darkening for depth (painted on change only)
    Canvas {
        id: vig
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width, h = height;
            const g = ctx.createRadialGradient(w / 2, h / 2, Math.min(w, h) * 0.28,
                                               w / 2, h / 2, Math.max(w, h) * 0.72);
            g.addColorStop(0.0, "transparent");
            g.addColorStop(1.0, Qt.rgba(0, 0, 0, Style.vignette));
            ctx.fillStyle = g;
            ctx.fillRect(0, 0, w, h);
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: Style
            function onChanged() { vig.requestPaint(); }
        }
    }

    // fine film grain, tiled, at a per-theme intensity
    Image {
        anchors.fill: parent
        source: "image://vespera/grain"
        fillMode: Image.Tile
        opacity: Style.grain
        cache: true
        smooth: false
    }
}
