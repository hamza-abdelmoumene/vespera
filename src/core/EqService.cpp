#include "EqService.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QSaveFile>
#include <QStandardPaths>
#include <QTimer>

namespace vespera {

namespace {
constexpr auto kPresetName = "vespera_eq";

// Which of the 32 EasyEffects bands each of the 10 sliders drives.
constexpr int kSliderBand[10] = {0, 3, 6, 9, 12, 15, 18, 21, 24, 27};
constexpr double kFreqs[32] = {32,   40,   50,   63,   80,    100,   125,   160,
                               200,  250,  315,  400,  500,   630,   800,   1000,
                               1250, 1600, 2000, 2500, 3150,  4000,  5000,  6300,
                               8000, 10000, 12500, 16000, 20000, 22000, 24000, 24000};

struct Preset {
    const char *name;
    int g[10];
};
constexpr Preset kPresets[] = {
    {"Flat", {0, 0, 0, 0, 0, 0, 0, 0, 0, 0}},
    {"Bass", {5, 7, 5, 2, 1, 0, 0, 0, 1, 2}},
    {"Treble", {-2, -1, 0, 1, 2, 3, 4, 5, 6, 6}},
    {"Vocal", {-2, -1, 1, 3, 5, 5, 4, 2, 1, 0}},
    {"Pop", {2, 4, 2, 0, 1, 2, 4, 2, 1, 2}},
    {"Rock", {5, 4, 2, -1, -2, -1, 2, 4, 5, 6}},
    {"Jazz", {3, 3, 1, 1, 1, 1, 2, 1, 2, 3}},
    {"Classic", {0, 1, 2, 2, 2, 2, 1, 2, 3, 4}},
};
}  // namespace

EqService::EqService(QObject *parent) : QObject(parent) {
    m_available = !QStandardPaths::findExecutable(QStringLiteral("easyeffects")).isEmpty();

    QString cfg = QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation);
    if (cfg.isEmpty()) cfg = QDir::homePath() + QStringLiteral("/.config/vespera");
    m_statePath = cfg + QStringLiteral("/eq_state.json");

    QString data = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation);
    if (data.isEmpty()) data = QDir::homePath() + QStringLiteral("/.local/share");
    m_presetPath =
        data + QStringLiteral("/easyeffects/output/") + QLatin1String(kPresetName) + QStringLiteral(".json");

    loadState();
}

QVariantList EqService::bands() const {
    QVariantList out;
    out.reserve(10);
    for (int i = 0; i < 10; ++i) out.append(m_gains[i]);
    return out;
}

int EqService::band(int idx) const {
    if (idx < 1 || idx > 10) return 0;
    return m_gains[idx - 1];
}

void EqService::setBand(int idx, int gain) {
    if (idx < 1 || idx > 10) return;
    gain = qBound(-12, gain, 12);
    if (m_gains[idx - 1] == gain && m_preset == QLatin1String("Custom")) return;
    m_gains[idx - 1] = gain;
    m_preset = QStringLiteral("Custom");
    emit bandsChanged();
    emit presetChanged();
    saveState();
    apply();
}

void EqService::applyPreset(const QString &name) {
    for (const auto &p : kPresets) {
        if (name.compare(QLatin1String(p.name), Qt::CaseInsensitive) == 0) {
            for (int i = 0; i < 10; ++i) m_gains[i] = p.g[i];
            m_preset = QLatin1String(p.name);
            emit bandsChanged();
            emit presetChanged();
            saveState();
            apply();
            return;
        }
    }
}

void EqService::loadDemo() {
    static const int vocal[10] = {-2, -1, 1, 3, 5, 5, 4, 2, 1, 0};
    for (int i = 0; i < 10; ++i) m_gains[i] = vocal[i];
    m_preset = QStringLiteral("Vocal");
    emit bandsChanged();
    emit presetChanged();
}

void EqService::loadState() {
    QFile f(m_statePath);
    if (!f.open(QIODevice::ReadOnly)) return;
    const QJsonObject o = QJsonDocument::fromJson(f.readAll()).object();
    for (int i = 0; i < 10; ++i)
        m_gains[i] = o.value(QStringLiteral("b%1").arg(i + 1)).toInt(0);
    m_preset = o.value(QStringLiteral("preset")).toString(QStringLiteral("Flat"));
    emit bandsChanged();
    emit presetChanged();
}

void EqService::saveState() {
    QJsonObject o;
    for (int i = 0; i < 10; ++i) o.insert(QStringLiteral("b%1").arg(i + 1), m_gains[i]);
    o.insert(QStringLiteral("preset"), m_preset);
    QDir().mkpath(QFileInfo(m_statePath).absolutePath());
    QSaveFile out(m_statePath);
    if (!out.open(QIODevice::WriteOnly | QIODevice::Truncate)) return;
    const QByteArray bytes = QJsonDocument(o).toJson(QJsonDocument::Compact);
    if (out.write(bytes) == bytes.size()) out.commit();
}

void EqService::apply() {
    if (!m_available) return;

    // Build the 32-band EasyEffects equalizer preset.
    QJsonObject bands;
    for (int i = 0; i < 32; ++i) {
        double gain = 0.0;
        for (int s = 0; s < 10; ++s)
            if (kSliderBand[s] == i) {
                gain = m_gains[s];
                break;
            }
        QJsonObject b;
        b.insert(QStringLiteral("frequency"), kFreqs[i]);
        b.insert(QStringLiteral("gain"), gain);
        b.insert(QStringLiteral("mode"), QStringLiteral("Bell"));
        b.insert(QStringLiteral("mute"), false);
        b.insert(QStringLiteral("q"), 1.0);
        b.insert(QStringLiteral("solo"), false);
        b.insert(QStringLiteral("width"), 1.0);
        b.insert(QStringLiteral("slope"), QStringLiteral("x1"));
        bands.insert(QStringLiteral("band%1").arg(i), b);
    }
    QJsonObject eq;
    eq.insert(QStringLiteral("bypass"), false);
    eq.insert(QStringLiteral("input-gain"), 0.0);
    eq.insert(QStringLiteral("output-gain"), 0.0);
    eq.insert(QStringLiteral("left"), bands);
    eq.insert(QStringLiteral("right"), bands);
    eq.insert(QStringLiteral("mode"), QStringLiteral("IIR"));
    eq.insert(QStringLiteral("num-bands"), 32);
    eq.insert(QStringLiteral("split-channels"), false);

    QJsonObject output;
    output.insert(QStringLiteral("blocklist"), QJsonArray{});
    output.insert(QStringLiteral("plugins_order"), QJsonArray{QStringLiteral("equalizer")});
    output.insert(QStringLiteral("equalizer"), eq);
    QJsonObject preset;
    preset.insert(QStringLiteral("output"), output);

    QDir().mkpath(QFileInfo(m_presetPath).absolutePath());
    QSaveFile out(m_presetPath);
    if (!out.open(QIODevice::WriteOnly | QIODevice::Truncate)) return;
    out.write(QJsonDocument(preset).toJson(QJsonDocument::Indented));
    if (!out.commit()) return;

    // Ensure the EasyEffects background service is running, then load the
    // preset live. Pure Qt — no shell/pgrep, so it works on any distro.
    // Starting the service when it is already up is a harmless no-op (the
    // second GApplication instance fails to claim the name and exits).
    const QString exe = QStringLiteral("easyeffects");
    const QString presetName = QLatin1String(kPresetName);
    QProcess::startDetached(exe, {QStringLiteral("--gapplication-service")});
    QTimer::singleShot(900, this, [exe, presetName]() {
        QProcess::startDetached(exe, {QStringLiteral("-l"), presetName});
    });
}

}  // namespace vespera
