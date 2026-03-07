/// Mock import service for simulator/emulator testing.
/// Generates realistic fake surf sessions across known locations.
/// Only used in debug builds.
import 'dart:math';
import '../models/session.dart';
import 'health_import_service.dart';

final _rng = Random(42); // Fixed seed for reproducible data

/// Generate mock sessions that look like a real surfer's history.
/// Returns an ImportResult matching the real pipeline output.
Future<ImportResult> generateMockImport({
  int sessionCount = 14,
  void Function(int completed, int total)? onProgress,
}) async {
  final sessions = <Session>[];
  final locationsUsed = <String>{};

  // Realistic location distribution: mostly home spot, some travel
  final locationWeights = [
    ('rockaway', 0.35),
    ('longbeach', 0.20),
    ('asbury', 0.15),
    ('belmar', 0.10),
    ('santacruz', 0.08),
    ('clearwater', 0.07),
    ('cocoabeach', 0.05),
  ];

  // Generate sessions spread over last 6 months
  final now = DateTime.now();
  for (var i = 0; i < sessionCount; i++) {
    // Simulate enrichment progress
    onProgress?.call(i + 1, sessionCount);
    await Future.delayed(const Duration(milliseconds: 120));

    // Random date within last 6 months, weighted toward recent
    final daysAgo = _rng.nextInt(180);
    final sessionDate = now.subtract(Duration(days: daysAgo));
    final dateStr =
        '${sessionDate.year}-${sessionDate.month.toString().padLeft(2, '0')}-${sessionDate.day.toString().padLeft(2, '0')}';

    // Pick location by weight
    final locationId = _pickWeighted(locationWeights);
    locationsUsed.add(locationId);

    // Realistic session time: 6-10 AM
    final startHour = 6 + _rng.nextInt(4);
    final durationMinutes = 45 + _rng.nextInt(90); // 45-135 min
    final startTime = DateTime(
        sessionDate.year, sessionDate.month, sessionDate.day, startHour);
    final endTime = startTime.add(Duration(minutes: durationMinutes));

    // Realistic conditions
    final waveHeight = 0.5 + _rng.nextDouble() * 2.0; // 0.5-2.5m
    final windSpeed = 5.0 + _rng.nextDouble() * 25.0; // 5-30 km/h
    final swellPeriod = 6.0 + _rng.nextDouble() * 10.0; // 6-16s
    final swellDirection = _rng.nextDouble() * 360;
    final windDirection = _rng.nextDouble() * 360;
    final matchScore = 0.25 + _rng.nextDouble() * 0.65; // 0.25-0.90

    // Some sessions have ratings (completed and reviewed)
    final hasRating = _rng.nextDouble() > 0.3;
    final rating = hasRating ? 2 + _rng.nextInt(4) : null; // 2-5 stars

    // Some have tags
    final allTags = ['glassy', 'crowded', 'fun', 'clean', 'choppy'];
    final tagCount = _rng.nextInt(3);
    final tags = tagCount > 0
        ? (allTags..shuffle(_rng)).sublist(0, tagCount)
        : <String>[];

    final hasGps = _rng.nextDouble() > 0.2; // 80% have GPS

    sessions.add(Session(
      id: hasGps ? 'hk_${startTime.millisecondsSinceEpoch}_$durationMinutes' : 'hk_${startTime.millisecondsSinceEpoch}_${durationMinutes}_nogps',
      locationId: locationId,
      date: dateStr,
      status: 'completed',
      selectedHours: [startHour],
      rating: rating,
      tags: tags.isNotEmpty ? tags : null,
      conditions: SessionConditions(
        matchScore: matchScore,
        waveHeight: waveHeight,
        windSpeed: windSpeed,
        windDirection: windDirection,
        swellDirection: swellDirection,
        swellPeriod: swellPeriod,
      ),
      source: hasGps ? 'healthkit' : 'healthkit_nogps',
      createdAt: startTime,
      updatedAt: endTime,
    ));
  }

  // Sort by date descending (most recent first)
  sessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));

  final dates = sessions.map((s) => s.date).toList();

  return ImportResult(
    sessions: sessions,
    totalDiscovered: sessionCount + 3, // simulate a few filtered out
    skippedTooFar: 2,
    skippedTooShort: 1,
    skippedDuplicate: 0,
    enrichedCount: sessions.length - 2, // a couple too recent for ERA5
    locationsFound: locationsUsed.toList(),
    earliestDate: dates.reduce((a, b) => a.compareTo(b) < 0 ? a : b),
    latestDate: dates.reduce((a, b) => a.compareTo(b) > 0 ? a : b),
  );
}

/// Generate mock Strava-style sessions (same data, different IDs/source)
Future<ImportResult> generateMockStravaImport({
  int sessionCount = 8,
  void Function(int completed, int total)? onProgress,
}) async {
  final result = await generateMockImport(
    sessionCount: sessionCount,
    onProgress: onProgress,
  );

  // Re-ID as Strava sessions
  var stravaId = 10000000;
  final stravaSessions = result.sessions.map((s) {
    stravaId++;
    return Session(
      id: 'strava_$stravaId',
      userId: s.userId,
      locationId: s.locationId,
      date: s.date,
      status: s.status,
      selectedHours: s.selectedHours,
      rating: s.rating,
      tags: s.tags,
      conditions: s.conditions,
      source: 'strava',
      createdAt: s.createdAt,
      updatedAt: s.updatedAt,
    );
  }).toList();

  return ImportResult(
    sessions: stravaSessions,
    totalDiscovered: result.totalDiscovered,
    skippedTooFar: result.skippedTooFar,
    skippedTooShort: result.skippedTooShort,
    skippedDuplicate: result.skippedDuplicate,
    enrichedCount: result.enrichedCount,
    locationsFound: result.locationsFound,
    earliestDate: result.earliestDate,
    latestDate: result.latestDate,
  );
}

String _pickWeighted(List<(String, double)> weights) {
  final total = weights.fold(0.0, (sum, w) => sum + w.$2);
  var roll = _rng.nextDouble() * total;
  for (final (id, weight) in weights) {
    roll -= weight;
    if (roll <= 0) return id;
  }
  return weights.last.$1;
}
