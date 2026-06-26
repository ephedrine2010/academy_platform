import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../theme/app_theme.dart';
import '../models/contractor.dart';
import '../models/region.dart';

/// Add/edit form for a contractor, including the many-to-many region
/// assignment (rendered as selectable chips). Returns the edited [Contractor]
/// (id is empty for a new one), or null if cancelled.
class ContractorEditDialog extends StatefulWidget {
  const ContractorEditDialog({
    super.key,
    required this.regions,
    this.existing,
  });

  final List<Region> regions;
  final Contractor? existing;

  static Future<Contractor?> show(
    BuildContext context, {
    required List<Region> regions,
    Contractor? existing,
  }) {
    return showDialog<Contractor>(
      context: context,
      builder: (_) =>
          ContractorEditDialog(regions: regions, existing: existing),
    );
  }

  @override
  State<ContractorEditDialog> createState() => _ContractorEditDialogState();
}

class _ContractorEditDialogState extends State<ContractorEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final Set<String> _regionIds;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _email = TextEditingController(text: e?.email ?? '');
    _phone = TextEditingController(text: e?.phone ?? '');
    _address = TextEditingController(text: e?.address ?? '');
    _regionIds = {...?e?.regionIds};
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final result = Contractor(
      id: widget.existing?.id ?? '',
      name: _name.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim(),
      address: _address.text.trim(),
      regionIds: _regionIds.toList(),
    );
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'Add contractor' : 'Edit contractor',
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _field(_name, 'Name', TablerIcons.user, required: true),
                const SizedBox(height: 12),
                _field(
                  _email,
                  'Email',
                  TablerIcons.mail,
                  keyboard: TextInputType.emailAddress,
                  validator: (v) => (v != null && v.isNotEmpty && !v.contains('@'))
                      ? 'Invalid email'
                      : null,
                ),
                const SizedBox(height: 12),
                _field(_phone, 'Phone', TablerIcons.phone,
                    keyboard: TextInputType.phone),
                const SizedBox(height: 12),
                _field(_address, 'Address', TablerIcons.map_pin, maxLines: 2),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'ASSIGNED REGIONS',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (widget.regions.isEmpty)
                  Text(
                    'No regions defined yet — add regions first.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final r in widget.regions)
                        FilterChip(
                          label: Text(r.name),
                          selected: _regionIds.contains(r.id),
                          selectedColor:
                              AppColors.accentFor(r.name).withValues(alpha: 0.2),
                          checkmarkColor: AppColors.accentFor(r.name),
                          onSelected: (on) => setState(() {
                            if (on) {
                              _regionIds.add(r.id);
                            } else {
                              _regionIds.remove(r.id);
                            }
                          }),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator: validator ??
          (required
              ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
              : null),
    );
  }
}
