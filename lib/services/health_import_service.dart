/// Orchestrates the full HealthKit/Health Connect import pipeline.
/// Reads surf workouts → snaps to locations → enriches with historical conditions.
import 'package:health/health.dart';
import '../models/session.dart';
import '../models/hourly_data.dart';
import '../models/location.dart';
import '../logic/locations.dart';
import '../logic/scoring.dart';
import 'historical_conditions_service.dart';

/// Max distance (km) from a known spot to count a workout
const _maxDistanceKm = 50.0;

/// Min workout duration to filter false positives
const _minDurationMinutes = 15;

/// Max sessions to import
const _maxSessions = 200;

/// ERA5 reanalysis has ~5-day delay
const _era5DelayDays = 5;

/// Raw workout data from HealthKit before processing
class RawHealthSession {
  final DateTime startTime;
  final DateTime endTime;
  final double? lat;
  final double? lon;

  const RawHealthSession({
    required this.startTime,
    required this.endTime,
    this.lat,
    this.lon,
  });

  int get durationMinutes => endTime.difference(startTime).inMinutes;
}

/// A candidate session after location snapping, before enrichment
class ImportCandidate {
  final RawHealthSession raw;
  final Location location;
  final double distanceKm;
  final bool hasGps;

  const ImportCandidate({
    required this.raw,
    required this.location,
    required this.distanceKm,
    required this.hasGps,
  });

  String get date =>
      '${raw.startTime.year}-${raw.startTime.month.toString().padLeft(2, '0')}-${raw.startTime.day.toString().padLeft(2, '0')}';

  String get fingerprint =>
      'hk_${raw.startTime.millisecondsSinceEpoch}_${raw.durationMinutes}';
}

/// Result of the full import pipeline
class ImportResult {
  final List<Session> sessions;
  final int totalDiscovered;
  final int skippedTooFar;
  final int skippedTooShort;
  final int skippedDuplicate;
  final int enrichedCount;
  final List<String> locationsFound;
  final String? earliestDate;
  final String? latestDate;

  const ImportResult({
    required this.sessions,
    required this.totalDiscovered,
    this.skippedTooFar = 0,
    this.skippedTooShort = 0,
    this.skippedDuplicate = 0,
    this.enrichedCount = 0,
    this.locationsFound = const [],
    this.earliestDate,
    this.latestDate,
  });
}

class HealthImportService {
  final Health _health = Health();
  final HistoricalConditionsService _historicalService;

  HealthImportService({HistoricalConditionsService? historicalService})
      : _historicalService =
            historicalService ?? HistoricalConditionsService();

  /// Check if Health data is available on this platform
  Future<bool> isHealthAvailable() async {
    try {
      return await _health.isHealthConnectAvailable();
    } catch (_) {
      // On iOS, Health is always available if HealthKit framework is present
      return true;
    }
  }

  /// Request permission to read surf workouts
  Future<bool> requestPermission() async {
    try {
      final types = [HealthDataType.WORKOUT];
      final permissions = [HealthDataAccess.READ];
      return await _health.requestAuthorization(types,
          permissions: permissions);
    } catch (_) {
      return false;
    }
  }

  /// Read surf workouts from HealthKit/Health Connect
  Future<List<RawHealthSession>> readSurfWorkouts() async {
    try {
      final now = DateTime.now();
      final threeYearsAgo = now.subtract(const Duration(days: 365 * 3));

      final dataPoints = await _health.getHealthDataFromTypes(
        types: [HealthDataType.WORKOUT],
        startTime: threeYearsAgo,
        endTime: now,
      );

      // Filter to surfing workouts
      final surfWorkouts = dataPoints.where((dp) {
        if (dp.value is! WorkoutHealthValue) return false;
        final workout = dp.value as WorkoutHealthValue;
        return workout.workoutActivityType == HealthWorkoutActivityType.SURFING;
      }).toList();

      return surfWorkouts.map((dp) {
        // GPS coordinates from workout route if available
        double? lat, lon;
        // Note: health package doesn't expose route data directly in v13
        // GPS will be null for most workouts — we handle this with the
        // 'healthkit_nogps' source tag and fall back to home location

        return RawHealthSession(
          startTime: dp.dateFrom,
          endTime: dp.dateTo,
          lat: lat,
          lon: lon,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Snap raw workouts to nearest known locations, filtering by distance
  List<ImportCandidate> snapToLocations(
    List<RawHealthSession> workouts, {
    String? homeLocationId,
  }) {
    final candidates = <ImportCandidate>[];

    for (final workout in workouts) {
      // Filter too-short workouts
      if (workout.durationMinutes < _minDurationMinutes) continue;

      if (workout.lat != null && workout.lon != null) {
        // GPS available — snap to nearest location
        final nearest = findNearestLocation(workout.lat!, workout.lon!);
        final distance = haversine(
            workout.lat!, workout.lon!, nearest.lat, nearest.lon);

        if (distance <= _maxDistanceKm) {
          candidates.add(ImportCandidate(
            raw: workout,
            location: nearest,
            distanceKm: distance,
            hasGps: true,
          ));
        }
        // else: skip — too far from any known spot
      } else {
        // No GPS — attribute to home location
        final homeLocation = homeLocationId != null
            ? getLocationById(homeLocationId)
            : getDefaultLocation();
        candidates.add(ImportCandidate(
          raw: workout,
          location: homeLocation,
          distanceKm: 0,
          hasGps: false,
        ));
      }
    }

    return candidates;
  }

  /// Enrich candidates with historical conditions and create Session objects.
  /// [existingIds] is used for dedup.
  /// [onProgress] is called with (completed, total) for UI updates.
  Future<ImportResult> enrichWithConditions(
    List<ImportCandidate> candidates, {
    Set<String> existingIds = const {},
    String? userId,
    void Function(int completed, int total)? onProgress,
  }) async {
    // Dedup and cap
    final deduped = <String, ImportCandidate>{};
    var skippedDuplicate = 0;

    for (final c in candidates) {
      if (existingIds.contains(c.fingerprint)) {
        skippedDuplicate++;
        continue;
      }
      if (deduped.containsKey(c.fingerprint)) {
        skippedDuplicate++;
        continue;
      }
      deduped[c.fingerprint] = c;
    }

    // Sort by date descending, cap at _maxSessions
    final sorted = deduped.values.toList()
      ..sort((a, b) => b.raw.startTime.compareTo(a.raw.startTime));
    final capped =
        sorted.length > _maxSessions ? sorted.sublist(0, _maxSessions) : sorted;

    // Filter out sessions within ERA5 delay window (no historical data yet)
    final cutoffDate =
        DateTime.now().subtract(const Duration(days: _era5DelayDays));
    final enrichable = <ImportCandidate>[];
    final tooRecent = <ImportCandidate>[];
    for (final c in capped) {
      if (c.raw.startTime.isAfter(cutoffDate)) {
        tooRecent.add(c);
      } else {
        enrichable.add(c);
      }
    }

    // Build requests for historical data
    final requests = enrichable
        .map((c) => (location: c.location, date: c.date))
        .toList();

    // Fetch historical conditions (batched by location)
    Map<ConditionKey, List<HourlyData>> conditionsMap = {};
    if (requests.isNotEmpty) {
      try {
        conditionsMap =
            await _historicalService.fetchHistoricalConditions(requests);
      } catch (_) {
        // Continue without conditions
      }
    }

    // Build sessions
    final sessions = <Session>[];
    var enrichedCount = 0;
    final locationsFound = <String>{};
    String? earliestDate;
    String? latestDate;

    final allCandidates = [...enrichable, ...tooRecent];
    for (var i = 0; i < allCandidates.length; i++) {
      final c = allCandidates[i];
      onProgress?.call(i + 1, allCandidates.length);

      final date = c.date;
      locationsFound.add(c.location.id);

      if (earliestDate == null || date.compareTo(earliestDate) < 0) {
        earliestDate = date;
      }
      if (latestDate == null || date.compareTo(latestDate) > 0) {
        latestDate = date;
      }

      // Look up conditions for this session's hour
      final key = (locationId: c.location.id, dateStr: date);
      final dayHourly = conditionsMap[key];

      SessionConditions? conditions;
      if (dayHourly != null && dayHourly.isNotEmpty) {
        // Find the hour closest to session start time
        final sessionHour = c.raw.startTime.hour;
        final targetTime =
            '${date}T${sessionHour.toString().padLeft(2, '0')}:00';
        final matchingHour = dayHourly.where((h) => h.time == targetTime);
        final hourData =
            matchingHour.isNotEmpty ? matchingHour.first : dayHourly.first;

        // Use existing scoring engine with default prefs for match score
        final score = computeMatchScore(hourData, null, c.location);

        conditions = SessionConditions(
          matchScore: score,
          waveHeight: hourData.waveHeight,
          windSpeed: hourData.windSpeed,
          windDirection: hourData.windDirection,
          swellDirection: hourData.swellDirection,
          swellPeriod: hourData.swellPeriod,
        );
        enrichedCount++;
      }

      sessions.add(Session(
        id: c.fingerprint,
        userId: userId,
        locationId: c.location.id,
        date: date,
        status: 'completed',
        selectedHours: [c.raw.startTime.hour],
        conditions: conditions,
        source: c.hasGps ? 'healthkit' : 'healthkit_nogps',
        createdAt: c.raw.startTime,
        updatedAt: c.raw.endTime,
      ));
    }

    return ImportResult(
      sessions: sessions,
      totalDiscovered: candidates.length,
      skippedTooFar: candidates.length - capped.length - skippedDuplicate,
      skippedTooShort: 0, // already filtered in snapToLocations
      skippedDuplicate: skippedDuplicate,
      enrichedCount: enrichedCount,
      locationsFound: locationsFound.toList(),
      earliestDate: earliestDate,
      latestDate: latestDate,
    );
  }

  /// End-to-end import pipeline
  Future<ImportResult> runFullImport({
    String? homeLocationId,
    String? userId,
    Set<String> existingSessionIds = const {},
    void Function(int completed, int total)? onProgress,
  }) async {
    final workouts = await readSurfWorkouts();
    if (workouts.isEmpty) {
      return const ImportResult(sessions: [], totalDiscovered: 0);
    }

    final candidates = snapToLocations(
      workouts,
      homeLocationId: homeLocationId,
    );
    if (candidates.isEmpty) {
      return ImportResult(
        sessions: const [],
        totalDiscovered: workouts.length,
        skippedTooFar: workouts.length,
      );
    }

    return enrichWithConditions(
      candidates,
      existingIds: existingSessionIds,
      userId: userId,
      onProgress: onProgress,
    );
  }
}
