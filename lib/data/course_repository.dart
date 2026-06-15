import 'dart:io';

import 'package:xml/xml.dart';

import '../models/course.dart';
import '../utils/log.dart';

/// Discovers SCORM courses by scanning a folder on disk. Each immediate
/// subfolder that contains an `imsmanifest.xml` becomes one [Course].
///
/// Drop a new SCORM package folder under `assets/courses/` and it shows up on
/// the next scan/restart — no rebuild and no `pubspec.yaml` edits, because we
/// read from the filesystem rather than the (build-time) Flutter asset bundle.
class CourseRepository {
  CourseRepository({String? coursesDir}) : _overrideDir = coursesDir;

  /// Optional explicit courses directory; when null the repo searches the
  /// candidate locations in [_candidateDirs].
  final String? _overrideDir;

  Future<List<Course>> loadCourses() async {
    final dir = _resolveCoursesDir();
    if (dir == null) {
      logServer(
        'No courses directory found. Looked in: ${_candidateDirs().join(", ")}',
      );
      return [];
    }
    logServer('Scanning courses in "${dir.path}"');

    final subDirs = dir.listSync().whereType<Directory>().toList()
      ..sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));

    final courses = <Course>[];
    for (final sub in subDirs) {
      final id = _basename(sub.path);
      final manifest = File('${sub.path}/imsmanifest.xml');
      if (!manifest.existsSync()) {
        logServer('Skipping "$id" (no imsmanifest.xml)');
        continue;
      }
      try {
        final info = _parseManifest(
          manifest.readAsStringSync(),
          fallbackTitle: id,
        );
        if (info == null) {
          logServer('Skipping "$id" (no launchable resource in manifest)');
          continue;
        }
        courses.add(
          Course(
            id: id,
            title: info.title,
            dir: sub.path,
            launchFile: info.launchFile,
          ),
        );
        logServer('Found course "${info.title}" -> ${info.launchFile}');
      } catch (e, s) {
        logError('parse manifest for "$id"', e, s);
      }
    }
    return courses;
  }

  Directory? _resolveCoursesDir() {
    for (final path in _candidateDirs()) {
      final d = Directory(path);
      if (d.existsSync()) return d;
    }
    return null;
  }

  /// Where to look for the courses folder, in priority order:
  /// 1. the project root (true during `flutter run`),
  /// 2. next to the built executable (`assets/courses` or `courses`),
  /// 3. the bundled flutter_assets path (if it ever gets bundled).
  List<String> _candidateDirs() {
    if (_overrideDir != null) return [_overrideDir];
    final cwd = Directory.current.path;
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    return [
      '$cwd/assets/courses',
      '$exeDir/assets/courses',
      '$exeDir/courses',
      '$exeDir/data/flutter_assets/assets/courses',
    ];
  }

  String _basename(String path) {
    final parts =
        path.split(RegExp(r'[\\/]+')).where((s) => s.isNotEmpty).toList();
    return parts.isEmpty ? path : parts.last;
  }
}

class _ManifestInfo {
  _ManifestInfo(this.title, this.launchFile);
  final String title;
  final String launchFile;
}

/// Pulls the course title and launch document out of an `imsmanifest.xml`.
///
/// Resolution: default `<organization>` → its first `<item identifierref>` →
/// the `<resource href>` it points at. Falls back to the first SCO resource,
/// then the first resource with any `href`.
_ManifestInfo? _parseManifest(String content, {required String fallbackTitle}) {
  var xmlStr = content;
  // Some authoring tools emit a UTF-8 BOM, which trips up XmlDocument.parse.
  if (xmlStr.isNotEmpty && xmlStr.codeUnitAt(0) == 0xFEFF) {
    xmlStr = xmlStr.substring(1);
  }
  final doc = XmlDocument.parse(xmlStr);

  // Resource identifier -> href, remembering useful fallbacks along the way.
  final resourceHref = <String, String>{};
  String? firstScoHref;
  String? firstAnyHref;
  for (final r in doc.findAllElements('resource')) {
    final href = r.getAttribute('href');
    if (href == null || href.isEmpty) continue;
    firstAnyHref ??= href;
    final id = r.getAttribute('identifier');
    if (id != null) resourceHref[id] = href;
    final type = (r.getAttribute('adlcp:scormtype') ??
            r.getAttribute('scormtype') ??
            '')
        .toLowerCase();
    if (firstScoHref == null && type == 'sco') firstScoHref = href;
  }

  // Default organization (or the first one present).
  String? defaultOrg;
  for (final orgs in doc.findAllElements('organizations')) {
    defaultOrg = orgs.getAttribute('default');
    break;
  }
  final allOrgs = doc.findAllElements('organization').toList();
  XmlElement? org;
  if (defaultOrg != null) {
    for (final o in allOrgs) {
      if (o.getAttribute('identifier') == defaultOrg) {
        org = o;
        break;
      }
    }
  }
  if (org == null && allOrgs.isNotEmpty) org = allOrgs.first;

  // Launch file: first item's identifierref resolved against the resources.
  String? launch;
  if (org != null) {
    for (final item in org.findAllElements('item')) {
      final ref = item.getAttribute('identifierref');
      if (ref != null && resourceHref.containsKey(ref)) {
        launch = resourceHref[ref];
        break;
      }
    }
  }
  launch ??= firstScoHref ?? firstAnyHref;
  if (launch == null) return null;
  launch = _normalizeLaunch(launch);

  // Title: organization <title>, else any LOM <langstring>, else folder name.
  String title = '';
  if (org != null) {
    for (final t in org.findElements('title')) {
      title = t.innerText.trim();
      break;
    }
  }
  if (title.isEmpty) {
    for (final ls in doc.findAllElements('langstring')) {
      final v = ls.innerText.trim();
      if (v.isNotEmpty) {
        title = v;
        break;
      }
    }
  }
  if (title.isEmpty) title = fallbackTitle;

  return _ManifestInfo(title, launch);
}

String _normalizeLaunch(String href) {
  var h = href.replaceAll('\\', '/').trim();
  while (h.startsWith('./')) {
    h = h.substring(2);
  }
  if (h.startsWith('/')) h = h.substring(1);
  return h;
}
