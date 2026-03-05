/// Selected location provider with GPS auto-detect on first launch
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../models/location.dart';
import '../logic/locations.dart';
import 'store_provider.dart';

/// Notifier for the selected location ID.
class LocationNotifier extends Notifier<String> {
  @override
  String build() {
    final store = ref.read(storeServiceProvider);
    final saved = store.getSelectedLocationId();

    // On first launch (no explicit location saved), try GPS auto-detect
    if (!store.hasExplicitLocation()) {
      _autoDetect();
    }

    return saved;
  }

  Future<void> _autoDetect() async {
    try {
      final permission = await Geolocator.checkPermission();
      // Only auto-detect if permission already granted (don't prompt on launch)
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 5),
        ),
      );
      final nearest = findNearestLocation(pos.latitude, pos.longitude);
      await select(nearest.id);
    } catch (_) {
      // Silent fail — keep default
    }
  }

  Future<void> select(String locationId) async {
    final store = ref.read(storeServiceProvider);
    await store.setSelectedLocationId(locationId);
    state = locationId;
  }
}

final selectedLocationIdProvider =
    NotifierProvider<LocationNotifier, String>(LocationNotifier.new);

/// Derived: the full Location object for the selected ID.
final selectedLocationProvider = Provider<Location>((ref) {
  final id = ref.watch(selectedLocationIdProvider);
  return getLocationById(id);
});
