import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../models/learning.dart';
import 'badges.dart';
import 'brand.dart';
import 'progress.dart';

/// Shared white card surface — radius 16, 1px hairline border, no shadow.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.radius = 16,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: AppColors.hairline),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Dark "continue learning" card — teal-ink fill, white text, progress bar.
class FeaturedCard extends StatelessWidget {
  const FeaturedCard({
    super.key,
    required this.course,
    this.label = 'Continue learning',
    this.onTap,
  });

  final Course course;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final progress = course.progress ?? 0;
    return Material(
      color: AppColors.tealDark,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow(label),
              const SizedBox(height: 8),
              Text(
                course.title,
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              LinearProgress(value: progress, track: Colors.white.withValues(alpha: 0.16)),
              const SizedBox(height: 8),
              Text(
                '${course.percent}% · Module ${course.completedModules} of ${course.totalModules}',
                style: GoogleFonts.manrope(fontSize: 10, color: AppColors.tealCaption),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thumbnail course card — pale header band with icon tile + due badge, title
/// and meta below. Used in the Courses grid/list.
class CourseCard extends StatelessWidget {
  const CourseCard({super.key, required this.course, this.onTap});

  final Course course;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.hairline),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail band.
              Container(
                height: 84,
                color: AppColors.tealMist,
                child: Stack(
                  children: [
                    Center(child: IconTile(icon: course.icon, bg: AppColors.teal, fg: Colors.white, size: 38)),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: StatusBadge.forStatus(course.status),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      course.meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(fontSize: 10.5, color: AppColors.muted),
                    ),
                    if (course.progress != null && course.status != CourseStatus.completed) ...[
                      const SizedBox(height: 10),
                      LinearProgress(value: course.progress!, height: 6),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal list row — icon tile, title + meta, trailing badge / percent /
/// chevron depending on [course] status.
class CourseListItem extends StatelessWidget {
  const CourseListItem({super.key, required this.course, this.onTap});

  final Course course;
  final VoidCallback? onTap;

  Widget _trailing() {
    switch (course.status) {
      case CourseStatus.completed:
        return Text(
          '${course.percent == 0 ? 100 : course.percent}%',
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.muted,
          ),
        );
      case CourseStatus.enrolled:
        // Matches the home reference: plain green label, not a filled pill.
        return Text(
          course.status.label,
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: course.status.colors.fg,
          ),
        );
      case CourseStatus.inProgress:
        return const Icon(TablerIcons.chevron_right, size: 18, color: Color(0xFFC5CDC9));
      default:
        return StatusBadge.forStatus(course.status);
    }
  }

  @override
  Widget build(BuildContext context) {
    final completed = course.status == CourseStatus.completed;
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          IconTile(
            icon: completed ? TablerIcons.check : course.icon,
            fg: course.accent,
            bg: course.accent.withValues(alpha: 0.14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  course.title,
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
                  course.meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(fontSize: 10.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _trailing(),
        ],
      ),
    );
  }
}
