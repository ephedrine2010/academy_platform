import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'scorm_api_js.dart';
import 'scorm_session.dart';

/// Web SCORM host: an `<iframe>` (via [HtmlElementView]) loading the same-origin
/// `/scorm/…` URL, with `window.API` defined on the **parent** (this) window so
/// the SCO inside the iframe finds `window.parent.API`. Same-origin is why
/// serving goes through the Hosting rewrite (see scorm_config.dart / firebase.json).
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
  State<ScormPlayer> createState() => _ScormPlayerWebState();
}

class _ScormPlayerWebState extends State<ScormPlayer> {
  final ScormSession _session = ScormSession();
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'scorm-iframe-${DateTime.now().microsecondsSinceEpoch}';

    // Expose the Dart receiver, then define window.API on the parent window.
    globalContext.setProperty(
      '__scormDartSend'.toJS,
      ((JSString payload) => _onRaw(payload.toDart)).toJS,
    );
    final bootstrap = buildScormBootstrapJs(
      initialCmi: widget.initialCmi,
      sendBody: 'window.__scormDartSend(p);',
    );
    final script = web.HTMLScriptElement()..text = bootstrap;
    web.document.head?.appendChild(script);

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..src = widget.contentUrl
        ..width = '100%'
        ..height = '100%'
        ..style.border = 'none';
      return iframe;
    });
  }

  void _onRaw(String payload) {
    final progress = _session.ingest(payload);
    if (progress != null && mounted) widget.onProgress(progress);
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
