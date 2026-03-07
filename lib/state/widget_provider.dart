/// Widget data provider — pushes conditions to home screen widget
/// and Apple Watch complication whenever conditions or location change.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/widget_service.dart';
import '../services/watch_service.dart';
import '../logic/locations.dart';
import 'conditions_provider.dart';
import 'location_provider.dart';
import 'preferences_provider.dart';

/// Widget service singleton. Must be initialized before use.
final widgetServiceProvider = Provider<WidgetService>((ref) {
  return WidgetService();
});

/// Watch service singleton for Apple Watch complication updates.
final watchServiceProvider = Provider<WatchService>((ref) {
  return WatchService();
});

/// Listener that auto-updates widget data when conditions resolve.
/// Add this provider to the widget tree to activate it.
final widgetUpdaterProvider = Provider<void>((ref) {
  final conditions = ref.watch(conditionsProvider);
  final prefs = ref.watch(preferencesProvider);
  final locationId = ref.watch(selectedLocationIdProvider);
  final widgetService = ref.read(widgetServiceProvider);
  final watchService = ref.read(watchServiceProvider);

  conditions.whenData((data) {
    final location = getLocationById(locationId);
    widgetService.updateWidgetData(
      conditions: data,
      prefs: prefs,
      location: location,
    );
    // Also push to Apple Watch complication
    watchService.updateWatchData(
      conditions: data,
      prefs: prefs,
      location: location,
    );
  });
});
