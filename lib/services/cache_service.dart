/// Per-location conditions cache using Hive
/// Replaces localStorage-based caching from the PWA
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/models.dart';

const _boxName = 'conditions_cache';

class CacheService {
  late Box<String> _box;

  /// Initialize Hive and open the cache box. Call once at app startup.
  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(_boxName);
  }

  /// Save merged conditions for a location.
  Future<void> putConditions(String locationId, MergedConditions data) async {
    final json = jsonEncode(data.toJson());
    await _box.put(locationId, json);
  }

  /// Get cached conditions for a location. Returns null if no cache exists.
  /// Always returns with `isStale = true` since it's from cache.
  MergedConditions? getConditions(String locationId) {
    final raw = _box.get(locationId);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return MergedConditions.fromJson(json).copyWith(isStale: true);
    } catch (_) {
      return null;
    }
  }

  /// How many minutes ago data was fetched, or null if no cache.
  int? getDataAge(String locationId) {
    final data = getConditions(locationId);
    if (data == null) return null;
    return DateTime.now().difference(data.fetchedAt).inMinutes;
  }

  /// Clear cache for a specific location.
  Future<void> clearLocation(String locationId) async {
    await _box.delete(locationId);
  }

  /// Clear all cached conditions.
  Future<void> clearAll() async {
    await _box.clear();
  }
}
