import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../theme/app_theme.dart';
import '../models/training_material.dart';
import 'material_filtering.dart';

/// Opens a searchable, filterable picker over the material library and returns
/// the chosen material, or null if cancelled. Scales past a dropdown: search by
/// title, filter by year / type, scroll the results.
Future<TrainingMaterial?> showMaterialPickerDialog(
  BuildContext context, {
  required List<TrainingMaterial> materials,
  String? selectedId,
}) {
  return showDialog<TrainingMaterial>(
    context: context,
    builder: (_) => _MaterialPickerDialog(
      materials: materials,
      selectedId: selectedId,
    ),
  );
}

class _MaterialPickerDialog extends StatefulWidget {
  const _MaterialPickerDialog({required this.materials, this.selectedId});

  final List<TrainingMaterial> materials;
  final String? selectedId;

  @override
  State<_MaterialPickerDialog> createState() => _MaterialPickerDialogState();
}

class _MaterialPickerDialogState extends State<_MaterialPickerDialog> {
  MaterialQuery _query = const MaterialQuery();

  @override
  Widget build(BuildContext context) {
    final years = distinctYears(widget.materials);
    final results = filterMaterials(widget.materials, _query);

    return AlertDialog(
      title: const Text('Choose material'),
      contentPadding: const EdgeInsets.only(top: 12),
      content: SizedBox(
        width: 480,
        height: 460,
        child: Column(
          children: [
            MaterialFilterBar(
              query: _query,
              years: years,
              onChanged: (q) => setState(() => _query = q),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '${results.length} of ${widget.materials.length}',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ),
            ),
            const Divider(height: 12),
            Expanded(
              child: results.isEmpty
                  ? const Center(
                      child: Text(
                        'No materials match.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    )
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, i) {
                        final m = results[i];
                        final selected = m.id == widget.selectedId;
                        final meta = [
                          m.type.label,
                          if (m.year != null) '${m.year}',
                          if (m.sizeLabel.isNotEmpty) m.sizeLabel,
                        ].join(' · ');
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            TablerIcons.file_zip,
                            size: 18,
                            color: selected ? AppColors.teal : AppColors.muted,
                          ),
                          title: Text(m.title),
                          subtitle: Text(meta),
                          trailing: selected
                              ? const Icon(TablerIcons.check,
                                  size: 18, color: AppColors.teal)
                              : null,
                          selected: selected,
                          onTap: () => Navigator.pop(context, m),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
