import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../admin/ui/admin_widgets.dart';
import '../../theme/app_theme.dart';
import '../cubit/courses_cubit.dart';
import 'course_expansion_tile.dart';

/// Admin Courses tab (shown to admin01/admin02): a live list of the courses in
/// the Firestore `courses` collection, with admin actions to add courses,
/// sessions and appointments.
class AdminCoursesPage extends StatelessWidget {
  const AdminCoursesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CoursesCubit, CoursesState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(count: state.courses.length, loading: state.loading),
            Expanded(child: _Body(state: state)),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.count, required this.loading});

  final int count;
  final bool loading;

  Future<void> _addCourse(BuildContext context) async {
    final name = await promptForText(
      context,
      title: 'Add course',
      label: 'Course name',
      hint: 'e.g. care360',
    );
    if (name == null || name.isEmpty || !context.mounted) return;
    await context.read<CoursesCubit>().addCourse(name);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          const Icon(TablerIcons.book, color: AppColors.teal),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Courses',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.teal,
                ),
              ),
              Text(
                loading ? 'Loading…' : '$count course(s)',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: () => _addCourse(context),
            icon: const Icon(TablerIcons.plus, size: 18),
            label: const Text('Add course'),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state});

  final CoursesState state;

  @override
  Widget build(BuildContext context) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return AdminMessage(
        icon: TablerIcons.alert_triangle,
        text: 'Could not load courses:\n${state.error}',
      );
    }
    if (state.courses.isEmpty) {
      return const AdminMessage(
        icon: TablerIcons.book_off,
        text: 'No courses yet.\nAdd documents to the Firestore "courses" '
            'collection (each with a title field).',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: state.courses.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) =>
          CourseExpansionTile(course: state.courses[i], isAdmin: true),
    );
  }
}
