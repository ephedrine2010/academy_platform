/// Configuration for serving SCORM courses from a shared OneDrive folder.
///
/// Each course must be stored **extracted** (a folder of loose files —
/// `imsmanifest.xml`, `index.html`, assets …), NOT as a `.zip`. The app then
/// streams individual files on demand through Microsoft Graph, so a large
/// course only transfers the pages the learner actually opens.
///
/// ──────────────────────────────────────────────────────────────────────────
/// SETUP:
///
/// 1. In OneDrive, put each course folder inside one parent folder, e.g.
///        Academy/
///          golf/        (imsmanifest.xml, shared/launchpage.html, …)
///          safety/      (imsmanifest.xml, index.html, …)
/// 2. Share that parent folder → "Anyone with the link" (or, for the company
///    rollout, share it with the employees' group) → Copy link.
/// 3. Paste the copied link into [shareUrl] below.
/// 4. Make sure sign-in can read Drive files: add the `Files.Read.All`
///    delegated permission to the Entra app registration, and confirm it is in
///    `AuthConfig.scopes`. (Personal Microsoft accounts grant this on consent.)
///
/// When [shareUrl] is still the placeholder the app falls back to scanning the
/// local `assets/courses/` folder, exactly as before.
/// ──────────────────────────────────────────────────────────────────────────
class OneDriveConfig {
  OneDriveConfig._();

  /// The "Copy link" share URL of the parent folder that contains the course
  /// subfolders. Works with both consumer (`https://1drv.ms/...`,
  /// `https://onedrive.live.com/...`) and business/SharePoint share links.
  static const String shareUrl = 'YOUR_ONEDRIVE_SHARE_URL';

  /// True once a real share URL has been supplied. Drives whether the app reads
  /// courses from OneDrive or from the local `assets/courses/` folder.
  static bool get isConfigured =>
      shareUrl.isNotEmpty && shareUrl != 'YOUR_ONEDRIVE_SHARE_URL';
}
