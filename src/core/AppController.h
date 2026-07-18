// Bridges D-Bus / IPC commands and QML window control.
//
// The running instance owns org.vespera.Vespera; a ControlAdaptor forwards
// Toggle/Show/Hide/PlayPause/Next/Previous here. Player commands are executed
// directly against the MPRIS controller; window commands are emitted as
// signals for QML (which owns the actual Window) to act on.
#pragma once

#include <QObject>
#include <QString>

namespace vespera {

class MprisController;

class AppController : public QObject {
    Q_OBJECT
public:
    explicit AppController(MprisController *mpris, QObject *parent = nullptr);

    Q_INVOKABLE QString version() const;

    // Invoked by the D-Bus adaptor (and usable from QML).
    void toggle();
    void show();
    void hide();
    void playPause();
    void next();
    void previous();

signals:
    void toggleRequested();
    void showRequested();
    void hideRequested();

private:
    MprisController *m_mpris;
};

}  // namespace vespera
