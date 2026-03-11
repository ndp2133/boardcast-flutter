/// Inline discovery hint — replaces front-loaded feature tour with
/// contextual tips that show once on first visit to each screen.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/tokens.dart';

class DiscoveryHint extends StatefulWidget {
  final String id;
  final String message;
  final IconData icon;
  final Set<String> seenHints;
  final ValueChanged<String> onDismiss;

  const DiscoveryHint({
    super.key,
    required this.id,
    required this.message,
    required this.icon,
    required this.seenHints,
    required this.onDismiss,
  });

  @override
  State<DiscoveryHint> createState() => _DiscoveryHintState();
}

class _DiscoveryHintState extends State<DiscoveryHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    // Delay entrance slightly so the screen settles first
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted && !_dismissed) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _dismiss() {
    HapticFeedback.lightImpact();
    setState(() => _dismissed = true);
    _ctrl.reverse().then((_) {
      widget.onDismiss(widget.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.seenHints.contains(widget.id) || _dismissed) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.s3),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s3,
            vertical: AppSpacing.s2 + 2,
          ),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: isDark ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 16, color: AppColors.accent),
              const SizedBox(width: AppSpacing.s2),
              Expanded(
                child: Text(
                  widget.message,
                  style: TextStyle(
                    fontSize: AppTypography.textXs,
                    color: isDark
                        ? AppColorsDark.textPrimary
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _dismiss,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: isDark
                        ? AppColorsDark.textTertiary
                        : AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
