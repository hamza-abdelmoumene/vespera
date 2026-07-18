// Synced-lyrics engine — a native, dependency-free port of the caelestia
// Lyrics service. lrclib is the primary backend (exact match by duration, then
// search); NetEase is a fallback. LRC is parsed into timed lines; the current
// line is found by binary search with a small fudge and a per-track offset that
// is persisted (keyed by "artist - title").
#pragma once

#include <QHash>
#include <QJsonObject>
#include <QObject>
#include <QPointer>
#include <QString>
#include <QStringList>
#include <QVector>

class QNetworkAccessManager;
class QNetworkReply;
class QTimer;
class QUrl;

namespace vespera {

struct LyricLine {
    qreal time = 0.0;
    QString text;
};

class LyricsService : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(bool hasLyrics READ hasLyrics NOTIFY hasLyricsChanged)
    Q_PROPERTY(QStringList lyrics READ lyrics NOTIFY lyricsChanged)
    Q_PROPERTY(qreal offset READ offset WRITE setOffset NOTIFY offsetChanged)
    Q_PROPERTY(QString trackArtist READ trackArtist NOTIFY trackChanged)
    Q_PROPERTY(QString trackTitle READ trackTitle NOTIFY trackChanged)

public:
    explicit LyricsService(QObject *parent = nullptr);

    bool loading() const { return m_loading; }
    bool hasLyrics() const { return m_hasLyrics; }
    QStringList lyrics() const { return m_lyrics; }
    qreal offset() const { return m_offset; }
    QString trackArtist() const { return m_artist; }
    QString trackTitle() const { return m_title; }
    void setOffset(qreal value);

    Q_INVOKABLE void setTrack(const QString &artist, const QString &title,
                              const QString &album = QString(), qreal duration = 0.0);
    Q_INVOKABLE void clearTrack();
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void nudgeOffset(qreal delta) { setOffset(m_offset + delta); }
    Q_INVOKABLE void loadDemo();  // fixed clean lyrics for screenshots

    // Index of the line active at `time` (accounts for offset), or -1.
    Q_INVOKABLE int indexForTime(qreal time) const;
    // Start time (with offset) of a line, for click-to-seek, or -1.
    Q_INVOKABLE qreal timeForIndex(int index) const;

signals:
    void loadingChanged();
    void hasLyricsChanged();
    void lyricsChanged();
    void offsetChanged();
    void trackChanged();

private:
    void scheduleLoad();
    void doLoad();
    void tryLrclibGet(int reqId);
    void tryLrclibSearch(int reqId);
    void tryNetEase(int reqId);
    QNetworkReply *getJson(const QUrl &url, const QByteArray &userAgent,
                           const QByteArray &referer = {});
    void trackReply(int reqId, QNetworkReply *reply);
    void cancelInFlight();

    void setLoading(bool value);
    void setLines(QVector<LyricLine> lines);
    void clearLines();  // keep old text but flip hasLyrics (so fades can run)

    static QVector<LyricLine> parseLrc(const QString &text);

    // per-track offset persistence
    QString trackKey() const;
    QString mapPath() const;
    void loadMap();
    void persistOffset();

    QNetworkAccessManager *m_nam = nullptr;
    QTimer *m_debounce = nullptr;

    QString m_artist;
    QString m_title;
    QString m_album;
    qreal m_duration = 0.0;

    QVector<LyricLine> m_lines;
    QStringList m_lyrics;
    bool m_loading = false;
    bool m_hasLyrics = false;
    qreal m_offset = 0.0;

    int m_requestId = 0;
    QHash<int, QVector<QPointer<QNetworkReply>>> m_pending;

    QJsonObject m_map;      // track-key -> { offset }
    bool m_mapLoaded = false;
    bool m_settingFromPrefs = false;
    bool m_demo = false;    // screenshot mode: ignore track pushes / fetches
};

}  // namespace vespera
