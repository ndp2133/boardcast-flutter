/// Condition scoring engine — v2.2 port of utils/conditions.js
/// Multiplicative wind model, multi-swell directional energy, peak period blend, break-specific parameters.
/// Key difference from JS: Location + TideRange passed explicitly (no global state).
import 'dart:math';
import '../models/hourly_data.dart';
import '../models/location.dart';
import '../models/user_prefs.dart';
import 'units.dart' show metersToFeet;
import 'time_utils.dart' show formatHour;

// Surfable daylight hours — shared constant
const daylightStart = 6; // 6 AM
const daylightEnd = 21; // 9 PM

// Condition label thresholds
const _epicThreshold = 0.85;
const _goodThreshold = 0.6;
const _fairThreshold = 0.4;

// Break-type defaults for spot-specific scoring parameters
const _breakDefaults = <String, _SpotParams>{
  'beach': _SpotParams(
      swellWindowWidth: 120,
      tideSensitivity: 0.3,
      windExposure: 0.8,
      minWaveEnergy: 2.3),
  'point': _SpotParams(
      swellWindowWidth: 60,
      tideSensitivity: 0.5,
      windExposure: 0.5,
      minWaveEnergy: 4.6),
  'reef': _SpotParams(
      swellWindowWidth: 70,
      tideSensitivity: 0.9,
      windExposure: 0.6,
      minWaveEnergy: 7.0),
};

// Base score component weights (sum to 1.0)
const _baseWeightHeight = 0.40;
const _baseWeightSwellDir = 0.30;
const _baseWeightSwellQuality = 0.30;

// Skill-based wind sensitivity: scales penalties only (not offshore bonus)
const _windSensitivity = <String, double>{
  'beginner': 1.3,
  'intermediate': 1.0,
  'advanced': 0.75,
};

// Power thresholds by skill for safety cap (H^2 x T)
const _powerThreshold = <String, double>{
  'beginner': 18,
  'intermediate': 46,
  'advanced': double.infinity,
};

// Dynamic taglines
const _taglines = <String, List<String>>{
  'epic': [
    "Rare alignment — don't miss it",
    'About as good as it gets here',
    'Drop everything and go',
  ],
  'good': [
    'Solid session ahead',
    'Worth getting wet',
    'Conditions are dialed',
  ],
  'fair': [
    'Rideable, not ideal',
    'Fun if you lower expectations',
    'Better than the couch',
  ],
  'poor': [
    'Save your energy',
    'Not worth the paddle',
    'Check back later',
  ],
};

class _SpotParams {
  final double swellWindowWidth;
  final double tideSensitivity;
  final double windExposure;
  final double minWaveEnergy;
  const _SpotParams({
    required this.swellWindowWidth,
    required this.tideSensitivity,
    required this.windExposure,
    required this.minWaveEnergy,
  });
}

_SpotParams _getSpotParams(Location location) {
  final defaults = _breakDefaults[location.breakType] ?? _breakDefaults['beach']!;
  return _SpotParams(
    swellWindowWidth:
        location.swellWindowWidth ?? defaults.swellWindowWidth,
    tideSensitivity:
        location.tideSensitivity ?? defaults.tideSensitivity,
    windExposure: location.windExposure ?? defaults.windExposure,
    minWaveEnergy: location.minWaveEnergy ?? defaults.minWaveEnergy,
  );
}

// --- Wind angle helpers ---

/// Check if a wind degree falls within a range, handling wrap-around at 360
bool _inWindRange(double deg, double rangeMin, double rangeMax) {
  if (rangeMin <= rangeMax) return deg >= rangeMin && deg <= rangeMax;
  // Wrap-around (e.g., 315 to 45 crosses 0)
  return deg >= rangeMin || deg <= rangeMax;
}

bool isOffshoreWind(double windDegrees, Location location) {
  return _inWindRange(windDegrees, location.offshoreMin, location.offshoreMax);
}

bool isOnshoreWind(double windDegrees, Location location) {
  return _inWindRange(windDegrees, location.onshoreMin, location.onshoreMax);
}

/// Center angle of a min/max range (handles wrap-around at 360)
double rangeCenterAngle(double rangeMin, double rangeMax) {
  if (rangeMin <= rangeMax) return (rangeMin + rangeMax) / 2;
  return ((rangeMin + rangeMax + 360) / 2) % 360;
}

/// Shortest angular distance between two bearings (0-180)
double angularDistance(double a, double b) {
  final diff = (a - b).abs() % 360;
  return diff > 180 ? 360 - diff : diff;
}

// --- Multi-swell directional energy (H^2 x peakPeriod x dirFit) ---

double _effectiveSwellEnergy(
    HourlyData hourData, Location location, _SpotParams spotParams) {
  final swells = [
    (
      h: hourData.swellHeight,
      p: hourData.swellPeakPeriod ?? hourData.swellPeriod,
      d: hourData.swellDirection,
    ),
    (
      h: hourData.secondarySwellHeight,
      p: hourData.secondarySwellPeakPeriod ?? hourData.secondarySwellPeriod,
      d: hourData.secondarySwellDirection,
    ),
  ];
  var total = 0.0;
  for (final s in swells) {
    if (s.h == null || s.p == null || s.h == 0 || s.p == 0) continue;
    if (s.h! < 0.25) continue; // guardrail: filter noise
    final dirFit = s.d != null
        ? _scoreSwellDirection(s.d, location, spotParams)
        : 0.5;
    total += s.h! * s.h! * s.p! * dirFit;
  }
  return total;
}

// --- Component scoring ---

/// Wave height match against user preferences (0-1)
/// Decay scaled by range width; too-big penalizes harder than too-small
double _scoreWaveHeight(double? wh, UserPrefs prefs) {
  if (wh == null || prefs.minWaveHeight == null || prefs.maxWaveHeight == null) {
    return 0.5;
  }
  if (wh >= prefs.minWaveHeight! && wh <= prefs.maxWaveHeight!) return 1.0;
  final rangeWidth = max(0.3, prefs.maxWaveHeight! - prefs.minWaveHeight!);
  if (wh < prefs.minWaveHeight!) {
    // Too small: linear decay proportional to range width
    final dist = prefs.minWaveHeight! - wh;
    return max(0.0, 1 - dist / rangeWidth);
  }
  // Too big: steeper decay (1.5x penalty) — oversized surf is worse than undersized
  final dist = wh - prefs.maxWaveHeight!;
  return max(0.0, 1 - 1.5 * dist / rangeWidth);
}

/// Swell quality based on peak period blend (0-1): longer period = more powerful, better shaped waves
/// Uses 80% peak period + 20% mean period for quality scoring
double _scoreSwellQuality(HourlyData hourData) {
  final peak = hourData.swellPeakPeriod ?? hourData.swellPeriod ?? 0;
  final meanPeriod = hourData.swellPeriod ?? peak;
  // Ignore peak period when swell is too small to measure reliably
  final h = hourData.swellHeight ?? hourData.waveHeight ?? 0;
  final period = (h >= 0.25 && peak > 0 && meanPeriod > 0)
      ? 0.8 * peak + 0.2 * meanPeriod
      : (meanPeriod > 0 ? meanPeriod : peak);
  if (period >= 14) return 1.0;
  if (period >= 12) return 0.85;
  if (period >= 10) return 0.65;
  if (period >= 8) return 0.45;
  if (period >= 6) return 0.25;
  if (period > 0) return 0.1;
  return 0;
}

/// Swell direction match (0-1) with per-spot swell window width
double _scoreSwellDirection(
    double? sd, Location location, _SpotParams spotParams) {
  if (sd == null) return 0.5;

  var diff = (sd - location.beachFacing).abs();
  if (diff > 180) diff = 360 - diff;

  final halfWindow = spotParams.swellWindowWidth / 2;
  final sweetSpot = halfWindow * 0.3;

  // Within sweet spot: perfect
  if (diff <= sweetSpot) return 1.0;

  // Outside window: drops quickly toward 0
  if (diff >= halfWindow) {
    final overshoot = diff - halfWindow;
    return max(0.0, 0.3 * (1 - overshoot / 90));
  }

  // Within window but outside sweet spot: linear decay from 1.0 to 0.3
  final t = (diff - sweetSpot) / (halfWindow - sweetSpot);
  return 1.0 - 0.7 * t;
}

/// Wind multiplier (floor-1.0): wind degrades wave quality.
/// Uses maxWindSpeed as threshold, skill as slope beyond that.
/// Offshore bonus is objective (not skill-scaled). Penalties are skill-scaled.
double _scoreWind(HourlyData hourData, Location location,
    _SpotParams spotParams, String? skillLevel, double? maxWindTolerance) {
  final ws = hourData.windSpeed;
  final gusts = hourData.windGusts;
  final wd = hourData.windDirection;
  final exposure = spotParams.windExposure;
  final sensitivity = _windSensitivity[skillLevel] ?? 1.0;

  // Exposure-conditional floor: 0.15 for fully exposed, 0.25 for sheltered
  final floor = 0.15 + 0.10 * (1 - exposure);

  if (ws == null) return 0.7;

  // Speed penalty: excess wind beyond user's tolerance, skill as slope
  final baseDecay = 0.012 + 0.006 * exposure;
  double speedFactor;
  if (maxWindTolerance != null && ws > maxWindTolerance) {
    final excess = ws - maxWindTolerance;
    final basePenalty = maxWindTolerance * baseDecay * 0.5;
    final excessPenalty = excess * baseDecay * sensitivity;
    speedFactor = max(floor, 1.0 - basePenalty - excessPenalty);
  } else {
    // Below tolerance: light objective decay (not skill-scaled)
    speedFactor = max(floor, 1.0 - ws * baseDecay * 0.5);
  }

  // Gust penalty: gusty conditions are worse than steady wind (skill-scaled)
  double gustPenalty = 0;
  if (gusts != null && gusts > ws + 5) {
    gustPenalty = min(0.15, (gusts - ws) * 0.004 * sensitivity);
  }

  // Direction: offshore bonus is objective, onshore penalty is skill-scaled
  double dirMod = 0;
  if (wd != null) {
    final offshoreCenter =
        rangeCenterAngle(location.offshoreMin, location.offshoreMax);
    final dist = angularDistance(wd, offshoreCenter);
    final offshoreness = cos(dist * pi / 180);
    dirMod = offshoreness > 0
        ? offshoreness * 0.08 // objective cleanup benefit
        : offshoreness * 0.15 * exposure * sensitivity; // skill-sensitive downside
  }

  return min(1.0, max(floor, speedFactor - gustPenalty + dirMod));
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

/// Tide modifier: break-specific fit + personal preference (-0.15 to +0.08)
double _scoreTide(double? tideHeight, UserPrefs prefs, Location location,
    _SpotParams spotParams, TideRange? range) {
  if (tideHeight == null) return 0;
  if (range == null) return 0;

  final span = range.max - range.min;
  if (span == 0) return 0;

  // Normalize: 0 = low tide, 1 = high tide
  final n = (tideHeight - range.min) / span;
  final sensitivity = spotParams.tideSensitivity;

  // Break-specific tide fit (objective)
  double breakFit = 0;
  if (location.breakType == 'reef') {
    if (n > 0.8) {
      breakFit = -0.15 * sensitivity;
    } else if (n > 0.6) {
      breakFit = -0.08 * sensitivity;
    } else if (n < 0.15) {
      breakFit = -0.05 * sensitivity;
    } else {
      breakFit = 0.03 * sensitivity;
    }
  } else if (location.breakType == 'point') {
    if (n > 0.8) {
      breakFit = -0.06 * sensitivity;
    } else if (n < 0.3) {
      breakFit = 0.02 * sensitivity;
    }
  }

  // Personal preference ("any" = no modifier, no free points)
  double prefMod = 0;
  final prefTide = prefs.preferredTide;
  if (prefTide != null && prefTide != 'any') {
    if (prefTide == 'low') {
      prefMod = (0.5 - n) * 0.08;
    } else if (prefTide == 'high') {
      prefMod = (n - 0.5) * 0.08;
    } else if (prefTide == 'mid') {
      prefMod = (1.0 - 2.0 * (n - 0.5).abs()) * 0.06;
    }
  }

  return breakFit + prefMod;
}

// --- Main scoring function ---

/// Reference prefs for "pro perspective" comparison score
const proPrefs = UserPrefs(
  skillLevel: 'advanced',
  minWaveHeight: 1.2,
  maxWaveHeight: 4.0,
  maxWindSpeed: 50,
  preferredTide: 'any',
);

/// Compute match score (0-1) for an hour of conditions against user preferences.
/// [location] is passed explicitly to keep this function pure.
/// [tideRange] is the min/max tide heights for normalization (from cached API data).
/// [weightOverrides] optionally replaces base component weights (height, swellDir, swellQuality).
double computeMatchScore(
  HourlyData? hourData,
  UserPrefs? prefs,
  Location location, {
  TideRange? tideRange,
  Map<String, double>? weightOverrides,
}) {
  if (hourData == null || prefs == null) return 0;

  final spotParams = _getSpotParams(location);

  // Base quality components
  final heightScore = _scoreWaveHeight(hourData.waveHeight, prefs);
  final qualityScore = _scoreSwellQuality(hourData);
  final dirScore =
      _scoreSwellDirection(hourData.swellDirection, location, spotParams);

  // Use custom weights if provided, then prefs.weights, else base weights
  final effectiveWeights = weightOverrides ?? prefs.weights;
  final wH = effectiveWeights?['height'] ?? _baseWeightHeight;
  final wD = effectiveWeights?['swellDir'] ?? _baseWeightSwellDir;
  final wQ = effectiveWeights?['swellQuality'] ?? _baseWeightSwellQuality;

  final baseScore = wH * heightScore +
      wD * dirScore +
      wQ * qualityScore;

  // Wind multiplier (threshold + skill as slope)
  final windMult = _scoreWind(
      hourData, location, spotParams, prefs.skillLevel, prefs.maxWindSpeed);

  // Tide modifier
  final tideMod =
      _scoreTide(hourData.tideHeight, prefs, location, spotParams, tideRange);

  var score = baseScore * windMult + tideMod;

  // --- Hard caps (applied after main calculation) ---

  final energy = _effectiveSwellEnergy(hourData, location, spotParams);

  // Minimum energy: spot isn't "turned on"
  if (energy > 0 && energy < spotParams.minWaveEnergy) {
    score = min(_fairThreshold - 0.01, score);
  }

  // Overpowered / oversized safety cap
  final powerCap = _powerThreshold[prefs.skillLevel] ?? double.infinity;
  final wh = hourData.waveHeight;
  if (powerCap < double.infinity && energy > powerCap) {
    score = min(_fairThreshold - 0.01, score);
  }
  if (prefs.maxWaveHeight != null && wh != null) {
    if (wh > prefs.maxWaveHeight! * 1.6 && prefs.skillLevel == 'beginner') {
      score = min(0.25, score);
    } else if (wh > prefs.maxWaveHeight! * 1.35 && energy > powerCap * 0.7) {
      score = min(_fairThreshold - 0.01, score);
    }
  }

  // Thunderstorm/lightning hard cap (safety)
  if (hourData.weatherCode != null && hourData.weatherCode! >= 95) {
    score = min(0.25, score);
  }

  // Strong onshore hard cap (>30 km/h onshore -> max Fair at exposed, max Good elsewhere)
  if (hourData.windSpeed != null &&
      hourData.windDirection != null &&
      isOnshoreWind(hourData.windDirection!, location) &&
      hourData.windSpeed! > 30) {
    final onshoreCap = spotParams.windExposure >= 0.7
        ? _fairThreshold - 0.01
        : _goodThreshold + 0.05;
    score = min(onshoreCap, score);
  }

  // Wrong tide at tide-sensitive spots: hard cap
  if (spotParams.tideSensitivity >= 0.7 && hourData.tideHeight != null) {
    if (tideRange != null && tideRange.max - tideRange.min > 0) {
      final n =
          (hourData.tideHeight! - tideRange.min) / (tideRange.max - tideRange.min);
      if (n > 0.85 && location.breakType == 'reef') {
        score = min(_fairThreshold - 0.01, score);
      } else if (n > 0.9) {
        score = min(_fairThreshold - 0.01, score);
      }
    }
  }

  return min(1.0, max(0.0, score));
}

/// Condition label result
class ConditionLabel {
  final String label;
  final String cssClass;
  final String color;
  final String tagline;

  const ConditionLabel(this.label, this.cssClass, this.color, this.tagline);
}

String _pickTagline(String cls, double score) {
  final lines = _taglines[cls]!;
  final idx = (score * 100).floor() % lines.length;
  return lines[idx];
}

ConditionLabel getConditionLabel(double score) {
  if (score >= _epicThreshold) {
    return ConditionLabel(
        'Epic', 'epic', '#2e8a5e', _pickTagline('epic', score));
  }
  if (score >= _goodThreshold) {
    return ConditionLabel(
        'Good', 'good', '#3d9189', _pickTagline('good', score));
  }
  if (score >= _fairThreshold) {
    return ConditionLabel(
        'Fair', 'fair', '#b07a4f', _pickTagline('fair', score));
  }
  return ConditionLabel(
      'Poor', 'poor', '#9e5e5e', _pickTagline('poor', score));
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
  Map<String, double>? weightOverrides,
}) {
  final dayHours = hourlyData.where((h) => h.time.startsWith(date)).toList();
  var bestScore = 0.0;
  HourlyData? bestHour;

  for (final hour in dayHours) {
    final score =
        computeMatchScore(hour, prefs, location, tideRange: tideRange, weightOverrides: weightOverrides);
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
  Map<String, double>? weightOverrides,
}) {
  final windows = <MatchingWindow>[];
  String? currentStart;
  String? currentEnd;
  double currentAvgScore = 0;
  int currentCount = 0;

  for (final hour in hourlyData) {
    final score =
        computeMatchScore(hour, prefs, location, tideRange: tideRange, weightOverrides: weightOverrides);
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
  Map<String, double>? weightOverrides,
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
    // Two-pass: compute all scores, then find windows with relative threshold
    final hourScores = <(HourlyData, double)>[];
    for (final h in entry.value) {
      final score =
          computeMatchScore(h, prefs, location, tideRange: tideRange, weightOverrides: weightOverrides);
      hourScores.add((h, score));
    }

    // Relative threshold: adapts to day quality
    final peakScore = hourScores.isEmpty
        ? 0.0
        : hourScores.map((e) => e.$2).reduce((a, b) => a > b ? a : b);
    final threshold = peakScore > 0.65 ? peakScore - 0.15 : 0.5;

    _RawWindow? currentWindow;

    for (final (h, score) in hourScores) {
      if (score >= threshold) {
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

  // Narrow oversized windows: if > 5 hours, find best 3-hour sub-window
  const maxWindowHours = 5;
  const slidingWindowSize = 3;
  for (var i = 0; i < scored.length; i++) {
    final w = scored[i].window;
    if (w.scores.length > maxWindowHours) {
      var bestStart = 0;
      var bestAvg = -1.0;
      for (var j = 0; j <= w.scores.length - slidingWindowSize; j++) {
        var sum = 0.0;
        for (var k = j; k < j + slidingWindowSize; k++) {
          sum += w.scores[k];
        }
        final avg = sum / slidingWindowSize;
        if (avg > bestAvg) {
          bestAvg = avg;
          bestStart = j;
        }
      }
      final baseHour = int.parse(w.startTime.split('T')[1].split(':')[0]);
      final newStartHour = baseHour + bestStart;
      final newEndHour = newStartHour + slidingWindowSize - 1;
      final datePart = w.startTime.split('T')[0];
      w.startTime = '$datePart'
          'T${newStartHour.toString().padLeft(2, '0')}:00';
      w.endTime = '$datePart'
          'T${newEndHour.toString().padLeft(2, '0')}:00';
      w.scores.replaceRange(
          0, w.scores.length, w.scores.sublist(bestStart, bestStart + slidingWindowSize));
    }
  }

  // Deduplicate: max one per day
  final seen = <String>{};
  final result = <TopWindow>[];
  for (final s in scored) {
    if (!seen.contains(s.window.date)) {
      seen.add(s.window.date);
      final avg =
          s.window.scores.reduce((a, b) => a + b) / s.window.scores.length;
      result.add(TopWindow(
        date: s.window.date,
        startTime: s.window.startTime,
        endTime: s.window.endTime,
        avgScore: avg,
        hours: s.window.scores.length,
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

  // Relative threshold: adapts to day quality
  final peakScore = matchScores.reduce((a, b) => a > b ? a : b);
  final threshold = peakScore > 0.65 ? peakScore - 0.15 : minScore;

  final runs = <(int, int)>[];
  int? runStart;

  for (var i = 0; i < matchScores.length; i++) {
    if (matchScores[i] >= threshold) {
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
    // Cap oversized windows: find best 3-hour sub-window
    var effectiveStart = start;
    var effectiveEnd = end;
    if (end - start + 1 > 5) {
      const slideSize = 3;
      var slideBestAvg = -1.0;
      for (var j = start; j <= end - slideSize + 1; j++) {
        var sum = 0.0;
        for (var k = j; k < j + slideSize; k++) {
          sum += matchScores[k];
        }
        final avg = sum / slideSize;
        if (avg > slideBestAvg) {
          slideBestAvg = avg;
          effectiveStart = j;
          effectiveEnd = j + slideSize - 1;
        }
      }
    }

    var sum = 0.0;
    for (var i = effectiveStart; i <= effectiveEnd; i++) {
      sum += matchScores[i];
    }
    final avg = sum / (effectiveEnd - effectiveStart + 1);
    if (avg > bestAvg) {
      bestAvg = avg;
      best = BestWindowIndices(effectiveStart, effectiveEnd, avg);
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
  Map<String, double>? weightOverrides,
}) {
  final windows = findTopWindows(hourlyData, prefs, location,
      count: 1, tideRange: tideRange, weightOverrides: weightOverrides);
  return windows.isNotEmpty ? windows.first : null;
}

// --- Confidence meter ---

class Confidence {
  final String level; // 'high', 'medium', 'low'
  final String reason;
  const Confidence(this.level, this.reason);
}

Confidence computeConfidence(List<HourlyData> hourlyData, HourlyData? current) {
  if (current == null || hourlyData.isEmpty) {
    return const Confidence('medium', 'Limited data');
  }

  final nowStr = DateTime.now().toIso8601String().substring(0, 13);
  final futureHours =
      hourlyData.where((h) => h.time.compareTo(nowStr) >= 0).take(6).toList();
  if (futureHours.length < 3) {
    return const Confidence('medium', 'Limited forecast window');
  }

  var signals = 0;
  var total = 0.0;
  final reasons = <String>[];

  // 1. Wind speed stability (coefficient of variation)
  final windSpeeds =
      futureHours.map((h) => h.windSpeed).whereType<double>().toList();
  if (windSpeeds.length >= 3) {
    final mean = windSpeeds.reduce((a, b) => a + b) / windSpeeds.length;
    final variance =
        windSpeeds.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
            windSpeeds.length;
    final cv = sqrt(variance) / (mean == 0 ? 1 : mean);
    signals++;
    if (cv < 0.15) {
      total += 1;
      reasons.add('stable wind');
    } else if (cv < 0.3) {
      total += 0.6;
    } else {
      total += 0.2;
      reasons.add('variable wind');
    }
  }

  // 2. Wind direction consistency
  final windDirs =
      futureHours.map((h) => h.windDirection).whereType<double>().toList();
  if (windDirs.length >= 3) {
    final spreads = <double>[];
    for (var i = 1; i < windDirs.length; i++) {
      var diff = (windDirs[i] - windDirs[i - 1]).abs();
      if (diff > 180) diff = 360 - diff;
      spreads.add(diff);
    }
    final avgSpread = spreads.reduce((a, b) => a + b) / spreads.length;
    signals++;
    if (avgSpread < 15) {
      total += 1;
    } else if (avgSpread < 40) {
      total += 0.6;
    } else {
      total += 0.2;
      reasons.add('wind shift expected');
    }
  }

  // 3. Swell clarity (primary vs secondary)
  if (current.swellHeight != null) {
    final primary = current.swellHeight!;
    final secondary = current.secondarySwellHeight ?? 0;
    final ratio = primary / (primary + secondary == 0 ? 1 : primary + secondary);
    signals++;
    if (ratio > 0.75) {
      total += 1;
      reasons.add('clean swell signal');
    } else if (ratio > 0.5) {
      total += 0.6;
      reasons.add('mixed swell');
    } else {
      total += 0.25;
      reasons.add('confused swell');
    }
  }

  // 4. Swell period (longer = more predictable)
  final period = current.swellPeakPeriod ?? current.swellPeriod;
  if (period != null) {
    signals++;
    if (period >= 12) {
      total += 1;
    } else if (period >= 8) {
      total += 0.6;
    } else {
      total += 0.3;
      reasons.add('short-period windswell');
    }
  }

  // 5. Weather stability
  final stormHours =
      futureHours.where((h) => h.weatherCode != null && h.weatherCode! >= 80);
  if (stormHours.isNotEmpty) {
    signals++;
    total += 0.1;
    reasons.add('storms possible');
  }

  final confidence = signals > 0 ? total / signals : 0.5;

  if (confidence >= 0.75) {
    final goodReasons = reasons
        .where((r) =>
            !r.contains('variable') &&
            !r.contains('shift') &&
            !r.contains('confused') &&
            !r.contains('storm') &&
            !r.contains('short'))
        .take(2)
        .toList();
    return Confidence(
        'high', goodReasons.isEmpty ? 'Stable conditions' : goodReasons.join(', '));
  }
  if (confidence >= 0.45) {
    return Confidence(
        'medium', reasons.isEmpty ? 'Mixed signals' : reasons.take(2).join(', '));
  }
  return Confidence(
      'low',
      reasons.isEmpty ? 'Uncertain conditions' : reasons.take(2).join(', '));
}

// --- Expected vs Potential ---

class ExpectedVsPotential {
  final double expectedScore;
  final String expectedDescription;
  final double potentialScore;
  final String potentialDescription;
  const ExpectedVsPotential({
    required this.expectedScore,
    required this.expectedDescription,
    required this.potentialScore,
    required this.potentialDescription,
  });
}

String _waveSizeWord(double ft) {
  if (ft < 1) return 'ankle-high';
  if (ft < 2.5) return 'knee-to-waist';
  if (ft < 4) return 'waist-to-chest';
  if (ft < 6) return 'head-high';
  return 'overhead';
}

String _textureWord(HourlyData? h, Location location) {
  if (h == null || h.windSpeed == null) return '';
  if (h.windSpeed! < 8) return 'clean';
  if (h.windDirection != null && isOffshoreWind(h.windDirection!, location)) {
    return 'groomed';
  }
  if (h.windSpeed! < 20) return 'textured';
  return 'bumpy';
}

ExpectedVsPotential? computeExpectedVsPotential(
  List<HourlyData> hourlyData,
  UserPrefs prefs,
  Location location, {
  TideRange? tideRange,
  Map<String, double>? weightOverrides,
}) {
  final todayDate = DateTime.now().toIso8601String().split('T')[0];
  final nowStr = DateTime.now().toIso8601String().substring(0, 13);

  final todayFuture = hourlyData.where((h) {
    if (!h.time.startsWith(todayDate)) return false;
    final hour = int.parse(h.time.split('T')[1].split(':')[0]);
    return hour >= daylightStart && hour <= daylightEnd && h.time.compareTo(nowStr) >= 0;
  }).toList();

  if (todayFuture.isEmpty) return null;

  // Expected: average of next 3 hours
  final next3 = todayFuture.take(3).toList();
  final expectedScores = next3
      .map((h) => computeMatchScore(h, prefs, location, tideRange: tideRange, weightOverrides: weightOverrides))
      .toList();
  final expectedScore =
      expectedScores.reduce((a, b) => a + b) / expectedScores.length;

  // Potential: best single hour today
  var potentialScore = 0.0;
  HourlyData? potentialHour;
  for (final h in todayFuture) {
    final s = computeMatchScore(h, prefs, location, tideRange: tideRange, weightOverrides: weightOverrides);
    if (s > potentialScore) {
      potentialScore = s;
      potentialHour = h;
    }
  }

  // Only show if potential is meaningfully better
  if (potentialScore - expectedScore < 0.08) return null;

  final avgWave =
      next3.map((h) => metersToFeet(h.waveHeight ?? 0)).reduce((a, b) => a + b) /
          next3.length;
  final potentialWave =
      potentialHour != null ? metersToFeet(potentialHour.waveHeight ?? 0) : avgWave;

  final expectedTexture = _textureWord(next3.first, location);
  final potentialTexture =
      potentialHour != null ? _textureWord(potentialHour, location) : '';

  final expectedDesc =
      '${_waveSizeWord(avgWave)}${expectedTexture.isNotEmpty ? ', $expectedTexture' : ''}';

  final potentialTime = potentialHour != null
      ? formatHour(potentialHour.time)
      : '';
  final potentialDesc =
      '${_waveSizeWord(potentialWave)}${potentialTexture.isNotEmpty ? ' $potentialTexture' : ''} sets${potentialTime.isNotEmpty ? ' around $potentialTime' : ''}';

  return ExpectedVsPotential(
    expectedScore: expectedScore,
    expectedDescription: expectedDesc,
    potentialScore: potentialScore,
    potentialDescription: potentialDesc,
  );
}

// --- Forecast Accuracy ---

class ForecastAccuracy {
  final int matched;
  final int total;
  final int pct;
  const ForecastAccuracy(this.matched, this.total, this.pct);
}

ForecastAccuracy? computeForecastAccuracy(List<dynamic> sessions) {
  final calibrated = sessions.where((s) =>
      s.status == 'completed' && s.calibration != null).toList();
  if (calibrated.length < 3) return null;

  final matched = calibrated.where((s) => s.calibration == 0).length;
  final total = calibrated.length;
  final pct = (matched / total * 100).round();

  return ForecastAccuracy(matched, total, pct);
}

// Internal mutable helper for building windows
class _RawWindow {
  final String date;
  String startTime;
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
