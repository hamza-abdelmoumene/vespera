#include "MprisPlayer.h"

#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusReply>
#include <QDBusVariant>
#include <QStringList>

namespace vespera {

namespace {
constexpr auto kPath = "/org/mpris/MediaPlayer2";
constexpr auto kAppIface = "org.mpris.MediaPlayer2";
constexpr auto kPlayerIface = "org.mpris.MediaPlayer2.Player";
constexpr auto kPropsIface = "org.freedesktop.DBus.Properties";

// Unwrap a QDBusVariant / QDBusArgument-wrapped scalar into a plain QVariant.
QVariant unwrap(const QVariant &v) {
    if (v.canConvert<QDBusVariant>()) return v.value<QDBusVariant>().variant();
    return v;
}

QVariantMap demarshalMap(const QVariant &value) {
    QVariant v = unwrap(value);
    if (v.canConvert<QDBusArgument>()) {
        const QDBusArgument arg = v.value<QDBusArgument>();
        QVariantMap m;
        arg >> m;
        return m;
    }
    return v.toMap();
}

QStringList demarshalStringList(const QVariant &value) {
    QVariant v = unwrap(value);
    if (v.canConvert<QDBusArgument>()) {
        const QDBusArgument arg = v.value<QDBusArgument>();
        QStringList out;
        arg.beginArray();
        while (!arg.atEnd()) {
            QString s;
            arg >> s;
            out << s;
        }
        arg.endArray();
        return out;
    }
    if (v.metaType().id() == QMetaType::QString) return {v.toString()};
    return v.toStringList();
}

QString demarshalObjectPath(const QVariant &value) {
    QVariant v = unwrap(value);
    if (v.canConvert<QDBusObjectPath>()) return v.value<QDBusObjectPath>().path();
    return v.toString();
}
}  // namespace

MprisPlayer::MprisPlayer(const QString &service, QObject *parent)
    : QObject(parent), m_service(service) {
    auto bus = QDBusConnection::sessionBus();

    bus.connect(m_service, kPath, kPropsIface, QStringLiteral("PropertiesChanged"), this,
                SLOT(onPropertiesChanged(QString, QVariantMap, QStringList)));
    bus.connect(m_service, kPath, kPlayerIface, QStringLiteral("Seeked"), this,
                SLOT(onSeeked(qlonglong)));

    refreshAll();
}

void MprisPlayer::refreshAll() {
    auto bus = QDBusConnection::sessionBus();

    // Application-level identity.
    {
        QDBusMessage msg = QDBusMessage::createMethodCall(m_service, kPath, kPropsIface,
                                                          QStringLiteral("GetAll"));
        msg << QString::fromLatin1(kAppIface);
        const QDBusReply<QVariantMap> reply = bus.call(msg);
        if (reply.isValid()) {
            const QVariantMap m = reply.value();
            m_identity = unwrap(m.value(QStringLiteral("Identity"))).toString();
            m_desktopEntry = unwrap(m.value(QStringLiteral("DesktopEntry"))).toString();
        }
    }

    // Player state.
    {
        QDBusMessage msg = QDBusMessage::createMethodCall(m_service, kPath, kPropsIface,
                                                          QStringLiteral("GetAll"));
        msg << QString::fromLatin1(kPlayerIface);
        const QDBusReply<QVariantMap> reply = bus.call(msg);
        if (reply.isValid()) applyPlayerProps(reply.value());
    }
}

void MprisPlayer::applyPlayerProps(const QVariantMap &props) {
    auto has = [&](const char *k) { return props.contains(QLatin1String(k)); };

    if (has("PlaybackStatus"))
        m_status = unwrap(props.value(QStringLiteral("PlaybackStatus"))).toString();
    if (has("Metadata")) m_metadata = demarshalMap(props.value(QStringLiteral("Metadata")));
    if (has("CanGoNext")) m_canGoNext = unwrap(props.value(QStringLiteral("CanGoNext"))).toBool();
    if (has("CanGoPrevious"))
        m_canGoPrevious = unwrap(props.value(QStringLiteral("CanGoPrevious"))).toBool();
    if (has("CanSeek")) m_canSeek = unwrap(props.value(QStringLiteral("CanSeek"))).toBool();
    if (has("CanControl")) m_canControl = unwrap(props.value(QStringLiteral("CanControl"))).toBool();

    emit changed();
}

void MprisPlayer::onPropertiesChanged(const QString &interface, const QVariantMap &changed,
                                      const QStringList &) {
    if (interface == QLatin1String(kPlayerIface)) {
        applyPlayerProps(changed);
    } else if (interface == QLatin1String(kAppIface)) {
        if (changed.contains(QStringLiteral("Identity")))
            m_identity = unwrap(changed.value(QStringLiteral("Identity"))).toString();
        if (changed.contains(QStringLiteral("DesktopEntry")))
            m_desktopEntry = unwrap(changed.value(QStringLiteral("DesktopEntry"))).toString();
    }
}

void MprisPlayer::onSeeked(qlonglong positionUs) {
    emit seeked(double(positionUs) / 1e6);
}

QString MprisPlayer::title() const {
    return unwrap(m_metadata.value(QStringLiteral("xesam:title"))).toString();
}

QString MprisPlayer::artist() const {
    const QStringList a = demarshalStringList(m_metadata.value(QStringLiteral("xesam:artist")));
    return a.join(QStringLiteral(", "));
}

QString MprisPlayer::album() const {
    return unwrap(m_metadata.value(QStringLiteral("xesam:album"))).toString();
}

QString MprisPlayer::artUrl() const {
    return unwrap(m_metadata.value(QStringLiteral("mpris:artUrl"))).toString();
}

QString MprisPlayer::trackId() const {
    return demarshalObjectPath(m_metadata.value(QStringLiteral("mpris:trackid")));
}

double MprisPlayer::lengthSeconds() const {
    return double(unwrap(m_metadata.value(QStringLiteral("mpris:length"))).toLongLong()) / 1e6;
}

double MprisPlayer::positionSeconds() {
    auto bus = QDBusConnection::sessionBus();
    QDBusMessage msg =
        QDBusMessage::createMethodCall(m_service, kPath, kPropsIface, QStringLiteral("Get"));
    msg << QString::fromLatin1(kPlayerIface) << QStringLiteral("Position");
    const QDBusMessage reply = bus.call(msg, QDBus::Block, 400);
    if (reply.type() != QDBusMessage::ReplyMessage || reply.arguments().isEmpty()) return -1.0;
    return double(unwrap(reply.arguments().first()).toLongLong()) / 1e6;
}

void MprisPlayer::playPause() {
    auto bus = QDBusConnection::sessionBus();
    bus.asyncCall(QDBusMessage::createMethodCall(m_service, kPath, kPlayerIface,
                                                 QStringLiteral("PlayPause")));
}

void MprisPlayer::next() {
    auto bus = QDBusConnection::sessionBus();
    bus.asyncCall(
        QDBusMessage::createMethodCall(m_service, kPath, kPlayerIface, QStringLiteral("Next")));
}

void MprisPlayer::previous() {
    auto bus = QDBusConnection::sessionBus();
    bus.asyncCall(
        QDBusMessage::createMethodCall(m_service, kPath, kPlayerIface, QStringLiteral("Previous")));
}

void MprisPlayer::seekBy(double seconds) {
    auto bus = QDBusConnection::sessionBus();
    QDBusMessage msg =
        QDBusMessage::createMethodCall(m_service, kPath, kPlayerIface, QStringLiteral("Seek"));
    msg << qlonglong(seconds * 1e6);
    bus.asyncCall(msg);
}

void MprisPlayer::seekTo(double seconds) {
    const QString id = trackId();
    if (id.isEmpty()) {
        const double cur = positionSeconds();
        if (cur >= 0) seekBy(seconds - cur);
        return;
    }
    auto bus = QDBusConnection::sessionBus();
    QDBusMessage msg = QDBusMessage::createMethodCall(m_service, kPath, kPlayerIface,
                                                      QStringLiteral("SetPosition"));
    msg << QVariant::fromValue(QDBusObjectPath(id)) << qlonglong(seconds * 1e6);
    bus.asyncCall(msg);
}

}  // namespace vespera
