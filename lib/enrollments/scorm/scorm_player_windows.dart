import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';

import 'scorm_api_js.dart';
import 'scorm_session.dart';

/// Windows SCORM host, backed by **`webview_windows`** (WebView2) instead of
/// `flutter_inappwebview`. The InAppWebView Windows backend hard-`abort()`s the
/// whole process mid-load on real packages; `webview_windows` is the plugin the
/// original SCORM POC used on Windows and is proven stable.
///
/// It reuses the shared brain — [buildScormBootstrapJs] for the injected
/// `window.API` and [ScormSession] for CMI→progress — so web, Android and
/// Windows all interpret SCORM identically; only the shell differs.
///
/// The API is injected at document-start via
/// `addScriptToExecuteOnDocumentCreated` (so the SCO's discovery finds it), and
/// posts back through `window.chrome.webview.postMessage`; the plugin
/// JSON-decodes the payload before emitting it on [WebviewController.webMessage].
class WindowsScormPlayer extends StatefulWidget {
  const WindowsScormPlayer({
    super.key,
    required this.contentUrl,
    required this.initialCmi,
    required this.onProgress,
  });

  final String contentUrl;
  final Map<String, String> initialCmi;
  final void Function(ScormProgress progress) onProgress;

  @override
  State<WindowsScormPlayer> createState() => _WindowsScormPlayerState();
}

class _WindowsScormPlayerState extends State<WindowsScormPlayer> {
  final WebviewController _controller = WebviewController();
  final ScormSession _session = ScormSession();

  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _controller.initialize();
      await _controller.setBackgroundColor(Colors.white);
      await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);

      _controller.onLoadError.listen(
        (err) => debugPrint('[SCORM] loadError (windows): $err'),
      );

      // Inject window.API before any document loads. Native has no parent
      // frame, so the API lives on the page's own window; the SCO posts JSON
      // back via window.chrome.webview.postMessage.
      final bootstrap = buildScormBootstrapJs(
        initialCmi: widget.initialCmi,
        sendBody: 'window.chrome.webview.postMessage(p);',
      );
      await _controller.addScriptToExecuteOnDocumentCreated(bootstrap);

      _controller.webMessage.listen(
        _onWebMessage,
        onError: (Object e, StackTrace s) =>
            debugPrint('[SCORM] webMessage error (windows): $e'),
      );

      await _controller.loadUrl(widget.contentUrl);

      if (mounted) setState(() => _ready = true);
    } catch (e, s) {
      debugPrint('[SCORM] WindowsScormPlayer init failed: $e\n$s');
      if (mounted) setState(() => _error = '$e');
    }
  }

  void _onWebMessage(dynamic message) {
    // The plugin JSON-decodes the payload, so a Map arrives; ScormSession.ingest
    // expects the raw JSON string, so re-encode a Map back to a string.
    final raw = message is String ? message : jsonEncode(message);
    final progress = _session.ingest(raw);
    if (progress != null && mounted) widget.onProgress(progress);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not start the course player.\n$_error',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (!_ready) {
      return const Center(child: CircularProgressIndicator());
    }
    return Webview(_controller);
  }
}
