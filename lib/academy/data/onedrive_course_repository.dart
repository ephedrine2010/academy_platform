import '../models/course.dart';
import '../utils/log.dart';
import 'course_repository.dart';
import 'manifest_parser.dart';
import 'onedrive_graph_client.dart';
import 'scorm_file_source.dart';

/// Discovers SCORM courses inside a **shared OneDrive folder**. Each immediate
/// subfolder that contains an `imsmanifest.xml` becomes one [Course].
///
/// Files are read one at a time, on demand, through Microsoft Graph — the
/// package is never downloaded whole, so this scales to large courses. The
/// only network cost up front is one manifest fetch per candidate folder.
class OneDriveCourseRepository implements CourseRepository {
  OneDriveCourseRepository({
    required String accessToken,
    required String shareUrl,
    OneDriveGraphClient? client,
  })  : _client = client ?? OneDriveGraphClient(accessToken: accessToken),
        _shareId = OneDriveGraphClient.encodeShareId(shareUrl);

  final OneDriveGraphClient _client;
  final String _shareId;

  @override
  Future<List<Course>> loadCourses() async {
    logServer('Scanning OneDrive shared folder (shareId=$_shareId)');
    final children = await _client.listChildren(_shareId);
    final folders = children.where((c) => c.isFolder).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final courses = <Course>[];
    for (final folder in folders) {
      final id = folder.name;
      try {
        final manifest =
            await _client.readString(_shareId, '$id/imsmanifest.xml');
        if (manifest == null) {
          logServer('Skipping "$id" (no imsmanifest.xml)');
          continue;
        }
        final info = parseManifest(manifest, fallbackTitle: id);
        if (info == null) {
          logServer('Skipping "$id" (no launchable resource in manifest)');
          continue;
        }
        courses.add(
          Course(
            id: id,
            title: info.title,
            basePath: id,
            launchFile: info.launchFile,
          ),
        );
        logServer('Found OneDrive course "${info.title}" -> ${info.launchFile}');
      } catch (e, s) {
        logError('OneDrive manifest for "$id"', e, s);
      }
    }
    return courses;
  }

  @override
  ScormFileSource sourceFor(Course course) => OneDriveScormSource(
        client: _client,
        shareId: _shareId,
        basePath: course.basePath,
      );
}
