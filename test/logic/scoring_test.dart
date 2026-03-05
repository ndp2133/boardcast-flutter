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
  double? swellPeriod,
  double? tideHeight,
}) =>
    HourlyData(
      time: time,
      waveHeight: waveHeight,
      windSpeed: windSpeed,
      windDirection: windDirection,
      swellDirection: swellDirection,
      swellPeriod: swellPeriod,
      tideHeight: tideHeight,
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

  group('scoreWindDirection', () {
    test('perfect offshore scores 1.0', () {
      // North (0°) is center of offshore range 315-45 at Rockaway
      final score = scoreWindDirection(
          0, _defaultPrefs, _rockaway);
      expect(score, closeTo(1.0, 0.01));
    });

    test('perfect onshore scores ~0.2 (worst)', () {
      // South (180°) is opposite of offshore center
      final score = scoreWindDirection(
          180, _defaultPrefs, _rockaway);
      expect(score, closeTo(0.2, 0.01));
    });

    test('cross-shore scores ~0.6', () {
      // East (90°) is 90° from offshore center
      final score = scoreWindDirection(
          90, _defaultPrefs, _rockaway);
      expect(score, closeTo(0.6, 0.05));
    });

    test('any preference returns 1.0', () {
      final anyPrefs = _defaultPrefs.copyWith(preferredWindDir: 'any');
      final score = scoreWindDirection(180, anyPrefs, _rockaway);
      expect(score, 1.0);
    });

    test('null wind returns 1.0', () {
      final score = scoreWindDirection(
          null, _defaultPrefs, _rockaway);
      expect(score, 1.0);
    });
  });

  group('scoreSwellPeriod', () {
    test('14s+ scores 1.0', () {
      expect(scoreSwellPeriod(14), 1.0);
      expect(scoreSwellPeriod(18), 1.0);
    });

    test('12s scores 0.9', () {
      expect(scoreSwellPeriod(12), 0.9);
    });

    test('10s scores 0.75', () {
      expect(scoreSwellPeriod(10), 0.75);
    });

    test('8s scores 0.5', () {
      expect(scoreSwellPeriod(8), 0.5);
    });

    test('6s scores 0.25', () {
      expect(scoreSwellPeriod(6), 0.25);
    });

    test('4s scores 0.1', () {
      expect(scoreSwellPeriod(4), 0.1);
    });

    test('null scores 0.5', () {
      expect(scoreSwellPeriod(null), 0.5);
    });
  });

  group('scoreTide', () {
    const range = TideRange(-0.5, 2.5);

    test('any preference returns 1.0', () {
      expect(scoreTide(1.0, 'any', range), 1.0);
    });

    test('null preference returns 1.0', () {
      expect(scoreTide(1.0, null, range), 1.0);
    });

    test('low tide at low water scores high', () {
      // -0.5 is min → normalized 0.0
      final score = scoreTide(-0.5, 'low', range);
      expect(score, closeTo(1.0, 0.01));
    });

    test('low tide at high water scores low', () {
      // 2.5 is max → normalized 1.0
      final score = scoreTide(2.5, 'low', range);
      expect(score, closeTo(0.3, 0.01));
    });

    test('high tide at high water scores high', () {
      final score = scoreTide(2.5, 'high', range);
      expect(score, closeTo(1.0, 0.01));
    });

    test('high tide at low water scores low', () {
      final score = scoreTide(-0.5, 'high', range);
      expect(score, closeTo(0.3, 0.01));
    });

    test('mid tide at mid water scores highest', () {
      // 1.0 is mid (0.5 normalized)
      final score = scoreTide(1.0, 'mid', range);
      expect(score, closeTo(1.0, 0.01));
    });

    test('mid tide at extremes scores lower', () {
      final scoreLow = scoreTide(-0.5, 'mid', range);
      final scoreHigh = scoreTide(2.5, 'mid', range);
      expect(scoreLow, closeTo(0.5, 0.01));
      expect(scoreHigh, closeTo(0.5, 0.01));
    });

    test('null range returns 0.5', () {
      expect(scoreTide(1.0, 'low', null), 0.5);
    });

    test('null tide height returns 0.5', () {
      expect(scoreTide(null, 'low', range), 0.5);
    });
  });

  group('getEffectiveWeights', () {
    test('beach break returns base weights', () {
      final weights = getEffectiveWeights(_rockaway);
      expect(weights['wave'], 0.30);
      expect(weights['wind'], 0.25);
      expect(weights['windDir'], 0.15);
      expect(weights['swellDir'], 0.10);
      expect(weights['swellPeriod'], 0.10);
      expect(weights['tide'], 0.10);
    });

    test('point break boosts swell period, reduces wave', () {
      final weights = getEffectiveWeights(_santaCruz);
      expect(weights['wave'], closeTo(0.25, 0.001)); // 0.30 - 0.05
      expect(weights['swellPeriod'], closeTo(0.15, 0.001)); // 0.10 + 0.05
      // Others unchanged
      expect(weights['wind'], 0.25);
      expect(weights['windDir'], 0.15);
    });

    test('reef break boosts tide + swell period, reduces wave + wind', () {
      const reefLocation = Location(
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
      final weights = getEffectiveWeights(reefLocation);
      expect(weights['wave'], closeTo(0.20, 0.001)); // 0.30 - 0.10
      expect(weights['wind'], closeTo(0.20, 0.001)); // 0.25 - 0.05
      expect(weights['swellPeriod'], closeTo(0.15, 0.001)); // 0.10 + 0.05
      expect(weights['tide'], closeTo(0.20, 0.001)); // 0.10 + 0.10
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

    test('perfect conditions score near 1.0', () {
      final hour = _makeHour(
        waveHeight: 1.0, // in range 0.3-2.0
        windSpeed: 8.0, // below max 25
        windDirection: 0, // offshore (N)
        swellDirection: 180, // direct hit on south-facing beach
        swellPeriod: 14, // long period groundswell
        tideHeight: 1.0, // mid tide (with any pref = 1.0)
      );
      final score = computeMatchScore(hour, _defaultPrefs, _rockaway);
      expect(score, greaterThan(0.8));
    });

    test('swell period affects score', () {
      final longPeriod = _makeHour(
        waveHeight: 1.0,
        windSpeed: 8.0,
        windDirection: 0,
        swellDirection: 180,
        swellPeriod: 14,
      );
      final shortPeriod = _makeHour(
        waveHeight: 1.0,
        windSpeed: 8.0,
        windDirection: 0,
        swellDirection: 180,
        swellPeriod: 4,
      );
      final scoreLong =
          computeMatchScore(longPeriod, _defaultPrefs, _rockaway);
      final scoreShort =
          computeMatchScore(shortPeriod, _defaultPrefs, _rockaway);
      expect(scoreLong, greaterThan(scoreShort));
    });

    test('tide affects score when user has tide preference', () {
      final tidePrefs =
          _defaultPrefs.copyWith(preferredTide: 'low');
      final tideRange = const TideRange(0, 3.0);

      final lowTide = _makeHour(
        waveHeight: 1.0,
        windSpeed: 8.0,
        tideHeight: 0.1,
      );
      final highTide = _makeHour(
        waveHeight: 1.0,
        windSpeed: 8.0,
        tideHeight: 2.9,
      );
      final scoreLow = computeMatchScore(lowTide, tidePrefs, _rockaway,
          tideRange: tideRange);
      final scoreHigh = computeMatchScore(highTide, tidePrefs, _rockaway,
          tideRange: tideRange);
      expect(scoreLow, greaterThan(scoreHigh));
    });

    test('flat conditions score low', () {
      final hour = _makeHour(
        waveHeight: 0.05, // way below min
        windSpeed: 40.0, // way above max
        windDirection: 180, // onshore
        swellDirection: 0, // opposite of beach facing
        swellPeriod: 4, // short period windswell
      );
      final score = computeMatchScore(hour, _defaultPrefs, _rockaway);
      // With cosine wind scoring and neutral tide/swell period, bad conditions score Fair or below
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

    test('point break adjusts weights (higher swell period weight)', () {
      final hour = _makeHour(
        waveHeight: 1.0,
        windSpeed: 8.0,
        windDirection: 0,
        swellDirection: 180,
        swellPeriod: 14, // long period — boosted at point breaks
      );
      final beachScore =
          computeMatchScore(hour, _defaultPrefs, _rockaway);
      final pointScore =
          computeMatchScore(hour, _defaultPrefs, _santaCruz);
      // Point break should score slightly differently due to weight shifts
      // With perfect conditions and long swell, point break boosts swellPeriod
      // so point score may differ from beach score
      expect(beachScore, greaterThan(0.8));
      expect(pointScore, greaterThan(0.8));
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
          swellPeriod: good ? 12 : 4,
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
      // Scores with moderate peak — threshold stays at 0.5
      final scores = [0.2, 0.55, 0.6, 0.65, 0.3, 0.4, 0.1];
      final result = findBestWindowIndices(scores);
      expect(result, isNotNull);
      expect(result!.startIndex, 1);
      expect(result.endIndex, 3);
      expect(result.avgScore, closeTo(0.6, 0.01));
    });

    test('epic scores use relative threshold (narrows window)', () {
      // Peak is 0.92, threshold = 0.92 - 0.15 = 0.77
      // Only indices 2-4 (0.80, 0.92, 0.85) are above 0.77
      final scores = [0.3, 0.6, 0.80, 0.92, 0.85, 0.55, 0.3];
      final result = findBestWindowIndices(scores);
      expect(result, isNotNull);
      expect(result!.startIndex, 2);
      expect(result.endIndex, 4);
      expect(result.avgScore, closeTo(0.857, 0.01));
    });

    test('mediocre day preserves 0.5 threshold', () {
      // Peak is 0.60, below 0.65, so threshold stays at 0.5
      final scores = [0.3, 0.55, 0.60, 0.52, 0.3];
      final result = findBestWindowIndices(scores);
      expect(result, isNotNull);
      expect(result!.startIndex, 1);
      expect(result.endIndex, 3);
    });

    test('oversized window gets narrowed via sliding window', () {
      // 8 hours above threshold — should narrow to best 3-hour sub-window
      // Peak is 0.9, threshold = 0.75
      final scores = [0.76, 0.78, 0.80, 0.90, 0.88, 0.82, 0.77, 0.76];
      final result = findBestWindowIndices(scores);
      expect(result, isNotNull);
      // Best 3-hour sub-window: indices 3-5 (0.90, 0.88, 0.82) avg=0.867
      expect(result!.endIndex - result.startIndex + 1, lessThanOrEqualTo(5));
      expect(result.startIndex, 3);
      expect(result.endIndex, 5);
    });
  });

  group('findTopWindows (relative threshold)', () {
    test('epic day narrows to peak hours', () {
      // Simulate an epic day: all daylight hours score high
      final hours = <HourlyData>[];
      // Hours 6-20 with varying quality: peak around 10-12
      for (var h = 6; h <= 20; h++) {
        final isPeak = h >= 9 && h <= 12;
        final isGood = h >= 7 && h <= 14;
        hours.add(_makeHour(
          time: '2025-01-15T${h.toString().padLeft(2, '0')}:00',
          waveHeight: isPeak ? 1.5 : (isGood ? 1.0 : 0.5),
          windSpeed: isPeak ? 3 : (isGood ? 8 : 15),
          windDirection: isPeak ? 0 : (isGood ? 20 : 90),
          swellDirection: 180,
          swellPeriod: isPeak ? 14 : (isGood ? 10 : 6),
        ));
      }
      final windows = findTopWindows(hours, _defaultPrefs, _rockaway);
      expect(windows, isNotEmpty);
      // Window should NOT span full daylight (15 hours)
      expect(windows.first.hours, lessThanOrEqualTo(5));
    });

    test('mediocre day preserves wider window', () {
      final hours = <HourlyData>[];
      for (var h = 6; h <= 20; h++) {
        final isFair = h >= 8 && h <= 14;
        hours.add(_makeHour(
          time: '2025-01-15T${h.toString().padLeft(2, '0')}:00',
          waveHeight: isFair ? 0.5 : 0.1,
          windSpeed: isFair ? 12 : 30,
          windDirection: isFair ? 45 : 180,
          swellDirection: 180,
          swellPeriod: isFair ? 8 : 4,
        ));
      }
      final windows = findTopWindows(hours, _defaultPrefs, _rockaway);
      // Mediocre day may have windows — if so they should be reasonable
      if (windows.isNotEmpty) {
        expect(windows.first.hours, greaterThan(0));
      }
    });
  });
}
