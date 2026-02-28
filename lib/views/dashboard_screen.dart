/// Dashboard screen — score ring, metric cards, best time, forecast summary
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/tokens.dart';
import '../models/merged_conditions.dart';
import '../models/location.dart';
import '../models/user_prefs.dart';
import '../logic/scoring.dart';
import '../logic/units.dart';
import '../logic/time_utils.dart';
import '../logic/forecast_summary.dart';
import '../state/conditions_provider.dart';
import '../state/location_provider.dart';
import '../state/preferences_provider.dart';
import '../components/score_ring.dart';
import '../components/metric_card.dart';
import '../components/wind_compass.dart';
import '../components/best_time_card.dart';
import '../components/stale_badge.dart';
import '../components/location_picker.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

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

    return Scaffold(
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
      ),
      body: conditionsAsync.when(
        loading: () => _buildSkeleton(isDark),
        error: (err, _) => _buildError(err, isDark),
        data: (data) => _buildDashboard(data, location, prefs, dataAge, isDark),
      ),
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
    final score = computeMatchScore(currentHour, prefs, location);

    // Find best window for today
    final today = DateTime.now().toIso8601String().split('T')[0];
    final todayHours =
        data.hourly.where((h) => h.time.startsWith(today)).toList();
    final bestWindow = findBestWindow(data.hourly, prefs, location);

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

    // Forecast summary
    final summary = generateForecastSummary(todayHours, prefs, location);

    // Metric dot colors
    final waveDot = _prefDotColor(
      current.waveHeight,
      prefs.minWaveHeight,
      prefs.maxWaveHeight,
    );
    final windDot = current.windSpeed != null && prefs.maxWindSpeed != null
        ? (current.windSpeed! <= prefs.maxWindSpeed!
            ? AppColors.conditionEpic
            : AppColors.conditionPoor)
        : null;

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () async => ref.invalidate(conditionsProvider),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
        children: [
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

          // Forecast summary
          if (summary.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s4),
              child: Text(
                summary,
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

          // Metric cards — 3 column grid
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  name: 'Waves',
                  value: formatWaveHeight(current.waveHeight),
                  unit: 'ft',
                  subLabel:
                      '${windDir != null ? degreesToCardinal(current.waveDirection ?? 0) : '--'} ${current.wavePeriod != null ? '${current.wavePeriod!.round()}s' : ''}',
                  dotColor: waveDot,
                  idealRange: prefs.minWaveHeight != null
                      ? 'Ideal: ${formatWaveHeight(prefs.minWaveHeight)}–${formatWaveHeight(prefs.maxWaveHeight)} ft'
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
                  subLabel: '$windDirLabel · $windQuality',
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
          BestTimeCard(window: bestWindow),

          const SizedBox(height: AppSpacing.s8),
        ],
      ),
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
