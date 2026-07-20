// A single MPRIS player on the session bus (one org.mpris.MediaPlayer2.* name).
//
// Wraps the org.mpris.MediaPlayer2 and .Player interfaces, tracks metadata /
// playback state via org.freedesktop.DBus.Properties.PropertiesChanged, and
// exposes controls. Position is not push-based in MPRIS, so it is fetched on
// demand (the controller polls while playing) and refined via Seeked.
#pragma once

#include <QObject>
#include <QString>
#include <QVariantMap>

namespace vespera {

class MprisPlayer : public QObject {
    Q_OBJECT
public:
    explicit MprisPlayer(const QString &service, QObject *parent = nullptr);

    QString service() const { return m_service; }
    QString identity() const { return m_identity; }
    QString desktopEntry() const { return m_desktopEntry; }

    QString playbackStatus() const { return m_status; }  // Playing/Paused/Stopped
    bool isPlaying() const { return m_status == QLatin1String("Playing"); }

    QString title() const;
    QString artist() const;
    QString album() const;
    QString artUrl() const;
    QString trackId() const;
    double lengthSeconds() const;  // from mpris:length (microseconds)
    bool hasTrack() const { return !title().isEmpty() || !artUrl().isEmpty(); }

    bool canGoNext() const { return m_canGoNext; }
    bool canGoPrevious() const { return m_canGoPrevious; }
    bool canSeek() const { return m_canSeek; }
    bool canControl() const { return m_canControl; }

    double volume() const { return m_volume; }        // 0..1
    bool shuffle() const { return m_shuffle; }
    QString loopStatus() const { return m_loopStatus; }  // None / Track / Playlist
    void setVolume(double v);
    void setShuffle(bool on);
    void setLoopStatus(const QString &status);

    // Fetch the live position (seconds). Returns -1 on failure.
    double positionSeconds();

    void playPause();
    void next();
    void previous();
    void seekBy(double seconds);   // relative
    void seekTo(double seconds);   // absolute (uses SetPosition + trackid)

signals:
    void changed();               // metadata / status / capabilities changed
    void seeked(double seconds);  // player reported a new position

private slots:
    void onPropertiesChanged(const QString &interface,
                             const QVariantMap &changed,
                             const QStringList &invalidated);
    void onSeeked(qlonglong positionUs);

private:
    void refreshAll();
    void applyPlayerProps(const QVariantMap &props);
    void setPlayerProp(const QString &name, const QVariant &value);

    QString m_service;
    QString m_identity;
    QString m_desktopEntry;
    QString m_status = QStringLiteral("Stopped");
    QVariantMap m_metadata;
    bool m_canGoNext = false;
    bool m_canGoPrevious = false;
    bool m_canSeek = false;
    bool m_canControl = false;
    double m_volume = 1.0;
    bool m_shuffle = false;
    QString m_loopStatus = QStringLiteral("None");
};

}  // namespace vespera
