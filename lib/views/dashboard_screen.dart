/// Dashboard screen — decision-first "The Call" hero, reason chips, metrics, AI Q&A
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../theme/tokens.dart';
import '../models/merged_conditions.dart';
import '../models/hourly_data.dart';
import '../models/location.dart';
import '../models/user_prefs.dart';
import '../logic/scoring.dart';
import '../logic/units.dart';
import '../logic/time_utils.dart';
import '../logic/forecast_summary.dart';
import '../logic/board_recommendation.dart';
import '../state/conditions_provider.dart';
import '../state/location_provider.dart';
import '../state/preferences_provider.dart';
import '../state/ai_provider.dart';
import '../state/boards_provider.dart';
import '../components/stale_badge.dart';
import '../components/location_picker.dart';
import '../components/the_call_card.dart';
import '../components/share_card.dart';
import '../components/alert_banner.dart';
import '../components/discovery_hint.dart';
import '../state/subscription_provider.dart';
import '../state/sessions_provider.dart';
import '../state/store_provider.dart';
import '../services/supabase_service.dart';
import '../components/shimmer.dart';

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
            child: Row(
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
    final generalScore = prefs.hasCustomWeights
        ? computeMatchScore(currentHour, prefs, location,
            tideRange: tideRange, weightOverrides: const {})
        : null;
    final scoreInt = (score * 100).round();
    final condLabel = getConditionLabel(score);

    // Best window
    final bestWindow = findBestWindow(data.hourly, prefs, location,
        tideRange: tideRange);

    // Sunrise for best window day
    final bestDate =
        bestWindow?.date ?? DateTime.now().toIso8601String().split('T')[0];
    final sunrise = data.daily
        .where((d) => d.date == bestDate)
        .map((d) => d.sunrise)
        .firstOrNull;

    // Wind direction
    final windDir = current.windDirection;
    final windDirLabel =
        windDir != null ? degreesToCardinal(windDir) : '--';
    final windQuality = windDir != null
        ? (isOffshoreWind(windDir, location)
            ? 'Offshore'
            : isOnshoreWind(windDir, location)
                ? 'Onshore'
                : 'Cross-shore')
        : '';

    // Tide
    final tideLabel = current.tideTrend ?? 'Unknown';
    final waterTempText = current.waterTemp != null
        ? '${formatTemp(current.waterTemp)}°'
        : '';
    final tideSubLabel =
        '$tideLabel${waterTempText.isNotEmpty ? ' · $waterTempText water' : ''}';

    // Verdict + trend (same logic as condition_state_builder)
    final bestWindowRange = _formatBestWindowRange(bestWindow);
    final verdict = _buildVerdict(
      scoreInt: scoreInt,
      windContext: windQuality.toLowerCase(),
      bestWindowRange: bestWindowRange,
    );
    final trend = _computeTrend(data.hourly, prefs, location, tideRange);

    // Board recommendation
    final boards = ref.watch(boardsProvider);
    final boardRec = boards.isNotEmpty
        ? recommendBoard(
            boards,
            BoardConditions(
              waveHeight: current.waveHeight,
              windSpeed: current.windSpeed,
              wavePeriod: current.wavePeriod,
              swellPeriod: currentHour?.swellPeriod,
            ),
          )
        : null;

    // Forecast summary
    final today = DateTime.now().toIso8601String().split('T')[0];
    final todayHours =
        data.hourly.where((h) => h.time.startsWith(today)).toList();
    final ruleBasedSummary =
        generateForecastSummary(todayHours, prefs, location);

    // LLM summary
    final llmState = ref.watch(llmSummaryProvider);
    final isPremium = ref.watch(isPremiumProvider);
    if (isPremium &&
        ruleBasedSummary.isNotEmpty &&
        llmState.status == AiStatus.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(llmSummaryProvider.notifier).fetch(
              ruleBasedSummary: ruleBasedSummary,
              locationId: location.id,
            );
      });
    }

    // Metric dot colors
    final waveDot = _prefDotColor(
      current.waveHeight,
      prefs.minWaveHeight,
      prefs.maxWaveHeight,
    );
    final windDot = current.windSpeed != null && prefs.maxWindSpeed != null
        ? (current.windSpeed! <= prefs.maxWindSpeed!
            ? (windDir != null && isOffshoreWind(windDir, location)
                ? AppColors.conditionEpic
                : AppColors.conditionFair)
            : AppColors.conditionPoor)
        : null;

    // Condition color
    final condColor = _scoreToConditionColor(score);

    // Atmospheric gradient — subtle condition-colored wash
    final bgColor = isDark ? AppColorsDark.bgPrimary : AppColors.bgPrimary;
    final gradientColor = condColor.withValues(alpha: isDark ? 0.04 : 0.03);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.6),
          radius: 1.2,
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

          // Stale badge
          if (data.isStale || (dataAge != null && dataAge >= 15))
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s3),
              child: StaleBadge(
                ageMinutes: dataAge,
                isStale: data.isStale,
                onRefresh: () => ref.invalidate(conditionsProvider),
              ),
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
              final hData = isActive ? data.hourly[scrubIdx!] : currentHour;
              final hScore = computeMatchScore(hData, prefs, location,
                  tideRange: tideRange);
              final hScoreInt = (hScore * 100).round();
              final hCondLabel = getConditionLabel(hScore);
              final hCondColor = _scoreToConditionColor(hScore);
              final hGeneralScore = prefs.hasCustomWeights
                  ? computeMatchScore(hData, prefs, location,
                      tideRange: tideRange, weightOverrides: const {})
                  : null;

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
              final hTideLabel = isActive
                  ? (hData!.tideHeight != null
                      ? (hData.tideHeight! > (current.tideHeight ?? 0)
                          ? 'Rising'
                          : 'Falling')
                      : 'Tide')
                  : tideLabel;

              // Verdict for scrubbed hour
              final hVerdict = isActive
                  ? _buildScrubVerdict(hScoreInt, hWindQuality.toLowerCase(), hData!)
                  : verdict;
              final hTrend = isActive ? '' : trend;

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

              // Dot colors for scrubbed hour
              final hWaveDot = _prefDotColor(
                hData?.waveHeight,
                prefs.minWaveHeight,
                prefs.maxWaveHeight,
              );
              final hWindDot =
                  hData?.windSpeed != null && prefs.maxWindSpeed != null
                      ? (hData!.windSpeed! <= prefs.maxWindSpeed!
                          ? (hWindDir != null &&
                                  isOffshoreWind(hWindDir, location)
                              ? AppColors.conditionEpic
                              : AppColors.conditionFair)
                          : AppColors.conditionPoor)
                      : null;

              return Column(
                children: [
                  // Decision card
                  AnimatedContainer(
                    duration: AppDurations.base,
                    curve: Curves.easeOut,
                    child: _DecisionCard(
                      verdict: hVerdict,
                      scoreInt: hScoreInt,
                      condLabel: hCondLabel,
                      condColor: hCondColor,
                      trend: hTrend,
                      bestWindow: isActive ? null : bestWindow,
                      bestWindowRange: isActive ? '' : bestWindowRange,
                      boardRec: hBoardRec,
                      generalScore: hGeneralScore,
                      isDark: isDark,
                      scrubTime: isActive ? _formatScrubTime(hData!) : null,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  // Reason chips
                  _ReasonChips(
                    waveHeight: hData?.waveHeight,
                    wavePeriod: hData?.wavePeriod ?? hData?.swellPeriod,
                    windSpeed: hData?.windSpeed,
                    windQuality: hWindQuality,
                    windDirLabel: hWindDirLabel,
                    tideLabel: hTideLabel,
                    tideHeight: hData?.tideHeight,
                    waveDot: hWaveDot,
                    windDot: hWindDot,
                    isDark: isDark,
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

          // ─── FORECAST SUMMARY ───
          if (ruleBasedSummary.isNotEmpty)
            _ForecastSummaryBlock(
              ruleBasedSummary: ruleBasedSummary,
              llmState: llmState,
              confidence: currentHour != null
                  ? computeConfidence(data.hourly, currentHour)
                  : null,
              isDark: isDark,
            ),

          // ─── EXPECTED VS POTENTIAL ───
          Builder(builder: (context) {
            final evp = computeExpectedVsPotential(data.hourly, prefs,
                location,
                tideRange: tideRange);
            if (evp == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s4),
              child:
                  _ExpectedVsPotentialCard(evp: evp, isDark: isDark),
            );
          }),

          // ─── UNIFIED CONDITIONS CARD ───
          _SpringLift(
            child: _UnifiedConditionsCard(
              waveHeight: current.waveHeight,
              waveDir: current.waveDirection,
              wavePeriod: current.wavePeriod,
              windSpeed: current.windSpeed,
              windDirLabel: windDirLabel,
              windQuality: windQuality,
              tideHeight: current.tideHeight,
              tideLabel: tideLabel,
              waterTemp: current.waterTemp,
              waveDot: waveDot,
              windDot: windDot,
              isDark: isDark,
            ),
          ),
          const SizedBox(height: AppSpacing.s3),

          // ─── WHY THIS SCORE ───
          _SpringLift(
            child: _WhyThisScoreCard(
              waveHeight: current.waveHeight,
              wavePeriod: current.wavePeriod,
              windSpeed: current.windSpeed,
              windQuality: windQuality,
              tideLabel: tideLabel,
              prefs: prefs,
              location: location,
              bestWindowRange: bestWindowRange,
              isDark: isDark,
            ),
          ),

          // ─── BOARD CALL ───
          if (boardRec != null)
            _SpringLift(
              child: _BoardCallCard(
                boardRec: boardRec!,
                isDark: isDark,
              ),
            ),

          const SizedBox(height: AppSpacing.s4),

          // Forecast accuracy
          Builder(builder: (context) {
            final sessions = ref.watch(sessionsProvider);
            final accuracy = computeForecastAccuracy(sessions);
            if (accuracy == null) return const SizedBox.shrink();
            return _ForecastAccuracyBadge(accuracy: accuracy);
          }),

          // The Call — interactive AI Q&A
          const TheCallCard(),

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

  String _computeTrend(List<HourlyData> hourly, UserPrefs prefs,
      Location location, TideRange? tideRange) {
    final now = DateTime.now();
    final upcoming = <double>[];
    double? currentScore;
    for (final h in hourly) {
      final t = DateTime.parse(h.time);
      if (t.isBefore(now.subtract(const Duration(minutes: 30)))) continue;
      final s =
          computeMatchScore(h, prefs, location, tideRange: tideRange);
      if (currentScore == null) {
        currentScore = s;
        continue;
      }
      upcoming.add(s);
      if (upcoming.length >= 3) break;
    }
    if (currentScore == null || upcoming.isEmpty) return '\u2192';
    final avgUpcoming = upcoming.reduce((a, b) => a + b) / upcoming.length;
    final delta = ((avgUpcoming - currentScore) * 100).round();
    if (delta >= 5) return '\u2191';
    if (delta <= -5) return '\u2193';
    return '\u2192';
  }
}

// ─── Static helpers ───

Color _scoreToConditionColor(double score) {
  if (score >= 0.8) return AppColors.conditionEpic;
  if (score >= 0.6) return AppColors.conditionGood;
  if (score >= 0.4) return AppColors.conditionFair;
  return AppColors.conditionPoor;
}

Color? _prefDotColor(double? value, double? min, double? max) {
  if (value == null || min == null || max == null) return null;
  if (value >= min && value <= max) return AppColors.conditionEpic;
  final dist = value < min ? min - value : value - max;
  if (dist < max * 0.3) return AppColors.conditionFair;
  return AppColors.conditionPoor;
}

// =============================================================================
// HERO: Decision Card
// =============================================================================

class _DecisionCard extends StatelessWidget {
  final String verdict;
  final int scoreInt;
  final ConditionLabel condLabel;
  final Color condColor;
  final String trend;
  final TopWindow? bestWindow;
  final String bestWindowRange;
  final BoardRecommendation? boardRec;
  final double? generalScore;
  final bool isDark;
  final String? scrubTime;

  const _DecisionCard({
    required this.verdict,
    required this.scoreInt,
    required this.condLabel,
    required this.condColor,
    required this.trend,
    required this.bestWindow,
    required this.bestWindowRange,
    required this.boardRec,
    required this.generalScore,
    required this.isDark,
    this.scrubTime,
  });

  String get _semanticLabel {
    final parts = <String>['The Call. $verdict. ${condLabel.label} now.'];
    if (scrubTime != null) parts.insert(0, 'Showing $scrubTime.');
    if (bestWindowRange.isNotEmpty) {
      parts.add('Best window ${bestWindow != null ? '' : ''}$bestWindowRange.');
    }
    if (boardRec != null) {
      parts.add('Bring your ${boardRec!.board.name.isNotEmpty ? boardRec!.board.name : boardRec!.board.type}.');
    }
    parts.add('Score $scoreInt.');
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColorsDark.bgSecondary : AppColors.bgSecondary;
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final subColor =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;

    // Best window day label
    String? bestWindowDay;
    if (bestWindow != null) {
      final windowDate = DateTime.parse(bestWindow!.startTime);
      final now = DateTime.now();
      final today =
          DateTime(now.year, now.month, now.day);
      final windowDay =
          DateTime(windowDate.year, windowDate.month, windowDate.day);
      if (windowDay == today) {
        bestWindowDay = 'Today';
      } else if (windowDay == today.add(const Duration(days: 1))) {
        bestWindowDay = 'Tomorrow';
      } else {
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        bestWindowDay = days[windowDate.weekday - 1];
      }
    }

    return Semantics(
      label: _semanticLabel,
      child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: condColor.withValues(alpha: 0.15),
        ),
        boxShadow: [
          // Hero tier: elevated with condition-colored shadow
          BoxShadow(
            offset: const Offset(0, 4),
            blurRadius: 20,
            color: condColor.withValues(alpha: isDark ? 0.15 : 0.10),
          ),
          const BoxShadow(
            offset: Offset(0, 1),
            blurRadius: 4,
            color: Color(0x0A000000),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Scrub time indicator
          if (scrubTime != null) ...[
            Row(
              children: [
                Icon(Icons.access_time, size: 12, color: condColor),
                const SizedBox(width: 4),
                Text(
                  scrubTime!,
                  style: TextStyle(
                    fontSize: AppTypography.textXs,
                    fontWeight: AppTypography.weightSemibold,
                    color: condColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],

          // Row: Verdict + Score badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Verdict headline — crossfades on scrub
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) =>
                          FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.1),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: Text(
                        verdict,
                        key: ValueKey(verdict),
                        style: TextStyle(
                          fontSize: AppTypography.text2xl,
                          fontWeight: AppTypography.weightBold,
                          color: textColor,
                          height: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Condition + trend
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: condColor.withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            condLabel.label,
                            style: TextStyle(
                              fontSize: AppTypography.textXs,
                              fontWeight: AppTypography.weightSemibold,
                              color: condColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          trend,
                          style: TextStyle(
                            fontSize: AppTypography.textSm,
                            color: condColor,
                          ),
                        ),
                        if (generalScore != null) ...[
                          const SizedBox(width: AppSpacing.s2),
                          Text(
                            '\u00b7 General: ${(generalScore! * 100).round()}',
                            style: TextStyle(
                              fontSize: AppTypography.textXs,
                              color: isDark
                                  ? AppColorsDark.textTertiary
                                  : AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Score badge
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: scoreInt),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOut,
                builder: (context, value, _) => Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: condColor.withValues(alpha: 0.3),
                      width: 3,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$value',
                      style: TextStyle(
                        fontFamily: AppTypography.fontMono,
                        fontSize: AppTypography.textLg,
                        fontWeight: AppTypography.weightBold,
                        color: condColor,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.s3),

          // Best window
          if (bestWindowRange.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.schedule, size: 14, color: subColor),
                const SizedBox(width: 6),
                Text(
                  'Best window: ',
                  style: TextStyle(
                    fontSize: AppTypography.textSm,
                    color: subColor,
                  ),
                ),
                Text(
                  '${bestWindowDay ?? ''} $bestWindowRange',
                  style: TextStyle(
                    fontSize: AppTypography.textSm,
                    fontWeight: AppTypography.weightSemibold,
                    color: textColor,
                  ),
                ),
                if (bestWindow?.waveHeight != null) ...[
                  Text(
                    ' \u00b7 ${formatWaveHeight(bestWindow!.waveHeight)}ft',
                    style: TextStyle(
                      fontSize: AppTypography.textSm,
                      color: subColor,
                    ),
                  ),
                ],
              ],
            ),
          ],

          // Board rec moved to standalone card below
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

class _HourlyScrubStripState extends State<_HourlyScrubStrip> {
  int? _activeIdx;
  int? _lastHapticIdx;

  // Filter to today's daylight hours (6am–9pm)
  late List<_StripEntry> _entries;

  @override
  void initState() {
    super.initState();
    _buildEntries();
  }

  @override
  void didUpdateWidget(_HourlyScrubStrip old) {
    super.didUpdateWidget(old);
    if (old.hourlyData != widget.hourlyData) _buildEntries();
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
    setState(() => _activeIdx = null);
    widget.scrubNotifier.value = null;
    _lastHapticIdx = null;
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

    return Semantics(
      label: 'Hourly surf conditions. Drag to explore different hours.',
      child: Container(
      height: 84,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.sm,
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
            // Also support tap
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
    final labelHeight = 16.0;
    final maxBarHeight = size.height - labelHeight - 8; // bars + padding
    final barTop = 6.0;

    // ── Best window background highlight (sea-glass wash) ──
    int? bwStart;
    int? bwEnd;
    for (var i = 0; i < entries.length; i++) {
      if (entries[i].isBestWindow) {
        bwStart ??= i;
        bwEnd = i;
      }
    }
    if (bwStart != null && bwEnd != null) {
      final bwPaint = Paint()
        ..color = AppColors.accent.withValues(alpha: 0.10);
      final bwRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          bwStart * barWidth,
          0,
          (bwEnd - bwStart + 1) * barWidth,
          size.height,
        ),
        const Radius.circular(4),
      );
      canvas.drawRRect(bwRect, bwPaint);
    }

    // ── Draw bars ──
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      final x = i * barWidth;
      final barH = maxBarHeight * e.score.clamp(0.05, 1.0);
      final y = barTop + (maxBarHeight - barH);
      final color = _barColor(e.score);

      // Bar with rounded top
      final isActive = activeIdx == i;
      final barRect = RRect.fromRectAndCorners(
        Rect.fromLTWH(
          x + barWidth * 0.15,
          y,
          barWidth * 0.7,
          barH,
        ),
        topLeft: const Radius.circular(3),
        topRight: const Radius.circular(3),
      );
      // Active bar springs to full opacity; nearby bars slightly brighter
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
      canvas.drawRRect(barRect, Paint()..color = color.withValues(alpha: alpha));

      // Active bar: wider glow + condition-colored fill (FL-DR-3d)
      if (isActive) {
        // Outer glow
        final glowRect = RRect.fromRectAndCorners(
          Rect.fromLTWH(
            x + barWidth * 0.02,
            y - 4,
            barWidth * 0.96,
            barH + 4,
          ),
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        );
        canvas.drawRRect(
          glowRect,
          Paint()..color = color.withValues(alpha: 0.18),
        );
        // Solid fill on top
        final solidRect = RRect.fromRectAndCorners(
          Rect.fromLTWH(
            x + barWidth * 0.08,
            y - 2,
            barWidth * 0.84,
            barH + 2,
          ),
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        );
        canvas.drawRRect(solidRect, Paint()..color = color);

        // FL-A11Y-3: Score label above active bar (color not sole cue)
        final scoreLabel = '${(e.score * 100).round()}';
        final scoreTp = TextPainter(
          text: TextSpan(
            text: scoreLabel,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColorsDark.textPrimary : AppColors.textPrimary,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final labelY = y - scoreTp.height - 3;
        scoreTp.paint(canvas,
            Offset(x + barWidth / 2 - scoreTp.width / 2, labelY.clamp(0.0, barTop)));
      }

      // Hour labels every 3 hours
      if (e.hour % 3 == 0) {
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

    // ── "Now" vertical line (thin, full height) ──
    final nowIdx = entries.indexWhere((e) => e.isNow);
    if (nowIdx >= 0 && activeIdx == null) {
      final nx = nowIdx * barWidth + barWidth / 2;
      final nowPaint = Paint()
        ..color = (isDark ? AppColorsDark.textPrimary : AppColors.textPrimary)
            .withValues(alpha: 0.6)
        ..strokeWidth = 1.0;
      canvas.drawLine(
        Offset(nx, barTop),
        Offset(nx, size.height - labelHeight - 2),
        nowPaint,
      );
      // Small "now" label
      final nowTp = TextPainter(
        text: TextSpan(
          text: 'now',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColorsDark.textSecondary : AppColors.textSecondary,
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
        ..color = isDark
            ? AppColorsDark.textPrimary
            : AppColors.textPrimary
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
// REASON CHIPS
// =============================================================================

class _ReasonChips extends StatelessWidget {
  final double? waveHeight;
  final double? wavePeriod;
  final double? windSpeed;
  final String windQuality;
  final String windDirLabel;
  final String tideLabel;
  final double? tideHeight;
  final Color? waveDot;
  final Color? windDot;
  final bool isDark;

  const _ReasonChips({
    required this.waveHeight,
    required this.wavePeriod,
    required this.windSpeed,
    required this.windQuality,
    required this.windDirLabel,
    required this.tideLabel,
    required this.tideHeight,
    required this.waveDot,
    required this.windDot,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColorsDark.bgSecondary : AppColors.bgSecondary;
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final subColor =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;

    return Row(
      children: [
        // Swell chip
        Expanded(
          child: _chip(
            bg: bg,
            dotColor: waveDot,
            title: waveHeight != null
                ? '${formatWaveHeight(waveHeight)}ft'
                : '--',
            subtitle: wavePeriod != null
                ? '${wavePeriod!.round()}s period'
                : 'Swell',
            textColor: textColor,
            subColor: subColor,
          ),
        ),
        const SizedBox(width: AppSpacing.s2),
        // Wind chip
        Expanded(
          child: _chip(
            bg: bg,
            dotColor: windDot,
            title: windSpeed != null
                ? '${formatWindSpeed(windSpeed)}mph'
                : '--',
            subtitle: windQuality.isNotEmpty
                ? '$windDirLabel $windQuality'
                : 'Wind',
            textColor: textColor,
            subColor: subColor,
          ),
        ),
        const SizedBox(width: AppSpacing.s2),
        // Tide chip
        Expanded(
          child: _chip(
            bg: bg,
            dotColor: null,
            title: tideHeight != null
                ? '${formatWaveHeight(tideHeight)}ft'
                : '--',
            subtitle: tideLabel,
            textColor: textColor,
            subColor: subColor,
          ),
        ),
      ],
    );
  }

  Widget _chip({
    required Color bg,
    required Color? dotColor,
    required String title,
    required String subtitle,
    required Color textColor,
    required Color subColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s3,
        vertical: AppSpacing.s2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        // Chips: no shadow — flat inline elements
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppTypography.fontMono,
                    fontSize: AppTypography.textSm,
                    fontWeight: AppTypography.weightSemibold,
                    color: textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: AppTypography.textXs,
              color: subColor,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// WHY THIS SCORE — deterministic bullet points, no AI
// =============================================================================

class _WhyThisScoreCard extends StatelessWidget {
  final double? waveHeight;
  final double? wavePeriod;
  final double? windSpeed;
  final String windQuality;
  final String tideLabel;
  final UserPrefs prefs;
  final Location location;
  final String bestWindowRange;
  final bool isDark;

  const _WhyThisScoreCard({
    required this.waveHeight,
    required this.wavePeriod,
    required this.windSpeed,
    required this.windQuality,
    required this.tideLabel,
    required this.prefs,
    required this.location,
    required this.bestWindowRange,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bullets = _buildBullets();
    if (bullets.isEmpty) return const SizedBox.shrink();

    final bg = isDark ? AppColorsDark.bgSecondary : AppColors.bgSecondary;
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final subColor =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Why this score',
            style: TextStyle(
              fontSize: AppTypography.textSm,
              fontWeight: AppTypography.weightSemibold,
              color: textColor,
            ),
          ),
          const SizedBox(height: AppSpacing.s2),
          ...bullets.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '\u2022 ',
                      style: TextStyle(
                        fontSize: AppTypography.textSm,
                        color: subColor,
                        height: 1.4,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        b,
                        style: TextStyle(
                          fontSize: AppTypography.textSm,
                          color: subColor,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  List<String> _buildBullets() {
    final bullets = <String>[];

    // Wave assessment
    if (waveHeight != null) {
      final minH = prefs.minWaveHeight ?? 2.0;
      final maxH = prefs.maxWaveHeight ?? 6.0;
      if (waveHeight! < minH) {
        bullets.add('Waves are small and underpowered for this spot right now');
      } else if (waveHeight! > maxH) {
        bullets.add('Swell is overhead and may be too much for comfortable surfing');
      } else {
        final periodNote = wavePeriod != null && wavePeriod! >= 10
            ? ' with good energy'
            : wavePeriod != null && wavePeriod! < 7
                ? ' but short period'
                : '';
        bullets.add('Wave size is in your sweet spot$periodNote');
      }
    }

    // Wind assessment
    if (windSpeed != null) {
      final wq = windQuality.toLowerCase();
      if (wq == 'offshore') {
        if (windSpeed! < 8) {
          bullets.add('Light offshore wind is grooming the faces nicely');
        } else {
          bullets.add('Offshore wind is cleaning things up but may hold some waves back');
        }
      } else if (wq == 'onshore') {
        bullets.add('Onshore wind is adding texture and chop');
      } else if (wq == 'cross-shore') {
        bullets.add('Cross-shore wind is manageable but not ideal');
      }
    }

    // Tide
    final tl = tideLabel.toLowerCase();
    if (tl.contains('rising')) {
      bullets.add('Tide is pushing in — shape may improve as it fills');
    } else if (tl.contains('falling')) {
      bullets.add('Tide is dropping — watch for shallow spots');
    }

    // Best window forward-look
    if (bestWindowRange.isNotEmpty && bullets.isNotEmpty) {
      bullets.add('Better shape expected during the $bestWindowRange window');
    }

    return bullets.take(3).toList();
  }
}

// =============================================================================
// UNIFIED CONDITIONS CARD
// =============================================================================

// =============================================================================
// BOARD CALL CARD — surf-native, personal
// =============================================================================

class _BoardCallCard extends StatelessWidget {
  final BoardRecommendation boardRec;
  final bool isDark;

  const _BoardCallCard({
    required this.boardRec,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColorsDark.bgSecondary : AppColors.bgSecondary;
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final subColor =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;

    final boardName = boardRec.board.name.isNotEmpty
        ? boardRec.board.name
        : boardRec.board.type;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s3),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.s4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.sm,
        ),
        child: Row(
          children: [
            Icon(Icons.surfing, size: 20, color: AppColors.accent),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Board call',
                    style: TextStyle(
                      fontSize: AppTypography.textXs,
                      fontWeight: AppTypography.weightMedium,
                      color: subColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ride your $boardName',
                    style: TextStyle(
                      fontSize: AppTypography.textSm,
                      fontWeight: AppTypography.weightSemibold,
                      color: textColor,
                    ),
                  ),
                  if (boardRec.reason.isNotEmpty)
                    Text(
                      boardRec.reason,
                      style: TextStyle(
                        fontSize: AppTypography.textXs,
                        color: subColor,
                        height: 1.3,
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
}

class _UnifiedConditionsCard extends StatelessWidget {
  final double? waveHeight;
  final double? waveDir;
  final double? wavePeriod;
  final double? windSpeed;
  final String windDirLabel;
  final String windQuality;
  final double? tideHeight;
  final String tideLabel;
  final double? waterTemp;
  final Color? waveDot;
  final Color? windDot;
  final bool isDark;

  const _UnifiedConditionsCard({
    required this.waveHeight,
    required this.waveDir,
    required this.wavePeriod,
    required this.windSpeed,
    required this.windDirLabel,
    required this.windQuality,
    required this.tideHeight,
    required this.tideLabel,
    required this.waterTemp,
    required this.waveDot,
    required this.windDot,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColorsDark.bgSecondary : AppColors.bgSecondary;
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final subColor =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;
    final dividerColor = isDark ? AppColorsDark.border : AppColors.border;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s4,
        vertical: AppSpacing.s4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.sm,
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Waves column
            Expanded(
              child: _column(
                label: 'Waves',
                value: waveHeight != null
                    ? formatWaveHeight(waveHeight)
                    : '--',
                unit: 'ft',
                detail: _waveDetail(),
                dotColor: waveDot,
                textColor: textColor,
                subColor: subColor,
              ),
            ),
            VerticalDivider(
              width: AppSpacing.s6,
              thickness: 1,
              color: dividerColor,
            ),
            // Wind column
            Expanded(
              child: _column(
                label: 'Wind',
                value: windSpeed != null
                    ? formatWindSpeed(windSpeed)
                    : '--',
                unit: 'mph',
                detail: windQuality.isNotEmpty
                    ? '$windDirLabel \u00b7 $windQuality'
                    : windDirLabel,
                dotColor: windDot,
                textColor: textColor,
                subColor: subColor,
              ),
            ),
            VerticalDivider(
              width: AppSpacing.s6,
              thickness: 1,
              color: dividerColor,
            ),
            // Tide column
            Expanded(
              child: _column(
                label: 'Tide',
                value: tideHeight != null
                    ? formatWaveHeight(tideHeight)
                    : '--',
                unit: 'ft',
                detail: _tideDetail(),
                dotColor: null,
                textColor: textColor,
                subColor: subColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _waveDetail() {
    final parts = <String>[];
    if (waveDir != null) parts.add(degreesToCardinal(waveDir!));
    if (wavePeriod != null) parts.add('${wavePeriod!.round()}s');
    return parts.isNotEmpty ? parts.join(' ') : 'Swell';
  }

  String _tideDetail() {
    final parts = <String>[tideLabel];
    if (waterTemp != null) {
      parts.add('${formatTemp(waterTemp)}°');
    }
    return parts.join(' \u00b7 ');
  }

  Widget _column({
    required String label,
    required String value,
    required String unit,
    required String detail,
    required Color? dotColor,
    required Color textColor,
    required Color subColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label with optional dot
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: AppTypography.textXs,
                fontWeight: AppTypography.weightMedium,
                color: subColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Value + unit
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: AppTypography.fontMono,
                fontSize: AppTypography.textXl,
                fontWeight: AppTypography.weightBold,
                color: textColor,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              unit,
              style: TextStyle(
                fontSize: AppTypography.textXs,
                color: subColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        // Detail line
        Text(
          detail,
          style: TextStyle(
            fontSize: AppTypography.textXs,
            color: subColor,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// =============================================================================
// FORECAST SUMMARY (left-aligned, with LLM crossfade)
// =============================================================================

class _ForecastSummaryBlock extends StatelessWidget {
  final String ruleBasedSummary;
  final AiState llmState;
  final Confidence? confidence;
  final bool isDark;

  const _ForecastSummaryBlock({
    required this.ruleBasedSummary,
    required this.llmState,
    required this.confidence,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final showLlm =
        llmState.status == AiStatus.loaded && llmState.text != null;
    final displayText = showLlm ? llmState.text! : ruleBasedSummary;
    final subColor =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;
    final tertiaryColor =
        isDark ? AppColorsDark.textTertiary : AppColors.textTertiary;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSwitcher(
            duration: AppDurations.slow,
            child: Text(
              displayText,
              key: ValueKey(displayText),
              textAlign: TextAlign.left,
              style: TextStyle(
                fontSize: AppTypography.textSm,
                color: subColor,
                height: 1.5,
              ),
            ),
          ),
          // Confidence is communicated through the score, not a badge
        ],
      ),
    );
  }
}

// =============================================================================
// EXPECTED VS POTENTIAL
// =============================================================================

class _ExpectedVsPotentialCard extends StatelessWidget {
  final ExpectedVsPotential evp;
  final bool isDark;
  const _ExpectedVsPotentialCard(
      {required this.evp, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final expectedLabel = getConditionLabel(evp.expectedScore);
    final potentialLabel = getConditionLabel(evp.potentialScore);
    final bgColor =
        isDark ? AppColorsDark.bgSecondary : AppColors.bgSecondary;
    final labelColor =
        isDark ? AppColorsDark.textTertiary : AppColors.textTertiary;
    final descColor =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        children: [
          _evpRow('EXPECTED', evp.expectedDescription, expectedLabel,
              labelColor, descColor),
          const SizedBox(height: AppSpacing.s1),
          _evpRow('POTENTIAL', evp.potentialDescription, potentialLabel,
              labelColor, descColor),
        ],
      ),
    );
  }

  Widget _evpRow(String label, String desc, ConditionLabel condition,
      Color labelColor, Color descColor) {
    return Row(
      children: [
        SizedBox(
          width: 68,
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppTypography.textXxs,
              fontWeight: AppTypography.weightSemibold,
              color: labelColor,
              letterSpacing: 0.3,
            ),
          ),
        ),
        Expanded(
          child: Text(
            desc,
            style: TextStyle(
              fontSize: AppTypography.textXs,
              color: descColor,
            ),
          ),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Color(int.parse(
                    condition.color.replaceFirst('#', '0xFF')))
                .withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            condition.label,
            style: TextStyle(
              fontSize: AppTypography.textXxs,
              fontWeight: AppTypography.weightSemibold,
              color: Color(int.parse(
                  condition.color.replaceFirst('#', '0xFF'))),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// FORECAST ACCURACY
// =============================================================================

class _ForecastAccuracyBadge extends StatelessWidget {
  final ForecastAccuracy accuracy;
  const _ForecastAccuracyBadge({required this.accuracy});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s3),
      child: Row(
        children: [
          Text(
            '\u2713',
            style: TextStyle(
              fontSize: AppTypography.textXs,
              fontWeight: AppTypography.weightBold,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'Matched ${accuracy.matched} of your last ${accuracy.total} sessions (${accuracy.pct}%)',
            style: TextStyle(
              fontSize: AppTypography.textXs,
              fontWeight: AppTypography.weightMedium,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SCORE FEEDBACK
// =============================================================================

class _ScoreFeedbackWidget extends StatefulWidget {
  final String locationId;
  final double score;
  final HourlyData? currentHour;
  final bool isDark;

  const _ScoreFeedbackWidget({
    required this.locationId,
    required this.score,
    this.currentHour,
    required this.isDark,
  });

  @override
  State<_ScoreFeedbackWidget> createState() => _ScoreFeedbackWidgetState();
}

class _ScoreFeedbackWidgetState extends State<_ScoreFeedbackWidget> {
  static const _hiveBox = 'boardcast_store';
  static const _feedbackKey = 'score_feedback_given';

  String? _submitted;

  String _dedupKey() {
    final hour = DateTime.now().toIso8601String().split('T')[0] +
        'T${DateTime.now().hour.toString().padLeft(2, '0')}';
    return '${widget.locationId}_$hour';
  }

  bool _hasGivenFeedback() {
    try {
      final box = Hive.box<String>(_hiveBox);
      final raw = box.get(_feedbackKey);
      if (raw == null) return false;
      final given = jsonDecode(raw) as Map<String, dynamic>;
      return given.containsKey(_dedupKey());
    } catch (_) {
      return false;
    }
  }

  void _saveFeedback(String feedback) {
    setState(() => _submitted = feedback);
    HapticFeedback.lightImpact();

    try {
      final box = Hive.box<String>(_hiveBox);
      final raw = box.get(_feedbackKey);
      final given = raw != null
          ? (jsonDecode(raw) as Map<String, dynamic>)
          : <String, dynamic>{};
      given[_dedupKey()] = feedback;
      if (given.length > 100) {
        final keys = given.keys.toList();
        for (final k in keys.sublist(0, keys.length - 100)) {
          given.remove(k);
        }
      }
      box.put(_feedbackKey, jsonEncode(given));
    } catch (_) {}

    final h = widget.currentHour;
    supabase.from('feedback').insert({
      'type': 'score_accuracy',
      'message': jsonEncode({
        'locationId': widget.locationId,
        'score': (widget.score * 100).round(),
        'feedback': feedback,
        'conditions': {
          'waveHeight': h?.waveHeight,
          'windSpeed': h?.windSpeed,
          'windDirection': h?.windDirection,
          'swellDirection': h?.swellDirection,
          'swellPeriod': h?.swellPeriod,
          'tideHeight': h?.tideHeight,
        },
      }),
    }).then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    if (_hasGivenFeedback() && _submitted == null) {
      return const SizedBox.shrink();
    }

    final subColor = widget.isDark
        ? AppColorsDark.textSecondary
        : AppColors.textSecondary;

    if (_submitted != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.s4),
        child: Text(
          'Thanks for the feedback!',
          style: TextStyle(
            fontSize: AppTypography.textXs,
            color: subColor,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Score feel right?',
            style: TextStyle(
              fontSize: AppTypography.textXs,
              color: subColor,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _feedbackButton('Too low', Icons.arrow_downward, subColor),
              const SizedBox(width: 8),
              _feedbackButton('Spot on', Icons.check, subColor,
                  isAccent: true),
              const SizedBox(width: 8),
              _feedbackButton('Too high', Icons.arrow_upward, subColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _feedbackButton(String label, IconData icon, Color color,
      {bool isAccent = false}) {
    final fg = isAccent ? AppColors.accent : color;
    return GestureDetector(
      onTap: () =>
          _saveFeedback(label.toLowerCase().replaceAll(' ', '_')),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(
              color: isAccent
                  ? AppColors.accent.withValues(alpha: 0.4)
                  : color.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                  fontSize: AppTypography.textXs, color: fg),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// FL-MOTION-3: Spring lift on tap — cards lift 2pt with spring curve
// =============================================================================

class _SpringLift extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _SpringLift({required this.child, this.onTap});

  @override
  State<_SpringLift> createState() => _SpringLiftState();
}

class _SpringLiftState extends State<_SpringLift>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _lift;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 300),
    );
    _lift = Tween<double>(begin: 0, end: -2).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Curves.easeOut,
        reverseCurve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _lift,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _lift.value),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
