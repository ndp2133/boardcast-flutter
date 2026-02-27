/// Condition scoring engine — direct port of utils/conditions.js
/// Key difference from JS: Location is passed explicitly (no global state).
import 'dart:math';
import '../models/hourly_data.dart';
import '../models/location.dart';
import '../models/user_prefs.dart';
import 'units.dart';
import 'time_utils.dart';

// Surfable daylight hours — shared constant
const daylightStart = 6; // 6 AM
const daylightEnd = 21; // 9 PM

// Scoring weights (must sum to 1.0)
const _scoreWeights = (wave: 0.40, wind: 0.30, windDir: 0.15, swellDir: 0.15);

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

/// Compute match score (0-1) for an hour of conditions against user preferences.
/// [location] is passed explicitly to keep this function pure.
double computeMatchScore(
    HourlyData? hourData, UserPrefs? prefs, Location location) {
  if (hourData == null || prefs == null) return 0;

  var score = 0.0;

  // Wave height score
  final wh = hourData.waveHeight;
  if (wh != null && prefs.minWaveHeight != null && prefs.maxWaveHeight != null) {
    if (wh >= prefs.minWaveHeight! && wh <= prefs.maxWaveHeight!) {
      score += _scoreWeights.wave * 1.0;
    } else {
      final dist = wh < prefs.minWaveHeight!
          ? prefs.minWaveHeight! - wh
          : wh - prefs.maxWaveHeight!;
      score += _scoreWeights.wave *
          max(0.0, 1 - dist / prefs.maxWaveHeight!);
    }
  }

  // Wind speed score
  final ws = hourData.windSpeed;
  if (ws != null && prefs.maxWindSpeed != null) {
    if (ws <= prefs.maxWindSpeed!) {
      score += _scoreWeights.wind * 1.0;
    } else {
      score += _scoreWeights.wind *
          max(0.0, 1 - (ws - prefs.maxWindSpeed!) / prefs.maxWindSpeed!);
    }
  }

  // Wind direction score
  final wd = hourData.windDirection;
  if (wd != null &&
      prefs.preferredWindDir != null &&
      prefs.preferredWindDir != 'any') {
    if (prefs.preferredWindDir == 'offshore') {
      score +=
          _scoreWeights.windDir * (isOffshoreWind(wd, location) ? 1.0 : 0.3);
    } else if (prefs.preferredWindDir == 'onshore') {
      score +=
          _scoreWeights.windDir * (isOnshoreWind(wd, location) ? 1.0 : 0.3);
    }
  } else {
    score += _scoreWeights.windDir;
  }

  // Swell direction score
  final sd = hourData.swellDirection;
  if (sd != null) {
    var diff = (sd - location.beachFacing).abs();
    if (diff > 180) diff = 360 - diff;
    final diffRad = diff * pi / 180;
    score += _scoreWeights.swellDir * max(0.0, cos(diffRad));
  } else {
    score += _scoreWeights.swellDir * 0.5;
  }

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
  String date,
) {
  final dayHours = hourlyData.where((h) => h.time.startsWith(date)).toList();
  var bestScore = 0.0;
  HourlyData? bestHour;

  for (final hour in dayHours) {
    final score = computeMatchScore(hour, prefs, location);
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
}) {
  final windows = <MatchingWindow>[];
  String? currentStart;
  String? currentEnd;
  double currentAvgScore = 0;
  int currentCount = 0;

  for (final hour in hourlyData) {
    final score = computeMatchScore(hour, prefs, location);
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
      final score = computeMatchScore(h, prefs, location);
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
  Location location,
) {
  final windows = findTopWindows(hourlyData, prefs, location, count: 1);
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
