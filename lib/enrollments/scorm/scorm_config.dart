import 'package:flutter/foundation.dart';

/// Base origin the SCORM serving proxy is reached at on **native** platforms
/// (Android/iOS/Windows/macOS), where there's no relative same-origin request.
/// This is your Firebase Hosting domain (the `/scorm/**` rewrite → `serveScorm`).
///
/// Update if you use a custom domain. On **web** this is ignored — the app
/// requests `/scorm/…` relative to its own origin (same-origin is required so
/// the SCO can reach `window.parent.API`).
const String kScormHostingOrigin = 'https://academyplatform-12c05.web.app';

/// Builds the URL for a package's launch file. Web → same-origin relative path;
/// native → absolute against [kScormHostingOrigin].
String scormContentUrl(String materialId, String entryPoint) {
  final path = '/scorm/$materialId/$entryPoint';
  return kIsWeb ? path : '$kScormHostingOrigin$path';
}
