import 'package:flutter_test/flutter_test.dart';
import 'package:boardcast_flutter/logic/scoring.dart';
import 'package:boardcast_flutter/logic/score_breakdown_helpers.dart';
import 'package:boardcast_flutter/models/hourly_data.dart';
import 'package:boardcast_flutter/models/location.dart';
import 'package:boardcast_flutter/models/user_prefs.dart';

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
  group('computeMatchScoreBreakdown', () {
    test('returns zero breakdown for null inputs', () {
      final bd = computeMatchScoreBreakdown(null, _defaultPrefs, _rockaway);
      expect(bd.finalScore, 0);
      expect(bd.heightScore, 0);
      expect(bd.qualityScore, 0);
      expect(bd.dirScore, 0);
      expect(bd.activeCaps, isEmpty);
    });

    test('finalScore matches computeMatchScore for perfect conditions', () {
      final hour = _makeHour(
        waveHeight: 1.0,
        windSpeed: 5.0,
        windDirection: 0,
        swellDirection: 180,
        swellPeriod: 14,
        swellHeight: 1.0,
        tideHeight: 1.0,
      );
      final score = computeMatchScore(hour, _defaultPrefs, _rockaway);
      final bd = computeMatchScoreBreakdown(hour, _defaultPrefs, _rockaway);
      expect(bd.finalScore, score);
    });

    test('finalScore matches computeMatchScore across varied conditions', () {
      final conditions = [
        _makeHour(waveHeight: 0.5, windSpeed: 10, swellPeriod: 6, swellHeight: 0.5),
        _makeHour(waveHeight: 2.0, windSpeed: 30, windDirection: 180,
            swellDirection: 180, swellPeriod: 8, swellHeight: 2.0),
        _makeHour(waveHeight: 1.0, windSpeed: 5, windDirection: 0,
            swellDirection: 180, swellPeriod: 14, swellHeight: 1.0),
        _makeHour(waveHeight: 0.3, windSpeed: 5, swellPeriod: 4, swellHeight: 0.3),
      ];
      for (final hour in conditions) {
        final score = computeMatchScore(hour, _defaultPrefs, _rockaway);
        final bd = computeMatchScoreBreakdown(hour, _defaultPrefs, _rockaway);
        expect(bd.finalScore, score, reason: 'Mismatch for ${hour.waveHeight}m');
      }
    });

    test('returns all component scores in valid ranges', () {
      final hour = _makeHour(
        waveHeight: 1.0,
        windSpeed: 10.0,
        windDirection: 0,
        swellDirection: 180,
        swellPeriod: 12,
        swellHeight: 1.0,
        tideHeight: 1.0,
      );
      final bd = computeMatchScoreBreakdown(hour, _defaultPrefs, _rockaway);
      expect(bd.heightScore, inInclusiveRange(0, 1));
      expect(bd.qualityScore, inInclusiveRange(0, 1));
      expect(bd.dirScore, inInclusiveRange(0, 1));
      expect(bd.windMult, inInclusiveRange(0, 1.1)); // wind can slightly exceed 1
      expect(bd.finalScore, inInclusiveRange(0, 1));
      expect(bd.energy, greaterThanOrEqualTo(0));
    });

    test('populates context fields correctly', () {
      final hour = _makeHour(
        waveHeight: 1.5,
        windSpeed: 12.0,
        windDirection: 0,
        swellDirection: 180,
        swellPeriod: 10,
        swellHeight: 1.5,
        tideHeight: 1.0,
      );
      const tideRange = TideRange(0, 3.0);
      final bd = computeMatchScoreBreakdown(hour, _defaultPrefs, _rockaway,
          tideRange: tideRange);
      expect(bd.actualWaveHeight, 1.5);
      expect(bd.idealMin, 0.3);
      expect(bd.idealMax, 2.0);
      expect(bd.windSpeed, 12.0);
      expect(bd.windDirection, 0);
      expect(bd.swellPeriod, 10);
      expect(bd.beachFacing, 180);
      expect(bd.breakType, 'beach');
      expect(bd.isOffshore, true);
      expect(bd.isOnshore, false);
      expect(bd.tideNormalized, closeTo(0.333, 0.01));
    });

    test('thunderstorm hard cap populates correctly', () {
      final hour = _makeHour(
        waveHeight: 1.0,
        windSpeed: 5.0,
        windDirection: 0,
        swellDirection: 180,
        swellPeriod: 14,
        swellHeight: 1.0,
        weatherCode: 95,
      );
      final bd = computeMatchScoreBreakdown(hour, _defaultPrefs, _rockaway);
      expect(bd.activeCaps, contains(HardCap.thunderstorm));
      expect(bd.finalScore, lessThanOrEqualTo(0.25));
      expect(bd.preCapsScore, greaterThan(bd.finalScore));
    });

    test('low energy hard cap populates correctly', () {
      final hour = _makeHour(
        waveHeight: 0.3,
        windSpeed: 5.0,
        windDirection: 0,
        swellDirection: 180,
        swellPeriod: 4,
        swellHeight: 0.3,
      );
      final bd = computeMatchScoreBreakdown(hour, _defaultPrefs, _rockaway);
      expect(bd.activeCaps, contains(HardCap.lowEnergy));
      expect(bd.finalScore, lessThan(0.4));
    });

    test('oversized beginner hard cap populates correctly', () {
      final hour = _makeHour(
        waveHeight: 2.0,
        windSpeed: 5.0,
        windDirection: 0,
        swellDirection: 180,
        swellPeriod: 14,
        swellHeight: 2.0,
      );
      final bd = computeMatchScoreBreakdown(hour, _beginnerPrefs, _rockaway);
      expect(bd.activeCaps, contains(HardCap.oversizedBeginner));
      expect(bd.finalScore, lessThanOrEqualTo(0.25));
    });

    test('strong onshore hard cap populates correctly', () {
      final hour = _makeHour(
        waveHeight: 1.0,
        windSpeed: 35.0,
        windDirection: 180,
        swellDirection: 180,
        swellPeriod: 14,
        swellHeight: 1.0,
      );
      final bd = computeMatchScoreBreakdown(hour, _defaultPrefs, _rockaway);
      expect(bd.activeCaps, contains(HardCap.strongOnshore));
      expect(bd.finalScore, lessThan(0.4));
    });

    test('wrong tide at reef populates correctly', () {
      const tideRange = TideRange(0, 3.0);
      final hour = _makeHour(
        waveHeight: 1.5,
        windSpeed: 5.0,
        windDirection: 0,
        swellDirection: 180,
        swellPeriod: 12,
        swellHeight: 1.5,
        tideHeight: 2.7,
      );
      final bd = computeMatchScoreBreakdown(hour, _defaultPrefs, _testReef,
          tideRange: tideRange);
      expect(bd.activeCaps, contains(HardCap.wrongTide));
      expect(bd.finalScore, lessThan(0.4));
    });

    test('no caps for clean conditions', () {
      final hour = _makeHour(
        waveHeight: 1.0,
        windSpeed: 5.0,
        windDirection: 0,
        swellDirection: 180,
        swellPeriod: 14,
        swellHeight: 1.0,
      );
      final bd = computeMatchScoreBreakdown(hour, _defaultPrefs, _rockaway);
      expect(bd.activeCaps, isEmpty);
    });
  });

  group('buildFactorSummaries', () {
    test('returns 4 factors', () {
      final hour = _makeHour(
        waveHeight: 1.0,
        windSpeed: 5.0,
        windDirection: 0,
        swellDirection: 180,
        swellPeriod: 12,
        swellHeight: 1.0,
      );
      final bd = computeMatchScoreBreakdown(hour, _defaultPrefs, _rockaway);
      final factors = buildFactorSummaries(bd);
      expect(factors.length, 4);
      final names = factors.map((f) => f.name).toSet();
      expect(names, containsAll(['Waves', 'Swell', 'Wind', 'Tide']));
    });

    test('perfect conditions produce helping statuses', () {
      final hour = _makeHour(
        waveHeight: 1.0,
        windSpeed: 3.0,
        windDirection: 0,
        swellDirection: 180,
        swellPeriod: 14,
        swellHeight: 1.0,
      );
      final bd = computeMatchScoreBreakdown(hour, _defaultPrefs, _rockaway);
      final factors = buildFactorSummaries(bd);
      final waves = factors.firstWhere((f) => f.name == 'Waves');
      final swell = factors.firstWhere((f) => f.name == 'Swell');
      final wind = factors.firstWhere((f) => f.name == 'Wind');
      expect(waves.status, FactorStatus.helping);
      expect(swell.status, FactorStatus.helping);
      expect(wind.status, FactorStatus.helping);
    });

    test('bad conditions produce hurting statuses', () {
      final hour = _makeHour(
        waveHeight: 0.1,
        windSpeed: 40.0,
        windDirection: 180,
        swellDirection: 0,
        swellPeriod: 4,
        swellHeight: 0.1,
      );
      final bd = computeMatchScoreBreakdown(hour, _defaultPrefs, _rockaway);
      final factors = buildFactorSummaries(bd);
      final wind = factors.firstWhere((f) => f.name == 'Wind');
      expect(wind.status, FactorStatus.hurting);
    });

    test('sorted by impact: helping first', () {
      final hour = _makeHour(
        waveHeight: 1.0,
        windSpeed: 30.0,
        windDirection: 180,
        swellDirection: 180,
        swellPeriod: 14,
        swellHeight: 1.0,
      );
      final bd = computeMatchScoreBreakdown(hour, _defaultPrefs, _rockaway);
      final factors = buildFactorSummaries(bd);
      // First factor should have highest impact
      for (var i = 1; i < factors.length; i++) {
        expect(factors[i - 1].impact, greaterThanOrEqualTo(factors[i].impact));
      }
    });
  });

  group('hardCapExplanation', () {
    test('returns non-empty string for all cap types', () {
      for (final cap in HardCap.values) {
        expect(hardCapExplanation(cap), isNotEmpty);
      }
    });
  });

  group('hardCapSummary', () {
    test('returns empty for no caps', () {
      expect(hardCapSummary([]), '');
    });

    test('thunderstorm takes priority', () {
      final summary = hardCapSummary([HardCap.lowEnergy, HardCap.thunderstorm]);
      expect(summary, contains('lightning'));
    });

    test('returns summary for single cap', () {
      expect(hardCapSummary([HardCap.strongOnshore]), contains('onshore'));
    });
  });
}
