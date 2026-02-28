import 'package:flutter_test/flutter_test.dart';
import 'package:boardcast_flutter/logic/ai_formatters.dart';
import 'package:boardcast_flutter/models/current_conditions.dart';
import 'package:boardcast_flutter/models/daily_data.dart';
import 'package:boardcast_flutter/models/hourly_data.dart';
import 'package:boardcast_flutter/models/user_prefs.dart';
import 'package:boardcast_flutter/logic/scoring.dart';

void main() {
  group('formatCurrentConditions', () {
    test('formats all fields when populated', () {
      final current = CurrentConditions(
        waveHeight: 1.0,    // ~3.3ft
        windSpeed: 16.0,    // ~10mph
        windDirection: 180,  // S
        swellPeriod: 12.0,
        tideHeight: 1.2,
        tideTrend: 'Rising',
        timestamp: '2026-02-27T12:00:00',
      );

      final result = formatCurrentConditions(current);
      expect(result, contains('Waves:'));
      expect(result, contains('ft'));
      expect(result, contains('mph'));
      expect(result, contains('S'));
      expect(result, contains('12s'));
      expect(result, contains('Rising'));
    });

    test('uses -- for null fields', () {
      final current = CurrentConditions(
        timestamp: '2026-02-27T12:00:00',
      );

      final result = formatCurrentConditions(current);
      expect(result, contains('Waves: --ft'));
      expect(result, contains('Wind: --mph --'));
      expect(result, contains('Swell period: --'));
      expect(result, contains('Tide: --'));
    });

    test('handles tide height without trend', () {
      final current = CurrentConditions(
        tideHeight: 2.0,
        timestamp: '2026-02-27T12:00:00',
      );

      final result = formatCurrentConditions(current);
      expect(result, contains('Tide: 2.0ft'));
    });
  });

  group('formatDailySummaries', () {
    test('formats daily data with hourly wind averages', () {
      final daily = [
        DailyData(
          date: '2026-03-01',
          waveHeightMax: 2.0,
          waveDirectionDominant: 270,
          tempMax: 20.0,
          tempMin: 10.0,
        ),
      ];
      final hourly = [
        HourlyData(time: '2026-03-01T08:00', windSpeed: 20.0),
        HourlyData(time: '2026-03-01T09:00', windSpeed: 30.0),
      ];

      final result = formatDailySummaries(daily, hourly);
      expect(result, contains('2026-03-01'));
      expect(result, contains('ft'));
      expect(result, contains('W'));
      expect(result, contains('Avg wind:'));
    });

    test('handles empty daily list', () {
      final result = formatDailySummaries([], []);
      expect(result, isEmpty);
    });

    test('handles null wave/temp fields', () {
      final daily = [DailyData(date: '2026-03-01')];
      final result = formatDailySummaries(daily, []);
      expect(result, contains('--'));
    });
  });

  group('formatTopWindows', () {
    test('formats ranked windows', () {
      final windows = [
        TopWindow(
          date: '2026-03-01',
          startTime: '2026-03-01T09:00',
          endTime: '2026-03-01T14:00',
          avgScore: 0.75,
          hours: 6,
          waveHeight: 1.5,
        ),
      ];

      final result = formatTopWindows(windows);
      expect(result, contains('75%'));
      expect(result, contains('6h'));
      expect(result, contains('ft waves'));
    });

    test('returns message for empty windows', () {
      final result = formatTopWindows([]);
      expect(result, equals('No good windows found this week.'));
    });

    test('handles null waveHeight in window', () {
      final windows = [
        TopWindow(
          date: '2026-03-01',
          startTime: '2026-03-01T09:00',
          endTime: '2026-03-01T12:00',
          avgScore: 0.6,
          hours: 4,
        ),
      ];

      final result = formatTopWindows(windows);
      expect(result, contains('--ft waves'));
    });
  });

  group('buildPrefsPayload', () {
    test('converts all fields to imperial', () {
      final prefs = UserPrefs(
        skillLevel: 'intermediate',
        minWaveHeight: 0.6,   // ~2.0ft
        maxWaveHeight: 2.0,   // ~6.6ft
        maxWindSpeed: 35.0,   // ~22mph
        preferredWindDir: 'offshore',
      );

      final payload = buildPrefsPayload(prefs);
      expect(payload['skillLevel'], 'intermediate');
      expect(payload['preferredWindDir'], 'offshore');
      expect(double.parse(payload['minWave']), closeTo(2.0, 0.1));
      expect(double.parse(payload['maxWave']), closeTo(6.6, 0.1));
      expect(int.parse(payload['maxWind']), closeTo(22, 1));
    });

    test('handles null optional fields', () {
      const prefs = UserPrefs();

      final payload = buildPrefsPayload(prefs);
      expect(payload['skillLevel'], 'intermediate');
      expect(payload['minWave'], isNull);
      expect(payload['maxWave'], isNull);
      expect(payload['maxWind'], isNull);
      expect(payload['preferredWindDir'], 'any');
    });
  });
}
