import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../cubit/courses_cubit.dart';
import 'course_expansion_tile.dart';

/// Renders the live [CoursesCubit] list as a column of [CourseTile]s, with
/// loading / error / empty states. Shared by the trainee Home, Courses and
/// Schedule screens.
///
/// Set [shrinkWrap] (with a non-scrolling [physics]) when embedding inside an
/// existing scroll view, e.g. the Home screen's `ListView`.
class CoursesListBody extends StatelessWidget {
  const CoursesListBody({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(18, 4, 18, 24),
    this.shrinkWrap = false,
    this.physics,
    this.emptyText = 'No courses yet.',
  });

  final EdgeInsetsGeometry padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CoursesCubit>().state;

    if (state.loading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.error != null) {
      return _Message(
        icon: TablerIcons.alert_triangle,
        text: 'Could not load courses:\n${state.error}',
      );
    }
    if (state.courses.isEmpty) {
      return _Message(icon: TablerIcons.book_off, text: emptyText);
    }

    return ListView.separated(
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      itemCount: state.courses.length,
      separatorBuilder: (_, __) => const SizedBox(height: 11),
      itemBuilder: (context, i) =>
          CourseExpansionTile(course: state.courses[i], isAdmin: false),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
