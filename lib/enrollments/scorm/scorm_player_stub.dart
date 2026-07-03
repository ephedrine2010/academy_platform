import 'package:flutter/material.dart';

import 'scorm_session.dart';

/// Fallback for platforms with no webview host. In practice every target the app
/// runs on resolves to the web or native implementation; this keeps the
/// conditional export total.
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
    return const Center(
      child: Text('The course player is not supported on this platform.'),
    );
  }
}
