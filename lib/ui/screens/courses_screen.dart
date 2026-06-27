import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../courses/ui/courses_list_body.dart';
import '../responsive.dart';
import '../widgets/teal_header.dart';

/// Catalogue screen — the live list of courses from the Firestore `courses`
/// collection. (Search / tabs and per-trainee assignment land in a later
/// milestone; for now every course is shown.)
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
                  'Explore courses',
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
                child: const CoursesListBody(
                  padding: EdgeInsets.fromLTRB(18, 16, 18, 24),
                  emptyText: 'No courses available yet.',
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
