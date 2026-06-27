import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../courses/ui/courses_list_body.dart';
import '../../theme/app_theme.dart';
import '../../user/cubit/home_cubit.dart';
import '../responsive.dart';
import '../widgets/brand.dart';
import '../widgets/teal_header.dart';

/// Trainee landing screen — greeting header followed by the trainee's courses.
/// Greeting identity comes from [HomeCubit]; the course list is the live
/// Firestore `courses` collection (via `CoursesCubit`). Adapts across phone /
/// tablet / desktop widths.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HomeCubit>().state;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = formFactorFor(constraints.maxWidth).contentMaxWidth;
        const hPad = 18.0;

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
                    const SectionHeader('My courses'),
                    const SizedBox(height: 12),
                    const CoursesListBody(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      emptyText: 'No courses assigned yet.',
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
