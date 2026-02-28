/// Wind compass — shows wind direction relative to beach facing angle
import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../models/location.dart';
import '../logic/scoring.dart';

class WindCompass extends StatelessWidget {
  final double windDegrees;
  final Location location;
  final double size;

  const WindCompass({
    super.key,
    required this.windDegrees,
    required this.location,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    final offshore = isOffshoreWind(windDegrees, location);
    final onshore = isOnshoreWind(windDegrees, location);
    final arrowColor = offshore
        ? AppColors.conditionEpic
        : onshore
            ? AppColors.conditionPoor
            : AppColors.conditionFair;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CompassPainter(
          windDegrees: windDegrees,
          beachFacing: location.beachFacing,
          arrowColor: arrowColor,
          isDark: Theme.of(context).brightness == Brightness.dark,
        ),
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
  final double windDegrees;
  final double beachFacing;
  final Color arrowColor;
  final bool isDark;

  _CompassPainter({
    required this.windDegrees,
    required this.beachFacing,
    required this.arrowColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    // Outer circle
    final circlePaint = Paint()
      ..color = isDark ? AppColorsDark.bgTertiary : AppColors.bgTertiary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, circlePaint);

    // Beach facing arc (light wedge showing beach direction)
    final beachRad = beachFacing * pi / 180 - pi / 2;
    final arcPaint = Paint()
      ..color = (isDark ? AppColorsDark.bgSurface : AppColors.bgSurface)
      ..style = PaintingStyle.fill;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      beachRad - pi / 6,
      pi / 3,
      true,
      arcPaint,
    );

    // Wind arrow
    final windRad = windDegrees * pi / 180 - pi / 2;
    final arrowLen = radius * 0.7;
    final arrowTip = Offset(
      center.dx + arrowLen * cos(windRad),
      center.dy + arrowLen * sin(windRad),
    );

    // Arrow line
    final arrowPaint = Paint()
      ..color = arrowColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, arrowTip, arrowPaint);

    // Arrowhead
    final headSize = radius * 0.25;
    final headAngle = pi / 6;
    final path = Path()
      ..moveTo(arrowTip.dx, arrowTip.dy)
      ..lineTo(
        arrowTip.dx - headSize * cos(windRad - headAngle),
        arrowTip.dy - headSize * sin(windRad - headAngle),
      )
      ..lineTo(
        arrowTip.dx - headSize * cos(windRad + headAngle),
        arrowTip.dy - headSize * sin(windRad + headAngle),
      )
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = arrowColor
        ..style = PaintingStyle.fill,
    );

    // Cardinal labels
    final textColor = isDark ? AppColorsDark.textTertiary : AppColors.textTertiary;
    const labels = ['N', 'E', 'S', 'W'];
    const angles = [0.0, 90.0, 180.0, 270.0];
    for (var i = 0; i < 4; i++) {
      final rad = angles[i] * pi / 180 - pi / 2;
      final labelRadius = radius + 0.5; // just inside edge
      // Skip if too close to arrow tip
      final pos = Offset(
        center.dx + labelRadius * 0.85 * cos(rad),
        center.dy + labelRadius * 0.85 * sin(rad),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            fontSize: size.width * 0.14,
            color: textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_CompassPainter old) =>
      old.windDegrees != windDegrees ||
      old.beachFacing != beachFacing ||
      old.arrowColor != arrowColor;
}
