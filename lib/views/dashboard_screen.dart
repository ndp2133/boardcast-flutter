/// Dashboard screen — decision-first "The Call" hero, reason chips, metrics, AI Q&A
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/tokens.dart';
import '../models/merged_conditions.dart';
import '../models/hourly_data.dart';
import '../models/location.dart';
import '../models/user_prefs.dart';
import '../logic/scoring.dart';
import '../logic/score_breakdown_helpers.dart';
import '../logic/units.dart';
import '../logic/time_utils.dart';
import '../logic/forecast_summary.dart';
import '../logic/board_recommendation.dart';
import '../state/conditions_provider.dart';
import '../state/location_provider.dart';
import '../state/preferences_provider.dart';
import '../state/ai_provider.dart';
import '../state/boards_provider.dart';
import '../components/location_picker.dart';
import '../components/the_call_card.dart';
import '../components/share_card.dart';
import '../components/alert_banner.dart';
import '../components/discovery_hint.dart';
import '../state/sessions_provider.dart';
import '../state/store_provider.dart';
import '../components/shimmer.dart';
import '../components/score_breakdown_sheet.dart';
import '../components/score_ring.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final VoidCallback? onNavigateToForecast;

  const DashboardScreen({super.key, this.onNavigateToForecast});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Timer? _autoRefresh;
  final _scrubNotifier = ValueNotifier<int?>(null);
  late Set<String> _seenHints;
  DateTime? _lastSheetOpen;

  @override
  void initState() {
    super.initState();
    _seenHints = ref.read(storeServiceProvider).getSeenHints();
    _autoRefresh = Timer.periodic(const Duration(minutes: 15), (_) {
      ref.invalidate(conditionsProvider);
    });
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    _scrubNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conditionsAsync = ref.watch(conditionsProvider);
    final location = ref.watch(selectedLocationProvider);
    final prefs = ref.watch(preferencesProvider);
    final dataAge = ref.watch(dataAgeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor:
            isDark ? AppColorsDark.bgPrimary : AppColors.bgPrimary,
        appBar: AppBar(
          backgroundColor:
              isDark ? AppColorsDark.bgPrimary : AppColors.bgPrimary,
          elevation: 0,
          title: GestureDetector(
            onTap: () => showLocationPicker(context, ref),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      location.name,
                      style: TextStyle(
                        fontSize: AppTypography.textBase,
                        fontWeight: AppTypography.weightSemibold,
                        color: isDark
                            ? AppColorsDark.textPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down,
                      size: 20,
                      color: isDark
                          ? AppColorsDark.textSecondary
                          : AppColors.textSecondary,
                    ),
                  ],
                ),
                if (dataAge != null && dataAge >= 15)
                  Text(
                    'Updated ${dataAge}m ago',
                    style: TextStyle(
                      fontSize: AppTypography.textXxs,
                      color: isDark
                          ? AppColorsDark.textTertiary
                          : AppColors.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
          centerTitle: false,
          actions: [
            if (conditionsAsync.hasValue)
              IconButton(
                icon: Icon(
                  Icons.share,
                  size: 20,
                  color: isDark
                      ? AppColorsDark.textSecondary
                      : AppColors.textSecondary,
                ),
                onPressed: () => _onShare(
                    conditionsAsync.value!, location, prefs, isDark),
              ),
          ],
        ),
        body: AnimatedSwitcher(
          duration: AppDurations.slow,
          child: conditionsAsync.when(
            skipLoadingOnRefresh: true,
            loading: () => _buildSkeleton(isDark),
            error: (err, _) => _buildError(err, isDark),
            data: (data) =>
                _buildDashboard(data, location, prefs, dataAge, isDark),
          ),
        ),
      ),
    );
  }

  void _onShare(MergedConditions data, Location location, UserPrefs prefs,
      bool isDark) {
    final bestWindow = findBestWindow(data.hourly, prefs, location);
    generateAndShareCard(
      current: data.current,
      location: location,
      isDark: isDark,
      prefs: prefs,
      bestWindow: bestWindow,
      hourlyData: data.hourly,
    );
  }

  Widget _buildDashboard(
    MergedConditions data,
    Location location,
    UserPrefs prefs,
    int? dataAge,
    bool isDark,
  ) {
    final current = data.current;

    // Compute current match score
    final hourlyTimes = data.hourly.map((h) => h.time).toList();
    final nowIdx = getCurrentHourIndex(hourlyTimes);
    final currentHour = nowIdx >= 0 && nowIdx < data.hourly.length
        ? data.hourly[nowIdx]
        : null;
    final tideRange = TideRange.fromHourlyData(data.hourly);
    final score = computeMatchScore(currentHour, prefs, location,
        tideRange: tideRange);
    final scoreInt = (score * 100).round();

    // Best window
    final bestWindow = findBestWindow(data.hourly, prefs, location,
        tideRange: tideRange);

    // Wind direction
    final windDir = current.windDirection;
    final windQuality = windDir != null
        ? (isOffshoreWind(windDir, location)
            ? 'Offshore'
            : isOnshoreWind(windDir, location)
                ? 'Onshore'
                : 'Cross-shore')
        : '';

    // Verdict (same logic as condition_state_builder)
    final bestWindowRange = _formatBestWindowRange(bestWindow);
    final verdict = _buildVerdict(
      scoreInt: scoreInt,
      windContext: windQuality.toLowerCase(),
      bestWindowRange: bestWindowRange,
    );

    // Board quiver (used in VLB for scrubbed board rec)
    final boards = ref.watch(boardsProvider);

    // Forecast summary (1-line for hero subtitle)
    final today = DateTime.now().toIso8601String().split('T')[0];
    final todayHours =
        data.hourly.where((h) => h.time.startsWith(today)).toList();
    final ruleBasedSummary =
        generateForecastSummary(todayHours, prefs, location);

    // Watch LLM summary for crossfade
    final llmState = ref.watch(llmSummaryProvider);
    final rawSummary = llmState.status == AiStatus.loaded && llmState.text != null
        ? llmState.text!
        : ruleBasedSummary;
    final displaySummary = rawSummary.isNotEmpty ? 'Today: $rawSummary' : '';

    // Trigger LLM fetch on first load (one-shot)
    if (llmState.status == AiStatus.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(llmSummaryProvider.notifier).fetch(
              ruleBasedSummary: ruleBasedSummary,
              locationId: location.id,
            );
      });
    }

    // Condition color
    final condColor = _scoreToConditionColor(score);

    // Atmospheric gradient — subtle condition-colored wash
    final bgColor = isDark ? AppColorsDark.bgPrimary : AppColors.bgPrimary;
    final gradientColor = condColor.withValues(alpha: isDark ? 0.03 : 0.02);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.4),
          radius: 0.8,
          colors: [gradientColor, bgColor],
        ),
      ),
      child: RefreshIndicator(
      key: ValueKey('dashboard_${location.id}'),
      color: AppColors.accent,
      onRefresh: () async {
        HapticFeedback.mediumImpact();
        ref.read(llmSummaryProvider.notifier).reset();
        ref.invalidate(conditionsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
        children: [
          // Alert banner
          AlertBanner(
            hourlyData: data.hourly,
            prefs: prefs,
            location: location,
            onTap: widget.onNavigateToForecast,
          ),

          // Discovery hint — contextual tip on first visit
          DiscoveryHint(
            id: 'dashboard_scrub',
            message: 'Drag the hour strip to see conditions change throughout the day.',
            icon: Icons.swipe,
            seenHints: _seenHints,
            onDismiss: (id) {
              _seenHints.add(id);
              ref.read(storeServiceProvider).markHintSeen(id);
            },
          ),

          // ─── HERO + SCRUBBER + CHIPS (reactive to scrub) ───
          ValueListenableBuilder<int?>(
            valueListenable: _scrubNotifier,
            builder: (context, scrubIdx, _) {
              // If scrubbing, recompute from that hour; else use current
              final isActive = scrubIdx != null &&
                  scrubIdx >= 0 &&
                  scrubIdx < data.hourly.length;
              final hData = isActive ? data.hourly[scrubIdx] : currentHour;
              final hBreakdown = computeMatchScoreBreakdown(
                  hData, prefs, location,
                  tideRange: tideRange);
              final hScore = hBreakdown.finalScore;
              final hScoreInt = (hScore * 100).round();
              final hCondLabel = getConditionLabel(hScore);
              final hCondColor = _scoreToConditionColor(hScore);

              // Factor summaries for breakdown UI
              final hFactors = buildFactorSummaries(hBreakdown);

              // Wind for scrubbed hour
              final hWindDir = hData?.windDirection;
              final hWindDirLabel =
                  hWindDir != null ? degreesToCardinal(hWindDir) : '--';
              final hWindQuality = hWindDir != null
                  ? (isOffshoreWind(hWindDir, location)
                      ? 'Offshore'
                      : isOnshoreWind(hWindDir, location)
                          ? 'Onshore'
                          : 'Cross-shore')
                  : '';
              // Verdict for scrubbed hour
              final hVerdict = isActive
                  ? _buildScrubVerdict(hScoreInt, hWindQuality.toLowerCase(), hData!)
                  : verdict;

              // Board rec for scrubbed hour
              final hBoardRec = boards.isNotEmpty
                  ? recommendBoard(
                      boards,
                      BoardConditions(
                        waveHeight: hData?.waveHeight,
                        windSpeed: hData?.windSpeed,
                        wavePeriod: hData?.wavePeriod,
                        swellPeriod: hData?.swellPeriod,
                      ),
                    )
                  : null;

              // Factor references for chips
              final waveFactor = hFactors.where((f) => f.name == 'Waves').firstOrNull;
              final windFactor = hFactors.where((f) => f.name == 'Wind').firstOrNull;

              // Forecast accuracy for breakdown sheet
              final sessions = ref.read(sessionsProvider);
              final accuracy = computeForecastAccuracy(sessions);

              void openBreakdown() {
                final now = DateTime.now();
                if (_lastSheetOpen != null &&
                    now.difference(_lastSheetOpen!).inMilliseconds < 500) {
                  return;
                }
                _lastSheetOpen = now;
                AppHaptics.tap();
                showScoreBreakdown(
                  context,
                  breakdown: hBreakdown,
                  factors: hFactors,
                  isDark: isDark,
                  onAskTheCall: _openTheCall,
                  scrubNotifier: _scrubNotifier,
                  hourlyData: data.hourly,
                  currentHour: currentHour,
                  prefs: prefs,
                  location: location,
                  tideRange: tideRange,
                  accuracy: accuracy,
                );
              }

              return Column(
                children: [
                  // ─── HERO BLOCK ───
                  _HeroBlock(
                    score: hScore,
                    scoreInt: hScoreInt,
                    condLabel: hCondLabel,
                    condColor: hCondColor,
                    verdict: hVerdict,
                    bestWindow: isActive ? null : bestWindow,
                    bestWindowRange: isActive ? '' : bestWindowRange,
                    boardRec: hBoardRec,
                    forecastNarrative: isActive ? null : displaySummary,
                    scrubTime: isActive ? _formatScrubTime(hData!) : null,
                    activeCaps: hBreakdown.activeCaps,
                    isDark: isDark,
                    onScoreTap: openBreakdown,
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  // ─── REASON CHIPS ───
                  GestureDetector(
                    onTap: openBreakdown,
                    child: _ReasonChips(
                      surfFactor: waveFactor,
                      windFactor: windFactor,
                      waveHeight: hData?.waveHeight,
                      wavePeriod: hData?.wavePeriod ?? hData?.swellPeriod,
                      windSpeed: hData?.windSpeed,
                      windDirLabel: hWindDirLabel,
                      isDark: isDark,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: AppSpacing.s3),

          // ─── HOURLY SCRUB STRIP ───
          _HourlyScrubStrip(
            hourlyData: data.hourly,
            prefs: prefs,
            location: location,
            tideRange: tideRange,
            currentHourIdx: nowIdx,
            bestWindow: bestWindow,
            scrubNotifier: _scrubNotifier,
            isDark: isDark,
          ),

          const SizedBox(height: AppSpacing.s4),

          // ─── COMPACT CTA ───
          _AskTheCallCta(
            isDark: isDark,
            onTap: _openTheCall,
          ),

          const SizedBox(height: AppSpacing.s8),
        ],
      ),
    ),
    );
  }

  Widget _buildSkeleton(bool isDark) {
    return Shimmer(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.s4),
            const ShimmerBox(height: 140, radius: AppRadius.lg),
            const SizedBox(height: AppSpacing.s4),
            Row(
              children: List.generate(
                3,
                (_) => const Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: ShimmerBox(height: 48),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s6),
            const ShimmerBox(height: 14, width: 240, radius: AppRadius.sm),
            const SizedBox(height: AppSpacing.s2),
            const ShimmerBox(height: 14, width: 180, radius: AppRadius.sm),
            const SizedBox(height: AppSpacing.s6),
            Row(
              children: List.generate(
                3,
                (_) => const Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: ShimmerBox(height: 80),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(Object error, bool isDark) {
    final isOffline = error.toString().contains('SocketException') ||
        error.toString().contains('NetworkException') ||
        error.toString().contains('Failed host lookup');
    final icon = isOffline ? Icons.wifi_off_rounded : Icons.cloud_off_rounded;
    final title = isOffline ? 'You\'re offline' : 'Couldn\'t load conditions';
    final subtitle = isOffline
        ? 'Connect to the internet and we\'ll grab the latest forecast.'
        : 'The forecast server didn\'t respond. Try again in a moment.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.conditionFair),
            const SizedBox(height: AppSpacing.s4),
            Text(
              title,
              style: TextStyle(
                fontSize: AppTypography.textBase,
                fontWeight: AppTypography.weightSemibold,
                color: isDark
                    ? AppColorsDark.textPrimary
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.s2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTypography.textSm,
                color: isDark
                    ? AppColorsDark.textSecondary
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.s5),
            ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.invalidate(conditionsProvider);
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ───

  void _openTheCall() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: isDark ? AppColorsDark.bgSecondary : AppColors.bgSecondary,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: const TheCallCard(),
      ),
    );
  }

  String _formatBestWindowRange(TopWindow? window) {
    if (window == null) return '';
    final startDt = DateTime.parse(window.startTime);
    final endDt = DateTime.parse(window.endTime);
    return '${_fmtHour(startDt)}\u2013${_fmtHour(endDt)}';
  }

  static String _fmtHour(DateTime dt) {
    final h = dt.hour;
    if (h == 0) return '12am';
    if (h < 12) return '${h}am';
    if (h == 12) return '12pm';
    return '${h - 12}pm';
  }

  String _buildScrubVerdict(int scoreInt, String windContext, HourlyData h) {
    if (scoreInt >= 80) return 'Epic conditions';
    if (scoreInt >= 60) {
      if (windContext == 'offshore') return 'Clean and surfable';
      return 'Worth paddling out';
    }
    if (scoreInt >= 40) return 'Marginal conditions';
    return 'Not worth it';
  }

  String _formatScrubTime(HourlyData h) {
    final dt = DateTime.parse(h.time);
    final hour = dt.hour;
    final ampm = hour < 12 ? 'am' : 'pm';
    final display = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final hDay = DateTime(dt.year, dt.month, dt.day);
    String dayLabel;
    if (hDay == today) {
      dayLabel = 'Today';
    } else if (hDay == today.add(const Duration(days: 1))) {
      dayLabel = 'Tomorrow';
    } else {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      dayLabel = days[dt.weekday - 1];
    }
    return '$dayLabel $display$ampm';
  }

  String _buildVerdict({
    required int scoreInt,
    required String windContext,
    required String bestWindowRange,
  }) {
    if (scoreInt >= 80) return 'Get out there';
    if (scoreInt >= 60) {
      if (windContext == 'offshore') return 'Clean and worth it';
      if (bestWindowRange.isNotEmpty) return 'Go at $bestWindowRange';
      return 'Worth a paddle';
    }
    if (scoreInt >= 40) {
      if (bestWindowRange.isNotEmpty) return 'Wait for $bestWindowRange';
      return 'Marginal, maybe skip';
    }
    return 'Give it a miss';
  }

}

// ─── Static helpers ───

Color _scoreToConditionColor(double score) {
  if (score >= 0.8) return AppColors.conditionEpic;
  if (score >= 0.6) return AppColors.conditionGood;
  if (score >= 0.4) return AppColors.conditionFair;
  return AppColors.conditionPoor;
}

// =============================================================================
// HERO BLOCK — Text-led: verdict dominant, mini ScoreRing top-right
// =============================================================================

class _HeroBlock extends StatelessWidget {
  final double score;
  final int scoreInt;
  final ConditionLabel condLabel;
  final Color condColor;
  final String verdict;
  final TopWindow? bestWindow;
  final String bestWindowRange;
  final BoardRecommendation? boardRec;
  final String? forecastNarrative;
  final String? scrubTime;
  final List<HardCap> activeCaps;
  final bool isDark;
  final VoidCallback? onScoreTap;

  const _HeroBlock({
    required this.score,
    required this.scoreInt,
    required this.condLabel,
    required this.condColor,
    required this.verdict,
    required this.bestWindowRange,
    this.bestWindow,
    this.boardRec,
    this.forecastNarrative,
    this.scrubTime,
    this.activeCaps = const [],
    required this.isDark,
    this.onScoreTap,
  });

  String get _semanticLabel {
    final parts = <String>['Score $scoreInt. $verdict. ${condLabel.label}.'];
    if (scrubTime != null) parts.insert(0, 'Showing $scrubTime.');
    if (bestWindowRange.isNotEmpty) parts.add('Best window $bestWindowRange.');
    if (boardRec != null) {
      parts.add('Board: ${boardRec!.board.name.isNotEmpty ? boardRec!.board.name : boardRec!.board.type}.');
    }
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColorsDark.bgSecondary : AppColors.bgSecondary;
    final textColor = isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final subColor = isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;

    // Best window day + wave label
    String? bestWindowLine;
    if (bestWindow != null && bestWindowRange.isNotEmpty) {
      final windowDate = DateTime.parse(bestWindow!.startTime);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final windowDay = DateTime(windowDate.year, windowDate.month, windowDate.day);
      String dayLabel;
      if (windowDay == today) {
        dayLabel = 'Today';
      } else if (windowDay == today.add(const Duration(days: 1))) {
        dayLabel = 'Tomorrow';
      } else {
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        dayLabel = days[windowDate.weekday - 1];
      }
      final wavePart = bestWindow!.waveHeight != null
          ? ' \u00b7 ${formatWaveHeight(bestWindow!.waveHeight)}ft'
          : '';
      bestWindowLine = '$dayLabel $bestWindowRange$wavePart';
    }

    final boardName = boardRec != null
        ? (boardRec!.board.name.isNotEmpty ? boardRec!.board.name : boardRec!.board.type)
        : null;
    final boardLine = boardName != null
        ? '$boardName${boardRec!.reason.isNotEmpty ? ' \u2014 ${boardRec!.reason}' : ''}'
        : null;

    return Semantics(
      label: _semanticLabel,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s5,
          vertical: AppSpacing.s4,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Scrub time pill
            if (scrubTime != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s2),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: condColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time, size: 12, color: condColor),
                      const SizedBox(width: 4),
                      Text(
                        'Previewing $scrubTime',
                        style: TextStyle(
                          fontSize: AppTypography.textXs,
                          fontWeight: AppTypography.weightSemibold,
                          color: condColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Main row: verdict + details left, mini ScoreRing right
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Verdict — DOMINANT
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        child: Text(
                          verdict,
                          key: ValueKey(verdict),
                          style: TextStyle(
                            fontSize: AppTypography.textHero,
                            fontWeight: AppTypography.weightBold,
                            color: textColor,
                            height: 1.15,
                          ),
                        ),
                      ),
                      // Best window line
                      if (bestWindowLine != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            bestWindowLine,
                            style: TextStyle(
                              fontSize: AppTypography.textSm,
                              color: subColor,
                            ),
                          ),
                        ),
                      // Board rec
                      if (boardLine != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            boardLine,
                            style: TextStyle(
                              fontSize: AppTypography.textSm,
                              color: subColor,
                            ),
                          ),
                        ),
                      // Hard cap warning
                      if (activeCaps.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            hardCapSummary(activeCaps),
                            style: TextStyle(
                              fontSize: AppTypography.textXs,
                              color: AppColors.conditionPoor,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s3),
                // Right: mini ScoreRing
                GestureDetector(
                  onTap: onScoreTap,
                  child: ScoreRing(score: score, size: 48, compact: true),
                ),
              ],
            ),

            // Forecast narrative (LLM crossfade, hidden during scrub)
            if (scrubTime == null && forecastNarrative != null && forecastNarrative!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.s3),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    forecastNarrative!,
                    key: ValueKey(forecastNarrative),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppTypography.textSm,
                      color: subColor,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// HOURLY SCRUB STRIP
// =============================================================================

class _HourlyScrubStrip extends StatefulWidget {
  final List<HourlyData> hourlyData;
  final UserPrefs prefs;
  final Location location;
  final TideRange? tideRange;
  final int currentHourIdx;
  final TopWindow? bestWindow;
  final ValueNotifier<int?> scrubNotifier;
  final bool isDark;

  const _HourlyScrubStrip({
    required this.hourlyData,
    required this.prefs,
    required this.location,
    required this.tideRange,
    required this.currentHourIdx,
    required this.bestWindow,
    required this.scrubNotifier,
    required this.isDark,
  });

  @override
  State<_HourlyScrubStrip> createState() => _HourlyScrubStripState();
}

class _HourlyScrubStripState extends State<_HourlyScrubStrip>
    with SingleTickerProviderStateMixin {
  int? _activeIdx;
  int? _lastHapticIdx;
  late AnimationController _lockedBorderController;

  // Filter to today's daylight hours (6am–9pm)
  late List<_StripEntry> _entries;

  @override
  void initState() {
    super.initState();
    _lockedBorderController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _buildEntries();
  }

  @override
  void didUpdateWidget(_HourlyScrubStrip old) {
    super.didUpdateWidget(old);
    if (old.hourlyData != widget.hourlyData) _buildEntries();
  }

  @override
  void dispose() {
    _lockedBorderController.dispose();
    super.dispose();
  }

  void _buildEntries() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Show today + tomorrow (up to 36 hours)
    final cutoff = today.add(const Duration(hours: 48));

    _entries = [];
    for (var i = 0; i < widget.hourlyData.length; i++) {
      final h = widget.hourlyData[i];
      final dt = DateTime.parse(h.time);
      if (dt.isBefore(today.add(const Duration(hours: 6)))) continue;
      if (dt.isAfter(cutoff)) break;
      final hour = dt.hour;
      if (hour < 6 || hour > 20) continue;

      final score = computeMatchScore(
          h, widget.prefs, widget.location,
          tideRange: widget.tideRange);
      _entries.add(_StripEntry(
        globalIdx: i,
        hour: hour,
        day: DateTime(dt.year, dt.month, dt.day),
        score: score,
        isNow: i == widget.currentHourIdx,
        isBestWindow: _isInBestWindow(h.time),
      ));
    }
  }

  bool _isInBestWindow(String time) {
    if (widget.bestWindow == null) return false;
    final t = DateTime.parse(time);
    final start = DateTime.parse(widget.bestWindow!.startTime);
    final end = DateTime.parse(widget.bestWindow!.endTime);
    return !t.isBefore(start) && !t.isAfter(end);
  }

  void _onDragUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (_entries.isEmpty) return;
    final dx = details.localPosition.dx.clamp(0.0, constraints.maxWidth);
    final idx = (dx / constraints.maxWidth * _entries.length)
        .floor()
        .clamp(0, _entries.length - 1);

    if (idx != _activeIdx) {
      setState(() => _activeIdx = idx);
      widget.scrubNotifier.value = _entries[idx].globalIdx;

      // FL-DR-3d: Haptic on every bar + stronger at best window boundary
      if (_lastHapticIdx != null) {
        final wasBest = _entries[_lastHapticIdx!].isBestWindow;
        final isBest = _entries[idx].isBestWindow;
        if (wasBest != isBest) {
          HapticFeedback.mediumImpact();
        } else {
          HapticFeedback.selectionClick();
        }
      } else {
        HapticFeedback.selectionClick();
      }
      _lastHapticIdx = idx;
    }
  }

  void _onDragEnd() {
    // Keep selection persistent — user taps "Now" to reset
    _lastHapticIdx = null;
    _lockedBorderController.forward();
  }

  void _resetToNow() {
    _lockedBorderController.reverse();
    setState(() => _activeIdx = null);
    widget.scrubNotifier.value = null;
    _lastHapticIdx = null;
    HapticFeedback.lightImpact();
  }

  static Color _barColor(double score) {
    if (score >= 0.8) return AppColors.conditionEpic;
    if (score >= 0.6) return AppColors.conditionGood;
    if (score >= 0.4) return AppColors.conditionFair;
    return AppColors.conditionPoor;
  }

  @override
  Widget build(BuildContext context) {
    if (_entries.isEmpty) return const SizedBox.shrink();

    final bg = widget.isDark
        ? AppColorsDark.bgSecondary
        : AppColors.bgSecondary;
    final subColor = widget.isDark
        ? AppColorsDark.textTertiary
        : AppColors.textTertiary;

    final isLocked = _activeIdx != null;

    // Locked bar color for bottom border
    final lockedColor = isLocked && _activeIdx! < _entries.length
        ? _barColor(_entries[_activeIdx!].score)
        : AppColors.accent;

    return Semantics(
      label: 'Hourly surf conditions. Drag to explore different hours.',
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _lockedBorderController,
            builder: (context, child) => Container(
              height: 84,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: AppShadows.sm,
                border: _lockedBorderController.value > 0
                    ? Border(
                        bottom: BorderSide(
                          color: lockedColor.withValues(alpha: 0.6 * _lockedBorderController.value),
                          width: 2 * _lockedBorderController.value,
                        ),
                      )
                    : null,
              ),
              child: child,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onHorizontalDragStart: (d) =>
                      _onDragUpdate(DragUpdateDetails(
                        globalPosition: d.globalPosition,
                        localPosition: d.localPosition,
                      ), constraints),
                  onHorizontalDragUpdate: (d) =>
                      _onDragUpdate(d, constraints),
                  onHorizontalDragEnd: (_) => _onDragEnd(),
                  onHorizontalDragCancel: _onDragEnd,
                  onTapDown: (d) {
                    _onDragUpdate(DragUpdateDetails(
                      globalPosition: d.globalPosition,
                      localPosition: d.localPosition,
                    ), constraints);
                  },
                  onTapUp: (_) => _onDragEnd(),
                  behavior: HitTestBehavior.opaque,
                  child: CustomPaint(
                    size: Size(constraints.maxWidth, 84),
                    painter: _StripPainter(
                      entries: _entries,
                      activeIdx: _activeIdx,
                      isDark: widget.isDark,
                      subColor: subColor,
                    ),
                  ),
                );
              },
            ),
          ),
          // "Now" reset button — visible when a selection is locked
          if (isLocked)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s2),
              child: GestureDetector(
                onTap: _resetToNow,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: (widget.isDark ? AppColorsDark.bgTertiary : AppColors.bgTertiary),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.my_location, size: 12,
                          color: widget.isDark ? AppColorsDark.textSecondary : AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        'Back to now',
                        style: TextStyle(
                          fontSize: AppTypography.textXs,
                          fontWeight: AppTypography.weightMedium,
                          color: widget.isDark ? AppColorsDark.textSecondary : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StripEntry {
  final int globalIdx;
  final int hour;
  final DateTime day;
  final double score;
  final bool isNow;
  final bool isBestWindow;

  const _StripEntry({
    required this.globalIdx,
    required this.hour,
    required this.day,
    required this.score,
    required this.isNow,
    required this.isBestWindow,
  });
}

class _StripPainter extends CustomPainter {
  final List<_StripEntry> entries;
  final int? activeIdx;
  final bool isDark;
  final Color subColor;

  _StripPainter({
    required this.entries,
    required this.activeIdx,
    required this.isDark,
    required this.subColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.isEmpty) return;

    final barWidth = size.width / entries.length;
    const labelHeight = 16.0;
    final maxBarHeight = size.height - labelHeight - 8;
    const barTop = 6.0;
    final textPrimary = isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;

    // ── Best window bracket (top bracket instead of background wash) ──
    int? bwStart;
    int? bwEnd;
    for (var i = 0; i < entries.length; i++) {
      if (entries[i].isBestWindow) {
        bwStart ??= i;
        bwEnd = i;
      }
    }
    if (bwStart != null && bwEnd != null) {
      final bracketPaint = Paint()
        ..color = AppColors.accent.withValues(alpha: 0.6)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      final bx1 = bwStart * barWidth;
      final bx2 = (bwEnd + 1) * barWidth;
      const tickH = 5.0;
      // Top line
      canvas.drawLine(Offset(bx1, 1), Offset(bx2, 1), bracketPaint);
      // Left tick
      canvas.drawLine(Offset(bx1, 1), Offset(bx1, 1 + tickH), bracketPaint);
      // Right tick
      canvas.drawLine(Offset(bx2, 1), Offset(bx2, 1 + tickH), bracketPaint);
    }

    // ── Day separator ──
    DateTime? prevDay;
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      if (prevDay != null && e.day != prevDay) {
        // Draw dashed line at boundary
        final sx = i * barWidth;
        final sepPaint = Paint()
          ..color = subColor.withValues(alpha: 0.4)
          ..strokeWidth = 1.0;
        // Simple dashed line
        for (var dy = barTop; dy < size.height - labelHeight; dy += 6) {
          canvas.drawLine(
            Offset(sx, dy),
            Offset(sx, (dy + 3).clamp(0, size.height - labelHeight)),
            sepPaint,
          );
        }
        // "Tomorrow" label
        final tomorrowTp = TextPainter(
          text: TextSpan(
            text: 'Tomorrow',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w500,
              color: subColor.withValues(alpha: 0.6),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tomorrowTp.paint(canvas,
            Offset(sx + 2, size.height - labelHeight + 2));
      }
      prevDay = e.day;
    }

    // ── Draw bars with gradient fill ──
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      final x = i * barWidth;
      final barH = maxBarHeight * e.score.clamp(0.05, 1.0);
      final y = barTop + (maxBarHeight - barH);
      final color = _barColor(e.score);
      final isActive = activeIdx == i;

      // Alpha based on state
      double alpha;
      if (isActive) {
        alpha = 1.0;
      } else if (e.isNow && activeIdx == null) {
        alpha = 0.9;
      } else if (activeIdx != null && (i - activeIdx!).abs() <= 1) {
        alpha = 0.7;
      } else {
        alpha = 0.45;
      }

      // Gradient bar: condition color at bottom → transparent at top
      final barRect = Rect.fromLTWH(
        x + barWidth * 0.15,
        y,
        barWidth * 0.7,
        barH,
      );
      final rrect = RRect.fromRectAndCorners(
        barRect,
        topLeft: const Radius.circular(3),
        topRight: const Radius.circular(3),
      );
      final gradient = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          color.withValues(alpha: alpha),
          color.withValues(alpha: alpha * 0.2),
        ],
      );
      canvas.save();
      canvas.clipRRect(rrect);
      canvas.drawRect(barRect, Paint()..shader = gradient.createShader(barRect));
      canvas.restore();

      // Active bar: glow + solid fill + floating score bubble
      if (isActive) {
        // Outer glow
        final glowRect = RRect.fromRectAndCorners(
          Rect.fromLTWH(x + barWidth * 0.02, y - 4, barWidth * 0.96, barH + 4),
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        );
        canvas.drawRRect(glowRect, Paint()..color = color.withValues(alpha: 0.18));
        // Solid fill on top
        final solidRect = RRect.fromRectAndCorners(
          Rect.fromLTWH(x + barWidth * 0.08, y - 2, barWidth * 0.84, barH + 2),
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        );
        canvas.drawRRect(solidRect, Paint()..color = color);

        // Floating score bubble above bar
        final scoreLabel = '${(e.score * 100).round()}';
        final scoreTp = TextPainter(
          text: TextSpan(
            text: scoreLabel,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFFFFFFFF),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final bubbleW = scoreTp.width + 8;
        final bubbleH = scoreTp.height + 4;
        final bubbleX = x + barWidth / 2 - bubbleW / 2;
        final bubbleY = (y - bubbleH - 5).clamp(0.0, barTop);
        // Bubble background
        final bubbleRRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(bubbleX, bubbleY, bubbleW, bubbleH),
          const Radius.circular(4),
        );
        canvas.drawRRect(bubbleRRect, Paint()..color = color.withValues(alpha: 0.9));
        scoreTp.paint(canvas, Offset(bubbleX + 4, bubbleY + 2));
        // Stem connecting bubble to bar
        canvas.drawLine(
          Offset(x + barWidth / 2, bubbleY + bubbleH),
          Offset(x + barWidth / 2, y),
          Paint()..color = color.withValues(alpha: 0.5)..strokeWidth = 1,
        );
      }

      // Hour labels every 3 hours (skip if day separator "Tomorrow" label is there)
      if (e.hour % 3 == 0) {
        // Check if this is not at a day boundary (to avoid overlap with "Tomorrow")
        final atDayBoundary = i > 0 && entries[i - 1].day != e.day;
        if (!atDayBoundary) {
          final label = _hourLabel(e.hour);
          final tp = TextPainter(
            text: TextSpan(
              text: label,
              style: TextStyle(
                fontSize: 10,
                fontFamily: AppTypography.fontMono,
                color: subColor,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas,
              Offset(x + barWidth / 2 - tp.width / 2, size.height - labelHeight));
        }
      }
    }

    // ── "Now" diamond marker ──
    final nowIdx = entries.indexWhere((e) => e.isNow);
    if (nowIdx >= 0 && activeIdx == null) {
      final nx = nowIdx * barWidth + barWidth / 2;
      final e = entries[nowIdx];
      final barH = maxBarHeight * e.score.clamp(0.05, 1.0);
      final diamondY = barTop + (maxBarHeight - barH) - 1;

      // Diamond shape at bar top
      final diamondPath = Path()
        ..moveTo(nx, diamondY - 6)
        ..lineTo(nx + 4, diamondY - 3)
        ..lineTo(nx, diamondY)
        ..lineTo(nx - 4, diamondY - 3)
        ..close();
      canvas.drawPath(diamondPath, Paint()..color = textPrimary);

      // "now" label below diamond
      final nowTp = TextPainter(
        text: TextSpan(
          text: 'now',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: textPrimary.withValues(alpha: 0.7),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      nowTp.paint(canvas,
          Offset(nx - nowTp.width / 2, size.height - labelHeight));
    }

    // ── Active scrubber line ──
    if (activeIdx != null && activeIdx! < entries.length) {
      final x = activeIdx! * barWidth + barWidth / 2;
      final linePaint = Paint()
        ..color = textPrimary
        ..strokeWidth = 1.5;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height - labelHeight - 2),
        linePaint,
      );
    }
  }

  Color _barColor(double score) {
    if (score >= 0.8) return AppColors.conditionEpic;
    if (score >= 0.6) return AppColors.conditionGood;
    if (score >= 0.4) return AppColors.conditionFair;
    return AppColors.conditionPoor;
  }

  String _hourLabel(int hour) {
    if (hour == 0 || hour == 12) return hour == 0 ? '12a' : '12p';
    return hour < 12 ? '${hour}a' : '${hour - 12}p';
  }

  @override
  bool shouldRepaint(_StripPainter old) =>
      old.activeIdx != activeIdx ||
      old.entries != entries ||
      old.isDark != isDark;
}

// =============================================================================
// REASON CHIPS — 2 data-native chips (waves + wind)
// =============================================================================

class _ReasonChips extends StatelessWidget {
  final FactorSummary? surfFactor;
  final FactorSummary? windFactor;
  final double? waveHeight;
  final double? wavePeriod;
  final double? windSpeed;
  final String windDirLabel;
  final bool isDark;

  const _ReasonChips({
    this.surfFactor,
    this.windFactor,
    required this.waveHeight,
    required this.wavePeriod,
    required this.windSpeed,
    required this.windDirLabel,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColorsDark.bgSecondary : AppColors.bgSecondary;
    final textColor = isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;

    // Wave chip value: "4.3ft · 12s"
    final waveParts = <String>[];
    if (waveHeight != null) waveParts.add('${formatWaveHeight(waveHeight)}ft');
    if (wavePeriod != null) waveParts.add('${wavePeriod!.round()}s');
    final waveValue = waveParts.isNotEmpty ? waveParts.join(' \u00b7 ') : '--';

    // Wind chip value: "10mph SW"
    final windValue = windSpeed != null
        ? '${formatWindSpeed(windSpeed)}mph${windDirLabel != '--' ? ' $windDirLabel' : ''}'
        : '--';

    return Row(
      children: [
        Expanded(
          child: _chip(
            bg: bg,
            dotColor: surfFactor != null ? statusColor(surfFactor!.status, isDark) : null,
            value: waveValue,
            textColor: textColor,
          ),
        ),
        const SizedBox(width: AppSpacing.s2),
        Expanded(
          child: _chip(
            bg: bg,
            dotColor: windFactor != null ? statusColor(windFactor!.status, isDark) : null,
            value: windValue,
            textColor: textColor,
          ),
        ),
        const SizedBox(width: AppSpacing.s1),
        Icon(Icons.chevron_right, size: 14,
            color: isDark ? AppColorsDark.textTertiary : AppColors.textTertiary),
      ],
    );
  }

  Widget _chip({
    required Color bg,
    required Color? dotColor,
    required String value,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s3, vertical: AppSpacing.s2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          if (dotColor != null) ...[
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ],
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: AppTypography.fontMono,
                fontSize: AppTypography.textSm,
                fontWeight: AppTypography.weightMedium,
                color: textColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// COMPACT "ASK THE CALL" CTA
// =============================================================================

class _AskTheCallCta extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _AskTheCallCta({required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accent;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s3),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s4, vertical: AppSpacing.s3,
          ),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: isDark ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: accent.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '\u2728',
                style: TextStyle(fontSize: AppTypography.textBase),
              ),
              const SizedBox(width: AppSpacing.s2),
              Text(
                'Ask The Call',
                style: TextStyle(
                  fontSize: AppTypography.textSm,
                  fontWeight: AppTypography.weightSemibold,
                  color: accent,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios, size: 12, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}

// Removed: _WhyThisScoreCard, _BoardCallCard, _UnifiedConditionsCard,
// _ForecastSummaryBlock, _ExpectedVsPotentialCard, _ScoreFeedbackWidget, _SpringLift,
// _FactorInsight, _ForecastAccuracyBadge
// — content moved to score_breakdown_sheet.dart
