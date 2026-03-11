/// Rule-based forecast summary — direct port of generateForecastSummary from conditions.js
import '../models/hourly_data.dart';
import '../models/location.dart';
import '../models/user_prefs.dart';
import 'scoring.dart';
import 'units.dart';
import 'time_utils.dart';

// Wave size categories (in feet)
const _waveSizeFlat = 0.5;
const _waveSizeAnkle = 1.5;
const _waveSizeSmall = 3.0;
const _waveSizeFun = 5.0;
const _waveSizeHead = 7.0;

String generateForecastSummary(
  List<HourlyData> dayHours,
  UserPrefs prefs,
  Location location,
) {
  if (dayHours.isEmpty) return '';

  // Filter to daylight hours (6AM-9PM)
  final daylightHours = dayHours.where((h) {
    final hour = int.parse(h.time.split('T')[1].split(':')[0]);
    return hour >= daylightStart && hour <= daylightEnd;
  }).toList();
  if (daylightHours.isEmpty) return '';

  // Compute averages
  final avgWaveFt = daylightHours.fold<double>(
          0, (s, h) => s + metersToFeet(h.waveHeight ?? 0)) /
      daylightHours.length;
  final avgWindMph = daylightHours.fold<double>(
          0, (s, h) => s + kmhToMph(h.windSpeed ?? 0)) /
      daylightHours.length;
  final avgSwellPeriod = daylightHours.fold<double>(
          0, (s, h) => s + (h.swellPeriod ?? 0)) /
      daylightHours.length;

  // Dominant wind direction (most common hourly value)
  final dirCounts = <int, int>{};
  for (final h in daylightHours) {
    if (h.windDirection != null) {
      final dir = h.windDirection!.round();
      dirCounts[dir] = (dirCounts[dir] ?? 0) + 1;
    }
  }
  int? dominantWindDir;
  if (dirCounts.isNotEmpty) {
    dominantWindDir = dirCounts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  // Flat day shortcut
  if (avgWaveFt < _waveSizeFlat) return 'Flat. Maybe tomorrow.';

  // Wave size word
  String waveSize;
  if (avgWaveFt < _waveSizeAnkle) {
    waveSize = 'Ankle-high';
  } else if (avgWaveFt < _waveSizeSmall) {
    waveSize = 'Small';
  } else if (avgWaveFt < _waveSizeFun) {
    waveSize = 'Fun-sized';
  } else if (avgWaveFt < _waveSizeHead) {
    waveSize = 'Head-high';
  } else {
    waveSize = 'Overhead';
  }

  // Wave range string (avg +/-30%, floor to ceil)
  final lo = (avgWaveFt * 0.7).floor();
  final hi = (avgWaveFt * 1.3).ceil();
  final range = '$lo\u2013${hi}ft';

  // Wind quality word
  String windQuality;
  if (avgWindMph < 5) {
    windQuality = 'Glassy';
  } else if (avgWindMph < 12) {
    if (dominantWindDir != null &&
        isOffshoreWind(dominantWindDir.toDouble(), location)) {
      windQuality = 'Light offshore';
    } else if (dominantWindDir != null &&
        isOnshoreWind(dominantWindDir.toDouble(), location)) {
      windQuality = 'Light onshore';
    } else {
      windQuality = 'Light cross-shore';
    }
  } else if (avgWindMph < 20) {
    if (dominantWindDir != null &&
        isOffshoreWind(dominantWindDir.toDouble(), location)) {
      windQuality = 'Moderate offshore';
    } else if (dominantWindDir != null &&
        isOnshoreWind(dominantWindDir.toDouble(), location)) {
      windQuality = 'Moderate onshore';
    } else {
      windQuality = 'Moderate cross-shore';
    }
  } else {
    windQuality = 'Gusty';
  }

  // Time advice — find best window scoped to this day
  var timeAdvice = '';
  final windows =
      findMatchingWindows(daylightHours, prefs, location, minScore: 0.5);
  if (windows.isNotEmpty) {
    final best = windows.reduce((a, b) => a.avgScore >= b.avgScore ? a : b);
    final startH = int.parse(best.start.split('T')[1].split(':')[0]);
    final endH = int.parse(best.end.split('T')[1].split(':')[0]);
    final span = endH - startH + 1;

    if (span >= 6) {
      timeAdvice = 'Holds all day.';
    } else {
      final startLabel = formatHour(best.start);
      final endLabel = formatHour(best.end);
      timeAdvice = 'Best $startLabel\u2013$endLabel.';
    }
  }

  // Swell quality descriptor
  String swellDesc = '';
  if (avgSwellPeriod >= 12) {
    swellDesc = 'Clean groundswell.';
  } else if (avgSwellPeriod >= 8) {
    swellDesc = 'Mixed swell.';
  } else if (avgSwellPeriod > 0) {
    swellDesc = 'Short-period windswell.';
  }

  // FL-COPY-3: Short decisive sentences, not compound
  final parts = <String>[
    '$waveSize $range.',
    '$windQuality.',
    if (swellDesc.isNotEmpty) swellDesc,
    if (timeAdvice.isNotEmpty) timeAdvice,
  ];
  return parts.join(' ');
}
