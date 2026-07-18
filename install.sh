#!/usr/bin/env bash
#
# Vespera installer — builds from source and installs.
#
# Run inside a checkout:      ./install.sh
# Or standalone (clones):     curl -fsSL https://raw.githubusercontent.com/hamza-abdelmoumene/vespera/main/install.sh | bash
#
# Options:
#   --user            install into ~/.local (no root)
#   --prefix=/path    install into a custom prefix (default: /usr/local)
#
# Piping any script to a shell is a trust decision. Prefer to download and read
# it first:  curl -fsSLO .../install.sh && less install.sh && bash install.sh
set -euo pipefail

REPO="https://github.com/hamza-abdelmoumene/vespera.git"
PREFIX="${PREFIX:-/usr/local}"
USER_INSTALL=0
JOBS="$(nproc 2>/dev/null || echo 2)"

for a in "$@"; do
    case "$a" in
        --user) USER_INSTALL=1; PREFIX="$HOME/.local" ;;
        --prefix=*) PREFIX="${a#*=}" ;;
        -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
        *) echo "unknown option: $a" >&2; exit 2 ;;
    esac
done

say() { printf '\033[36m==>\033[0m %s\n' "$*"; }
die() { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

command -v cmake >/dev/null || die "cmake (>= 3.21) is required"
command -v g++ >/dev/null || command -v clang++ >/dev/null || die "a C++20 compiler is required"
if ! command -v qmake6 >/dev/null && ! pkg-config --exists Qt6Core 2>/dev/null; then
    die "Qt 6 (>= 6.5) is required: install qt6-base + qt6-declarative (and their -dev packages)"
fi

if [ -f CMakeLists.txt ] && grep -q "project(vespera" CMakeLists.txt 2>/dev/null; then
    SRC="$(pwd)"
    say "Building from the current checkout"
else
    command -v git >/dev/null || die "git is required to fetch the source"
    SRC="$(mktemp -d)"
    trap 'rm -rf "$SRC"' EXIT
    say "Cloning $REPO"
    git clone --depth 1 "$REPO" "$SRC"
fi

GEN=""
command -v ninja >/dev/null && GEN="-G Ninja"

say "Configuring (prefix: $PREFIX)"
cmake -S "$SRC" -B "$SRC/build" $GEN -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX"
say "Building"
cmake --build "$SRC/build" -j "$JOBS"

say "Installing to $PREFIX"
if [ "$USER_INSTALL" -eq 1 ] || [ -w "$PREFIX" ]; then
    cmake --install "$SRC/build"
else
    say "root required to write to $PREFIX"
    sudo cmake --install "$SRC/build"
fi

say "Done — run: vespera   (health check: vespera doctor)"
if [ "$USER_INSTALL" -eq 1 ]; then
    case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) echo "note: add ~/.local/bin to your PATH";; esac
fi
