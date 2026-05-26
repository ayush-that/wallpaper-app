(function () {
  if (window.__muralBridgeInstalled) return;
  window.__muralBridgeInstalled = true;

  // Default-no-op stubs for the global functions a wallpaper author may
  // override. We assign with ||= so any pre-existing user definitions win.
  window.livelyPropertyListener         ||= function (_name, _value) {};
  window.livelyAudioListener            ||= function (_array) {};
  window.livelyCurrentTrack             ||= function (_json) {};
  window.livelySystemInformation        ||= function (_json) {};
  window.livelyWallpaperPlaybackChanged ||= function (_json) {};

  function post(message) {
    try {
      webkit.messageHandlers.muralBridge.postMessage(message);
    } catch (_) {
      // No native bridge present (e.g. opened in regular browser for debugging).
    }
  }

  // Forward console.{log,info,warn,error} to native logging.
  ['log', 'info', 'warn', 'error'].forEach(function (level) {
    var original = console[level].bind(console);
    console[level] = function () {
      try {
        var args = Array.prototype.slice.call(arguments);
        var message = args.map(function (a) {
          try { return typeof a === 'string' ? a : JSON.stringify(a); }
          catch (_) { return String(a); }
        }).join(' ');
        post({ type: 'console', level: level, message: message });
      } catch (_) {}
      original.apply(null, arguments);
    };
  });

  // Public surface for user JS to call back into native.
  window.mural = {
    postProperty: function (name, value) {
      post({ type: 'propertyChanged', name: name, value: value });
    },
    ready: function () {
      post({ type: 'ready' });
    }
  };

  // Disable scrollbars, text selection, drag, and give body a transparent background.
  function installStylesheet() {
    if (document.getElementById('__muralBridgeStyles')) return;
    var style = document.createElement('style');
    style.id = '__muralBridgeStyles';
    style.textContent =
      'html,body{margin:0;padding:0;height:100%;width:100%;overflow:hidden;' +
      '-webkit-user-select:none;user-select:none;-webkit-user-drag:none;}' +
      'body{background:transparent;}';
    (document.head || document.documentElement).appendChild(style);
  }

  // Hard-mute every HTMLMediaElement (video, audio). Wallpapers can produce
  // sound via WebAudio if they want; baseline media elements are always silent.
  function muteMedia() {
    if (!window.HTMLMediaElement) return;
    HTMLMediaElement.prototype._muralMuted = true;
    var descriptor = Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype, 'muted');
    if (!descriptor) return;
    var setter = descriptor.set;
    Object.defineProperty(HTMLMediaElement.prototype, 'muted', {
      configurable: true,
      enumerable: true,
      get: function () { return true; },
      set: function (_) { setter.call(this, true); }
    });
    document.addEventListener('play', function (e) {
      try { e.target.muted = true; } catch (_) {}
    }, true);
  }

  installStylesheet();
  muteMedia();

  // Fire 'ready' once DOM is parsed (or immediately if we landed late).
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function () { post({ type: 'ready' }); });
  } else {
    post({ type: 'ready' });
  }
})();
