/// Onboarding step: HealthKit import with 3-phase animated UX.
/// 1. Offer: "Import your surf history?"
/// 2. Importing: Animated progress
/// 3. Results: Session count, locations, date range, inferred prefs
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/tokens.dart';
import '../state/health_import_provider.dart';
import '../logic/locations.dart';

class HealthImportStep extends ConsumerStatefulWidget {
  final String? homeLocationId;
  final String? userId;
  final VoidCallback onSkip;
  final VoidCallback onComplete;

  const HealthImportStep({
    super.key,
    this.homeLocationId,
    this.userId,
    required this.onSkip,
    required this.onComplete,
  });

  @override
  ConsumerState<HealthImportStep> createState() => _HealthImportStepState();
}

class _HealthImportStepState extends ConsumerState<HealthImportStep>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _startImport() {
    ref.read(healthImportProvider.notifier).startImport(
          homeLocationId: widget.homeLocationId,
          userId: widget.userId,
        );
  }

  Future<void> _confirmImport() async {
    await ref.read(healthImportProvider.notifier).saveImportedSessions();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final subColor =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;

    final importState = ref.watch(healthImportProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
      child: switch (importState.phase) {
        ImportPhase.idle => _buildOffer(textColor, subColor, isDark),
        ImportPhase.requesting ||
        ImportPhase.discovering =>
          _buildDiscovering(textColor, subColor),
        ImportPhase.enriching =>
          _buildEnriching(importState, textColor, subColor),
        ImportPhase.complete =>
          _buildResults(importState, textColor, subColor, isDark),
        ImportPhase.error =>
          _buildError(importState, textColor, subColor, isDark),
      },
    );
  }

  // Phase 1: Offer
  Widget _buildOffer(Color textColor, Color subColor, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.s6),
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.accentBg,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Icon(
              Icons.favorite_border,
              size: 40,
              color: AppColors.accent,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s5),
        Text(
          'Import your surf history?',
          style: TextStyle(
            fontSize: AppTypography.textXl,
            fontWeight: AppTypography.weightBold,
            color: textColor,
          ),
        ),
        const SizedBox(height: AppSpacing.s2),
        Text(
          'If you track surf sessions with Apple Watch or another fitness device, '
          'we can import them to personalize your experience instantly.',
          style: TextStyle(
            fontSize: AppTypography.textSm,
            color: subColor,
            height: 1.5,
          ),
        ),
        const SizedBox(height: AppSpacing.s6),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _startImport,
            icon: const Icon(Icons.sync, size: 18),
            label: const Text('Connect Health Data'),
          ),
        ),
        const SizedBox(height: AppSpacing.s3),
        Center(
          child: TextButton(
            onPressed: widget.onSkip,
            child: Text(
              'Skip for now',
              style: TextStyle(color: subColor),
            ),
          ),
        ),
      ],
    );
  }

  // Phase 2: Discovering workouts
  Widget _buildDiscovering(Color textColor, Color subColor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 + (_pulseController.value * 0.1),
              child: child,
            );
          },
          child: Icon(
            Icons.search,
            size: 48,
            color: AppColors.accent,
          ),
        ),
        const SizedBox(height: AppSpacing.s4),
        Text(
          'Scanning your surf sessions...',
          style: TextStyle(
            fontSize: AppTypography.textBase,
            fontWeight: AppTypography.weightSemibold,
            color: textColor,
          ),
        ),
        const SizedBox(height: AppSpacing.s2),
        Text(
          'Reading workout data from Health',
          style: TextStyle(
            fontSize: AppTypography.textSm,
            color: subColor,
          ),
        ),
        const SizedBox(height: AppSpacing.s4),
        const CircularProgressIndicator(color: AppColors.accent),
      ],
    );
  }

  // Phase 3: Enriching with conditions
  Widget _buildEnriching(
      HealthImportState importState, Color textColor, Color subColor) {
    final progress = importState.enrichTotal > 0
        ? importState.enrichProgress / importState.enrichTotal
        : 0.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.waves,
          size: 48,
          color: AppColors.accent,
        ),
        const SizedBox(height: AppSpacing.s4),
        Text(
          'Found ${importState.discoveredCount} surf sessions!',
          style: TextStyle(
            fontSize: AppTypography.textBase,
            fontWeight: AppTypography.weightSemibold,
            color: textColor,
          ),
        ),
        const SizedBox(height: AppSpacing.s2),
        Text(
          'Enriching with ocean conditions '
          '(${importState.enrichProgress}/${importState.enrichTotal})...',
          style: TextStyle(
            fontSize: AppTypography.textSm,
            color: subColor,
          ),
        ),
        const SizedBox(height: AppSpacing.s4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.accentBg,
              valueColor: const AlwaysStoppedAnimation(AppColors.accent),
              minHeight: 6,
            ),
          ),
        ),
      ],
    );
  }

  // Phase 4: Results
  Widget _buildResults(HealthImportState importState, Color textColor,
      Color subColor, bool isDark) {
    final result = importState.result;
    if (result == null || result.sessions.isEmpty) {
      return _buildNoResults(textColor, subColor);
    }

    final locationNames = result.locationsFound
        .map((id) => getLocationById(id).name.split(',').first)
        .toSet()
        .toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.s6),
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.conditionEpic.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Icon(
                Icons.check_circle,
                size: 40,
                color: AppColors.conditionEpic,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Center(
            child: Text(
              '${result.sessions.length} sessions imported!',
              style: TextStyle(
                fontSize: AppTypography.textXl,
                fontWeight: AppTypography.weightBold,
                color: textColor,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s4),

          // Stats
          _resultRow(
            'Locations',
            locationNames.join(', '),
            Icons.location_on_outlined,
            textColor,
            subColor,
            isDark,
          ),
          if (result.earliestDate != null && result.latestDate != null)
            _resultRow(
              'Date range',
              '${_formatShortDate(result.earliestDate!)} – ${_formatShortDate(result.latestDate!)}',
              Icons.calendar_today_outlined,
              textColor,
              subColor,
              isDark,
            ),
          _resultRow(
            'Enriched',
            '${result.enrichedCount}/${result.sessions.length} with conditions',
            Icons.waves_outlined,
            textColor,
            subColor,
            isDark,
          ),

          if (importState.inferredPrefs != null) ...[
            const SizedBox(height: AppSpacing.s3),
            Container(
              padding: const EdgeInsets.all(AppSpacing.s3),
              decoration: BoxDecoration(
                color: AppColors.accentBg,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, size: 18, color: AppColors.accent),
                  const SizedBox(width: AppSpacing.s2),
                  Expanded(
                    child: Text(
                      'Preferences auto-detected from your surf history',
                      style: TextStyle(
                        fontSize: AppTypography.textXs,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (result.skippedDuplicate > 0 || result.skippedTooFar > 0) ...[
            const SizedBox(height: AppSpacing.s2),
            Text(
              [
                if (result.skippedDuplicate > 0)
                  '${result.skippedDuplicate} already imported',
                if (result.skippedTooFar > 0)
                  '${result.skippedTooFar} at unsupported locations',
              ].join(', '),
              style: TextStyle(
                fontSize: AppTypography.textXs,
                color: subColor,
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.s5),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _confirmImport,
              child: const Text('Import & Continue'),
            ),
          ),
          const SizedBox(height: AppSpacing.s2),
          Center(
            child: TextButton(
              onPressed: widget.onSkip,
              child: Text(
                'Skip import',
                style: TextStyle(color: subColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults(Color textColor, Color subColor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.surfing,
          size: 48,
          color: subColor,
        ),
        const SizedBox(height: AppSpacing.s4),
        Text(
          'No surf sessions found',
          style: TextStyle(
            fontSize: AppTypography.textBase,
            fontWeight: AppTypography.weightSemibold,
            color: textColor,
          ),
        ),
        const SizedBox(height: AppSpacing.s2),
        Text(
          'No surfing workouts were found in your Health data. '
          'You can import later from your Profile.',
          style: TextStyle(
            fontSize: AppTypography.textSm,
            color: subColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.s5),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: widget.onSkip,
            child: const Text('Continue'),
          ),
        ),
      ],
    );
  }

  Widget _buildError(HealthImportState importState, Color textColor,
      Color subColor, bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.info_outline,
          size: 48,
          color: subColor,
        ),
        const SizedBox(height: AppSpacing.s4),
        Text(
          'No worries!',
          style: TextStyle(
            fontSize: AppTypography.textBase,
            fontWeight: AppTypography.weightSemibold,
            color: textColor,
          ),
        ),
        const SizedBox(height: AppSpacing.s2),
        Text(
          'You can import your surf history later from your Profile.',
          style: TextStyle(
            fontSize: AppTypography.textSm,
            color: subColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.s5),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: widget.onSkip,
            child: const Text('Continue'),
          ),
        ),
      ],
    );
  }

  Widget _resultRow(String label, String value, IconData icon,
      Color textColor, Color subColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s2),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s3),
        decoration: BoxDecoration(
          color: isDark ? AppColorsDark.bgSecondary : AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.accent),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: AppTypography.textXs,
                      color: subColor,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: AppTypography.textSm,
                      fontWeight: AppTypography.weightMedium,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatShortDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }
}
