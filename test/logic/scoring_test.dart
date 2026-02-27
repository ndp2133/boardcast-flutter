import 'package:flutter_test/flutter_test.dart';
import 'package:boardcast_flutter/logic/scoring.dart';
import 'package:boardcast_flutter/models/hourly_data.dart';
import 'package:boardcast_flutter/models/location.dart';
import 'package:boardcast_flutter/models/user_prefs.dart';

// Rockaway Beach — south-facing, offshore = N (315-45)
const _rockaway = Location(
  id: 'rockaway',
  name: 'Rockaway Beach, NY',
  lat: 40.5835,
  lon: -73.8155,
  timezone: 'America/New_York',
  beachFacing: 180,
  offshoreMin: 315,
  offshoreMax: 45,
  onshoreMin: 135,
  onshoreMax: 225,
  noaaStation: '8517137',
);

const _defaultPrefs = UserPrefs(
  minWaveHeight: 0.3,
  maxWaveHeight: 2.0,
  maxWindSpeed: 25.0,
  preferredWindDir: 'offshore',
  preferredTide: 'any',
  skillLevel: 'intermediate',
);

HourlyData _makeHour({
  String time = '2025-01-15T10:00',
  double? waveHeight,
  double? windSpeed,
  double? windDirection,
  double? swellDirection,
}) =>
    HourlyData(
      time: time,
      waveHeight: waveHeight,
      windSpeed: windSpeed,
      windDirection: windDirection,
      swellDirection: swellDirection,
    );

void main() {
  group('isOffshoreWind', () {
    test('north wind is offshore at south-facing beach', () {
      expect(isOffshoreWind(0, _rockaway), true);
    });

    test('NW wind is offshore at south-facing beach', () {
      expect(isOffshoreWind(330, _rockaway), true);
    });

    test('south wind is NOT offshore at south-facing beach', () {
      expect(isOffshoreWind(180, _rockaway), false);
    });
  });

  group('isOnshoreWind', () {
    test('south wind is onshore at south-facing beach', () {
      expect(isOnshoreWind(180, _rockaway), true);
    });

    test('north wind is NOT onshore at south-facing beach', () {
      expect(isOnshoreWind(0, _rockaway), false);
    });
  });

  group('computeMatchScore', () {
    test('returns 0 for null inputs', () {
      expect(computeMatchScore(null, _defaultPrefs, _rockaway), 0);
      expect(computeMatchScore(_makeHour(), null, _rockaway), 0);
    });

    test('perfect conditions score near 1.0', () {
      final hour = _makeHour(
        waveHeight: 1.0, // in range 0.3-2.0
        windSpeed: 8.0, // below max 25
        windDirection: 0, // offshore (N)
        swellDirection: 180, // direct hit on south-facing beach
      );
      final score = computeMatchScore(hour, _defaultPrefs, _rockaway);
      expect(score, greaterThan(0.8));
    });

    test('flat conditions score low', () {
      final hour = _makeHour(
        waveHeight: 0.05, // way below min
        windSpeed: 40.0, // way above max
        windDirection: 180, // onshore
        swellDirection: 0, // opposite of beach facing
      );
      final score = computeMatchScore(hour, _defaultPrefs, _rockaway);
      // Onshore wind still gets 0.3 * windDir weight, and wind/wave degrade gradually
      expect(score, lessThan(0.55));
    });

    test('score is clamped between 0 and 1', () {
      final hour = _makeHour(
        waveHeight: 1.0,
        windSpeed: 10.0,
        windDirection: 0,
        swellDirection: 180,
      );
      final score = computeMatchScore(hour, _defaultPrefs, _rockaway);
      expect(score, greaterThanOrEqualTo(0));
      expect(score, lessThanOrEqualTo(1));
    });

    test('missing swell direction gives half credit', () {
      final hourWithSwell = _makeHour(
        waveHeight: 1.0,
        windSpeed: 10.0,
        windDirection: 0,
        swellDirection: 180,
      );
      final hourNoSwell = _makeHour(
        waveHeight: 1.0,
        windSpeed: 10.0,
        windDirection: 0,
      );
      final scoreWith =
          computeMatchScore(hourWithSwell, _defaultPrefs, _rockaway);
      final scoreWithout =
          computeMatchScore(hourNoSwell, _defaultPrefs, _rockaway);
      // With perfect swell should score higher than half-credit
      expect(scoreWith, greaterThan(scoreWithout));
    });
  });

  group('getConditionLabel', () {
    test('0.9 is Epic', () {
      expect(getConditionLabel(0.9).label, 'Epic');
    });

    test('0.7 is Good', () {
      expect(getConditionLabel(0.7).label, 'Good');
    });

    test('0.5 is Fair', () {
      expect(getConditionLabel(0.5).label, 'Fair');
    });

    test('0.2 is Poor', () {
      expect(getConditionLabel(0.2).label, 'Poor');
    });

    test('boundary: 0.8 is Epic', () {
      expect(getConditionLabel(0.8).label, 'Epic');
    });

    test('boundary: 0.6 is Good', () {
      expect(getConditionLabel(0.6).label, 'Good');
    });

    test('boundary: 0.4 is Fair', () {
      expect(getConditionLabel(0.4).label, 'Fair');
    });
  });

  group('findBestHours', () {
    test('returns best hour for a date', () {
      final hours = [
        _makeHour(time: '2025-01-15T08:00', waveHeight: 0.5, windSpeed: 10),
        _makeHour(time: '2025-01-15T10:00', waveHeight: 1.5, windSpeed: 5,
            windDirection: 0, swellDirection: 180),
        _makeHour(time: '2025-01-15T14:00', waveHeight: 0.3, windSpeed: 30),
      ];
      final result =
          findBestHours(hours, _defaultPrefs, _rockaway, '2025-01-15');
      expect(result, isNotNull);
      expect(result!.time, '2025-01-15T10:00');
      expect(result.matchScore, greaterThan(0));
    });

    test('returns null for empty data', () {
      final result =
          findBestHours([], _defaultPrefs, _rockaway, '2025-01-15');
      expect(result, isNull);
    });

    test('returns null for wrong date', () {
      final hours = [
        _makeHour(time: '2025-01-16T10:00', waveHeight: 1.5, windSpeed: 5),
      ];
      final result =
          findBestHours(hours, _defaultPrefs, _rockaway, '2025-01-15');
      expect(result, isNull);
    });
  });

  group('findMatchingWindows', () {
    test('finds consecutive windows above threshold', () {
      // Create hours where middle chunk is good
      final hours = List.generate(12, (i) {
        final good = i >= 3 && i <= 7;
        return _makeHour(
          time: '2025-01-15T${(6 + i).toString().padLeft(2, '0')}:00',
          waveHeight: good ? 1.0 : 0.05,
          windSpeed: good ? 5 : 40,
          windDirection: good ? 0 : 180,
          swellDirection: good ? 180 : 0,
        );
      });
      final windows =
          findMatchingWindows(hours, _defaultPrefs, _rockaway, minScore: 0.5);
      expect(windows, isNotEmpty);
      expect(windows.first.count, greaterThan(1));
    });
  });

  group('findTopWindows', () {
    test('returns empty for empty data', () {
      expect(findTopWindows([], _defaultPrefs, _rockaway), isEmpty);
    });

    test('max one window per day', () {
      // Two days of good conditions
      final hours = <HourlyData>[];
      for (final date in ['2025-01-15', '2025-01-16']) {
        for (var h = 6; h <= 18; h++) {
          hours.add(_makeHour(
            time: '$date\T${h.toString().padLeft(2, '0')}:00',
            waveHeight: 1.0,
            windSpeed: 5,
            windDirection: 0,
            swellDirection: 180,
          ));
        }
      }
      final windows =
          findTopWindows(hours, _defaultPrefs, _rockaway, count: 5);
      // Should have at most one per day
      final dates = windows.map((w) => w.date).toSet();
      expect(dates.length, windows.length);
    });
  });

  group('findBestWindowIndices', () {
    test('returns null for empty list', () {
      expect(findBestWindowIndices([]), isNull);
    });

    test('returns null when no scores meet threshold', () {
      expect(findBestWindowIndices([0.1, 0.2, 0.3]), isNull);
    });

    test('finds best consecutive run', () {
      final scores = [0.2, 0.7, 0.8, 0.9, 0.3, 0.6, 0.5, 0.1];
      final result = findBestWindowIndices(scores);
      expect(result, isNotNull);
      expect(result!.startIndex, 1);
      expect(result.endIndex, 3);
      expect(result.avgScore, closeTo(0.8, 0.01));
    });
  });
}
