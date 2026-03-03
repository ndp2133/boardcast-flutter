/// Live Activity provider — auto-starts and updates Live Activity
/// whenever conditions resolve, mirroring widgetUpdaterProvider pattern.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/live_activity_service.dart';
import '../services/condition_state_builder.dart';
import '../logic/locations.dart';
import 'conditions_provider.dart';
import 'location_provider.dart';
import 'preferences_provider.dart';

/// Live Activity service singleton. Must be initialized before use.
final liveActivityServiceProvider = Provider<LiveActivityService>((ref) {
  return LiveActivityService();
});

/// Listener that auto-manages the Live Activity lifecycle.
/// Starts on first data load, updates on each refresh.
/// Add this provider to the widget tree to activate it.
final liveActivityUpdaterProvider = Provider<void>((ref) {
  final conditions = ref.watch(conditionsProvider);
  final prefs = ref.watch(preferencesProvider);
  final locationId = ref.watch(selectedLocationIdProvider);
  final laService = ref.read(liveActivityServiceProvider);

  conditions.whenData((data) async {
    final location = getLocationById(locationId);
    final state = buildConditionState(
      conditions: data,
      prefs: prefs,
      location: location,
    );

    final supported = await laService.isSupported();
    if (!supported) return;

    // Start (or update) the Live Activity
    await laService.start(
      locationName: location.name,
      locationId: location.id,
      score: state.score,
      conditionLabel: state.label,
      waveHeight: state.waveHeight,
      windSpeed: state.windSpeed,
      windDir: state.windDir,
      windContext: state.windContext,
      bestWindowRange: state.bestWindowRange,
      bestWindowLabel: state.bestWindowLabel,
    );
  });
});
