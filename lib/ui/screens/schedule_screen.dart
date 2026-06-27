import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../models/learning.dart';
import '../responsive.dart';
import '../widgets/cards.dart';
import '../widgets/teal_header.dart';
import 'course_detail_screen.dart';

/// Upcoming sessions, webinars and due assessments for the trainee.
class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = formFactorFor(constraints.maxWidth).contentMaxWidth;
        return Column(
          children: [
            TealHeader(
              maxContentWidth: maxW,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Text(
                  'Your schedule',
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ContentColumn(
                maxWidth: maxW,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                  children: [
                    Text(
                      'Upcoming',
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final course in DemoData.schedule) ...[
                      CourseListItem(
                        course: course,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CourseDetailScreen(course: course),
                          ),
                        ),
                      ),
                      const SizedBox(height: 11),
                    ],
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
