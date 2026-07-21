#!/usr/bin/env bash
#
# Vespera installer — installs build dependencies, builds from source, and installs.
#
# Run inside a checkout:      ./install.sh
# Or standalone (clones):     curl -fsSL https://raw.githubusercontent.com/hamza-abdelmoumene/vespera/main/install.sh | bash
# No-root user install:       ./install.sh --user      (installs into ~/.local)
#
# Options:
#   --user            install into ~/.local (no root)
#   --prefix=/path    install into a custom prefix (default: /usr/local)
#   --no-deps         don't try to install build dependencies automatically
#
# Piping any script to a shell is a trust decision. Prefer to download and read it
# first:  curl -fsSLO .../install.sh && less install.sh && bash install.sh
set -euo pipefail

REPO="https://github.com/hamza-abdelmoumene/vespera.git"
PREFIX="${PREFIX:-/usr/local}"
USER_INSTALL=0
NO_DEPS=0
JOBS="$(nproc 2>/dev/null || echo 2)"

for a in "$@"; do
    case "$a" in
        --user) USER_INSTALL=1; PREFIX="$HOME/.local" ;;
        --prefix=*) PREFIX="${a#*=}" ;;
        --no-deps) NO_DEPS=1 ;;
        -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
        *) echo "unknown option: $a" >&2; exit 2 ;;
    esac
done

say()  { printf '\033[36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[33m warn:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }
as_root() { if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi; }

deps_present() {
    have cmake \
        && { have g++ || have clang++; } \
        && { have qmake6 || pkg-config --exists Qt6Core 2>/dev/null || pkg-config --exists Qt6Quick 2>/dev/null; }
}

# Detect the distro's package manager and install the Qt 6 + build toolchain.
install_deps() {
    local id="" ; [ -r /etc/os-release ] && id="$(. /etc/os-release; echo "${ID} ${ID_LIKE:-}")"
    say "Installing build dependencies (Qt 6 + toolchain)…"
    case " $id " in
        *arch*|*manjaro*|*endeavouros*|*cachyos*)
            as_root pacman -S --needed --noconfirm base-devel cmake ninja qt6-base qt6-declarative ;;
        *debian*|*ubuntu*|*pop*|*mint*|*elementary*)
            as_root apt-get update
            as_root apt-get install -y build-essential cmake ninja-build \
                qt6-base-dev qt6-declarative-dev libqt6svg6 ;;
        *fedora*|*rhel*|*centos*|*rocky*|*almalinux*)
            as_root dnf install -y gcc-c++ cmake ninja-build \
                qt6-qtbase-devel qt6-qtdeclarative-devel ;;
        *suse*|*opensuse*)
            as_root zypper install -y gcc-c++ cmake ninja \
                qt6-base-devel qt6-declarative-devel ;;
        *)
            die "Couldn't detect your package manager. Install Qt 6.5+ (base + declarative),
       CMake 3.21+, Ninja and a C++20 compiler, then re-run with --no-deps." ;;
    esac
}

if ! deps_present; then
    if [ "$NO_DEPS" -eq 1 ]; then
        die "Missing build dependencies. Install Qt 6.5+ (base + declarative), CMake, a
       C++20 compiler, then re-run."
    fi
    install_deps
    deps_present || die "Dependencies still missing after install — please install them manually."
fi

if [ -f CMakeLists.txt ] && grep -q "project(vespera" CMakeLists.txt 2>/dev/null; then
    SRC="$(pwd)"
    say "Building from the current checkout"
else
    have git || die "git is required to fetch the source"
    SRC="$(mktemp -d)"
    trap 'rm -rf "$SRC"' EXIT
    say "Cloning $REPO"
    git clone --depth 1 "$REPO" "$SRC"
fi

GEN=""
have ninja && GEN="-G Ninja"

say "Configuring (prefix: $PREFIX)"
cmake -S "$SRC" -B "$SRC/build" $GEN -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX"
say "Building"
cmake --build "$SRC/build" -j "$JOBS"

say "Installing to $PREFIX"
if [ "$USER_INSTALL" -eq 1 ] || [ -w "$PREFIX" ]; then
    cmake --install "$SRC/build"
else
    as_root cmake --install "$SRC/build"
fi

say "Done — run: vespera   (health check: vespera doctor)"
if [ "$USER_INSTALL" -eq 1 ]; then
    case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) warn "add ~/.local/bin to your PATH to run 'vespera' directly";; esac
fi
