import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../logic/surf_iq.dart';

class SurfIQCard extends StatelessWidget {
  final SurfIQResult iq;
  final String? insight;
  final bool isDark;
  final Color textColor;
  final Color subColor;

  const SurfIQCard({
    super.key,
    required this.iq,
    this.insight,
    required this.isDark,
    required this.textColor,
    required this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    final progressColor = iq.score >= 61
        ? AppColors.conditionEpic
        : iq.score >= 41
            ? AppColors.conditionGood
            : iq.score >= 21
                ? AppColors.conditionFair
                : AppColors.conditionPoor;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: isDark ? AppColorsDark.bgSecondary : AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Surf IQ',
                  style: TextStyle(
                    fontSize: AppTypography.textSm,
                    fontWeight: AppTypography.weightSemibold,
                    color: textColor,
                  ),
                ),
              ),
              Text(
                '${iq.score}',
                style: TextStyle(
                  fontSize: AppTypography.textLg,
                  fontWeight: AppTypography.weightBold,
                  color: progressColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s1),
          Text(
            iq.level,
            style: TextStyle(
              fontSize: AppTypography.textXs,
              fontWeight: AppTypography.weightMedium,
              color: progressColor,
            ),
          ),
          const SizedBox(height: AppSpacing.s2),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: iq.score / 100,
              backgroundColor: isDark
                  ? AppColorsDark.bgSurface
                  : AppColors.bgSurface,
              valueColor: AlwaysStoppedAnimation(progressColor),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            '${iq.totalSessions} sessions \u00b7 ${iq.calibratedSessions} calibrated',
            style: TextStyle(
              fontSize: AppTypography.textXs,
              color: subColor,
            ),
          ),
          if (insight != null) ...[
            const SizedBox(height: AppSpacing.s2),
            Container(
              padding: const EdgeInsets.all(AppSpacing.s2),
              decoration: BoxDecoration(
                color: AppColors.accentBg,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                insight!,
                style: TextStyle(
                  fontSize: AppTypography.textXs,
                  color: textColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
