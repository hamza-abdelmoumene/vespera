#include "AppController.h"

#include "MprisController.h"

namespace vespera {

AppController::AppController(MprisController *mpris, QObject *parent)
    : QObject(parent), m_mpris(mpris) {}

QString AppController::version() const { return QStringLiteral(VESPERA_VERSION); }

void AppController::toggle() { emit toggleRequested(); }
void AppController::show() { emit showRequested(); }
void AppController::hide() { emit hideRequested(); }

void AppController::playPause() {
    if (m_mpris) m_mpris->playPause();
}
void AppController::next() {
    if (m_mpris) m_mpris->next();
}
void AppController::previous() {
    if (m_mpris) m_mpris->previous();
}

}  // namespace vespera
