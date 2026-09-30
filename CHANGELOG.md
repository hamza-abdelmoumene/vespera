# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- Near-idle when the window is on a hidden or special workspace: Wayland keeps
  reporting the window as visible, so cava kept streaming at 60 fps and the
  scene kept animating off screen. Vespera now notices when the compositor stops
  taking frames and pauses cava, the backdrop, the disc spin and the lyrics
  follow timer until it is shown again (3.7% → 0.7% of a core while hidden).

## [0.2.0] - 2026-09-30

A full visual redesign. (Everything below was only in `vespera-git` until now —
the `vespera` package was still on 0.1.0.)

### Added

- **Theme engine**: eight built-in themes (Vespera, Ember, Obsidian, Velvet,
  Starlit, Noir, Aurora, Neon) plus user JSON themes in
  `~/.config/vespera/themes`. The new default, Vespera, is fully album-dynamic —
  accent, base, grade and orbs recolour per track with a smooth cross-fade
  across every surface.
- **Real glass**: panels blur what is behind them (with a frost fallback on
  software rendering), with elevation shadows and inner depth.
- **Backdrop**: a translucent album-tinted ground, a blurred and graded cover
  as a colour field, and large soft floating orbs.
- **Block-letter karaoke lyrics** alongside the synced list, plus a toggle to
  hide lyrics and go full-width.
- **Equalizer**: a one-shot "lightning" bolt sweeps through the bands when a
  preset is applied, each slider reacting as it passes (can be switched off).
- **Settings drawer** with live knobs for cover, orbs, transparency, frost,
  blur, glow, accent, vignette, motion, lyrics, EQ and type; a reduce-motion
  switch; all persisted.
- **First-run tutorial** and a `?` help overlay.
- Window drag-to-move and a minimize button; press/hover feedback throughout.
- The installer now installs Qt and the toolchain for your distro.

### Changed

- Transport controls are centred on the wide layout, and the compact view
  scales cleanly from the minimum window size up.

### Fixed

- Lyrics for the previous track could appear after the player closed, and every
  track skip fired a wasted lyrics request: cancelling a lookup let the aborted
  request start the next fallback search.
- The lyrics loading spinner never turned.
- Blocky, muddy cover backdrop at large window sizes.
- Effects silently rendering blank on software/offscreen rendering.
- Demo/screenshot mode no longer leaks the live player's cover art.

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

[Unreleased]: https://github.com/hamza-abdelmoumene/vespera/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/hamza-abdelmoumene/vespera/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/hamza-abdelmoumene/vespera/releases/tag/v0.1.0
