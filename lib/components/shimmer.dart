// Shimmer loading placeholder — left-to-right sweep animation for skeleton screens.
import 'package:flutter/material.dart';
import '../theme/tokens.dart';

class Shimmer extends StatefulWidget {
  final Widget child;

  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? AppColorsDark.bgTertiary : AppColors.bgTertiary;
    final highlight = isDark
        ? AppColorsDark.bgSurface.withValues(alpha: 0.6)
        : AppColors.bgSecondary.withValues(alpha: 0.8);

    return _ShimmerInheritedWidget(
      controller: _ctrl,
      baseColor: base,
      highlightColor: highlight,
      child: widget.child,
    );
  }
}

class _ShimmerInheritedWidget extends InheritedWidget {
  final AnimationController controller;
  final Color baseColor;
  final Color highlightColor;

  const _ShimmerInheritedWidget({
    required this.controller,
    required this.baseColor,
    required this.highlightColor,
    required super.child,
  });

  @override
  bool updateShouldNotify(_ShimmerInheritedWidget oldWidget) =>
      controller != oldWidget.controller;

  static _ShimmerInheritedWidget? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ShimmerInheritedWidget>();
}

/// Convenience: a shimmer-animated rounded box placeholder.
class ShimmerBox extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;

  const ShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.radius = AppRadius.md,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox> {
  @override
  Widget build(BuildContext context) {
    final shimmerWidget = _ShimmerInheritedWidget.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Fallback: static placeholder if no Shimmer ancestor
    if (shimmerWidget == null) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: isDark ? AppColorsDark.bgTertiary : AppColors.bgTertiary,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      );
    }

    return AnimatedBuilder(
      animation: shimmerWidget.controller,
      builder: (context, child) {
        final t = shimmerWidget.controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                shimmerWidget.baseColor,
                shimmerWidget.highlightColor,
                shimmerWidget.baseColor,
              ],
              stops: [
                (t - 0.3).clamp(0.0, 1.0),
                t,
                (t + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}
