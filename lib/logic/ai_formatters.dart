// Pure formatting functions for AI payloads — ported from surfCoach.js
// Builds compact string summaries of conditions, daily data, and windows
// for the surf-coach, surf-query, and forecast-summary Edge Functions.
import '../models/current_conditions.dart' show CurrentConditions;
import '../models/daily_data.dart';
import '../models/hourly_data.dart';
import '../models/user_prefs.dart';
import '../logic/scoring.dart';
import 'units.dart';
import 'time_utils.dart';

/// Compact one-line current conditions string for AI context.
String formatCurrentConditions(CurrentConditions current) {
  final wave = current.waveHeight != null
      ? metersToFeet(current.waveHeight!).toStringAsFixed(1)
      : '--';
  final wind = current.windSpeed != null
      ? kmhToMph(current.windSpeed!).round().toString()
      : '--';
  final windDir = current.windDirection != null
      ? degreesToCardinal(current.windDirection!)
      : '--';
  final swell = current.swellPeriod != null
      ? '${current.swellPeriod!.round()}s'
      : '--';
  final tide = current.tideHeight != null
      ? '${current.tideHeight!.toStringAsFixed(1)}ft ${current.tideTrend ?? ''}'.trim()
      : '--';
  return 'Waves: ${wave}ft, Wind: ${wind}mph $windDir, Swell period: $swell, Tide: $tide';
}

/// Multi-line daily summaries with average wind from hourly data.
String formatDailySummaries(List<DailyData> daily, List<HourlyData> hourly) {
  return daily.map((d) {
    final dayLabel = isToday(d.date) ? 'Today' : formatDayFull(d.date);
    final waveMax = d.waveHeightMax != null
        ? metersToFeet(d.waveHeightMax!).toStringAsFixed(1)
        : '--';
    final dir = d.waveDirectionDominant != null
        ? degreesToCardinal(d.waveDirectionDominant!)
        : '--';
    final tempHi = d.tempMax != null
        ? celsiusToFahrenheit(d.tempMax!).round().toString()
        : '--';
    final tempLo = d.tempMin != null
        ? celsiusToFahrenheit(d.tempMin!).round().toString()
        : '--';

    // Hourly wind summary for this day
    final dayHours = hourly.where((h) => h.time.startsWith(d.date)).toList();
    var windSummary = '';
    if (dayHours.isNotEmpty) {
      final winds = dayHours
          .where((h) => h.windSpeed != null)
          .map((h) => kmhToMph(h.windSpeed!))
          .toList();
      if (winds.isNotEmpty) {
        final avgWind =
            (winds.reduce((a, b) => a + b) / winds.length).round();
        windSummary = ', Avg wind: ${avgWind}mph';
      }
    }

    return '$dayLabel (${d.date}): Waves up to ${waveMax}ft $dir, $tempHi/${tempLo}F$windSummary';
  }).join('\n');
}

/// Ranked top windows summary for AI context.
String formatTopWindows(List<TopWindow> windows) {
  if (windows.isEmpty) return 'No good windows found this week.';
  return windows.map((w) {
    final dayLabel = isToday(w.date) ? 'Today' : formatDayFull(w.date);
    final score = (w.avgScore * 100).round();
    final start = formatHour(w.startTime);
    final end = formatHour(w.endTime);
    final wave = w.waveHeight != null
        ? metersToFeet(w.waveHeight!).toStringAsFixed(1)
        : '--';
    return '$dayLabel $start\u2013$end (${w.hours}h): $score% match, ${wave}ft waves';
  }).join('\n');
}

/// Build a prefs payload with imperial-converted values for AI.
Map<String, dynamic> buildPrefsPayload(UserPrefs prefs) {
  return {
    'skillLevel': prefs.skillLevel ?? 'intermediate',
    'minWave': prefs.minWaveHeight != null
        ? metersToFeet(prefs.minWaveHeight!).toStringAsFixed(1)
        : null,
    'maxWave': prefs.maxWaveHeight != null
        ? metersToFeet(prefs.maxWaveHeight!).toStringAsFixed(1)
        : null,
    'maxWind': prefs.maxWindSpeed != null
        ? kmhToMph(prefs.maxWindSpeed!).round().toString()
        : null,
    'preferredWindDir': prefs.preferredWindDir ?? 'any',
  };
}
