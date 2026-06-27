import 'dart:io';

import '../../../academy/utils/log.dart';
import 'scorm_file_source.dart';

/// Serves a SCORM package over a local loopback HTTP server, reading each file
/// from a [ScormFileSource] (local disk, or a shared OneDrive folder).
///
/// SCORM content uses relative URLs and an inner `<iframe>`, which do not work
/// when loaded via `file://`. Serving over `http://127.0.0.1` makes the package
/// behave exactly as it would inside a real LMS — and, because the WebView only
/// ever talks to this loopback origin, the injected `window.API` adapter shares
/// the package's origin no matter where the bytes actually come from.
class ScormAssetServer {
  ScormAssetServer({required this.source, required this.launchFile});

  /// Where to read course files from, one relative path at a time.
  final ScormFileSource source;

  /// Launch document relative to the course root, e.g. `shared/launchpage.html`.
  final String launchFile;

  HttpServer? _server;

  /// Starts the server and returns the absolute URL of the launch file.
  Future<String> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen(_handleRequest);
    logServer('Listening on 127.0.0.1:${server.port}, source=${source.runtimeType}');
    return 'http://127.0.0.1:${server.port}/$launchFile';
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    source.dispose();
  }

  Future<void> _handleRequest(HttpRequest request) async {
    // Decode percent-encoding, strip the leading slash, ignore query strings.
    var path = Uri.decodeComponent(request.uri.path);
    if (path.startsWith('/')) path = path.substring(1);
    if (path.isEmpty) path = launchFile;

    try {
      final bytes = await source.read(path);
      if (bytes == null) {
        request.response.statusCode = HttpStatus.notFound;
        logServer('404 $path');
        await request.response.close();
        return;
      }
      request.response.headers.contentType = _contentTypeFor(path);
      request.response.add(bytes);
      logServer('200 $path (${bytes.length} bytes)');
    } catch (e, s) {
      request.response.statusCode = HttpStatus.internalServerError;
      logError('server $path', e, s);
    }
    await request.response.close();
  }

  ContentType _contentTypeFor(String path) {
    final ext = path.contains('.') ? path.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'html':
      case 'htm':
        return ContentType.html;
      case 'js':
      case 'mjs':
        return ContentType('application', 'javascript', charset: 'utf-8');
      case 'css':
        return ContentType('text', 'css', charset: 'utf-8');
      case 'xml':
      case 'xsd':
        return ContentType('application', 'xml', charset: 'utf-8');
      case 'json':
        return ContentType('application', 'json', charset: 'utf-8');
      case 'txt':
      case 'vtt':
        return ContentType('text', 'plain', charset: 'utf-8');
      case 'jpg':
      case 'jpeg':
        return ContentType('image', 'jpeg');
      case 'png':
        return ContentType('image', 'png');
      case 'gif':
        return ContentType('image', 'gif');
      case 'svg':
        return ContentType('image', 'svg+xml');
      case 'ico':
        return ContentType('image', 'x-icon');
      case 'webp':
        return ContentType('image', 'webp');
      case 'woff':
        return ContentType('font', 'woff');
      case 'woff2':
        return ContentType('font', 'woff2');
      case 'ttf':
        return ContentType('font', 'ttf');
      case 'otf':
        return ContentType('font', 'otf');
      case 'eot':
        return ContentType('application', 'vnd.ms-fontobject');
      case 'mp3':
        return ContentType('audio', 'mpeg');
      case 'm4a':
        return ContentType('audio', 'mp4');
      case 'mp4':
        return ContentType('video', 'mp4');
      case 'webm':
        return ContentType('video', 'webm');
      default:
        return ContentType.binary;
    }
  }
}
