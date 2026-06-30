import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../cubit/my_sessions_cubit.dart';
import '../models/assigned_session.dart';

/// Renders the signed-in trainee's assigned **sessions** (from
/// [MySessionsCubit]) as a column of cards, with loading / error / empty states.
/// Each card shows the session name + description under its parent course's
/// title. Used by the trainee Home screen.
class MySessionsBody extends StatelessWidget {
  const MySessionsBody({
    super.key,
    this.padding = EdgeInsets.zero,
    this.shrinkWrap = true,
    this.physics = const NeverScrollableScrollPhysics(),
    this.emptyText = 'No sessions assigned yet.',
  });

  final EdgeInsetsGeometry padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MySessionsCubit>().state;

    if (state.loading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.error != null) {
      return _Message(
        icon: TablerIcons.alert_triangle,
        text: 'Could not load your sessions:\n${state.error}',
      );
    }
    if (state.sessions.isEmpty) {
      return _Message(icon: TablerIcons.calendar_off, text: emptyText);
    }

    return ListView.separated(
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      itemCount: state.sessions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 11),
      itemBuilder: (context, i) => _SessionCard(item: state.sessions[i]),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.item});

  final AssignedSession item;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentFor(item.courseTitle);
    final session = item.session;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: accent.withValues(alpha: 0.14),
            child: Icon(TablerIcons.calendar_event, color: accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Parent course label.
                Text(
                  item.courseTitle.toUpperCase(),
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  session.name,
                  style: GoogleFonts.manrope(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                if (session.description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    session.description,
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: AppColors.muted),
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
