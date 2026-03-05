import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/tokens.dart';
import '../state/strava_import_provider.dart';

/// Official Strava brand orange per brand guidelines
const _stravaOrange = Color(0xFFFC5200);

void showStravaImport(BuildContext context, WidgetRef ref) {
  ref.read(stravaImportProvider.notifier).reset();

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
          final importState = ref.watch(stravaImportProvider);
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final textColor =
              isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
          final subColor =
              isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;

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
                  'Import from Strava',
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
  StravaImportState importState,
  Color textColor,
  Color subColor,
  bool isDark,
) {
  switch (importState.phase) {
    case StravaImportPhase.idle:
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Import surf sessions from your Strava account.',
            style: TextStyle(fontSize: AppTypography.textSm, color: subColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            'We only read activities tagged as "Surfing".',
            style: TextStyle(fontSize: AppTypography.textXs, color: subColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s5),
          if (!importState.isConnected)
            // Official "Connect with Strava" button per brand guidelines
            GestureDetector(
              onTap: () =>
                  ref.read(stravaImportProvider.notifier).startImport(),
              child: Image.asset(
                isDark
                    ? 'assets/images/btn_strava_connect_orange.png'
                    : 'assets/images/btn_strava_connect_orange.png',
                height: 48,
              ),
            )
          else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () =>
                    ref.read(stravaImportProvider.notifier).startImport(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _stravaOrange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Import Sessions'),
              ),
            ),
            const SizedBox(height: AppSpacing.s2),
            TextButton(
              onPressed: () async {
                await ref
                    .read(stravaImportProvider.notifier)
                    .disconnect();
              },
              child: Text(
                'Disconnect Strava',
                style: TextStyle(
                  fontSize: AppTypography.textXs,
                  color: AppColors.conditionPoor,
                ),
              ),
            ),
          ],
        ],
      );

    case StravaImportPhase.connecting:
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: _stravaOrange),
          const SizedBox(height: AppSpacing.s4),
          Text(
            'Connecting to Strava...',
            style: TextStyle(
              fontSize: AppTypography.textSm,
              color: textColor,
            ),
          ),
        ],
      );

    case StravaImportPhase.discovering:
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: _stravaOrange),
          const SizedBox(height: AppSpacing.s4),
          Text(
            'Scanning surf activities...',
            style: TextStyle(
              fontSize: AppTypography.textSm,
              color: textColor,
            ),
          ),
        ],
      );

    case StravaImportPhase.enriching:
      final progress = importState.enrichTotal > 0
          ? importState.enrichProgress / importState.enrichTotal
          : 0.0;
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Found ${importState.discoveredCount} surf sessions',
            style: TextStyle(
              fontSize: AppTypography.textBase,
              fontWeight: AppTypography.weightSemibold,
              color: textColor,
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: _stravaOrange.withValues(alpha: 0.15),
            valueColor: const AlwaysStoppedAnimation(_stravaOrange),
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            'Enriching ${importState.enrichProgress}/${importState.enrichTotal} with conditions...',
            style: TextStyle(
              fontSize: AppTypography.textSm,
              color: subColor,
            ),
          ),
        ],
      );

    case StravaImportPhase.complete:
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
          if (count > 0 && result != null) ...[
            const SizedBox(height: AppSpacing.s2),
            if (result.enrichedCount > 0)
              Text(
                '${result.enrichedCount} enriched with conditions',
                style: TextStyle(
                  fontSize: AppTypography.textXs,
                  color: subColor,
                ),
              ),
            if (result.skippedDuplicate > 0)
              Text(
                '${result.skippedDuplicate} duplicates skipped',
                style: TextStyle(
                  fontSize: AppTypography.textXs,
                  color: subColor,
                ),
              ),
            const SizedBox(height: AppSpacing.s4),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await ref
                      .read(stravaImportProvider.notifier)
                      .saveImportedSessions();
                  if (context.mounted) Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _stravaOrange,
                  foregroundColor: Colors.white,
                ),
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

    case StravaImportPhase.error:
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
            onPressed: () {
              ref.read(stravaImportProvider.notifier).reset();
            },
            child: Text('Try Again', style: TextStyle(color: _stravaOrange)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close', style: TextStyle(color: subColor)),
          ),
        ],
      );
  }
}
