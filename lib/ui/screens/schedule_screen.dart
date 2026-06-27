import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../courses/ui/courses_list_body.dart';
import '../../theme/app_theme.dart';
import '../responsive.dart';
import '../widgets/teal_header.dart';

/// Upcoming sessions for the trainee. For now this shows every course from the
/// Firestore `courses` collection; once appointments and per-trainee
/// assignment are modelled it will narrow to the trainee's scheduled sessions.
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                      child: Text(
                        'Upcoming',
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    const Expanded(
                      child: CoursesListBody(
                        padding: EdgeInsets.fromLTRB(18, 10, 18, 24),
                        emptyText: 'Nothing scheduled yet.',
                      ),
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
