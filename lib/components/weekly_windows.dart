import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../logic/scoring.dart';
import '../logic/time_utils.dart';
import '../logic/units.dart';

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
        ...windows.map((w) => _windowRow(w, isDark, textColor, subColor)),
      ],
    );
  }

  Widget _windowRow(
      TopWindow w, bool isDark, Color textColor, Color subColor) {
    final dayLabel = isToday(w.date) ? 'Today' : formatDayShort(w.date);
    final startHour = formatHour(w.startTime);
    final endHour = formatHour(w.endTime);
    final label = getConditionLabel(w.avgScore);
    final color = _scoreColor(w.avgScore);
    final waveText =
        w.waveHeight != null ? '${formatWaveHeight(w.waveHeight)} ft' : '';

    return GestureDetector(
      onTap: () => onWindowTap?.call(w.date),
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.s2),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s3,
            vertical: AppSpacing.s2,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppColorsDark.bgSecondary : AppColors.bgSecondary,
            borderRadius: BorderRadius.circular(AppRadius.sm),
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
                    color: textColor,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '$startHour – $endHour',
                  style: TextStyle(
                    fontSize: AppTypography.textXs,
                    color: subColor,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  label.label,
                  style: TextStyle(
                    fontSize: 10,
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
                    color: subColor,
                  ),
                ),
              ],
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 16, color: subColor),
            ],
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
