/// Conditions data provider — fetch + cache + offline fallback
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/merged_conditions.dart';
import '../services/cache_service.dart';
import '../services/conditions_repository.dart';
import 'location_provider.dart';

/// Cache service singleton.
final cacheServiceProvider = Provider<CacheService>((ref) {
  return CacheService();
});

/// Conditions repository singleton.
final conditionsRepositoryProvider = Provider<ConditionsRepository>((ref) {
  final cache = ref.read(cacheServiceProvider);
  return ConditionsRepository(cache);
});

/// Async conditions for the selected location.
/// Automatically refetches when location changes.
final conditionsProvider =
    FutureProvider.autoDispose<MergedConditions>((ref) async {
  final locationId = ref.watch(selectedLocationIdProvider);
  final repo = ref.read(conditionsRepositoryProvider);
  return repo.fetchAllConditions(locationId);
});

/// Cached (possibly stale) conditions for immediate display.
final cachedConditionsProvider = Provider<MergedConditions?>((ref) {
  final locationId = ref.watch(selectedLocationIdProvider);
  final repo = ref.read(conditionsRepositoryProvider);
  return repo.getCachedData(locationId);
});

/// Data age in minutes, or null.
final dataAgeProvider = Provider<int?>((ref) {
  final locationId = ref.watch(selectedLocationIdProvider);
  final repo = ref.read(conditionsRepositoryProvider);
  return repo.getDataAge(locationId);
});
