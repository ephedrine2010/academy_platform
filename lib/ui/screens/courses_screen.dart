import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../models/learning.dart';
import '../responsive.dart';
import '../widgets/cards.dart';
import '../widgets/inputs.dart';
import '../widgets/teal_header.dart';
import 'course_detail_screen.dart';

/// Catalogue screen — search, All/Courses/Webinars tabs, then a grid of
/// [CourseCard]s.
class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  static const _tabs = ['All', 'Courses', 'Webinars'];
  int _tab = 0;
  String _query = '';

  List<Course> get _filtered {
    return DemoData.catalog.where((c) {
      final matchesTab = switch (_tab) {
        1 => c.kind == CourseKind.course || c.kind == CourseKind.pathway,
        2 => c.kind == CourseKind.webinar,
        _ => true,
      };
      final matchesQuery =
          _query.isEmpty || c.title.toLowerCase().contains(_query.toLowerCase());
      return matchesTab && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final courses = _filtered;
    return LayoutBuilder(
      builder: (context, constraints) {
        final form = formFactorFor(constraints.maxWidth);
        final maxW = form.contentMaxWidth;
        final columns = switch (form) {
          FormFactor.phone => 2,
          FormFactor.tablet => 3,
          FormFactor.desktop => 4,
        };
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
            ContentColumn(
              maxWidth: maxW,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                child: Column(
                  children: [
                    SearchField(onChanged: (v) => setState(() => _query = v)),
                    const SizedBox(height: 12),
                    SegmentedTabs(
                      tabs: _tabs,
                      index: _tab,
                      onChanged: (i) => setState(() => _tab = i),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: courses.isEmpty
                  ? Center(
                      child: Text(
                        'No matching courses',
                        style: GoogleFonts.manrope(color: AppColors.muted),
                      ),
                    )
                  : ContentColumn(
                      maxWidth: maxW,
                      child: GridView.builder(
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          mainAxisExtent: 184,
                        ),
                        itemCount: courses.length,
                        itemBuilder: (context, i) => CourseCard(
                          course: courses[i],
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  CourseDetailScreen(course: courses[i]),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}
