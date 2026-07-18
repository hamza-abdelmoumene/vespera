# Security Policy

## Supported versions

Vespera is pre-1.0; security fixes are applied to the latest release and `main`.

## Reporting a vulnerability

Please report suspected vulnerabilities privately using GitHub's
[**Report a vulnerability**](https://github.com/hamza-abdelmoumene/vespera/security/advisories/new)
feature (Security → Advisories). Do not open a public issue for security matters.

Include a description, affected version, and steps to reproduce. You can expect an
acknowledgement within a reasonable timeframe.

## Security model

Vespera is a media *controller*, and its attack surface is intentionally small:

- **Runs unprivileged.** It never asks for root and needs no special
  capabilities. Installation may use `sudo` only to copy files into a system
  prefix; the application itself does not.
- **Session bus only.** It speaks MPRIS on the D-Bus *session* bus to observe and
  control media players, and owns `org.vespera.Vespera` for its own IPC. It does
  not touch the system bus.
- **Network use is limited to lyric lookups** over HTTPS to `lrclib.net` (and, as
  a fallback, `music.163.com`). Only the current track's artist/title/album and
  duration are sent, as query parameters, to fetch lyrics. There is **no
  telemetry, no analytics, and no account**.
- **No shell interpolation.** External programs (`cava`, `easyeffects`) are
  launched with explicit argument lists via `QProcess`, never through a shell, so
  metadata cannot be interpreted as commands.
- **Writes only to XDG paths** it owns (`~/.config/vespera`,
  `~/.local/share/vespera`, and the EasyEffects presets directory) using atomic
  saves.

## About the install script

`install.sh` can be piped to a shell (`curl … | bash`). Piping any script to a
shell is a trust decision. Prefer to download and read it first:

```sh
curl -fsSLO https://raw.githubusercontent.com/hamza-abdelmoumene/vespera/main/install.sh
less install.sh
bash install.sh
```

## A note on provenance

Vespera was written with AI assistance ("vibe-coded"). The code is reviewed and
builds reproducibly, but you are encouraged to read it before deploying in
sensitive environments.
