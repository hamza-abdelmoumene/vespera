#pragma once

#include <QElapsedTimer>
#include <QObject>
#include <QPointer>
#include <QQuickWindow>
#include <QTimer>

namespace vespera {

// Whether the window is actually on screen.
//
// Wayland never tells a client its window sits on a hidden workspace —
// QWindow::isVisible() stays true — but the compositor stops answering frame
// callbacks, so Qt stops swapping frames. Once a second, if no frame has landed
// lately, we ask for one; if that request goes unanswered by the next tick the
// window is off screen. The same probe keeps running while off screen, so the
// first frame after the window comes back flips us straight back on. Costs at
// most one extra frame a second while visible and otherwise idle.
class FrameWatch : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool onScreen READ onScreen NOTIFY onScreenChanged)

public:
    explicit FrameWatch(QObject *parent = nullptr) : QObject(parent) {
        m_tick.setInterval(kProbeMs);
        connect(&m_tick, &QTimer::timeout, this, &FrameWatch::probe);
        m_clock.start();
    }

    void attach(QQuickWindow *win) {
        m_win = win;
        // frameSwapped fires on the render thread; handle it on ours.
        connect(win, &QQuickWindow::frameSwapped, this, &FrameWatch::frameLanded,
                Qt::QueuedConnection);
        connect(win, &QWindow::visibleChanged, this, [this](bool visible) {
            m_probedAt = -1;
            if (visible) {
                m_lastFrame = m_clock.elapsed();
                setOnScreen(true);
                m_tick.start();
            } else {
                m_tick.stop();
            }
        });
        m_lastFrame = m_clock.elapsed();
        if (win->isVisible()) m_tick.start();
    }

    bool onScreen() const { return m_onScreen; }

signals:
    void onScreenChanged();

private:
    static constexpr int kProbeMs = 1000;

    void frameLanded() {
        m_lastFrame = m_clock.elapsed();
        setOnScreen(true);
    }

    void probe() {
        if (!m_win) return;
        const qint64 now = m_clock.elapsed();
        if (now - m_lastFrame < kProbeMs + 100) {  // frames are flowing
            m_probedAt = -1;
            return;
        }
        if (m_probedAt >= 0 && m_lastFrame < m_probedAt) setOnScreen(false);
        m_probedAt = now;
        m_win->update();
    }

    void setOnScreen(bool value) {
        if (value == m_onScreen) return;
        m_onScreen = value;
        emit onScreenChanged();
    }

    QPointer<QQuickWindow> m_win;
    QTimer m_tick;
    QElapsedTimer m_clock;
    qint64 m_lastFrame = 0;
    qint64 m_probedAt = -1;
    bool m_onScreen = true;
};

}  // namespace vespera
