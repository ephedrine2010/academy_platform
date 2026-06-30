import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../cubit/attendance_cubit.dart';
import '../data/instructor_repository.dart';
import '../data/latlng_parser.dart';
import '../models/today_appointment.dart';
import 'attendance_table.dart';

/// Attendance screen for one appointment: arm the geofence + window, then mark
/// the enrolled trainees present (or revoke). Reached from the instructor Home.
class AttendancePage extends StatelessWidget {
  const AttendancePage({
    super.key,
    required this.today,
    required this.repository,
  });

  final TodayAppointment today;
  final InstructorRepository repository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AttendanceCubit(
        repository: repository,
        sessionId: today.sessionId,
        appointment: today.appointment,
      ),
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(
          title: Text(
            today.sessionName,
            style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
          ),
          backgroundColor: AppColors.surface,
        ),
        body: BlocBuilder<AttendanceCubit, AttendanceState>(
          builder: (context, state) {
            final cubit = context.read<AttendanceCubit>();
            final confirmed = state.records.length;
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HeaderCard(today: today),
                  const SizedBox(height: 12),
                  _ArmPanel(state: state),
                  const SizedBox(height: 16),
                  Text(
                    'ENROLLED TRAINEES · ${state.profiles.length}'
                    '${confirmed > 0 ? ' · $confirmed confirmed' : ''}',
                    style: GoogleFonts.manrope(
                      fontSize: 10.5,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w800,
                      color: AppColors.teal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: state.error != null
                        ? Center(
                            child: Text(
                              'Could not load attendance:\n${state.error}',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(color: AppColors.red),
                            ),
                          )
                        : state.profiles.isEmpty
                            ? Center(
                                child: Text(
                                  'No trainees enrolled in this appointment.',
                                  style: GoogleFonts.manrope(
                                    color: AppColors.muted,
                                  ),
                                ),
                              )
                            : AttendanceTable(
                                profiles: state.profiles,
                                records: state.records,
                                onMark: cubit.mark,
                                onRevoke: cubit.revoke,
                              ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.today});

  final TodayAppointment today;

  @override
  Widget build(BuildContext context) {
    final a = today.appointment;
    final meta = [
      if (a.date.isNotEmpty) a.date,
      if (a.location.isNotEmpty) a.location,
    ].join('  ·  ');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.tealMist,
            child: const Icon(TablerIcons.calendar_event, color: AppColors.teal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  today.courseTitle,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
                Text(
                  today.sessionName,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                if (meta.isNotEmpty)
                  Text(
                    meta,
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      color: AppColors.muted,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The geofence + window form. Pre-fills from the appointment when already
/// armed, and shows an "open" badge once saved.
class _ArmPanel extends StatefulWidget {
  const _ArmPanel({required this.state});

  final AttendanceState state;

  @override
  State<_ArmPanel> createState() => _ArmPanelState();
}

class _ArmPanelState extends State<_ArmPanel> {
  late final TextEditingController _coords;
  late final TextEditingController _radius;
  late final TextEditingController _hours;

  @override
  void initState() {
    super.initState();
    final a = widget.state.appointment;
    _coords = TextEditingController(
      text: (a.geoLat != null && a.geoLng != null)
          ? '${a.geoLat}, ${a.geoLng}'
          : '',
    );
    _radius = TextEditingController(text: '${a.geoRadiusM ?? 200}');
    _hours = TextEditingController(text: '${a.windowHours ?? 4}');
  }

  @override
  void dispose() {
    _coords.dispose();
    _radius.dispose();
    _hours.dispose();
    super.dispose();
  }

  void _save() {
    final coords = parseLatLng(_coords.text);
    if (coords == null) {
      _snack('Paste a valid "latitude, longitude" from Google Maps.');
      return;
    }
    final radius = int.tryParse(_radius.text.trim());
    final hours = int.tryParse(_hours.text.trim());
    if (radius == null || radius <= 0) {
      _snack('Enter a radius in metres (e.g. 200).');
      return;
    }
    if (hours == null || hours <= 0) {
      _snack('Enter the check-in window in hours (e.g. 4).');
      return;
    }
    context.read<AttendanceCubit>().arm(
          lat: coords.lat,
          lng: coords.lng,
          radiusM: radius,
          windowHours: hours,
        );
    _snack('Attendance armed — trainees can now self check-in.');
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final open = widget.state.appointment.attendanceOpen;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(TablerIcons.map_pin, size: 18, color: AppColors.teal),
              const SizedBox(width: 8),
              Text(
                'Geofence check-in',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const Spacer(),
              if (open)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Open',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.green,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Right-click the venue in Google Maps and click the coordinates to '
            'copy them, then paste below.',
            style: GoogleFonts.manrope(fontSize: 11, color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _coords,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              prefixIcon: Icon(TablerIcons.map_2, size: 18),
              labelText: 'Location (latitude, longitude)',
              hintText: '24.7136, 46.6753',
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _radius,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(TablerIcons.circle_dashed, size: 18),
                    labelText: 'Radius (m)',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _hours,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(TablerIcons.clock_hour_4, size: 18),
                    labelText: 'Window (hours)',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _save,
              icon: Icon(open ? TablerIcons.refresh : TablerIcons.lock_open,
                  size: 18),
              label: Text(open ? 'Update' : 'Arm attendance'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
            ),
          ),
        ],
      ),
    );
  }
}
