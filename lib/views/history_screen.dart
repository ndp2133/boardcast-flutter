import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/tokens.dart';
import '../logic/surf_iq.dart';
import '../logic/board_recommendation.dart';
import '../state/auth_provider.dart';
import '../state/sessions_provider.dart';
import '../state/boards_provider.dart';
import '../state/preferences_provider.dart';
import '../state/theme_provider.dart';
import '../state/store_provider.dart';
import '../state/subscription_provider.dart';
import '../state/push_provider.dart';
import '../state/location_provider.dart';
import '../logic/locations.dart';
import '../components/paywall.dart';
import '../components/preferences_editor.dart';
import '../components/board_modal.dart';
import '../components/empty_state.dart';
import '../components/auth_modal.dart';
import '../components/health_import_modal.dart';
import '../components/strava_import_modal.dart';
import '../components/surf_iq_card.dart';
import '../components/session_history_list.dart';
import '../components/surf_wrapped.dart';
import '../theme/transitions.dart';
import 'feature_tour_screen.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  bool _sessionsVisible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _sessionsVisible = true);
    });
  }

  Future<void> _onRefresh() async {
    HapticFeedback.mediumImpact();
    final store = ref.read(storeServiceProvider);
    await Future.wait([
      store.syncSessions(),
      store.syncUserData(),
    ]);
    ref.invalidate(sessionsProvider);
    ref.invalidate(boardsProvider);
    ref.invalidate(preferencesProvider);
  }

  @override
  Widget build(BuildContext context) {
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
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: AppColors.accent,
        child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
        children: [
          // Account
          _buildAccountSection(context, ref, isGuest, isDark, textColor),
          const SizedBox(height: AppSpacing.s5),

          // Subscription
          _buildSubscriptionSection(context, ref, isDark, textColor, subColor),
          const SizedBox(height: AppSpacing.s5),

          // Theme toggle
          _buildThemeToggle(ref, themeMode, isDark, textColor),
          const SizedBox(height: AppSpacing.s3),

          // Surf Alerts toggle
          _buildPushToggle(context, ref, isGuest, isDark, textColor),
          const SizedBox(height: AppSpacing.s5),

          // Feature Tour replay
          _buildFeatureTourRow(context, isDark, textColor),
          const SizedBox(height: AppSpacing.s5),

          // Preferences summary
          _buildPreferencesSection(context, ref, prefs, isDark, textColor, subColor),
          const SizedBox(height: AppSpacing.s5),

          // Board quiver
          _buildQuiverSection(context, ref, boards, sessions, isDark, textColor, subColor),
          const SizedBox(height: AppSpacing.s5),

          // Surf IQ
          SurfIQCard(
            iq: surfIQ,
            insight: insight,
            isDark: isDark,
            textColor: textColor,
            subColor: subColor,
          ),
          const SizedBox(height: AppSpacing.s5),

          // Stats
          SessionStatsGrid(
            completed: completed,
            isDark: isDark,
            textColor: textColor,
            subColor: subColor,
          ),

          // Import from Health / Strava + Share Surf Wrapped
          const SizedBox(height: AppSpacing.s3),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () => showHealthImport(context, ref),
                icon: Icon(Icons.favorite_border, size: AppIconSize.base, color: AppColors.accent),
                label: Text(
                  'Health',
                  style: TextStyle(
                    fontSize: AppTypography.textSm,
                    color: AppColors.accent,
                  ),
                ),
              ),
              Text(' · ', style: TextStyle(color: isDark ? AppColorsDark.textTertiary : AppColors.textTertiary)),
              TextButton.icon(
                onPressed: () => showStravaImport(context, ref),
                icon: Icon(Icons.directions_bike, size: AppIconSize.base, color: const Color(0xFFFC5200)),
                label: Text(
                  'Strava',
                  style: TextStyle(
                    fontSize: AppTypography.textSm,
                    color: const Color(0xFFFC5200),
                  ),
                ),
              ),
            ],
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
                icon: Icon(Icons.share, size: AppIconSize.base, color: AppColors.accent),
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
          SessionHistoryList(
            sessions: completed,
            boards: boards,
            isDark: isDark,
            textColor: textColor,
            subColor: subColor,
            visible: _sessionsVisible,
          ),

          // Privacy statement
          const SizedBox(height: AppSpacing.s4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
            child: Text(
              'Your data stays yours. No ads. No selling your location to third parties. We use anonymous analytics to improve the app.',
              style: TextStyle(
                fontSize: AppTypography.textXs,
                color: subColor,
                fontStyle: FontStyle.italic,
              ),
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
      ),
    );
  }

  // --- Profile section builders (kept inline as they're short + tightly coupled) ---

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
                size: AppIconSize.xl,
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
                  onPressed: () => showAuthModal(context, ref),
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
                onPressed: () => showDeleteAccountDialog(context, ref),
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

  Widget _buildSubscriptionSection(BuildContext context, WidgetRef ref,
      bool isDark, Color textColor, Color subColor) {
    final isPremium = ref.watch(isPremiumProvider);
    final service = ref.read(subscriptionServiceProvider);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: isDark ? AppColorsDark.bgSecondary : AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(
            isPremium ? Icons.star : Icons.star_border,
            color: isPremium ? AppColors.conditionEpic : AppColors.accent,
            size: AppIconSize.xl,
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPremium ? 'Premium' : 'Free',
                  style: TextStyle(
                    fontSize: AppTypography.textSm,
                    fontWeight: AppTypography.weightMedium,
                    color: textColor,
                  ),
                ),
                Text(
                  isPremium
                      ? 'All features unlocked'
                      : 'Upgrade for AI coach & more',
                  style: TextStyle(
                    fontSize: AppTypography.textXs,
                    color: subColor,
                  ),
                ),
              ],
            ),
          ),
          if (isPremium)
            TextButton(
              onPressed: () => service.presentCustomerCenter(),
              child: const Text('Manage'),
            )
          else
            TextButton(
              onPressed: () => showPaywall(context),
              child: const Text('Upgrade'),
            ),
        ],
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
              color: AppColors.accent, size: AppIconSize.lg),
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
            activeThumbColor: AppColors.accent,
            onChanged: (_) =>
                ref.read(themeModeProvider.notifier).toggle(),
          ),
        ],
      ),
    );
  }

  Widget _buildPushToggle(BuildContext context, WidgetRef ref,
      bool isGuest, bool isDark, Color textColor) {
    final pushEnabled = ref.watch(pushEnabledProvider);
    final locationId = ref.watch(selectedLocationIdProvider);
    final location = getLocationById(locationId);
    final subColor =
        isDark ? AppColorsDark.textTertiary : AppColors.textTertiary;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s3, vertical: AppSpacing.s2),
      decoration: BoxDecoration(
        color: isDark ? AppColorsDark.bgSecondary : AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                pushEnabled
                    ? Icons.notifications_active
                    : Icons.notifications_none,
                color: AppColors.accent,
                size: AppIconSize.lg,
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Text(
                  'Surf Alerts',
                  style: TextStyle(
                    fontSize: AppTypography.textSm,
                    color: textColor,
                  ),
                ),
              ),
              Switch(
                value: pushEnabled,
                activeThumbColor: AppColors.accent,
                onChanged: (_) async {
                  if (isGuest) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Sign in to enable surf alerts')),
                    );
                    return;
                  }
                  await ref.read(pushEnabledProvider.notifier).toggle();
                },
              ),
            ],
          ),
          if (pushEnabled)
            Padding(
              padding: const EdgeInsets.only(
                  left: AppSpacing.s3 + AppSpacing.s3 + 24,
                  bottom: AppSpacing.s2),
              child: Text(
                'Alerts for: ${location.name}',
                style: TextStyle(
                  fontSize: AppTypography.textXs,
                  color: subColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeatureTourRow(
      BuildContext context, bool isDark, Color textColor) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        SlideUpRoute(
          builder: (_) => const FeatureTourScreen(isReplay: true),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s3, vertical: AppSpacing.s3),
        decoration: BoxDecoration(
          color: isDark ? AppColorsDark.bgSecondary : AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_awesome, color: AppColors.accent, size: AppIconSize.lg),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Text(
                'Feature Tour',
                style: TextStyle(
                  fontSize: AppTypography.textSm,
                  color: textColor,
                ),
              ),
            ),
            Icon(Icons.chevron_right,
                color: isDark
                    ? AppColorsDark.textTertiary
                    : AppColors.textTertiary,
                size: AppIconSize.lg),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferencesSection(BuildContext context, WidgetRef ref,
      prefs, bool isDark, Color textColor, Color subColor) {
    final waveMin = prefs?.minWaveHeight?.toStringAsFixed(1) ?? '?';
    final waveMax = prefs?.maxWaveHeight?.toStringAsFixed(1) ?? '?';
    final windMax = prefs?.maxWindSpeed?.round().toString() ?? '?';
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
                child: Icon(Icons.edit, size: AppIconSize.md, color: AppColors.accent),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            'Waves $waveMin\u2013${waveMax}ft  \u00b7  Wind <${windMax}mph  \u00b7  $tide tide',
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
      List boards, List sessions, bool isDark, Color textColor, Color subColor) {
    final boardStats = aggregateBoardStats(sessions.cast(), boards.cast());
    final insights = generateBoardInsights(sessions.cast(), boards.cast());
    return Column(
      children: [
        Container(
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
                    child: Icon(Icons.add, size: AppIconSize.lg, color: AppColors.accent),
                  ),
                ],
              ),
              if (boards.isEmpty)
                const EmptyState(
                  icon: Icons.sailing_outlined,
                  title: 'Your quiver is empty',
                  subtitle: 'Add your first board to track which shapes work best.',
                )
              else
                ...boards.map((b) {
                  final stats = boardStats[b.id];
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.s2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                b.name,
                                style: TextStyle(
                                  fontSize: AppTypography.textSm,
                                  color: textColor,
                                ),
                              ),
                              if (stats != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    [
                                      '${stats.count} session${stats.count != 1 ? 's' : ''}',
                                      if (stats.avgRating != null)
                                        '${stats.avgRating!.toStringAsFixed(1)}\u2605 avg',
                                      if (stats.bestRange != null)
                                        'Best in ${stats.bestRange}',
                                    ].join(' \u00b7 '),
                                    style: TextStyle(
                                      fontSize: AppTypography.textXs,
                                      color: subColor,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          b.type,
                          style: TextStyle(
                            fontSize: AppTypography.textXs,
                            color: subColor,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s2),
                        GestureDetector(
                          onTap: () =>
                              showBoardModal(context, ref, existing: b),
                          child: Icon(Icons.edit, size: AppIconSize.base, color: subColor),
                        ),
                        const SizedBox(width: AppSpacing.s1),
                        GestureDetector(
                          onTap: () => ref
                              .read(boardsProvider.notifier)
                              .delete(b.id),
                          child: Icon(Icons.delete_outline,
                              size: AppIconSize.base, color: AppColors.conditionPoor),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
        if (insights.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s2),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.s3),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Board Insights',
                    style: TextStyle(
                      fontSize: AppTypography.textXs,
                      fontWeight: AppTypography.weightSemibold,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...insights.map((insight) => Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      insight,
                      style: TextStyle(
                        fontSize: AppTypography.textXs,
                        color: isDark
                            ? AppColorsDark.textSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                  )),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
