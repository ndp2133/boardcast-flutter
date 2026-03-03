/// Shared condition state computation — used by both widget_service and
/// live_activity_provider to avoid duplicating score/label/wind logic.
import '../models/merged_conditions.dart';
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

  const ConditionState({
    required this.score,
    required this.label,
    required this.waveHeight,
    required this.windSpeed,
    required this.windDir,
    required this.windContext,
    required this.bestWindowRange,
    required this.bestWindowLabel,
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
  final score = computeMatchScore(currentData, prefs, location);
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

  final bestWindow = findBestWindow(conditions.hourly, prefs, location);
  String bestWindowRange = '';
  String bestWindowLabel = '';
  if (bestWindow != null) {
    final startDt = DateTime.parse(bestWindow.startTime);
    final endDt = DateTime.parse(bestWindow.endTime);
    bestWindowRange = '${_formatHour(startDt)}–${_formatHour(endDt)}';
    bestWindowLabel = getConditionLabel(bestWindow.avgScore).label;
  }

  return ConditionState(
    score: scoreInt,
    label: label.label,
    waveHeight: waveHeight,
    windSpeed: windSpeed,
    windDir: windDir,
    windContext: windContext,
    bestWindowRange: bestWindowRange,
    bestWindowLabel: bestWindowLabel,
  );
}

String _formatHour(DateTime dt) {
  final hour = dt.hour;
  if (hour == 0) return '12am';
  if (hour < 12) return '${hour}am';
  if (hour == 12) return '12pm';
  return '${hour - 12}pm';
}
