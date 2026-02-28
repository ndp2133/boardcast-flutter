/// Best time card — shows the best surfing window for today
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../logic/scoring.dart';
import '../logic/time_utils.dart';
import '../logic/units.dart';

class BestTimeCard extends StatelessWidget {
  final TopWindow? window;

  const BestTimeCard({super.key, this.window});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColorsDark.bgSecondary : AppColors.bgSecondary;

    if (window == null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.s4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: AppShadows.sm,
        ),
        child: Row(
          children: [
            Icon(Icons.star_outline, color: AppColors.textTertiary, size: 20),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Text(
                'No good windows found today',
                style: TextStyle(
                  color: isDark
                      ? AppColorsDark.textSecondary
                      : AppColors.textSecondary,
                  fontSize: AppTypography.textSm,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final w = window!;
    final label = getConditionLabel(w.avgScore);
    final color = _conditionColor(w.avgScore);
    final startHour = formatHour(w.startTime);
    final endHour = formatHour(w.endTime);
    final dayLabel = isToday(w.date) ? 'Today' : formatDayShort(w.date);
    final waveText = w.waveHeight != null
        ? '${formatWaveHeight(w.waveHeight)} ft'
        : '';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.sm,
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.star, color: color, size: 20),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      dayLabel,
                      style: TextStyle(
                        fontSize: AppTypography.textSm,
                        fontWeight: AppTypography.weightSemibold,
                        color: isDark
                            ? AppColorsDark.textPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
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
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$startHour – $endHour${waveText.isNotEmpty ? ' · $waveText' : ''} · ${w.hours}h window',
                  style: TextStyle(
                    fontSize: AppTypography.textXs,
                    color: isDark
                        ? AppColorsDark.textSecondary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color _conditionColor(double score) {
  if (score >= 0.8) return AppColors.conditionEpic;
  if (score >= 0.6) return AppColors.conditionGood;
  if (score >= 0.4) return AppColors.conditionFair;
  return AppColors.conditionPoor;
}
