import 'dart:io';

import '../models/course.dart';
import '../../../academy/utils/log.dart';
import 'manifest_parser.dart';
import 'scorm_file_source.dart';

/// Discovers SCORM courses and knows how to read each one's files.
///
/// Implementations: [DiskCourseRepository] (local `assets/courses/`) and
/// `OneDriveCourseRepository` (a shared OneDrive folder). The cubit picks one
/// based on whether OneDrive is configured.
abstract class CourseRepository {
  /// Finds the available courses (each must expose an `imsmanifest.xml`).
  Future<List<Course>> loadCourses();

  /// Builds the file source a [ScormAssetServer] uses to play [course].
  ScormFileSource sourceFor(Course course);
}

/// Discovers SCORM courses by scanning a folder on disk. Each immediate
/// subfolder that contains an `imsmanifest.xml` becomes one [Course].
///
/// Drop a new SCORM package folder under `assets/courses/` and it shows up on
/// the next scan/restart — no rebuild and no `pubspec.yaml` edits, because we
/// read from the filesystem rather than the (build-time) Flutter asset bundle.
class DiskCourseRepository implements CourseRepository {
  DiskCourseRepository({String? coursesDir}) : _overrideDir = coursesDir;

  /// Optional explicit courses directory; when null the repo searches the
  /// candidate locations in [_candidateDirs].
  final String? _overrideDir;

  @override
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
        final info = parseManifest(
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
            basePath: sub.path,
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

  @override
  ScormFileSource sourceFor(Course course) => DiskScormSource(course.basePath);

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
