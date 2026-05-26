import AppKit

/// A `WallpaperRenderer` is the unit of rendering for one display. Every wallpaper
/// type (video, image, gif, web, shader, app-window) implements this protocol and
/// the engine swaps instances in and out of per-display `WallpaperHost` views.
///
/// `attach` installs the rendering surface into the host. `detach` releases media
/// resources and returns the host to a transparent state. `pause` halts animation
/// without tearing down resources — `resume` brings it back. `pause` and `resume`
/// must be safe to call repeatedly and in any order; idempotency is the contract.
public protocol WallpaperRenderer: AnyObject {
    @MainActor func attach(to host: WallpaperHost)
    @MainActor func detach()
    @MainActor func pause()
    @MainActor func resume()
}
