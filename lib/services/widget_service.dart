/// Home screen widget data service — writes pre-computed conditions
/// to shared UserDefaults via home_widget for the native WidgetKit extension.
import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import '../models/merged_conditions.dart';
import '../models/user_prefs.dart';
import '../models/location.dart';
import '../logic/scoring.dart';
import '../logic/units.dart';

const _appGroupId = 'group.com.boardcast.boardcastFlutter';
const _iOSWidgetName = 'BoardcastWidget';

class WidgetService {
  /// Call once at app startup.
  Future<void> init() async {
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  /// Write all widget data after a successful conditions fetch.
  /// The native SwiftUI widget reads these keys from shared UserDefaults.
  Future<void> updateWidgetData({
    required MergedConditions conditions,
    required UserPrefs prefs,
    required Location location,
  }) async {
    final now = DateTime.now();
    final currentHour = conditions.hourly.where((h) {
      final t = DateTime.parse(h.time);
      return t.year == now.year &&
          t.month == now.month &&
          t.day == now.day &&
          t.hour == now.hour;
    }).toList();

    // Current score
    final currentData = currentHour.isNotEmpty ? currentHour.first : null;
    final score = computeMatchScore(currentData, prefs, location);
    final label = getConditionLabel(score);

    // Current conditions formatted
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

    // Best window today
    final bestWindow = findBestWindow(conditions.hourly, prefs, location);

    // Build 18-hour score timeline starting from current hour
    // Each entry: { "h": hour (0-23), "s": score (0-100 int), "c": condition index (0-3) }
    final hourlyScores = <Map<String, dynamic>>[];
    for (var i = 0; i < conditions.hourly.length && hourlyScores.length < 18; i++) {
      final h = conditions.hourly[i];
      final t = DateTime.parse(h.time);
      if (t.isBefore(now.subtract(const Duration(hours: 1)))) continue;
      final s = computeMatchScore(h, prefs, location);
      final scoreInt = (s * 100).round();
      // Condition index: 0=epic, 1=good, 2=fair, 3=poor
      final cIdx = s >= 0.8 ? 0 : s >= 0.6 ? 1 : s >= 0.4 ? 2 : 3;
      hourlyScores.add({'h': t.hour, 's': scoreInt, 'c': cIdx});
    }

    // Write all keys
    await Future.wait([
      HomeWidget.saveWidgetData<int>('score', (score * 100).round()),
      HomeWidget.saveWidgetData<String>('conditionLabel', label.label),
      HomeWidget.saveWidgetData<String>('locationName', location.name),
      HomeWidget.saveWidgetData<String>('waveHeight', waveHeight),
      HomeWidget.saveWidgetData<String>('windSpeed', windSpeed),
      HomeWidget.saveWidgetData<String>('windDir', windDir),
      HomeWidget.saveWidgetData<String>('windContext', windContext),
      HomeWidget.saveWidgetData<String>('fetchedAt', conditions.fetchedAt.toIso8601String()),
      HomeWidget.saveWidgetData<String>('hourlyScores', jsonEncode(hourlyScores)),
      HomeWidget.saveWidgetData<String>(
        'bestWindowStart',
        bestWindow?.startTime ?? '',
      ),
      HomeWidget.saveWidgetData<String>(
        'bestWindowEnd',
        bestWindow?.endTime ?? '',
      ),
      HomeWidget.saveWidgetData<int>(
        'bestWindowScore',
        bestWindow != null ? (bestWindow.avgScore * 100).round() : 0,
      ),
      HomeWidget.saveWidgetData<String>(
        'bestWindowLabel',
        bestWindow != null ? getConditionLabel(bestWindow.avgScore).label : '',
      ),
    ]);

    // Tell WidgetKit to reload the timeline
    await HomeWidget.updateWidget(iOSName: _iOSWidgetName);
  }
}
