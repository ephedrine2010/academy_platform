import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:material_table_view/material_table_view.dart';

import '../../theme/app_theme.dart';
import '../cubit/regions_cubit.dart';
import '../cubit/instructors_cubit.dart';
import '../models/instructor.dart';
import 'admin_widgets.dart';
import 'instructor_edit_dialog.dart';

/// Admin screen: list / add / edit / delete instructors and assign them to
/// regions (many-to-many, freely re-assignable).
class InstructorsPage extends StatelessWidget {
  const InstructorsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InstructorsCubit, InstructorsState>(
      builder: (context, state) {
        final cubit = context.read<InstructorsCubit>();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminToolbar(
              icon: TablerIcons.users,
              title: 'Instructors',
              subtitle: '${state.instructors.length} instructor(s)',
              actionLabel: 'Add instructor',
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
    InstructorsCubit cubit, {
    Instructor? instructor,
  }) async {
    final regions = context.read<RegionsCubit>().state.regions;
    final result = await InstructorEditDialog.show(
      context,
      regions: regions,
      existing: instructor,
    );
    if (result == null) return;
    if (instructor == null) {
      await cubit.add(result);
    } else {
      await cubit.update(result);
    }
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state});

  final InstructorsState state;

  @override
  Widget build(BuildContext context) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return AdminMessage(
        icon: TablerIcons.alert_triangle,
        text: 'Could not load instructors:\n${state.error}',
      );
    }
    if (state.instructors.isEmpty) {
      return const AdminMessage(
        icon: TablerIcons.user_off,
        text: 'No instructors yet.\nUse “Add instructor” to create one.',
      );
    }

    final cubit = context.read<InstructorsCubit>();
    final instructors = state.instructors;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: TableView.builder(
        columns: const [
          TableColumn(width: 100, flex: 1),
          TableColumn(width: 150, flex: 2),
          TableColumn(width: 180, flex: 2),
          TableColumn(width: 110, flex: 1),
          TableColumn(width: 150, flex: 2),
          TableColumn(width: 112),
        ],
        rowCount: instructors.length,
        rowHeight: 60,
        headerHeight: 44,
        headerBuilder: (context, contentBuilder) => contentBuilder(
          context,
          (context, column) => _HeaderCell(
            label: const [
              'Instructor ID',
              'Name',
              'Email',
              'Phone',
              'Regions',
              'Actions'
            ][column],
          ),
        ),
        rowBuilder: (context, row, contentBuilder) {
          final t = instructors[row];
          return contentBuilder(
            context,
            (context, column) => _cell(context, cubit, t, column),
          );
        },
      ),
    );
  }

  Widget _cell(
    BuildContext context,
    InstructorsCubit cubit,
    Instructor t,
    int column,
  ) {
    switch (column) {
      case 0:
        return _TextCell(t.instructorId, weight: FontWeight.w600);
      case 1:
        return _TextCell(t.name, weight: FontWeight.w600);
      case 2:
        return _TextCell(t.email);
      case 3:
        return _TextCell(t.phone);
      case 4:
        if (t.regionNames.isEmpty) {
          return _TextCell('—', color: Theme.of(context).colorScheme.outline);
        }
        return Align(
          alignment: Alignment.centerLeft,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final name in t.regionNames)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _RegionChip(name: name),
                  ),
              ],
            ),
          ),
        );
      default:
        return Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(TablerIcons.pencil, size: 18),
              onPressed: () =>
                  InstructorsPage._edit(context, cubit, instructor: t),
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(TablerIcons.trash, size: 18),
              color: AppColors.red,
              onPressed: () => _confirmDelete(context, cubit, t),
            ),
          ],
        );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    InstructorsCubit cubit,
    Instructor t,
  ) async {
    final ok = await confirmDelete(
      context,
      message: 'Delete instructor “${t.name}”?',
    );
    if (ok) await cubit.delete(t.id);
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
