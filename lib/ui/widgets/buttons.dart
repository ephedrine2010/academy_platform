import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Minimum touch target per the design system (≥ 44px).
const double kMinHit = 48;

/// Filled teal call-to-action. Radius 14, weight 700.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.track,
        disabledForegroundColor: AppColors.muted,
        minimumSize: const Size(0, kMinHit),
        padding: const EdgeInsets.symmetric(horizontal: 28),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: icon == null
          ? Text(label)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(label)],
            ),
    );
    return expand ? SizedBox(width: double.infinity, child: child) : child;
  }
}

/// Outlined teal button — secondary action.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.teal,
        minimumSize: const Size(0, kMinHit),
        padding: const EdgeInsets.symmetric(horizontal: 27),
        side: const BorderSide(color: AppColors.teal, width: 1.5),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: icon == null
          ? Text(label)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(label)],
            ),
    );
    return expand ? SizedBox(width: double.infinity, child: child) : child;
  }
}

/// Borderless teal text button, trailing chevron by default.
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    this.onPressed,
    this.trailing = Icons.chevron_right,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.teal,
        minimumSize: const Size(0, kMinHit),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (trailing != null) Icon(trailing, size: 18),
        ],
      ),
    );
  }
}

/// Square teal floating action button (radius 14, ≥ 48px).
class AppFab extends StatelessWidget {
  const AppFab({super.key, required this.icon, this.onPressed, this.tooltip});

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: AppColors.teal,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: kMinHit,
            height: kMinHit,
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}
