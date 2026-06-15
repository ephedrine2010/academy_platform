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
              Expanded(
                child: ListView(
                  children: [
                    for (final course in state.courses)
                      _CourseTile(
                        course: course,
                        selected: course.id == state.selectedCourseId,
                        onTap: () =>
                            context.read<CoursesCubit>().selectCourse(course.id),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
                assetRoot: course.assetRoot,
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
