#include "LyricsService.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QSaveFile>
#include <QStandardPaths>
#include <QTimer>
#include <QUrl>
#include <QUrlQuery>
#include <algorithm>
#include <cmath>

namespace vespera {

namespace {
constexpr int kDebounceMs = 60;
constexpr qreal kIndexFudge = 0.1;
const QByteArray kLrclibUa = "vespera (https://github.com/hamza-abdelmoumene/vespera)";
const QByteArray kNetEaseUa =
    "Mozilla/5.0 (X11; Linux x86_64; rv:120.0) Gecko/20100101 Firefox/120.0";

bool containsCi(const QString &hay, const QString &needle) {
    return hay.contains(needle, Qt::CaseInsensitive);
}
}  // namespace

LyricsService::LyricsService(QObject *parent)
    : QObject(parent), m_nam(new QNetworkAccessManager(this)), m_debounce(new QTimer(this)) {
    m_debounce->setSingleShot(true);
    m_debounce->setInterval(kDebounceMs);
    connect(m_debounce, &QTimer::timeout, this, &LyricsService::doLoad);
    loadMap();
}

void LyricsService::setOffset(qreal value) {
    if (qFuzzyCompare(m_offset, value)) return;
    m_offset = value;
    emit offsetChanged();
    if (!m_settingFromPrefs) persistOffset();
}

int LyricsService::indexForTime(qreal time) const {
    if (m_lines.isEmpty()) return -1;
    const qreal target = time - m_offset + kIndexFudge;
    qsizetype lo = 0, hi = m_lines.size();
    while (lo < hi) {
        const qsizetype mid = lo + (hi - lo) / 2;
        if (m_lines.at(mid).time <= target)
            lo = mid + 1;
        else
            hi = mid;
    }
    return int(lo - 1);
}

qreal LyricsService::timeForIndex(int index) const {
    if (index < 0 || index >= m_lines.size()) return -1.0;
    return m_lines.at(index).time + m_offset;
}

void LyricsService::setTrack(const QString &artist, const QString &title, const QString &album,
                             qreal duration) {
    if (m_demo) return;
    const QString a = artist.trimmed();
    const QString t = title.trimmed();
    if (a == m_artist && t == m_title && album == m_album &&
        qFuzzyCompare(duration + 1.0, m_duration + 1.0))
        return;
    m_artist = a;
    m_title = t;
    m_album = album;
    m_duration = duration;
    emit trackChanged();
    scheduleLoad();
}

void LyricsService::clearTrack() {
    cancelInFlight();
    m_artist.clear();
    m_title.clear();
    m_album.clear();
    m_duration = 0.0;
    emit trackChanged();
    clearLines();
    setLoading(false);
}

void LyricsService::refresh() {
    if (m_demo) return;
    scheduleLoad();
}

void LyricsService::loadDemo() {
    m_demo = true;
    m_debounce->stop();
    cancelInFlight();
    m_artist = QStringLiteral("Vesper Lake");
    m_title = QStringLiteral("Lantern Weather");
    emit trackChanged();
    static const char *demo[] = {
        "we let the evening tune itself",       "a streetlight kept the second hand",
        "the radio hummed a lower key",         "and every window turned to gold",
        "we traced the map of what we knew",    "the quiet took its favourite chair",
        "and every star was ours to keep",      "till morning rearranged the sky",
        "we named the colour of the dark",      "and called it home for one more night",
        "the city learned our melody",          "we hummed it back, a little slow",
        "and let the lantern weather stay",     "until the dawn came soft and blue",
    };
    const int n = int(sizeof(demo) / sizeof(demo[0]));
    QVector<LyricLine> lines;
    for (int i = 0; i < n; ++i)
        lines.append(LyricLine{double(i) * 8.0, QLatin1String(demo[i])});
    m_offset = 0.0;
    setLines(std::move(lines));
    setLoading(false);
}

void LyricsService::scheduleLoad() { m_debounce->start(); }

void LyricsService::doLoad() {
    if (m_artist.isEmpty() && m_title.isEmpty()) {
        clearLines();
        setLoading(false);
        return;
    }
    cancelInFlight();
    const int reqId = ++m_requestId;
    setLoading(true);
    clearLines();

    // restore persisted per-track offset
    m_settingFromPrefs = true;
    setOffset(m_map.value(trackKey()).toObject().value(QStringLiteral("offset")).toDouble(0.0));
    m_settingFromPrefs = false;

    tryLrclibGet(reqId);
}

QNetworkReply *LyricsService::getJson(const QUrl &url, const QByteArray &userAgent,
                                      const QByteArray &referer) {
    QNetworkRequest req(url);
    req.setAttribute(QNetworkRequest::CacheLoadControlAttribute, QNetworkRequest::AlwaysNetwork);
    req.setRawHeader("Accept", "application/json");
    req.setRawHeader("User-Agent", userAgent);
    if (!referer.isEmpty()) req.setRawHeader("Referer", referer);
    return m_nam->get(req);
}

void LyricsService::trackReply(int reqId, QNetworkReply *reply) {
    if (reply) m_pending[reqId].append(QPointer<QNetworkReply>(reply));
}

void LyricsService::cancelInFlight() {
    for (auto it = m_pending.begin(); it != m_pending.end(); ++it)
        for (auto &ptr : it.value())
            if (auto *r = ptr.data()) {
                r->abort();
                r->deleteLater();
            }
    m_pending.clear();
}

void LyricsService::tryLrclibGet(int reqId) {
    QUrl url(QStringLiteral("https://lrclib.net/api/get"));
    QUrlQuery q;
    q.addQueryItem(QStringLiteral("track_name"), m_title);
    q.addQueryItem(QStringLiteral("artist_name"), m_artist);
    if (!m_album.isEmpty()) q.addQueryItem(QStringLiteral("album_name"), m_album);
    if (m_duration > 0)
        q.addQueryItem(QStringLiteral("duration"), QString::number(qRound(m_duration)));
    url.setQuery(q);

    auto *reply = getJson(url, kLrclibUa);
    trackReply(reqId, reply);
    connect(reply, &QNetworkReply::finished, this, [this, reply, reqId] {
        reply->deleteLater();
        if (reqId != m_requestId) return;
        QString synced;
        if (reply->error() == QNetworkReply::NoError)
            synced = QJsonDocument::fromJson(reply->readAll())
                         .object()
                         .value(QStringLiteral("syncedLyrics"))
                         .toString();
        const auto lines = parseLrc(synced);
        if (!lines.isEmpty()) {
            setLines(lines);
            setLoading(false);
        } else {
            tryLrclibSearch(reqId);
        }
    });
}

void LyricsService::tryLrclibSearch(int reqId) {
    QUrl url(QStringLiteral("https://lrclib.net/api/search"));
    QUrlQuery q;
    q.addQueryItem(QStringLiteral("track_name"), m_title);
    q.addQueryItem(QStringLiteral("artist_name"), m_artist);
    url.setQuery(q);

    auto *reply = getJson(url, kLrclibUa);
    trackReply(reqId, reply);
    connect(reply, &QNetworkReply::finished, this, [this, reply, reqId] {
        reply->deleteLater();
        if (reqId != m_requestId) return;
        if (reply->error() != QNetworkReply::NoError) {
            tryNetEase(reqId);
            return;
        }
        const QJsonArray arr = QJsonDocument::fromJson(reply->readAll()).array();
        // Prefer the closest duration match that actually has synced lyrics.
        QString best;
        qreal bestDelta = 1e9;
        for (const auto &v : arr) {
            const QJsonObject o = v.toObject();
            const QString synced = o.value(QStringLiteral("syncedLyrics")).toString();
            if (synced.isEmpty()) continue;
            const qreal dur = o.value(QStringLiteral("duration")).toDouble();
            const qreal delta = m_duration > 0 ? std::fabs(dur - m_duration) : 0.0;
            if (delta < bestDelta) {
                bestDelta = delta;
                best = synced;
            }
        }
        const auto lines = parseLrc(best);
        if (!lines.isEmpty()) {
            setLines(lines);
            setLoading(false);
        } else {
            tryNetEase(reqId);
        }
    });
}

void LyricsService::tryNetEase(int reqId) {
    QUrl url(QStringLiteral("https://music.163.com/api/search/get"));
    QUrlQuery q;
    q.addQueryItem(QStringLiteral("s"), m_title + QLatin1Char(' ') + m_artist);
    q.addQueryItem(QStringLiteral("type"), QStringLiteral("1"));
    q.addQueryItem(QStringLiteral("limit"), QStringLiteral("5"));
    url.setQuery(q);

    auto *reply = getJson(url, kNetEaseUa, "https://music.163.com/");
    trackReply(reqId, reply);
    connect(reply, &QNetworkReply::finished, this, [this, reply, reqId] {
        reply->deleteLater();
        if (reqId != m_requestId) return;
        if (reply->error() != QNetworkReply::NoError) {
            setLoading(false);
            return;
        }
        const QJsonArray songs = QJsonDocument::fromJson(reply->readAll())
                                     .object()
                                     .value(QStringLiteral("result"))
                                     .toObject()
                                     .value(QStringLiteral("songs"))
                                     .toArray();
        qint64 bestId = -1;
        for (const auto &v : songs) {
            const QJsonObject s = v.toObject();
            const QJsonArray artists = s.value(QStringLiteral("artists")).toArray();
            if (artists.isEmpty()) continue;
            const QString sArtist = artists.first().toObject().value(QStringLiteral("name")).toString();
            if (containsCi(m_artist, sArtist) || containsCi(sArtist, m_artist)) {
                bestId = qint64(s.value(QStringLiteral("id")).toDouble());
                break;
            }
        }
        if (bestId < 0) {
            setLoading(false);
            return;
        }
        QUrl lurl(QStringLiteral("https://music.163.com/api/song/lyric"));
        QUrlQuery lq;
        lq.addQueryItem(QStringLiteral("id"), QString::number(bestId));
        lq.addQueryItem(QStringLiteral("lv"), QStringLiteral("1"));
        lq.addQueryItem(QStringLiteral("kv"), QStringLiteral("1"));
        lq.addQueryItem(QStringLiteral("tv"), QStringLiteral("-1"));
        lurl.setQuery(lq);
        auto *lr = getJson(lurl, kNetEaseUa, "https://music.163.com/");
        trackReply(reqId, lr);
        connect(lr, &QNetworkReply::finished, this, [this, lr, reqId] {
            lr->deleteLater();
            if (reqId != m_requestId) return;
            QString lrc;
            if (lr->error() == QNetworkReply::NoError)
                lrc = QJsonDocument::fromJson(lr->readAll())
                          .object()
                          .value(QStringLiteral("lrc"))
                          .toObject()
                          .value(QStringLiteral("lyric"))
                          .toString();
            const auto lines = parseLrc(lrc);
            if (!lines.isEmpty()) setLines(lines);
            setLoading(false);
        });
    });
}

void LyricsService::setLoading(bool value) {
    if (m_loading == value) return;
    m_loading = value;
    emit loadingChanged();
}

void LyricsService::setLines(QVector<LyricLine> lines) {
    std::sort(lines.begin(), lines.end(),
              [](const LyricLine &a, const LyricLine &b) { return a.time < b.time; });
    m_lines = std::move(lines);
    QStringList list;
    list.reserve(m_lines.size());
    for (const auto &l : std::as_const(m_lines)) list.append(l.text);
    m_lyrics = std::move(list);
    emit lyricsChanged();
    const bool has = !m_lines.isEmpty();
    if (has != m_hasLyrics) {
        m_hasLyrics = has;
        emit hasLyricsChanged();
    }
}

void LyricsService::clearLines() {
    // Keep m_lyrics so the QML fade-out can run; just flip availability.
    if (m_hasLyrics) {
        m_hasLyrics = false;
        emit hasLyricsChanged();
    }
}

QVector<LyricLine> LyricsService::parseLrc(const QString &text) {
    QVector<LyricLine> result;
    if (text.isEmpty()) return result;

    static const QRegularExpression timeRe(QStringLiteral("\\[(\\d+):(\\d+(?:\\.\\d+)?)\\]"));
    static const QStringList creditKeywords = {
        QStringLiteral("作词"),   QStringLiteral("作曲"),     QStringLiteral("编曲"),
        QStringLiteral("制作"),   QStringLiteral("词："),     QStringLiteral("曲："),
        QStringLiteral("Lyricist"), QStringLiteral("Composer"), QStringLiteral("Arranger"),
        QStringLiteral("Producer"), QStringLiteral("Mixing"),   QStringLiteral("Mastering"),
    };

    const QStringList lines = text.split(QLatin1Char('\n'));
    for (const QString &line : lines) {
        QList<QRegularExpressionMatch> matches;
        auto it = timeRe.globalMatch(line);
        while (it.hasNext()) matches.append(it.next());
        if (matches.isEmpty()) continue;

        QString lyric = line;
        lyric.replace(timeRe, QString());
        lyric = lyric.trimmed();

        const qreal firstTime =
            matches.first().captured(1).toInt() * 60.0 + matches.first().captured(2).toDouble();
        if (firstTime < 20.0) {
            bool isCredit = false;
            for (const QString &k : creditKeywords)
                if (lyric.contains(k, Qt::CaseInsensitive)) {
                    isCredit = true;
                    break;
                }
            if (isCredit && (lyric.contains(QLatin1Char(':')) || lyric.contains(QChar(0xFF1A)) ||
                             lyric.size() < 25))
                continue;
        }

        for (const auto &m : std::as_const(matches)) {
            const qreal t = m.captured(1).toInt() * 60.0 + m.captured(2).toDouble();
            result.append(LyricLine{t, lyric});
        }
    }

    std::sort(result.begin(), result.end(),
              [](const LyricLine &a, const LyricLine &b) { return a.time < b.time; });
    return result;
}

// ---- per-track offset persistence -----------------------------------------

QString LyricsService::trackKey() const {
    if (m_artist.isEmpty() && m_title.isEmpty()) return {};
    return m_artist + QStringLiteral(" - ") + m_title;
}

QString LyricsService::mapPath() const {
    QString base = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation);
    if (base.isEmpty())
        base = QDir::homePath() + QStringLiteral("/.local/share/vespera");
    return base + QStringLiteral("/lyrics_map.json");
}

void LyricsService::loadMap() {
    m_map = {};
    QFile f(mapPath());
    if (f.open(QIODevice::ReadOnly)) {
        m_map = QJsonDocument::fromJson(f.readAll()).object();
    }
    m_mapLoaded = true;
}

void LyricsService::persistOffset() {
    if (!m_mapLoaded || trackKey().isEmpty()) return;
    QJsonObject entry = m_map.value(trackKey()).toObject();
    entry.insert(QStringLiteral("offset"), m_offset);
    m_map.insert(trackKey(), entry);

    const QString path = mapPath();
    QDir().mkpath(QFileInfo(path).absolutePath());
    QSaveFile out(path);
    if (!out.open(QIODevice::WriteOnly | QIODevice::Truncate)) return;
    const QByteArray bytes = QJsonDocument(m_map).toJson(QJsonDocument::Compact);
    if (out.write(bytes) == bytes.size()) out.commit();
}

}  // namespace vespera
