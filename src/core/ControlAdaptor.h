// D-Bus adaptor exposing org.vespera.Control on the running instance, so any
// WM/DE can bind keys to `vespera toggle|show|hide|play-pause|next|prev`.
#pragma once

#include <QDBusAbstractAdaptor>

#include "AppController.h"

namespace vespera {

class ControlAdaptor : public QDBusAbstractAdaptor {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.vespera.Control")
public:
    explicit ControlAdaptor(AppController *app) : QDBusAbstractAdaptor(app), m_app(app) {}

public slots:  // NOLINT — these are the exported D-Bus methods
    void Toggle() { m_app->toggle(); }
    void Show() { m_app->show(); }
    void Hide() { m_app->hide(); }
    void PlayPause() { m_app->playPause(); }
    void Next() { m_app->next(); }
    void Previous() { m_app->previous(); }

private:
    AppController *m_app;
};

}  // namespace vespera
