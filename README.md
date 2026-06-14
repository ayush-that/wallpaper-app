# Mural

A native macOS live wallpaper engine. Animated video, web, and Metal shader wallpapers rendered behind your desktop icons, on every display, with low CPU and respect for fullscreen apps and battery.

[![CI](https://github.com/ayush-that/wallpaper-app/actions/workflows/ci.yml/badge.svg)](https://github.com/ayush-that/wallpaper-app/actions/workflows/ci.yml)
[![Latest release](https://img.shields.io/github/v/release/ayush-that/wallpaper-app?sort=semver)](https://github.com/ayush-that/wallpaper-app/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/ayush-that/wallpaper-app/total)](https://github.com/ayush-that/wallpaper-app/releases)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-000000?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift 5.10](https://img.shields.io/badge/Swift-5.10-F05138?logo=swift&logoColor=white)](https://swift.org)
[![License: GPL v3](https://img.shields.io/badge/license-GPLv3-blue.svg)](LICENSE)

> [!WARNING]
> **Mural is alpha software and a work in progress.** It is under active
> development and nowhere near a finished product. Expect rough edges, missing
> features, bugs, and breaking changes at any time. Use it at your own risk.

Mural lives in the menu bar and draws a live wallpaper on the desktop layer, behind your icons, on each connected display. It pauses itself when a fullscreen app is in front, when you unplug from power, or when Low Power Mode is on, so an animated desktop never costs you a battery charge.

## Features

- **Video wallpapers** from mp4, mov, webm/VP9, mkv, and m4v, hardware decoded with audio suppressed by default
- **Web/HTML/JS wallpapers** with a JavaScript bridge for live property tweaks and a 128-bin audio FFT
- **Metal shader wallpapers** in the ShaderToy fragment-shader style
- **Animated GIF** and **static image** wallpapers
- **App-window wallpapers**: project another app's window onto the wallpaper layer via ScreenCaptureKit
- **Per-display control** with independent scale modes (fill, fit, stretch, center, tile)
- **Automatic pausing** on fullscreen apps, battery, Low Power Mode, a foreground app rule, or a remote session
- **Playlists** with interval, shuffle, and time-of-day rotation
- **Wallpaper packages** imported from a `.zip` bundle or a `.pkg` archive
- **A command-line interface** (`muralctl`) that drives the running app over a local socket
- **Automatic updates** through Sparkle 2, notarized for Developer ID distribution

## Install

### Homebrew

```bash
brew install --cask ayush-that/mural/mural
```

Updates then arrive with `brew upgrade --cask mural`.

### Direct download

Grab the latest notarized `.dmg` from the [releases page](https://github.com/ayush-that/wallpaper-app/releases/latest), open it, and drag Mural to Applications. The app updates itself in place through Sparkle.

## Requirements

- macOS 14 Sonoma or newer
- Universal binary (Apple Silicon and Intel)
- Distributed outside the App Store, since the sandbox would block the desktop-window technique

## Build from source

The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen). Never edit `Mural.xcodeproj` directly; it is a build artifact.

```bash
brew install xcodegen xcbeautify
xcodegen generate
xcodebuild -scheme Mural -configuration Debug -destination 'platform=macOS' build | xcbeautify
```

Run the test suite:

```bash
xcodebuild test -scheme Mural -destination 'platform=macOS' | xcbeautify
```

Format and lint:

```bash
./scripts/lint.sh        # check formatting and linting
swiftformat App Sources Tests Tools   # auto-fix formatting
```

## Architecture

Mural is a single app target, organized into layers by folder convention:

| Layer | Responsibility |
| --- | --- |
| `MuralKit` | Models, GRDB-backed library and catalog, importers, settings, IPC, logging |
| `MuralWindowing` | The desktop-window technique: borderless click-through windows on the desktop layer, one host per display |
| `MuralRenderers` | One renderer per wallpaper type, the engine that attaches them, and the orchestrator the UI calls into |
| `MuralPolicy` | The pause and throttle stack: fullscreen, power, foreground-app, and thermal watchers |
| `MuralPlaylist` | Playlist model and scheduler |
| `MuralUI` | SwiftUI menu bar, library, playlists, properties, and settings |
| `MuralUpdates` | Sparkle 2 update manager |

`Tools/muralctl` is a separate CLI target that talks to the running app over a Unix domain socket.

## Contributing

Issues and pull requests are welcome. Before opening a PR:

- Run `./scripts/lint.sh` and make sure it passes
- Run the test suite and keep it green
- Keep new code concurrency-clean, since the build enforces strict concurrency and treats warnings as errors

## License

Mural is licensed under the [GNU General Public License v3.0](LICENSE).
