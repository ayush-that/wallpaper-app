# Wallpaper.app

A native macOS live wallpaper engine. Goal: feature-equivalent to [Lively](https://github.com/rocksdanister/lively) (Windows) and [Wallpaper Engine](https://www.wallpaperengine.io), but built specifically for macOS in Swift.

**Status:** Planning. See `docs/superpowers/plans/` for the implementation roadmap.

## Target

- macOS 14 Sonoma minimum (`-target arm64-apple-macos14.0`), macOS 15 Sequoia for primary development.
- Universal binary (Apple Silicon + Intel).
- Distributed outside the App Store (sandbox would block desktop-window manipulation).

## License

Private until v1.0.
