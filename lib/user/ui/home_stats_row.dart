import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../enrollments/cubit/my_enrollments_cubit.dart';
import '../../enrollments/models/enrollment.dart';
import '../../theme/app_theme.dart';
import '../../ui/widgets/cards.dart';
import '../cubit/my_sessions_cubit.dart';

/// The trainee's learning tally shown on Home, just below the header:
/// **Assigned** (assigned sessions), **Enrolled** (self-paced enrollments) and
/// **Completed** (fulfilled sessions + finished enrollments). Live-bound to
/// [MySessionsCubit] and [MyEnrollmentsCubit], so it stays in sync with the
/// lists below.
class HomeStatsRow extends StatelessWidget {
  const HomeStatsRow({super.key});

  @override
  Widget build(BuildContext context) {
    final sessions = context.watch<MySessionsCubit>().state;
    final learning = context.watch<MyEnrollmentsCubit>().state.learning;

    final assigned = sessions.total;
    final enrolled = learning.length;
    final completed = sessions.fulfilled +
        learning.where((e) => e.lifecycleState == LifecycleState.done).length;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            value: '$assigned',
            label: 'Assigned',
            icon: TablerIcons.clipboard_list,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            value: '$enrolled',
            label: 'Enrolled',
            icon: TablerIcons.book,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            value: '$completed',
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
