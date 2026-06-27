import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'brand.dart';

/// The deep-teal header zone every screen opens with: the brand lockup row,
/// then screen-specific content (a greeting, a title, etc.) flowing into the
/// warm-paper body below.
class TealHeader extends StatelessWidget {
  const TealHeader({
    super.key,
    required this.child,
    this.actions,
    this.leading,
    this.maxContentWidth = double.infinity,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 12, 22),
  });

  final Widget child;
  final List<Widget>? actions;

  /// Optional widget shown before the brand lockup (e.g. a back button on a
  /// pushed detail route).
  final Widget? leading;

  /// Caps the inner content width so the teal banner can stay full-bleed while
  /// its contents stay aligned with the body column on wide windows.
  final double maxContentWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.teal,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (leading != null) leading!,
                      const BrandLockup(),
                      const Spacer(),
                      if (actions != null) ...actions!,
                    ],
                  ),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A circular ghost icon button for the teal header (search, sign-out, …).
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({super.key, required this.icon, this.onPressed, this.tooltip});

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, color: AppColors.tealCaption, size: 22),
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    );
  }
}
