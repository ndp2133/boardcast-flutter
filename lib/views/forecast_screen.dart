import 'package:flutter/material.dart';
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
import '../components/tide_chart.dart';
import '../components/daily_card.dart';
import '../components/weekly_windows.dart';

class ForecastScreen extends ConsumerStatefulWidget {
  const ForecastScreen({super.key});

  @override
  ConsumerState<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends ConsumerState<ForecastScreen> {
  int _selectedDayIndex = 0;
  final _scrubberNotifier = ValueNotifier<int?>(null);

  @override
  void dispose() {
    _scrubberNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conditionsAsync = ref.watch(conditionsProvider);
    final location = ref.watch(selectedLocationProvider);
    final prefs = ref.watch(preferencesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
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
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 48, color: AppColors.conditionFair),
              const SizedBox(height: AppSpacing.s3),
              Text(
                'Could not load forecast',
                style: TextStyle(
                  color: isDark
                      ? AppColorsDark.textPrimary
                      : AppColors.textPrimary,
                ),
              ),
              TextButton.icon(
                onPressed: () => ref.invalidate(conditionsProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (data) => _buildForecast(data, isDark),
      ),
    );
  }

  Widget _buildForecast(MergedConditions data, bool isDark) {
    final location = ref.read(selectedLocationProvider);
    final prefs = ref.read(preferencesProvider);

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

    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final subColor =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
      children: [
        // Charts section
        ForecastChart(
          hourlyData: dayHours,
          prefs: prefs,
          location: location,
          isToday: today,
          currentHourIndex: currentIdx,
          scrubberNotifier: _scrubberNotifier,
        ),

        // Chart legend
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendItem('Waves (ft)', AppColors.accent),
              const SizedBox(width: 16),
              _legendItem(
                'Wind (mph)',
                isDark ? const Color(0xFF64748B) : const Color(0xFF9CA3AF),
                dashed: true,
              ),
            ],
          ),
        ),

        // Tide chart
        TideChart(
          hourlyData: dayHours,
          isToday: today,
          currentHourIndex: currentIdx,
        ),
        const SizedBox(height: 4),

        // Window label
        if (windowLabel != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s3),
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

        // Daily cards
        ...List.generate(data.daily.length, (i) {
          final d = data.daily[i];
          final hours = dayHoursMap[d.date] ?? [];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s2),
            child: DailyCard(
              day: d,
              dayHours: hours,
              prefs: prefs,
              location: location,
              isSelected: i == _selectedDayIndex,
              onTap: () => setState(() => _selectedDayIndex = i),
            ),
          );
        }),

        const SizedBox(height: AppSpacing.s4),

        // Weekly windows
        WeeklyWindows(
          windows: topWindows,
          onWindowTap: (date) {
            final idx = data.daily.indexWhere((d) => d.date == date);
            if (idx >= 0) setState(() => _selectedDayIndex = idx);
          },
        ),

        const SizedBox(height: AppSpacing.s8),
      ],
    );
  }

  Widget _legendItem(String label, Color color, {bool dashed = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 2,
          decoration: BoxDecoration(
            color: dashed ? Colors.transparent : color,
            border: dashed
                ? Border(
                    bottom: BorderSide(
                      color: color,
                      width: 2,
                      strokeAlign: BorderSide.strokeAlignCenter,
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: color,
          ),
        ),
      ],
    );
  }
}
