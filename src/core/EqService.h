// 10-band equalizer, applied through EasyEffects. Mirrors the reference
// equalizer.sh: the 10 sliders map onto a 32-band EasyEffects output preset
// (written to the EasyEffects presets dir) which is then loaded live with
// `easyeffects -l`. Optional: if EasyEffects isn't installed the service
// reports unavailable and the UI hides the EQ. State is persisted.
#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>

namespace vespera {

class EqService : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool available READ available CONSTANT)
    Q_PROPERTY(QVariantList bands READ bands NOTIFY bandsChanged)
    Q_PROPERTY(QString preset READ preset NOTIFY presetChanged)

public:
    explicit EqService(QObject *parent = nullptr);

    bool available() const { return m_available; }
    QVariantList bands() const;
    QString preset() const { return m_preset; }

    // idx is 1..10; gain in dB (-12..12). Applies immediately.
    Q_INVOKABLE void setBand(int idx, int gain);
    Q_INVOKABLE void applyPreset(const QString &name);
    Q_INVOKABLE int band(int idx) const;  // idx 1..10
    Q_INVOKABLE void loadDemo();          // set a preset for screenshots, no apply

signals:
    void bandsChanged();
    void presetChanged();

private:
    void loadState();
    void saveState();
    void apply();  // write EasyEffects preset + load it live

    bool m_available = false;
    int m_gains[10] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
    QString m_preset = QStringLiteral("Flat");
    QString m_statePath;
    QString m_presetPath;
};

}  // namespace vespera
