import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// The payload kind of an uploaded training material. This is the *content*
/// type (what's inside the zip), distinct from a session's `deliveryType`
/// (physical / self-paced / webinar), which decides how it's delivered.
enum MaterialType {
  scorm,
  pdf,
  video;

  static MaterialType fromKey(String? key) {
    switch (key) {
      case 'pdf':
        return MaterialType.pdf;
      case 'video':
        return MaterialType.video;
      case 'scorm':
      default:
        return MaterialType.scorm;
    }
  }

  String get key => name;

  String get label {
    switch (this) {
      case MaterialType.scorm:
        return 'SCORM';
      case MaterialType.pdf:
        return 'PDF';
      case MaterialType.video:
        return 'Video';
    }
  }
}

/// One reusable item in the shared **`materials`** library
/// (`materials/{id}`). An admin uploads it once (a `.zip` to Firebase Storage)
/// and any session can point at it by [id]. The document id is the generated
/// 10-digit [materialId] as a string.
///
/// `status` is `uploaded` for now — the server-side unzip + manifest parse and
/// the serving/play pipeline are later steps (see the training-materials
/// brainstorm §12). The admin enters [title] / [type] / exam info manually.
class TrainingMaterial extends Equatable {
  const TrainingMaterial({
    required this.id,
    required this.title,
    required this.type,
    this.materialId,
    this.storagePath = '',
    this.fileName = '',
    this.sizeBytes,
    this.hasExam = false,
    this.passThreshold,
    this.durationMinutes,
    this.year,
    this.status = 'uploaded',
    this.entryPoint,
    this.createdByEmail,
  });

  /// Firestore document id in the `materials` collection (== `material_id`).
  final String id;

  /// Stable 10-digit numeric id (the `material_id` field).
  final int? materialId;

  /// Display title, e.g. `Fire Safety Basics`.
  final String title;

  /// Content payload kind (SCORM / PDF / video).
  final MaterialType type;

  /// Storage object path of the uploaded zip, e.g. `materials/{id}/pkg.zip`.
  final String storagePath;

  /// Original uploaded file name (for display).
  final String fileName;

  /// Size of the uploaded zip in bytes.
  final int? sizeBytes;

  /// Whether the material has a graded exam gate.
  final bool hasExam;

  /// Pass threshold percentage (0..100) when [hasExam]; null otherwise.
  final int? passThreshold;

  /// Rough duration in minutes (admin-entered), for the trainee card later.
  final int? durationMinutes;

  /// The year the material was uploaded (the `year` field). Set automatically
  /// at upload; used as the coarse library filter. Null for legacy docs.
  final int? year;

  /// Processing state, driven by the unzip Cloud Function:
  /// `uploaded` (client wrote it) → `processing` → `ready` | `failed`.
  final String status;

  /// The launch file relative to the package root (e.g. `index.html`), set by
  /// the unzip function once [status] is `ready`. Null until then.
  final String? entryPoint;

  /// Whether the package is unzipped, parsed and playable.
  bool get isReady => status == 'ready' && (entryPoint?.isNotEmpty ?? false);

  /// Human-readable processing state for the admin list.
  String get statusLabel {
    switch (status) {
      case 'ready':
        return 'Ready';
      case 'processing':
        return 'Processing…';
      case 'failed':
        return 'Failed';
      case 'uploaded':
      default:
        return 'Pending';
    }
  }

  /// Email of the admin who uploaded it (audit only).
  final String? createdByEmail;

  factory TrainingMaterial.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final title = (data['title'] ?? '').toString();
    return TrainingMaterial(
      id: doc.id,
      materialId: (data['material_id'] as num?)?.toInt(),
      title: title.trim().isNotEmpty ? title : doc.id,
      type: MaterialType.fromKey(data['type'] as String?),
      storagePath: (data['storage_path'] ?? '').toString(),
      fileName: (data['file_name'] ?? '').toString(),
      sizeBytes: (data['size_bytes'] as num?)?.toInt(),
      hasExam: data['has_exam'] == true,
      passThreshold: (data['pass_threshold'] as num?)?.toInt(),
      durationMinutes: (data['duration_minutes'] as num?)?.toInt(),
      year: (data['year'] as num?)?.toInt(),
      status: (data['status'] ?? 'uploaded').toString(),
      entryPoint: data['entry_point'] as String?,
      createdByEmail: data['created_by_email'] as String?,
    );
  }

  /// Human-readable size, e.g. `41.2 MB`. Empty when unknown.
  String get sizeLabel {
    final bytes = sizeBytes;
    if (bytes == null || bytes <= 0) return '';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final fixed = unit == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
    return '$fixed ${units[unit]}';
  }

  @override
  List<Object?> get props => [
        id,
        materialId,
        title,
        type,
        storagePath,
        fileName,
        sizeBytes,
        hasExam,
        passThreshold,
        durationMinutes,
        year,
        status,
        entryPoint,
        createdByEmail,
      ];
}
