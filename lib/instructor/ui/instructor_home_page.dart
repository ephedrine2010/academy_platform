import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../cubit/instructor_home_cubit.dart';
import '../data/instructor_repository.dart';
import '../models/today_appointment.dart';
import 'attendance_page.dart';

/// The instructor's "Today" landing tab: a carousel of the appointments dated
/// today across their courses. Tapping one opens its attendance screen.
class InstructorHomePage extends StatelessWidget {
  const InstructorHomePage({super.key, required this.instructorId});

  final String instructorId;

  @override
  Widget build(BuildContext context) {
    final repository = InstructorRepository(instructorId: instructorId);
    return BlocProvider(
      create: (_) => InstructorHomeCubit(repository: repository),
      child: _HomeView(repository: repository),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView({required this.repository});

  final InstructorRepository repository;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InstructorHomeCubit, InstructorHomeState>(
      builder: (context, state) {
        final cubit = context.read<InstructorHomeCubit>();
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(TablerIcons.calendar_clock,
                      color: AppColors.teal),
                  const SizedBox(width: 10),
                  Text(
                    "Today's appointments",
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Refresh',
                    icon: const Icon(TablerIcons.refresh),
                    onPressed: cubit.refresh,
                  ),
                ],
              ),
              Text(
                '${state.appointments.length} appointment(s) scheduled today',
                style: GoogleFonts.manrope(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              Expanded(child: _body(context, state)),
            ],
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, InstructorHomeState state) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return Center(
        child: Text(
          'Could not load today’s appointments:\n${state.error}',
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(color: AppColors.red),
        ),
      );
    }
    if (state.appointments.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(TablerIcons.calendar_off,
                size: 40, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(
              'Nothing scheduled today.',
              style: GoogleFonts.manrope(color: AppColors.muted),
            ),
          ],
        ),
      );
    }

    // Carousel: a horizontal strip of fixed-width cards (scales to many).
    return Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        height: 184,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: state.appointments.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, i) => _AppointmentCard(
            today: state.appointments[i],
            onTap: () => _open(context, state.appointments[i]),
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, TodayAppointment today) async {
    final cubit = context.read<InstructorHomeCubit>();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AttendancePage(today: today, repository: repository),
      ),
    );
    // Reflect any newly-armed appointment when returning.
    await cubit.refresh();
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.today, required this.onTap});

  final TodayAppointment today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = today.appointment;
    final accent = AppColors.accentFor(today.courseTitle);
    return SizedBox(
      width: 280,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: accent.withValues(alpha: 0.14),
                    child: Icon(TablerIcons.calendar_event,
                        color: accent, size: 18),
                  ),
                  const Spacer(),
                  _StatusPill(open: a.attendanceOpen),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                today.courseTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                ),
              ),
              Text(
                today.sessionName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const Spacer(),
              _MetaRow(icon: TablerIcons.clock, text: a.date),
              if (a.location.isNotEmpty)
                _MetaRow(icon: TablerIcons.map_pin, text: a.location),
              _MetaRow(
                icon: TablerIcons.users,
                text: '${a.enrolledTraineeIds.length} enrolled',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(fontSize: 11.5, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.open});

  final bool open;

  @override
  Widget build(BuildContext context) {
    final color = open ? AppColors.green : AppColors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        open ? 'Check-in open' : 'Not armed',
        style: GoogleFonts.manrope(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
