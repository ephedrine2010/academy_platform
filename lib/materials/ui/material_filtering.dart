import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../theme/app_theme.dart';
import '../models/training_material.dart';

/// The active filter over the material library: free-text [text] (matched
/// against the title), a [year] bucket, and a content [type]. A null [year] /
/// [type] means "any".
///
/// NOTE: filtering is currently client-side over the loaded list, which is fine
/// up to ~1–2k materials. Beyond that, move the `year` / `type` legs to
/// server-side Firestore `where` queries (they're exact matches) and paginate.
class MaterialQuery {
  const MaterialQuery({this.text = '', this.year, this.type});

  final String text;
  final int? year;
  final MaterialType? type;

  bool get isEmpty => text.trim().isEmpty && year == null && type == null;

  MaterialQuery copyWith({
    String? text,
    int? year,
    MaterialType? type,
    bool clearYear = false,
    bool clearType = false,
  }) {
    return MaterialQuery(
      text: text ?? this.text,
      year: clearYear ? null : (year ?? this.year),
      type: clearType ? null : (type ?? this.type),
    );
  }
}

/// Applies [query] to [materials]. Text match is case-insensitive substring on
/// the title; year and type are exact when set.
List<TrainingMaterial> filterMaterials(
  List<TrainingMaterial> materials,
  MaterialQuery query,
) {
  final needle = query.text.trim().toLowerCase();
  return materials.where((m) {
    if (needle.isNotEmpty && !m.title.toLowerCase().contains(needle)) {
      return false;
    }
    if (query.year != null && m.year != query.year) return false;
    if (query.type != null && m.type != query.type) return false;
    return true;
  }).toList();
}

/// The distinct years present in [materials], newest first.
List<int> distinctYears(List<TrainingMaterial> materials) {
  final years = <int>{for (final m in materials) if (m.year != null) m.year!};
  final sorted = years.toList()..sort((a, b) => b.compareTo(a));
  return sorted;
}

/// Search field + year dropdown + type dropdown. Stateless — the parent owns
/// the [query] and rebuilds on [onChanged].
class MaterialFilterBar extends StatelessWidget {
  const MaterialFilterBar({
    super.key,
    required this.query,
    required this.years,
    required this.onChanged,
  });

  final MaterialQuery query;
  final List<int> years;
  final ValueChanged<MaterialQuery> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 240,
            child: TextField(
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(TablerIcons.search, size: 18),
                hintText: 'Search by title',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => onChanged(query.copyWith(text: v)),
            ),
          ),
          _YearDropdown(
            value: query.year,
            years: years,
            onChanged: (y) => onChanged(
              y == null ? query.copyWith(clearYear: true) : query.copyWith(year: y),
            ),
          ),
          _TypeDropdown(
            value: query.type,
            onChanged: (t) => onChanged(
              t == null ? query.copyWith(clearType: true) : query.copyWith(type: t),
            ),
          ),
          if (!query.isEmpty)
            TextButton.icon(
              onPressed: () => onChanged(const MaterialQuery()),
              icon: const Icon(TablerIcons.x, size: 16),
              label: const Text('Clear'),
              style: TextButton.styleFrom(foregroundColor: AppColors.muted),
            ),
        ],
      ),
    );
  }
}

class _YearDropdown extends StatelessWidget {
  const _YearDropdown({
    required this.value,
    required this.years,
    required this.onChanged,
  });

  final int? value;
  final List<int> years;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: DropdownButtonFormField<int?>(
        value: value,
        isDense: true,
        decoration: const InputDecoration(
          isDense: true,
          labelText: 'Year',
          border: OutlineInputBorder(),
        ),
        onChanged: onChanged,
        items: [
          const DropdownMenuItem(value: null, child: Text('All years')),
          for (final y in years)
            DropdownMenuItem(value: y, child: Text('$y')),
        ],
      ),
    );
  }
}

class _TypeDropdown extends StatelessWidget {
  const _TypeDropdown({required this.value, required this.onChanged});

  final MaterialType? value;
  final ValueChanged<MaterialType?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: DropdownButtonFormField<MaterialType?>(
        value: value,
        isDense: true,
        decoration: const InputDecoration(
          isDense: true,
          labelText: 'Type',
          border: OutlineInputBorder(),
        ),
        onChanged: onChanged,
        items: [
          const DropdownMenuItem(value: null, child: Text('All types')),
          for (final t in MaterialType.values)
            DropdownMenuItem(value: t, child: Text(t.label)),
        ],
      ),
    );
  }
}
