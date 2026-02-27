/// Conditions repository — orchestrates API fetch + cache with offline fallback
/// Direct port of fetchAllConditions() and getCachedData() from api.js
import 'package:http/http.dart' as http;
import '../models/models.dart';
import '../logic/locations.dart';
import 'api_service.dart';
import 'cache_service.dart';

class ConditionsRepository {
  final CacheService _cache;
  final http.Client? _httpClient;

  /// In-memory cache (mirrors the JS `dataCache` Map)
  final Map<String, MergedConditions> _memoryCache = {};

  ConditionsRepository(this._cache, {http.Client? httpClient})
      : _httpClient = httpClient;

  /// Fetch fresh conditions for a location. Falls back to cache on failure.
  Future<MergedConditions> fetchAllConditions(
    String locationId, {
    int forecastDays = 14,
  }) async {
    final location = getLocationById(locationId);

    try {
      // Fetch all three APIs in parallel; tide failure doesn't block
      final results = await Future.wait([
        fetchMarineData(location,
            forecastDays: forecastDays, client: _httpClient),
        fetchWeatherData(location,
            forecastDays: forecastDays, client: _httpClient),
        fetchTideData(location,
                forecastDays: forecastDays, client: _httpClient)
            .catchError((_) => null),
      ]);

      final marineRaw = results[0] as Map<String, dynamic>;
      final weatherRaw = results[1] as Map<String, dynamic>;
      final tideRaw = results[2] as Map<String, dynamic>?;

      final merged = mergeConditions(marineRaw, weatherRaw, tideRaw);

      // Update both caches
      _memoryCache[locationId] = merged;
      await _cache.putConditions(locationId, merged);

      return merged;
    } catch (err) {
      // Offline fallback: try Hive cache
      final persisted = _cache.getConditions(locationId);
      if (persisted != null) {
        _memoryCache[locationId] = persisted;
        return persisted; // already marked isStale by CacheService
      }
      rethrow;
    }
  }

  /// Get cached data (memory first, then Hive). Returns null if no cache.
  MergedConditions? getCachedData(String locationId) {
    final inMemory = _memoryCache[locationId];
    if (inMemory != null) return inMemory;

    final persisted = _cache.getConditions(locationId);
    if (persisted != null) {
      _memoryCache[locationId] = persisted;
      return persisted;
    }
    return null;
  }

  /// How many minutes since last fetch, or null.
  int? getDataAge(String locationId) {
    final data = getCachedData(locationId);
    if (data == null) return null;
    return DateTime.now().difference(data.fetchedAt).inMinutes;
  }

  /// Clear in-memory cache (e.g. on location change).
  void clearMemoryCache() => _memoryCache.clear();
}
