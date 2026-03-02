import 'package:flutter_test/flutter_test.dart';
import 'package:boardcast_flutter/logic/units.dart';
import 'package:boardcast_flutter/models/hourly_data.dart';

/// Tests for wave energy computation logic used in daily_card.dart.
/// Formula: energy = avgWaveFt² × avgPeriod
/// Thresholds: ≥100 High Energy, ≥30 Moderate, <30 Low Energy

double? _computeEnergy(List<HourlyData> hours) {
  if (hours.isEmpty) return null;
  final waveFts = hours
      .where((h) => h.waveHeight != null)
      .map((h) => metersToFeet(h.waveHeight!))
      .toList();
  final periods = hours
      .where((h) => h.swellPeriod != null || h.wavePeriod != null)
      .map((h) => (h.swellPeriod ?? h.wavePeriod)!)
      .toList();
  if (waveFts.isEmpty || periods.isEmpty) return null;
  final avgWaveFt = waveFts.reduce((a, b) => a + b) / waveFts.length;
  final avgPeriod = periods.reduce((a, b) => a + b) / periods.length;
  if (avgWaveFt <= 0 || avgPeriod <= 0) return null;
  return avgWaveFt * avgWaveFt * avgPeriod;
}

String? _energyLabel(double? energy) {
  if (energy == null) return null;
  if (energy >= 100) return 'High Energy';
  if (energy >= 30) return 'Moderate';
  return 'Low Energy';
}

HourlyData _makeHour({
  String time = '2025-01-15T10:00',
  double? waveHeight,
  double? swellPeriod,
  double? wavePeriod,
}) =>
    HourlyData(
      time: time,
      waveHeight: waveHeight,
      swellPeriod: swellPeriod,
      wavePeriod: wavePeriod,
    );

void main() {
  group('wave energy computation', () {
    test('returns null for empty hours', () {
      expect(_computeEnergy([]), isNull);
    });

    test('returns null when no wave height data', () {
      final hours = [_makeHour(swellPeriod: 12.0)];
      expect(_computeEnergy(hours), isNull);
    });

    test('returns null when no period data', () {
      final hours = [_makeHour(waveHeight: 1.0)];
      expect(_computeEnergy(hours), isNull);
    });

    test('high energy: large waves + long period', () {
      // 2m waves ≈ 6.56ft, 14s period → 6.56² × 14 ≈ 602
      final hours = [
        _makeHour(waveHeight: 2.0, swellPeriod: 14.0),
        _makeHour(waveHeight: 2.0, swellPeriod: 14.0),
      ];
      final energy = _computeEnergy(hours)!;
      expect(energy, greaterThan(100));
      expect(_energyLabel(energy), 'High Energy');
    });

    test('moderate energy: medium waves + medium period', () {
      // 0.6m ≈ 1.97ft, 10s → 1.97² × 10 ≈ 38.8
      final hours = [
        _makeHour(waveHeight: 0.6, swellPeriod: 10.0),
        _makeHour(waveHeight: 0.6, swellPeriod: 10.0),
      ];
      final energy = _computeEnergy(hours)!;
      expect(energy, greaterThanOrEqualTo(30));
      expect(energy, lessThan(100));
      expect(_energyLabel(energy), 'Moderate');
    });

    test('low energy: small waves + short period', () {
      // 0.3m ≈ 0.98ft, 5s → 0.98² × 5 ≈ 4.8
      final hours = [
        _makeHour(waveHeight: 0.3, swellPeriod: 5.0),
        _makeHour(waveHeight: 0.3, swellPeriod: 5.0),
      ];
      final energy = _computeEnergy(hours)!;
      expect(energy, lessThan(30));
      expect(_energyLabel(energy), 'Low Energy');
    });

    test('prefers swellPeriod over wavePeriod', () {
      final hours = [
        _makeHour(waveHeight: 1.0, swellPeriod: 14.0, wavePeriod: 8.0),
      ];
      final energy = _computeEnergy(hours)!;
      // With swellPeriod 14: 3.28² × 14 ≈ 150.6
      // With wavePeriod 8: 3.28² × 8 ≈ 86.1
      expect(energy, greaterThan(100));
    });

    test('falls back to wavePeriod when no swellPeriod', () {
      final hours = [
        _makeHour(waveHeight: 1.0, wavePeriod: 8.0),
      ];
      final energy = _computeEnergy(hours)!;
      // 3.28² × 8 ≈ 86.1
      expect(energy, greaterThan(30));
      expect(energy, lessThan(100));
    });

    test('averages across multiple hours', () {
      final hours = [
        _makeHour(waveHeight: 1.0, swellPeriod: 10.0), // 3.28ft
        _makeHour(waveHeight: 2.0, swellPeriod: 14.0), // 6.56ft
      ];
      final energy = _computeEnergy(hours)!;
      // avgFt = (3.28 + 6.56) / 2 = 4.92, avgPeriod = 12
      // 4.92² × 12 ≈ 290
      expect(energy, greaterThan(100));
    });
  });

  group('energy label thresholds', () {
    test('null energy returns null label', () {
      expect(_energyLabel(null), isNull);
    });

    test('boundary: exactly 100 is High Energy', () {
      expect(_energyLabel(100.0), 'High Energy');
    });

    test('boundary: exactly 30 is Moderate', () {
      expect(_energyLabel(30.0), 'Moderate');
    });

    test('boundary: 29.9 is Low Energy', () {
      expect(_energyLabel(29.9), 'Low Energy');
    });
  });
}
