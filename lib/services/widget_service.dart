/// Home screen widget data service — writes pre-computed conditions
/// to shared UserDefaults via home_widget for the native WidgetKit extension.
import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import '../models/merged_conditions.dart';
import '../models/user_prefs.dart';
import '../models/location.dart';
import '../logic/scoring.dart';
import '../logic/units.dart';
import 'condition_state_builder.dart';

const _appGroupId = 'group.com.boardcast.app';
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
    final state = buildConditionState(
      conditions: conditions,
      prefs: prefs,
      location: location,
    );

    // Build 18-hour score timeline starting from current hour
    // Each entry: { "h": hour (0-23), "s": score (0-100 int), "c": condition index (0-3) }
    final now = DateTime.now();
    final tideRange = TideRange.fromHourlyData(conditions.hourly);
    final hourlyScores = <Map<String, dynamic>>[];
    final hourlyWaveHeights = <Map<String, dynamic>>[];
    final hourlyTideHeights = <Map<String, dynamic>>[];
    for (var i = 0; i < conditions.hourly.length && hourlyScores.length < 18; i++) {
      final h = conditions.hourly[i];
      final t = DateTime.parse(h.time);
      if (t.isBefore(now.subtract(const Duration(hours: 1)))) continue;
      final s = computeMatchScore(h, prefs, location, tideRange: tideRange);
      final scoreInt = (s * 100).round();
      // Condition index: 0=epic, 1=good, 2=fair, 3=poor
      final cIdx = s >= 0.8 ? 0 : s >= 0.6 ? 1 : s >= 0.4 ? 2 : 3;
      hourlyScores.add({'h': t.hour, 's': scoreInt, 'c': cIdx});
      // Wave height in feet
      final waveFt = h.waveHeight != null
          ? double.parse(metersToFeet(h.waveHeight!).toStringAsFixed(1))
          : null;
      hourlyWaveHeights.add({'h': t.hour, 'w': waveFt});
      // Tide height in feet
      final tideFt = h.tideHeight != null
          ? double.parse(metersToFeet(h.tideHeight!).toStringAsFixed(1))
          : null;
      hourlyTideHeights.add({'h': t.hour, 't': tideFt});
    }

    // Best window raw times for widget (ISO format)
    final bestWindow = findBestWindow(conditions.hourly, prefs, location,
        tideRange: tideRange);

    // Top 3 upcoming windows for large widget
    final topWindows = findTopWindows(conditions.hourly, prefs, location,
        count: 3, tideRange: tideRange);
    final upcomingWindows = topWindows.map((w) {
      final waveFt = w.waveHeight != null
          ? double.parse(metersToFeet(w.waveHeight!).toStringAsFixed(1))
          : null;
      return {
        'start': w.startTime,
        'end': w.endTime,
        'score': (w.avgScore * 100).round(),
        'label': getConditionLabel(w.avgScore).label,
        'wave': waveFt,
      };
    }).toList();

    // Write all keys (including selectedLocationId for Siri Shortcuts)
    await Future.wait([
      HomeWidget.saveWidgetData<String>('selectedLocationId', location.id),
      HomeWidget.saveWidgetData<int>('score', state.score),
      HomeWidget.saveWidgetData<String>('conditionLabel', state.label),
      HomeWidget.saveWidgetData<String>('locationName', location.name),
      HomeWidget.saveWidgetData<String>('waveHeight', state.waveHeight),
      HomeWidget.saveWidgetData<String>('windSpeed', state.windSpeed),
      HomeWidget.saveWidgetData<String>('windDir', state.windDir),
      HomeWidget.saveWidgetData<String>('windContext', state.windContext),
      HomeWidget.saveWidgetData<String>('fetchedAt', conditions.fetchedAt.toIso8601String()),
      HomeWidget.saveWidgetData<String>('hourlyScores', jsonEncode(hourlyScores)),
      HomeWidget.saveWidgetData<String>('hourlyWaveHeights', jsonEncode(hourlyWaveHeights)),
      HomeWidget.saveWidgetData<String>('hourlyTideHeights', jsonEncode(hourlyTideHeights)),
      HomeWidget.saveWidgetData<String>('upcomingWindows', jsonEncode(upcomingWindows)),
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

    // Tell native widgets to reload (iOS WidgetKit + Android AppWidgetManager)
    await HomeWidget.updateWidget(
      iOSName: _iOSWidgetName,
      androidName: 'MediumWidgetReceiver',
    );
    await HomeWidget.updateWidget(
      iOSName: 'BoardcastSmallWidget',
      androidName: 'SmallWidgetReceiver',
    );
    await HomeWidget.updateWidget(
      iOSName: 'BoardcastLargeWidget',
      androidName: 'LargeWidgetReceiver',
    );
    await HomeWidget.updateWidget(iOSName: 'BoardcastLockScreenWidget');
    await HomeWidget.updateWidget(iOSName: 'BoardcastLockScreenCircularWidget');
  }
}
