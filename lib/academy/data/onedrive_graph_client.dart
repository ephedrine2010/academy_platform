import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// One entry returned when listing a folder's children.
class GraphChild {
  GraphChild({required this.name, required this.isFolder});
  final String name;
  final bool isFolder;
}

/// Raised when a Graph request fails in a way the caller should surface.
class GraphException implements Exception {
  GraphException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Thin Microsoft Graph client for reading a **shared** OneDrive/SharePoint
/// folder by its share link, using the signed-in user's delegated access token.
///
/// Everything is addressed through the `/shares/{shareId}/driveItem` endpoint so
/// the exact same code works whether the link is a personal "anyone with the
/// link" share (testing) or a folder shared to the company group (production).
///
/// Only individual files are fetched, on demand — the package is never
/// downloaded as a whole. See [OneDriveConfig].
class OneDriveGraphClient {
  OneDriveGraphClient({required this.accessToken, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final String accessToken;
  final http.Client _http;

  static const String _base = 'https://graph.microsoft.com/v1.0';

  /// Encodes a sharing URL into a Graph share token (`u!...`).
  ///
  /// Per the Graph "shares" API: base64 the UTF-8 URL, strip `=` padding, then
  /// make it URL-safe (`/`→`_`, `+`→`-`) and prefix with `u!`.
  static String encodeShareId(String shareUrl) {
    final b64 = base64Encode(utf8.encode(shareUrl));
    final urlSafe = b64.replaceAll('=', '').replaceAll('/', '_').replaceAll('+', '-');
    return 'u!$urlSafe';
  }

  /// Lists the children of [relativePath] within the shared folder. An empty
  /// [relativePath] lists the root of the shared folder itself.
  Future<List<GraphChild>> listChildren(
    String shareId, {
    String relativePath = '',
  }) async {
    final uri = Uri.parse('$_base/shares/$shareId/driveItem'
        '${_pathSegment(relativePath)}/children'
        '?\$select=name,folder&\$top=200');
    final res = await _http.get(uri, headers: _authHeaders);
    if (res.statusCode != 200) {
      throw GraphException(
        'List "$relativePath" failed (${res.statusCode}): ${_briefError(res.body)}',
      );
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final values = (json['value'] as List?) ?? const [];
    return [
      for (final v in values.cast<Map<String, dynamic>>())
        GraphChild(
          name: (v['name'] ?? '').toString(),
          isFolder: v.containsKey('folder'),
        ),
    ];
  }

  /// Fetches the raw bytes of [relativePath] within the shared folder, or null
  /// when the file does not exist (404). Other failures throw.
  ///
  /// Graph answers `:/path:/content` with a 302 to a short-lived, pre-signed
  /// download URL; we follow it manually so the bearer token isn't replayed to
  /// the storage CDN.
  Future<Uint8List?> readBytes(String shareId, String relativePath) async {
    final uri = Uri.parse(
      '$_base/shares/$shareId/driveItem${_pathSegment(relativePath)}/content',
    );
    final req = http.Request('GET', uri)..followRedirects = false;
    req.headers.addAll(_authHeaders);
    final streamed = await _http.send(req);

    if (streamed.statusCode == 302 || streamed.statusCode == 301) {
      final location = streamed.headers['location'];
      await streamed.stream.drain<void>();
      if (location == null) {
        throw GraphException('Redirect for "$relativePath" had no Location.');
      }
      final dl = await _http.get(Uri.parse(location));
      if (dl.statusCode != 200) {
        throw GraphException(
          'Download "$relativePath" failed (${dl.statusCode}).',
        );
      }
      return dl.bodyBytes;
    }

    final res = await http.Response.fromStream(streamed);
    if (res.statusCode == 200) return res.bodyBytes;
    if (res.statusCode == 404) return null;
    throw GraphException(
      'Read "$relativePath" failed (${res.statusCode}): ${_briefError(res.body)}',
    );
  }

  /// Convenience: fetch [relativePath] as UTF-8 text, or null when missing.
  Future<String?> readString(String shareId, String relativePath) async {
    final bytes = await readBytes(shareId, relativePath);
    return bytes == null ? null : utf8.decode(bytes, allowMalformed: true);
  }

  void close() => _http.close();

  Map<String, String> get _authHeaders => {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
      };

  /// Builds the Graph path-addressing segment for a file/folder relative to the
  /// shared item: `` for the root, or `:/a/b%20c.html:` for a nested path.
  String _pathSegment(String relativePath) {
    final clean = relativePath.replaceAll('\\', '/').trim();
    final parts =
        clean.split('/').where((s) => s.isNotEmpty).map(Uri.encodeComponent);
    final joined = parts.join('/');
    return joined.isEmpty ? '' : ':/$joined:';
  }

  String _briefError(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final err = json['error'];
      if (err is Map && err['message'] != null) return err['message'].toString();
    } catch (_) {
      // fall through
    }
    return body.length > 200 ? '${body.substring(0, 200)}…' : body;
  }
}
