import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../models/learning.dart';

/// Pill-shaped status badge — full radius, weight 700, ~11px.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.colors});

  /// Convenience for the common case of badging a [CourseStatus].
  StatusBadge.forStatus(CourseStatus status, {super.key})
      : label = status.label,
        colors = status.colors;

  final String label;
  final StatusColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          color: colors.fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Outlined neutral category tag (e.g. "Pharmacy", "Compliance").
class CategoryChip extends StatelessWidget {
  const CategoryChip(this.label, {super.key, this.selected = false, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.teal : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.teal : const Color(0xFFE3DED5),
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.manrope(
              color: selected ? Colors.white : StatusColors.completed.fg,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded-square icon tile used on list items / course cards. Defaults to a
/// pale teal fill; pass [status] to tint it from the mosaic palette.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    this.fg = AppColors.teal,
    this.bg = AppColors.tealMist,
    this.size = 40,
  });

  IconTile.forStatus(CourseStatus status, {super.key, required this.icon, this.size = 40})
      : fg = status.colors.fg,
        bg = status.colors.bg;

  final IconData icon;
  final Color fg;
  final Color bg;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, color: fg, size: size * 0.45),
    );
  }
}
