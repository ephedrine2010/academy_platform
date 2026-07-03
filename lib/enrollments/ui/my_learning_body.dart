import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../auth/cubit/auth_cubit.dart';
import '../../theme/app_theme.dart';
import '../cubit/my_enrollments_cubit.dart';
import '../models/enrollment.dart';
import 'material_viewer_page.dart';

/// The trainee's **self-paced** materials (from [MyEnrollmentsCubit]) as a
/// column of cards: title, progress, status, and a Start / Resume / Review
/// button that opens the [MaterialViewerPage]. Rendered on the Courses tab.
class MyLearningBody extends StatelessWidget {
  const MyLearningBody({
    super.key,
    this.padding = EdgeInsets.zero,
    this.shrinkWrap = true,
    this.physics = const NeverScrollableScrollPhysics(),
  });

  final EdgeInsetsGeometry padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MyEnrollmentsCubit>().state;

    if (state.loading) {
      return const Padding(
        padding: EdgeInsets.all(28),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.error != null) {
      return _Message(
        icon: TablerIcons.alert_triangle,
        text: 'Could not load your materials:\n${state.error}',
      );
    }
    final items = state.learning;
    if (items.isEmpty) {
      return const _Message(
        icon: TablerIcons.book_off,
        text: 'No self-paced materials assigned yet.',
      );
    }

    return ListView.separated(
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 11),
      itemBuilder: (context, i) => _LearningCard(enrollment: items[i]),
    );
  }
}

class _LearningCard extends StatelessWidget {
  const _LearningCard({required this.enrollment});

  final Enrollment enrollment;

  void _open(BuildContext context) {
    final cubit = context.read<MyEnrollmentsCubit>();
    final studentName = context.read<AuthCubit>().state.user?.name;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MaterialViewerPage(
          enrollment: enrollment,
          studentName: studentName,
          onOpen: () => cubit.markStarted(enrollment),
          onProgress: (p) => cubit.saveProgress(enrollment, p),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = enrollment;
    final accent = AppColors.accentFor(e.title);
    final (buttonLabel, buttonIcon) = _button(e);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: accent.withValues(alpha: 0.14),
                child: Icon(TablerIcons.book, color: accent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.title,
                      style: GoogleFonts.manrope(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      e.deliveryType.label,
                      style: GoogleFonts.manrope(
                        fontSize: 10.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(enrollment: e),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (e.progress / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppColors.hairline,
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => _open(context),
              icon: Icon(buttonIcon, size: 16),
              label: Text(buttonLabel),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                textStyle: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  (String, IconData) _button(Enrollment e) {
    if (e.isDone) return ('Review', TablerIcons.rotate);
    if (e.isStarted) return ('Resume', TablerIcons.player_play);
    return ('Start', TablerIcons.player_play);
  }
}

/// Chip reflecting the enrollment's outcome / state.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.enrollment});

  final Enrollment enrollment;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg, icon) = _style(enrollment);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  (String, Color, Color, IconData) _style(Enrollment e) {
    switch (e.outcome) {
      case EnrollmentOutcome.passed:
        return ('Passed', const Color(0xFFE6F4EA), const Color(0xFF1E7B34),
            TablerIcons.circle_check);
      case EnrollmentOutcome.failed:
        return ('Failed', const Color(0xFFFCE8E6), AppColors.red,
            TablerIcons.circle_x);
      case EnrollmentOutcome.attended:
      case EnrollmentOutcome.absent:
      case EnrollmentOutcome.none:
        break;
    }
    switch (e.lifecycleState) {
      case LifecycleState.done:
        return ('Completed', const Color(0xFFE6F4EA), const Color(0xFF1E7B34),
            TablerIcons.circle_check);
      case LifecycleState.inProgress:
        return ('In progress', const Color(0xFFFFF4E5), const Color(0xFFB5651D),
            TablerIcons.progress);
      case LifecycleState.notStarted:
        return ('Not started', const Color(0xFFEDEEF0), AppColors.muted,
            TablerIcons.circle_dashed);
    }
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 38, color: AppColors.muted),
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
