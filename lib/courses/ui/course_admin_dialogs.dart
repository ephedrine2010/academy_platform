// Flutter also exports a `MaterialType`; hide it (our library's is unused here,
// but the import would otherwise clash).
import 'package:flutter/material.dart' hide MaterialType;

import '../../materials/models/training_material.dart';
import '../../materials/ui/material_picker_dialog.dart';
import '../../theme/app_theme.dart';
import '../models/course.dart';

/// Result of the "add / edit session" dialog.
typedef NewSession = ({
  String name,
  String description,
  List<int> trainees,
  SessionType deliveryType,
  String? materialId,
});

/// Result of the "add / edit appointment" dialog. [capacity] is the max number
/// of trainees who may self-enroll (null = unlimited).
typedef NewAppointment = ({DateTime date, String location, int? capacity});

/// Collects a session's name, description, delivery type, attached material and
/// assigned trainee ids — used for both add and edit (pass the existing values
/// to pre-fill). [materials] is the shared library the material picker chooses
/// from. Returns null if cancelled or the name is empty.
Future<NewSession?> showSessionDialog(
  BuildContext context, {
  String initialName = '',
  String initialDescription = '',
  List<int> initialTrainees = const [],
  SessionType initialType = SessionType.physical,
  String? initialMaterialId,
  List<TrainingMaterial> materials = const [],
  bool isEdit = false,
}) {
  return showDialog<NewSession>(
    context: context,
    builder: (context) => _SessionDialog(
      initialName: initialName,
      initialDescription: initialDescription,
      initialTrainees: initialTrainees,
      initialType: initialType,
      initialMaterialId: initialMaterialId,
      materials: materials,
      isEdit: isEdit,
    ),
  );
}

class _SessionDialog extends StatefulWidget {
  const _SessionDialog({
    this.initialName = '',
    this.initialDescription = '',
    this.initialTrainees = const [],
    this.initialType = SessionType.physical,
    this.initialMaterialId,
    this.materials = const [],
    this.isEdit = false,
  });

  final String initialName;
  final String initialDescription;
  final List<int> initialTrainees;
  final SessionType initialType;
  final String? initialMaterialId;
  final List<TrainingMaterial> materials;
  final bool isEdit;

  @override
  State<_SessionDialog> createState() => _SessionDialogState();
}

class _SessionDialogState extends State<_SessionDialog> {
  late final _nameCtrl = TextEditingController(text: widget.initialName);
  late final _descCtrl = TextEditingController(text: widget.initialDescription);
  late final _traineesCtrl =
      TextEditingController(text: widget.initialTrainees.join(', '));

  late SessionType _type = widget.initialType;
  // Only keep the preselected material if it still exists in the library.
  late String? _materialId =
      widget.materials.any((m) => m.id == widget.initialMaterialId)
          ? widget.initialMaterialId
          : null;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _traineesCtrl.dispose();
    super.dispose();
  }

  List<int> _parseIds(String raw) => raw
      .split(',')
      .map((e) => int.tryParse(e.trim()))
      .whereType<int>()
      .toList();

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a session name.');
      return;
    }
    if (_type.requiresMaterial && _materialId == null) {
      setState(() => _error = 'Self-paced sessions need a material.');
      return;
    }
    Navigator.pop(context, (
      name: name,
      description: _descCtrl.text.trim(),
      trainees: _parseIds(_traineesCtrl.text),
      deliveryType: _type,
      materialId: _type.usesMaterial ? _materialId : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isEdit ? 'Edit session' : 'Add session'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Session name',
                  hintText: 'e.g. Health360',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'e.g. about medicine',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<SessionType>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Session type'),
                onChanged: (v) =>
                    setState(() => _type = v ?? SessionType.physical),
                items: [
                  for (final t in SessionType.values)
                    DropdownMenuItem(value: t, child: Text(t.label)),
                ],
              ),
              if (_type.usesMaterial) ...[
                const SizedBox(height: 12),
                _MaterialPicker(
                  materials: widget.materials,
                  value: _materialId,
                  required: _type.requiresMaterial,
                  onChanged: (v) => setState(() => _materialId = v),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _traineesCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Assigned trainee ids',
                  hintText: 'comma separated, e.g. 1111, 222',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}

/// A tappable field that opens the searchable material picker (search + year +
/// type). Scales past a plain dropdown for large libraries. Shows the selected
/// material's title, with a clear button when the material is optional.
class _MaterialPicker extends StatelessWidget {
  const _MaterialPicker({
    required this.materials,
    required this.value,
    required this.required,
    required this.onChanged,
  });

  final List<TrainingMaterial> materials;
  final String? value;
  final bool required;
  final ValueChanged<String?> onChanged;

  Future<void> _choose(BuildContext context) async {
    final picked = await showMaterialPickerDialog(
      context,
      materials: materials,
      selectedId: value,
    );
    if (picked != null) onChanged(picked.id);
  }

  @override
  Widget build(BuildContext context) {
    if (materials.isEmpty) {
      return const InputDecorator(
        decoration: InputDecoration(labelText: 'Material'),
        child: Text(
          'No materials uploaded. Add one in the Materials tab first.',
          style: TextStyle(fontSize: 12),
        ),
      );
    }

    TrainingMaterial? selected;
    if (value != null) {
      for (final m in materials) {
        if (m.id == value) {
          selected = m;
          break;
        }
      }
    }
    final label = selected?.title ??
        (value != null ? 'Material $value (missing)' : 'Choose material…');

    return InkWell(
      onTap: () => _choose(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: required ? 'Material (required)' : 'Material (optional)',
          suffixIcon: (!required && value != null)
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  tooltip: 'Clear',
                  onPressed: () => onChanged(null),
                )
              : const Icon(Icons.search, size: 18),
        ),
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected == null ? AppColors.muted : AppColors.ink,
          ),
        ),
      ),
    );
  }
}

/// Collects an appointment's date and location — used for both add and edit
/// (pass the existing values to pre-fill). Returns null if cancelled.
Future<NewAppointment?> showAppointmentDialog(
  BuildContext context, {
  DateTime? initialDate,
  String initialLocation = '',
  int? initialCapacity,
  bool isEdit = false,
}) {
  return showDialog<NewAppointment>(
    context: context,
    builder: (context) => _AppointmentDialog(
      initialDate: initialDate,
      initialLocation: initialLocation,
      initialCapacity: initialCapacity,
      isEdit: isEdit,
    ),
  );
}

class _AppointmentDialog extends StatefulWidget {
  const _AppointmentDialog({
    this.initialDate,
    this.initialLocation = '',
    this.initialCapacity,
    this.isEdit = false,
  });

  final DateTime? initialDate;
  final String initialLocation;
  final int? initialCapacity;
  final bool isEdit;

  @override
  State<_AppointmentDialog> createState() => _AppointmentDialogState();
}

class _AppointmentDialogState extends State<_AppointmentDialog> {
  late final _locationCtrl = TextEditingController(text: widget.initialLocation);
  late final _capacityCtrl = TextEditingController(
    text: widget.initialCapacity?.toString() ?? '',
  );
  late DateTime? _date = widget.initialDate;

  @override
  void dispose() {
    _locationCtrl.dispose();
    _capacityCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date ?? now),
    );
    if (!mounted) return;
    setState(() {
      _date = DateTime(
        day.year,
        day.month,
        day.day,
        time?.hour ?? 0,
        time?.minute ?? 0,
      );
    });
  }

  String _fmt(DateTime d) =>
      '${d.year}-${_two(d.month)}-${_two(d.day)} '
      '${_two(d.hour)}:${_two(d.minute)}';
  static String _two(int n) => n.toString().padLeft(2, '0');

  /// Blank / zero / negative / non-numeric → null (unlimited).
  static int? _parseCapacity(String raw) {
    final n = int.tryParse(raw.trim());
    return (n == null || n <= 0) ? null : n;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isEdit ? 'Edit appointment' : 'Add appointment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.event, size: 18),
            label: Text(_date == null ? 'Pick date & time' : _fmt(_date!)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _locationCtrl,
            decoration: const InputDecoration(
              labelText: 'Location',
              hintText: 'e.g. voco hotel',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _capacityCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Max capacity',
              hintText: 'leave blank for unlimited',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _date == null
              ? null
              : () => Navigator.pop(context, (
                  date: _date!,
                  location: _locationCtrl.text.trim(),
                  capacity: _parseCapacity(_capacityCtrl.text),
                )),
          child: Text(widget.isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
