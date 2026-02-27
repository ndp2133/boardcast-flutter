/// Surf IQ — personalized scoring engine — direct port of utils/surfiq.js
import 'dart:math';
import '../models/session.dart';
import '../models/user_prefs.dart';

const _levels = [
  (min: 0, label: 'Grom'),
  (min: 21, label: 'Paddler'),
  (min: 41, label: 'Local'),
  (min: 61, label: 'Waterman'),
  (min: 81, label: 'Soul Surfer'),
];

String _getLevel(int score) {
  for (var i = _levels.length - 1; i >= 0; i--) {
    if (score >= _levels[i].min) return _levels[i].label;
  }
  return _levels[0].label;
}

/// Pearson correlation between two lists of equal length
double _pearson(List<double> xs, List<double> ys) {
  final n = xs.length;
  if (n < 2) return 0;

  final meanX = xs.reduce((a, b) => a + b) / n;
  final meanY = ys.reduce((a, b) => a + b) / n;

  var num = 0.0;
  var denX = 0.0;
  var denY = 0.0;
  for (var i = 0; i < n; i++) {
    final dx = xs[i] - meanX;
    final dy = ys[i] - meanY;
    num += dx * dy;
    denX += dx * dx;
    denY += dy * dy;
  }

  final den = sqrt(denX * denY);
  if (den == 0) return 0;
  return num / den;
}

class SurfIQResult {
  final int score;
  final String level;
  final int totalSessions;
  final int calibratedSessions;
  final SurfIQBreakdown breakdown;

  const SurfIQResult({
    required this.score,
    required this.level,
    required this.totalSessions,
    required this.calibratedSessions,
    required this.breakdown,
  });
}

class SurfIQBreakdown {
  final double experience;
  final double calibration;
  final double consistency;

  const SurfIQBreakdown({
    required this.experience,
    required this.calibration,
    required this.consistency,
  });
}

/// Compute Surf IQ score from session history.
SurfIQResult computeSurfIQ(List<Session> sessions) {
  final completed = sessions.where((s) => s.status == 'completed').toList();
  final calibrated =
      completed.where((s) => s.calibration != null).toList();

  // Experience: min(completedSessions * 5, 30)
  final experience = min(completed.length * 5, 30).toDouble();

  // Calibration accuracy: % of "about right" (0) answers * 40
  var calibrationScore = 0.0;
  if (calibrated.isNotEmpty) {
    final aboutRight =
        calibrated.where((s) => s.calibration == 0).length;
    calibrationScore = (aboutRight / calibrated.length) * 40;
  }

  // Consistency: Pearson correlation between matchScore and rating * 30
  var consistency = 0.0;
  final withBoth = completed
      .where(
          (s) => s.rating != null && s.conditions?.matchScore != null)
      .toList();
  if (withBoth.length >= 2) {
    final scores = withBoth.map((s) => s.conditions!.matchScore!).toList();
    final ratings = withBoth.map((s) => s.rating! / 5.0).toList();
    final r = _pearson(scores, ratings);
    consistency = max(0.0, r) * 30;
  }

  final rawScore = (experience + calibrationScore + consistency).round();
  final clampedScore = rawScore.clamp(0, 100);

  return SurfIQResult(
    score: clampedScore,
    level: _getLevel(clampedScore),
    totalSessions: completed.length,
    calibratedSessions: calibrated.length,
    breakdown: SurfIQBreakdown(
      experience: experience,
      calibration: calibrationScore,
      consistency: consistency,
    ),
  );
}

/// Generate a textual insight from session history. Requires 3+ calibrated sessions.
String? generateInsight(List<Session> sessions) {
  final calibrated = sessions
      .where((s) => s.status == 'completed' && s.calibration != null)
      .toList();
  if (calibrated.length < 3) return null;

  final avgCalibration =
      calibrated.fold<double>(0, (s, c) => s + c.calibration!) /
          calibrated.length;

  if (avgCalibration > 0.3) {
    return 'You find conditions better than expected \u2014 forecast may be conservative for your style.';
  }
  if (avgCalibration < -0.3) {
    return 'Conditions often fall short of expectations \u2014 be more selective when planning.';
  }

  final withBoth = calibrated
      .where(
          (s) => s.rating != null && s.conditions?.matchScore != null)
      .toList();
  if (withBoth.length >= 3) {
    final scores = withBoth.map((s) => s.conditions!.matchScore!).toList();
    final ratings = withBoth.map((s) => s.rating! / 5.0).toList();
    final r = _pearson(scores, ratings);
    if (r > 0.5) {
      return 'Your ratings align well with forecasts \u2014 preferences are well-calibrated.';
    }
  }

  return 'Keep logging sessions to unlock deeper insights.';
}

class PreferenceNudge {
  final String type;
  final String message;
  final String prefKey;
  final double currentValue;
  final double suggestedValue;
  final String formatLabel;

  const PreferenceNudge({
    required this.type,
    required this.message,
    required this.prefKey,
    required this.currentValue,
    required this.suggestedValue,
    required this.formatLabel,
  });
}

/// Generate a preference nudge based on high-rated session patterns.
/// Requires 5+ calibrated sessions.
PreferenceNudge? generateNudge(List<Session> sessions, UserPrefs? prefs) {
  if (prefs == null) return null;

  final calibrated = sessions
      .where((s) => s.status == 'completed' && s.calibration != null)
      .toList();
  if (calibrated.length < 5) return null;

  final highRated =
      calibrated.where((s) => s.rating != null && s.rating! >= 4 && s.conditions != null).toList();
  if (highRated.length < 3) return null;

  final avgWave = highRated.fold<double>(
          0, (s, r) => s + (r.conditions!.waveHeight ?? 0)) /
      highRated.length;
  final avgWind = highRated.fold<double>(
          0, (s, r) => s + (r.conditions!.windSpeed ?? 0)) /
      highRated.length;

  // Check nudges in priority order
  if (prefs.maxWaveHeight != null && avgWave > prefs.maxWaveHeight! * 1.15) {
    final suggested = (avgWave * 10).round() / 10;
    return PreferenceNudge(
      type: 'maxWaveHeight',
      message:
          'Your best sessions had bigger waves than your max. Bump it up?',
      prefKey: 'maxWaveHeight',
      currentValue: prefs.maxWaveHeight!,
      suggestedValue: suggested,
      formatLabel: 'Max Wave Height',
    );
  }

  if (prefs.minWaveHeight != null && avgWave < prefs.minWaveHeight! * 0.85) {
    final suggested = (avgWave * 10).round() / 10;
    return PreferenceNudge(
      type: 'minWaveHeight',
      message: 'You rate smaller waves highly. Lower your minimum?',
      prefKey: 'minWaveHeight',
      currentValue: prefs.minWaveHeight!,
      suggestedValue: suggested,
      formatLabel: 'Min Wave Height',
    );
  }

  if (prefs.maxWindSpeed != null && avgWind > prefs.maxWindSpeed! * 1.2) {
    final suggested = avgWind.roundToDouble();
    return PreferenceNudge(
      type: 'maxWindSpeed',
      message:
          'You enjoy sessions with more wind than your limit. Increase it?',
      prefKey: 'maxWindSpeed',
      currentValue: prefs.maxWindSpeed!,
      suggestedValue: suggested,
      formatLabel: 'Max Wind Speed',
    );
  }

  return null;
}
