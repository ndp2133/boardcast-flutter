/// Expandable metric card — wave, wind, or tide with dot, value, sub-label,
/// sparkline, and explainer.
import 'package:flutter/material.dart';
import '../theme/tokens.dart';

class MetricCard extends StatefulWidget {
  final String name;
  final String value;
  final String unit;
  final String subLabel;
  final Color? dotColor;
  final String? idealRange;
  final String? explainer;
  final List<double>? sparklineData;
  final Widget? extra; // e.g. WindCompass

  const MetricCard({
    super.key,
    required this.name,
    required this.value,
    required this.unit,
    required this.subLabel,
    this.dotColor,
    this.idealRange,
    this.explainer,
    this.sparklineData,
    this.extra,
  });

  @override
  State<MetricCard> createState() => _MetricCardState();
}

class _MetricCardState extends State<MetricCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColorsDark.bgSecondary : AppColors.bgSecondary;
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final subColor =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: AppDurations.base,
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(AppSpacing.s3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: AppShadows.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                if (widget.dotColor != null) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: widget.dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  widget.name,
                  style: TextStyle(
                    fontSize: AppTypography.textXs,
                    fontWeight: AppTypography.weightMedium,
                    color: subColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Value
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  widget.value,
                  style: TextStyle(
                    fontFamily: AppTypography.fontMono,
                    fontSize: AppTypography.textXl,
                    fontWeight: AppTypography.weightBold,
                    color: textColor,
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  widget.unit,
                  style: TextStyle(
                    fontSize: AppTypography.textXs,
                    color: subColor,
                  ),
                ),
              ],
            ),
            // Sub-label
            Text(
              widget.subLabel,
              style: TextStyle(
                fontSize: AppTypography.textXs,
                color: subColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            // Expanded detail
            AnimatedSize(
              duration: AppDurations.base,
              curve: Curves.easeInOut,
              child: _expanded
                  ? _buildDetail(subColor)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetail(Color subColor) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.idealRange != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                widget.idealRange!,
                style: TextStyle(
                  fontSize: AppTypography.textXs,
                  color: AppColors.accent,
                  fontWeight: AppTypography.weightMedium,
                ),
              ),
            ),
          if (widget.sparklineData != null &&
              widget.sparklineData!.isNotEmpty) ...[
            SizedBox(
              height: 24,
              child: CustomPaint(
                size: const Size(double.infinity, 24),
                painter: _SparklinePainter(
                  data: widget.sparklineData!,
                  color: AppColors.accent,
                ),
              ),
            ),
            Text(
              '6h trend',
              style: TextStyle(
                fontSize: 10,
                color: subColor,
              ),
            ),
          ],
          if (widget.extra != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: widget.extra!,
            ),
          if (widget.explainer != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                widget.explainer!,
                style: TextStyle(
                  fontSize: AppTypography.textXs,
                  color: subColor,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _SparklinePainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final minVal = data.reduce((a, b) => a < b ? a : b);
    final maxVal = data.reduce((a, b) => a > b ? a : b);
    final range = maxVal - minVal;
    if (range == 0) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    for (var i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - ((data[i] - minVal) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.data != data;
}
