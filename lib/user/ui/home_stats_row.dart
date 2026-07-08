import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../enrollments/cubit/my_enrollments_cubit.dart';
import '../../theme/app_theme.dart';
import '../../ui/widgets/cards.dart';
import '../cubit/my_sessions_cubit.dart';
import '../services/home_stats_service.dart';

/// The trainee's learning tally shown on Home, just below the header:
/// **Assigned** (assigned sessions), **Enrolled** (self-paced sessions) and
/// **Completed** (finished sessions). Numbers come from [HomeStatsService] — the
/// same source the [SessionProgressCard] uses — so the two can't disagree.
class HomeStatsRow extends StatelessWidget {
  const HomeStatsRow({super.key});

  @override
  Widget build(BuildContext context) {
    final sessions = context.watch<MySessionsCubit>().state;
    final enrollments = context.watch<MyEnrollmentsCubit>().state;
    final stats = const HomeStatsService().compute(sessions, enrollments);

    // Placeholder until both sources are ready, so the numbers appear once
    // rather than changing as each source resolves.
    String show(int value) => stats.ready ? '$value' : '—';

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            value: show(stats.assigned),
            label: 'Assigned',
            icon: TablerIcons.clipboard_list,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            value: show(stats.enrolled),
            label: 'Enrolled',
            icon: TablerIcons.book,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            value: show(stats.completed),
            label: 'Completed',
            icon: TablerIcons.discount_check,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label, required this.icon});

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        children: [
          Icon(icon, size: 22, color: AppColors.teal),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.manrope(fontSize: 10.5, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
