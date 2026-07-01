import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../courses/models/appointment.dart';
import '../../theme/app_theme.dart';
import '../cubit/my_sessions_cubit.dart';
import '../models/assigned_session.dart';

/// Renders the signed-in trainee's assigned **sessions** (from
/// [MySessionsCubit]) as a column of cards, with loading / error / empty states.
/// Each card expands to reveal the session's **appointments**, where the trainee
/// can enroll (one appointment per session) or leave. Used by the trainee Home
/// screen.
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

/// One assigned session. Expands to lazily load its appointments and let the
/// trainee enroll into one of them (or leave the one they're in).
class _SessionCard extends StatefulWidget {
  const _SessionCard({required this.item});

  final AssignedSession item;

  @override
  State<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<_SessionCard> {
  Future<List<Appointment>>? _future;

  AssignedSession get _item => widget.item;

  void _onExpansion(bool open) {
    if (open && _future == null) _load();
  }

  void _load() {
    setState(() {
      _future =
          context.read<MySessionsCubit>().loadAppointments(_item.session.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentFor(_item.courseTitle);
    final session = _item.session;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          onExpansionChanged: _onExpansion,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: accent.withValues(alpha: 0.14),
            child: Icon(TablerIcons.calendar_event, color: accent, size: 18),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _item.courseTitle.toUpperCase(),
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: accent,
                      ),
                    ),
                  ),
                  _StatusChip(status: _item.status),
                ],
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
            ],
          ),
          subtitle: session.description.isEmpty
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    session.description,
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      color: AppColors.muted,
                    ),
                  ),
                ),
          children: [
            if (_future == null)
              const SizedBox.shrink()
            else
              FutureBuilder<List<Appointment>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }
                  if (snap.hasError) {
                    return Text(
                      'Could not load appointments:\n${snap.error}',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: AppColors.red,
                      ),
                    );
                  }
                  final appointments = snap.data ?? const <Appointment>[];
                  if (appointments.isEmpty) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'No appointments yet.',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final a in appointments)
                        _AppointmentRow(
                          sessionId: session.id,
                          appointment: a,
                          accent: accent,
                          onChanged: _load,
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// One appointment row on the trainee Home: date + location, with an
/// **Enroll** / **Enrolled** toggle reflecting whether this trainee is in it.
class _AppointmentRow extends StatefulWidget {
  const _AppointmentRow({
    required this.sessionId,
    required this.appointment,
    required this.accent,
    required this.onChanged,
  });

  final String sessionId;
  final Appointment appointment;
  final Color accent;

  /// Reloads the session's appointments after enroll / leave.
  final VoidCallback onChanged;

  @override
  State<_AppointmentRow> createState() => _AppointmentRowState();
}

class _AppointmentRowState extends State<_AppointmentRow> {
  bool _busy = false;

  Future<void> _toggle(bool enrolled) async {
    if (_busy) return;
    setState(() => _busy = true);
    final cubit = context.read<MySessionsCubit>();
    final appt = widget.appointment;
    try {
      if (enrolled) {
        await cubit.unenroll(widget.sessionId, appt.id);
      } else {
        await cubit.enroll(widget.sessionId, appt.id);
      }
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update enrollment: $e')),
        );
      }
    }
    // On success the parent reloads (this row is rebuilt), so no need to clear
    // `_busy` here.
  }

  @override
  Widget build(BuildContext context) {
    final appt = widget.appointment;
    final myId = context.read<MySessionsCubit>().state.traineeId;
    final enrolled = myId != null && appt.enrolledTraineeIds.contains(myId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(TablerIcons.clock, size: 14, color: AppColors.muted),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appt.date.isEmpty ? appt.id : appt.date,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                if (appt.location.isNotEmpty)
                  Text(
                    appt.location,
                    style: GoogleFonts.manrope(
                      fontSize: 10.5,
                      color: AppColors.muted,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _EnrollButton(
            enrolled: enrolled,
            busy: _busy,
            accent: widget.accent,
            onPressed: myId == null ? null : () => _toggle(enrolled),
          ),
        ],
      ),
    );
  }
}

/// Pill button that flips between **Enroll** and **Enrolled** (tap to leave).
class _EnrollButton extends StatelessWidget {
  const _EnrollButton({
    required this.enrolled,
    required this.busy,
    required this.accent,
    required this.onPressed,
  });

  final bool enrolled;
  final bool busy;
  final Color accent;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const SizedBox(
        width: 32,
        height: 32,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (enrolled) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(TablerIcons.check, size: 14),
        label: const Text('Enrolled'),
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: BorderSide(color: accent.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle:
              GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w700),
        ),
      );
    }

    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle:
            GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w700),
      ),
      child: const Text('Enroll'),
    );
  }
}

/// Small pill on a session card showing the trainee's standing: **Completed**
/// (fulfilled), **Booked** (enrolled, not yet attended), or **Not booked**.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final SessionStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, colors, icon) = switch (status) {
      SessionStatus.attended => (
          'Completed',
          StatusColors.enrolled,
          TablerIcons.circle_check,
        ),
      SessionStatus.enrolled => (
          'Booked',
          StatusColors.inProgress,
          TablerIcons.calendar_check,
        ),
      SessionStatus.notEnrolled => (
          'Not booked',
          StatusColors.dueSoon,
          TablerIcons.calendar_plus,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: colors.fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: colors.fg,
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
