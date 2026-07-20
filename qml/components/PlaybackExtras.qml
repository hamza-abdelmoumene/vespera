// Secondary playback controls: shuffle · volume · repeat. Drawn geometric icons
// (no emoji), wired to the MPRIS Shuffle / Volume / LoopStatus properties.
import QtQuick
import Vespera

Row {
    id: root
    spacing: Theme.s5

    // ---- shuffle ----
    Item {
        width: 26; height: 26
        anchors.verticalCenter: parent.verticalCenter
        readonly property bool on: Player.shuffle
        Canvas {
            id: shuf
            anchors.centerIn: parent
            width: 18; height: 18
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.strokeStyle = parent.on ? Style.accent : Theme.alpha(Style.text, sMa.containsMouse ? 0.8 : 0.45);
                ctx.fillStyle = ctx.strokeStyle;
                ctx.lineWidth = 1.6; ctx.lineJoin = "round"; ctx.lineCap = "round";
                const w = width, h = height;
                // two crossing paths
                ctx.beginPath(); ctx.moveTo(1, 3); ctx.lineTo(6, 3); ctx.lineTo(w - 4, h - 3); ctx.lineTo(w - 1, h - 3); ctx.stroke();
                ctx.beginPath(); ctx.moveTo(1, h - 3); ctx.lineTo(6, h - 3); ctx.lineTo(w - 4, 3); ctx.lineTo(w - 1, 3); ctx.stroke();
                // arrowheads
                ctx.beginPath(); ctx.moveTo(w - 1, 3); ctx.lineTo(w - 4, 1); ctx.lineTo(w - 4, 5); ctx.closePath(); ctx.fill();
                ctx.beginPath(); ctx.moveTo(w - 1, h - 3); ctx.lineTo(w - 4, h - 5); ctx.lineTo(w - 4, h - 1); ctx.closePath(); ctx.fill();
            }
            Connections { target: Player; function onActiveChanged() { shuf.requestPaint(); } }
            Connections { target: Style; function onChanged() { shuf.requestPaint(); } }
        }
        MouseArea {
            id: sMa; anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: shuf.requestPaint()
            onClicked: Player.toggleShuffle()
        }
    }

    // ---- volume ----
    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.s2
        Canvas {
            id: spk
            width: 16; height: 16
            anchors.verticalCenter: parent.verticalCenter
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = Theme.alpha(Style.text, 0.6);
                ctx.strokeStyle = Theme.alpha(Style.text, 0.6);
                ctx.lineWidth = 1.4; ctx.lineCap = "round";
                // speaker body
                ctx.beginPath();
                ctx.moveTo(2, 6); ctx.lineTo(5, 6); ctx.lineTo(9, 3); ctx.lineTo(9, 13); ctx.lineTo(5, 10); ctx.lineTo(2, 10); ctx.closePath();
                ctx.fill();
                // waves scale with volume
                const v = Player.volume;
                if (v > 0.05) { ctx.beginPath(); ctx.arc(9, 8, 4, -0.9, 0.9); ctx.stroke(); }
                if (v > 0.55) { ctx.beginPath(); ctx.arc(9, 8, 6.5, -0.9, 0.9); ctx.stroke(); }
            }
            Connections { target: Player; function onActiveChanged() { spk.requestPaint(); } }
            Connections { target: Style; function onChanged() { spk.requestPaint(); } }
        }
        Item {
            width: 92; height: 24
            anchors.verticalCenter: parent.verticalCenter
            readonly property real v: Player.volume
            Rectangle {
                id: vtrack
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: 4; radius: 2
                color: Theme.alpha(Style.text, 0.16)
                Rectangle {
                    width: parent.width * parent.parent.v; height: parent.height; radius: 2
                    color: Style.accent
                }
                Rectangle {
                    width: 11; height: 11; radius: 6
                    color: Style.text
                    border.width: 1.5; border.color: Style.accent
                    y: (parent.height - height) / 2
                    x: Math.max(0, Math.min(parent.width - width, parent.width * parent.parent.v - width / 2))
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                function apply(mx) { Player.setVolume(Math.max(0, Math.min(1, mx / width))); }
                onPressed: (m) => apply(m.x)
                onPositionChanged: (m) => { if (pressed) apply(m.x); }
            }
        }
    }

    // ---- repeat ----
    Item {
        width: 26; height: 26
        anchors.verticalCenter: parent.verticalCenter
        readonly property string mode: Player.loopStatus   // None / Playlist / Track
        readonly property bool on: mode !== "None"
        Canvas {
            id: rep
            anchors.centerIn: parent
            width: 18; height: 18
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.strokeStyle = parent.on ? Style.accent : Theme.alpha(Style.text, rMa.containsMouse ? 0.8 : 0.45);
                ctx.fillStyle = ctx.strokeStyle;
                ctx.lineWidth = 1.6; ctx.lineJoin = "round"; ctx.lineCap = "round";
                const w = width, h = height;
                // rounded loop with an arrow
                ctx.beginPath();
                ctx.moveTo(5, 3); ctx.lineTo(w - 5, 3);
                ctx.arcTo(w - 1, 3, w - 1, 7, 4);
                ctx.lineTo(w - 1, 9);
                ctx.stroke();
                ctx.beginPath();
                ctx.moveTo(w - 5, h - 3); ctx.lineTo(5, h - 3);
                ctx.arcTo(1, h - 3, 1, h - 7, 4);
                ctx.lineTo(1, h - 9);
                ctx.stroke();
                // arrowheads
                ctx.beginPath(); ctx.moveTo(w - 1, 9); ctx.lineTo(w - 3, 5.5); ctx.lineTo(w + 1, 5.5); ctx.closePath(); ctx.fill();
                ctx.beginPath(); ctx.moveTo(1, h - 9); ctx.lineTo(-1, h - 5.5); ctx.lineTo(3, h - 5.5); ctx.closePath(); ctx.fill();
                // "1" for repeat-one
                if (parent.mode === "Track") {
                    ctx.fillStyle = parent.on ? Style.accent : Theme.alpha(Style.text, 0.6);
                    ctx.font = "bold 8px sans-serif";
                    ctx.textAlign = "center"; ctx.textBaseline = "middle";
                    ctx.fillText("1", w / 2, h / 2 + 0.5);
                }
            }
            Connections { target: Player; function onActiveChanged() { rep.requestPaint(); } }
            Connections { target: Style; function onChanged() { rep.requestPaint(); } }
        }
        MouseArea {
            id: rMa; anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: rep.requestPaint()
            onClicked: Player.cycleLoop()
        }
    }
}
