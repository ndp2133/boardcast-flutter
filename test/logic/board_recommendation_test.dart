import 'package:flutter_test/flutter_test.dart';
import 'package:boardcast_flutter/logic/board_recommendation.dart';
import 'package:boardcast_flutter/models/board.dart';

void main() {
  group('getBoardType', () {
    test('finds shortboard', () {
      expect(getBoardType('shortboard')?.name, 'Shortboard');
    });

    test('finds longboard', () {
      expect(getBoardType('longboard')?.name, 'Longboard');
    });

    test('returns null for unknown type', () {
      expect(getBoardType('unknown'), isNull);
    });
  });

  group('boardTypes', () {
    test('has 6 board types', () {
      expect(boardTypes.length, 6);
    });

    test('all have valid ideal ranges', () {
      for (final type in boardTypes) {
        expect(type.idealWave.$1, lessThanOrEqualTo(type.idealWave.$2));
        expect(type.idealWind.$1, lessThanOrEqualTo(type.idealWind.$2));
        expect(type.idealPeriod.$1, lessThanOrEqualTo(type.idealPeriod.$2));
      }
    });
  });

  group('recommendBoard', () {
    final quiver = [
      const Board(id: '1', name: 'My Shortboard', type: 'shortboard'),
      const Board(id: '2', name: 'My Fish', type: 'fish'),
      const Board(id: '3', name: 'My Longboard', type: 'longboard'),
    ];

    test('returns null for empty quiver', () {
      expect(recommendBoard([], const BoardConditions()), isNull);
    });

    test('recommends longboard for small waves', () {
      final result = recommendBoard(
        quiver,
        const BoardConditions(waveHeight: 0.3, windSpeed: 5),
      );
      expect(result, isNotNull);
      expect(result!.board.type, anyOf('longboard', 'fish'));
    });

    test('recommends shortboard for overhead waves', () {
      final result = recommendBoard(
        quiver,
        const BoardConditions(waveHeight: 2.5, windSpeed: 8, wavePeriod: 12),
      );
      expect(result, isNotNull);
      expect(result!.board.type, 'shortboard');
    });

    test('always returns a recommendation with valid quiver', () {
      final result = recommendBoard(
        quiver,
        const BoardConditions(waveHeight: 1.0, windSpeed: 10),
      );
      expect(result, isNotNull);
      expect(result!.score, greaterThan(0));
      expect(result.reason, isNotEmpty);
    });

    test('skips boards with unknown type', () {
      final mixed = [
        const Board(id: '1', name: 'Unknown', type: 'paddleboard'),
        const Board(id: '2', name: 'My Fish', type: 'fish'),
      ];
      final result = recommendBoard(
        mixed,
        const BoardConditions(waveHeight: 0.5),
      );
      expect(result, isNotNull);
      expect(result!.board.type, 'fish');
    });
  });
}
