import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../materials/data/material_repository.dart';
import '../../materials/models/training_material.dart';
import '../../theme/app_theme.dart';
import '../models/enrollment.dart';
import '../scorm/scorm_config.dart';
import '../scorm/scorm_player.dart';
import '../scorm/scorm_session.dart';

/// The trainee **Material Viewer** (training-materials brainstorm §8): a thin
/// teal top bar (close · title · live progress) over the platform SCORM player
/// (`<iframe>` on web, an in-app webview on native). Opening marks the
/// enrollment started; SCORM progress flows back through [onProgress].
///
/// When the material isn't `ready` yet (still unzipping, or failed), the body
/// explains why instead of loading a player.
class MaterialViewerPage extends StatefulWidget {
  const MaterialViewerPage({
    super.key,
    required this.enrollment,
    this.onOpen,
    this.onProgress,
    this.studentName,
  });

  final Enrollment enrollment;

  /// Called once when the viewer opens (marks the enrollment started).
  final Future<void> Function()? onOpen;

  /// Persists a progress snapshot from the player.
  final void Function(ScormProgress progress)? onProgress;

  /// Shown to the SCO as `cmi.core.student_name`.
  final String? studentName;

  @override
  State<MaterialViewerPage> createState() => _MaterialViewerPageState();
}

class _MaterialViewerPageState extends State<MaterialViewerPage> {
  late Future<TrainingMaterial?> _materialFuture;
  late int _progress = widget.enrollment.progress;

  @override
  void initState() {
    super.initState();
    widget.onOpen?.call();
    final materialId = widget.enrollment.materialId;
    _materialFuture = materialId == null
        ? Future.value(null)
        : MaterialRepository().getById(materialId);
  }

  void _onProgress(ScormProgress p) {
    if (mounted) setState(() => _progress = p.progress);
    widget.onProgress?.call(p);
  }

  /// Seeds the CMI map: identity + resume bookmark/suspend data + entry mode.
  Map<String, String> _initialCmi() {
    final e = widget.enrollment;
    final resuming =
        (e.suspendData?.isNotEmpty ?? false) || (e.lessonLocation?.isNotEmpty ?? false);
    return {
      'cmi.core.student_id': '${e.userId}',
      'cmi.core.student_name': widget.studentName ?? 'Trainee',
      'cmi.core.lesson_status': _priorStatus(e),
      'cmi.core.lesson_location': e.lessonLocation ?? '',
      'cmi.suspend_data': e.suspendData ?? '',
      'cmi.core.entry': resuming ? 'resume' : 'ab-initio',
      'cmi.core.credit': 'credit',
      'cmi.core.lesson_mode': 'normal',
    };
  }

  static String _priorStatus(Enrollment e) {
    switch (e.outcome) {
      case EnrollmentOutcome.passed:
        return 'passed';
      case EnrollmentOutcome.failed:
        return 'failed';
      case EnrollmentOutcome.attended:
      case EnrollmentOutcome.absent:
      case EnrollmentOutcome.none:
        break;
    }
    switch (e.lifecycleState) {
      case LifecycleState.done:
        return 'completed';
      case LifecycleState.inProgress:
        return 'incomplete';
      case LifecycleState.notStarted:
        return 'not attempted';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(title: widget.enrollment.title, progress: _progress),
            Expanded(
              child: FutureBuilder<TrainingMaterial?>(
                future: _materialFuture,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final material = snap.data;
                  if (material == null || !material.isReady) {
                    return _NotReadyBody(
                      title: widget.enrollment.title,
                      material: material,
                    );
                  }
                  return ScormPlayer(
                    contentUrl:
                        scormContentUrl(material.id, material.entryPoint!),
                    initialCmi: _initialCmi(),
                    onProgress: _onProgress,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.progress});

  final String title;
  final int progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.tealDark,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(TablerIcons.x, color: Colors.white),
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$progress%',
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (progress / 100).clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: Colors.white24,
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.tealLight),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// Shown when the package can't play yet: still processing, failed, or no
/// material attached.
class _NotReadyBody extends StatelessWidget {
  const _NotReadyBody({required this.title, required this.material});

  final String title;
  final TrainingMaterial? material;

  @override
  Widget build(BuildContext context) {
    final (icon, heading, detail) = _content();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: AppColors.muted),
              const SizedBox(height: 14),
              Text(
                heading,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  (IconData, String, String) _content() {
    final status = material?.status;
    if (material == null) {
      return (
        TablerIcons.file_off,
        'Material unavailable',
        'This session has no playable material attached.',
      );
    }
    switch (status) {
      case 'processing':
      case 'uploaded':
        return (
          TablerIcons.loader,
          'Preparing this course…',
          'The package is still being processed. Check back in a moment.',
        );
      case 'failed':
        return (
          TablerIcons.alert_triangle,
          'This course could not be prepared',
          'The uploaded package failed to process. Please tell your admin.',
        );
      default:
        return (
          TablerIcons.tools,
          'Not ready yet',
          'This course is not ready to play.',
        );
    }
  }
}
