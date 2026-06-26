import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:material_table_view/material_table_view.dart';

import '../../theme/app_theme.dart';
import '../cubit/regions_cubit.dart';
import '../models/region.dart';
import 'admin_widgets.dart';

/// Admin screen: list / add / rename / delete company regions.
class RegionsPage extends StatelessWidget {
  const RegionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RegionsCubit, RegionsState>(
      builder: (context, state) {
        final cubit = context.read<RegionsCubit>();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminToolbar(
              icon: TablerIcons.map_pin,
              title: 'Regions',
              subtitle: '${state.regions.length} region(s)',
              actionLabel: 'Add region',
              onAction: () => _edit(context, cubit),
            ),
            Expanded(
              child: _Body(state: state),
            ),
          ],
        );
      },
    );
  }

  static Future<void> _edit(
    BuildContext context,
    RegionsCubit cubit, {
    Region? region,
  }) async {
    final name = await promptForText(
      context,
      title: region == null ? 'Add region' : 'Rename region',
      label: 'Region name',
      initial: region?.name ?? '',
      hint: 'e.g. East, West, Central',
    );
    if (name == null || name.isEmpty) return;
    if (region == null) {
      await cubit.add(name);
    } else {
      await cubit.rename(region.id, name);
    }
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state});

  final RegionsState state;

  @override
  Widget build(BuildContext context) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return AdminMessage(
        icon: TablerIcons.alert_triangle,
        text: 'Could not load regions:\n${state.error}',
      );
    }
    if (state.regions.isEmpty) {
      return const AdminMessage(
        icon: TablerIcons.map_off,
        text: 'No regions yet.\nUse “Add region” to create the first one.',
      );
    }

    final cubit = context.read<RegionsCubit>();
    final regions = state.regions;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: TableView.builder(
        columns: const [
          TableColumn(width: 56),
          TableColumn(width: 260, flex: 1),
          TableColumn(width: 120),
        ],
        rowCount: regions.length,
        rowHeight: 56,
        headerHeight: 44,
        headerBuilder: (context, contentBuilder) => contentBuilder(
          context,
          (context, column) => _HeaderCell(
            label: const ['', 'Name', 'Actions'][column],
          ),
        ),
        rowBuilder: (context, row, contentBuilder) {
          final region = regions[row];
          return contentBuilder(
            context,
            (context, column) => _cell(context, cubit, region, column),
          );
        },
      ),
    );
  }

  Widget _cell(
    BuildContext context,
    RegionsCubit cubit,
    Region region,
    int column,
  ) {
    switch (column) {
      case 0:
        return Center(
          child: CircleAvatar(
            radius: 8,
            backgroundColor: AppColors.accentFor(region.name),
          ),
        );
      case 1:
        return Align(
          alignment: Alignment.centerLeft,
          child: Text(
            region.name,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        );
      default:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              tooltip: 'Rename',
              icon: const Icon(TablerIcons.pencil, size: 18),
              onPressed: () =>
                  RegionsPage._edit(context, cubit, region: region),
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(TablerIcons.trash, size: 18),
              color: AppColors.red,
              onPressed: () => _confirmDelete(context, cubit, region),
            ),
          ],
        );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    RegionsCubit cubit,
    Region region,
  ) async {
    final ok = await confirmDelete(
      context,
      message: 'Delete region “${region.name}”?\n'
          'It will also be removed from any assigned contractors.',
    );
    if (ok) await cubit.delete(region.id);
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
