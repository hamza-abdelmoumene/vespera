# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-07-18

Initial release.

### Added

- MPRIS controller over QtDBus: enumerate players, ranked active-player
  selection with browser de-prioritisation, play/pause/next/previous/seek, live
  position and metadata.
- In-process album-art palette extraction (OKLCh-normalised, no ImageMagick)
  driving the whole UI theme.
- Synced lyrics via lrclib with a NetEase fallback: auto-scroll, click-to-seek,
  per-track offset (persisted), and resync.
- cava audio visualizer (optional) with an album-tinted bar spectrum.
- 10-band equalizer applied through EasyEffects (optional) with presets and a
  lightning-sweep animation.
- Responsive layout: player | lyrics two-pane on wide windows, compact
  now-playing card on narrow ones; remembers size and position.
- Single-instance D-Bus control (`org.vespera.Control`) and a CLI:
  `toggle | show | hide | play-pause | next | prev`.
- Keyboard shortcuts (space, arrows, n/p) and `vespera doctor` health check.
- Packaging: CMake install (binary, desktop entry, icon, AppStream metainfo),
  AUR PKGBUILDs, Flatpak manifest, AppImage recipe, and CI that ships an
  AppImage and source tarball on tag.

[Unreleased]: https://github.com/hamza-abdelmoumene/vespera/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/hamza-abdelmoumene/vespera/releases/tag/v0.1.0
