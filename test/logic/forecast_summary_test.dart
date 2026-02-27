import 'package:flutter_test/flutter_test.dart';
import 'package:boardcast_flutter/logic/forecast_summary.dart';
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

const _prefs = UserPrefs(
  minWaveHeight: 0.3,
  maxWaveHeight: 2.0,
  maxWindSpeed: 25.0,
  preferredWindDir: 'offshore',
);

void main() {
  group('generateForecastSummary', () {
    test('returns empty for empty hours', () {
      expect(generateForecastSummary([], _prefs, _rockaway), '');
    });

    test('returns flat day for tiny waves', () {
      final hours = List.generate(
        12,
        (i) => HourlyData(
          time: '2025-01-15T${(6 + i).toString().padLeft(2, '0')}:00',
          waveHeight: 0.05, // tiny
          windSpeed: 5,
        ),
      );
      final result = generateForecastSummary(hours, _prefs, _rockaway);
      expect(result, contains('Flat day'));
    });

    test('includes wave size word for decent waves', () {
      final hours = List.generate(
        12,
        (i) => HourlyData(
          time: '2025-01-15T${(6 + i).toString().padLeft(2, '0')}:00',
          waveHeight: 0.6, // ~2 ft = Small
          windSpeed: 8,
          windDirection: 0,
          swellDirection: 180,
        ),
      );
      final result = generateForecastSummary(hours, _prefs, _rockaway);
      expect(result, contains('Small'));
      expect(result, contains('waves'));
      expect(result, contains('winds'));
    });

    test('includes glassy for calm wind', () {
      final hours = List.generate(
        12,
        (i) => HourlyData(
          time: '2025-01-15T${(6 + i).toString().padLeft(2, '0')}:00',
          waveHeight: 1.0,
          windSpeed: 3, // very light
        ),
      );
      final result = generateForecastSummary(hours, _prefs, _rockaway);
      expect(result, contains('glassy'));
    });

    test('filters to daylight hours only', () {
      // Only provide nighttime hours — should return empty
      final hours = [
        const HourlyData(time: '2025-01-15T02:00', waveHeight: 1.0, windSpeed: 5),
        const HourlyData(time: '2025-01-15T03:00', waveHeight: 1.0, windSpeed: 5),
      ];
      final result = generateForecastSummary(hours, _prefs, _rockaway);
      expect(result, '');
    });

    test('overhead label for big waves', () {
      final hours = List.generate(
        12,
        (i) => HourlyData(
          time: '2025-01-15T${(6 + i).toString().padLeft(2, '0')}:00',
          waveHeight: 3.0, // ~10 ft = Overhead
          windSpeed: 8,
          windDirection: 0,
        ),
      );
      final result = generateForecastSummary(hours, _prefs, _rockaway);
      expect(result, contains('Overhead'));
    });
  });
}
