import 'package:flutter_test/flutter_test.dart';
import 'package:boardcast_flutter/logic/surf_iq.dart';
import 'package:boardcast_flutter/models/session.dart';
import 'package:boardcast_flutter/models/user_prefs.dart';

Session _makeSession({
  String status = 'completed',
  int? rating,
  int? calibration,
  double? matchScore,
  double? waveHeight,
  double? windSpeed,
}) {
  final now = DateTime.now();
  return Session(
    id: 'test-${now.microsecondsSinceEpoch}',
    locationId: 'rockaway',
    date: '2025-01-15',
    status: status,
    rating: rating,
    calibration: calibration,
    conditions: matchScore != null
        ? SessionConditions(
            matchScore: matchScore,
            waveHeight: waveHeight,
            windSpeed: windSpeed,
          )
        : null,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('computeSurfIQ', () {
    test('zero sessions returns score 0, level Grom', () {
      final result = computeSurfIQ([]);
      expect(result.score, 0);
      expect(result.level, 'Grom');
      expect(result.totalSessions, 0);
    });

    test('planned sessions dont count', () {
      final sessions = [_makeSession(status: 'planned')];
      final result = computeSurfIQ(sessions);
      expect(result.totalSessions, 0);
      expect(result.score, 0);
    });

    test('completed sessions build experience score', () {
      final sessions = List.generate(
          3, (_) => _makeSession(status: 'completed'));
      final result = computeSurfIQ(sessions);
      expect(result.breakdown.experience, 15); // 3 * 5 = 15
      expect(result.score, greaterThanOrEqualTo(15));
    });

    test('experience caps at 30', () {
      final sessions = List.generate(
          10, (_) => _makeSession(status: 'completed'));
      final result = computeSurfIQ(sessions);
      expect(result.breakdown.experience, 30);
    });

    test('calibration accuracy counts', () {
      final sessions = [
        _makeSession(calibration: 0), // about right
        _makeSession(calibration: 0),
        _makeSession(calibration: 1), // better than expected
      ];
      final result = computeSurfIQ(sessions);
      // 2/3 about right * 40 = ~26.67
      expect(result.breakdown.calibration, closeTo(26.67, 0.1));
    });

    test('level progresses with score', () {
      // Create enough sessions to push score into different levels
      final sessions = List.generate(6, (_) => _makeSession(calibration: 0));
      final result = computeSurfIQ(sessions);
      expect(result.score, greaterThan(20));
      expect(result.level, isNot('Grom'));
    });

    test('score is clamped to 0-100', () {
      final result = computeSurfIQ([]);
      expect(result.score, greaterThanOrEqualTo(0));
      expect(result.score, lessThanOrEqualTo(100));
    });
  });

  group('generateInsight', () {
    test('returns null with fewer than 3 calibrated sessions', () {
      final sessions = [
        _makeSession(calibration: 0),
        _makeSession(calibration: 0),
      ];
      expect(generateInsight(sessions), isNull);
    });

    test('returns optimistic insight for positive calibration', () {
      final sessions = [
        _makeSession(calibration: 1),
        _makeSession(calibration: 1),
        _makeSession(calibration: 1),
      ];
      final result = generateInsight(sessions);
      expect(result, contains('better than expected'));
    });

    test('returns pessimistic insight for negative calibration', () {
      final sessions = [
        _makeSession(calibration: -1),
        _makeSession(calibration: -1),
        _makeSession(calibration: -1),
      ];
      final result = generateInsight(sessions);
      expect(result, contains('fall short'));
    });

    test('returns default message for neutral calibration', () {
      final sessions = [
        _makeSession(calibration: 0, rating: 3, matchScore: 0.5),
        _makeSession(calibration: 0, rating: 3, matchScore: 0.5),
        _makeSession(calibration: 0, rating: 3, matchScore: 0.5),
      ];
      final result = generateInsight(sessions);
      expect(result, isNotNull);
    });
  });

  group('generateNudge', () {
    test('returns null with fewer than 5 calibrated sessions', () {
      final sessions = [
        _makeSession(calibration: 0, rating: 5, matchScore: 0.8),
        _makeSession(calibration: 0, rating: 5, matchScore: 0.8),
      ];
      expect(generateNudge(sessions, UserPrefs.defaultPrefs), isNull);
    });

    test('returns null with null prefs', () {
      expect(generateNudge([], null), isNull);
    });

    test('suggests wave height increase when high-rated sessions have bigger waves', () {
      final prefs = const UserPrefs(
        minWaveHeight: 0.3,
        maxWaveHeight: 1.0,
        maxWindSpeed: 25.0,
      );
      final sessions = List.generate(
        6,
        (_) => _makeSession(
          calibration: 0,
          rating: 5,
          matchScore: 0.8,
          waveHeight: 1.5, // above max 1.0
          windSpeed: 10,
        ),
      );
      final result = generateNudge(sessions, prefs);
      expect(result, isNotNull);
      expect(result!.type, 'maxWaveHeight');
      expect(result.suggestedValue, greaterThan(prefs.maxWaveHeight!));
    });
  });
}
