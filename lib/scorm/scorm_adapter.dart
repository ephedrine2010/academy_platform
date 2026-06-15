/// JavaScript injected into the WebView **before the page loads**.
///
/// It defines a minimal **SCORM 1.2** `window.API` object — exactly what the
/// ADL "API discovery algorithm" (see `assets/golf/shared/scormfunctions.js`)
/// walks the window tree looking for. Every call the package makes is mirrored
/// back to Flutter through the WebView2 message channel
/// (`window.chrome.webview.postMessage`).
///
/// This is intentionally tiny — it covers what the Golf sample needs. For
/// production, swap this for the full `scorm-again` runtime (SCORM 1.2 + 2004).
///
/// IMPORTANT: the package's `scormfunctions.js` runs `var API = null;` at global
/// scope (because in a real LMS the API lives in a *parent* window). Since we
/// inject into the same frame, that line would clobber our adapter. We therefore
/// define `window.API` as **non-writable** so the package's `API = null`
/// assignment silently no-ops (the file is non-strict) and our adapter survives.
const String scorm12AdapterJs = r'''
(function () {
  if (window.__academyScormInjected) return;
  window.__academyScormInjected = true;

  // In-memory CMI data model (enough for the POC).
  var data = {};

  function post(type, payload) {
    try {
      window.chrome.webview.postMessage(
        JSON.stringify({ type: type, payload: payload || {} })
      );
    } catch (e) {
      // No host channel (e.g. opened in a plain browser) — ignore.
    }
  }

  var api = {
    LMSInitialize: function () {
      post('Initialize', {});
      return 'true';
    },
    LMSFinish: function () {
      post('Finish', { data: data });
      return 'true';
    },
    LMSGetValue: function (key) {
      return data[key] != null ? String(data[key]) : '';
    },
    LMSSetValue: function (key, value) {
      data[key] = value;
      post('SetValue', { key: key, value: String(value) });
      return 'true';
    },
    LMSCommit: function () {
      post('Commit', { data: data });
      return 'true';
    },
    LMSGetLastError: function () {
      return '0';
    },
    LMSGetErrorString: function () {
      return '';
    },
    LMSGetDiagnostic: function () {
      return '';
    }
  };

  // Lock window.API so the package's `var API = null;` cannot overwrite it.
  try {
    Object.defineProperty(window, 'API', {
      value: api,
      writable: false,
      configurable: true,
      enumerable: true
    });
  } catch (e) {
    window.API = api;
  }

  post('AdapterReady', { url: String(window.location.href) });
})();
''';
