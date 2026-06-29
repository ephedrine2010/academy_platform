import 'package:flutter/material.dart';

/// Result of the "add session" dialog.
typedef NewSession = ({String name, String description});

/// Result of the "add appointment" dialog.
typedef NewAppointment = ({DateTime date, String location, List<int> instructorIds});

/// Collects a session name + description. Returns null if cancelled or the name
/// is empty.
Future<NewSession?> showAddSessionDialog(BuildContext context) async {
  final nameCtrl = TextEditingController();
  final descCtrl = TextEditingController();

  final result = await showDialog<NewSession>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Add session'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Session name',
              hintText: 'e.g. Health360',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descCtrl,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'e.g. about medicine',
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
          onPressed: () {
            final name = nameCtrl.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(context, (name: name, description: descCtrl.text.trim()));
          },
          child: const Text('Add'),
        ),
      ],
    ),
  );

  nameCtrl.dispose();
  descCtrl.dispose();
  return result;
}

/// Collects an appointment's date, location and assigned instructor ids — used for
/// both add and edit (pass the existing values to pre-fill). Returns null if
/// cancelled.
Future<NewAppointment?> showAppointmentDialog(
  BuildContext context, {
  DateTime? initialDate,
  String initialLocation = '',
  List<int> initialInstructorIds = const [],
  bool isEdit = false,
}) {
  return showDialog<NewAppointment>(
    context: context,
    builder: (context) => _AppointmentDialog(
      initialDate: initialDate,
      initialLocation: initialLocation,
      initialInstructorIds: initialInstructorIds,
      isEdit: isEdit,
    ),
  );
}

class _AppointmentDialog extends StatefulWidget {
  const _AppointmentDialog({
    this.initialDate,
    this.initialLocation = '',
    this.initialInstructorIds = const [],
    this.isEdit = false,
  });

  final DateTime? initialDate;
  final String initialLocation;
  final List<int> initialInstructorIds;
  final bool isEdit;

  @override
  State<_AppointmentDialog> createState() => _AppointmentDialogState();
}

class _AppointmentDialogState extends State<_AppointmentDialog> {
  late final _locationCtrl = TextEditingController(text: widget.initialLocation);
  late final _instructorsCtrl =
      TextEditingController(text: widget.initialInstructorIds.join(', '));
  late DateTime? _date = widget.initialDate;

  @override
  void dispose() {
    _locationCtrl.dispose();
    _instructorsCtrl.dispose();
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

  List<int> _parseIds(String raw) => raw
      .split(',')
      .map((e) => int.tryParse(e.trim()))
      .whereType<int>()
      .toList();

  String _fmt(DateTime d) =>
      '${d.year}-${_two(d.month)}-${_two(d.day)} '
      '${_two(d.hour)}:${_two(d.minute)}';
  static String _two(int n) => n.toString().padLeft(2, '0');

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
            controller: _instructorsCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Assigned instructor ids',
              hintText: 'comma separated, e.g. 222, 444, 555',
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
                  instructorIds: _parseIds(_instructorsCtrl.text),
                )),
          child: Text(widget.isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
