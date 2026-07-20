// The QML-facing MPRIS aggregator.
//
// Enumerates every org.mpris.MediaPlayer2.* name on the session bus, tracks
// them appearing/disappearing, and picks an "active" player via a ranking that
// de-prioritises browsers. Exposes the active player's metadata, playback
// state, live position, and an album-derived colour palette to QML.
#pragma once

#include <QColor>
#include <QHash>
#include <QObject>
#include <QString>
#include <QTimer>

#include "PaletteExtractor.h"

class QNetworkAccessManager;
class QNetworkReply;
class QVariantAnimation;

namespace vespera {

class MprisPlayer;

class MprisController : public QObject {
    Q_OBJECT

    Q_PROPERTY(bool hasPlayer READ hasPlayer NOTIFY activeChanged)
    Q_PROPERTY(int playerCount READ playerCount NOTIFY playersChanged)
    Q_PROPERTY(QString playerName READ playerName NOTIFY activeChanged)

    Q_PROPERTY(QString title READ title NOTIFY activeChanged)
    Q_PROPERTY(QString artist READ artist NOTIFY activeChanged)
    Q_PROPERTY(QString album READ album NOTIFY activeChanged)
    Q_PROPERTY(QString artUrl READ artUrl NOTIFY activeChanged)

    Q_PROPERTY(QString playbackStatus READ playbackStatus NOTIFY activeChanged)
    Q_PROPERTY(bool playing READ playing NOTIFY activeChanged)
    Q_PROPERTY(bool canGoNext READ canGoNext NOTIFY activeChanged)
    Q_PROPERTY(bool canGoPrevious READ canGoPrevious NOTIFY activeChanged)
    Q_PROPERTY(bool canSeek READ canSeek NOTIFY activeChanged)

    Q_PROPERTY(double position READ position NOTIFY positionChanged)
    Q_PROPERTY(double length READ length NOTIFY activeChanged)

    Q_PROPERTY(double volume READ volume NOTIFY activeChanged)
    Q_PROPERTY(bool shuffle READ shuffle NOTIFY activeChanged)
    Q_PROPERTY(QString loopStatus READ loopStatus NOTIFY activeChanged)

    Q_PROPERTY(QColor accent READ accent NOTIFY paletteChanged)
    Q_PROPERTY(QColor accentAlt READ accentAlt NOTIFY paletteChanged)
    Q_PROPERTY(QColor base READ base NOTIFY paletteChanged)
    Q_PROPERTY(QColor text READ text NOTIFY paletteChanged)

public:
    explicit MprisController(QObject *parent = nullptr);
    ~MprisController() override;

    bool hasPlayer() const { return m_demo || m_active != nullptr; }
    int playerCount() const { return int(m_players.size()); }
    QString playerName() const;

    QString title() const;
    QString artist() const;
    QString album() const;
    QString artUrl() const;

    QString playbackStatus() const;
    bool playing() const;
    bool canGoNext() const;
    bool canGoPrevious() const;
    bool canSeek() const;

    double position() const { return m_position; }
    double length() const;

    double volume() const;
    bool shuffle() const;
    QString loopStatus() const;

    // The *shown* palette is a cross-fade toward the target (see applyPalette);
    // reading it here is what makes the whole UI recolour smoothly per track.
    QColor accent() const { return m_shown.accent; }
    QColor accentAlt() const { return m_shown.accentAlt; }
    QColor base() const { return m_shown.base; }
    QColor text() const { return m_shown.text; }

    Q_INVOKABLE void playPause();
    Q_INVOKABLE void next();
    Q_INVOKABLE void previous();
    Q_INVOKABLE void seekTo(double seconds);
    Q_INVOKABLE void seekBy(double seconds);
    Q_INVOKABLE void setVolume(double v);
    Q_INVOKABLE void toggleShuffle();
    Q_INVOKABLE void cycleLoop();

    // Deterministic fake state for screenshots (see `vespera --capture ... demo`).
    // `variant` selects one of a couple of invented tracks + palettes so the
    // per-track recolour can be demonstrated (demo = 0, demo2 = 1).
    Q_INVOKABLE void loadDemo(int variant = 0);

signals:
    void activeChanged();
    void playersChanged();
    void positionChanged();
    void paletteChanged();
    // The decoded cover image for the active track (null when there's no art),
    // used to feed the blurred backdrop. Emitted alongside palette extraction.
    void artImageReady(const QImage &image);

private slots:
    void onNameOwnerChanged(const QString &name, const QString &oldOwner,
                            const QString &newOwner);
    void onPlayerChanged();
    void onPlayerSeeked(double seconds);
    void pollPosition();

private:
    void refreshPlayers();
    void addPlayer(const QString &service);
    void removePlayer(const QString &service);
    double scoreOf(MprisPlayer *p) const;
    void chooseActive();
    void onActiveSwitched();
    void handleActiveUpdate();
    void managePolling();
    void fetchArt();
    void applyPalette(const Palette &p);

    QHash<QString, MprisPlayer *> m_players;  // service name -> player
    MprisPlayer *m_active = nullptr;
    QString m_lastArtUrl;
    double m_position = 0.0;

    // Palette cross-fade: m_palette is the target, m_shown is what QML reads and
    // is animated toward the target over ~half a second so a track change washes
    // the whole UI to the new album colours instead of snapping.
    Palette m_palette = PaletteExtractor::defaults();
    Palette m_shown = PaletteExtractor::defaults();
    Palette m_fromPalette = PaletteExtractor::defaults();
    QVariantAnimation *m_paletteAnim = nullptr;
    bool m_paletteReady = false;  // first palette snaps; later ones cross-fade

    QTimer m_posTimer;
    QNetworkAccessManager *m_net = nullptr;
    quint64 m_artToken = 0;

    bool m_demo = false;  // screenshot mode: getters return fixed clean data
    int m_demoVariant = 0;
};

}  // namespace vespera
