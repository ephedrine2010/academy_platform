import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_table_view/material_table_view.dart';

import '../../courses/data/trainee_directory.dart';
import '../../theme/app_theme.dart';
import '../models/attendance_record.dart';

/// Roster table for an appointment's enrolled trainees with their attendance
/// status and the instructor's mark / revoke action per row.
///
/// Profiles are the (mocked) [TraineeDirectory] data; [records] holds whoever is
/// already confirmed (absent id = not yet).
class AttendanceTable extends StatelessWidget {
  const AttendanceTable({
    super.key,
    required this.profiles,
    required this.records,
    required this.onMark,
    required this.onRevoke,
  });

  final List<TraineeProfile> profiles;
  final Map<int, AttendanceRecord> records;
  final ValueChanged<int> onMark;
  final ValueChanged<int> onRevoke;

  static const _headers = ['ID', 'Name', 'Email', 'Department', 'Status', ''];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: TableView.builder(
        columns: const [
          TableColumn(width: 90),
          TableColumn(width: 150, flex: 2),
          TableColumn(width: 200, flex: 2),
          TableColumn(width: 130, flex: 1),
          TableColumn(width: 160),
          TableColumn(width: 120),
        ],
        rowCount: profiles.length,
        rowHeight: 54,
        headerHeight: 42,
        headerBuilder: (context, contentBuilder) => contentBuilder(
          context,
          (context, column) => _HeaderCell(label: _headers[column]),
        ),
        rowBuilder: (context, row, contentBuilder) {
          final p = profiles[row];
          final record = records[p.id];
          return contentBuilder(
            context,
            (context, column) => _cell(p, record, column),
          );
        },
      ),
    );
  }

  Widget _cell(TraineeProfile p, AttendanceRecord? record, int column) {
    switch (column) {
      case 0:
        return _TextCell('${p.id}', weight: FontWeight.w700);
      case 1:
        return _TextCell(p.name, weight: FontWeight.w600);
      case 2:
        return _TextCell(p.email);
      case 3:
        return _TextCell(p.department);
      case 4:
        return Align(
          alignment: Alignment.centerLeft,
          child: _StatusChip(record: record),
        );
      default:
        return Align(
          alignment: Alignment.centerLeft,
          child: record == null
              ? _MarkButton(onPressed: () => onMark(p.id))
              : IconButton(
                  tooltip: 'Revoke',
                  icon: const Icon(TablerIcons.x, size: 18),
                  color: AppColors.red,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onRevoke(p.id),
                ),
        );
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.record});

  final AttendanceRecord? record;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (record?.method) {
      AttendanceMethod.location => ('Self-confirmed', AppColors.green),
      AttendanceMethod.instructor => ('Confirmed by you', AppColors.blue),
      null => ('Not yet', AppColors.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MarkButton extends StatelessWidget {
  const _MarkButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(TablerIcons.check, size: 16),
      label: const Text('Mark'),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.teal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _TextCell extends StatelessWidget {
  const _TextCell(this.text, {this.weight});

  final String text;
  final FontWeight? weight;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: weight ?? FontWeight.w500,
          color: AppColors.ink,
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.manrope(
          fontSize: 10.5,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w800,
          color: AppColors.muted,
        ),
      ),
    );
  }
}
