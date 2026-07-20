// Vespera — entry point.
//
// Modes:
//   vespera                 launch (or raise a running instance)
//   vespera --compact       launch in the compact mini layout
//   vespera --version       print version and exit
//   vespera <command>       send a control command to the running instance:
//                             toggle | show | hide | play-pause | next | prev
//
// Single-instance is enforced by owning the D-Bus name org.vespera.Vespera.
#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusInterface>
#include <QGuiApplication>
#include <QImage>
#include <QQmlApplicationEngine>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQuickWindow>
#include <QStandardPaths>
#include <QTimer>
#include <cstdio>

#include <QQuickStyle>

#include "core/AppController.h"
#include "core/AppImageProvider.h"
#include "core/CavaService.h"
#include "core/ControlAdaptor.h"
#include "core/CoverStore.h"
#include "core/EqService.h"
#include "core/LyricsService.h"
#include "core/MprisController.h"
#include "core/ThemeManager.h"

namespace {
constexpr auto kService = "org.vespera.Vespera";
constexpr auto kPath = "/org/vespera/Vespera";
constexpr auto kIface = "org.vespera.Control";

void printUsage() {
    std::puts(
        "vespera " VESPERA_VERSION " — standalone Linux music player companion\n"
        "\n"
        "Usage:\n"
        "  vespera                launch, or raise the running instance\n"
        "  vespera --compact      launch in the compact mini layout\n"
        "  vespera --version      print version and exit\n"
        "  vespera doctor         report detected players and optional features\n"
        "  vespera --help         show this help\n"
        "\n"
        "Control a running instance (bind these to WM keys):\n"
        "  vespera toggle         show/hide the window\n"
        "  vespera show           show and raise the window\n"
        "  vespera hide           hide the window\n"
        "  vespera play-pause     toggle playback\n"
        "  vespera next           next track\n"
        "  vespera prev           previous track");
}

// Map a control word to its D-Bus method name, or empty if not a command.
QString commandMethod(const QString &arg) {
    if (arg == QLatin1String("toggle")) return QStringLiteral("Toggle");
    if (arg == QLatin1String("show")) return QStringLiteral("Show");
    if (arg == QLatin1String("hide")) return QStringLiteral("Hide");
    if (arg == QLatin1String("play-pause") || arg == QLatin1String("playpause"))
        return QStringLiteral("PlayPause");
    if (arg == QLatin1String("next")) return QStringLiteral("Next");
    if (arg == QLatin1String("prev") || arg == QLatin1String("previous"))
        return QStringLiteral("Previous");
    return {};
}

// Developer/CI screenshot mode: render the UI offscreen at an exact size and
// save a PNG. Intended to be run with:
//   QT_QPA_PLATFORM=offscreen vespera --capture <w> <h> <out.png> [compact]
// (default RHI backend — QT_QUICK_BACKEND=software kills the effects layer.
// The per-panel glass blur does not render offscreen either way; captures use
// the C++ frost fallback, so the real glass must be verified live.)
int runCapture(int argc, char **argv) {
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral("vespera"));
    QGuiApplication::setOrganizationName(QStringLiteral("vespera"));

    const int w = argc > 2 ? QString::fromLocal8Bit(argv[2]).toInt() : 1000;
    const int h = argc > 3 ? QString::fromLocal8Bit(argv[3]).toInt() : 640;
    const QString out =
        argc > 4 ? QString::fromLocal8Bit(argv[4]) : QStringLiteral("vespera.png");
    bool compact = false, demo = false, picker = false, interact = false;
    int demoVariant = 0;
    for (int i = 5; i < argc; ++i) {
        const QString a = QString::fromLocal8Bit(argv[i]);
        if (a == QLatin1String("compact")) compact = true;
        else if (a == QLatin1String("demo")) demo = true;
        else if (a == QLatin1String("demo2")) { demo = true; demoVariant = 1; }
        else if (a == QLatin1String("picker")) picker = true;
        else if (a == QLatin1String("interact")) interact = true;
    }

    QQuickStyle::setStyle(QStringLiteral("Basic"));

    auto *mpris = new vespera::MprisController(&app);
    auto *appc = new vespera::AppController(mpris, &app);
    auto *lyrics = new vespera::LyricsService(&app);
    auto *cava = new vespera::CavaService(&app);
    auto *eq = new vespera::EqService(&app);
    auto *style = new vespera::ThemeManager(mpris, &app);
    auto *coverStore = new vespera::CoverStore(&app);
    auto *imageProvider = new vespera::AppImageProvider(coverStore);
    QObject::connect(mpris, &vespera::MprisController::artImageReady, coverStore,
                     &vespera::CoverStore::setSource);
    // backdrop grade follows the theme (saturation · brightness · luminance floor)
    auto applyGrade = [style, coverStore] {
        coverStore->setGrade(style->coverSaturation(), style->coverBrightness(),
                             style->lumFloor());
    };
    QObject::connect(style, &vespera::ThemeManager::changed, coverStore, applyGrade);
    applyGrade();

    QQmlApplicationEngine engine;
    engine.addImageProvider(QStringLiteral("vespera"), imageProvider);
    engine.rootContext()->setContextProperty(QStringLiteral("Player"), mpris);
    engine.rootContext()->setContextProperty(QStringLiteral("App"), appc);
    engine.rootContext()->setContextProperty(QStringLiteral("Lyrics"), lyrics);
    engine.rootContext()->setContextProperty(QStringLiteral("Cava"), cava);
    engine.rootContext()->setContextProperty(QStringLiteral("Eq"), eq);
    engine.rootContext()->setContextProperty(QStringLiteral("Style"), style);
    engine.rootContext()->setContextProperty(QStringLiteral("Cover"), coverStore);
    engine.rootContext()->setContextProperty(QStringLiteral("startCompact"), compact);
    // capture-only hooks: drive the transient EQ effect + lyrics hand-scroll
    // state so those interactions can be screenshotted deterministically.
    engine.rootContext()->setContextProperty(QStringLiteral("captureTide"), interact);
    engine.rootContext()->setContextProperty(QStringLiteral("captureScrolled"), interact);
    // offscreen capture can't render the effects layer — panels fall back to frost
    engine.rootContext()->setContextProperty(QStringLiteral("glassAvailable"), false);
    engine.loadFromModule("Vespera", "Main");
    if (engine.rootObjects().isEmpty()) {
        QQmlComponent probe(&engine);
        probe.loadFromModule("Vespera", "Main");
        for (const QQmlError &e : probe.errors())
            std::fprintf(stderr, "vespera QML: %s\n", e.toString().toLocal8Bit().constData());
        return 1;
    }

    auto *win = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
    if (!win) {
        std::fprintf(stderr, "vespera: root is not a window\n");
        return 1;
    }
    if (demo) {
        mpris->loadDemo(demoVariant);
        lyrics->loadDemo();
        cava->loadDemo();
        eq->loadDemo();
        // demo art never reaches the store via MPRIS; seed it with the synthetic
        // cover so the blurred backdrop renders in captures.
        coverStore->setSource(imageProvider->coverImage(demoVariant));
    }
    if (interact) {
        // fire the EQ preset-change moment so the capture lands mid-flight
        // (comet head + shockwave + echoes visible), not at rest. The delay is
        // tunable via VESPERA_FX_DELAY for screenshotting different points in
        // the animation (default: early, while the shockwave ring is visible).
        const int fxDelay = qEnvironmentVariableIntValue("VESPERA_FX_DELAY") > 0
                                 ? qEnvironmentVariableIntValue("VESPERA_FX_DELAY") : 120;
        QTimer::singleShot(fxDelay, eq, [eq]() { eq->applyPreset(QStringLiteral("Bass")); });
    }

    win->resize(w, h);
    win->setVisible(true);
    if (picker) win->setProperty("pickerOpen", QVariant(true));

    // Demo data is static (no network); live captures wait for metadata + art +
    // lyrics to arrive. Then grab and quit.
    QTimer::singleShot(demo ? 900 : 3200, &app, [win, out]() {
        const QImage img = win->grabWindow();
        if (!img.isNull() && img.save(out))
            std::fprintf(stderr, "vespera: wrote %s (%dx%d)\n", out.toLocal8Bit().constData(),
                         img.width(), img.height());
        else
            std::fprintf(stderr, "vespera: capture failed\n");
        QGuiApplication::quit();
    });
    return QGuiApplication::exec();
}

// `vespera doctor` — report the session-bus / MPRIS state and which optional
// programs are present and what each unlocks. Everything degrades gracefully.
int runDoctor(int argc, char **argv) {
    QCoreApplication app(argc, argv);
    auto found = [](const QString &e) { return !QStandardPaths::findExecutable(e).isEmpty(); };

    std::printf("vespera %s — environment check\n\n", VESPERA_VERSION);

    auto bus = QDBusConnection::sessionBus();
    const bool busOk = bus.isConnected();
    std::printf("  %-16s %s\n", "session bus",
                busOk ? "[ ok ]" : "[ -- ]  MPRIS control unavailable");

    int players = 0;
    if (busOk && bus.interface()) {
        const QStringList names = bus.interface()->registeredServiceNames().value();
        for (const QString &n : names)
            if (n.startsWith(QLatin1String("org.mpris.MediaPlayer2."))) ++players;
    }
    std::printf("  %-16s %d detected\n\n", "MPRIS players", players);

    struct Dep {
        const char *bin;
        const char *unlocks;
    };
    static const Dep deps[] = {
        {"cava", "audio visualizer"},
        {"easyeffects", "10-band equalizer"},
    };
    std::puts("  optional features:");
    for (const Dep &d : deps)
        std::printf("    %-14s %s  %s\n", d.bin, found(QLatin1String(d.bin)) ? "[ ok ]" : "[ -- ]",
                    d.unlocks);

    std::puts("\n  synced lyrics use lrclib.net over HTTPS (no local dependency).");
    return 0;
}

int runClientCommand(int argc, char **argv, const QString &method) {
    QCoreApplication app(argc, argv);
    auto bus = QDBusConnection::sessionBus();
    if (!bus.isConnected()) {
        std::fprintf(stderr, "vespera: cannot connect to the session bus.\n");
        return 1;
    }
    if (!bus.interface()->isServiceRegistered(QString::fromLatin1(kService))) {
        std::fprintf(stderr, "vespera is not running. Start it with `vespera`.\n");
        return 1;
    }
    QDBusInterface iface(QString::fromLatin1(kService), QString::fromLatin1(kPath),
                         QString::fromLatin1(kIface), bus);
    iface.call(method);
    return 0;
}
}  // namespace

int main(int argc, char **argv) {
    const QString arg1 = argc > 1 ? QString::fromLocal8Bit(argv[1]) : QString();

    if (arg1 == QLatin1String("--version") || arg1 == QLatin1String("-v") ||
        arg1 == QLatin1String("version")) {
        std::puts(VESPERA_VERSION);
        return 0;
    }
    if (arg1 == QLatin1String("--help") || arg1 == QLatin1String("-h") ||
        arg1 == QLatin1String("help")) {
        printUsage();
        return 0;
    }

    if (arg1 == QLatin1String("doctor")) return runDoctor(argc, argv);
    if (arg1 == QLatin1String("--capture")) return runCapture(argc, argv);

    // Control words are sent to the running instance; they never spawn a GUI.
    const QString method = commandMethod(arg1);
    if (!method.isEmpty()) return runClientCommand(argc, argv, method);

    const bool compact = (arg1 == QLatin1String("--compact"));
    if (!arg1.isEmpty() && !compact) {
        std::fprintf(stderr, "vespera: unknown argument '%s'\n\n", argv[1]);
        printUsage();
        return 2;
    }

    // ---- launch path ----
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral("vespera"));
    QGuiApplication::setOrganizationName(QStringLiteral("vespera"));
    QGuiApplication::setApplicationVersion(QStringLiteral(VESPERA_VERSION));
    QGuiApplication::setDesktopFileName(QStringLiteral("vespera"));

    auto bus = QDBusConnection::sessionBus();
    const bool becameOwner = bus.isConnected() && bus.registerService(QString::fromLatin1(kService));
    if (bus.isConnected() && !becameOwner) {
        // Another instance already owns the name — raise it and exit.
        QDBusInterface iface(QString::fromLatin1(kService), QString::fromLatin1(kPath),
                             QString::fromLatin1(kIface), bus);
        iface.call(QStringLiteral("Show"));
        return 0;
    }

    QQuickStyle::setStyle(QStringLiteral("Basic"));

    vespera::MprisController mpris;
    vespera::AppController appController(&mpris);
    vespera::LyricsService lyrics;
    vespera::CavaService cava;
    vespera::EqService eq;
    vespera::ThemeManager style(&mpris);
    vespera::CoverStore coverStore;
    auto *imageProvider = new vespera::AppImageProvider(&coverStore);
    QObject::connect(&mpris, &vespera::MprisController::artImageReady, &coverStore,
                     &vespera::CoverStore::setSource);
    // backdrop grade follows the theme (saturation · brightness · luminance floor)
    auto applyGrade = [&style, &coverStore] {
        coverStore.setGrade(style.coverSaturation(), style.coverBrightness(),
                            style.lumFloor());
    };
    QObject::connect(&style, &vespera::ThemeManager::changed, &coverStore, applyGrade);
    applyGrade();
    new vespera::ControlAdaptor(&appController);
    if (becameOwner)
        bus.registerObject(QString::fromLatin1(kPath), &appController,
                           QDBusConnection::ExportAdaptors);

    QQmlApplicationEngine engine;
    engine.addImageProvider(QStringLiteral("vespera"), imageProvider);
    engine.rootContext()->setContextProperty(QStringLiteral("Player"), &mpris);
    engine.rootContext()->setContextProperty(QStringLiteral("App"), &appController);
    engine.rootContext()->setContextProperty(QStringLiteral("Lyrics"), &lyrics);
    engine.rootContext()->setContextProperty(QStringLiteral("Cava"), &cava);
    engine.rootContext()->setContextProperty(QStringLiteral("Eq"), &eq);
    engine.rootContext()->setContextProperty(QStringLiteral("Style"), &style);
    engine.rootContext()->setContextProperty(QStringLiteral("Cover"), &coverStore);
    engine.rootContext()->setContextProperty(QStringLiteral("startCompact"), compact);
    engine.rootContext()->setContextProperty(QStringLiteral("captureTide"), false);
    engine.rootContext()->setContextProperty(QStringLiteral("captureScrolled"), false);
    // real per-panel backdrop-blur glass; VESPERA_NO_GLASS forces the frost
    // fallback (GlassPanel additionally checks for the software render backend)
    engine.rootContext()->setContextProperty(
        QStringLiteral("glassAvailable"),
        !qEnvironmentVariableIsSet("VESPERA_NO_GLASS"));

    engine.loadFromModule("Vespera", "Main");
    if (engine.rootObjects().isEmpty()) {
        QQmlComponent probe(&engine);
        probe.loadFromModule("Vespera", "Main");
        const auto errs = probe.errors();
        for (const QQmlError &e : errs)
            std::fprintf(stderr, "vespera QML: %s\n", e.toString().toLocal8Bit().constData());
        std::fprintf(stderr, "vespera: failed to load the QML interface.\n");
        return 1;
    }

    return QGuiApplication::exec();
}
