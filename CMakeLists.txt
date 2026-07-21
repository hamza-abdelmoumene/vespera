cmake_minimum_required(VERSION 3.21)

project(vespera
    VERSION 0.1.0
    DESCRIPTION "Standalone, distro-agnostic Linux music player companion"
    HOMEPAGE_URL "https://github.com/hamza-abdelmoumene/vespera"
    LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "" FORCE)
endif()

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 DBus Network)

qt_standard_project_setup(REQUIRES 6.5)

# Auto-generate qmldir entries for QML files kept in subdirectories.
if(QT_KNOWN_POLICY_QTP0004)
    qt_policy(SET QTP0004 NEW)
endif()

qt_add_executable(vespera
    src/main.cpp
    src/core/OklchColor.h
    src/core/PaletteExtractor.h
    src/core/PaletteExtractor.cpp
    src/core/MprisPlayer.h
    src/core/MprisPlayer.cpp
    src/core/MprisController.h
    src/core/MprisController.cpp
    src/core/AppController.h
    src/core/AppController.cpp
    src/core/ControlAdaptor.h
    src/core/LyricsService.h
    src/core/LyricsService.cpp
    src/core/CavaService.h
    src/core/CavaService.cpp
    src/core/EqService.h
    src/core/EqService.cpp
    src/core/ThemeManager.h
    src/core/ThemeManager.cpp
    src/core/AppImageProvider.h
    src/core/CoverStore.h
    src/core/CoverStore.cpp
)

set_source_files_properties(qml/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(vespera
    URI Vespera
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/Theme.qml
        qml/blockfont.js
        qml/scene/CoverBackdrop.qml
        qml/scene/AuroraOverlay.qml
        qml/scene/StarfieldOverlay.qml
        qml/scene/SynthwaveOverlay.qml
        qml/scene/Backdrop.qml
        qml/scene/FloatingNotes.qml
        qml/components/GlassPanel.qml
        qml/components/EclipseDisc.qml
        qml/components/DiscGlow.qml
        qml/components/NowPlaying.qml
        qml/components/TransportBar.qml
        qml/components/GlyphButton.qml
        qml/components/SeekBar.qml
        qml/components/Equalizer.qml
        qml/components/LyricsPanel.qml
        qml/components/PlayerPane.qml
        qml/components/PlaybackExtras.qml
        qml/components/PresetButton.qml
        qml/components/IconButton.qml
        qml/components/ThemePicker.qml
        qml/components/HelpOverlay.qml
)

qt_add_resources(vespera "fonts"
    PREFIX "/"
    FILES
        assets/fonts/JetBrainsMono-Regular.ttf
        assets/fonts/JetBrainsMono-Medium.ttf
        assets/fonts/JetBrainsMono-Bold.ttf
        assets/fonts/JetBrainsMono-ExtraBold.ttf
        assets/fonts/MapleMono-Regular.ttf
        assets/fonts/MapleMono-Bold.ttf
        assets/fonts/Rubik-Variable.ttf
)

target_compile_definitions(vespera PRIVATE
    VESPERA_VERSION="${PROJECT_VERSION}"
)

target_link_libraries(vespera PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::DBus
    Qt6::Network
)

include(GNUInstallDirs)
install(TARGETS vespera
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})

install(FILES packaging/vespera.desktop
    DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
install(FILES packaging/icons/vespera.svg
    DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/scalable/apps)
install(FILES packaging/io.github.hamza_abdelmoumene.vespera.metainfo.xml
    DESTINATION ${CMAKE_INSTALL_DATADIR}/metainfo)
