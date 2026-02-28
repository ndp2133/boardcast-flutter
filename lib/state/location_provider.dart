/// Selected location provider
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/location.dart';
import '../logic/locations.dart';
import 'store_provider.dart';

/// Notifier for the selected location ID.
class LocationNotifier extends Notifier<String> {
  @override
  String build() {
    final store = ref.read(storeServiceProvider);
    return store.getSelectedLocationId();
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
