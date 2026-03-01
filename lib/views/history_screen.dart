import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/tokens.dart';
import '../logic/surf_iq.dart';
import '../logic/units.dart';
import '../logic/time_utils.dart';
import '../logic/scoring.dart';
import '../state/auth_provider.dart';
import '../state/sessions_provider.dart';
import '../state/boards_provider.dart';
import '../state/preferences_provider.dart';
import '../state/theme_provider.dart';
import '../state/health_import_provider.dart';
import '../state/store_provider.dart';
import '../components/preferences_editor.dart';
import '../components/board_modal.dart';
import '../components/star_rating.dart';
import '../components/surf_wrapped.dart';
import 'package:url_launcher/url_launcher.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final subColor =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;
    final isGuest = ref.watch(isGuestProvider);
    final sessions = ref.watch(sessionsProvider);
    final boards = ref.watch(boardsProvider);
    final prefs = ref.watch(preferencesProvider);
    final themeMode = ref.watch(themeModeProvider);

    final completed =
        sessions.where((s) => s.status == 'completed').toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    final surfIQ = computeSurfIQ(sessions);
    final insight = generateInsight(sessions);

    return Scaffold(
      backgroundColor: isDark ? AppColorsDark.bgPrimary : AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor:
            isDark ? AppColorsDark.bgPrimary : AppColors.bgPrimary,
        elevation: 0,
        title: Text(
          'Profile',
          style: TextStyle(
            fontSize: AppTypography.textBase,
            fontWeight: AppTypography.weightSemibold,
            color: textColor,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
        children: [
          // Account section
          _buildAccountSection(context, ref, isGuest, isDark, textColor),
          const SizedBox(height: AppSpacing.s5),

          // Theme toggle
          _buildThemeToggle(ref, themeMode, isDark, textColor),
          const SizedBox(height: AppSpacing.s5),

          // Preferences summary
          _buildPreferencesSection(context, ref, prefs, isDark, textColor, subColor),
          const SizedBox(height: AppSpacing.s5),

          // Board quiver
          _buildQuiverSection(context, ref, boards, isDark, textColor, subColor),
          const SizedBox(height: AppSpacing.s5),

          // Surf IQ
          _buildSurfIQCard(surfIQ, insight, isDark, textColor, subColor),
          const SizedBox(height: AppSpacing.s5),

          // Stats
          _buildStatsGrid(completed, isDark, textColor, subColor),

          // Import from Health + Share Surf Wrapped
          const SizedBox(height: AppSpacing.s3),
          Center(
            child: TextButton.icon(
              onPressed: () => _showHealthImport(context, ref),
              icon: Icon(Icons.favorite_border, size: 16, color: AppColors.accent),
              label: Text(
                'Import from Health',
                style: TextStyle(
                  fontSize: AppTypography.textSm,
                  color: AppColors.accent,
                ),
              ),
            ),
          ),
          if (completed.isNotEmpty) ...[
            Center(
              child: TextButton.icon(
                onPressed: () {
                  final isDarkNow =
                      Theme.of(context).brightness == Brightness.dark;
                  generateAndShareWrapped(
                    sessions: sessions,
                    boards: boards,
                    isDark: isDarkNow,
                  );
                },
                icon: Icon(Icons.share, size: 16, color: AppColors.accent),
                label: Text(
                  'Share Surf Wrapped',
                  style: TextStyle(
                    fontSize: AppTypography.textSm,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.s5),

          // Session history
          if (completed.isNotEmpty) ...[
            Text(
              'Session History',
              style: TextStyle(
                fontSize: AppTypography.textSm,
                fontWeight: AppTypography.weightSemibold,
                color: textColor,
              ),
            ),
            const SizedBox(height: AppSpacing.s2),
            ...completed
                .map((s) => _buildSessionRow(s, boards, isDark, textColor, subColor)),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
              child: Text(
                'No completed sessions yet.\nPlan a session from the Track tab!',
                style: TextStyle(color: subColor),
                textAlign: TextAlign.center,
              ),
            ),

          // Legal links
          const SizedBox(height: AppSpacing.s3),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse('https://myboardcast.vercel.app/privacy.html'),
                  mode: LaunchMode.externalApplication,
                ),
                child: Text(
                  'Privacy Policy',
                  style: TextStyle(
                    fontSize: AppTypography.textXs,
                    color: subColor,
                  ),
                ),
              ),
              Text(' · ', style: TextStyle(color: subColor)),
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse('https://myboardcast.vercel.app/terms.html'),
                  mode: LaunchMode.externalApplication,
                ),
                child: Text(
                  'Terms of Service',
                  style: TextStyle(
                    fontSize: AppTypography.textXs,
                    color: subColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
        ],
      ),
    );
  }

  void _showHealthImport(BuildContext context, WidgetRef ref) {
    // Reset import state and start the import flow
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
                  // Handle bar
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
                    child: _buildHealthImportContent(
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

  Widget _buildHealthImportContent(
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

  Widget _buildAccountSection(BuildContext context, WidgetRef ref,
      bool isGuest, bool isDark, Color textColor) {
    final subColor =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;
    final user = ref.watch(authStateProvider).valueOrNull;
    final email = user?.email;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: isDark ? AppColorsDark.bgSecondary : AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                isGuest ? Icons.person_outline : Icons.person,
                color: AppColors.accent,
                size: 24,
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isGuest ? 'Guest' : 'Signed In',
                      style: TextStyle(
                        fontSize: AppTypography.textSm,
                        fontWeight: AppTypography.weightMedium,
                        color: textColor,
                      ),
                    ),
                    if (email != null)
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: AppTypography.textXs,
                          color: subColor,
                        ),
                      ),
                  ],
                ),
              ),
              if (isGuest)
                TextButton(
                  onPressed: () => _showAuthModal(context, ref),
                  child: const Text('Sign In'),
                )
              else
                TextButton(
                  onPressed: () async {
                    final auth = ref.read(authServiceProvider);
                    await auth.signOut();
                  },
                  child: const Text('Sign Out'),
                ),
            ],
          ),
          if (!isGuest) ...[
            const SizedBox(height: AppSpacing.s2),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _showDeleteAccountDialog(context, ref),
                child: Text(
                  'Delete Account',
                  style: TextStyle(
                    fontSize: AppTypography.textXs,
                    color: AppColors.conditionPoor,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This will permanently delete your account and all associated data. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final auth = ref.read(authServiceProvider);
              final store = ref.read(storeServiceProvider);
              final error = await auth.deleteAccount();
              if (error != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $error')),
                );
              } else {
                await store.clearAll();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Account deleted')),
                  );
                }
              }
            },
            child: Text(
              'Delete',
              style: TextStyle(color: AppColors.conditionPoor),
            ),
          ),
        ],
      ),
    );
  }

  void _showAuthModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColorsDark.bgPrimary
          : AppColors.bgPrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: _AuthModalContent(ref: ref),
      ),
    );
  }

  Widget _buildThemeToggle(
      WidgetRef ref, ThemeMode mode, bool isDark, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s3, vertical: AppSpacing.s2),
      decoration: BoxDecoration(
        color: isDark ? AppColorsDark.bgSecondary : AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(isDark ? Icons.dark_mode : Icons.light_mode,
              color: AppColors.accent, size: 20),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Text(
              'Dark Mode',
              style: TextStyle(
                fontSize: AppTypography.textSm,
                color: textColor,
              ),
            ),
          ),
          Switch(
            value: mode == ThemeMode.dark,
            activeColor: AppColors.accent,
            onChanged: (_) =>
                ref.read(themeModeProvider.notifier).toggle(),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesSection(BuildContext context, WidgetRef ref,
      prefs, bool isDark, Color textColor, Color subColor) {
    final waveMin = prefs?.minWaveHeight?.toStringAsFixed(1) ?? '?';
    final waveMax = prefs?.maxWaveHeight?.toStringAsFixed(1) ?? '?';
    final windMax = prefs?.maxWindSpeed?.round().toString() ?? '?';
    final windDir = prefs?.preferredWindDir ?? 'any';
    final tide = prefs?.preferredTide ?? 'any';

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
                  'Preferences',
                  style: TextStyle(
                    fontSize: AppTypography.textSm,
                    fontWeight: AppTypography.weightSemibold,
                    color: textColor,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => showPreferencesEditor(context, ref),
                child: Icon(Icons.edit, size: 18, color: AppColors.accent),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            'Waves $waveMin\u2013${waveMax}ft  \u00b7  Wind <${windMax}mph  \u00b7  $windDir wind  \u00b7  $tide tide',
            style: TextStyle(
              fontSize: AppTypography.textXs,
              color: subColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuiverSection(BuildContext context, WidgetRef ref,
      List boards, bool isDark, Color textColor, Color subColor) {
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
                  'My Quiver',
                  style: TextStyle(
                    fontSize: AppTypography.textSm,
                    fontWeight: AppTypography.weightSemibold,
                    color: textColor,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => showBoardModal(context, ref),
                child: Icon(Icons.add, size: 20, color: AppColors.accent),
              ),
            ],
          ),
          if (boards.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s2),
              child: Text(
                'No boards yet. Tap + to add one.',
                style: TextStyle(
                  fontSize: AppTypography.textXs,
                  color: subColor,
                ),
              ),
            )
          else
            ...boards.map((b) => Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          b.name,
                          style: TextStyle(
                            fontSize: AppTypography.textSm,
                            color: textColor,
                          ),
                        ),
                      ),
                      Text(
                        b.type,
                        style: TextStyle(
                          fontSize: AppTypography.textXs,
                          color: subColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () =>
                            showBoardModal(context, ref, existing: b),
                        child: Icon(Icons.edit, size: 16, color: subColor),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => ref
                            .read(boardsProvider.notifier)
                            .delete(b.id),
                        child: Icon(Icons.delete_outline,
                            size: 16, color: AppColors.conditionPoor),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildSurfIQCard(SurfIQResult iq, String? insight, bool isDark,
      Color textColor, Color subColor) {
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
          const SizedBox(height: 4),
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
                insight,
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

  Widget _buildStatsGrid(List completed, bool isDark, Color textColor,
      Color subColor) {
    final totalSessions = completed.length;
    final rated = completed.where((s) => s.rating != null);
    final avgRating = rated.isNotEmpty
        ? (rated.fold<int>(0, (sum, s) => sum + (s.rating as int)) / rated.length)
        : 0.0;
    final bestRating = rated.isNotEmpty
        ? rated.map((s) => s.rating as int).reduce((a, b) => a > b ? a : b)
        : 0;

    // Calibration accuracy
    final calibrated =
        completed.where((s) => s.calibration != null).toList();
    final aboutRight =
        calibrated.where((s) => s.calibration == 0).length;
    final accuracy = calibrated.isNotEmpty
        ? ((aboutRight / calibrated.length) * 100).round()
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Stats',
          style: TextStyle(
            fontSize: AppTypography.textSm,
            fontWeight: AppTypography.weightSemibold,
            color: textColor,
          ),
        ),
        const SizedBox(height: AppSpacing.s2),
        Row(
          children: [
            _statCell('Sessions', '$totalSessions', isDark, textColor, subColor),
            _statCell('Avg Rating',
                avgRating > 0 ? avgRating.toStringAsFixed(1) : '\u2014', isDark, textColor, subColor),
            _statCell('Best', bestRating > 0 ? '$bestRating/5' : '\u2014',
                isDark, textColor, subColor),
            _statCell('Accuracy',
                calibrated.isNotEmpty ? '$accuracy%' : '\u2014', isDark, textColor, subColor),
          ],
        ),
      ],
    );
  }

  Widget _statCell(String label, String value, bool isDark, Color textColor,
      Color subColor) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.s2, horizontal: AppSpacing.s2),
        decoration: BoxDecoration(
          color: isDark ? AppColorsDark.bgSecondary : AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: AppTypography.textBase,
                fontWeight: AppTypography.weightBold,
                fontFamily: AppTypography.fontMono,
                color: textColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: subColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionRow(session, List boards, bool isDark, Color textColor,
      Color subColor) {
    final cond = session.conditions;
    final board = session.boardId != null
        ? boards.where((b) => b.id == session.boardId).firstOrNull
        : null;

    final scoreColor = cond?.matchScore != null
        ? _sessionScoreColor(cond!.matchScore!)
        : subColor;
    final label = cond?.matchScore != null
        ? getConditionLabel(cond!.matchScore!).label
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s2),
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: isDark ? AppColorsDark.bgSecondary : AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${formatDate('${session.date}T00:00:00')} \u00b7 ${session.locationId}',
                  style: TextStyle(
                    fontSize: AppTypography.textSm,
                    fontWeight: AppTypography.weightSemibold,
                    color: textColor,
                  ),
                ),
              ),
              if (label.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: AppTypography.weightMedium,
                      color: scoreColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (cond?.waveHeight != null)
                Text(
                  '${formatWaveHeight(cond!.waveHeight)}ft',
                  style: TextStyle(
                    fontSize: AppTypography.textXs,
                    color: subColor,
                  ),
                ),
              if (cond?.windSpeed != null)
                Text(
                  ' \u00b7 ${formatWindSpeed(cond!.windSpeed)}mph',
                  style: TextStyle(
                    fontSize: AppTypography.textXs,
                    color: subColor,
                  ),
                ),
              if (board != null)
                Text(
                  ' \u00b7 ${board.name}',
                  style: TextStyle(
                    fontSize: AppTypography.textXs,
                    color: subColor,
                  ),
                ),
            ],
          ),
          if (session.tags != null && (session.tags as List).isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: (session.tags as List<String>).map((t) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.accentBg,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      t,
                      style: TextStyle(
                          fontSize: 9, color: AppColors.accent),
                    ),
                  )).toList(),
            ),
          ],
          if (session.rating != null) ...[
            const SizedBox(height: 4),
            StarRating(rating: session.rating!, size: 16),
          ],
        ],
      ),
    );
  }
}

Color _sessionScoreColor(double score) {
  if (score >= 0.8) return AppColors.conditionEpic;
  if (score >= 0.6) return AppColors.conditionGood;
  if (score >= 0.4) return AppColors.conditionFair;
  return AppColors.conditionPoor;
}

/// Auth modal — email/password sign-in + sign-up + Google OAuth.
class _AuthModalContent extends StatefulWidget {
  final WidgetRef ref;
  const _AuthModalContent({required this.ref});

  @override
  State<_AuthModalContent> createState() => _AuthModalContentState();
}

class _AuthModalContentState extends State<_AuthModalContent> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Email and password are required');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = widget.ref.read(authServiceProvider);
    final result = _isSignUp
        ? await auth.signUp(email, password)
        : await auth.signIn(email, password);

    if (!mounted) return;

    if (result.error != null) {
      setState(() {
        _loading = false;
        _error = result.error;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = widget.ref.read(authServiceProvider);
    final error = await auth.signInWithGoogle();

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _loading = false;
        _error = error;
      });
    }
    // Google OAuth opens a browser — modal stays open until auth callback
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final subColor =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
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
            _isSignUp ? 'Create Account' : 'Sign In',
            style: TextStyle(
              fontSize: AppTypography.textBase,
              fontWeight: AppTypography.weightSemibold,
              color: textColor,
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          // Email
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          // Password
          TextField(
            controller: _passwordController,
            obscureText: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.s2),
            Text(
              _error!,
              style: TextStyle(
                fontSize: AppTypography.textXs,
                color: AppColors.conditionPoor,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.s4),
          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_isSignUp ? 'Create Account' : 'Sign In'),
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          // Google sign-in
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _loading ? null : _signInWithGoogle,
              icon: const Icon(Icons.g_mobiledata, size: 24),
              label: const Text('Continue with Google'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          // Toggle sign-in / sign-up
          TextButton(
            onPressed: () => setState(() {
              _isSignUp = !_isSignUp;
              _error = null;
            }),
            child: Text(
              _isSignUp
                  ? 'Already have an account? Sign In'
                  : "Don't have an account? Sign Up",
              style: TextStyle(
                fontSize: AppTypography.textSm,
                color: AppColors.accent,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
        ],
      ),
    );
  }
}
