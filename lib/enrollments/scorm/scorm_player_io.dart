import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'scorm_api_js.dart';
import 'scorm_session.dart';

/// Native SCORM host (Android / iOS / Windows / macOS): an [InAppWebView]
/// loading the serving URL, with `window.API` injected at **document start** (a
/// [UserScript]) so it exists before the SCO runs. The SCO calls back via
/// `flutter_inappwebview.callHandler('scorm', …)`. No same-origin constraint —
/// the API lives in the loaded page itself, not a parent window.
class ScormPlayer extends StatefulWidget {
  const ScormPlayer({
    super.key,
    required this.contentUrl,
    required this.initialCmi,
    required this.onProgress,
  });

  final String contentUrl;
  final Map<String, String> initialCmi;
  final void Function(ScormProgress progress) onProgress;

  @override
  State<ScormPlayer> createState() => _ScormPlayerIoState();
}

class _ScormPlayerIoState extends State<ScormPlayer> {
  final ScormSession _session = ScormSession();
  late final UnmodifiableListView<UserScript> _userScripts;

  @override
  void initState() {
    super.initState();
    final bootstrap = buildScormBootstrapJs(
      initialCmi: widget.initialCmi,
      sendBody: "window.flutter_inappwebview.callHandler('scorm', p);",
    );
    _userScripts = UnmodifiableListView([
      UserScript(
        source: bootstrap,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        forMainFrameOnly: true,
      ),
    ]);
  }

  void _onRaw(String payload) {
    final progress = _session.ingest(payload);
    if (progress != null && mounted) widget.onProgress(progress);
  }

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(widget.contentUrl)),
      initialUserScripts: _userScripts,
      initialSettings: InAppWebViewSettings(
        transparentBackground: true,
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
      ),
      onWebViewCreated: (controller) {
        controller.addJavaScriptHandler(
          handlerName: 'scorm',
          callback: (args) {
            if (args.isNotEmpty && args.first is String) {
              _onRaw(args.first as String);
            }
            return null;
          },
        );
      },
    );
  }
}
