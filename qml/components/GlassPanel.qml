// A frosted-glass panel — REAL glass. The panel samples the backdrop directly
// behind itself (ShaderEffectSource on the window's glassSourceItem), blurs and
// resaturates it (MultiEffect), and clips the result to its rounded rect. A
// near-white frost gradient, a crisp specular top edge, and a barely-there
// hairline sit on top — the refracted cover light does the rest.
//
// The GPU path is gated: offscreen capture (glassAvailable=false), the software
// render backend, and VESPERA_NO_GLASS all fall back to the C++-frost look —
// the same gradient fill this component used before the glass pass — so the
// panel degrades gracefully instead of rendering nothing.
// All tokens come from Style, so panels recolour with track + theme.
import QtQuick
import QtQuick.Effects
import Vespera

Item {
    id: root
    property real radius: Style.radius
    property real fillOpacity: Style.glassOpacity
    property color tint: Style.surface
    property bool sheen: true
    default property alias content: inner.data

    // the item the glass refracts (set by Main.qml on the window)
    readonly property Item backdropItem: Window.window
        ? (Window.window.glassSourceItem !== undefined ? Window.window.glassSourceItem : null)
        : null
    readonly property bool live: (typeof glassAvailable === "undefined" || glassAvailable)
                                 && GraphicsInfo.api !== GraphicsInfo.Software
                                 && backdropItem !== null

    // ---- elevation — the panel floats above the backdrop instead of sitting
    // flush on it. Two soft, low-alpha layers offset downward approximate a
    // blurred drop shadow without another effect pass (same trick as the seek
    // bar's playhead glow). z:-1/-2 keeps them strictly behind the fill.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 7; width: parent.width * 0.94; height: parent.height
        radius: root.radius; color: Theme.alpha("#000000", 0.10); z: -2
    }
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 3; width: parent.width * 0.985; height: parent.height
        radius: root.radius; color: Theme.alpha("#000000", 0.16); z: -1
    }

    // ---- real glass: backdrop blur, masked to the rounded rect ----
    Loader {
        anchors.fill: parent
        active: root.live
        sourceComponent: Component {
            Item {
                // the rect behind the panel, in backdrop coordinates. Depends on
                // the panel's own geometry AND the window's (layout reflow), so
                // it re-evaluates whenever either moves.
                readonly property rect behind: {
                    void(root.x + root.y + root.width + root.height);
                    const w = Window.window;
                    void(w ? w.width + w.height : 0);
                    const p = root.mapToItem(root.backdropItem, 0, 0);
                    return Qt.rect(p.x, p.y, Math.max(1, root.width), Math.max(1, root.height));
                }

                ShaderEffectSource {
                    id: src
                    sourceItem: root.backdropItem
                    sourceRect: parent.behind
                    // half-res sampling: cheaper, and the extra softness feeds the blur
                    textureSize: Qt.size(Math.max(1, Math.ceil(root.width / 2)),
                                         Math.max(1, Math.ceil(root.height / 2)))
                    live: true
                    visible: false
                }
                Rectangle {
                    id: maskShape
                    anchors.fill: parent
                    radius: root.radius
                    color: "black"
                    visible: false
                    layer.enabled: true
                    layer.smooth: true
                }
                MultiEffect {
                    anchors.fill: parent
                    source: src
                    autoPaddingEnabled: false
                    blurEnabled: true
                    blurMax: 64
                    blur: 0.86          // glassier — heavier frost so the orbs melt behind
                    saturation: 0.55    // keep the refracted orb colour alive through the frost
                    maskEnabled: true
                    maskSource: maskShape
                }
            }
        }
    }

    // ---- frost fill ----
    // live: a near-white veil so the panel reads as lit glass over the blur.
    // fallback: the previous C++-frost gradient (surface-tinted, more opaque)
    // so software/offscreen renders still look composed.
    readonly property color frost: Theme.mix(tint, "#ffffff", root.live ? 0.85 : 0.32)
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: root.live ? Theme.alpha(root.frost, Math.min(0.36, root.fillOpacity * 0.62))
                                 : Qt.rgba(root.frost.r, root.frost.g, root.frost.b,
                                           Math.min(0.85, root.fillOpacity * 1.3))
            }
            GradientStop {
                position: 0.55
                color: root.live ? Theme.alpha(root.frost, root.fillOpacity * 0.32)
                                 : Qt.rgba(root.tint.r, root.tint.g, root.tint.b, root.fillOpacity * 0.85)
            }
            GradientStop {
                position: 1.0
                color: root.live ? Theme.alpha(root.frost, root.fillOpacity * 0.22)
                                 : Qt.rgba(root.tint.r, root.tint.g, root.tint.b, root.fillOpacity * 0.72)
            }
        }
        // barely-there edge — seamless glass, no hard border
        border.width: 1
        border.color: Theme.alpha("#ffffff", Math.min(0.14, Style.glassBorder * 0.6))
    }

    // a whisper of diagonal light across the pane — the material tell that
    // separates glass from a flat fill (live path only; the fallback stays flat)
    Rectangle {
        visible: root.live
        anchors.fill: parent
        radius: root.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.alpha("#ffffff", 0.05) }
            GradientStop { position: 0.32; color: "transparent" }
            GradientStop { position: 0.78; color: "transparent" }
            GradientStop { position: 1.0; color: Theme.alpha("#ffffff", 0.025) }
        }
    }

    // specular top edge — the single crisp glass tell
    Rectangle {
        visible: root.sheen
        anchors { left: parent.left; right: parent.right; top: parent.top }
        anchors.leftMargin: root.radius
        anchors.rightMargin: root.radius
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: Theme.alpha("#ffffff", Math.min(0.6, Style.glassBorder * 2.6)) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // soft inner shadow hugging the bottom edge — reads as the glass's own
    // thickness, pairing with the bright top specular for real depth
    Rectangle {
        visible: root.live
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        anchors.leftMargin: root.radius
        anchors.rightMargin: root.radius
        height: Math.min(18, root.height * 0.3)
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: Theme.alpha("#000000", 0.10) }
        }
    }

    Item {
        id: inner
        anchors.fill: parent
    }
}
