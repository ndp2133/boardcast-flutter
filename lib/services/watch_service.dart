/// Apple Watch complication data service — pushes surf data via WatchConnectivity.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import '../models/merged_conditions.dart';
import '../models/user_prefs.dart';
import '../models/location.dart';
import '../logic/scoring.dart';
import '../logic/units.dart';
import 'condition_state_builder.dart';

class WatchService {
  static const _channel = MethodChannel('com.boardcast.app/watch');

  /// Push current conditions to Apple Watch complication.
  /// No-op on Android.
  Future<bool> updateWatchData({
    required MergedConditions conditions,
    required UserPrefs prefs,
    required Location location,
  }) async {
    if (!Platform.isIOS) return false;

    final state = buildConditionState(
      conditions: conditions,
      prefs: prefs,
      location: location,
    );

    // Build next 6 hours of forecast for the watch app view
    final now = DateTime.now();
    final tideRange = TideRange.fromHourlyData(conditions.hourly);
    final hourlyForecast = <Map<String, dynamic>>[];
    for (final h in conditions.hourly) {
      final t = DateTime.parse(h.time);
      if (t.isBefore(now.subtract(const Duration(hours: 1)))) continue;
      if (hourlyForecast.length >= 6) break;
      final s = computeMatchScore(h, prefs, location, tideRange: tideRange);
      final scoreInt = (s * 100).round();
      final waveFt = h.waveHeight != null
          ? metersToFeet(h.waveHeight!).toStringAsFixed(1)
          : '--';
      final windMph = h.windSpeed != null
          ? kmhToMph(h.windSpeed!).round().toString()
          : '--';
      final windD = h.windDirection != null
          ? degreesToCardinal(h.windDirection!)
          : '--';
      hourlyForecast.add({
        'h': t.hour,
        's': scoreInt,
        'w': waveFt,
        'ws': windMph,
        'wd': windD,
      });
    }

    try {
      final result = await _channel.invokeMethod<bool>('updateWatchData', {
        'score': state.score,
        'conditionLabel': state.label,
        'locationName': location.name,
        'waveHeight': state.waveHeight,
        'windSpeed': state.windSpeed,
        'windDir': state.windDir,
        'windContext': state.windContext,
        'bestWindowRange': state.bestWindowRange,
        'bestWindowLabel': state.bestWindowLabel,
        'verdict': state.verdict,
        'trend': state.trend,
        'hourlyForecast': jsonEncode(hourlyForecast),
      });
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Check if an Apple Watch is paired and reachable.
  Future<bool> get isWatchPaired async {
    if (!Platform.isIOS) return false;
    try {
      return await _channel.invokeMethod<bool>('isWatchPaired') ?? false;
    } catch (_) {
      return false;
    }
  }
}
