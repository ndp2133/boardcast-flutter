import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/tokens.dart';
import '../logic/scoring.dart';
import '../logic/time_utils.dart';
import '../logic/units.dart';
import 'stagger_animate.dart';

class WeeklyWindows extends StatelessWidget {
  final List<TopWindow> windows;
  final ValueChanged<String>? onWindowTap;

  const WeeklyWindows({
    super.key,
    required this.windows,
    this.onWindowTap,
  });

  @override
  Widget build(BuildContext context) {
    if (windows.length < 2) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final subColor =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Best Windows This Week',
          style: TextStyle(
            fontSize: AppTypography.textSm,
            fontWeight: AppTypography.weightSemibold,
            color: textColor,
          ),
        ),
        const SizedBox(height: AppSpacing.s2),
        ...windows.asMap().entries.map((e) => StaggerAnimate(
              index: e.key,
              child: _WindowRow(
                window: e.value,
                isDark: isDark,
                textColor: textColor,
                subColor: subColor,
                onTap: () => onWindowTap?.call(e.value.date),
              ),
            )),
      ],
    );
  }
}

class _WindowRow extends StatefulWidget {
  final TopWindow window;
  final bool isDark;
  final Color textColor;
  final Color subColor;
  final VoidCallback? onTap;

  const _WindowRow({
    required this.window,
    required this.isDark,
    required this.textColor,
    required this.subColor,
    this.onTap,
  });

  @override
  State<_WindowRow> createState() => _WindowRowState();
}

class _WindowRowState extends State<_WindowRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final w = widget.window;
    final dayLabel = isToday(w.date) ? 'Today' : formatDayShort(w.date);
    final startHour = formatHour(w.startTime);
    final endHour = formatHour(w.endTime);
    final label = getConditionLabel(w.avgScore);
    final color = _scoreColor(w.avgScore);
    final waveText =
        w.waveHeight != null ? '${formatWaveHeight(w.waveHeight)} ft' : '';

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.selectionClick();
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: AppDurations.fast,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.7 : 1.0,
          duration: AppDurations.fast,
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s2),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s3,
                vertical: AppSpacing.s2,
              ),
              decoration: BoxDecoration(
                color: Color.lerp(
                  widget.isDark ? AppColorsDark.bgSecondary : AppColors.bgSecondary,
                  color,
                  widget.isDark ? 0.06 : 0.04,
                ),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border(
                  left: BorderSide(color: color, width: 3),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 42,
                    child: Text(
                      dayLabel,
                      style: TextStyle(
                        fontSize: AppTypography.textXs,
                        fontWeight: AppTypography.weightSemibold,
                        color: widget.textColor,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '$startHour – $endHour',
                      style: TextStyle(
                        fontSize: AppTypography.textXs,
                        color: widget.subColor,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      label.label,
                      style: TextStyle(
                        fontSize: AppTypography.textXxs,
                        fontWeight: AppTypography.weightMedium,
                        color: color,
                      ),
                    ),
                  ),
                  if (waveText.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(
                      waveText,
                      style: TextStyle(
                        fontFamily: AppTypography.fontMono,
                        fontSize: AppTypography.textXs,
                        color: widget.subColor,
                      ),
                    ),
                  ],
                  const SizedBox(width: AppSpacing.s1),
                  Icon(Icons.chevron_right,
                      size: AppIconSize.base, color: widget.subColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Color _scoreColor(double score) {
  if (score >= 0.8) return AppColors.conditionEpic;
  if (score >= 0.6) return AppColors.conditionGood;
  if (score >= 0.4) return AppColors.conditionFair;
  return AppColors.conditionPoor;
}
