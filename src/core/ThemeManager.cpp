#include "ThemeManager.h"

#include <QDir>
#include <QEasingCurve>
#include <QFile>
#include <QFileInfo>
#include <QFontDatabase>
#include <QFileSystemWatcher>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QJsonValue>
#include <QSettings>
#include <QStandardPaths>
#include <QVariantAnimation>
#include <QVariantMap>
#include <algorithm>
#include <cmath>

#include "MprisController.h"
#include "OklchColor.h"

namespace vespera {

namespace {

QColor lerpColor(const QColor &a, const QColor &b, double t) {
    return QColor::fromRgbF(a.redF() + (b.redF() - a.redF()) * t,
                            a.greenF() + (b.greenF() - a.greenF()) * t,
                            a.blueF() + (b.blueF() - a.blueF()) * t,
                            a.alphaF() + (b.alphaF() - a.alphaF()) * t);
}

// Warm/cool mood tint — nudge a colour toward amber (warmth>0) or toward a cool
// blue (warmth<0) by a small, perceptually gentle amount.
QColor tintMood(const QColor &c, double warmth, double amount) {
    if (std::fabs(warmth) < 1e-3 || amount < 1e-3) return c;
    const QColor warm(255, 176, 118);
    const QColor cool(150, 182, 255);
    const QColor ref = warmth > 0 ? warm : cool;
    const double t = std::min(0.6, std::fabs(warmth) * amount);
    return lerpColor(c, ref, t);
}

QColor parseColor(const QJsonValue &v, const QColor &fallback) {
    if (!v.isString()) return fallback;
    QColor c(v.toString());
    return c.isValid() ? c : fallback;
}

// Shortest-path hue interpolation (radians).
double lerpAngle(double a, double b, double t) {
    double d = std::fmod(b - a, 2.0 * M_PI);
    if (d > M_PI) d -= 2.0 * M_PI;
    if (d < -M_PI) d += 2.0 * M_PI;
    return a + d * t;
}

}  // namespace

namespace {
// Register a bundled font (all its weights) and return the family name.
QString loadFamily(const QStringList &paths) {
    QString family;
    for (const QString &p : paths) {
        const int id = QFontDatabase::addApplicationFont(p);
        if (id >= 0 && family.isEmpty()) {
            const auto fams = QFontDatabase::applicationFontFamilies(id);
            if (!fams.isEmpty()) family = fams.first();
        }
    }
    return family;
}
}  // namespace

ThemeManager::ThemeManager(MprisController *player, QObject *parent)
    : QObject(parent), m_player(player) {
    m_jbFamily = loadFamily({QStringLiteral(":/assets/fonts/JetBrainsMono-Regular.ttf"),
                             QStringLiteral(":/assets/fonts/JetBrainsMono-Medium.ttf"),
                             QStringLiteral(":/assets/fonts/JetBrainsMono-Bold.ttf"),
                             QStringLiteral(":/assets/fonts/JetBrainsMono-ExtraBold.ttf")});
    m_mapleFamily = loadFamily({QStringLiteral(":/assets/fonts/MapleMono-Regular.ttf"),
                                QStringLiteral(":/assets/fonts/MapleMono-Bold.ttf")});
    m_rubikFamily = loadFamily({QStringLiteral(":/assets/fonts/Rubik-Variable.ttf")});
    loadBuiltins();
    loadUserThemes();
    loadPrefs();
    selectInitial();

    if (m_player)
        connect(m_player, &MprisController::paletteChanged, this,
                &ThemeManager::onPaletteChanged);

    // Hot-reload user themes when the directory changes.
    QString dir = QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation);
    if (dir.isEmpty()) dir = QDir::homePath() + QStringLiteral("/.config/vespera");
    dir += QStringLiteral("/themes");
    QDir().mkpath(dir);
    auto *watcher = new QFileSystemWatcher(this);
    watcher->addPath(dir);
    connect(watcher, &QFileSystemWatcher::directoryChanged, this, [this] {
        const QString curId = m_cur.id;
        m_defs.clear();
        loadBuiltins();
        loadUserThemes();
        emit themesChanged();
        if (const ThemeDef *d = find(curId)) {  // keep the current selection alive
            m_cur = *d;
            m_prev = *d;
            emit changed();
        }
    });
}

void ThemeManager::onPaletteChanged() {
    emit changed();  // getters recompute against the freshly cross-faded palette
}

// ---- catalogue -------------------------------------------------------------

void ThemeManager::loadBuiltins() {
    auto add = [this](ThemeDef d) { m_defs.push_back(std::move(d)); };

    {  // VESPERA — the DYNAMIC flagship: the whole room follows the album. No fixed
        // hue anywhere — accent + accentAlt are the album's own vivid colours, the
        // base and grade are album-derived, so every track visibly recolours the UI.
        // This is the "dynamic theming" default; the curated themes below commit a
        // hue/mood on purpose.
        ThemeDef t;
        t.id = "vespera"; t.name = "Vespera"; t.blurb = "Living colour — the whole room follows your album";
        t.scene = "field"; t.iridescent = true; t.warmth = 0.0; t.saturation = 1.22;
        t.accentLift = 0.02; t.baseDarken = 0.92;
        t.blur = 54; t.coverOpacity = 0.55;
        t.coverSaturation = 1.42; t.coverBrightness = 1.12; t.lumFloor = 0.28;
        t.gradeStrength = 0.15; t.grain = 0.0; t.vignette = 0.2;
        t.glassOpacity = 0.3; t.glassBorder = 0.15; t.radius = 18; t.motion = 1.0;
        t.sceneIntensity = 0.0;
        add(t);
    }
    {  // EMBER — warm amber/sage glass, heir to the owner's own
        // MusicPopup reference. Kept id "halo" so the persisted default and
        // VESPERA_THEME fallback keep working untouched.
        ThemeDef t;
        t.id = "halo"; t.name = "Ember"; t.blurb = "Warm glass — amber and sage, the cover glows through";
        // "field" = the plain graded backdrop, no cool aurora curtains fighting
        // the warmth. accentFixed commits the accent hue to amber so it reads
        // warm on every track; chroma/lightness still track the album so it
        // stays alive. Non-iridescent so accentAlt is a hue-sibling of THAT
        // amber (not the album's raw, possibly-cold second colour) — the
        // amber→sage pairing from the approved mockup, every track.
        t.scene = "field"; t.iridescent = false; t.saturation = 1.15; t.warmth = 0.46;
        t.accentFixed = QColor(0xff, 0xc9, 0x78);  // warm gold
        // The full-bleed cover is deliberately quiet now: the album's light
        // reads from the disc's radial bloom (DiscGlow), not a photo stretched
        // edge-to-edge. This backdrop is just a faint graded atmosphere the glass
        // refracts. Ember went 1.0 -> 0.58 last round; this is the bigger step.
        t.baseDarken = 1.0; t.blur = 56; t.coverOpacity = 0.34;
        t.coverSaturation = 1.5; t.coverBrightness = 1.14; t.lumFloor = 0.3;
        t.gradeColor = QColor(0x1c, 0x14, 0x0c);  // warm bias even on cool-toned art
        t.gradeStrength = 0.22; t.grain = 0.0; t.vignette = 0.22;
        t.glassOpacity = 0.32; t.glassBorder = 0.17; t.radius = 18; t.motion = 1.0;
        t.sceneIntensity = 0.0;
        add(t);
    }
    {  // OBSIDIAN — black glass: deep, precise, jewel-lit
        ThemeDef t;
        t.id = "obsidian"; t.name = "Obsidian"; t.blurb = "Black glass — deep, precise, jewel-lit";
        t.scene = "field"; t.warmth = 0.0; t.saturation = 0.92; t.accentLift = 0.1;
        t.baseFixed = QColor(0x07, 0x07, 0x0a); t.blur = 50; t.coverOpacity = 0.3;
        t.coverSaturation = 0.92; t.coverBrightness = 0.96; t.lumFloor = 0.22;
        t.gradeColor = QColor(0x0a, 0x0a, 0x0d); t.gradeStrength = 0.4; t.grain = 0.0;
        t.vignette = 0.34; t.glassOpacity = 0.34; t.glassBorder = 0.18; t.radius = 14;
        t.motion = 0.8;
        add(t);
    }
    {  // VELVET — rich, saturated, after-dark lush (no grain, no sepia)
        ThemeDef t;
        t.id = "velvet"; t.name = "Velvet"; t.blurb = "Velvet — rich colour, after-dark lush";
        t.scene = "field"; t.warmth = 0.2; t.saturation = 1.25; t.iridescent = true;
        t.baseDarken = 0.85; t.blur = 48; t.coverOpacity = 0.44;
        t.coverSaturation = 1.5; t.coverBrightness = 1.1; t.lumFloor = 0.3;
        t.gradeStrength = 0.2; t.grain = 0.0; t.vignette = 0.24; t.glassOpacity = 0.3;
        t.glassBorder = 0.14; t.radius = 18; t.motion = 0.95;
        add(t);
    }
    {  // STARLIT — heir to Observatory: deep space, but the cover still glows
        ThemeDef t;
        t.id = "starlit"; t.name = "Starlit"; t.blurb = "Deep space — stars over an album-tinted planet";
        t.scene = "starfield"; t.warmth = -0.08; t.saturation = 1.05;
        t.baseFixed = QColor(0x09, 0x0e, 0x22); t.blur = 58; t.coverOpacity = 0.32;
        t.coverSaturation = 1.15; t.coverBrightness = 1.06; t.lumFloor = 0.24;
        t.gradeColor = QColor(0x0a, 0x10, 0x28);
        t.gradeStrength = 0.38; t.grain = 0.0; t.vignette = 0.3; t.glassOpacity = 0.3;
        t.glassBorder = 0.13; t.radius = 16; t.motion = 1.0; t.sceneIntensity = 1.0;
        add(t);
    }
    {  // NOIR — monochrome, still, work-safe, low power
        ThemeDef t;
        t.id = "noir"; t.name = "Noir"; t.blurb = "Monochrome — desaturated, still, work-safe";
        t.scene = "field"; t.warmth = 0.0; t.saturation = 0.12; t.accentLift = 0.12;
        t.baseFixed = QColor(0x0e, 0x0e, 0x11); t.blur = 52; t.coverOpacity = 0.32;
        t.coverSaturation = 0.0; t.coverBrightness = 1.05; t.lumFloor = 0.24;
        t.gradeColor = QColor(0x0c, 0x0c, 0x0e);
        t.gradeStrength = 0.35; t.grain = 0.0; t.vignette = 0.3; t.glassOpacity = 0.3;
        t.glassBorder = 0.12; t.radius = 16; t.motion = 0.5; t.sceneAnimate = false;
        t.sceneIntensity = 0.0;
        add(t);
    }
    {  // AURORA — cool flowing curtains
        ThemeDef t;
        t.id = "aurora"; t.name = "Aurora"; t.blurb = "Northern light — cool curtains over frost";
        t.scene = "aurora"; t.warmth = -0.34; t.saturation = 1.1;
        t.accentFixed = QColor(0x5a, 0xd6, 0xcf);  // aurora teal
        t.baseFixed = QColor(0x07, 0x16, 0x1a); t.blur = 50; t.coverOpacity = 0.34;
        t.coverSaturation = 1.25; t.coverBrightness = 1.08; t.lumFloor = 0.26;
        t.gradeColor = QColor(0x08, 0x22, 0x22);
        t.gradeStrength = 0.3; t.grain = 0.0; t.vignette = 0.26; t.glassOpacity = 0.28;
        t.glassBorder = 0.13; t.radius = 16; t.motion = 1.08; t.sceneIntensity = 1.16;
        add(t);
    }
    {  // NEON — synthwave horizon, grid + sun, cover as the sky
        ThemeDef t;
        t.id = "neon"; t.name = "Neon"; t.blurb = "Synthwave — grid, sun, and a cover sky";
        t.scene = "synthwave"; t.warmth = 0.12; t.saturation = 1.22; t.iridescent = true;
        t.accentFixed = QColor(0xff, 0x5d, 0xb2);  // hot magenta
        t.baseFixed = QColor(0x14, 0x0a, 0x24); t.blur = 42; t.coverOpacity = 0.36;
        t.coverSaturation = 1.35; t.coverBrightness = 1.08; t.lumFloor = 0.26;
        t.gradeColor = QColor(0x2a, 0x0e, 0x38);
        t.gradeStrength = 0.35; t.grain = 0.0; t.vignette = 0.3; t.glassOpacity = 0.34;
        t.glassBorder = 0.16; t.radius = 16; t.motion = 1.14; t.sceneIntensity = 0.92;
        add(t);
    }
}

void ThemeManager::loadUserThemes() {
    QString dir = QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation);
    if (dir.isEmpty()) dir = QDir::homePath() + QStringLiteral("/.config/vespera");
    dir += QStringLiteral("/themes");
    QDir d(dir);
    if (!d.exists()) return;
    const auto files = d.entryList({QStringLiteral("*.json")}, QDir::Files, QDir::Name);
    for (const QString &f : files) {
        QFile file(d.filePath(f));
        if (!file.open(QIODevice::ReadOnly)) continue;
        QJsonParseError err{};
        const QJsonDocument doc = QJsonDocument::fromJson(file.readAll(), &err);
        if (err.error != QJsonParseError::NoError || !doc.isObject()) continue;
        const QJsonObject o = doc.object();

        // user themes may extend a built-in via "base": "<id>"
        ThemeDef t;
        if (o.contains(QStringLiteral("base"))) {
            if (const ThemeDef *b = find(o.value(QStringLiteral("base")).toString())) t = *b;
        }
        t.id = o.value(QStringLiteral("id")).toString(QFileInfo(f).completeBaseName());
        t.name = o.value(QStringLiteral("name")).toString(t.id);
        t.blurb = o.value(QStringLiteral("blurb")).toString(t.blurb);
        t.scene = o.value(QStringLiteral("scene")).toString(t.scene);
        auto num = [&](const char *k, double def) {
            return o.contains(QLatin1String(k)) ? o.value(QLatin1String(k)).toDouble(def) : def;
        };
        t.warmth = num("warmth", t.warmth);
        t.saturation = num("saturation", t.saturation);
        t.accentLift = num("accentLift", t.accentLift);
        t.iridescent = o.value(QStringLiteral("iridescent")).toBool(t.iridescent);
        t.baseTint = num("baseTint", t.baseTint);
        t.baseDarken = num("baseDarken", t.baseDarken);
        t.blur = num("blur", t.blur);
        t.coverOpacity = num("coverOpacity", t.coverOpacity);
        t.coverSaturation = num("coverSaturation", t.coverSaturation);
        t.coverBrightness = num("coverBrightness", t.coverBrightness);
        t.lumFloor = num("lumFloor", t.lumFloor);
        t.gradeStrength = num("gradeStrength", t.gradeStrength);
        t.grain = num("grain", t.grain);
        t.vignette = num("vignette", t.vignette);
        t.glassOpacity = num("glassOpacity", t.glassOpacity);
        t.glassBorder = num("glassBorder", t.glassBorder);
        t.radius = int(num("radius", t.radius));
        t.motion = num("motion", t.motion);
        t.sceneAnimate = o.value(QStringLiteral("sceneAnimate")).toBool(t.sceneAnimate);
        t.sceneIntensity = num("sceneIntensity", t.sceneIntensity);
        t.baseFixed = parseColor(o.value(QStringLiteral("baseFixed")), t.baseFixed);
        t.gradeColor = parseColor(o.value(QStringLiteral("gradeColor")), t.gradeColor);
        t.accentFixed = parseColor(o.value(QStringLiteral("accentFixed")), t.accentFixed);

        // replace a built-in of the same id, else append
        bool replaced = false;
        for (auto &d0 : m_defs)
            if (d0.id == t.id) { d0 = t; replaced = true; break; }
        if (!replaced) m_defs.push_back(t);
    }
}

const ThemeDef *ThemeManager::find(const QString &id) const {
    for (const auto &d : m_defs)
        if (d.id == id) return &d;
    return nullptr;
}

// ---- palette interpretation ------------------------------------------------

QColor ThemeManager::deriveAccent(const ThemeDef &t) const {
    QColor album = m_player ? m_player->accent() : QColor(0x6f, 0xe9, 0xff);
    oklch::Lch c = oklch::fromColor(album);
    c.C = std::clamp(c.C * t.saturation, 0.0, 0.33);
    c.L = std::clamp(c.L + t.accentLift, 0.55, 0.9);
    // Strongly-themed palettes commit the accent HUE (Vellum → amber, Aurora →
    // teal, Neon → magenta) so it belongs to the theme; chroma/lightness still
    // come from the album, so it stays alive per track. Neutral themes keep the
    // album hue for full per-track identity.
    if (t.accentFixed.isValid()) c.h = oklch::fromColor(t.accentFixed).h;
    c.h += (m_accentHue * M_PI / 180.0);
    return oklch::toColor(c);
}

QColor ThemeManager::deriveAccentAlt(const ThemeDef &t) const {
    if (t.iridescent) {
        QColor album = m_player ? m_player->accentAlt() : QColor(0xb4, 0x90, 0xff);
        oklch::Lch c = oklch::fromColor(album);
        c.C = std::clamp(c.C * t.saturation, 0.0, 0.33);
        c.L = std::clamp(c.L + t.accentLift, 0.55, 0.9);
        c.h += (m_accentHue * M_PI / 180.0);
        return oklch::toColor(c);
    }
    // non-iridescent themes: a hue-rotated sibling of the accent for gradients
    oklch::Lch c = oklch::fromColor(deriveAccent(t));
    c.h += 0.5;  // ~28°
    c.L = std::clamp(c.L - 0.04, 0.5, 0.9);
    return oklch::toColor(c);
}

QColor ThemeManager::deriveBase(const ThemeDef &t) const {
    QColor out;
    if (t.baseFixed.isValid()) {
        out = tintMood(t.baseFixed, t.warmth, 0.1);
    } else {
        QColor album = m_player ? m_player->base() : QColor(0x0b, 0x0f, 0x24);
        oklch::Lch c = oklch::fromColor(album);
        c.L = std::clamp(c.L * t.baseDarken, 0.03, 0.22);
        out = tintMood(oklch::toColor(c), t.warmth, 0.16);
    }
    // a small, global deepen of the ground — a touch darker with a bit more
    // contrast against the bright accents/text, applied to every theme.
    oklch::Lch cc = oklch::fromColor(out);
    cc.L = std::clamp(cc.L * 0.88, 0.02, 0.2);
    return oklch::toColor(cc);
}

QColor ThemeManager::deriveText(const ThemeDef &t) const {
    QColor album = m_player ? m_player->text() : QColor(0xea, 0xf2, 0xff);
    return tintMood(album, t.warmth, 0.07);
}

QColor ThemeManager::deriveGrade(const ThemeDef &t) const {
    if (t.gradeColor.isValid()) return t.gradeColor;
    // Halo & other derived-grade themes: pull the grade from base+accent so it
    // recolours per track.
    QColor b = deriveBase(t);
    QColor a = deriveAccent(t);
    return lerpColor(b, a, 0.28);
}

// ---- effective getters (blend prev->cur across a theme switch) --------------

QColor ThemeManager::base() const {
    return lerpColor(deriveBase(m_prev), deriveBase(m_cur), m_mix);
}
QColor ThemeManager::accent() const {
    return lerpColor(deriveAccent(m_prev), deriveAccent(m_cur), m_mix);
}
QColor ThemeManager::accentAlt() const {
    return lerpColor(deriveAccentAlt(m_prev), deriveAccentAlt(m_cur), m_mix);
}
QColor ThemeManager::text() const {
    return lerpColor(deriveText(m_prev), deriveText(m_cur), m_mix);
}
QColor ThemeManager::gradeColor() const {
    return lerpColor(deriveGrade(m_prev), deriveGrade(m_cur), m_mix);
}
QColor ThemeManager::textDim() const {
    QColor tx = text();
    oklch::Lch c = oklch::fromColor(tx);
    c.L = std::clamp(c.L - 0.16, 0.35, 0.85);
    return oklch::toColor(c);
}
QColor ThemeManager::surface() const {
    // glass fill tint: base lifted slightly toward the accent, warm-tinted
    QColor b = base();
    QColor a = accent();
    QColor s = lerpColor(b, a, 0.08);
    oklch::Lch c = oklch::fromColor(s);
    c.L = std::clamp(c.L + 0.06, 0.06, 0.3);
    return oklch::toColor(c);
}
QColor ThemeManager::surfaceStrong() const {
    QColor s = surface();
    oklch::Lch c = oklch::fromColor(s);
    c.L = std::clamp(c.L + 0.04, 0.06, 0.34);
    return oklch::toColor(c);
}
QColor ThemeManager::line() const { return text(); }

int ThemeManager::radius() const {
    return int(std::lround(m_prev.radius + (m_cur.radius - m_prev.radius) * m_mix));
}

// ---- catalogue for QML -----------------------------------------------------

QVariantList ThemeManager::themes() const {
    QVariantList out;
    for (const auto &d : m_defs) {
        QVariantMap m;
        m[QStringLiteral("id")] = d.id;
        m[QStringLiteral("name")] = d.name;
        m[QStringLiteral("blurb")] = d.blurb;
        m[QStringLiteral("scene")] = d.scene;
        out.push_back(m);
    }
    return out;
}

QVariantList ThemeManager::swatch(const QString &id) const {
    const ThemeDef *d = find(id);
    if (!d) return {};
    return {QVariant(deriveGrade(*d)), QVariant(deriveAccent(*d)), QVariant(deriveBase(*d))};
}

// ---- selection + transition ------------------------------------------------

void ThemeManager::selectInitial() {
    if (m_defs.isEmpty()) { m_cur = m_prev = ThemeDef(); return; }
    QSettings s;
    // VESPERA_THEME overrides the persisted choice without writing it back —
    // used by the screenshot tooling to render each theme deterministically.
    QString want = qEnvironmentVariable("VESPERA_THEME");
    if (want.isEmpty() || !find(want))
        want = s.value(QStringLiteral("theme/id"), QStringLiteral("vespera")).toString();
    const ThemeDef *d = find(want);
    if (!d) d = &m_defs.first();
    m_cur = *d;
    m_prev = *d;
    m_mix = 1.0;
}

void ThemeManager::setTheme(const QString &id) {
    const ThemeDef *d = find(id);
    if (!d || d->id == m_cur.id) return;
    beginTransition(*d);
    QSettings s;
    s.setValue(QStringLiteral("theme/id"), id);
}

void ThemeManager::beginTransition(const ThemeDef &to) {
    if (m_anim) m_anim->stop();
    m_prev = m_cur;
    m_cur = to;
    m_mix = 0.0;
    emit sceneChanged();  // QML learns the new scene id + from-scene up front
    if (!m_anim) {
        m_anim = new QVariantAnimation(this);
        m_anim->setStartValue(0.0);
        m_anim->setEndValue(1.0);
        m_anim->setDuration(560);
        m_anim->setEasingCurve(QEasingCurve::InOutCubic);
        connect(m_anim, &QVariantAnimation::valueChanged, this, [this](const QVariant &v) {
            m_mix = v.toDouble();
            emit changed();
        });
        connect(m_anim, &QVariantAnimation::finished, this, [this] {
            m_mix = 1.0;
            m_prev = m_cur;  // settle: from == cur, scene cross-fade idle
            emit changed();
            emit sceneChanged();
        });
    }
    m_anim->start();
}

// ---- knobs + persistence ---------------------------------------------------

void ThemeManager::setOvBlur(qreal v) {
    if (qFuzzyCompare(m_ovBlur, v)) return;
    m_ovBlur = v; savePrefs(); emit changed();
}
void ThemeManager::setOvCoverOpacity(qreal v) {
    if (qFuzzyCompare(m_ovCoverOpacity, v)) return;
    m_ovCoverOpacity = v; savePrefs(); emit changed();
}
void ThemeManager::setOvGrain(qreal v) {
    if (qFuzzyCompare(m_ovGrain, v)) return;
    m_ovGrain = v; savePrefs(); emit changed();
}
void ThemeManager::setOvGlass(qreal v) {
    if (qFuzzyCompare(m_ovGlass, v)) return;
    m_ovGlass = v; savePrefs(); emit changed();
}
void ThemeManager::setFontChoice(int v) {
    v = std::clamp(v, 0, 3);
    if (m_fontChoice == v) return;
    m_fontChoice = v; savePrefs(); emit changed();
}
// fontChoice: 0 Rubik (display) · 1 Maple Mono · 2 JetBrains Mono · 3 System
QString ThemeManager::displayFamily() const {
    switch (m_fontChoice) {
        case 1: return m_mapleFamily.isEmpty() ? m_jbFamily : m_mapleFamily;
        case 2: return m_jbFamily;
        case 3: return QString();  // system default sans
        default: return m_rubikFamily.isEmpty() ? m_jbFamily : m_rubikFamily;
    }
}
QString ThemeManager::monoFamily() const {
    if (m_fontChoice == 1 && !m_mapleFamily.isEmpty()) return m_mapleFamily;
    return m_jbFamily.isEmpty() ? QStringLiteral("monospace") : m_jbFamily;
}
void ThemeManager::setNotesOn(bool v) {
    if (m_notesOn == v) return;
    m_notesOn = v; savePrefs(); emit changed();
}
void ThemeManager::setTutorialSeen(bool v) {
    if (m_tutorialSeen == v) return;
    m_tutorialSeen = v; savePrefs(); emit changed();
}
void ThemeManager::setAccentHue(qreal v) {
    v = std::clamp(v, -30.0, 30.0);
    if (qFuzzyCompare(m_accentHue, v)) return;
    m_accentHue = v; savePrefs(); emit changed();
}
void ThemeManager::setDiscSpin(qreal v) {
    v = std::clamp(v, 0.2, 3.0);
    if (qFuzzyCompare(m_discSpin, v)) return;
    m_discSpin = v; savePrefs(); emit changed();
}
void ThemeManager::setReduceMotion(bool v) {
    if (m_reduceMotion == v) return;
    m_reduceMotion = v; savePrefs(); emit changed();
}
void ThemeManager::setOrbIntensity(qreal v) {
    v = std::clamp(v, 0.0, 1.0);
    if (qFuzzyCompare(m_orbIntensity, v)) return;
    m_orbIntensity = v; savePrefs(); emit changed();
}
void ThemeManager::setGlowStrength(qreal v) {
    v = std::clamp(v, 0.0, 1.0);
    if (qFuzzyCompare(m_glowStrength, v)) return;
    m_glowStrength = v; savePrefs(); emit changed();
}
void ThemeManager::setBgOpacity(qreal v) {
    v = std::clamp(v, 0.35, 1.0);   // keep some floor so it never vanishes
    if (qFuzzyCompare(m_bgOpacity, v)) return;
    m_bgOpacity = v; savePrefs(); emit changed();
}
void ThemeManager::setCoverPresence(qreal v) {
    v = std::clamp(v, 0.0, 1.0);
    if (qFuzzyCompare(m_coverPresence, v)) return;
    m_coverPresence = v; savePrefs(); emit changed();
}
void ThemeManager::setOvVignette(qreal v) {
    if (v >= 0) v = std::clamp(v, 0.0, 1.0);
    if (qFuzzyCompare(m_ovVignette, v)) return;
    m_ovVignette = v; savePrefs(); emit changed();
}
void ThemeManager::setEqEffectOn(bool v) {
    if (m_eqEffectOn == v) return;
    m_eqEffectOn = v; savePrefs(); emit changed();
}
void ThemeManager::setLyricsHidden(bool v) {
    if (m_lyricsHidden == v) return;
    m_lyricsHidden = v; savePrefs(); emit changed();
}
void ThemeManager::setLyricsBlockMode(bool v) {
    if (m_lyricsBlockMode == v) return;
    m_lyricsBlockMode = v; savePrefs(); emit changed();
}
void ThemeManager::resetKnobs() {
    m_ovBlur = m_ovCoverOpacity = m_ovGrain = m_ovGlass = -1;
    m_accentHue = 0;
    m_discSpin = 1.0;
    m_reduceMotion = false;
    m_orbIntensity = 0.85;
    m_glowStrength = 0.7;
    m_bgOpacity = 1.0;
    m_coverPresence = 0.55;
    m_ovVignette = -1;
    m_eqEffectOn = true;
    // lyricsHidden is a layout preference, not a look knob — leave it on reset
    savePrefs();
    emit changed();
}

void ThemeManager::loadPrefs() {
    QSettings s;
    m_ovBlur = s.value(QStringLiteral("theme/ovBlur"), -1.0).toDouble();
    m_ovCoverOpacity = s.value(QStringLiteral("theme/ovCoverOpacity"), -1.0).toDouble();
    m_ovGrain = s.value(QStringLiteral("theme/ovGrain"), -1.0).toDouble();
    m_ovGlass = s.value(QStringLiteral("theme/ovGlass"), -1.0).toDouble();
    m_accentHue = s.value(QStringLiteral("theme/accentHue"), 0.0).toDouble();
    m_fontChoice = s.value(QStringLiteral("theme/fontChoice"), 0).toInt();
    m_notesOn = s.value(QStringLiteral("theme/notesOn"), true).toBool();
    m_tutorialSeen = s.value(QStringLiteral("app/tutorialSeen"), false).toBool();
    m_discSpin = s.value(QStringLiteral("theme/discSpin"), 1.0).toDouble();
    m_reduceMotion = s.value(QStringLiteral("theme/reduceMotion"), false).toBool();
    m_orbIntensity = s.value(QStringLiteral("theme/orbIntensity"), 0.85).toDouble();
    m_glowStrength = s.value(QStringLiteral("theme/glowStrength"), 0.7).toDouble();
    m_bgOpacity = s.value(QStringLiteral("theme/bgOpacity"), 1.0).toDouble();
    m_coverPresence = s.value(QStringLiteral("theme/coverPresence"), 0.55).toDouble();
    m_ovVignette = s.value(QStringLiteral("theme/ovVignette"), -1.0).toDouble();
    m_eqEffectOn = s.value(QStringLiteral("theme/eqEffectOn"), true).toBool();
    m_lyricsHidden = s.value(QStringLiteral("theme/lyricsHidden"), false).toBool();
    m_lyricsBlockMode = s.value(QStringLiteral("theme/lyricsBlockMode"), true).toBool();
}
void ThemeManager::savePrefs() {
    QSettings s;
    s.setValue(QStringLiteral("theme/ovBlur"), m_ovBlur);
    s.setValue(QStringLiteral("theme/ovCoverOpacity"), m_ovCoverOpacity);
    s.setValue(QStringLiteral("theme/ovGrain"), m_ovGrain);
    s.setValue(QStringLiteral("theme/ovGlass"), m_ovGlass);
    s.setValue(QStringLiteral("theme/accentHue"), m_accentHue);
    s.setValue(QStringLiteral("theme/fontChoice"), m_fontChoice);
    s.setValue(QStringLiteral("theme/notesOn"), m_notesOn);
    s.setValue(QStringLiteral("app/tutorialSeen"), m_tutorialSeen);
    s.setValue(QStringLiteral("theme/discSpin"), m_discSpin);
    s.setValue(QStringLiteral("theme/reduceMotion"), m_reduceMotion);
    s.setValue(QStringLiteral("theme/orbIntensity"), m_orbIntensity);
    s.setValue(QStringLiteral("theme/glowStrength"), m_glowStrength);
    s.setValue(QStringLiteral("theme/bgOpacity"), m_bgOpacity);
    s.setValue(QStringLiteral("theme/coverPresence"), m_coverPresence);
    s.setValue(QStringLiteral("theme/ovVignette"), m_ovVignette);
    s.setValue(QStringLiteral("theme/eqEffectOn"), m_eqEffectOn);
    s.setValue(QStringLiteral("theme/lyricsHidden"), m_lyricsHidden);
    s.setValue(QStringLiteral("theme/lyricsBlockMode"), m_lyricsBlockMode);
}

}  // namespace vespera
