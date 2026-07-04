import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'scorm_api_js.dart';
import 'scorm_session.dart';

/// Native SCORM host. Picks the WebView backend at runtime:
///
/// - **Android / iOS / macOS** → [InAppWebView] (`flutter_inappwebview`).
/// - **Windows** → **deferred** (shows [_WindowsUnsupported]). A `webview_windows`
///   host is written and ready in `scorm_player_windows.dart`, but it can't
///   initialize while `flutter_inappwebview_windows` is in the build: both
///   plugins fight over the one-per-thread WebView2 DispatcherQueueController and
///   the inappwebview one wins at startup. Re-enable by excluding
///   `flutter_inappwebview_windows` from the Windows build and routing here to
///   `WindowsScormPlayer`. Full write-up:
///   `documentation/training_materials/windows_scorm_playback.md`.
///
/// Both native backends inject the same shared `window.API`
/// ([buildScormBootstrapJs]) at document-start and interpret CMI through the same
/// [ScormSession]; only the WebView shell differs. No same-origin constraint on
/// native — the API lives in the loaded page itself, not a parent window.
class ScormPlayer extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return const _WindowsUnsupported();
    }
    return _InAppWebViewScormPlayer(
      contentUrl: contentUrl,
      initialCmi: initialCmi,
      onProgress: onProgress,
    );
  }
}

/// Placeholder shown on Windows desktop while native SCORM playback is deferred
/// (see the class doc above). Avoids initializing the conflicted WebView2 plugin.
class _WindowsUnsupported extends StatelessWidget {
  const _WindowsUnsupported();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.devices_other, size: 48, color: Colors.blueGrey),
            const SizedBox(height: 16),
            Text(
              'Course playback isn’t available on Windows desktop yet.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Please open this course in the web app or on your phone.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// The `flutter_inappwebview` host used on Android / iOS / macOS.
class _InAppWebViewScormPlayer extends StatefulWidget {
  const _InAppWebViewScormPlayer({
    required this.contentUrl,
    required this.initialCmi,
    required this.onProgress,
  });

  final String contentUrl;
  final Map<String, String> initialCmi;
  final void Function(ScormProgress progress) onProgress;

  @override
  State<_InAppWebViewScormPlayer> createState() => _ScormPlayerIoState();
}

class _ScormPlayerIoState extends State<_InAppWebViewScormPlayer> {
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
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        // Android-only: some SCORM packages mix http asset refs. Guarded to
        // Android because flutter_inappwebview_windows can abort on settings it
        // doesn't implement.
        mixedContentMode: defaultTargetPlatform == TargetPlatform.android
            ? MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW
            : null,
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
      onLoadStart: (_, url) => debugPrint('[SCORM] loadStart: $url'),
      onLoadStop: (_, url) => debugPrint('[SCORM] loadStop: $url'),
      onReceivedError: (_, req, err) =>
          debugPrint('[SCORM] loadError ${err.type} for ${req.url}: '
              '${err.description}'),
      onReceivedHttpError: (_, req, resp) => debugPrint(
          '[SCORM] httpError ${resp.statusCode} for ${req.url}'),
      onConsoleMessage: (_, msg) =>
          debugPrint('[SCORM][console] ${msg.messageLevel}: ${msg.message}'),
    );
  }
}
