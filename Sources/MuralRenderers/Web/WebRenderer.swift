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
