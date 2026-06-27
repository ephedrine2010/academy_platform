import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';

/// Slim rounded progress bar — green fill on a warm-grey track.
class LinearProgress extends StatelessWidget {
  const LinearProgress({
    super.key,
    required this.value,
    this.height = 8,
    this.color = AppColors.green,
    this.track = AppColors.track,
  });

  final double value; // 0..1
  final double height;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: height,
        backgroundColor: track,
        valueColor: AlwaysStoppedAnimation(color),
      ),
    );
  }
}

/// Ring progress with the percentage centred inside.
class CircularProgress extends StatelessWidget {
  const CircularProgress({
    super.key,
    required this.value,
    this.size = 54,
    this.color = AppColors.green,
  });

  final double value; // 0..1
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: value.clamp(0, 1),
              strokeWidth: 7,
              backgroundColor: AppColors.track,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Text(
            '${(value * 100).round()}%',
            style: GoogleFonts.bricolageGrotesque(
              fontSize: size * 0.2,
              fontWeight: FontWeight.w800,
              color: AppColors.teal,
            ),
          ),
        ],
      ),
    );
  }
}

/// Segmented step bar — [completed] of [total] segments filled.
class SegmentedStepBar extends StatelessWidget {
  const SegmentedStepBar({
    super.key,
    required this.total,
    required this.completed,
    this.color = AppColors.green,
    this.gap = 5,
    this.height = 6,
  });

  final int total;
  final int completed;
  final Color color;
  final double gap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final steps = math.max(total, 1);
    return Row(
      children: List.generate(steps, (i) {
        return Expanded(
          child: Container(
            height: height,
            margin: EdgeInsets.only(right: i == steps - 1 ? 0 : gap),
            decoration: BoxDecoration(
              color: i < completed ? color : AppColors.track,
              borderRadius: BorderRadius.circular(height / 2),
            ),
          ),
        );
      }),
    );
  }
}
