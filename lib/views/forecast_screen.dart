import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/tokens.dart';
import '../models/merged_conditions.dart';
import '../models/hourly_data.dart';
import '../logic/scoring.dart';
import '../logic/time_utils.dart';
import '../logic/units.dart';
import '../state/conditions_provider.dart';
import '../state/location_provider.dart';
import '../state/preferences_provider.dart';
import '../components/forecast_chart.dart';
import '../components/condition_bar.dart';
import '../components/tide_chart.dart';
import '../components/daily_card.dart';
import '../components/weekly_windows.dart';
import '../components/stale_badge.dart';
import '../components/discovery_hint.dart';
import '../state/store_provider.dart';
import '../components/shimmer.dart';
import '../components/stagger_animate.dart';

class ForecastScreen extends ConsumerStatefulWidget {
  const ForecastScreen({super.key});

  @override
  ConsumerState<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends ConsumerState<ForecastScreen> {
  int _selectedDayIndex = 0;
  final _scrubberNotifier = ValueNotifier<int?>(null);
  late Set<String> _seenHints;

  @override
  void initState() {
    super.initState();
    _seenHints = ref.read(storeServiceProvider).getSeenHints();
  }

  @override
  void dispose() {
    _scrubberNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conditionsAsync = ref.watch(conditionsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
      backgroundColor: isDark ? AppColorsDark.bgPrimary : AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: isDark ? AppColorsDark.bgPrimary : AppColors.bgPrimary,
        elevation: 0,
        title: Text(
          'Forecast',
          style: TextStyle(
            fontSize: AppTypography.textBase,
            fontWeight: AppTypography.weightSemibold,
            color: isDark ? AppColorsDark.textPrimary : AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: conditionsAsync.when(
        loading: () => _buildSkeleton(isDark),
        error: (err, _) {
          final isOffline = err.toString().contains('SocketException') ||
              err.toString().contains('Failed host lookup');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isOffline ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
                    size: 48,
                    color: AppColors.conditionFair,
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    isOffline ? 'You\'re offline' : 'Couldn\'t load forecast',
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
                    isOffline
                        ? 'Connect to the internet and try again.'
                        : 'The forecast server didn\'t respond.',
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
        },
        data: (data) => _buildForecast(data, isDark),
      ),
    ),
    );
  }

  Widget _buildForecast(MergedConditions data, bool isDark) {
    final location = ref.read(selectedLocationProvider);
    final prefs = ref.read(preferencesProvider);
    final dataAge = ref.watch(dataAgeProvider);

    if (data.daily.isEmpty) {
      return const Center(child: Text('No forecast data available'));
    }

    // Clamp selected day index
    if (_selectedDayIndex >= data.daily.length) {
      _selectedDayIndex = 0;
    }

    final selectedDay = data.daily[_selectedDayIndex];
    final selectedDate = selectedDay.date;

    // Filter hourly data for selected day
    final dayHours =
        data.hourly.where((h) => h.time.startsWith(selectedDate)).toList();

    // Is today?
    final today = isToday(selectedDate);
    int? currentIdx;
    if (today) {
      final times = dayHours.map((h) => h.time).toList();
      currentIdx = getCurrentHourIndex(times);
      if (currentIdx < 0) currentIdx = null;
    }

    // Best window label
    final bestWindow = findBestWindow(data.hourly, prefs, location);
    String? windowLabel;
    if (bestWindow != null) {
      final startH = formatHour(bestWindow.startTime);
      final endH = formatHour(bestWindow.endTime);
      final label = getConditionLabel(bestWindow.avgScore);
      final wave = bestWindow.waveHeight != null
          ? ' ${formatWaveHeight(bestWindow.waveHeight)} ft'
          : '';
      windowLabel = '$startH – $endH  ${label.label}$wave';
    }

    // Weekly top windows
    final topWindows = findTopWindows(data.hourly, prefs, location, count: 5);

    // Build hourly data map per day for daily cards
    final dayHoursMap = <String, List<HourlyData>>{};
    for (final h in data.hourly) {
      final d = h.time.split('T')[0];
      dayHoursMap.putIfAbsent(d, () => []).add(h);
    }

    final subColor =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () async {
        HapticFeedback.mediumImpact();
        ref.invalidate(conditionsProvider);
        // Wait for the provider to reload
        await ref.read(conditionsProvider.future);
      },
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

        // Discovery hint
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s1),
          child: DiscoveryHint(
            id: 'forecast_windows',
            message: 'Tap a best window to jump to that day\u2019s forecast.',
            icon: Icons.touch_app,
            seenHints: _seenHints,
            onDismiss: (id) {
              _seenHints.add(id);
              ref.read(storeServiceProvider).markHintSeen(id);
            },
          ),
        ),

        // Best windows — lead with the answer
        WeeklyWindows(
          windows: topWindows,
          onWindowTap: (date) {
            final idx = data.daily.indexWhere((d) => d.date == date);
            if (idx >= 0) setState(() => _selectedDayIndex = idx);
          },
        ),
        const SizedBox(height: AppSpacing.s4),

        // Charts section — crossfade on day switch
        AnimatedSwitcher(
          duration: AppDurations.slow,
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: Column(
            key: ValueKey(selectedDate),
            children: [
              ForecastChart(
                hourlyData: dayHours,
                prefs: prefs,
                location: location,
                isToday: today,
                currentHourIndex: currentIdx,
                scrubberNotifier: _scrubberNotifier,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s1),
                child: ConditionBar(
                  hourlyData: dayHours,
                  prefs: prefs,
                  location: location,
                ),
              ),
              TideChart(
                hourlyData: dayHours,
                isToday: today,
                currentHourIndex: currentIdx,
              ),
            ],
          ),
        ),

        // Window label
        if (windowLabel != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '\u2726 Your window: ',
                  style: TextStyle(
                    fontSize: AppTypography.textXs,
                    color: AppColors.accent,
                    fontWeight: AppTypography.weightMedium,
                  ),
                ),
                Text(
                  windowLabel,
                  style: TextStyle(
                    fontSize: AppTypography.textXs,
                    color: subColor,
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: AppSpacing.s3),

        // Daily cards — staggered entrance
        ...List.generate(data.daily.length, (i) {
          final d = data.daily[i];
          final hours = dayHoursMap[d.date] ?? [];
          return StaggerAnimate(
            index: i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s2),
              child: DailyCard(
                day: d,
                dayHours: hours,
                prefs: prefs,
                location: location,
                isSelected: i == _selectedDayIndex,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedDayIndex = i);
                },
              ),
            ),
          );
        }),

        const SizedBox(height: AppSpacing.s8),
      ],
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
            const ShimmerBox(height: 180),
            const SizedBox(height: AppSpacing.s4),
            ...List.generate(4, (_) => const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.s2),
              child: ShimmerBox(height: 72),
            )),
          ],
        ),
      ),
    );
  }
}
