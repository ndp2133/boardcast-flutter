/// Analytics service — wraps PostHog for product analytics.
/// Privacy-first: anonymous by default, identified only after sign-in.
import 'dart:developer';
import 'package:posthog_flutter/posthog_flutter.dart';

const _posthogApiKey = 'phc_4KjjWgRlgQF6UFJrXrxGyew9Oj4u46DS1AJG63J026v';
const _posthogHost = 'https://us.i.posthog.com';

class AnalyticsService {
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      final config = PostHogConfig(_posthogApiKey);
      config.host = _posthogHost;
      config.captureApplicationLifecycleEvents = true;
      config.debug = false;
      await Posthog().setup(config);
      _initialized = true;
      log('PostHog initialized');
    } catch (e) {
      log('PostHog init error: $e');
    }
  }

  /// Identify user after sign-in.
  void identify(String userId, {Map<String, Object>? properties}) {
    if (!_initialized) return;
    Posthog().identify(userId: userId, userProperties: properties);
  }

  /// Reset on sign-out.
  void reset() {
    if (!_initialized) return;
    Posthog().reset();
  }

  /// Track a named event.
  void track(String event, {Map<String, Object>? properties}) {
    if (!_initialized) return;
    Posthog().capture(eventName: event, properties: properties);
  }

  /// Track screen view.
  void screen(String name) {
    if (!_initialized) return;
    Posthog().screen(screenName: name);
  }
}
