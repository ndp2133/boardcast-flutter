/// Dashboard screen — score ring, metric cards, best time, forecast summary, AI coach
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
import '../state/conditions_provider.dart';
import '../state/location_provider.dart';
import '../state/preferences_provider.dart';
import '../state/ai_provider.dart';
import '../components/score_ring.dart';
import '../components/metric_card.dart';
import '../components/wind_compass.dart';
import '../components/best_time_card.dart';
import '../components/stale_badge.dart';
import '../components/location_picker.dart';
import '../components/surf_coach_card.dart';
import '../components/share_card.dart';
import '../components/alert_banner.dart';
import '../state/subscription_provider.dart';
import '../services/supabase_service.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final VoidCallback? onNavigateToForecast;

  const DashboardScreen({super.key, this.onNavigateToForecast});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Timer? _autoRefresh;

  @override
  void initState() {
    super.initState();
    // Auto-refresh every 15 minutes
    _autoRefresh = Timer.periodic(const Duration(minutes: 15), (_) {
      ref.invalidate(conditionsProvider);
    });
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
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
      backgroundColor: isDark ? AppColorsDark.bgPrimary : AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: isDark ? AppColorsDark.bgPrimary : AppColors.bgPrimary,
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
                  color:
                      isDark ? AppColorsDark.textPrimary : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down,
                size: 20,
                color:
                    isDark ? AppColorsDark.textSecondary : AppColors.textSecondary,
              ),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          // Share button
          if (conditionsAsync.hasValue)
            IconButton(
              icon: Icon(
                Icons.share,
                size: 20,
                color: isDark
                    ? AppColorsDark.textSecondary
                    : AppColors.textSecondary,
              ),
              onPressed: () => _onShare(conditionsAsync.value!, location, prefs, isDark),
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: AppDurations.slow,
        child: conditionsAsync.when(
          skipLoadingOnRefresh: true,
          loading: () => _buildSkeleton(isDark),
          error: (err, _) => _buildError(err, isDark),
          data: (data) => _buildDashboard(data, location, prefs, dataAge, isDark),
        ),
      ),
    ),
    );
  }

  void _onShare(MergedConditions data, Location location, UserPrefs prefs, bool isDark) {
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

    // Compute current match score from the nearest hourly data
    final hourlyTimes = data.hourly.map((h) => h.time).toList();
    final nowIdx = getCurrentHourIndex(hourlyTimes);
    final currentHour = nowIdx >= 0 && nowIdx < data.hourly.length
        ? data.hourly[nowIdx]
        : null;
    final tideRange = TideRange.fromHourlyData(data.hourly);
    final score = computeMatchScore(currentHour, prefs, location,
        tideRange: tideRange);

    // Find best window for today
    final today = DateTime.now().toIso8601String().split('T')[0];
    final todayHours =
        data.hourly.where((h) => h.time.startsWith(today)).toList();
    final bestWindow = findBestWindow(data.hourly, prefs, location,
        tideRange: tideRange);

    // Sunrise for the best window's day
    final bestDate = bestWindow?.date ?? today;
    final sunrise = data.daily
        .where((d) => d.date == bestDate)
        .map((d) => d.sunrise)
        .firstOrNull;

    // Sparkline data: next 6 hours
    final next6 = getNextNHours(data.hourly, nowIdx, 6);
    final waveSparkline =
        next6.map((h) => h.waveHeight ?? 0.0).toList();
    final windSparkline = next6.map((h) => h.windSpeed ?? 0.0).toList();
    final tideSparkline = next6.map((h) => h.tideHeight ?? 0.0).toList();

    // Wind direction label
    final windDir = current.windDirection;
    final windDirLabel = windDir != null
        ? degreesToCardinal(windDir)
        : '--';
    final windQuality = windDir != null
        ? (isOffshoreWind(windDir, location)
            ? 'Offshore'
            : isOnshoreWind(windDir, location)
                ? 'Onshore'
                : 'Cross-shore')
        : '';

    // Tide trend
    final tideLabel = current.tideTrend ?? 'Unknown';
    final waterTempText = current.waterTemp != null
        ? '${formatTemp(current.waterTemp)}°'
        : '';
    final tideSubLabel =
        '$tideLabel${waterTempText.isNotEmpty ? ' · $waterTempText water' : ''}';

    // Forecast summary (rule-based)
    final ruleBasedSummary = generateForecastSummary(todayHours, prefs, location);

    // Trigger LLM summary fetch in background (premium only)
    final llmState = ref.watch(llmSummaryProvider);
    final isPremium = ref.watch(isPremiumProvider);
    if (isPremium && ruleBasedSummary.isNotEmpty && llmState.status == AiStatus.idle) {
      // Schedule after frame to avoid build-time provider mutation
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

    return RefreshIndicator(
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
          // Alert banner — proactive notification for good conditions
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
              child: Center(
                child: StaleBadge(
                  ageMinutes: dataAge,
                  isStale: data.isStale,
                  onRefresh: () => ref.invalidate(conditionsProvider),
                ),
              ),
            ),

          // Score ring
          Center(child: ScoreRing(score: score)),
          const SizedBox(height: AppSpacing.s3),

          // Forecast summary with LLM crossfade
          if (ruleBasedSummary.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s4),
              child: _buildSummaryWithCrossfade(
                ruleBasedSummary, llmState, isDark),
            ),

          // Score feedback
          if (score > 0)
            _ScoreFeedbackWidget(
              locationId: location.id,
              score: score,
              currentHour: currentHour,
              isDark: isDark,
            ),

          // Metric cards — 3 column grid
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  name: 'Waves',
                  value: formatWaveHeight(current.waveHeight),
                  unit: 'ft',
                  numericValue: current.waveHeight,
                  formatValue: (v) => formatWaveHeight(v),
                  subLabel:
                      '${windDir != null ? degreesToCardinal(current.waveDirection ?? 0) : '--'} ${current.wavePeriod != null ? '${current.wavePeriod!.round()}s' : ''}',
                  dotColor: waveDot,
                  idealRange: prefs.minWaveHeight != null
                      ? 'Ideal: ${formatWaveHeight(prefs.minWaveHeight)}\u2013${formatWaveHeight(prefs.maxWaveHeight)} ft'
                      : null,
                  sparklineData: waveSparkline,
                  explainer:
                      'Wave height is the primary factor in surf quality. Measured from trough to crest.',
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              Expanded(
                child: MetricCard(
                  name: 'Wind',
                  value: formatWindSpeed(current.windSpeed),
                  unit: 'mph',
                  numericValue: current.windSpeed,
                  formatValue: (v) => formatWindSpeed(v),
                  subLabel: '$windDirLabel \u00b7 $windQuality',
                  dotColor: windDot,
                  idealRange: prefs.maxWindSpeed != null
                      ? 'Ideal: < ${formatWindSpeed(prefs.maxWindSpeed)} mph'
                      : null,
                  sparklineData: windSparkline,
                  extra: windDir != null
                      ? WindCompass(
                          windDegrees: windDir,
                          location: location,
                        )
                      : null,
                  explainer:
                      'Offshore winds (blowing from land) create clean, well-shaped waves.',
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              Expanded(
                child: MetricCard(
                  name: 'Tide',
                  value: current.tideHeight != null
                      ? formatWaveHeight(current.tideHeight)
                      : '--',
                  unit: 'ft',
                  numericValue: current.tideHeight,
                  formatValue: (v) => formatWaveHeight(v),
                  subLabel: tideSubLabel,
                  sparklineData: tideSparkline,
                  explainer:
                      'Tide affects wave shape. Mid-tide often produces the best conditions at most breaks.',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),

          // Best time card
          BestTimeCard(window: bestWindow, sunrise: sunrise),
          const SizedBox(height: AppSpacing.s4),

          // AI Surf Coach card
          const SurfCoachCard(),

          const SizedBox(height: AppSpacing.s8),
        ],
      ),
    );
  }

  /// Crossfade between rule-based and LLM summary text.
  Widget _buildSummaryWithCrossfade(
      String ruleBasedSummary, AiState llmState, bool isDark) {
    final showLlm = llmState.status == AiStatus.loaded && llmState.text != null;
    final displayText = showLlm ? llmState.text! : ruleBasedSummary;

    return Column(
      children: [
        AnimatedSwitcher(
          duration: AppDurations.slow,
          child: Text(
            displayText,
            key: ValueKey(displayText),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppTypography.textSm,
              color: isDark
                  ? AppColorsDark.textSecondary
                  : AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ),
        if (showLlm)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '\u2726 AI-generated',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.accent.withValues(alpha: 0.6),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSkeleton(bool isDark) {
    final shimmer = isDark ? AppColorsDark.bgTertiary : AppColors.bgTertiary;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s4),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.s8),
          // Score ring placeholder
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(shape: BoxShape.circle, color: shimmer),
          ),
          const SizedBox(height: AppSpacing.s6),
          // Summary placeholder
          Container(
            height: 16,
            width: 200,
            decoration: BoxDecoration(
              color: shimmer,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
          const SizedBox(height: AppSpacing.s6),
          // Metric cards placeholder
          Row(
            children: List.generate(
              3,
              (_) => Expanded(
                child: Container(
                  height: 80,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: shimmer,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(Object error, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: AppColors.conditionFair),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'Could not load conditions',
              style: TextStyle(
                fontSize: AppTypography.textBase,
                fontWeight: AppTypography.weightMedium,
                color: isDark
                    ? AppColorsDark.textPrimary
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.s2),
            Text(
              'Check your connection and try again.',
              style: TextStyle(
                fontSize: AppTypography.textSm,
                color: isDark
                    ? AppColorsDark.textSecondary
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            TextButton.icon(
              onPressed: () => ref.invalidate(conditionsProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dot color based on whether current value is within preference range
Color? _prefDotColor(double? value, double? min, double? max) {
  if (value == null || min == null || max == null) return null;
  if (value >= min && value <= max) return AppColors.conditionEpic;
  final dist = value < min ? min - value : value - max;
  if (dist < max * 0.3) return AppColors.conditionFair;
  return AppColors.conditionPoor;
}

/// Score feedback widget — "Score feel right?" with dedup per location+hour
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

    // Save dedup locally
    try {
      final box = Hive.box<String>(_hiveBox);
      final raw = box.get(_feedbackKey);
      final given = raw != null
          ? (jsonDecode(raw) as Map<String, dynamic>)
          : <String, dynamic>{};
      given[_dedupKey()] = feedback;
      // Prune to last 100
      if (given.length > 100) {
        final keys = given.keys.toList();
        for (final k in keys.sublist(0, keys.length - 100)) {
          given.remove(k);
        }
      }
      box.put(_feedbackKey, jsonEncode(given));
    } catch (_) {}

    // Push to Supabase fire-and-forget
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
        child: Center(
          child: Text(
            'Thanks for the feedback!',
            style: TextStyle(
              fontSize: AppTypography.textXs,
              color: subColor,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s4),
      child: Column(
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
            mainAxisAlignment: MainAxisAlignment.center,
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
      onTap: () => _saveFeedback(label.toLowerCase().replaceAll(' ', '_')),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
              style: TextStyle(fontSize: AppTypography.textXs, color: fg),
            ),
          ],
        ),
      ),
    );
  }
}
