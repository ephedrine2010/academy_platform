import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../theme/app_theme.dart';

/// Lifecycle state of a learning item, driving the [StatusColors] pair and the
/// label shown on its badge.
enum CourseStatus {
  enrolled('Enrolled', StatusColors.enrolled),
  inProgress('In progress', StatusColors.inProgress),
  dueSoon('Due soon', StatusColors.dueSoon),
  overdue('Overdue', StatusColors.overdue),
  completed('Completed', StatusColors.completed),
  certificate('Certificate', StatusColors.certificate);

  const CourseStatus(this.label, this.colors);
  final String label;
  final StatusColors colors;
}

/// Kind of learning item — drives the category chip / meta prefix.
enum CourseKind { course, webinar, pathway }

extension CourseKindLabel on CourseKind {
  String get label => switch (this) {
        CourseKind.course => 'Course',
        CourseKind.webinar => 'Webinar',
        CourseKind.pathway => 'Pathway',
      };
}

/// One module / lesson within a [Course].
class Module {
  const Module(this.title, this.meta, {this.done = false, this.current = false});
  final String title;
  final String meta;
  final bool done;
  final bool current;
}

/// A single learning item (course / webinar / pathway) shown across the
/// trainee screens. Demo data only — there is no backend wired yet.
class Course {
  const Course({
    required this.title,
    required this.kind,
    required this.status,
    required this.icon,
    required this.accent,
    this.meta = '',
    this.progress,
    this.completedModules = 0,
    this.totalModules = 0,
    this.categories = const [],
    this.modules = const [],
  });

  final String title;
  final CourseKind kind;
  final CourseStatus status;
  final IconData icon;
  final Color accent;

  /// Free-form meta line, e.g. "6 modules · 45 min" or "Webinar · Jul 2".
  final String meta;

  /// Completion fraction 0..1, or null when not started / not applicable.
  final double? progress;
  final int completedModules;
  final int totalModules;
  final List<String> categories;
  final List<Module> modules;

  int get percent => progress == null ? 0 : (progress! * 100).round();
}

/// Demo content mirroring the design-system reference screen.
class DemoData {
  DemoData._();

  static const Course continueLearning = Course(
    title: 'Patient Care Essentials',
    kind: CourseKind.course,
    status: CourseStatus.inProgress,
    icon: TablerIcons.heartbeat,
    accent: AppColors.green,
    meta: 'Module 4 of 6',
    progress: 0.68,
    completedModules: 4,
    totalModules: 6,
    categories: ['Pharmacy', 'Care'],
    modules: [
      Module('Welcome & overview', '6 min', done: true),
      Module('Patient communication', '12 min', done: true),
      Module('Medication counselling', '15 min', done: true),
      Module('Handling sensitive cases', '14 min', current: true),
      Module('Documentation', '9 min'),
      Module('Assessment', '20 min'),
    ],
  );

  static const List<Course> myCourses = [
    Course(
      title: 'Pharmacy Compliance',
      kind: CourseKind.webinar,
      status: CourseStatus.enrolled,
      icon: TablerIcons.shield_check,
      accent: AppColors.orange,
      meta: 'Webinar · Jul 2',
      categories: ['Compliance'],
    ),
    Course(
      title: 'New-Hire Onboarding',
      kind: CourseKind.pathway,
      status: CourseStatus.completed,
      icon: TablerIcons.discount_check,
      accent: AppColors.green,
      meta: 'Pathway · Completed',
      progress: 1,
      completedModules: 5,
      totalModules: 5,
      categories: ['Onboarding'],
    ),
    Course(
      title: 'Inventory Management',
      kind: CourseKind.course,
      status: CourseStatus.inProgress,
      icon: TablerIcons.building_warehouse,
      accent: AppColors.blue,
      meta: 'Course · 3 of 8 modules',
      progress: 0.38,
      completedModules: 3,
      totalModules: 8,
      categories: ['Operations'],
    ),
  ];

  static const List<Course> catalog = [
    Course(
      title: 'Dispensing Safety',
      kind: CourseKind.course,
      status: CourseStatus.dueSoon,
      icon: TablerIcons.pill,
      accent: AppColors.orange,
      meta: '6 modules · 45 min',
      categories: ['Pharmacy', 'Safety'],
    ),
    Course(
      title: 'Patient Care Essentials',
      kind: CourseKind.course,
      status: CourseStatus.inProgress,
      icon: TablerIcons.heartbeat,
      accent: AppColors.green,
      meta: '6 modules · 1h 20m',
      progress: 0.68,
      categories: ['Care'],
    ),
    Course(
      title: 'Pharmacy Compliance',
      kind: CourseKind.webinar,
      status: CourseStatus.enrolled,
      icon: TablerIcons.shield_check,
      accent: AppColors.sky,
      meta: 'Webinar · 1h · Jul 2',
      categories: ['Compliance'],
    ),
    Course(
      title: 'Inventory Management',
      kind: CourseKind.course,
      status: CourseStatus.inProgress,
      icon: TablerIcons.building_warehouse,
      accent: AppColors.blue,
      meta: '8 modules · 2h',
      progress: 0.38,
      categories: ['Operations'],
    ),
    Course(
      title: 'Customer Experience',
      kind: CourseKind.webinar,
      status: CourseStatus.dueSoon,
      icon: TablerIcons.mood_smile,
      accent: AppColors.purple,
      meta: 'Webinar · 45 min',
      categories: ['Service'],
    ),
    Course(
      title: 'Cold Chain Handling',
      kind: CourseKind.course,
      status: CourseStatus.completed,
      icon: TablerIcons.snowflake,
      accent: AppColors.green,
      meta: '4 modules · 30 min',
      progress: 1,
      categories: ['Operations', 'Safety'],
    ),
  ];

  static const List<Course> schedule = [
    Course(
      title: 'Pharmacy Compliance',
      kind: CourseKind.webinar,
      status: CourseStatus.dueSoon,
      icon: TablerIcons.calendar_event,
      accent: AppColors.orange,
      meta: 'Wed, Jul 2 · 10:00',
      categories: ['Compliance'],
    ),
    Course(
      title: 'Customer Experience',
      kind: CourseKind.webinar,
      status: CourseStatus.enrolled,
      icon: TablerIcons.calendar_event,
      accent: AppColors.purple,
      meta: 'Mon, Jul 7 · 14:00',
      categories: ['Service'],
    ),
    Course(
      title: 'Dispensing Safety — Assessment',
      kind: CourseKind.course,
      status: CourseStatus.overdue,
      icon: TablerIcons.clock_exclamation,
      accent: AppColors.red,
      meta: 'Due Jun 25',
      categories: ['Pharmacy'],
    ),
  ];

  static const List<String> certificates = [
    'New-Hire Onboarding',
    'Cold Chain Handling',
    'Fire Safety Basics',
  ];
}
