import 'package:file_picker/file_picker.dart';
// Flutter also exports a `MaterialType`; hide it so ours (the content kind) wins.
import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../theme/app_theme.dart';
import '../cubit/materials_cubit.dart';
import '../models/training_material.dart';

/// Opens the upload dialog for a new material. Performs the Storage upload +
/// Firestore write via [cubit], showing live progress, and pops when done.
Future<void> showMaterialUploadDialog(
  BuildContext context, {
  required MaterialsCubit cubit,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _MaterialDialog(cubit: cubit),
  );
}

/// Opens the metadata edit dialog for an existing material (no file change —
/// re-uploading is a later "versioning" step).
Future<void> showMaterialEditDialog(
  BuildContext context, {
  required MaterialsCubit cubit,
  required TrainingMaterial material,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _MaterialDialog(cubit: cubit, existing: material),
  );
}

class _MaterialDialog extends StatefulWidget {
  const _MaterialDialog({required this.cubit, this.existing});

  final MaterialsCubit cubit;
  final TrainingMaterial? existing;

  @override
  State<_MaterialDialog> createState() => _MaterialDialogState();
}

class _MaterialDialogState extends State<_MaterialDialog> {
  late final _titleCtrl =
      TextEditingController(text: widget.existing?.title ?? '');
  late final _thresholdCtrl = TextEditingController(
      text: widget.existing?.passThreshold?.toString() ?? '80');
  late final _durationCtrl = TextEditingController(
      text: widget.existing?.durationMinutes?.toString() ?? '');

  late MaterialType _type = widget.existing?.type ?? MaterialType.scorm;
  late bool _hasExam = widget.existing?.hasExam ?? false;

  PlatformFile? _picked;
  bool _busy = false;
  double _progress = 0;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _thresholdCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      withData: true, // needed on web + to upload bytes
    );
    if (result == null || result.files.isEmpty) return;
    setState(() {
      _picked = result.files.single;
      // Default the title to the file name (sans extension) if still empty.
      if (_titleCtrl.text.trim().isEmpty) {
        final base = _picked!.name.replaceAll(RegExp(r'\.zip$', caseSensitive: false), '');
        _titleCtrl.text = base;
      }
    });
  }

  int? _parseThreshold() {
    if (!_hasExam) return null;
    final v = int.tryParse(_thresholdCtrl.text.trim());
    if (v == null) return null;
    return v.clamp(0, 100);
  }

  int? _parseDuration() {
    final v = int.tryParse(_durationCtrl.text.trim());
    return (v == null || v <= 0) ? null : v;
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Enter a title.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (_isEdit) {
        await widget.cubit.editMaterial(
          widget.existing!.id,
          title: title,
          type: _type,
          hasExam: _hasExam,
          passThreshold: _parseThreshold(),
          durationMinutes: _parseDuration(),
        );
      } else {
        final file = _picked;
        final bytes = file?.bytes;
        if (file == null || bytes == null) {
          setState(() {
            _busy = false;
            _error = 'Pick a .zip file to upload.';
          });
          return;
        }
        await widget.cubit.upload(
          title: title,
          type: _type,
          bytes: bytes,
          fileName: file.name,
          hasExam: _hasExam,
          passThreshold: _parseThreshold(),
          durationMinutes: _parseDuration(),
          onProgress: (f) {
            if (mounted) setState(() => _progress = f);
          },
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit material' : 'Upload material'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_isEdit) ...[
                _FilePickRow(picked: _picked, onPick: _busy ? null : _pickFile),
                const SizedBox(height: 14),
              ],
              TextField(
                controller: _titleCtrl,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g. Fire Safety Basics',
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<MaterialType>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Content type'),
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _type = v ?? MaterialType.scorm),
                items: [
                  for (final t in MaterialType.values)
                    DropdownMenuItem(value: t, child: Text(t.label)),
                ],
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Has a graded exam'),
                value: _hasExam,
                onChanged:
                    _busy ? null : (v) => setState(() => _hasExam = v),
              ),
              if (_hasExam)
                TextField(
                  controller: _thresholdCtrl,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Pass threshold (%)',
                    hintText: 'e.g. 80',
                  ),
                ),
              const SizedBox(height: 14),
              TextField(
                controller: _durationCtrl,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Duration (minutes, optional)',
                  hintText: 'e.g. 25',
                ),
              ),
              if (_busy && !_isEdit) ...[
                const SizedBox(height: 18),
                LinearProgressIndicator(value: _progress == 0 ? null : _progress),
                const SizedBox(height: 6),
                Text(
                  'Uploading… ${(_progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(fontSize: 12, color: AppColors.red),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_isEdit ? 'Save' : 'Upload'),
        ),
      ],
    );
  }
}

class _FilePickRow extends StatelessWidget {
  const _FilePickRow({required this.picked, required this.onPick});

  final PlatformFile? picked;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    final file = picked;
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: onPick,
          icon: const Icon(TablerIcons.file_zip, size: 18),
          label: const Text('Choose .zip'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            file == null ? 'No file selected' : file.name,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: file == null ? AppColors.muted : AppColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}
