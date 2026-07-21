// Block-letter font — ported from the owner's terminal lyrics tool "lyricsooo"
// (~/Projects/cli-tools/lyrics-tool/src/lyrics_tool/fonts.py BLOCK_LETTERS +
// visualizer_display.py packing). Each character is 5 rows of full-block (█) and
// space cells; rendered into a monospace Text at a large size, the blocks tile
// into big chunky letters — the terminal karaoke look, transplanted into QML.
.pragma library

var H = 5;

var GLYPHS = {
    'A': ["  ███  ", " ██ ██ ", "███████", "██   ██", "██   ██"],
    'B': ["██████ ", "██   ██", "██████ ", "██   ██", "██████ "],
    'C': [" █████ ", "██   ██", "██     ", "██   ██", " █████ "],
    'D': ["██████ ", "██   ██", "██   ██", "██   ██", "██████ "],
    'E': ["███████", "██     ", "█████  ", "██     ", "███████"],
    'F': ["███████", "██     ", "█████  ", "██     ", "██     "],
    'G': [" █████ ", "██     ", "██  ███", "██   ██", " █████ "],
    'H': ["██   ██", "██   ██", "███████", "██   ██", "██   ██"],
    'I': ["███", " ██", " ██", " ██", "███"],
    'J': ["     ██", "     ██", "     ██", "██   ██", " █████ "],
    'K': ["██   ██", "██  ██ ", "█████  ", "██  ██ ", "██   ██"],
    'L': ["██     ", "██     ", "██     ", "██     ", "███████"],
    'M': ["██   ██", "███ ███", "███████", "██ █ ██", "██   ██"],
    'N': ["██   ██", "███  ██", "████ ██", "██ ████", "██   ██"],
    'O': [" █████ ", "██   ██", "██   ██", "██   ██", " █████ "],
    'P': ["██████ ", "██   ██", "██████ ", "██     ", "██     "],
    'Q': [" █████ ", "██   ██", "██   ██", "██  ███", " ██████"],
    'R': ["██████ ", "██   ██", "██████ ", "██  ██ ", "██   ██"],
    'S': [" █████ ", "██     ", " █████ ", "     ██", " █████ "],
    'T': ["███████", "  ██   ", "  ██   ", "  ██   ", "  ██   "],
    'U': ["██   ██", "██   ██", "██   ██", "██   ██", " █████ "],
    'V': ["██   ██", "██   ██", "██   ██", " ██ ██ ", "  ███  "],
    'W': ["██   ██", "██   ██", "██ █ ██", "███████", "███ ███"],
    'X': ["██   ██", " ██ ██ ", "  ███  ", " ██ ██ ", "██   ██"],
    'Y': ["██   ██", " ██ ██ ", "  ███  ", "  ██   ", "  ██   "],
    'Z': ["███████", "    ██ ", "  ███  ", " ██    ", "███████"],
    ' ': ["    ", "    ", "    ", "    ", "    "],
    '0': [" █████ ", "██   ██", "██   ██", "██   ██", " █████ "],
    '1': ["  ██   ", " ███   ", "  ██   ", "  ██   ", "███████"],
    '2': [" █████ ", "██   ██", "   ███ ", " ██    ", "███████"],
    '3': [" █████ ", "██   ██", "  ████ ", "██   ██", " █████ "],
    '4': ["██   ██", "██   ██", "███████", "     ██", "     ██"],
    '5': ["███████", "██     ", "██████ ", "     ██", "██████ "],
    '6': [" █████ ", "██     ", "██████ ", "██   ██", " █████ "],
    '7': ["███████", "     ██", "    ██ ", "   ██  ", "  ██   "],
    '8': [" █████ ", "██   ██", " █████ ", "██   ██", " █████ "],
    '9': [" █████ ", "██   ██", " ██████", "     ██", " █████ "],
    '[': ["███", "██ ", "██ ", "██ ", "███"],
    ']': ["███", " ██", " ██", " ██", "███"],
    "'": ["██", "██", "  ", "  ", "  "],
    ',': ["  ", "  ", "  ", "██", "█ "],
    '.': ["  ", "  ", "  ", "  ", "██"],
    '!': ["██", "██", "██", "  ", "██"],
    '?': [" ███ ", "█   █", "   █ ", "     ", "  █  "],
    '-': ["      ", "      ", "██████", "      ", "      "],
    '(': [" ██", "██ ", "██ ", "██ ", " ██"],
    ')': ["██ ", " ██", " ██", " ██", "██ "],
    ':': ["  ", "██", "  ", "██", "  "],
    ';': ["  ", "██", "  ", "██", "█ "],
    '/': ["    ██", "   ██ ", "  ██  ", " ██   ", "██    "],
    '"': ["██ ██", "██ ██", "     ", "     ", "     "],
    '&': [" ███  ", "█   █ ", " ███  ", "█ █ █ ", " ███ █"],
    '+': ["  ██  ", "  ██  ", "██████", "  ██  ", "  ██  "]
};

var SPACE_W = GLYPHS[' '][0].length;  // blank-cell width used for gaps/unknowns

// Render one row of words (each word's letters joined, words separated by a
// blank glyph) into H strings. Mirrors _render_block_line in the Python tool.
function _renderRow(words) {
    var lines = [];
    for (var i = 0; i < H; i++) lines.push("");
    for (var wi = 0; wi < words.length; wi++) {
        if (wi > 0) {
            for (var g = 0; g < H; g++) lines[g] += _spaces(SPACE_W + 1);
        }
        var word = words[wi];
        for (var ci = 0; ci < word.length; ci++) {
            var ch = word[ci];
            var glyph = GLYPHS[ch];
            if (glyph === undefined) {                 // unknown char -> blank
                for (var u = 0; u < H; u++) lines[u] += _spaces(SPACE_W + 1);
                continue;
            }
            for (var r = 0; r < H; r++) {
                var cell = r < glyph.length ? glyph[r] : _spaces(glyph[0].length);
                lines[r] += cell + " ";
            }
        }
    }
    return lines;
}

function _spaces(n) {
    var s = "";
    for (var i = 0; i < n; i++) s += " ";
    return s;
}

function _rowWidth(words) {
    var lines = _renderRow(words);
    var w = 0;
    for (var i = 0; i < lines.length; i++) w = Math.max(w, lines[i].length);
    return w;
}

// Pack `text` into stacked block-letter rows that each fit within `cols` glyph
// columns, greedily by word; word-rows are separated by a blank line. Returns the
// grid as an ARRAY of strings (one per pixel-row). Mirrors _pack_block_lines. The
// grid is painted cell-by-cell on a Canvas (see LyricsPanel) rather than set as
// Text, so the blocks are always crisp — a monospace font tiles █ unevenly at
// fractional sizes and garbles letters with internal counters (O, M, E).
function grid(text, cols) {
    var words = String(text).toUpperCase().split(/\s+/).filter(function (w) { return w.length > 0; });
    if (words.length === 0) return [];

    var rowWords = [];
    var current = [];
    for (var i = 0; i < words.length; i++) {
        var trial = current.concat([words[i]]);
        if (current.length > 0 && _rowWidth(trial) > cols) {
            rowWords.push(current);
            current = [words[i]];
        } else {
            current = trial;
        }
    }
    if (current.length > 0) rowWords.push(current);

    var out = [];
    for (var ri = 0; ri < rowWords.length; ri++) {
        if (ri > 0) out.push("");                       // blank separator between rows
        var rendered = _renderRow(rowWords[ri]);
        for (var k = 0; k < rendered.length; k++) out.push(rendered[k]);
    }
    return out;
}
