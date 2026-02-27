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
  if (avgWaveFt < _waveSizeFlat) return 'Flat day \u2014 maybe tomorrow.';

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
    windQuality = 'glassy';
  } else if (avgWindMph < 12) {
    if (dominantWindDir != null &&
        isOffshoreWind(dominantWindDir.toDouble(), location)) {
      windQuality = 'light offshore';
    } else if (dominantWindDir != null &&
        isOnshoreWind(dominantWindDir.toDouble(), location)) {
      windQuality = 'light onshore';
    } else {
      windQuality = 'light cross-shore';
    }
  } else if (avgWindMph < 20) {
    if (dominantWindDir != null &&
        isOffshoreWind(dominantWindDir.toDouble(), location)) {
      windQuality = 'moderate offshore';
    } else if (dominantWindDir != null &&
        isOnshoreWind(dominantWindDir.toDouble(), location)) {
      windQuality = 'moderate onshore';
    } else {
      windQuality = 'moderate cross-shore';
    }
  } else {
    windQuality = 'gusty';
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
      timeAdvice = 'Conditions hold all day.';
    } else {
      final startLabel = formatHour(best.start);
      final endLabel = formatHour(best.end);
      if (endH < 12) {
        timeAdvice = 'Best window $startLabel\u2013$endLabel.';
      } else if (startH >= 12) {
        timeAdvice = 'Best from $startLabel\u2013$endLabel.';
      } else {
        timeAdvice = 'Best window $startLabel\u2013$endLabel.';
      }
    }
  }

  return '$waveSize $range waves, $windQuality winds.${timeAdvice.isNotEmpty ? ' $timeAdvice' : ''}';
}
