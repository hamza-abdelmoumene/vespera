// Synced lyrics in a glass panel — centred current line, click-to-seek,
// ±0.25s per-track offset, resync.
//
// Scrolling: the list follows the song automatically, smoothly centring the
// current line (ApplyRange + highlightMoveDuration). The moment you scroll by
// hand, auto-follow yields — your position sticks — and a "Resume" affordance
// appears. After a few idle seconds (or a tap on Resume) it eases the current
// line back to centre and resumes following.
import QtQuick
import Vespera
import "../blockfont.js" as BlockFont

GlassPanel {
    id: root

    // Two ways to read along: the scrolling synced LIST (click-to-seek, offset)
    // and a big ASCII BLOCK-LETTER karaoke view — the current line drawn in chunky
    // █-glyphs, the way the owner's terminal tool "lyricsooo" does it. The choice
    // is a shared, persisted setting (Style) so both this pane's header toggle and
    // the settings menu drive the same state.
    readonly property bool blockMode: Style.lyricsBlockMode

    // interpolated playback position (poll cadence is coarse; advance locally)
    property real estPos: Player.position
    property double _t0: Date.now()
    function pushFollow() { if (list.following) list.currentIndex = Lyrics.indexForTime(root.estPos); }
    Connections {
        target: Player
        function onPositionChanged() { root.estPos = Player.position; root._t0 = Date.now(); root.pushFollow(); }
    }
    Timer {
        interval: 120
        running: Player.playing && root.visible && Lyrics.hasLyrics
        repeat: true
        onTriggered: { root.estPos = Player.position + (Date.now() - root._t0) / 1000; root.pushFollow(); }
    }

    Column {
        anchors.fill: parent
        anchors.margins: Theme.s4
        spacing: Theme.s3

        // header
        Item {
            width: parent.width
            height: 26
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.s2
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 7; height: 7; radius: 2; rotation: 45
                    color: Style.accent
                }
                Text {
                    text: "Lyrics"
                    color: Style.accent
                    font.family: Style.displayFamily
                    font.pixelSize: Theme.fTitle
                    font.weight: Font.DemiBold
                    font.letterSpacing: Theme.trackLabel
                }
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.s1

                // mode toggle: big block-letters <-> synced list. The 2x2 "blocks"
                // glyph fills with the accent when block mode is on.
                Rectangle {
                    id: modeToggle
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26; height: 22; radius: Theme.rSm
                    color: root.blockMode ? Theme.alpha(Style.accent, 0.9)
                                          : (modeMa.containsMouse ? Theme.alpha(Style.text, 0.14)
                                                                  : Theme.alpha(Style.text, 0.06))
                    border.width: 1
                    border.color: root.blockMode ? "transparent" : Theme.alpha(Style.text, 0.18)
                    visible: Lyrics.hasLyrics
                    Grid {
                        anchors.centerIn: parent
                        columns: 2
                        rowSpacing: 2
                        columnSpacing: 2
                        Repeater {
                            model: 4
                            Rectangle {
                                width: 5; height: 5; radius: 1
                                color: root.blockMode ? Style.base : Theme.alpha(Style.text, 0.7)
                            }
                        }
                    }
                    MouseArea {
                        id: modeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Style.lyricsBlockMode = !Style.lyricsBlockMode
                    }
                    Behavior on color { ColorAnimation { duration: Theme.durFast } }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    readonly property bool hasOffset: Math.abs(Lyrics.offset) > 0.01
                    text: Lyrics.loading ? "syncing…"
                        : hasOffset ? ((Lyrics.offset > 0 ? "+" : "") + Lyrics.offset.toFixed(2) + "s")
                        : (Lyrics.hasLyrics ? "synced" : "")
                    color: hasOffset && !Lyrics.loading ? "#e8c07d" : Theme.alpha(Style.text, 0.45)
                    font.family: Style.monoFamily
                    font.pixelSize: Theme.fCaption
                    font.letterSpacing: 1
                    rightPadding: Theme.s2
                    MouseArea {
                        anchors.fill: parent
                        enabled: parent.hasOffset && !Lyrics.loading
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: Lyrics.offset = 0
                    }
                }
                IconButton { kind: "minus"; enabled: Lyrics.hasLyrics; onTapped: Lyrics.nudgeOffset(-0.25) }
                IconButton { kind: "plus"; enabled: Lyrics.hasLyrics; onTapped: Lyrics.nudgeOffset(0.25) }
                IconButton { kind: "resync"; spinning: Lyrics.loading; onTapped: Lyrics.refresh() }
            }
        }

        // list / empty states
        Item {
            width: parent.width
            height: parent.height - 26 - Theme.s3

            ListView {
                id: list
                anchors.fill: parent
                visible: Lyrics.hasLyrics && !root.blockMode
                model: Lyrics.lyrics
                spacing: Theme.s3
                clip: true
                interactive: true
                boundsBehavior: Flickable.StopAtBounds
                flickDeceleration: 3500

                // auto-follow lever: while following, currentIndex tracks the song
                // and ApplyRange keeps it centred; hand-scrolling freezes it.
                // `moving` is set only by user gestures (drag / flick / wheel), not
                // by the programmatic ApplyRange recentre, so it's the clean signal
                // that the listener took over.
                property bool following: true
                function refollow() {
                    following = true;
                    currentIndex = Lyrics.indexForTime(root.estPos);
                }
                function userTook() { following = false; idle.restart(); }
                Timer { id: idle; interval: 3400; onTriggered: list.refollow() }

                onMovingChanged: if (moving) userTook()

                onModelChanged: Qt.callLater(() => { refollow(); positionViewAtIndex(currentIndex, ListView.Center); })

                // capture-only: enter the hand-scrolled state so the Resume
                // affordance + take-over can be screenshotted.
                Timer {
                    running: captureScrolled
                    interval: 250
                    onTriggered: {
                        list.userTook();
                        list.contentY = Math.min(Math.max(0, list.contentHeight - list.height),
                                                 list.contentY + 150);
                    }
                }
                highlightRangeMode: ListView.ApplyRange
                highlightMoveDuration: 380
                preferredHighlightBegin: (height - (currentItem ? currentItem.implicitHeight : 0)) / 2
                preferredHighlightEnd: (height + (currentItem ? currentItem.implicitHeight : 0)) / 2

                delegate: Text {
                    id: line
                    required property string modelData
                    required property int index
                    width: list.width
                    text: modelData !== "" ? modelData : "· · ·"
                    textFormat: Text.PlainText
                    horizontalAlignment: Text.AlignLeft
                    color: ListView.isCurrentItem ? Style.text
                         : lineMa.containsMouse ? Theme.alpha(Style.text, 0.75)
                         : Theme.alpha(Style.text, 0.34)
                    font.pixelSize: ListView.isCurrentItem ? 18 : 14
                    font.weight: ListView.isCurrentItem ? Font.DemiBold : Font.Normal
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    Behavior on color { ColorAnimation { duration: 300 } }

                    MouseArea {
                        id: lineMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const t = Lyrics.timeForIndex(line.index);
                            if (t >= 0 && Player.canSeek) Player.seekTo(t);
                        }
                    }
                }
            }

            // ---- big ASCII block-letter karaoke view ----
            // The current lyric line rendered as chunky █-glyphs (BlockFont), sized
            // to fill the pane via Text.Fit, in the album accent; the next line sits
            // small and dim beneath for a beat of lead-in. Synced off the same
            // interpolated position as the list.
            Item {
                id: blockView
                anchors.fill: parent
                visible: Lyrics.hasLyrics && root.blockMode

                readonly property int curIdx: Lyrics.hasLyrics ? Lyrics.indexForTime(root.estPos) : -1
                readonly property string curText:
                    (curIdx >= 0 && curIdx < Lyrics.lyrics.length) ? Lyrics.lyrics[curIdx] : ""
                readonly property string nextText:
                    (curIdx + 1 >= 0 && curIdx + 1 < Lyrics.lyrics.length) ? Lyrics.lyrics[curIdx + 1] : ""
                // narrower column budget => the line wraps to more stacked rows =>
                // bigger letters filling this tall pane. Clamped so wide panes still
                // break long lines instead of shrinking them to nothing.
                readonly property int cols: Math.max(13, Math.min(48, Math.round(width / 11)))

                // the block grid, painted cell-by-cell so every letter is crisp
                Canvas {
                    id: blockCanvas
                    anchors.fill: parent
                    anchors.bottomMargin: nextLine.visible ? nextLine.height + Theme.s4 : 0
                    renderTarget: Canvas.FramebufferObject

                    property var lines: blockView.curText !== ""
                                        ? BlockFont.grid(blockView.curText, blockView.cols) : []
                    property color ink: Style.accent
                    onLinesChanged: requestPaint()
                    onInkChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()

                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        const rows = lines.length;
                        if (rows === 0) {
                            // interlude / gap between lines — three soft dots
                            ctx.fillStyle = Theme.alpha(Style.text, 0.3);
                            const dr = Math.max(3, Math.min(width, height) * 0.011);
                            for (let k = -1; k <= 1; k++) {
                                ctx.beginPath();
                                ctx.arc(width / 2 + k * dr * 6, height / 2, dr, 0, Math.PI * 2);
                                ctx.fill();
                            }
                            return;
                        }
                        let maxc = 0;
                        for (let i = 0; i < rows; i++) maxc = Math.max(maxc, lines[i].length);
                        if (maxc === 0) return;
                        // fit the grid keeping a terminal-ish cell aspect (a hair
                        // taller than wide), then centre it in the pane
                        const aspect = 0.62;   // cellW / cellH
                        const cellH = Math.min(height / rows, width / (maxc * aspect));
                        const cellW = cellH * aspect;
                        const oy = (height - rows * cellH) / 2;
                        // One SHARED integer origin + a shared fractional cell grid,
                        // and centre each row by a whole number of CELLS (like the
                        // terminal tool space-pads on its character grid). Every cell
                        // in every row then lands on the same sub-pixel phase, so
                        // vertical strokes line up across rows and there's no moiré —
                        // per-ROW pixel centring put each row on its own phase and
                        // garbled letters with fine internal detail (O/M/E).
                        const ox = Math.round((width - maxc * cellW) / 2);
                        ctx.fillStyle = blockCanvas.ink;
                        for (let r = 0; r < rows; r++) {
                            // NB: do NOT trim trailing spaces here — the 5 pixel-lines
                            // of a word-row are all equal width, but letters like E/F/L
                            // carry trailing spaces on some rows, so trimming would make
                            // those lines shorter and shear the word apart (the bug that
                            // garbled HOME/ONE/MORE). Blank cells simply aren't filled.
                            const line = lines[r];
                            const pad = Math.floor((maxc - line.length) / 2);   // centre in whole cells
                            const y0 = Math.round(oy + r * cellH);
                            const y1 = Math.round(oy + (r + 1) * cellH);
                            for (let c = 0; c < line.length; c++) {
                                if (line.charAt(c) === "█") {
                                    const x0 = Math.round(ox + (c + pad) * cellW);
                                    const x1 = Math.round(ox + (c + pad + 1) * cellW);
                                    ctx.fillRect(x0, y0, x1 - x0, y1 - y0);
                                }
                            }
                        }
                    }
                    Connections { target: Style; function onChanged() { blockCanvas.ink = Style.accent; } }
                }

                Text {
                    id: nextLine
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    horizontalAlignment: Text.AlignHCenter
                    visible: blockView.nextText !== ""
                    text: blockView.nextText
                    textFormat: Text.PlainText
                    color: Theme.alpha(Style.text, 0.42)
                    font.family: Style.monoFamily
                    font.pixelSize: Theme.fBody
                    font.letterSpacing: 1
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }

            // resume affordance — only while hand-scrolled away from the song
            Rectangle {
                id: resume
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.s3
                visible: Lyrics.hasLyrics && !root.blockMode && !list.following
                width: resumeRow.width + Theme.s4
                height: 28
                radius: 14
                color: Theme.alpha(Style.accent, 0.9)
                Row {
                    id: resumeRow
                    anchors.centerIn: parent
                    spacing: Theme.s1
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "↺"
                        color: Style.base
                        font.pixelSize: 14
                        font.weight: Font.Bold
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Resume"
                        color: Style.base
                        font.pixelSize: Theme.fCaption
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: list.refollow()
                }
                Behavior on opacity { NumberAnimation { duration: Theme.durMed } }
            }

            // empty / loading
            Column {
                anchors.centerIn: parent
                spacing: Theme.s2
                visible: !Lyrics.hasLyrics
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Lyrics.loading ? "◌" : "◈"
                    color: Theme.alpha(Style.text, 0.4)
                    font.pixelSize: 28
                    RotationAnimation on rotation {
                        from: 0; to: 360; duration: 1600
                        loops: Animation.Infinite
                        running: Lyrics.loading && root.visible
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Lyrics.loading ? "Loading lyrics…" : "No lyrics found"
                    color: Theme.alpha(Style.text, 0.5)
                    font.pixelSize: Theme.fLabel
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !Lyrics.loading
                    text: "click to retry"
                    color: retryMa.containsMouse ? Theme.alpha(Style.text, 0.75) : Theme.alpha(Style.text, 0.4)
                    font.pixelSize: Theme.fCaption
                    font.letterSpacing: 1
                }
            }
            MouseArea {
                id: retryMa
                anchors.centerIn: parent
                width: 160; height: 90
                visible: !Lyrics.hasLyrics && !Lyrics.loading
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Lyrics.refresh()
            }
        }
    }
}
