import 'dart:convert';

/// Builds the bootstrap JavaScript that defines the SCORM 1.2 `window.API` a
/// package looks for. Shared by every platform host; only [sendBody] differs —
/// it's the statement that ships a JSON payload to the Dart side:
///
/// - web:    `window.__scormDartSend(p);`
/// - native: `window.flutter_inappwebview.callHandler('scorm', p);`
///
/// [initialCmi] seeds the CMI map (student name, resume bookmark, suspend data,
/// entry mode) so `LMSGetValue` returns sensible values and Resume works.
///
/// `window.API` is defined **non-writable** (the CLAUDE.md gotcha): a SCO's
/// `var API = null;` at global scope in the same frame would otherwise clobber
/// it; `Object.defineProperty` makes that assignment a no-op.
String buildScormBootstrapJs({
  required Map<String, String> initialCmi,
  required String sendBody,
}) {
  final initJson = jsonEncode(initialCmi);
  return '''
(function () {
  if (window.__scormApiReady) { return; }
  window.__scormApiReady = true;

  var cmi = $initJson;
  var errorCode = "0";

  function send(type, extra) {
    try {
      var payload = { type: type, cmi: cmi };
      if (extra) { for (var k in extra) { payload[k] = extra[k]; } }
      var p = JSON.stringify(payload);
      $sendBody
    } catch (e) {}
  }

  var API = {
    LMSInitialize: function () { errorCode = "0"; send("init"); return "true"; },
    LMSFinish: function () { send("finish"); return "true"; },
    LMSGetValue: function (k) {
      errorCode = "0";
      return (cmi[k] !== undefined && cmi[k] !== null) ? String(cmi[k]) : "";
    },
    LMSSetValue: function (k, v) {
      cmi[k] = v;
      errorCode = "0";
      send("set", { key: k, value: String(v) });
      return "true";
    },
    LMSCommit: function () { send("commit"); return "true"; },
    LMSGetLastError: function () { return errorCode; },
    LMSGetErrorString: function (c) { return ""; },
    LMSGetDiagnostic: function (c) { return ""; }
  };

  try {
    Object.defineProperty(window, "API", {
      value: API, writable: false, configurable: true
    });
  } catch (e) {
    window.API = API;
  }
})();
''';
}
