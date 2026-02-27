import 'package:flutter_test/flutter_test.dart';
import 'package:boardcast_flutter/models/models.dart';
import 'package:boardcast_flutter/services/api_service.dart';

// Minimal mock JSON matching Open-Meteo Marine API response shape
final _marineJson = <String, dynamic>{
  'current': {
    'wave_height': 1.2,
    'wave_period': 8.5,
    'wave_direction': 190.0,
    'swell_wave_height': 1.0,
    'swell_wave_period': 10.0,
    'swell_wave_direction': 180.0,
    'sea_surface_temperature': 15.5,
  },
  'hourly': {
    'time': ['2025-01-15T06:00', '2025-01-15T07:00', '2025-01-15T08:00'],
    'wave_height': [1.0, 1.2, 1.1],
    'wave_direction': [185.0, 190.0, 188.0],
    'wave_period': [8.0, 8.5, 8.2],
    'swell_wave_height': [0.9, 1.0, 0.95],
    'swell_wave_period': [10.0, 10.0, 10.0],
    'swell_wave_direction': [180.0, 180.0, 180.0],
    'sea_surface_temperature': [15.5, 15.5, 15.5],
  },
  'daily': {
    'time': ['2025-01-15', '2025-01-16'],
    'wave_height_max': [1.5, null],
    'wave_period_max': [10.0, null],
    'wave_direction_dominant': [185.0, null],
  },
};

final _weatherJson = <String, dynamic>{
  'current': {
    'temperature_2m': 12.0,
    'apparent_temperature': 10.5,
    'wind_speed_10m': 15.0,
    'wind_direction_10m': 220.0,
    'wind_gusts_10m': 25.0,
    'weather_code': 3,
  },
  'hourly': {
    'time': ['2025-01-15T06:00', '2025-01-15T07:00', '2025-01-15T08:00'],
    'temperature_2m': [11.0, 11.5, 12.0],
    'wind_speed_10m': [14.0, 15.0, 13.0],
    'wind_direction_10m': [220.0, 225.0, 215.0],
    'wind_gusts_10m': [22.0, 25.0, 20.0],
    'weather_code': [3, 3, 2],
  },
  'daily': {
    'time': ['2025-01-15', '2025-01-16'],
    'temperature_2m_max': [14.0, 13.0],
    'temperature_2m_min': [8.0, 7.0],
    'sunrise': ['2025-01-15T07:15', '2025-01-16T07:14'],
    'sunset': ['2025-01-15T16:50', '2025-01-16T16:51'],
  },
};

final _tideJson = <String, dynamic>{
  'predictions': [
    {'t': '2025-01-15 06:00', 'v': '2.5'},
    {'t': '2025-01-15 07:00', 'v': '2.8'},
    {'t': '2025-01-15 08:00', 'v': '3.1'},
  ],
};

void main() {
  group('normalizeMarineData', () {
    test('extracts current conditions', () {
      final result = normalizeMarineData(_marineJson);
      expect(result.current['waveHeight'], 1.2);
      expect(result.current['wavePeriod'], 8.5);
      expect(result.current['swellDirection'], 180.0);
      expect(result.current['waterTemp'], 15.5);
    });

    test('extracts hourly data', () {
      final result = normalizeMarineData(_marineJson);
      expect(result.hourly.length, 3);
      expect(result.hourly[0].time, '2025-01-15T06:00');
      expect(result.hourly[0].waveHeight, 1.0);
      expect(result.hourly[1].swellPeriod, 10.0);
    });

    test('extracts daily data', () {
      final result = normalizeMarineData(_marineJson);
      expect(result.daily.length, 2);
      expect(result.daily[0].waveHeightMax, 1.5);
      expect(result.daily[1].waveHeightMax, isNull);
    });

    test('handles empty data gracefully', () {
      final result = normalizeMarineData(<String, dynamic>{});
      expect(result.hourly, isEmpty);
      expect(result.daily, isEmpty);
    });
  });

  group('normalizeWeatherData', () {
    test('extracts current conditions', () {
      final result = normalizeWeatherData(_weatherJson);
      expect(result.current['temperature'], 12.0);
      expect(result.current['windSpeed'], 15.0);
      expect(result.current['weatherCode'], 3);
    });

    test('extracts hourly data', () {
      final result = normalizeWeatherData(_weatherJson);
      expect(result.hourly.length, 3);
      expect(result.hourly[0]['temperature'], 11.0);
      expect(result.hourly[2]['windGusts'], 20.0);
    });

    test('extracts daily data with sunrise/sunset', () {
      final result = normalizeWeatherData(_weatherJson);
      expect(result.daily.length, 2);
      expect(result.daily[0]['tempMax'], 14.0);
      expect(result.daily[0]['sunrise'], '2025-01-15T07:15');
    });
  });

  group('normalizeTideData', () {
    test('returns null for null input', () {
      expect(normalizeTideData(null), isNull);
    });

    test('returns null for missing predictions', () {
      expect(normalizeTideData(<String, dynamic>{}), isNull);
    });

    test('parses predictions and converts time format', () {
      final result = normalizeTideData(_tideJson);
      expect(result, isNotNull);
      expect(result!.hourly.length, 3);
      // "2025-01-15 06:00" → "2025-01-15T06:00"
      expect(result.hourly[0].time, '2025-01-15T06:00');
      expect(result.hourly[0].height, 2.5);
    });

    test('detects rising tide', () {
      final result = normalizeTideData(_tideJson);
      expect(result, isNotNull);
      // All heights are increasing, so trend should be Rising
      expect(result!.tideTrend, 'Rising');
    });
  });

  group('mergeConditions', () {
    test('merges marine + weather + tide into MergedConditions', () {
      final result = mergeConditions(_marineJson, _weatherJson, _tideJson);

      // Current should have both marine and weather fields
      expect(result.current.waveHeight, 1.2);
      expect(result.current.temperature, 12.0);
      expect(result.current.windSpeed, 15.0);
      expect(result.current.tideTrend, isNotNull);
    });

    test('hourly data is merged by time key', () {
      final result = mergeConditions(_marineJson, _weatherJson, _tideJson);
      expect(result.hourly.length, 3);

      final h0 = result.hourly[0];
      // Marine fields
      expect(h0.waveHeight, 1.0);
      expect(h0.swellPeriod, 10.0);
      // Weather fields
      expect(h0.temperature, 11.0);
      expect(h0.windSpeed, 14.0);
      // Tide field
      expect(h0.tideHeight, 2.5);
    });

    test('daily data filters out null waveHeightMax', () {
      final result = mergeConditions(_marineJson, _weatherJson, _tideJson);
      // Second day has null waveHeightMax, should be filtered
      expect(result.daily.length, 1);
      expect(result.daily[0].date, '2025-01-15');
      expect(result.daily[0].tempMax, 14.0);
      expect(result.daily[0].sunrise, '2025-01-15T07:15');
    });

    test('works without tide data', () {
      final result = mergeConditions(_marineJson, _weatherJson, null);
      expect(result.current.tideHeight, isNull);
      expect(result.current.tideTrend, isNull);
      expect(result.hourly[0].tideHeight, isNull);
    });

    test('isStale defaults to false for fresh data', () {
      final result = mergeConditions(_marineJson, _weatherJson, _tideJson);
      expect(result.isStale, false);
    });

    test('fetchedAt is set', () {
      final before = DateTime.now();
      final result = mergeConditions(_marineJson, _weatherJson, _tideJson);
      final after = DateTime.now();
      expect(result.fetchedAt.isAfter(before.subtract(const Duration(seconds: 1))), true);
      expect(result.fetchedAt.isBefore(after.add(const Duration(seconds: 1))), true);
    });
  });

  group('MergedConditions serialization round-trip', () {
    test('toJson/fromJson preserves data', () {
      final original = mergeConditions(_marineJson, _weatherJson, _tideJson);
      final json = original.toJson();
      final restored = MergedConditions.fromJson(json);

      expect(restored.hourly.length, original.hourly.length);
      expect(restored.daily.length, original.daily.length);
      expect(restored.current.waveHeight, original.current.waveHeight);
      expect(restored.current.temperature, original.current.temperature);
      expect(restored.isStale, original.isStale);
    });
  });
}
