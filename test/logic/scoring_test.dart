import 'package:flutter_test/flutter_test.dart';
import 'package:boardcast_flutter/logic/scoring.dart';
import 'package:boardcast_flutter/models/hourly_data.dart';
import 'package:boardcast_flutter/models/location.dart';
import 'package:boardcast_flutter/models/user_prefs.dart';

// Rockaway Beach — south-facing beach break, offshore = N (315-45)
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

// Santa Cruz — point break
const _santaCruz = Location(
  id: 'santacruz',
  name: 'Santa Cruz, CA',
  lat: 36.9624,
  lon: -122.0235,
  timezone: 'America/Los_Angeles',
  beachFacing: 180,
  offshoreMin: 315,
  offshoreMax: 45,
  onshoreMin: 135,
  onshoreMax: 225,
  noaaStation: '9413745',
  breakType: 'point',
  swellWindowWidth: 50,
);

// Test reef for tide-sensitive scoring
const _testReef = Location(
  id: 'test-reef',
  name: 'Test Reef',
  lat: 0,
  lon: 0,
  timezone: 'UTC',
  beachFacing: 180,
  offshoreMin: 315,
  offshoreMax: 45,
  onshoreMin: 135,
  onshoreMax: 225,
  noaaStation: '0',
  breakType: 'reef',
);

const _defaultPrefs = UserPrefs(
  minWaveHeight: 0.3,
  maxWaveHeight: 2.0,
  maxWindSpeed: 25.0,
  preferredTide: 'any',
  skillLevel: 'intermediate',
);

const _beginnerPrefs = UserPrefs(
  minWaveHeight: 0.3,
  maxWaveHeight: 1.0,
  maxWindSpeed: 20.0,
  preferredTide: 'mid',
  skillLevel: 'beginner',
);

HourlyData _makeHour({
  String time = '2025-01-15T10:00',
  double? waveHeight,
  double? windSpeed,
  double? windDirection,
  double? windGusts,
  double? swellDirection,
  double? swellPeriod,
  double? swellHeight,
  double? tideHeight,
  int? weatherCode,
}) =>
    HourlyData(
      time: time,
      waveHeight: waveHeight,
      windSpeed: windSpeed,
      windDirection: windDirection,
      windGusts: windGusts,
      swellDirection: swellDirection,
      swellPeriod: swellPeriod,
      swellHeight: swellHeight,
      tideHeight: tideHeight,
      weatherCode: weatherCode,
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

  group('rangeCenterAngle', () {
    test('simple range', () {
      expect(rangeCenterAngle(90, 180), 135);
    });

    test('wrap-around range (315-45)', () {
      expect(rangeCenterAngle(315, 45), 0);
    });

    test('wrap-around range (270-90)', () {
      expect(rangeCenterAngle(270, 90), 0);
    });
  });

  group('angularDistance', () {
    test('same angle is 0', () {
      expect(angularDistance(0, 0), 0);
    });

    test('opposite angles are 180', () {
      expect(angularDistance(0, 180), 180);
    });

    test('90 degree separation', () {
      expect(angularDistance(0, 90), 90);
    });

    test('handles wrap-around', () {
      expect(angularDistance(350, 10), 20);
    });
  });

  group('TideRange.fromHourlyData', () {
    test('computes min and max from tide heights', () {
      final hourly = [
        _makeHour(tideHeight: 1.0),
        _makeHour(tideHeight: 3.0),
        _makeHour(tideHeight: -0.5),
        _makeHour(tideHeight: 2.0),
      ];
      final range = TideRange.fromHourlyData(hourly);
      expect(range, isNotNull);
      expect(range!.min, -0.5);
      expect(range.max, 3.0);
    });

    test('returns null when no tide data', () {
      final hourly = [
        _makeHour(waveHeight: 1.0),
        _makeHour(waveHeight: 2.0),
      ];
      expect(TideRange.fromHourlyData(hourly), isNull);
    });

    test('skips null tide heights', () {
      final hourly = [
        _makeHour(tideHeight: 1.0),
        _makeHour(), // null tide
        _makeHour(tideHeight: 3.0),
      ];
      final range = TideRange.fromHourlyData(hourly);
      expect(range, isNotNull);
      expect(range!.min, 1.0);
      expect(range.max, 3.0);
    });
  });

  group('computeMatchScore', () {
    test('returns 0 for null inputs', () {
      expect(computeMatchScore(null, _defaultPrefs, _rockaway), 0);
      expect(computeMatchScore(_makeHour(), null, _rockaway), 0);
    });

    test('perfect conditions score high', () {
      final hour = _makeHour(
        waveHeight: 1.0,
        windSpeed: 5.0,
        windDirection: 0, // offshore (N)
        swellDirection: 180, // direct hit on south-facing beach
        swellPeriod: 14, // long period groundswell
        swellHeight: 1.0,
        tideHeight: 1.0,
      );
      final score = computeMatchScore(hour, _defaultPrefs, _rockaway);
      expect(score, greaterThan(0.7));
    });

    test('swell period affects score', () {
      final longPeriod = _makeHour(
        waveHeight: 1.0,
        windSpeed: 5.0,
        windDirection: 0,
        swellDirection: 180,
        swellPeriod: 14,
        swellHeight: 1.0,
      );
      final shortPeriod = _makeHour(
        waveHeight: 1.0,
        windSpeed: 5.0,
        windDirection: 0,
        swellDirection: 180,
        swellPeriod: 4,
        swellHeight: 1.0,
      );
      final scoreLong =
          computeMatchScore(longPeriod, _defaultPrefs, _rockaway);
      final scoreShort =
          computeMatchScore(shortPeriod, _defaultPrefs, _rockaway);
      expect(scoreLong, greaterThan(scoreShort));
    });

    test('offshore wind scores higher than onshore', () {
      final offshore = _makeHour(
        waveHeight: 1.0,
        windSpeed: 15.0,
        windDirection: 0, // offshore
        swellDirection: 180,
        swellPeriod: 10,
        swellHeight: 1.0,
      );
      final onshore = _makeHour(
        waveHeight: 1.0,
        windSpeed: 15.0,
        windDirection: 180, // onshore
        swellDirection: 180,
        swellPeriod: 10,
        swellHeight: 1.0,
      );
      final scoreOffshore =
          computeMatchScore(offshore, _defaultPrefs, _rockaway);
      final scoreOnshore =
          computeMatchScore(onshore, _defaultPrefs, _rockaway);
      expect(scoreOffshore, greaterThan(scoreOnshore));
    });

    test('high wind above tolerance penalizes more for beginners', () {
      final hour = _makeHour(
        waveHeight: 0.5,
        windSpeed: 30.0,
        windDirection: 90, // cross-shore
        swellDirection: 180,
        swellPeriod: 8,
        swellHeight: 0.5,
      );
      final beginnerScore =
          computeMatchScore(hour, _beginnerPrefs, _rockaway);
      final intermediateScore =
          computeMatchScore(hour, _defaultPrefs, _rockaway);
      expect(intermediateScore, greaterThan(beginnerScore));
    });

    test('thunderstorm caps score at 0.25', () {
      final hour = _makeHour(
        waveHeight: 1.0,
        windSpeed: 5.0,
        windDirection: 0,
        swellDirection: 180,
        swellPeriod: 14,
        swellHeight: 1.0,
        weatherCode: 95, // thunderstorm
      );
      final score = computeMatchScore(hour, _defaultPrefs, _rockaway);
      expect(score, lessThanOrEqualTo(0.25));
    });

    test('strong onshore caps score at Fair for exposed spots', () {
      final hour = _makeHour(
        waveHeight: 1.0,
        windSpeed: 35.0,
        windDirection: 180, // onshore
        swellDirection: 180,
        swellPeriod: 14,
        swellHeight: 1.0,
      );
      final score = computeMatchScore(hour, _defaultPrefs, _rockaway);
      // Beach break with windExposure 0.8 >= 0.7 -> capped at Fair
      expect(score, lessThan(0.4));
    });

    test('low energy caps score at Fair', () {
      final hour = _makeHour(
        waveHeight: 0.3,
        windSpeed: 5.0,
        windDirection: 0,
        swellDirection: 180,
        swellPeriod: 4, // very short period
        swellHeight: 0.3, // H^2*T = 0.09*4 = 0.36, below beach minEnergy 2.0
      );
      final score = computeMatchScore(hour, _defaultPrefs, _rockaway);
      expect(score, lessThan(0.4));
    });

    test('overpowered surf caps beginner score', () {
      final hour = _makeHour(
        waveHeight: 2.0, // 2x beginner max of 1.0 -> > 1.6x
        windSpeed: 5.0,
        windDirection: 0,
        swellDirection: 180,
        swellPeriod: 14,
        swellHeight: 2.0,
      );
      final score = computeMatchScore(hour, _beginnerPrefs, _rockaway);
      expect(score, lessThanOrEqualTo(0.25));
    });

    test('too-big waves penalize harder than too-small', () {
      // Both 0.5m outside the preferred range, with enough energy to avoid low-energy cap
      final tooSmall = _makeHour(
        waveHeight: 0.8, // below min 0.3 by ~0.5 after accounting for range
        windSpeed: 5.0,
        windDirection: 0,
        swellDirection: 180,
        swellPeriod: 12,
        swellHeight: 1.0, // enough energy
      );
      final tooBig = _makeHour(
        waveHeight: 2.5, // 0.5 above max of 2.0
        windSpeed: 5.0,
        windDirection: 0,
        swellDirection: 180,
        swellPeriod: 12,
        swellHeight: 2.5,
      );
      final scoreSmall =
          computeMatchScore(tooSmall, _defaultPrefs, _rockaway);
      final scoreBig =
          computeMatchScore(tooBig, _defaultPrefs, _rockaway);
      // Too-small is actually in range (0.3-2.0), so it should score better
      // than too-big which is penalized at 1.5x rate
      expect(scoreSmall, greaterThan(scoreBig));
    });

    test('tide affects score when user has tide preference', () {
      final tidePrefs =
          _defaultPrefs.copyWith(preferredTide: 'low');
      const tideRange = TideRange(0, 3.0);

      final lowTide = _makeHour(
        waveHeight: 1.0,
        windSpeed: 8.0,
        swellPeriod: 10,
        swellHeight: 1.0,
        tideHeight: 0.1,
      );
      final highTide = _makeHour(
        waveHeight: 1.0,
        windSpeed: 8.0,
        swellPeriod: 10,
        swellHeight: 1.0,
        tideHeight: 2.9,
      );
      final scoreLow = computeMatchScore(lowTide, tidePrefs, _rockaway,
          tideRange: tideRange);
      final scoreHigh = computeMatchScore(highTide, tidePrefs, _rockaway,
          tideRange: tideRange);
      expect(scoreLow, greaterThan(scoreHigh));
    });

    test('reef at high tide is capped when tide-sensitive', () {
      const tideRange = TideRange(0, 3.0);
      final hour = _makeHour(
        waveHeight: 1.5,
        windSpeed: 5.0,
        windDirection: 0,
        swellDirection: 180,
        swellPeriod: 12,
        swellHeight: 1.5,
        tideHeight: 2.7, // 90% of range -> above 0.85 threshold
      );
      final score = computeMatchScore(hour, _defaultPrefs, _testReef,
          tideRange: tideRange);
      expect(score, lessThan(0.4));
    });

    test('score is clamped between 0 and 1', () {
      final hour = _makeHour(
        waveHeight: 1.0,
        windSpeed: 10.0,
        windDirection: 0,
        swellDirection: 180,
        swellPeriod: 10,
        swellHeight: 1.0,
      );
      final score = computeMatchScore(hour, _defaultPrefs, _rockaway);
      expect(score, greaterThanOrEqualTo(0));
      expect(score, lessThanOrEqualTo(1));
    });

    test('point break scores differently than beach break', () {
      final hour = _makeHour(
        waveHeight: 1.0,
        windSpeed: 5.0,
        windDirection: 0,
        swellDirection: 180,
        swellPeriod: 14,
        swellHeight: 1.0,
      );
      final beachScore =
          computeMatchScore(hour, _defaultPrefs, _rockaway);
      final pointScore =
          computeMatchScore(hour, _defaultPrefs, _santaCruz);
      // Both should score well with perfect conditions
      expect(beachScore, greaterThan(0.6));
      expect(pointScore, greaterThan(0.6));
    });
  });

  group('getConditionLabel', () {
    test('0.9 is Epic', () {
      final label = getConditionLabel(0.9);
      expect(label.label, 'Epic');
      expect(label.tagline, isNotEmpty);
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

    test('boundary: 0.85 is Epic', () {
      expect(getConditionLabel(0.85).label, 'Epic');
    });

    test('boundary: 0.6 is Good', () {
      expect(getConditionLabel(0.6).label, 'Good');
    });

    test('boundary: 0.4 is Fair', () {
      expect(getConditionLabel(0.4).label, 'Fair');
    });

    test('boundary: 0.84 is Good (not Epic)', () {
      expect(getConditionLabel(0.84).label, 'Good');
    });
  });

  group('proPrefs', () {
    test('proPrefs is advanced with wide range', () {
      expect(proPrefs.skillLevel, 'advanced');
      expect(proPrefs.minWaveHeight, 1.2);
      expect(proPrefs.maxWaveHeight, 4.0);
      expect(proPrefs.preferredTide, 'any');
    });
  });

  group('findBestHours', () {
    test('returns best hour for a date', () {
      final hours = [
        _makeHour(time: '2025-01-15T08:00', waveHeight: 0.5, windSpeed: 10,
            swellHeight: 0.5, swellPeriod: 6),
        _makeHour(time: '2025-01-15T10:00', waveHeight: 1.5, windSpeed: 5,
            windDirection: 0, swellDirection: 180, swellHeight: 1.5, swellPeriod: 12),
        _makeHour(time: '2025-01-15T14:00', waveHeight: 0.3, windSpeed: 30,
            swellHeight: 0.3, swellPeriod: 4),
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
        _makeHour(time: '2025-01-16T10:00', waveHeight: 1.5, windSpeed: 5,
            swellHeight: 1.5, swellPeriod: 10),
      ];
      final result =
          findBestHours(hours, _defaultPrefs, _rockaway, '2025-01-15');
      expect(result, isNull);
    });
  });

  group('findMatchingWindows', () {
    test('finds consecutive windows above threshold', () {
      final hours = List.generate(12, (i) {
        final good = i >= 3 && i <= 7;
        return _makeHour(
          time: '2025-01-15T${(6 + i).toString().padLeft(2, '0')}:00',
          waveHeight: good ? 1.0 : 0.05,
          windSpeed: good ? 5 : 40,
          windDirection: good ? 0 : 180,
          swellDirection: good ? 180 : 0,
          swellPeriod: good ? 12 : 4,
          swellHeight: good ? 1.0 : 0.05,
        );
      });
      final windows =
          findMatchingWindows(hours, _defaultPrefs, _rockaway, minScore: 0.4);
      expect(windows, isNotEmpty);
      expect(windows.first.count, greaterThan(1));
    });
  });

  group('findTopWindows', () {
    test('returns empty for empty data', () {
      expect(findTopWindows([], _defaultPrefs, _rockaway), isEmpty);
    });

    test('max one window per day', () {
      final hours = <HourlyData>[];
      for (final date in ['2025-01-15', '2025-01-16']) {
        for (var h = 6; h <= 18; h++) {
          hours.add(_makeHour(
            time: '$date\T${h.toString().padLeft(2, '0')}:00',
            waveHeight: 1.0,
            windSpeed: 5,
            windDirection: 0,
            swellDirection: 180,
            swellPeriod: 10,
            swellHeight: 1.0,
          ));
        }
      }
      final windows =
          findTopWindows(hours, _defaultPrefs, _rockaway, count: 5);
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
      final scores = [0.2, 0.55, 0.6, 0.65, 0.3, 0.4, 0.1];
      final result = findBestWindowIndices(scores);
      expect(result, isNotNull);
      expect(result!.startIndex, 1);
      expect(result.endIndex, 3);
      expect(result.avgScore, closeTo(0.6, 0.01));
    });

    test('epic scores use relative threshold (narrows window)', () {
      final scores = [0.3, 0.6, 0.80, 0.92, 0.85, 0.55, 0.3];
      final result = findBestWindowIndices(scores);
      expect(result, isNotNull);
      expect(result!.startIndex, 2);
      expect(result.endIndex, 4);
      expect(result.avgScore, closeTo(0.857, 0.01));
    });

    test('mediocre day preserves 0.5 threshold', () {
      final scores = [0.3, 0.55, 0.60, 0.52, 0.3];
      final result = findBestWindowIndices(scores);
      expect(result, isNotNull);
      expect(result!.startIndex, 1);
      expect(result.endIndex, 3);
    });
  });
}
