import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';

/// "nahdi academy" wordmark — Bricolage Grotesque, "nahdi" w800 + "academy"
/// w500. On dark surfaces the "academy" half uses the teal caption tint.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.onDark = true, this.fontSize = 18});

  final bool onDark;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final primary = onDark ? Colors.white : AppColors.ink;
    final secondary = onDark ? AppColors.tealCaption : AppColors.teal;
    return RichText(
      text: TextSpan(
        style: GoogleFonts.bricolageGrotesque(
          fontSize: fontSize,
          height: 1,
          letterSpacing: -0.5,
        ),
        children: [
          TextSpan(
            text: 'nahdi ',
            style: TextStyle(fontWeight: FontWeight.w800, color: primary),
          ),
          TextSpan(
            text: 'academy',
            style: TextStyle(fontWeight: FontWeight.w500, color: secondary),
          ),
        ],
      ),
    );
  }
}

/// Logo mark + wordmark row, as it appears at the top of each teal header.
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.onDark = true, this.logoSize = 28, this.fontSize = 18});

  final bool onDark;
  final double logoSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          onDark ? 'assets/brand/logo/logo-white.png' : 'assets/brand/logo/logo.png',
          height: logoSize,
        ),
        const SizedBox(width: 10),
        BrandWordmark(onDark: onDark, fontSize: fontSize),
      ],
    );
  }
}

/// Teal app bar carrying the brand lockup and optional trailing actions.
class BrandAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BrandAppBar({super.key, this.actions});

  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.teal,
      foregroundColor: Colors.white,
      elevation: 0,
      titleSpacing: 20,
      title: const BrandLockup(),
      actions: actions,
    );
  }
}

/// Section heading — Bricolage Grotesque 15/w700 — with an optional trailing
/// action (e.g. a "See all" ghost button).
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing, this.color = AppColors.ink});

  final String title;
  final Widget? trailing;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Small all-caps eyebrow label (e.g. "CONTINUE LEARNING").
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color = AppColors.lime});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.manrope(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: color,
      ),
    );
  }
}
