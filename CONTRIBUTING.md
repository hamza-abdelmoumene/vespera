# Contributing to Vespera

Thanks for your interest. Vespera aims to be a calm, professional, genuinely
cross-distro music companion — contributions that keep it that way are very
welcome.

## Ground rules

- **Stay distro-agnostic.** No dependency on a specific shell, compositor, or
  dotfiles. No hardcoded user paths — use XDG locations (`QStandardPaths`).
- **Degrade gracefully.** Optional tools (cava, EasyEffects, …) must be detected
  at runtime; a missing tool hides its feature with a friendly state, never a
  crash.
- **No telemetry, no accounts, no DRM.** Vespera is a controller.
- **No emoji in the UI.** Use geometric glyphs or drawn icons.

## Development setup

```sh
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build build
./build/vespera
```

Build dependencies are listed in the README. `compile_commands.json` is emitted
into `build/` for editor tooling (clang-based LSPs, `.qmlls.ini` for QML).

The C++ core lives in `src/core/` (MPRIS, palette, lyrics, cava, EQ, IPC); the UI
is in `qml/`. Services are exposed to QML as context objects (`Player`, `Lyrics`,
`Cava`, `Eq`, `App`).

## Making changes

1. Fork and branch off `main` (`feature/…` or `fix/…`).
2. Keep commits focused; write clear messages.
3. Match the surrounding style. C++ is C++20; QML follows the existing component
   conventions.
4. Verify it builds cleanly and the app runs. For UI changes, sanity-check at a
   few window sizes — offscreen screenshots help:
   ```sh
   QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
     ./build/vespera --capture 1200 780 /tmp/shot.png
   ```
5. Open a pull request describing what changed and why, with screenshots for UI
   work.

## Reporting bugs / requesting features

Use the [issue tracker](https://github.com/hamza-abdelmoumene/vespera/issues).
For bugs, include your distro, Qt version, `vespera doctor` output, and steps to
reproduce.

## License

By contributing, you agree that your contributions are licensed under the MIT
License that covers the project.
