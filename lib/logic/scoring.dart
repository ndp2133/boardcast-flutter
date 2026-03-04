/// Condition scoring engine — direct port of utils/conditions.js
/// Key difference from JS: Location is passed explicitly (no global state).
import 'dart:math';
import '../models/hourly_data.dart';
import '../models/location.dart';
import '../models/user_prefs.dart';

// Surfable daylight hours — shared constant
const daylightStart = 6; // 6 AM
const daylightEnd = 21; // 9 PM

// Scoring weights (must sum to 1.0)
const _scoreWeights = {
  'wave': 0.30,
  'wind': 0.25,
  'windDir': 0.15,
  'swellDir': 0.10,
  'swellPeriod': 0.10,
  'tide': 0.10,
};

// Weight adjustments by break type (deltas from base weights)
const _breakAdjustments = {
  'beach': <String, double>{},
  'point': {'swellPeriod': 0.05, 'wave': -0.05},
  'reef': {'tide': 0.10, 'swellPeriod': 0.05, 'wave': -0.10, 'wind': -0.05},
};

/// Get effective scoring weights adjusted for location's break type
Map<String, double> getEffectiveWeights(Location location) {
  final adjustments = _breakAdjustments[location.breakType];
  if (adjustments == null || adjustments.isEmpty) {
    return Map.of(_scoreWeights);
  }
  final weights = Map.of(_scoreWeights);
  for (final entry in adjustments.entries) {
    weights[entry.key] = (weights[entry.key] ?? 0) + entry.value;
  }
  return weights;
}

// Condition label thresholds
const _epicThreshold = 0.8;
const _goodThreshold = 0.6;
const _fairThreshold = 0.4;

/// Check if a wind degree falls within a range, handling wrap-around at 360
bool _inWindRange(double deg, double min, double max) {
  if (min <= max) return deg >= min && deg <= max;
  // Wrap-around (e.g., 315 to 45 crosses 0)
  return deg >= min || deg <= max;
}

bool isOffshoreWind(double windDegrees, Location location) {
  return _inWindRange(windDegrees, location.offshoreMin, location.offshoreMax);
}

bool isOnshoreWind(double windDegrees, Location location) {
  return _inWindRange(windDegrees, location.onshoreMin, location.onshoreMax);
}

// --- Wind direction gradient scoring ---

/// Center angle of a min/max range (handles wrap-around at 360)
double rangeCenterAngle(double min, double max) {
  if (min <= max) return (min + max) / 2;
  // Wraps around 0 (e.g., 315-45) — unwrap, average, re-mod
  return ((min + max + 360) / 2) % 360;
}

/// Shortest angular distance between two bearings (0-180)
double angularDistance(double a, double b) {
  final diff = (a - b).abs() % 360;
  return diff > 180 ? 360 - diff : diff;
}

/// Smooth wind direction score: cosine falloff from ideal center
/// 0 deg from ideal -> 1.0, 90 deg -> 0.6, 180 deg -> 0.2
double scoreWindDirection(
    double? windDeg, UserPrefs prefs, Location location) {
  if (windDeg == null ||
      prefs.preferredWindDir == null ||
      prefs.preferredWindDir == 'any') return 1.0;

  double idealCenter;
  if (prefs.preferredWindDir == 'offshore') {
    idealCenter =
        rangeCenterAngle(location.offshoreMin, location.offshoreMax);
  } else {
    idealCenter =
        rangeCenterAngle(location.onshoreMin, location.onshoreMax);
  }

  final dist = angularDistance(windDeg, idealCenter);
  final distRad = dist * pi / 180;
  return 0.6 + 0.4 * cos(distRad);
}

// --- Swell period scoring (longer is always better) ---

double scoreSwellPeriod(double? periodSeconds) {
  if (periodSeconds == null) return 0.5;
  if (periodSeconds >= 14) return 1.0;
  if (periodSeconds >= 12) return 0.9;
  if (periodSeconds >= 10) return 0.75;
  if (periodSeconds >= 8) return 0.5;
  if (periodSeconds >= 6) return 0.25;
  return 0.1;
}

// --- Tide scoring ---

/// Tide range for normalization
class TideRange {
  final double min;
  final double max;
  const TideRange(this.min, this.max);

  /// Compute tide range from hourly data (min/max of all tide heights)
  static TideRange? fromHourlyData(List<HourlyData> hourly) {
    final heights = hourly
        .map((h) => h.tideHeight)
        .whereType<double>()
        .toList();
    if (heights.isEmpty) return null;
    return TideRange(
      heights.reduce((a, b) => a < b ? a : b),
      heights.reduce((a, b) => a > b ? a : b),
    );
  }
}

/// Score tide based on user's preferred tide and normalized position
double scoreTide(double? tideHeight, String? preferredTide, TideRange? range) {
  if (preferredTide == null || preferredTide == 'any') return 1.0;
  if (range == null || tideHeight == null) return 0.5;

  final span = range.max - range.min;
  if (span == 0) return 0.5;

  // Normalize to 0-1 (0 = low tide, 1 = high tide)
  final n = (tideHeight - range.min) / span;

  if (preferredTide == 'low') return 1.0 - 0.7 * n;
  if (preferredTide == 'high') return 0.3 + 0.7 * n;
  // 'mid' — quadratic: 1.0 at mid-tide, 0.5 at extremes
  return 1.0 - 2.0 * pow(n - 0.5, 2);
}

/// Compute match score (0-1) for an hour of conditions against user preferences.
/// [location] is passed explicitly to keep this function pure.
/// [tideRange] is the min/max tide heights for normalization (from cached API data).
double computeMatchScore(
  HourlyData? hourData,
  UserPrefs? prefs,
  Location location, {
  TideRange? tideRange,
}) {
  if (hourData == null || prefs == null) return 0;

  final weights = getEffectiveWeights(location);
  var score = 0.0;

  // Wave height score
  final wh = hourData.waveHeight;
  if (wh != null && prefs.minWaveHeight != null && prefs.maxWaveHeight != null) {
    if (wh >= prefs.minWaveHeight! && wh <= prefs.maxWaveHeight!) {
      score += weights['wave']! * 1.0;
    } else {
      final dist = wh < prefs.minWaveHeight!
          ? prefs.minWaveHeight! - wh
          : wh - prefs.maxWaveHeight!;
      score += weights['wave']! *
          max(0.0, 1 - dist / prefs.maxWaveHeight!);
    }
  }

  // Wind speed score
  final ws = hourData.windSpeed;
  if (ws != null && prefs.maxWindSpeed != null) {
    if (ws <= prefs.maxWindSpeed!) {
      score += weights['wind']! * 1.0;
    } else {
      score += weights['wind']! *
          max(0.0, 1 - (ws - prefs.maxWindSpeed!) / prefs.maxWindSpeed!);
    }
  }

  // Wind direction score (smooth cosine gradient)
  score +=
      weights['windDir']! * scoreWindDirection(hourData.windDirection, prefs, location);

  // Swell direction score — how well does swell angle hit the beach?
  final sd = hourData.swellDirection;
  if (sd != null) {
    var diff = (sd - location.beachFacing).abs();
    if (diff > 180) diff = 360 - diff;
    final diffRad = diff * pi / 180;
    score += weights['swellDir']! * max(0.0, cos(diffRad));
  } else {
    score += weights['swellDir']! * 0.5;
  }

  // Swell period score (longer period = better quality waves)
  score += weights['swellPeriod']! * scoreSwellPeriod(hourData.swellPeriod);

  // Tide score (based on user preference)
  score += weights['tide']! *
      scoreTide(hourData.tideHeight, prefs.preferredTide, tideRange);

  return min(1.0, max(0.0, score));
}

/// Condition label result
class ConditionLabel {
  final String label;
  final String cssClass;
  final String color;

  const ConditionLabel(this.label, this.cssClass, this.color);
}

ConditionLabel getConditionLabel(double score) {
  if (score >= _epicThreshold) {
    return const ConditionLabel('Epic', 'epic', '#22c55e');
  }
  if (score >= _goodThreshold) {
    return const ConditionLabel('Good', 'good', '#3b82f6');
  }
  if (score >= _fairThreshold) {
    return const ConditionLabel('Fair', 'fair', '#f59e0b');
  }
  return const ConditionLabel('Poor', 'poor', '#ef4444');
}

/// Find best hour result
class BestHourResult {
  final String time;
  final double matchScore;
  const BestHourResult(this.time, this.matchScore);
}

BestHourResult? findBestHours(
  List<HourlyData> hourlyData,
  UserPrefs prefs,
  Location location,
  String date, {
  TideRange? tideRange,
}) {
  final dayHours = hourlyData.where((h) => h.time.startsWith(date)).toList();
  var bestScore = 0.0;
  HourlyData? bestHour;

  for (final hour in dayHours) {
    final score =
        computeMatchScore(hour, prefs, location, tideRange: tideRange);
    if (score > bestScore) {
      bestScore = score;
      bestHour = hour;
    }
  }

  return bestHour != null
      ? BestHourResult(bestHour.time, bestScore)
      : null;
}

/// Matching window
class MatchingWindow {
  final String start;
  final String end;
  final double avgScore;
  final int count;

  const MatchingWindow(this.start, this.end, this.avgScore, this.count);
}

List<MatchingWindow> findMatchingWindows(
  List<HourlyData> hourlyData,
  UserPrefs prefs,
  Location location, {
  double minScore = 0.6,
  TideRange? tideRange,
}) {
  final windows = <MatchingWindow>[];
  String? currentStart;
  String? currentEnd;
  double currentAvgScore = 0;
  int currentCount = 0;

  for (final hour in hourlyData) {
    final score =
        computeMatchScore(hour, prefs, location, tideRange: tideRange);
    if (score >= minScore) {
      if (currentStart == null) {
        currentStart = hour.time;
        currentEnd = hour.time;
        currentAvgScore = score;
        currentCount = 1;
      } else {
        currentEnd = hour.time;
        currentAvgScore =
            (currentAvgScore * currentCount + score) / (currentCount + 1);
        currentCount++;
      }
    } else {
      if (currentStart != null) {
        windows.add(MatchingWindow(
            currentStart, currentEnd!, currentAvgScore, currentCount));
        currentStart = null;
      }
    }
  }
  if (currentStart != null) {
    windows.add(MatchingWindow(
        currentStart, currentEnd!, currentAvgScore, currentCount));
  }

  return windows;
}

/// Top window result (for weekly best windows)
class TopWindow {
  final String date;
  final String startTime;
  final String endTime;
  final double avgScore;
  final int hours;
  final double? waveHeight;

  const TopWindow({
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.avgScore,
    required this.hours,
    this.waveHeight,
  });
}

/// Find top N surfing windows across forecast (max one per day)
List<TopWindow> findTopWindows(
  List<HourlyData> hourlyData,
  UserPrefs prefs,
  Location location, {
  int count = 3,
  TideRange? tideRange,
}) {
  if (hourlyData.isEmpty) return [];

  final dayMap = <String, List<HourlyData>>{};
  for (final h in hourlyData) {
    final date = h.time.split('T')[0];
    final hour = int.parse(h.time.split('T')[1].split(':')[0]);
    if (hour < daylightStart || hour > daylightEnd) continue;
    dayMap.putIfAbsent(date, () => []).add(h);
  }

  final allWindows = <_RawWindow>[];

  for (final entry in dayMap.entries) {
    _RawWindow? currentWindow;

    for (final h in entry.value) {
      final score =
          computeMatchScore(h, prefs, location, tideRange: tideRange);
      if (score >= 0.5) {
        if (currentWindow == null) {
          currentWindow = _RawWindow(
            date: entry.key,
            startTime: h.time,
            endTime: h.time,
            scores: [score],
            waveHeight: h.waveHeight,
          );
        } else {
          currentWindow.endTime = h.time;
          currentWindow.scores.add(score);
        }
      } else {
        if (currentWindow != null) {
          allWindows.add(currentWindow);
          currentWindow = null;
        }
      }
    }
    if (currentWindow != null) allWindows.add(currentWindow);
  }

  // Score and sort
  final scored = allWindows.map((w) {
    final avg = w.scores.reduce((a, b) => a + b) / w.scores.length;
    return (window: w, avgScore: avg, hours: w.scores.length);
  }).toList()
    ..sort((a, b) => b.avgScore.compareTo(a.avgScore));

  // Deduplicate: max one per day
  final seen = <String>{};
  final result = <TopWindow>[];
  for (final s in scored) {
    if (!seen.contains(s.window.date)) {
      seen.add(s.window.date);
      result.add(TopWindow(
        date: s.window.date,
        startTime: s.window.startTime,
        endTime: s.window.endTime,
        avgScore: s.avgScore,
        hours: s.hours,
        waveHeight: s.window.waveHeight,
      ));
      if (result.length >= count) break;
    }
  }

  return result;
}

/// Best window index result (for chart overlay)
class BestWindowIndices {
  final int startIndex;
  final int endIndex;
  final double avgScore;
  const BestWindowIndices(this.startIndex, this.endIndex, this.avgScore);
}

BestWindowIndices? findBestWindowIndices(List<double> matchScores,
    {double minScore = 0.5}) {
  if (matchScores.isEmpty) return null;

  final runs = <(int, int)>[];
  int? runStart;

  for (var i = 0; i < matchScores.length; i++) {
    if (matchScores[i] >= minScore) {
      runStart ??= i;
    } else {
      if (runStart != null) {
        runs.add((runStart, i - 1));
        runStart = null;
      }
    }
  }
  if (runStart != null) runs.add((runStart, matchScores.length - 1));

  if (runs.isEmpty) return null;

  BestWindowIndices? best;
  var bestAvg = -1.0;
  for (final (start, end) in runs) {
    var sum = 0.0;
    for (var i = start; i <= end; i++) {
      sum += matchScores[i];
    }
    final avg = sum / (end - start + 1);
    if (avg > bestAvg) {
      bestAvg = avg;
      best = BestWindowIndices(start, end, avg);
    }
  }

  return best;
}

/// Find the best surfing window across all days
TopWindow? findBestWindow(
  List<HourlyData> hourlyData,
  UserPrefs prefs,
  Location location, {
  TideRange? tideRange,
}) {
  final windows = findTopWindows(hourlyData, prefs, location,
      count: 1, tideRange: tideRange);
  return windows.isNotEmpty ? windows.first : null;
}

// Internal mutable helper for building windows
class _RawWindow {
  final String date;
  final String startTime;
  String endTime;
  final List<double> scores;
  final double? waveHeight;

  _RawWindow({
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.scores,
    this.waveHeight,
  });
}
