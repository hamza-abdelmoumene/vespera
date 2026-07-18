#!/usr/bin/env bash
#
# Build a Vespera AppImage locally. Requires: cmake, ninja, a Qt 6 (>=6.5) dev
# install, and linuxdeploy + linuxdeploy-plugin-qt on PATH
# (https://github.com/linuxdeploy/linuxdeploy/releases).
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root"

cmake -S . -B build-appimage -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
cmake --build build-appimage
rm -rf AppDir
DESTDIR="$root/AppDir" cmake --install build-appimage

export QML_SOURCES_PATHS="$root/qml"
export APPIMAGE_EXTRACT_AND_RUN=1

linuxdeploy --appdir AppDir --plugin qt --output appimage \
    --desktop-file packaging/vespera.desktop \
    --icon-file packaging/icons/vespera.svg

echo "Built: $(ls -1 Vespera*.AppImage 2>/dev/null || echo '<check output>')"
