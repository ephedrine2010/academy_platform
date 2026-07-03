// Picks the platform-specific SCORM player host: an <iframe> on web, an
// InAppWebView on native (Android/iOS/Windows/macOS), or an unsupported
// placeholder elsewhere. All three expose the same `ScormPlayer` widget.
export 'scorm_player_stub.dart'
    if (dart.library.js_interop) 'scorm_player_web.dart'
    if (dart.library.io) 'scorm_player_io.dart';
