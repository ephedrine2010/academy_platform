import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/courses_cubit.dart';
import '../models/course.dart';
import 'scorm_player.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Academy — Courses'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Builder(
            builder: (context) => IconButton(
              tooltip: 'Rescan courses folder',
              icon: const Icon(Icons.refresh),
              onPressed: () => context.read<CoursesCubit>().loadCourses(),
            ),
          ),
        ],
      ),
      body: const Row(
        children: [
          SizedBox(width: 300, child: _CourseSidebar()),
          VerticalDivider(width: 1),
          Expanded(child: _ContentArea()),
        ],
      ),
    );
  }
}

class _CourseSidebar extends StatelessWidget {
  const _CourseSidebar();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CoursesCubit, CoursesState>(
      builder: (context, state) {
        return Material(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'AVAILABLE COURSES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Expanded(child: _CourseList(state: state)),
            ],
          ),
        );
      },
    );
  }
}

class _CourseList extends StatelessWidget {
  const _CourseList({required this.state});

  final CoursesState state;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.loadError != null) {
      return _SidebarMessage(
        icon: Icons.error_outline,
        text: 'Could not scan courses:\n${state.loadError}',
      );
    }
    if (state.courses.isEmpty) {
      return const _SidebarMessage(
        icon: Icons.folder_open,
        text: 'No courses found.\nDrop a SCORM folder into assets/courses/ '
            'and press refresh.',
      );
    }
    return ListView(
      children: [
        for (final course in state.courses)
          _CourseTile(
            course: course,
            selected: course.id == state.selectedCourseId,
            onTap: () => context.read<CoursesCubit>().selectCourse(course.id),
          ),
      ],
    );
  }
}

class _SidebarMessage extends StatelessWidget {
  const _SidebarMessage({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.blueGrey, size: 36),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseTile extends StatelessWidget {
  const _CourseTile({
    required this.course,
    required this.selected,
    required this.onTap,
  });

  final Course course;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      selected: selected,
      leading: const Icon(Icons.menu_book),
      title: Text(course.title),
      subtitle: Text(course.status.label),
      trailing: course.isFinished
          ? const Icon(Icons.check_circle, color: Colors.green)
          : null,
      onTap: onTap,
    );
  }
}

class _ContentArea extends StatelessWidget {
  const _ContentArea();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CoursesCubit, CoursesState>(
      builder: (context, state) {
        final course = state.selectedCourse;
        if (course == null) {
          return const Center(
            child: Text('Select a course from the list to start.'),
          );
        }

        return Column(
          children: [
            _StatusBar(course: course, message: state.lastStatusMessage),
            Expanded(
              child: ScormPlayer(
                // Key by course so switching courses rebuilds the player.
                key: ValueKey(course.id),
                dir: course.dir,
                launchFile: course.launchFile,
                onSetValue: (key, value) =>
                    context.read<CoursesCubit>().onScormSetValue(key, value),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.course, required this.message});

  final Course course;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final finished = course.isFinished;
    return Container(
      width: double.infinity,
      color: finished
          ? Colors.green.shade50
          : Theme.of(context).colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(
            finished ? Icons.check_circle : Icons.play_circle_outline,
            color: finished ? Colors.green : Colors.blueGrey,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              course.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          // The completion label requested for the POC.
          Text(
            message ?? course.status.label,
            style: TextStyle(
              color: finished ? Colors.green.shade800 : Colors.black54,
              fontWeight: finished ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
