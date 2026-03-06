import 'package:flutter_test/flutter_test.dart';
import 'package:boardcast_flutter/logic/preference_inference.dart';
import 'package:boardcast_flutter/models/session.dart';

Session _makeSession({
  double? waveHeight,
  double? windSpeed,
  double? windDirection,
  String locationId = 'rockaway',
}) {
  return Session(
    id: 'test_${DateTime.now().microsecondsSinceEpoch}',
    locationId: locationId,
    date: '2025-06-15',
    status: 'completed',
    conditions: SessionConditions(
      waveHeight: waveHeight,
      windSpeed: windSpeed,
      windDirection: windDirection,
    ),
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

void main() {
  group('inferPrefsFromSessions', () {
    test('returns null with 0 sessions', () {
      final result = inferPrefsFromSessions([]);
      expect(result, isNull);
    });

    test('returns null with 1 session', () {
      final sessions = [_makeSession(waveHeight: 1.0)];
      final result = inferPrefsFromSessions(sessions);
      expect(result, isNull);
    });

    test('returns skill-only inference with 2-4 sessions', () {
      final sessions = [
        _makeSession(waveHeight: 1.5, windSpeed: 15),
        _makeSession(waveHeight: 1.8, windSpeed: 20),
        _makeSession(waveHeight: 1.2, windSpeed: 10),
      ];
      final result = inferPrefsFromSessions(sessions);
      expect(result, isNotNull);
      expect(result!.prefs.skillLevel, 'intermediate');
      // Should not have full wave range inference
      expect(result.prefs.minWaveHeight, isNull);
      expect(result.confidence, lessThan(0.5));
    });

    test('infers beginner from small wave heights', () {
      final sessions = [
        _makeSession(waveHeight: 0.5),
        _makeSession(waveHeight: 0.8),
        _makeSession(waveHeight: 0.6),
      ];
      final result = inferPrefsFromSessions(sessions);
      expect(result!.inferredSkill, 'beginner');
    });

    test('infers advanced from large wave heights', () {
      final sessions = [
        _makeSession(waveHeight: 2.0),
        _makeSession(waveHeight: 3.0),
        _makeSession(waveHeight: 2.8),
      ];
      final result = inferPrefsFromSessions(sessions);
      expect(result!.inferredSkill, 'advanced');
    });

    test('full inference with 5+ sessions', () {
      final sessions = [
        _makeSession(waveHeight: 1.0, windSpeed: 10, windDirection: 0),
        _makeSession(waveHeight: 1.2, windSpeed: 15, windDirection: 350),
        _makeSession(waveHeight: 1.5, windSpeed: 20, windDirection: 10),
        _makeSession(waveHeight: 1.8, windSpeed: 12, windDirection: 5),
        _makeSession(waveHeight: 2.0, windSpeed: 18, windDirection: 355),
      ];
      final result = inferPrefsFromSessions(sessions);
      expect(result, isNotNull);
      expect(result!.prefs.minWaveHeight, isNotNull);
      expect(result.prefs.maxWaveHeight, isNotNull);
      expect(result.prefs.maxWindSpeed, isNotNull);
      expect(result.prefs.preferredTide, 'any');
      expect(result.confidence, greaterThanOrEqualTo(0.25));
    });

    test('returns null when sessions lack conditions', () {
      final sessions = [
        Session(
          id: 'a',
          locationId: 'rockaway',
          date: '2025-06-15',
          status: 'completed',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Session(
          id: 'b',
          locationId: 'rockaway',
          date: '2025-06-16',
          status: 'completed',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];
      final result = inferPrefsFromSessions(sessions);
      expect(result, isNull);
    });

    test('confidence scales with session count', () {
      final sessions = List.generate(
        20,
        (i) => _makeSession(waveHeight: 1.0 + i * 0.05, windSpeed: 15),
      );
      final result = inferPrefsFromSessions(sessions);
      expect(result!.confidence, equals(1.0));
    });
  });
}
