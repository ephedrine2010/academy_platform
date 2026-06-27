import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../ui/models/learning.dart';
import '../ui/responsive.dart';
import '../ui/widgets/badges.dart';
import '../ui/widgets/brand.dart';
import '../ui/widgets/buttons.dart';
import '../ui/widgets/progress.dart';
import '../ui/widgets/teal_header.dart';

/// Full course view — teal header with title + status, a progress panel and the
/// module list.
class CourseDetailScreen extends StatelessWidget {
  const CourseDetailScreen({super.key, required this.course});

  final Course course;

  bool get _started => (course.progress ?? 0) > 0;

  @override
  Widget build(BuildContext context) {
    final modules = course.modules.isNotEmpty
        ? course.modules
        : _fallbackModules(course.totalModules);

    final maxW = context.formFactor.contentMaxWidth;

    return Scaffold(
      body: Column(
        children: [
          TealHeader(
            maxContentWidth: maxW,
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 24),
            leading: HeaderIconButton(
              icon: TablerIcons.chevron_left,
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      IconTile(icon: course.icon, bg: AppColors.tealDark, fg: Colors.white, size: 44),
                      const SizedBox(width: 12),
                      StatusBadge.forStatus(course.status),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    course.title,
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${course.kind.label} · ${course.meta}',
                    style: GoogleFonts.manrope(fontSize: 11.5, color: AppColors.tealCaption),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ContentColumn(
              maxWidth: maxW,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                children: [
                  if (course.status != CourseStatus.completed) _progressPanel(modules),
                if (course.categories.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [for (final c in course.categories) CategoryChip(c)],
                  ),
                ],
                  const SizedBox(height: 22),
                  const SectionHeader('Modules'),
                  const SizedBox(height: 8),
                  for (var i = 0; i < modules.length; i++) ...[
                    _ModuleRow(index: i + 1, module: modules[i]),
                    if (i != modules.length - 1) const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
        child: SafeArea(
          top: false,
          child: ContentColumn(
            maxWidth: maxW,
            child: PrimaryButton(
              label: course.status == CourseStatus.completed
                  ? 'Review course'
                  : _started
                      ? 'Resume learning'
                      : 'Start course',
              icon: TablerIcons.player_play,
              expand: true,
              onPressed: () {},
            ),
          ),
        ),
      ),
    );
  }

  Widget _progressPanel(List<Module> modules) {
    final done = modules.where((m) => m.done).length;
    final total = modules.length;
    final value = total == 0 ? (course.progress ?? 0) : done / total;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          CircularProgress(value: value),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your progress',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$done of $total modules complete',
                  style: GoogleFonts.manrope(fontSize: 11, color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                SegmentedStepBar(total: total, completed: done),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Module> _fallbackModules(int count) {
    final n = count == 0 ? 5 : count;
    return [for (var i = 0; i < n; i++) Module('Module ${i + 1}', '10 min')];
  }
}

class _ModuleRow extends StatelessWidget {
  const _ModuleRow({required this.index, required this.module});

  final int index;
  final Module module;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color fg;
    final Color bg;
    if (module.done) {
      icon = TablerIcons.check;
      fg = StatusColors.enrolled.fg;
      bg = StatusColors.enrolled.bg;
    } else if (module.current) {
      icon = TablerIcons.player_play;
      fg = AppColors.teal;
      bg = AppColors.tealMist;
    } else {
      icon = TablerIcons.lock;
      fg = AppColors.muted;
      bg = AppColors.chipBg;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: module.current ? AppColors.teal : AppColors.hairline,
          width: module.current ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          IconTile(icon: icon, fg: fg, bg: bg),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$index. ${module.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  module.meta,
                  style: GoogleFonts.manrope(fontSize: 10.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
          if (module.current)
            Text(
              'Continue',
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.teal,
              ),
            ),
        ],
      ),
    );
  }
}
