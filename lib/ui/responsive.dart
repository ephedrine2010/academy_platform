import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Form factor derived from the available width, used to adapt layout across
/// phone, tablet and Windows/desktop.
enum FormFactor { phone, tablet, desktop }

class Breakpoints {
  Breakpoints._();
  static const double tablet = 600;
  static const double desktop = 1024;
}

FormFactor formFactorFor(double width) {
  if (width >= Breakpoints.desktop) return FormFactor.desktop;
  if (width >= Breakpoints.tablet) return FormFactor.tablet;
  return FormFactor.phone;
}

extension FormFactorX on FormFactor {
  bool get isPhone => this == FormFactor.phone;
  bool get isTablet => this == FormFactor.tablet;
  bool get isDesktop => this == FormFactor.desktop;
  bool get isWide => this != FormFactor.phone;

  /// Max width the centred content column is allowed to grow to. Phones use the
  /// full width; wider screens keep the mobile rhythm by capping the column.
  double get contentMaxWidth => switch (this) {
        FormFactor.phone => double.infinity,
        FormFactor.tablet => 680,
        FormFactor.desktop => 860,
      };

  /// Columns for a list/grid of course rows at this size.
  int get courseColumns => isPhone ? 1 : 2;
}

extension ResponsiveContext on BuildContext {
  FormFactor get formFactor => formFactorFor(MediaQuery.sizeOf(this).width);
}

/// Centres its [child] and caps it to [maxWidth] so wide windows keep the
/// mobile layout rhythm instead of stretching edge to edge.
class ContentColumn extends StatelessWidget {
  const ContentColumn({super.key, required this.child, required this.maxWidth});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Width of a single item when [count] items are laid out across [available]
/// width with [gap] between them.
double itemWidthFor(double available, int count, double gap) {
  final cols = math.max(count, 1);
  return (available - gap * (cols - 1)) / cols;
}
