# Mural

A native macOS live wallpaper engine. Animated video, web, and shader wallpapers rendered behind your desktop icons, on every display, with low CPU and respect for fullscreen apps + battery.

**Status:** under development. Shipped phases tagged `v0.x.0`; the current roadmap lives in `docs/superpowers/plans/`.

## What it does

- Loop video files (mp4, mov, webm/VP9, mkv, m4v) as the desktop wallpaper
- Hardware-decoded, audio suppressed by default
- Pause when a fullscreen app covers the display, when the laptop is on battery, when Low Power Mode is on, or when a specific app is in the foreground
- Multi-display: per-screen scale modes (fill / fit / stretch / center / tile)
- Import wallpaper packages from a `.zip` bundle or a `.pkg` archive
- Web/HTML/JS wallpapers with a JavaScript bridge for live property tweaks and 128-bin audio FFT
- ShaderToy-style fragment shaders via Metal
- Animated GIF wallpapers
- Project another app's window onto the wallpaper layer (capture via ScreenCaptureKit)
- Wallpaper playlists with interval / shuffle / time-of-day rotation
- Auto-update via Sparkle 2, notarized for Developer ID distribution

## Target

- macOS 14 Sonoma minimum (`MACOSX_DEPLOYMENT_TARGET=14.0`)
- Universal binary (Apple Silicon + Intel)
- Distributed outside the App Store (sandbox would block the desktop-window technique)

## License

Private until v1.0.
