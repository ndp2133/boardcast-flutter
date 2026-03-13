/// Animated score ring — CustomPainter arc with score + condition label
/// Epic celebration: breathing glow when score >= 0.85
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/tokens.dart';
import '../logic/scoring.dart';

class ScoreRing extends StatefulWidget {
  final double score; // 0-1
  final double size;
  final bool compact; // hide label, thinner stroke, tighter glow

  const ScoreRing({super.key, required this.score, this.size = 220, this.compact = false});

  @override
  State<ScoreRing> createState() => _ScoreRingState();
}

class _ScoreRingState extends State<ScoreRing>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  // Epic glow
  AnimationController? _glowController;
  Animation<double>? _glowAnimation;
  bool _wasEpic = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _controller.forward();

    _setupGlow();
  }

  void _setupGlow() {
    final isEpic = widget.score >= 0.85;
    if (isEpic && !_wasEpic) {
      // Entering Epic — start glow + haptic
      _startGlow();
      HapticFeedback.heavyImpact();
    } else if (!isEpic && _wasEpic) {
      _stopGlow();
    }
    _wasEpic = isEpic;
  }

  void _startGlow() {
    _glowController ??= AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _glowAnimation = CurvedAnimation(
      parent: _glowController!,
      curve: Curves.easeInOut,
    );
    _glowController!.repeat(reverse: true);
  }

  void _stopGlow() {
    _glowController?.stop();
    _glowController?.dispose();
    _glowController = null;
    _glowAnimation = null;
  }

  @override
  void didUpdateWidget(ScoreRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) {
      _controller.forward(from: 0);
      _setupGlow();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _glowController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = getConditionLabel(widget.score);
    final color = _conditionColor(widget.score);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final isEpic = widget.score >= 0.85;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final animatedScore = widget.score * _animation.value;
        final displayScore = (animatedScore * 100).round();

        // Compact mode values
        final isCompact = widget.compact;
        final glowPadding = isCompact ? 12.0 : 32.0;
        final glowBlur = isCompact ? 16.0 : 32.0;

        // Glow values for Epic
        double glowSpread = isCompact ? 2 : 4;
        double glowAlpha = 0.25;
        if (isEpic && !reduceMotion && _glowAnimation != null) {
          final t = _glowAnimation!.value;
          glowSpread = isCompact ? (2 + 4 * t) : (4 + 8 * t);
          glowAlpha = 0.25 + 0.20 * t;
        }

        // Cap text scale inside the ring to prevent overflow
        return MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: Semantics(
            label: 'Surf conditions score: $displayScore out of 100, ${label.label}',
            child: Container(
              width: widget.size + glowPadding,
              height: widget.size + glowPadding,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: glowAlpha * _animation.value),
                    blurRadius: glowBlur,
                    spreadRadius: glowSpread,
                  ),
                ],
              ),
              child: Center(
                child: SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: Size(widget.size, widget.size),
                        painter: _RingPainter(
                          progress: animatedScore,
                          color: color,
                          trackColor: Theme.of(context).brightness == Brightness.dark
                              ? AppColorsDark.bgTertiary
                              : AppColors.bgTertiary,
                          strokeWidth: isCompact ? 5.0 : 12.0,
                        ),
                      ),
                      if (isCompact)
                        Text(
                          '$displayScore',
                          style: TextStyle(
                            fontFamily: AppTypography.fontMono,
                            fontSize: widget.size * 0.35,
                            fontWeight: AppTypography.weightBold,
                            color: color,
                            height: 1,
                          ),
                        )
                      else
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$displayScore',
                              style: TextStyle(
                                fontFamily: AppTypography.fontMono,
                                fontSize: widget.size * 0.30,
                                fontWeight: AppTypography.weightBold,
                                color: color,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              label.label.toUpperCase(),
                              style: TextStyle(
                                fontSize: AppTypography.textSm,
                                fontWeight: AppTypography.weightSemibold,
                                letterSpacing: 1.2,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

Color _conditionColor(double score) {
  if (score >= 0.8) return AppColors.conditionEpic;
  if (score >= 0.6) return AppColors.conditionGood;
  if (score >= 0.4) return AppColors.conditionFair;
  return AppColors.conditionPoor;
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    this.strokeWidth = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Fill arc
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final sweepAngle = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}
