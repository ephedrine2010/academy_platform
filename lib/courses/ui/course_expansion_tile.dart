import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../academy/utils/log.dart';
import '../../admin/ui/admin_widgets.dart';
import '../../theme/app_theme.dart';
import '../cubit/courses_cubit.dart';
import '../models/appointment.dart';
import '../models/course.dart';
import '../models/session_detail.dart';
import 'course_admin_dialogs.dart';

/// A course row that expands to reveal its sessions; each session in turn
/// expands to show that session's appointments. Assigned trainers are shown
/// under a session only when [isAdmin] is true.
class CourseExpansionTile extends StatelessWidget {
  const CourseExpansionTile({
    super.key,
    required this.course,
    required this.isAdmin,
  });

  final Course course;
  final bool isAdmin;

  Future<void> _addSession(BuildContext context) async {
    final result = await showAddSessionDialog(context);
    if (result == null || !context.mounted) return;
    await context.read<CoursesCubit>().addSession(
          course.id,
          name: result.name,
          description: result.description,
          order: course.sessions.length + 1,
        );
  }

  Future<void> _editCourse(BuildContext context) async {
    final title = await promptForText(
      context,
      title: 'Edit course',
      label: 'Course title',
      initial: course.title,
    );
    if (title == null || title.isEmpty || !context.mounted) return;
    await context.read<CoursesCubit>().editCourse(course.id, title: title);
  }

  Future<void> _deleteCourse(BuildContext context) async {
    final ok = await confirmDelete(
      context,
      message: 'Delete course “${course.title}”?\n'
          'This also removes its ${course.sessions.length} session(s) and all '
          'their appointments.',
    );
    if (!ok || !context.mounted) return;
    await context
        .read<CoursesCubit>()
        .deleteCourse(course.id, [for (final s in course.sessions) s.name]);
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentFor(course.title);
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
          leading: CircleAvatar(
            backgroundColor: accent.withValues(alpha: 0.14),
            child: Icon(TablerIcons.book, color: accent, size: 20),
          ),
          title: Text(
            course.title,
            style: GoogleFonts.manrope(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          subtitle: Text(
            course.sessions.isEmpty
                ? 'No sessions'
                : '${course.sessions.length} session(s)',
            style: GoogleFonts.manrope(fontSize: 10.5, color: AppColors.muted),
          ),
          onExpansionChanged: (open) {
            if (open) {
              logCourse(
                'course selected → "${course.id}" (title="${course.title}"), '
                'sessions(${course.sessions.length})='
                '${course.sessions.map((s) => s.name).toList()}',
              );
            }
          },
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          children: [
            if (course.sessions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No sessions for this course yet.'),
              )
            else
              for (final session in course.sessions)
                _SessionTile(
                  courseId: course.id,
                  session: session,
                  isAdmin: isAdmin,
                ),
            if (isAdmin)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    _ActionButton(
                      icon: TablerIcons.plus,
                      label: 'Add session',
                      onPressed: () => _addSession(context),
                    ),
                    _ActionButton(
                      icon: TablerIcons.pencil,
                      label: 'Edit course',
                      onPressed: () => _editCourse(context),
                    ),
                    _ActionButton(
                      icon: TablerIcons.trash,
                      label: 'Delete course',
                      danger: true,
                      onPressed: () => _deleteCourse(context),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One session row. Fetches its appointments (and, for admins, assigned
/// trainers) the first time it is expanded.
class _SessionTile extends StatefulWidget {
  const _SessionTile({
    required this.courseId,
    required this.session,
    required this.isAdmin,
  });

  final String courseId;
  final CourseSession session;
  final bool isAdmin;

  @override
  State<_SessionTile> createState() => _SessionTileState();
}

class _SessionTileState extends State<_SessionTile> {
  Future<SessionDetail>? _future;

  void _onExpansion(bool open) {
    if (open) {
      logCourse(
        'session selected → "${widget.session.name}" of course '
        '"${widget.courseId}"',
      );
    }
    if (open && _future == null) _load();
  }

  void _load() {
    setState(() {
      _future = context
          .read<CoursesCubit>()
          .loadSession(widget.courseId, widget.session.name);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          dense: true,
          leading: const Icon(TablerIcons.calendar_event,
              size: 18, color: AppColors.teal),
          title: Text(
            widget.session.name,
            style: GoogleFonts.manrope(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          subtitle: widget.session.description.isEmpty
              ? null
              : Text(
                  widget.session.description,
                  style: GoogleFonts.manrope(
                    fontSize: 10.5,
                    color: AppColors.muted,
                  ),
                ),
          onExpansionChanged: _onExpansion,
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          children: [
            if (_future == null)
              const SizedBox.shrink()
            else
              FutureBuilder<SessionDetail>(
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
                      'Could not load session:\n${snap.error}',
                      style: GoogleFonts.manrope(
                          fontSize: 11, color: AppColors.red),
                    );
                  }
                  final detail = snap.data!;
                  return _SessionBody(
                    detail: detail,
                    isAdmin: widget.isAdmin,
                    courseId: widget.courseId,
                    session: widget.session,
                    onChanged: _load,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _SessionBody extends StatelessWidget {
  const _SessionBody({
    required this.detail,
    required this.isAdmin,
    required this.courseId,
    required this.session,
    required this.onChanged,
  });

  final SessionDetail detail;
  final bool isAdmin;
  final String courseId;
  final CourseSession session;
  final VoidCallback onChanged;

  Future<void> _addAppointment(BuildContext context) async {
    final result = await showAppointmentDialog(context);
    if (result == null || !context.mounted) return;
    await context.read<CoursesCubit>().addAppointment(
          courseId,
          session.name,
          date: result.date,
          location: result.location,
          trainerIds: result.trainerIds,
        );
    onChanged();
  }

  Future<void> _editSession(BuildContext context) async {
    final desc = await promptForText(
      context,
      title: 'Edit session',
      label: 'Description',
      initial: session.description,
    );
    if (desc == null || !context.mounted) return;
    await context
        .read<CoursesCubit>()
        .editSession(courseId, key: session.key, description: desc);
  }

  Future<void> _deleteSession(BuildContext context) async {
    final ok = await confirmDelete(
      context,
      message: 'Delete session “${session.name}” and its appointments?',
    );
    if (!ok || !context.mounted) return;
    await context
        .read<CoursesCubit>()
        .deleteSession(courseId, key: session.key, sessionName: session.name);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label('Appointments'),
        const SizedBox(height: 6),
        if (detail.appointments.isEmpty)
          Text(
            'No appointments.',
            style: GoogleFonts.manrope(fontSize: 11, color: AppColors.muted),
          )
        else
          for (final a in detail.appointments)
            _AppointmentRow(
              appointment: a,
              isAdmin: isAdmin,
              courseId: courseId,
              sessionName: session.name,
              onChanged: onChanged,
            ),
        if (isAdmin) ...[
          const SizedBox(height: 12),
          _Label('Assigned trainers'),
          const SizedBox(height: 6),
          if (detail.assignedTrainerIds.isEmpty)
            Text(
              'None assigned.',
              style: GoogleFonts.manrope(fontSize: 11, color: AppColors.muted),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final id in detail.assignedTrainerIds)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(TablerIcons.user, size: 14),
                    label: Text('Trainer $id'),
                  ),
              ],
            ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _ActionButton(
                icon: TablerIcons.plus,
                label: 'Add appointment & assign',
                onPressed: () => _addAppointment(context),
              ),
              _ActionButton(
                icon: TablerIcons.pencil,
                label: 'Edit session',
                onPressed: () => _editSession(context),
              ),
              _ActionButton(
                icon: TablerIcons.trash,
                label: 'Delete session',
                danger: true,
                onPressed: () => _deleteSession(context),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _AppointmentRow extends StatelessWidget {
  const _AppointmentRow({
    required this.appointment,
    required this.isAdmin,
    required this.courseId,
    required this.sessionName,
    required this.onChanged,
  });

  final Appointment appointment;
  final bool isAdmin;
  final String courseId;
  final String sessionName;
  final VoidCallback onChanged;

  Future<void> _edit(BuildContext context) async {
    final result = await showAppointmentDialog(
      context,
      initialDate: appointment.dateTime,
      initialLocation: appointment.location,
      initialTrainerIds: appointment.enrolledTrainerIds,
      isEdit: true,
    );
    if (result == null || !context.mounted) return;
    await context.read<CoursesCubit>().editAppointment(
          courseId,
          sessionName,
          appointment.id,
          date: result.date,
          location: result.location,
          trainerIds: result.trainerIds,
        );
    onChanged();
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await confirmDelete(
      context,
      message: 'Delete appointment “${appointment.id}”?',
    );
    if (!ok || !context.mounted) return;
    await context
        .read<CoursesCubit>()
        .deleteAppointment(courseId, sessionName, appointment.id);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (appointment.location.isNotEmpty) appointment.location,
      if (appointment.enrolledTrainerIds.isNotEmpty)
        'Trainers: ${appointment.enrolledTrainerIds.join(', ')}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  appointment.date.isEmpty ? appointment.id : appointment.date,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                if (meta.isNotEmpty)
                  Text(
                    meta,
                    style: GoogleFonts.manrope(
                        fontSize: 10.5, color: AppColors.muted),
                  ),
              ],
            ),
          ),
          if (isAdmin) ...[
            _IconAction(
              icon: TablerIcons.pencil,
              tooltip: 'Edit appointment',
              onPressed: () => _edit(context),
            ),
            _IconAction(
              icon: TablerIcons.trash,
              tooltip: 'Delete appointment',
              danger: true,
              onPressed: () => _delete(context),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact labelled button used for the course / session admin actions.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: danger ? AppColors.red : AppColors.teal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: GoogleFonts.manrope(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Small icon-only action for per-appointment edit / delete.
class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.danger = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 16),
      tooltip: tooltip,
      onPressed: onPressed,
      color: danger ? AppColors.red : AppColors.muted,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: EdgeInsets.zero,
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.manrope(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        color: AppColors.teal,
      ),
    );
  }
}
