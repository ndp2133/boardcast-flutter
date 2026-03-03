import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/tokens.dart';
import '../state/health_import_provider.dart';

void showHealthImport(BuildContext context, WidgetRef ref) {
  ref.read(healthImportProvider.notifier).reset();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).brightness == Brightness.dark
        ? AppColorsDark.bgPrimary
        : AppColors.bgPrimary,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (ctx, scrollController) => Consumer(
        builder: (ctx, ref, _) {
          final importState = ref.watch(healthImportProvider);
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final textColor = isDark
              ? AppColorsDark.textPrimary
              : AppColors.textPrimary;
          final subColor = isDark
              ? AppColorsDark.textSecondary
              : AppColors.textSecondary;

          return Padding(
            padding: const EdgeInsets.all(AppSpacing.s4),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.s4),
                  decoration: BoxDecoration(
                    color: subColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Import from Health',
                  style: TextStyle(
                    fontSize: AppTypography.textBase,
                    fontWeight: AppTypography.weightSemibold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                Expanded(
                  child: _buildContent(
                      ctx, ref, importState, textColor, subColor, isDark),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

Widget _buildContent(
  BuildContext context,
  WidgetRef ref,
  HealthImportState importState,
  Color textColor,
  Color subColor,
  bool isDark,
) {
  switch (importState.phase) {
    case ImportPhase.idle:
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 48, color: AppColors.accent),
          const SizedBox(height: AppSpacing.s4),
          Text(
            'Import surf workouts from Apple Health or Health Connect.',
            style: TextStyle(fontSize: AppTypography.textSm, color: subColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s5),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                ref.read(healthImportProvider.notifier).startImport();
              },
              child: const Text('Start Import'),
            ),
          ),
        ],
      );
    case ImportPhase.requesting:
    case ImportPhase.discovering:
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.accent),
          const SizedBox(height: AppSpacing.s4),
          Text(
            'Scanning surf sessions...',
            style: TextStyle(
              fontSize: AppTypography.textSm,
              color: textColor,
            ),
          ),
        ],
      );
    case ImportPhase.enriching:
      final progress = importState.enrichTotal > 0
          ? importState.enrichProgress / importState.enrichTotal
          : 0.0;
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Found ${importState.discoveredCount} sessions',
            style: TextStyle(
              fontSize: AppTypography.textBase,
              fontWeight: AppTypography.weightSemibold,
              color: textColor,
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.accentBg,
            valueColor: const AlwaysStoppedAnimation(AppColors.accent),
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            'Enriching ${importState.enrichProgress}/${importState.enrichTotal}...',
            style: TextStyle(
              fontSize: AppTypography.textSm,
              color: subColor,
            ),
          ),
        ],
      );
    case ImportPhase.complete:
      final result = importState.result;
      final count = result?.sessions.length ?? 0;
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            count > 0 ? Icons.check_circle : Icons.info_outline,
            size: 48,
            color: count > 0 ? AppColors.conditionEpic : subColor,
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            count > 0
                ? '$count sessions imported!'
                : 'No new surf sessions found.',
            style: TextStyle(
              fontSize: AppTypography.textBase,
              fontWeight: AppTypography.weightSemibold,
              color: textColor,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(height: AppSpacing.s4),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await ref
                      .read(healthImportProvider.notifier)
                      .saveImportedSessions();
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: const Text('Save & Close'),
              ),
            ),
          ] else
            const SizedBox(height: AppSpacing.s4),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close', style: TextStyle(color: subColor)),
          ),
        ],
      );
    case ImportPhase.error:
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, size: 48, color: subColor),
          const SizedBox(height: AppSpacing.s4),
          Text(
            importState.errorMessage ?? 'Import failed',
            style: TextStyle(
              fontSize: AppTypography.textSm,
              color: subColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s4),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close', style: TextStyle(color: subColor)),
          ),
        ],
      );
  }
}
