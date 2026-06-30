import 'package:flutter/material.dart';

/// Result of the "add / edit session" dialog.
typedef NewSession = ({String name, String description, List<int> trainees});

/// Result of the "add / edit appointment" dialog.
typedef NewAppointment = ({DateTime date, String location});

/// Collects a session's name, description and assigned trainee ids — used for
/// both add and edit (pass the existing values to pre-fill). Returns null if
/// cancelled or the name is empty.
Future<NewSession?> showSessionDialog(
  BuildContext context, {
  String initialName = '',
  String initialDescription = '',
  List<int> initialTrainees = const [],
  bool isEdit = false,
}) {
  return showDialog<NewSession>(
    context: context,
    builder: (context) => _SessionDialog(
      initialName: initialName,
      initialDescription: initialDescription,
      initialTrainees: initialTrainees,
      isEdit: isEdit,
    ),
  );
}

class _SessionDialog extends StatefulWidget {
  const _SessionDialog({
    this.initialName = '',
    this.initialDescription = '',
    this.initialTrainees = const [],
    this.isEdit = false,
  });

  final String initialName;
  final String initialDescription;
  final List<int> initialTrainees;
  final bool isEdit;

  @override
  State<_SessionDialog> createState() => _SessionDialogState();
}

class _SessionDialogState extends State<_SessionDialog> {
  late final _nameCtrl = TextEditingController(text: widget.initialName);
  late final _descCtrl = TextEditingController(text: widget.initialDescription);
  late final _traineesCtrl =
      TextEditingController(text: widget.initialTrainees.join(', '));

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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isEdit ? 'Edit session' : 'Add session'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
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
          TextField(
            controller: _traineesCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Assigned trainee ids',
              hintText: 'comma separated, e.g. 1111, 222',
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
            final name = _nameCtrl.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(context, (
              name: name,
              description: _descCtrl.text.trim(),
              trainees: _parseIds(_traineesCtrl.text),
            ));
          },
          child: Text(widget.isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}

/// Collects an appointment's date and location — used for both add and edit
/// (pass the existing values to pre-fill). Returns null if cancelled.
Future<NewAppointment?> showAppointmentDialog(
  BuildContext context, {
  DateTime? initialDate,
  String initialLocation = '',
  bool isEdit = false,
}) {
  return showDialog<NewAppointment>(
    context: context,
    builder: (context) => _AppointmentDialog(
      initialDate: initialDate,
      initialLocation: initialLocation,
      isEdit: isEdit,
    ),
  );
}

class _AppointmentDialog extends StatefulWidget {
  const _AppointmentDialog({
    this.initialDate,
    this.initialLocation = '',
    this.isEdit = false,
  });

  final DateTime? initialDate;
  final String initialLocation;
  final bool isEdit;

  @override
  State<_AppointmentDialog> createState() => _AppointmentDialogState();
}

class _AppointmentDialogState extends State<_AppointmentDialog> {
  late final _locationCtrl = TextEditingController(text: widget.initialLocation);
  late DateTime? _date = widget.initialDate;

  @override
  void dispose() {
    _locationCtrl.dispose();
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
                )),
          child: Text(widget.isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
