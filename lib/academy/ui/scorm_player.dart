import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';

import '../data/scorm_asset_server.dart';
import '../scorm/scorm_adapter.dart';
import '../utils/log.dart';

/// Hosts a single SCORM package inside a WebView2 surface and reports SCORM
/// `LMSSetValue` events back to the caller.
class ScormPlayer extends StatefulWidget {
  const ScormPlayer({
    super.key,
    required this.dir,
    required this.launchFile,
    required this.onSetValue,
  });

  /// Absolute filesystem path to the course folder.
  final String dir;
  final String launchFile;

  /// Called for every `cmi.*` value the package writes. The cubit decides what
  /// to do with `cmi.core.lesson_status`.
  final void Function(String key, String value) onSetValue;

  @override
  State<ScormPlayer> createState() => _ScormPlayerState();
}

class _ScormPlayerState extends State<ScormPlayer> {
  final _controller = WebviewController();
  ScormAssetServer? _runningServer;

  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      logScorm('Initializing player for "${widget.dir}/${widget.launchFile}"');

      // 1. Serve the package over loopback HTTP.
      final server = ScormAssetServer(
        rootDir: widget.dir,
        launchFile: widget.launchFile,
      );
      _runningServer = server;
      final launchUrl = await server.start();
      logScorm('Asset server started, launch URL: $launchUrl');

      // 2. Bring up the WebView2 controller.
      await _controller.initialize();
      logScorm('WebView2 controller initialized');
      await _controller.setBackgroundColor(Colors.white);
      await _controller
          .setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);

      // Surface navigation lifecycle + load failures in the console.
      _controller.loadingState.listen(
        (state) => logScorm('Loading state: $state'),
      );
      _controller.onLoadError.listen(
        (err) => logError('WebView load', err),
      );

      // 3. Inject the SCORM API *before* any document loads, so the package's
      //    discovery algorithm finds window.API immediately.
      await _controller.addScriptToExecuteOnDocumentCreated(scorm12AdapterJs);
      logScorm('SCORM 1.2 adapter injected (addScriptToExecuteOnDocumentCreated)');

      // 4. Listen for messages the injected adapter posts back.
      //    The plugin JSON-decodes the payload, so we receive a Map directly.
      _controller.webMessage.listen(
        _onWebMessage,
        onError: (Object e, StackTrace s) =>
            logError('webMessage stream', e, s),
      );

      // 5. Load the course.
      await _controller.loadUrl(launchUrl);
      logScorm('loadUrl called');

      if (mounted) setState(() => _ready = true);
    } catch (e, s) {
      logError('ScormPlayer._init', e, s);
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _onWebMessage(dynamic message) {
    try {
      final decoded = message is String ? jsonDecode(message) : message;
      if (decoded is! Map) {
        logScorm('Ignored non-map message: $message');
        return;
      }

      final type = decoded['type'];
      final payload = decoded['payload'];
      logScorm('JS -> Flutter: type=$type payload=$payload');

      if (type != 'SetValue' || payload is! Map) return;

      final key = payload['key']?.toString();
      final value = payload['value']?.toString();
      if (key != null && value != null) {
        widget.onSetValue(key, value);
      }
    } catch (e, s) {
      logError('ScormPlayer._onWebMessage', e, s);
    }
  }

  @override
  void dispose() {
    logScorm('Disposing player; stopping asset server');
    _controller.dispose();
    _runningServer?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _PlayerMessage(
        icon: Icons.error_outline,
        title: 'Could not start the SCORM player',
        detail: _error!,
      );
    }
    if (!_ready) {
      return const _PlayerMessage(
        icon: Icons.downloading,
        title: 'Loading course…',
      );
    }
    return Webview(_controller);
  }
}

class _PlayerMessage extends StatelessWidget {
  const _PlayerMessage({required this.icon, required this.title, this.detail});

  final IconData icon;
  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.blueGrey),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (detail != null) ...[
              const SizedBox(height: 8),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
