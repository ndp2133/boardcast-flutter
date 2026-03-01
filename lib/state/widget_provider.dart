/// Widget data provider — pushes conditions to home screen widget
/// whenever conditions or location change.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/widget_service.dart';
import '../logic/locations.dart';
import 'conditions_provider.dart';
import 'location_provider.dart';
import 'preferences_provider.dart';

/// Widget service singleton. Must be initialized before use.
final widgetServiceProvider = Provider<WidgetService>((ref) {
  return WidgetService();
});

/// Listener that auto-updates widget data when conditions resolve.
/// Add this provider to the widget tree to activate it.
final widgetUpdaterProvider = Provider<void>((ref) {
  final conditions = ref.watch(conditionsProvider);
  final prefs = ref.watch(preferencesProvider);
  final locationId = ref.watch(selectedLocationIdProvider);
  final widgetService = ref.read(widgetServiceProvider);

  conditions.whenData((data) {
    final location = getLocationById(locationId);
    widgetService.updateWidgetData(
      conditions: data,
      prefs: prefs,
      location: location,
    );
  });
});
