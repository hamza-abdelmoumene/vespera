// Vespera theme engine — the presentation authority ("Style" in QML).
//
// A theme is DATA: a small struct of numeric + colour parameters describing a
// backdrop treatment, how the album palette is transformed, the glass tokens,
// and a motion character. The engine interprets those parameters against the
// live, per-track album palette (read from MprisController) and exposes the
// resulting effective tokens to QML. User themes are JSON files with the same
// fields in ~/.config/vespera/themes/*.json.
//
// Two transitions, both driven here so nothing double-animates in QML:
//   • per-track recolour — the album palette itself is already cross-faded in
//     MprisController; the getters simply recompute, so the whole UI washes.
//   • theme switch — a local mix 0->1 blends the outgoing theme's tokens into
//     the incoming theme's tokens over ~half a second.
#pragma once

#include <QColor>
#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVector>

class QVariantAnimation;

namespace vespera {

class MprisController;

// The declarative description of one theme. Everything here can be authored in
// JSON; the engine below is the single shared interpreter.
struct ThemeDef {
    QString id;
    QString name;
    QString blurb;
    QString scene = QStringLiteral("field");  // field | aurora | starfield | synthwave

    // --- palette transform (applied to the album palette in OKLCh) ---
    double warmth = 0.0;       // hue nudge: -1 cool .. +1 warm (amber)
    double saturation = 1.0;   // accent chroma multiplier (Noir ~0.12)
    double accentLift = 0.0;   // add to accent lightness
    bool iridescent = false;   // keep accent + accentAlt vivid & hue-split
    QColor accentFixed;        // if valid, commit the accent HUE to this (chroma/
                               // lightness still track the album, so it stays alive)
    QColor baseFixed;          // if valid, the window ground is this (else album-derived)
    double baseTint = 1.0;     // when not fixed, how strongly the album tints the ground
    double baseDarken = 1.0;   // multiply base lightness (Starlit deep, etc.)

    // --- backdrop / colour grade (drives CoverBackdrop + the C++ grade) ---
    double blur = 52.0;        // cover blur radius (logical px)
    double coverOpacity = 0.5; // how present the cover reads (0 washed .. 1 bold)
    double coverSaturation = 1.1;
    double coverBrightness = 1.0;  // backdrop gain (lush themes run >1)
    double lumFloor = 0.0;     // min mean luminance — dark albums get lifted to it
    QColor gradeColor;         // if invalid, derived from base
    double gradeStrength = 0.55;
    double grain = 0.06;       // film grain intensity
    double vignette = 0.5;     // edge darkening

    // --- glass tokens ---
    double glassOpacity = 0.30;
    double glassBorder = 0.10;
    int radius = 16;

    // --- motion / scene ---
    double motion = 1.0;       // scales durations / animation intensity
    bool sceneAnimate = true;
    double sceneIntensity = 1.0;  // aurora curtain / star density / grid glow
};

class ThemeManager : public QObject {
    Q_OBJECT

    // effective colours (album palette × theme, blended across theme switches)
    Q_PROPERTY(QColor base READ base NOTIFY changed)
    Q_PROPERTY(QColor surface READ surface NOTIFY changed)
    Q_PROPERTY(QColor surfaceStrong READ surfaceStrong NOTIFY changed)
    Q_PROPERTY(QColor accent READ accent NOTIFY changed)
    Q_PROPERTY(QColor accentAlt READ accentAlt NOTIFY changed)
    Q_PROPERTY(QColor text READ text NOTIFY changed)
    Q_PROPERTY(QColor textDim READ textDim NOTIFY changed)
    Q_PROPERTY(QColor line READ line NOTIFY changed)
    Q_PROPERTY(QColor gradeColor READ gradeColor NOTIFY changed)

    // effective backdrop / glass scalars
    Q_PROPERTY(qreal coverBlur READ coverBlur NOTIFY changed)
    Q_PROPERTY(qreal coverOpacity READ coverOpacity NOTIFY changed)
    Q_PROPERTY(qreal coverSaturation READ coverSaturation NOTIFY changed)
    Q_PROPERTY(qreal gradeStrength READ gradeStrength NOTIFY changed)
    Q_PROPERTY(qreal grain READ grain NOTIFY changed)
    Q_PROPERTY(qreal vignette READ vignette NOTIFY changed)
    Q_PROPERTY(qreal glassOpacity READ glassOpacity NOTIFY changed)
    Q_PROPERTY(qreal glassBorder READ glassBorder NOTIFY changed)
    Q_PROPERTY(int radius READ radius NOTIFY changed)
    Q_PROPERTY(qreal motion READ motion NOTIFY changed)
    Q_PROPERTY(qreal sceneIntensity READ sceneIntensity NOTIFY changed)

    // scene selection (cross-faded in QML by sceneMix during a switch)
    Q_PROPERTY(QString scene READ scene NOTIFY sceneChanged)
    Q_PROPERTY(QString sceneFrom READ sceneFrom NOTIFY sceneChanged)
    Q_PROPERTY(qreal sceneMix READ sceneMix NOTIFY changed)
    Q_PROPERTY(bool sceneAnimate READ sceneAnimate NOTIFY changed)

    // current theme + catalogue (for the switcher)
    Q_PROPERTY(QString themeId READ themeId NOTIFY sceneChanged)
    Q_PROPERTY(QString themeName READ themeName NOTIFY sceneChanged)
    Q_PROPERTY(QVariantList themes READ themes NOTIFY themesChanged)

    // user customisation knobs (-1 = follow theme). Persisted.
    Q_PROPERTY(qreal ovBlur READ ovBlur WRITE setOvBlur NOTIFY changed)
    Q_PROPERTY(qreal ovCoverOpacity READ ovCoverOpacity WRITE setOvCoverOpacity NOTIFY changed)
    Q_PROPERTY(qreal ovGrain READ ovGrain WRITE setOvGrain NOTIFY changed)
    Q_PROPERTY(qreal ovGlass READ ovGlass WRITE setOvGlass NOTIFY changed)
    Q_PROPERTY(qreal accentHue READ accentHue WRITE setAccentHue NOTIFY changed)

    // absolute knobs (no theme default to fall back to). Persisted.
    Q_PROPERTY(qreal discSpin READ discSpin WRITE setDiscSpin NOTIFY changed)
    Q_PROPERTY(bool reduceMotion READ reduceMotion WRITE setReduceMotion NOTIFY changed)
    Q_PROPERTY(qreal orbIntensity READ orbIntensity WRITE setOrbIntensity NOTIFY changed)
    Q_PROPERTY(qreal glowStrength READ glowStrength WRITE setGlowStrength NOTIFY changed)
    Q_PROPERTY(qreal bgOpacity READ bgOpacity WRITE setBgOpacity NOTIFY changed)
    Q_PROPERTY(qreal coverPresence READ coverPresence WRITE setCoverPresence NOTIFY changed)
    Q_PROPERTY(qreal ovVignette READ ovVignette WRITE setOvVignette NOTIFY changed)
    Q_PROPERTY(bool eqEffectOn READ eqEffectOn WRITE setEqEffectOn NOTIFY changed)
    Q_PROPERTY(bool lyricsHidden READ lyricsHidden WRITE setLyricsHidden NOTIFY changed)
    Q_PROPERTY(bool lyricsBlockMode READ lyricsBlockMode WRITE setLyricsBlockMode NOTIFY changed)

    // bundled typography (registered in C++ so it's consistent on every distro)
    Q_PROPERTY(int fontChoice READ fontChoice WRITE setFontChoice NOTIFY changed)
    Q_PROPERTY(QString displayFamily READ displayFamily NOTIFY changed)
    Q_PROPERTY(QString monoFamily READ monoFamily NOTIFY changed)

    Q_PROPERTY(bool notesOn READ notesOn WRITE setNotesOn NOTIFY changed)
    // whether the first-run tutorial has been shown (persisted)
    Q_PROPERTY(bool tutorialSeen READ tutorialSeen WRITE setTutorialSeen NOTIFY changed)

public:
    explicit ThemeManager(MprisController *player, QObject *parent = nullptr);

    // effective colours
    QColor base() const;
    QColor surface() const;
    QColor surfaceStrong() const;
    QColor accent() const;
    QColor accentAlt() const;
    QColor text() const;
    QColor textDim() const;
    QColor line() const;
    QColor gradeColor() const;

    // effective scalars
    qreal coverBlur() const { return blend(&ThemeDef::blur) * ((ovBlur() >= 0) ? m_ovBlur : 1.0); }
    qreal coverOpacity() const { return m_ovCoverOpacity >= 0 ? m_ovCoverOpacity : blend(&ThemeDef::coverOpacity); }
    qreal coverSaturation() const { return blend(&ThemeDef::coverSaturation); }
    qreal coverBrightness() const { return blend(&ThemeDef::coverBrightness); }
    qreal lumFloor() const { return blend(&ThemeDef::lumFloor); }
    qreal gradeStrength() const { return blend(&ThemeDef::gradeStrength); }
    qreal grain() const { return m_ovGrain >= 0 ? m_ovGrain : blend(&ThemeDef::grain); }
    qreal vignette() const { return m_ovVignette >= 0 ? m_ovVignette : blend(&ThemeDef::vignette); }
    qreal glassOpacity() const { return m_ovGlass >= 0 ? m_ovGlass : blend(&ThemeDef::glassOpacity); }
    qreal glassBorder() const { return blend(&ThemeDef::glassBorder); }
    int radius() const;
    qreal motion() const { return blend(&ThemeDef::motion); }
    qreal sceneIntensity() const { return blend(&ThemeDef::sceneIntensity); }

    QString scene() const { return m_cur.scene; }
    QString sceneFrom() const { return m_prev.scene; }
    qreal sceneMix() const { return m_mix; }
    // reduceMotion is a hard override: no ambient scene motion regardless of
    // what the active theme normally wants.
    bool sceneAnimate() const { return m_reduceMotion ? false : m_cur.sceneAnimate; }

    QString themeId() const { return m_cur.id; }
    QString themeName() const { return m_cur.name; }
    QVariantList themes() const;

    qreal ovBlur() const { return m_ovBlur; }
    qreal ovCoverOpacity() const { return m_ovCoverOpacity; }
    qreal ovGrain() const { return m_ovGrain; }
    qreal ovGlass() const { return m_ovGlass; }
    qreal accentHue() const { return m_accentHue; }
    void setOvBlur(qreal v);
    void setOvCoverOpacity(qreal v);
    void setOvGrain(qreal v);
    void setOvGlass(qreal v);
    void setAccentHue(qreal v);

    qreal discSpin() const { return m_discSpin; }
    void setDiscSpin(qreal v);
    bool reduceMotion() const { return m_reduceMotion; }
    void setReduceMotion(bool v);
    qreal orbIntensity() const { return m_orbIntensity; }
    void setOrbIntensity(qreal v);
    qreal glowStrength() const { return m_glowStrength; }
    void setGlowStrength(qreal v);
    qreal bgOpacity() const { return m_bgOpacity; }
    void setBgOpacity(qreal v);
    qreal coverPresence() const { return m_coverPresence; }
    void setCoverPresence(qreal v);
    qreal ovVignette() const { return m_ovVignette; }
    void setOvVignette(qreal v);
    bool eqEffectOn() const { return m_eqEffectOn; }
    void setEqEffectOn(bool v);
    bool lyricsHidden() const { return m_lyricsHidden; }
    void setLyricsHidden(bool v);
    bool lyricsBlockMode() const { return m_lyricsBlockMode; }
    void setLyricsBlockMode(bool v);

    int fontChoice() const { return m_fontChoice; }
    void setFontChoice(int v);
    QString displayFamily() const;
    QString monoFamily() const;
    bool notesOn() const { return m_notesOn; }
    void setNotesOn(bool v);
    bool tutorialSeen() const { return m_tutorialSeen; }
    void setTutorialSeen(bool v);

    Q_INVOKABLE void setTheme(const QString &id);
    Q_INVOKABLE void resetKnobs();
    // A swatch pair {c1,c2} used by the picker to preview a theme without loading it.
    Q_INVOKABLE QVariantList swatch(const QString &id) const;

signals:
    void changed();       // any effective token changed (palette tick or knob)
    void sceneChanged();  // the active theme id / scene changed
    void themesChanged(); // the catalogue changed (user theme added/removed)

private:
    void loadBuiltins();
    void loadUserThemes();
    void loadPrefs();
    void savePrefs();
    void selectInitial();
    void beginTransition(const ThemeDef &to);
    void onPaletteChanged();
    const ThemeDef *find(const QString &id) const;

    // Interpret one theme against the current album palette.
    QColor deriveBase(const ThemeDef &t) const;
    QColor deriveAccent(const ThemeDef &t) const;
    QColor deriveAccentAlt(const ThemeDef &t) const;
    QColor deriveText(const ThemeDef &t) const;
    QColor deriveGrade(const ThemeDef &t) const;

    // Blend a scalar field across the theme switch (m_prev -> m_cur by m_mix).
    qreal blend(double ThemeDef::*field) const {
        return m_prev.*field + (m_cur.*field - m_prev.*field) * m_mix;
    }

    MprisController *m_player;
    QVector<ThemeDef> m_defs;   // catalogue (built-ins + user)
    ThemeDef m_cur;             // active (target of any in-flight transition)
    ThemeDef m_prev;            // outgoing during a transition
    double m_mix = 1.0;         // 0 = fully prev, 1 = fully cur
    QVariantAnimation *m_anim = nullptr;

    // knobs (-1 sentinel = follow theme)
    qreal m_ovBlur = -1;         // stored as a multiplier when >=0
    qreal m_ovCoverOpacity = -1; // absolute 0..1
    qreal m_ovGrain = -1;        // absolute 0..1
    qreal m_ovGlass = -1;        // absolute 0..1 (glass frost / panel opacity)
    qreal m_accentHue = 0;       // extra hue rotation in degrees (-30..30)

    qreal m_discSpin = 1.0;          // absolute 0.2..3.0, disc rotation speed multiplier
    bool m_reduceMotion = false;     // hard-disables ambient/looping motion app-wide
    qreal m_orbIntensity = 0.85;     // absolute 0..1, strength of the floating-orb backdrop
    qreal m_glowStrength = 0.7;      // absolute 0..1, master strength of disc/UI glows
    qreal m_bgOpacity = 1.0;         // absolute 0..1, window background opacity (transparency)
    qreal m_coverPresence = 0.55;    // absolute 0..1, how present the blurred cover backdrop is
    qreal m_ovVignette = -1;         // -1 = follow theme, else absolute 0..1
    bool m_eqEffectOn = true;        // the EQ preset/band transition sweep
    bool m_lyricsHidden = false;     // user hid the lyrics pane
    bool m_lyricsBlockMode = true;   // lyrics rendered as big ASCII block letters

    // typography (families resolved from the bundled fonts registered at ctor)
    int m_fontChoice = 0;        // 0 Rubik · 1 Maple Mono · 2 JetBrains Mono · 3 System
    QString m_jbFamily;
    QString m_mapleFamily;
    QString m_rubikFamily;
    bool m_notesOn = true;       // ambient floating music notes
    bool m_tutorialSeen = false; // first-run tutorial has been shown
};

}  // namespace vespera
