import AppKit
import OSLog
import WebKit

@MainActor
public final class WebRenderer: NSObject, WallpaperRenderer {
    private let log = Log.logger("WebRenderer")
    private let entryURL: URL
    private let packageRoot: URL
    private let webView: WKWebView
    private weak var host: WallpaperHost?

    /// Optional callback for JS→native messages — set by the orchestrator if it
    /// needs to observe console / propertyChanged / ready events.
    public var onBridgeMessage: (@MainActor (WebBridgeMessage) -> Void)?

    /// Active audio subscription. The broadcaster is retained alongside the token
    /// so `detach()` can unsubscribe without the caller having to pass it back in.
    private var currentAudioToken: (AudioBroadcaster, AudioBroadcaster.Token)?

    public init(entryURL: URL, packageRoot: URL) {
        self.entryURL = entryURL
        self.packageRoot = packageRoot
        webView = Self.makeWebView()
        super.init()
        Self.attachBridge(to: webView, target: self)
        webView.navigationDelegate = self
    }

    /// Convenience initializer for remote URLs (Phase 4 Task 4 wires this for `urlPage` wallpapers).
    public convenience init(remoteURL: URL) {
        self.init(entryURL: remoteURL, packageRoot: remoteURL.deletingLastPathComponent())
    }

    // MARK: - WallpaperRenderer

    public func attach(to host: WallpaperHost) {
        self.host = host
        host.install(view: webView)
        loadEntry()
    }

    public func detach() {
        if let (broadcaster, token) = currentAudioToken {
            broadcaster.unsubscribe(token)
            currentAudioToken = nil
        }
        webView.stopLoading()
        webView.loadHTMLString("", baseURL: nil)
        host?.clear()
        host = nil
    }

    public func pause() {
        // Hiding the document drops requestAnimationFrame callbacks on most pages
        // without tearing down the renderer. Cheaper than load(""), which would
        // also kill timers but require a reload on resume.
        webView.evaluateJavaScript(
            "document.documentElement.style.visibility='hidden';",
            completionHandler: nil
        )
    }

    public func resume() {
        webView.evaluateJavaScript(
            "document.documentElement.style.visibility='';",
            completionHandler: nil
        )
    }

    // MARK: - Public API for orchestrator

    /// Push a property change down to the page's `livelyPropertyListener`.
    public func set(property name: String, value: WebBridgePropertyValue) {
        let valueJS = Self.javaScriptLiteral(for: value)
        let nameJS = Self.escapedJSString(name)
        let js = "try{livelyPropertyListener('\(nameJS)', \(valueJS));}catch(e){console.error(e.message);}"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    /// Push an FFT-binned audio array to `livelyAudioListener` (Phase 6 wires this).
    public func deliver(audioArray: [Float]) {
        let payload = audioArray.map { String($0) }.joined(separator: ",")
        let js = "try{livelyAudioListener([\(payload)]);}catch(e){}"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    /// Subscribe to an audio broadcaster. The broadcaster will call
    /// `deliver(audioArray:)` on each FFT tick. Idempotent — re-attaching to
    /// the same (or a different) broadcaster replaces the prior subscription.
    public func attachAudio(_ broadcaster: AudioBroadcaster) {
        if let (currentBroadcaster, token) = currentAudioToken {
            currentBroadcaster.unsubscribe(token)
            currentAudioToken = nil
        }
        // The handler runs on the broadcaster's publisher thread (main, in the
        // current pipeline). We hop to main explicitly so the contract holds
        // even if a future publisher posts off-main. `WebRendererWeakBox` lets
        // us weakly reference a `@MainActor` class from a `@Sendable` closure
        // without tripping Swift 6 strict-concurrency diagnostics.
        let box = WebRendererWeakBox(self)
        let token = broadcaster.subscribe { bins in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    box.value?.deliver(audioArray: bins)
                }
            }
        }
        currentAudioToken = (broadcaster, token)
    }

    /// Unsubscribe from `broadcaster` if it is the currently-attached one.
    /// Detaching from a different broadcaster is a no-op so callers don't
    /// accidentally tear down an unrelated subscription.
    public func detachAudio(from broadcaster: AudioBroadcaster) {
        if let (currentBroadcaster, token) = currentAudioToken,
           currentBroadcaster === broadcaster
        {
            broadcaster.unsubscribe(token)
            currentAudioToken = nil
        }
    }

    // MARK: - Helpers

    private func loadEntry() {
        if entryURL.isFileURL {
            webView.loadFileURL(entryURL, allowingReadAccessTo: packageRoot)
        } else {
            webView.load(URLRequest(url: entryURL))
        }
    }

    private static func makeWebView() -> WKWebView {
        let config = WKWebViewConfiguration()

        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        // file:// → file:// access is the only way local wallpapers can pull
        // in their sibling assets (CSS, images, JS). KVC is the only way to set this.
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        // Developer tools available for debugging via Safari → Develop menu.
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsAirPlayForMediaPlayback = false

        let webView = WKWebView(frame: .zero, configuration: config)
        // Transparent background — the only public path on macOS 15+.
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsBackForwardNavigationGestures = false
        webView.allowsLinkPreview = false
        return webView
    }

    private static func attachBridge(to webView: WKWebView, target: WebRenderer) {
        let controller = webView.configuration.userContentController
        if let bridgeURL = Self.bridgeJSURL(),
           let source = try? String(contentsOf: bridgeURL, encoding: .utf8)
        {
            let userScript = WKUserScript(
                source: source,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
            controller.addUserScript(userScript)
        }
        controller.add(BridgeMessageRelay(owner: target), name: "muralBridge")
    }

    private static func bridgeJSURL() -> URL? {
        if let direct = Bundle.main.url(forResource: "mural-bridge", withExtension: "js") {
            return direct
        }
        return Bundle.main.url(forResource: "mural-bridge", withExtension: "js", subdirectory: "Resources")
    }

    /// Escape a single-quoted JS string literal. Handles backslashes, single
    /// quotes, newlines. Inputs are property names from a manifest — short
    /// enough that a regex isn't needed.
    private static func escapedJSString(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    fileprivate static func javaScriptLiteral(for value: WebBridgePropertyValue) -> String {
        switch value {
        case let .bool(v): v ? "true" : "false"
        case let .int(v): "\(v)"
        case let .double(v): "\(v)"
        case let .string(v), let .color(v):
            "'\(escapedJSString(v))'"
        }
    }

    // MARK: - Test seams

    #if DEBUG
        /// Test-only accessor for assertions on the underlying WKWebView.
        var testWebView: WKWebView {
            webView
        }
    #endif
}

// MARK: - WKNavigationDelegate

extension WebRenderer: WKNavigationDelegate {
    public func webView(
        _: WKWebView,
        didFail _: WKNavigation!,
        withError error: Error
    ) {
        log.error("WebRenderer navigation failed: \(error.localizedDescription, privacy: .public)")
    }

    public func webView(
        _: WKWebView,
        didFailProvisionalNavigation _: WKNavigation!,
        withError error: Error
    ) {
        log.error("WebRenderer provisional navigation failed: \(error.localizedDescription, privacy: .public)")
    }
}

/// `WKScriptMessageHandler` keeps a strong reference to its target. We don't
/// want WKWebView retaining the WebRenderer indefinitely, so we use a small
/// weak-relay class for the message handler.
@MainActor
private final class BridgeMessageRelay: NSObject, WKScriptMessageHandler {
    private weak var owner: WebRenderer?

    init(owner: WebRenderer) {
        self.owner = owner
        super.init()
    }

    func userContentController(
        _: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        // WKScriptMessageHandler is MainActor-isolated via WK_SWIFT_UI_ACTOR.
        guard message.name == "muralBridge" else { return }
        guard let dict = message.body as? [String: Any],
              let data = try? JSONSerialization.data(withJSONObject: dict),
              let decoded = try? JSONDecoder().decode(WebBridgeMessage.self, from: data)
        else { return }
        owner?.handle(bridgeMessage: decoded)
    }
}

private extension WebRenderer {
    func handle(bridgeMessage: WebBridgeMessage) {
        if case let .console(level, text) = bridgeMessage {
            log.info("[web/\(level, privacy: .public)] \(text, privacy: .public)")
        }
        onBridgeMessage?(bridgeMessage)
    }
}

/// Sendable weak holder so audio broadcaster handlers can reference the
/// `@MainActor`-isolated `WebRenderer` without forcing a strong capture.
/// The `@unchecked Sendable` is justified: `weak` references are atomic on
/// Apple platforms, and the box is only read after a hop to the main actor.
private final class WebRendererWeakBox: @unchecked Sendable {
    weak var value: WebRenderer?
    init(_ value: WebRenderer) {
        self.value = value
    }
}
