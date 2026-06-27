import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../../user/cubit/home_cubit.dart';
import '../models/learning.dart';
import '../responsive.dart';
import '../widgets/brand.dart';
import '../widgets/cards.dart';
import '../widgets/teal_header.dart';
import 'course_detail_screen.dart';

/// Trainee landing screen — greeting header, "Continue learning" featured card
/// and the "My courses" list. State comes from [HomeCubit]; this widget is pure
/// presentation. Adapts across phone / tablet / desktop widths.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _openCourse(BuildContext context, Course course) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CourseDetailScreen(course: course)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HomeCubit>().state;

    return LayoutBuilder(
      builder: (context, constraints) {
        final form = formFactorFor(constraints.maxWidth);
        final maxW = form.contentMaxWidth;
        const hPad = 18.0;
        final contentWidth =
            (constraints.maxWidth.clamp(0, maxW)) - hPad * 2;

        return Column(
          children: [
            TealHeader(
              maxContentWidth: maxW,
              child: Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_greeting()}, ${state.name}',
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      state.subtitle,
                      style: GoogleFonts.manrope(
                        fontSize: 11.5,
                        color: AppColors.tealCaption,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ContentColumn(
                maxWidth: maxW,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(hPad, 18, hPad, 24),
                  children: [
                    if (state.featured != null)
                      FeaturedCard(
                        course: state.featured!,
                        onTap: () => _openCourse(context, state.featured!),
                      ),
                    const SizedBox(height: 22),
                    const SectionHeader('My courses'),
                    const SizedBox(height: 12),
                    _MyCourses(
                      courses: state.myCourses,
                      columns: form.courseColumns,
                      contentWidth: contentWidth,
                      onTap: (c) => _openCourse(context, c),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// "My courses" list — a single column on phones, a 2-up wrapped grid on
/// tablet / desktop.
class _MyCourses extends StatelessWidget {
  const _MyCourses({
    required this.courses,
    required this.columns,
    required this.contentWidth,
    required this.onTap,
  });

  final List<Course> courses;
  final int columns;
  final double contentWidth;
  final ValueChanged<Course> onTap;

  @override
  Widget build(BuildContext context) {
    const gap = 11.0;
    if (columns <= 1) {
      return Column(
        children: [
          for (final c in courses) ...[
            CourseListItem(course: c, onTap: () => onTap(c)),
            if (c != courses.last) const SizedBox(height: gap),
          ],
        ],
      );
    }

    final itemWidth = itemWidthFor(contentWidth, columns, gap);
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        for (final c in courses)
          SizedBox(
            width: itemWidth,
            child: CourseListItem(course: c, onTap: () => onTap(c)),
          ),
      ],
    );
  }
}
