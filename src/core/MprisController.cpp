#include "MprisController.h"

#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QEasingCurve>
#include <QImage>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QUrl>
#include <QVariantAnimation>
#include <algorithm>

#include "MprisPlayer.h"

namespace vespera {

namespace {
const QString kMprisPrefix = QStringLiteral("org.mpris.MediaPlayer2.");

bool looksLikeBrowser(const QString &haystack) {
    static const char *needles[] = {"chrom",  "firefox", "mozilla", "brave", "edge",
                                    "vivaldi", "opera",  "epiphany", "webkit"};
    for (const char *n : needles)
        if (haystack.contains(QLatin1String(n))) return true;
    return false;
}

QColor lerpColor(const QColor &a, const QColor &b, double t) {
    return QColor::fromRgbF(a.redF() + (b.redF() - a.redF()) * t,
                            a.greenF() + (b.greenF() - a.greenF()) * t,
                            a.blueF() + (b.blueF() - a.blueF()) * t,
                            a.alphaF() + (b.alphaF() - a.alphaF()) * t);
}

Palette lerpPalette(const Palette &a, const Palette &b, double t) {
    Palette p = b;  // carry the target's validity/metadata
    p.accent = lerpColor(a.accent, b.accent, t);
    p.accentAlt = lerpColor(a.accentAlt, b.accentAlt, t);
    p.base = lerpColor(a.base, b.base, t);
    p.text = lerpColor(a.text, b.text, t);
    return p;
}
}  // namespace

MprisController::MprisController(QObject *parent) : QObject(parent) {
    m_net = new QNetworkAccessManager(this);

    m_posTimer.setInterval(500);
    connect(&m_posTimer, &QTimer::timeout, this, &MprisController::pollPosition);

    auto bus = QDBusConnection::sessionBus();
    bus.connect(QStringLiteral("org.freedesktop.DBus"), QStringLiteral("/org/freedesktop/DBus"),
                QStringLiteral("org.freedesktop.DBus"), QStringLiteral("NameOwnerChanged"), this,
                SLOT(onNameOwnerChanged(QString, QString, QString)));

    refreshPlayers();
}

MprisController::~MprisController() = default;

void MprisController::refreshPlayers() {
    auto bus = QDBusConnection::sessionBus();
    if (!bus.interface()) return;
    const QStringList names = bus.interface()->registeredServiceNames().value();
    for (const QString &name : names)
        if (name.startsWith(kMprisPrefix)) addPlayer(name);
    chooseActive();
}

void MprisController::addPlayer(const QString &service) {
    if (m_players.contains(service)) return;
    auto *p = new MprisPlayer(service, this);
    m_players.insert(service, p);
    connect(p, &MprisPlayer::changed, this, &MprisController::onPlayerChanged);
    connect(p, &MprisPlayer::seeked, this, &MprisController::onPlayerSeeked);
    emit playersChanged();
}

void MprisController::removePlayer(const QString &service) {
    auto it = m_players.find(service);
    if (it == m_players.end()) return;
    MprisPlayer *p = it.value();
    m_players.erase(it);
    if (p == m_active) m_active = nullptr;
    p->deleteLater();
    emit playersChanged();
    chooseActive();
    if (!m_active) {
        applyPalette(PaletteExtractor::defaults());
        m_position = 0.0;
        emit activeChanged();
        emit positionChanged();
        managePolling();
    }
}

void MprisController::onNameOwnerChanged(const QString &name, const QString &oldOwner,
                                        const QString &newOwner) {
    if (m_demo) return;  // screenshot mode is frozen; ignore live players
    if (!name.startsWith(kMprisPrefix)) return;
    if (newOwner.isEmpty() && !oldOwner.isEmpty()) {
        removePlayer(name);
    } else if (oldOwner.isEmpty() && !newOwner.isEmpty()) {
        addPlayer(name);
        chooseActive();
    }
}

double MprisController::scoreOf(MprisPlayer *p) const {
    double s = 0.0;
    const QString id =
        (p->identity() + QLatin1Char(' ') + p->desktopEntry() + QLatin1Char(' ') + p->service())
            .toLower();

    const QString st = p->playbackStatus();
    if (st == QLatin1String("Playing"))
        s += 1000;
    else if (st == QLatin1String("Paused"))
        s += 400;
    else
        s += 50;

    if (p->hasTrack()) s += 120;
    if (looksLikeBrowser(id)) s -= 600;
    if (p == m_active) s += 60;  // sticky: avoid flapping between two players
    return s;
}

void MprisController::chooseActive() {
    MprisPlayer *best = nullptr;
    double bestScore = 0.0;  // require strictly positive to be "active"
    for (MprisPlayer *p : std::as_const(m_players)) {
        const double s = scoreOf(p);
        if (s > bestScore) {
            bestScore = s;
            best = p;
        }
    }
    if (best == m_active) return;
    m_active = best;
    onActiveSwitched();
}

void MprisController::onActiveSwitched() {
    if (m_demo) return;
    m_lastArtUrl = m_active ? m_active->artUrl() : QString();
    m_position = 0.0;
    fetchArt();
    emit activeChanged();
    emit positionChanged();
    managePolling();
}

void MprisController::onPlayerChanged() {
    if (m_demo) return;
    auto *p = qobject_cast<MprisPlayer *>(sender());
    MprisPlayer *prev = m_active;
    chooseActive();
    if (m_active == prev && p == m_active) handleActiveUpdate();
}

void MprisController::handleActiveUpdate() {
    if (m_demo || !m_active) return;
    const QString url = m_active->artUrl();
    if (url != m_lastArtUrl) {
        m_lastArtUrl = url;
        fetchArt();
    }
    emit activeChanged();
    managePolling();
}

void MprisController::onPlayerSeeked(double seconds) {
    if (m_demo || qobject_cast<MprisPlayer *>(sender()) != m_active) return;
    m_position = seconds;
    emit positionChanged();
}

void MprisController::managePolling() {
    if (m_active && m_active->isPlaying()) {
        if (!m_posTimer.isActive()) m_posTimer.start();
        pollPosition();
    } else {
        m_posTimer.stop();
    }
}

void MprisController::pollPosition() {
    if (m_demo || !m_active) return;
    const double pos = m_active->positionSeconds();
    if (pos >= 0.0) {
        m_position = pos;
        emit positionChanged();
    }
}

void MprisController::fetchArt() {
    const quint64 token = ++m_artToken;
    const QString url = m_active ? m_active->artUrl() : QString();

    if (url.isEmpty()) {
        applyPalette(PaletteExtractor::defaults());
        return;
    }

    const QUrl u(url);
    if (u.isLocalFile() || url.startsWith(QLatin1Char('/'))) {
        const QImage img(u.isLocalFile() ? u.toLocalFile() : url);
        applyPalette(PaletteExtractor::extract(img));
        return;
    }

    if (u.scheme() == QLatin1String("http") || u.scheme() == QLatin1String("https")) {
        QNetworkRequest req(u);
        req.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::NoLessSafeRedirectPolicy);
        QNetworkReply *reply = m_net->get(req);
        connect(reply, &QNetworkReply::finished, this, [this, reply, token]() {
            reply->deleteLater();
            if (token != m_artToken) return;  // superseded by a newer track
            if (reply->error() != QNetworkReply::NoError) {
                applyPalette(PaletteExtractor::defaults());
                return;
            }
            QImage img;
            img.loadFromData(reply->readAll());
            applyPalette(PaletteExtractor::extract(img));
        });
        return;
    }

    applyPalette(PaletteExtractor::defaults());
}

void MprisController::applyPalette(const Palette &p) {
    if (m_demo) return;  // demo palette is fixed; ignore any late live art
    m_palette = p;

    // First palette of the session snaps into place — no fade-in from the
    // default cyan on launch.
    if (!m_paletteReady) {
        m_paletteReady = true;
        m_shown = p;
        emit paletteChanged();
        return;
    }
    // Already showing these colours — nothing to animate.
    if (m_shown.accent == p.accent && m_shown.accentAlt == p.accentAlt &&
        m_shown.base == p.base && m_shown.text == p.text)
        return;

    // Cross-fade every palette-derived colour toward the new album's palette in
    // one central pass — equivalent to a ColorAnimation on each, but driven from
    // the source so the whole UI shifts in unison. Self-terminating: costs
    // nothing once the track has settled.
    m_fromPalette = m_shown;
    if (!m_paletteAnim) {
        m_paletteAnim = new QVariantAnimation(this);
        m_paletteAnim->setStartValue(0.0);
        m_paletteAnim->setEndValue(1.0);
        m_paletteAnim->setDuration(560);
        m_paletteAnim->setEasingCurve(QEasingCurve::InOutQuad);
        connect(m_paletteAnim, &QVariantAnimation::valueChanged, this,
                [this](const QVariant &v) {
                    m_shown = lerpPalette(m_fromPalette, m_palette, v.toDouble());
                    emit paletteChanged();
                });
    }
    m_paletteAnim->stop();
    m_paletteAnim->start();
}

// ---- demo mode (deterministic screenshots) ---------------------------------

void MprisController::loadDemo(int variant) {
    m_demo = true;
    m_demoVariant = variant;
    if (m_paletteAnim) m_paletteAnim->stop();  // freeze any in-flight cross-fade
    m_position = 74.0;
    Palette p;
    p.valid = true;
    if (variant == 1) {
        // A warm, amber-lit track — clearly different colours so the per-track
        // recolour is visible when compared against variant 0.
        p.base = QColor(0x1a, 0x11, 0x1c);
        p.accent = QColor(0xf6, 0xb2, 0x6b);
        p.accentAlt = QColor(0xf0, 0x7d, 0x9c);
        p.text = QColor(0xfb, 0xef, 0xe8);
    } else {
        p.base = QColor(0x0b, 0x0f, 0x24);
        p.accent = QColor(0x6f, 0xe9, 0xff);
        p.accentAlt = QColor(0xb4, 0x90, 0xff);
        p.text = QColor(0xea, 0xf2, 0xff);
    }
    m_palette = p;
    m_shown = p;  // demo snaps (single frame), no cross-fade
    m_paletteReady = true;
    emit paletteChanged();
    emit activeChanged();
    emit positionChanged();
}

// ---- active-player pass-throughs -------------------------------------------

QString MprisController::playerName() const {
    if (m_demo) return QStringLiteral("Spotify");
    return m_active ? m_active->identity() : QString();
}
QString MprisController::title() const {
    if (m_demo) return m_demoVariant == 1 ? QStringLiteral("Amber in the Dark")
                                          : QStringLiteral("Lantern Weather");
    return m_active ? m_active->title() : QString();
}
QString MprisController::artist() const {
    if (m_demo) return m_demoVariant == 1 ? QStringLiteral("Kestrel Lume")
                                          : QStringLiteral("Vesper Lake");
    return m_active ? m_active->artist() : QString();
}
QString MprisController::album() const {
    if (m_demo) return m_demoVariant == 1 ? QStringLiteral("Slow Ember")
                                          : QStringLiteral("Evening Static");
    return m_active ? m_active->album() : QString();
}
// In demo mode we never surface the live player's art — that would leak the
// user's actually-playing (possibly explicit) cover into "clean" screenshots;
// the cover falls back to the geometric placeholder instead.
QString MprisController::artUrl() const {
    if (m_demo) return QString();
    return m_active ? m_active->artUrl() : QString();
}
QString MprisController::playbackStatus() const {
    if (m_demo) return QStringLiteral("Playing");
    return m_active ? m_active->playbackStatus() : QStringLiteral("Stopped");
}
bool MprisController::playing() const { return m_demo || (m_active && m_active->isPlaying()); }
bool MprisController::canGoNext() const { return m_demo || (m_active && m_active->canGoNext()); }
bool MprisController::canGoPrevious() const {
    return m_demo || (m_active && m_active->canGoPrevious());
}
bool MprisController::canSeek() const { return m_demo || (m_active && m_active->canSeek()); }
double MprisController::length() const {
    if (m_demo) return 227.0;
    return m_active ? m_active->lengthSeconds() : 0.0;
}

void MprisController::playPause() {
    if (m_active) m_active->playPause();
}
void MprisController::next() {
    if (m_active) m_active->next();
}
void MprisController::previous() {
    if (m_active) m_active->previous();
}
void MprisController::seekTo(double seconds) {
    if (m_active) m_active->seekTo(seconds);
}
void MprisController::seekBy(double seconds) {
    if (m_active) m_active->seekBy(seconds);
}

}  // namespace vespera
