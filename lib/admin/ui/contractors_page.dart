import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:material_table_view/material_table_view.dart';

import '../../theme/app_theme.dart';
import '../cubit/contractors_cubit.dart';
import '../cubit/regions_cubit.dart';
import '../models/contractor.dart';
import 'admin_widgets.dart';
import 'contractor_edit_dialog.dart';

/// Admin screen: list / add / edit / delete contractors and assign them to
/// regions (many-to-many, freely re-assignable).
class ContractorsPage extends StatelessWidget {
  const ContractorsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ContractorsCubit, ContractorsState>(
      builder: (context, state) {
        final cubit = context.read<ContractorsCubit>();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminToolbar(
              icon: TablerIcons.users,
              title: 'Contractors',
              subtitle: '${state.contractors.length} contractor(s)',
              actionLabel: 'Add contractor',
              onAction: () => _edit(context, cubit),
            ),
            Expanded(child: _Body(state: state)),
          ],
        );
      },
    );
  }

  static Future<void> _edit(
    BuildContext context,
    ContractorsCubit cubit, {
    Contractor? contractor,
  }) async {
    final regions = context.read<RegionsCubit>().state.regions;
    final result = await ContractorEditDialog.show(
      context,
      regions: regions,
      existing: contractor,
    );
    if (result == null) return;
    if (contractor == null) {
      await cubit.add(result);
    } else {
      await cubit.update(result);
    }
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state});

  final ContractorsState state;

  @override
  Widget build(BuildContext context) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return AdminMessage(
        icon: TablerIcons.alert_triangle,
        text: 'Could not load contractors:\n${state.error}',
      );
    }
    if (state.contractors.isEmpty) {
      return const AdminMessage(
        icon: TablerIcons.user_off,
        text: 'No contractors yet.\nUse “Add contractor” to create one.',
      );
    }

    final cubit = context.read<ContractorsCubit>();
    final contractors = state.contractors;
    // Region-id -> name lookup for rendering the assignment chips.
    final regionNames = {
      for (final r in context.watch<RegionsCubit>().state.regions) r.id: r.name,
    };

    return Padding(
      padding: const EdgeInsets.all(16),
      child: TableView.builder(
        columns: const [
          TableColumn(width: 200, flex: 2),
          TableColumn(width: 220, flex: 2),
          TableColumn(width: 140, flex: 1),
          TableColumn(width: 220, flex: 2),
          TableColumn(width: 110),
        ],
        rowCount: contractors.length,
        rowHeight: 60,
        headerHeight: 44,
        headerBuilder: (context, contentBuilder) => contentBuilder(
          context,
          (context, column) => _HeaderCell(
            label: const ['Name', 'Email', 'Phone', 'Regions', 'Actions'][column],
          ),
        ),
        rowBuilder: (context, row, contentBuilder) {
          final c = contractors[row];
          return contentBuilder(
            context,
            (context, column) =>
                _cell(context, cubit, c, regionNames, column),
          );
        },
      ),
    );
  }

  Widget _cell(
    BuildContext context,
    ContractorsCubit cubit,
    Contractor c,
    Map<String, String> regionNames,
    int column,
  ) {
    switch (column) {
      case 0:
        return _TextCell(c.name, weight: FontWeight.w600);
      case 1:
        return _TextCell(c.email);
      case 2:
        return _TextCell(c.phone);
      case 3:
        if (c.regionIds.isEmpty) {
          return _TextCell('—', color: Theme.of(context).colorScheme.outline);
        }
        return Align(
          alignment: Alignment.centerLeft,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final id in c.regionIds)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _RegionChip(name: regionNames[id] ?? '?'),
                  ),
              ],
            ),
          ),
        );
      default:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(TablerIcons.pencil, size: 18),
              onPressed: () =>
                  ContractorsPage._edit(context, cubit, contractor: c),
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(TablerIcons.trash, size: 18),
              color: AppColors.red,
              onPressed: () => _confirmDelete(context, cubit, c),
            ),
          ],
        );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ContractorsCubit cubit,
    Contractor c,
  ) async {
    final ok = await confirmDelete(
      context,
      message: 'Delete contractor “${c.name}”?',
    );
    if (ok) await cubit.delete(c.id);
  }
}

class _TextCell extends StatelessWidget {
  const _TextCell(this.text, {this.weight, this.color});

  final String text;
  final FontWeight? weight;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: weight, color: color),
      ),
    );
  }
}

class _RegionChip extends StatelessWidget {
  const _RegionChip({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.accentFor(name);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        name,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 0.8,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}
