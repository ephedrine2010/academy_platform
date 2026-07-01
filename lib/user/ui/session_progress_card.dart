import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../cubit/my_sessions_cubit.dart';

/// A summary card for the trainee Home: how many of their assigned sessions
/// they've **fulfilled** (confirmed present), shown as a big fraction, a
/// progress bar, and pending/completed counts. Reads [MySessionsCubit] state, so
/// it stays in sync with the session list. Hides itself while loading, on error,
/// or when nothing is assigned (the list below already shows those states).
class SessionProgressCard extends StatelessWidget {
  const SessionProgressCard({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MySessionsCubit>().state;
    if (state.loading || state.error != null || state.total == 0) {
      return const SizedBox.shrink();
    }

    final done = state.fulfilled;
    final total = state.total;
    final pct = (state.progress * 100).round();
    final allDone = done == total;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.teal,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                allDone ? TablerIcons.trophy : TablerIcons.progress_check,
                size: 18,
                color: AppColors.tealCaption,
              ),
              const SizedBox(width: 8),
              Text(
                allDone ? 'All sessions completed' : 'Your progress',
                style: GoogleFonts.manrope(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: AppColors.tealCaption,
                ),
              ),
              const Spacer(),
              Text(
                '$pct%',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$done',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'of $total sessions completed',
                style: GoogleFonts.manrope(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: state.progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.16),
              valueColor: const AlwaysStoppedAnimation(AppColors.lime),
            ),
          ),
          if (state.pending > 0) ...[
            const SizedBox(height: 10),
            Text(
              '${state.pending} upcoming ${state.pending == 1 ? 'session' : 'sessions'} booked',
              style: GoogleFonts.manrope(
                fontSize: 11.5,
                color: AppColors.tealCaption,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
