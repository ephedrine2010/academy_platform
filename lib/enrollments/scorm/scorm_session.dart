import 'dart:convert';

import '../models/enrollment.dart';

/// A snapshot of progress derived from the SCORM CMI data model — the shape the
/// player hands back to be persisted via `EnrollmentRepository.updateProgress`.
class ScormProgress {
  const ScormProgress({
    required this.lifecycleState,
    required this.outcome,
    required this.progress,
    this.score,
    this.lessonLocation,
    this.suspendData,
  });

  final LifecycleState lifecycleState;
  final EnrollmentOutcome outcome;
  final int progress;
  final int? score;
  final String? lessonLocation;
  final String? suspendData;
}

/// Platform-agnostic SCORM 1.2 (+ light 2004) interpreter. Each player host feeds
/// it the raw JSON payloads posted by the injected `window.API`
/// (see `scorm_api_js.dart`); it maintains the CMI map, maps it to a
/// [ScormProgress], and decides when a write is worthwhile — on the SCO's own
/// commit/finish, or when a meaningful field changed (§9 write strategy).
class ScormSession {
  final Map<String, String> _cmi = {};
  ScormProgress? _lastPersisted;

  /// Ingests one raw payload. Returns a [ScormProgress] when it should be
  /// persisted, or null when nothing worth writing changed.
  ScormProgress? ingest(String rawPayload) {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(rawPayload) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }

    final cmi = msg['cmi'];
    if (cmi is Map) {
      cmi.forEach((k, v) => _cmi['$k'] = v == null ? '' : '$v');
    }

    final type = msg['type'] as String?;
    final progress = _compute();
    final isSaveSignal = type == 'commit' || type == 'finish';

    if (isSaveSignal || _changed(progress)) {
      _lastPersisted = progress;
      return progress;
    }
    return null;
  }

  String? _get(List<String> keys) {
    for (final k in keys) {
      final v = _cmi[k];
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  ScormProgress _compute() {
    final status = (_get(['cmi.core.lesson_status', 'cmi.completion_status',
            'cmi.success_status']) ??
        '')
        .toLowerCase();
    final location =
        _get(['cmi.core.lesson_location', 'cmi.location']);
    final suspend = _get(['cmi.suspend_data']);
    final score = int.tryParse(
        (_get(['cmi.core.score.raw', 'cmi.score.raw']) ?? '').split('.').first);

    LifecycleState state;
    var outcome = EnrollmentOutcome.none;
    switch (status) {
      case 'passed':
        state = LifecycleState.done;
        outcome = EnrollmentOutcome.passed;
        break;
      case 'failed':
        state = LifecycleState.done;
        outcome = EnrollmentOutcome.failed;
        break;
      case 'completed':
        state = LifecycleState.done;
        break;
      default:
        // not attempted / incomplete / browsed / unknown → they've opened it.
        state = LifecycleState.inProgress;
    }

    // SCORM 1.2 has no native % complete; 2004 may expose progress_measure.
    int progress;
    final measure = double.tryParse(_cmi['cmi.progress_measure'] ?? '');
    if (state == LifecycleState.done) {
      progress = 100;
    } else if (measure != null) {
      progress = (measure * 100).round().clamp(0, 100);
    } else {
      progress = (score ?? 0).clamp(0, 100);
    }

    return ScormProgress(
      lifecycleState: state,
      outcome: outcome,
      progress: progress,
      score: score,
      lessonLocation: location,
      suspendData: suspend,
    );
  }

  bool _changed(ScormProgress p) {
    final last = _lastPersisted;
    if (last == null) return true;
    return p.lifecycleState != last.lifecycleState ||
        p.outcome != last.outcome ||
        p.progress != last.progress ||
        p.lessonLocation != last.lessonLocation ||
        p.suspendData != last.suspendData;
  }
}
