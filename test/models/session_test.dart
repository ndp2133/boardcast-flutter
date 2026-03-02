import 'package:flutter_test/flutter_test.dart';
import 'package:boardcast_flutter/models/session.dart';

void main() {
  group('SessionConditions', () {
    test('serialization round-trip preserves all fields', () {
      const conditions = SessionConditions(
        matchScore: 0.85,
        waveHeight: 1.5,
        windSpeed: 12.0,
        windDirection: 180.0,
        swellDirection: 200.0,
        swellPeriod: 14.0,
        forecastAccuracy: 0.87,
      );
      final json = conditions.toJson();
      final restored = SessionConditions.fromJson(json);

      expect(restored.matchScore, 0.85);
      expect(restored.waveHeight, 1.5);
      expect(restored.windSpeed, 12.0);
      expect(restored.windDirection, 180.0);
      expect(restored.swellDirection, 200.0);
      expect(restored.swellPeriod, 14.0);
      expect(restored.forecastAccuracy, 0.87);
    });

    test('forecastAccuracy round-trip with null', () {
      const conditions = SessionConditions(
        matchScore: 0.7,
        waveHeight: 1.0,
      );
      final json = conditions.toJson();
      final restored = SessionConditions.fromJson(json);

      expect(restored.forecastAccuracy, isNull);
      expect(restored.matchScore, 0.7);
    });

    test('toJson omits null fields', () {
      const conditions = SessionConditions(matchScore: 0.5);
      final json = conditions.toJson();

      expect(json.containsKey('matchScore'), true);
      expect(json.containsKey('waveHeight'), false);
      expect(json.containsKey('forecastAccuracy'), false);
    });

    test('fromJson handles integer values as doubles', () {
      final json = {
        'matchScore': 1,
        'waveHeight': 2,
        'forecastAccuracy': 0,
      };
      final conditions = SessionConditions.fromJson(json);

      expect(conditions.matchScore, 1.0);
      expect(conditions.waveHeight, 2.0);
      expect(conditions.forecastAccuracy, 0.0);
    });

    test('copyWith updates forecastAccuracy', () {
      const original = SessionConditions(
        matchScore: 0.8,
        waveHeight: 1.5,
      );
      final updated = original.copyWith(forecastAccuracy: 0.92);

      expect(updated.matchScore, 0.8);
      expect(updated.waveHeight, 1.5);
      expect(updated.forecastAccuracy, 0.92);
    });

    test('copyWith preserves forecastAccuracy when not specified', () {
      const original = SessionConditions(
        matchScore: 0.8,
        forecastAccuracy: 0.75,
      );
      final updated = original.copyWith(matchScore: 0.9);

      expect(updated.forecastAccuracy, 0.75);
      expect(updated.matchScore, 0.9);
    });
  });

  group('Session', () {
    final now = DateTime(2025, 1, 15, 10, 0);

    test('full serialization round-trip', () {
      final session = Session(
        id: 'sess_123',
        userId: 'user_456',
        locationId: 'rockaway',
        date: '2025-01-15',
        status: 'completed',
        selectedHours: [8, 9, 10],
        rating: 4,
        calibration: 1,
        boardId: 'board_1',
        tags: ['glassy', 'offshore'],
        notes: 'Great session',
        conditions: const SessionConditions(
          matchScore: 0.85,
          waveHeight: 1.5,
          windSpeed: 12.0,
          forecastAccuracy: 0.9,
        ),
        source: 'manual',
        createdAt: now,
        updatedAt: now,
      );

      final json = session.toJson();
      final restored = Session.fromJson(json);

      expect(restored.id, 'sess_123');
      expect(restored.userId, 'user_456');
      expect(restored.locationId, 'rockaway');
      expect(restored.date, '2025-01-15');
      expect(restored.status, 'completed');
      expect(restored.selectedHours, [8, 9, 10]);
      expect(restored.rating, 4);
      expect(restored.calibration, 1);
      expect(restored.boardId, 'board_1');
      expect(restored.tags, ['glassy', 'offshore']);
      expect(restored.notes, 'Great session');
      expect(restored.conditions!.forecastAccuracy, 0.9);
      expect(restored.source, 'manual');
    });

    test('session with null conditions round-trips', () {
      final session = Session(
        id: 'sess_789',
        locationId: 'montauk',
        date: '2025-01-15',
        status: 'planned',
        createdAt: now,
        updatedAt: now,
      );

      final json = session.toJson();
      final restored = Session.fromJson(json);

      expect(restored.conditions, isNull);
      expect(restored.selectedHours, isNull);
    });

    test('copyWith preserves conditions with forecastAccuracy', () {
      final session = Session(
        id: 'sess_100',
        locationId: 'rockaway',
        date: '2025-01-15',
        status: 'planned',
        conditions: const SessionConditions(
          matchScore: 0.7,
          forecastAccuracy: 0.88,
        ),
        createdAt: now,
        updatedAt: now,
      );

      final completed = session.copyWith(status: 'completed', rating: 5);
      expect(completed.status, 'completed');
      expect(completed.rating, 5);
      expect(completed.conditions!.forecastAccuracy, 0.88);
    });
  });

  group('forecast accuracy computation', () {
    // Mirror the logic from completion_modal.dart
    double metricAccuracy(double forecast, double actual) {
      final maxVal = forecast > actual ? forecast : actual;
      if (maxVal == 0) return 1.0;
      return 1.0 - (forecast - actual).abs() / maxVal;
    }

    test('identical values give 100% accuracy', () {
      expect(metricAccuracy(1.5, 1.5), 1.0);
    });

    test('both zero gives 100% accuracy', () {
      expect(metricAccuracy(0, 0), 1.0);
    });

    test('forecast 1.5, actual 1.3 gives high accuracy', () {
      final acc = metricAccuracy(1.5, 1.3);
      // |1.5-1.3|/1.5 = 0.133, accuracy = 0.867
      expect(acc, closeTo(0.867, 0.01));
    });

    test('forecast 12, actual 8 gives moderate accuracy', () {
      final acc = metricAccuracy(12.0, 8.0);
      // |12-8|/12 = 0.333, accuracy = 0.667
      expect(acc, closeTo(0.667, 0.01));
    });

    test('actual much larger than forecast', () {
      final acc = metricAccuracy(1.0, 3.0);
      // |1-3|/3 = 0.667, accuracy = 0.333
      expect(acc, closeTo(0.333, 0.01));
    });

    test('accuracy is always 0-1', () {
      expect(metricAccuracy(0, 10), greaterThanOrEqualTo(0));
      expect(metricAccuracy(10, 0), greaterThanOrEqualTo(0));
      expect(metricAccuracy(5, 5), lessThanOrEqualTo(1));
    });

    test('overall accuracy averages wave and wind', () {
      final waveAcc = metricAccuracy(1.5, 1.3); // ~0.867
      final windAcc = metricAccuracy(12.0, 8.0); // ~0.667
      final overall = (waveAcc + windAcc) / 2; // ~0.767
      expect(overall, closeTo(0.767, 0.01));
    });
  });
}
