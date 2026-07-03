import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../courses/ui/courses_list_body.dart';
import '../../enrollments/ui/my_learning_body.dart';
import '../responsive.dart';
import '../widgets/brand.dart';
import '../widgets/teal_header.dart';

/// Trainee Courses screen — the trainee's **self-paced materials** ("My
/// learning", from their enrollments) followed by the browsable course
/// catalogue. Per the brainstorm rule, self-driven learning lives here (dated
/// sessions stay on Home / Schedule).
class CoursesScreen extends StatelessWidget {
  const CoursesScreen({super.key});

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
                  'Courses',
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
                    const SectionHeader('My learning'),
                    const SizedBox(height: 12),
                    const MyLearningBody(),
                    const SizedBox(height: 22),
                    const SectionHeader('Explore courses'),
                    const SizedBox(height: 12),
                    const CoursesListBody(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      emptyText: 'No courses available yet.',
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
