import 'package:xml/xml.dart';

/// Title + launch document pulled out of a SCORM `imsmanifest.xml`.
class ManifestInfo {
  ManifestInfo(this.title, this.launchFile);
  final String title;
  final String launchFile;
}

/// Pulls the course title and launch document out of an `imsmanifest.xml`.
///
/// Resolution: default `<organization>` → its first `<item identifierref>` →
/// the `<resource href>` it points at. Falls back to the first SCO resource,
/// then the first resource with any `href`. Returns null when nothing in the
/// manifest is launchable.
///
/// This is shared by every [CourseRepository] implementation (disk, OneDrive,
/// …) so manifest handling stays identical no matter where the bytes came from.
ManifestInfo? parseManifest(String content, {required String fallbackTitle}) {
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

  return ManifestInfo(title, launch);
}

String _normalizeLaunch(String href) {
  var h = href.replaceAll('\\', '/').trim();
  while (h.startsWith('./')) {
    h = h.substring(2);
  }
  if (h.startsWith('/')) h = h.substring(1);
  return h;
}
