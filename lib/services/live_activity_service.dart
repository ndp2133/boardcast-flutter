/// Live Activity service — MethodChannel wrapper for ActivityKit lifecycle.
/// Live Activity is optional — all calls gracefully degrade on failure.
import 'package:flutter/services.dart';

const _channel = MethodChannel('com.boardcast.app/live_activity');

class LiveActivityService {
  /// Check if Live Activities are supported and enabled.
  Future<bool> isSupported() async {
    try {
      final result = await _channel.invokeMethod<bool>('isSupported');
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Start a Live Activity with initial conditions data.
  Future<bool> start({
    required String locationName,
    required String locationId,
    required int score,
    required String conditionLabel,
    required String waveHeight,
    required String windSpeed,
    required String windDir,
    String windContext = '',
    String bestWindowRange = '',
    String bestWindowLabel = '',
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('start', {
        'locationName': locationName,
        'locationId': locationId,
        'score': score,
        'conditionLabel': conditionLabel,
        'waveHeight': waveHeight,
        'windSpeed': windSpeed,
        'windDir': windDir,
        'windContext': windContext,
        'bestWindowRange': bestWindowRange,
        'bestWindowLabel': bestWindowLabel,
      });
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Update the Live Activity with fresh conditions data.
  Future<bool> update({
    required int score,
    required String conditionLabel,
    required String waveHeight,
    required String windSpeed,
    required String windDir,
    String windContext = '',
    String bestWindowRange = '',
    String bestWindowLabel = '',
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('update', {
        'score': score,
        'conditionLabel': conditionLabel,
        'waveHeight': waveHeight,
        'windSpeed': windSpeed,
        'windDir': windDir,
        'windContext': windContext,
        'bestWindowRange': bestWindowRange,
        'bestWindowLabel': bestWindowLabel,
      });
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// End the current Live Activity.
  Future<bool> end() async {
    try {
      final result = await _channel.invokeMethod<bool>('end');
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
