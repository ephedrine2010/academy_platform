import 'dart:io';
import 'dart:typed_data';

import 'onedrive_graph_client.dart';

/// Where a [ScormAssetServer] reads a course's files from. The loopback server
/// asks for one relative path at a time (`shared/launchpage.html`,
/// `images/logo.png`, …) as the WebView requests them, so a remote source only
/// transfers the files the learner actually opens.
abstract class ScormFileSource {
  /// Returns the bytes of [relativePath] within the course, or null if missing.
  Future<Uint8List?> read(String relativePath);

  /// Release any held resources (HTTP clients, etc.). Optional.
  void dispose() {}
}

/// Reads course files straight off the local filesystem (the original POC
/// behaviour). [rootDir] is the absolute path to the course folder.
class DiskScormSource implements ScormFileSource {
  DiskScormSource(this.rootDir);

  final String rootDir;

  @override
  Future<Uint8List?> read(String relativePath) async {
    final file = File('$rootDir/$relativePath');
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  @override
  void dispose() {}
}

/// Reads course files on demand from a shared OneDrive folder via Microsoft
/// Graph. [basePath] is the course folder's path within the shared folder
/// (e.g. `golf`); requested paths are resolved relative to it.
///
/// A small in-memory cache keeps re-requested files (the SCORM runtime JS, CSS,
/// the launch page when navigating back, …) instant within a session.
class OneDriveScormSource implements ScormFileSource {
  OneDriveScormSource({
    required this.client,
    required this.shareId,
    required this.basePath,
  });

  final OneDriveGraphClient client;
  final String shareId;
  final String basePath;

  final Map<String, Uint8List?> _cache = {};

  @override
  Future<Uint8List?> read(String relativePath) async {
    final full = basePath.isEmpty ? relativePath : '$basePath/$relativePath';
    if (_cache.containsKey(full)) return _cache[full];
    final bytes = await client.readBytes(shareId, full);
    _cache[full] = bytes;
    return bytes;
  }

  @override
  void dispose() => _cache.clear();
}
