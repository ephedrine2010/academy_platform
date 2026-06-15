import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;

import '../utils/log.dart';

/// Serves a SCORM package (bundled under `assets/<assetRoot>/`) over a local
/// loopback HTTP server.
///
/// SCORM content uses relative URLs and an inner `<iframe>`, which do not work
/// when loaded via `file://`. Serving over `http://127.0.0.1` makes the package
/// behave exactly as it would inside a real LMS.
class ScormAssetServer {
  ScormAssetServer({required this.assetRoot, required this.launchFile});

  /// Folder inside the Flutter asset bundle, e.g. `assets/golf`.
  final String assetRoot;

  /// Launch document relative to [assetRoot], e.g. `shared/launchpage.html`.
  final String launchFile;

  HttpServer? _server;

  /// Starts the server and returns the absolute URL of the launch file.
  Future<String> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen(_handleRequest);
    logServer('Listening on 127.0.0.1:${server.port}, root="$assetRoot"');
    return 'http://127.0.0.1:${server.port}/$launchFile';
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    // Strip leading slash and ignore any query string (e.g. assessment params).
    var path = request.uri.path;
    if (path.startsWith('/')) path = path.substring(1);
    if (path.isEmpty) path = launchFile;

    final assetKey = '$assetRoot/$path';
    try {
      final data = await rootBundle.load(assetKey);
      request.response.headers.contentType = _contentTypeFor(path);
      request.response.add(data.buffer.asUint8List());
      logServer('200 $path (${data.lengthInBytes} bytes)');
    } catch (e) {
      request.response.statusCode = HttpStatus.notFound;
      logServer('404 $path  (asset not found: $assetKey)');
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
        return ContentType('application', 'javascript', charset: 'utf-8');
      case 'css':
        return ContentType('text', 'css', charset: 'utf-8');
      case 'xml':
      case 'xsd':
        return ContentType('application', 'xml', charset: 'utf-8');
      case 'json':
        return ContentType('application', 'json', charset: 'utf-8');
      case 'jpg':
      case 'jpeg':
        return ContentType('image', 'jpeg');
      case 'png':
        return ContentType('image', 'png');
      case 'gif':
        return ContentType('image', 'gif');
      case 'svg':
        return ContentType('image', 'svg+xml');
      default:
        return ContentType.binary;
    }
  }
}
