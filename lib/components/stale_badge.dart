/// Stale data badge — shows data age with refresh button
import 'package:flutter/material.dart';
import '../theme/tokens.dart';

class StaleBadge extends StatelessWidget {
  final int? ageMinutes;
  final bool isStale;
  final VoidCallback? onRefresh;

  const StaleBadge({
    super.key,
    this.ageMinutes,
    this.isStale = false,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (!isStale && (ageMinutes == null || ageMinutes! < 15)) {
      return const SizedBox.shrink();
    }

    final ageText = _formatAge(ageMinutes);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s3,
        vertical: AppSpacing.s1,
      ),
      decoration: BoxDecoration(
        color: AppColors.conditionFair.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.access_time,
            size: 14,
            color: AppColors.conditionFair,
          ),
          const SizedBox(width: 4),
          Text(
            'Updated $ageText',
            style: TextStyle(
              fontSize: AppTypography.textXs,
              color: AppColors.conditionFair,
              fontWeight: AppTypography.weightMedium,
            ),
          ),
          if (onRefresh != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRefresh,
              child: Icon(
                Icons.refresh,
                size: 14,
                color: AppColors.conditionFair,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatAge(int? minutes) {
    if (minutes == null) return 'unknown';
    if (minutes < 60) return '${minutes}m ago';
    if (minutes < 1440) return '${minutes ~/ 60}h ago';
    return '${minutes ~/ 1440}d ago';
  }
}
