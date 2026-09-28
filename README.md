# er (二)

[![pipeline](https://gitlab.com/HttpAnimations/er/badges/main/pipeline.svg)](https://gitlab.com/HttpAnimations/er/-/pipelines)
[![release](https://gitlab.com/HttpAnimations/er/-/badges/release.svg)](https://gitlab.com/HttpAnimations/er/-/releases)
[![landing page](https://img.shields.io/badge/site-er--7708c3.gitlab.io-2DD4BF)](https://er-7708c3.gitlab.io)

Run the same Flatpak app multiple times, fully isolated. Each instance gets its
own home directory, its own `~/.var/app/<id>` data, and its own D-Bus session
bus, so apps that normally refuse a second window happily run side by side.

Built to multi-box [Mocktail](https://github.com/komaruworld/mocktail)
(`space.bigrat.mocktail`), but it works with any installed Flatpak.

## How it works

For each instance, er launches:

```
setsid bwrap --dev-bind / / --bind <instance>/home $HOME \
  --bind $HOME/.local/share/flatpak $HOME/.local/share/flatpak \
  -- dbus-run-session -- flatpak run <app-id>
```

The bind mount makes the app's entire view of `$HOME` (including
`~/.var/app/<id>` where Flatpak keeps per-app config/data/cache) live inside the
instance directory. The private session bus prevents D-Bus single-instance
detection from forwarding to an already-running copy. Everything else (display,
network, devices) is shared.

Requires `flatpak`, `bubblewrap`, and `dbus-run-session` (all standard on a
Flatpak-capable Linux system).

When er itself is installed as a flatpak it detects the sandbox and runs the
same pipeline through `flatpak-spawn --host`, so instances behave identically
to the native build.

## Install

The easiest way is the flatpak repo hosted on GitLab Pages:

```
flatpak install https://er-7708c3.gitlab.io/flatpak/er.flatpakref
```

Or download the latest release for your architecture from the
[releases page](https://gitlab.com/HttpAnimations/er/-/releases) (tar.gz, zip,
.deb, .rpm, or AppImage) and run `er`.

## Web

The web build serves a landing page only; the app itself is Linux-only since
Flatpak is a Linux technology.

## Development

```bash
flutter pub get
flutter run -d linux
flutter test --coverage
```

## License

[AGPL-3.0](LICENSE)
