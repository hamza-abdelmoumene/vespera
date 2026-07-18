// cava audio visualizer bridge. Runs `cava` with a generated raw-ascii config
// and streams N bars (0..100) to QML. Optional: if cava isn't installed the
// service reports unavailable and the UI hides the visualizer cleanly. Running
// is gated on `active` so nothing spins while the window is hidden or paused.
#pragma once

#include <QObject>
#include <QVariantList>

class QProcess;

namespace vespera {

class CavaService : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool available READ available CONSTANT)
    Q_PROPERTY(int barCount READ barCount CONSTANT)
    Q_PROPERTY(QVariantList bars READ bars NOTIFY barsChanged)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)

public:
    explicit CavaService(QObject *parent = nullptr);
    ~CavaService() override;

    bool available() const { return m_available; }
    int barCount() const { return m_barCount; }
    QVariantList bars() const { return m_bars; }
    bool active() const { return m_active; }
    void setActive(bool value);

    Q_INVOKABLE void loadDemo();  // frozen spectrum for screenshots

signals:
    void barsChanged();
    void activeChanged();

private:
    void start();
    void stop();
    void writeConfig();
    void onReadyRead();

    bool m_available = false;
    bool m_active = false;
    bool m_demo = false;
    int m_barCount = 44;
    QVariantList m_bars;
    QString m_configPath;
    QProcess *m_proc = nullptr;
    QByteArray m_buffer;
};

}  // namespace vespera
