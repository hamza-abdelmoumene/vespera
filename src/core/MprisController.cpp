#include "MprisController.h"

#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QImage>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QUrl>
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
    m_lastArtUrl = m_active ? m_active->artUrl() : QString();
    m_position = 0.0;
    fetchArt();
    emit activeChanged();
    emit positionChanged();
    managePolling();
}

void MprisController::onPlayerChanged() {
    auto *p = qobject_cast<MprisPlayer *>(sender());
    MprisPlayer *prev = m_active;
    chooseActive();
    if (m_active == prev && p == m_active) handleActiveUpdate();
}

void MprisController::handleActiveUpdate() {
    if (!m_active) return;
    const QString url = m_active->artUrl();
    if (url != m_lastArtUrl) {
        m_lastArtUrl = url;
        fetchArt();
    }
    emit activeChanged();
    managePolling();
}

void MprisController::onPlayerSeeked(double seconds) {
    if (qobject_cast<MprisPlayer *>(sender()) != m_active) return;
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
    if (!m_active) return;
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
    m_palette = p;
    emit paletteChanged();
}

// ---- demo mode (deterministic screenshots) ---------------------------------

void MprisController::loadDemo() {
    m_demo = true;
    m_position = 74.0;
    Palette p;
    p.base = QColor(0x0b, 0x0f, 0x24);
    p.accent = QColor(0x6f, 0xe9, 0xff);
    p.accentAlt = QColor(0xb4, 0x90, 0xff);
    p.text = QColor(0xea, 0xf2, 0xff);
    p.valid = true;
    m_palette = p;
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
    if (m_demo) return QStringLiteral("Lantern Weather");
    return m_active ? m_active->title() : QString();
}
QString MprisController::artist() const {
    if (m_demo) return QStringLiteral("Vesper Lake");
    return m_active ? m_active->artist() : QString();
}
QString MprisController::album() const {
    if (m_demo) return QStringLiteral("Evening Static");
    return m_active ? m_active->album() : QString();
}
QString MprisController::artUrl() const { return m_active ? m_active->artUrl() : QString(); }
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
