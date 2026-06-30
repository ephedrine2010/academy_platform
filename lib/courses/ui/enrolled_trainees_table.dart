import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_table_view/material_table_view.dart';

import '../../theme/app_theme.dart';
import '../data/trainee_directory.dart';

/// Scrollable table of the trainees enrolled in a session, resolved from their
/// int ids via [TraineeDirectory]. Sized to scroll within an expanded session
/// card so a roster of ~100 stays usable.
///
/// Only the int id is real today; the remaining columns come from the mocked
/// directory and will be filled by the staff API later (see [TraineeDirectory]).
class EnrolledTraineesTable extends StatelessWidget {
  const EnrolledTraineesTable({
    super.key,
    required this.traineeIds,
    this.directory = const TraineeDirectory(),
  });

  final List<int> traineeIds;
  final TraineeDirectory directory;

  static const _headers = [
    'ID',
    'Name',
    'Email',
    'Phone',
    'Department',
    'Job title',
    'Status',
  ];

  @override
  Widget build(BuildContext context) {
    final profiles = directory.profilesFor(traineeIds);

    return Container(
      height: 320,
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
          TableColumn(width: 120, flex: 1),
          TableColumn(width: 130, flex: 1),
          TableColumn(width: 130, flex: 1),
          TableColumn(width: 110),
        ],
        rowCount: profiles.length,
        rowHeight: 52,
        headerHeight: 42,
        headerBuilder: (context, contentBuilder) => contentBuilder(
          context,
          (context, column) => _HeaderCell(label: _headers[column]),
        ),
        rowBuilder: (context, row, contentBuilder) {
          final p = profiles[row];
          return contentBuilder(
            context,
            (context, column) => _cell(p, column),
          );
        },
      ),
    );
  }

  Widget _cell(TraineeProfile p, int column) {
    switch (column) {
      case 0:
        return _TextCell('${p.id}', weight: FontWeight.w700);
      case 1:
        return _TextCell(p.name, weight: FontWeight.w600);
      case 2:
        return _TextCell(p.email);
      case 3:
        return _TextCell(p.phone);
      case 4:
        return _TextCell(p.department);
      case 5:
        return _TextCell(p.jobTitle);
      default:
        return Align(
          alignment: Alignment.centerLeft,
          child: _StatusChip(status: p.status),
        );
    }
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  Color get _color {
    switch (status) {
      case 'Active':
        return AppColors.green;
      case 'Completed':
        return AppColors.blue;
      default:
        return AppColors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: GoogleFonts.manrope(
          fontSize: 11,
          color: _color,
          fontWeight: FontWeight.w700,
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
