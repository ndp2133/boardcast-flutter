/// Shared condition state computation — used by both widget_service and
/// live_activity_provider to avoid duplicating score/label/wind logic.
import '../models/merged_conditions.dart';
import '../models/hourly_data.dart';
import '../models/user_prefs.dart';
import '../models/location.dart';
import '../logic/scoring.dart';
import '../logic/units.dart';

class ConditionState {
  final int score;
  final String label;
  final String waveHeight;
  final String windSpeed;
  final String windDir;
  final String windContext;
  final String bestWindowRange;
  final String bestWindowLabel;
  final String verdict;
  final String trend; // '↑' improving, '→' steady, '↓' declining

  const ConditionState({
    required this.score,
    required this.label,
    required this.waveHeight,
    required this.windSpeed,
    required this.windDir,
    required this.windContext,
    required this.bestWindowRange,
    required this.bestWindowLabel,
    required this.verdict,
    required this.trend,
  });
}

/// Compute current conditions state from merged data + preferences.
ConditionState buildConditionState({
  required MergedConditions conditions,
  required UserPrefs prefs,
  required Location location,
}) {
  final now = DateTime.now();
  final currentHour = conditions.hourly.where((h) {
    final t = DateTime.parse(h.time);
    return t.year == now.year &&
        t.month == now.month &&
        t.day == now.day &&
        t.hour == now.hour;
  }).toList();

  final currentData = currentHour.isNotEmpty ? currentHour.first : null;
  final tideRange = TideRange.fromHourlyData(conditions.hourly);
  final score = computeMatchScore(currentData, prefs, location,
      tideRange: tideRange);
  final label = getConditionLabel(score);
  final scoreInt = (score * 100).round();

  final waveHeight = formatWaveHeight(conditions.current.waveHeight);
  final windSpeed = formatWindSpeed(conditions.current.windSpeed);
  final windDir = conditions.current.windDirection != null
      ? degreesToCardinal(conditions.current.windDirection!)
      : '--';
  final windContext = conditions.current.windDirection != null
      ? (isOffshoreWind(conditions.current.windDirection!, location)
          ? 'offshore'
          : isOnshoreWind(conditions.current.windDirection!, location)
              ? 'onshore'
              : 'cross')
      : '';

  final bestWindow = findBestWindow(conditions.hourly, prefs, location,
      tideRange: tideRange);
  String bestWindowRange = '';
  String bestWindowLabel = '';
  if (bestWindow != null) {
    final startDt = DateTime.parse(bestWindow.startTime);
    final endDt = DateTime.parse(bestWindow.endTime);
    bestWindowRange = '${_formatHour(startDt)}–${_formatHour(endDt)}';
    bestWindowLabel = getConditionLabel(bestWindow.avgScore).label;
  }

  // Compute 3-hour trend from hourly scores
  final trend = _computeTrend(conditions.hourly, prefs, location, tideRange);

  // Generate a short decisive verdict for the watch
  final verdict = _buildVerdict(
    scoreInt: scoreInt,
    label: label.label,
    windContext: windContext,
    bestWindowRange: bestWindowRange,
  );

  return ConditionState(
    score: scoreInt,
    label: label.label,
    waveHeight: waveHeight,
    windSpeed: windSpeed,
    windDir: windDir,
    windContext: windContext,
    bestWindowRange: bestWindowRange,
    bestWindowLabel: bestWindowLabel,
    verdict: verdict,
    trend: trend,
  );
}

/// Short decisive verdict for watch face — max ~25 chars.
String _buildVerdict({
  required int scoreInt,
  required String label,
  required String windContext,
  required String bestWindowRange,
}) {
  if (scoreInt >= 80) {
    return 'Get out there';
  }
  if (scoreInt >= 60) {
    if (windContext == 'offshore') return 'Clean and worth it';
    if (bestWindowRange.isNotEmpty) return 'Go at $bestWindowRange';
    return 'Worth a paddle';
  }
  if (scoreInt >= 40) {
    if (bestWindowRange.isNotEmpty) return 'Wait for $bestWindowRange';
    return 'Marginal, maybe skip';
  }
  return 'Give it a miss';
}

/// Compute 3-hour trend: compare current score to average of next 3 hours.
/// Returns '↑' (improving ≥5pts), '↓' (declining ≥5pts), or '→' (steady).
String _computeTrend(
  List<HourlyData> hourly,
  UserPrefs prefs,
  Location location,
  TideRange? tideRange,
) {
  final now = DateTime.now();
  // Find current hour and next 3 hours
  final upcoming = <double>[];
  double? currentScore;
  for (final h in hourly) {
    final t = DateTime.parse(h.time);
    if (t.isBefore(now.subtract(const Duration(minutes: 30)))) continue;
    final s = computeMatchScore(h, prefs, location, tideRange: tideRange);
    if (currentScore == null) {
      currentScore = s;
      continue;
    }
    upcoming.add(s);
    if (upcoming.length >= 3) break;
  }
  if (currentScore == null || upcoming.isEmpty) return '\u2192';
  final avgUpcoming = upcoming.reduce((a, b) => a + b) / upcoming.length;
  final delta = ((avgUpcoming - currentScore) * 100).round();
  if (delta >= 5) return '\u2191';
  if (delta <= -5) return '\u2193';
  return '\u2192';
}

String _formatHour(DateTime dt) {
  final hour = dt.hour;
  if (hour == 0) return '12am';
  if (hour < 12) return '${hour}am';
  if (hour == 12) return '12pm';
  return '${hour - 12}pm';
}
