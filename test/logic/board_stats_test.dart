import 'package:flutter_test/flutter_test.dart';
import 'package:boardcast_flutter/logic/board_recommendation.dart';
import 'package:boardcast_flutter/models/board.dart';
import 'package:boardcast_flutter/models/session.dart';

final _now = DateTime.now();

Session _makeSession({
  required String boardId,
  String status = 'completed',
  int? rating,
  double? waveHeight,
}) =>
    Session(
      id: 'sess-${_now.millisecondsSinceEpoch}',
      locationId: 'rockaway',
      date: _now.toIso8601String(),
      status: status,
      boardId: boardId,
      rating: rating,
      conditions: waveHeight != null
          ? SessionConditions(waveHeight: waveHeight)
          : null,
      createdAt: _now,
      updatedAt: _now,
    );

const _board1 = Board(id: 'b1', name: 'Fish', type: 'fish');
const _board2 = Board(id: 'b2', name: 'Shortboard', type: 'shortboard');

void main() {
  group('aggregateBoardStats', () {
    test('returns empty map for no data', () {
      expect(aggregateBoardStats([], []), isEmpty);
    });

    test('returns null stats for board with no sessions', () {
      final stats = aggregateBoardStats([], [_board1]);
      expect(stats['b1'], isNull);
    });

    test('counts completed sessions only', () {
      final sessions = [
        _makeSession(boardId: 'b1', rating: 4),
        _makeSession(boardId: 'b1', status: 'planned'),
        _makeSession(boardId: 'b1', rating: 3),
      ];
      final stats = aggregateBoardStats(sessions, [_board1]);
      expect(stats['b1'], isNotNull);
      expect(stats['b1']!.count, 2);
    });

    test('computes average rating', () {
      final sessions = [
        _makeSession(boardId: 'b1', rating: 4),
        _makeSession(boardId: 'b1', rating: 2),
      ];
      final stats = aggregateBoardStats(sessions, [_board1]);
      expect(stats['b1']!.avgRating, closeTo(3.0, 0.01));
    });

    test('finds best wave range', () {
      final sessions = [
        _makeSession(boardId: 'b1', rating: 5, waveHeight: 0.6), // ~1.97ft → 1-2ft bucket
        _makeSession(boardId: 'b1', rating: 3, waveHeight: 1.2), // ~3.9ft → 3-4ft bucket
        _makeSession(boardId: 'b1', rating: 4, waveHeight: 0.7), // ~2.3ft → 2-3ft bucket
      ];
      final stats = aggregateBoardStats(sessions, [_board1]);
      expect(stats['b1']!.bestRange, '1-2ft'); // highest rated bucket (rating 5)
    });

    test('handles multiple boards independently', () {
      final sessions = [
        _makeSession(boardId: 'b1', rating: 5),
        _makeSession(boardId: 'b2', rating: 3),
      ];
      final stats = aggregateBoardStats(sessions, [_board1, _board2]);
      expect(stats['b1']!.count, 1);
      expect(stats['b2']!.count, 1);
      expect(stats['b1']!.avgRating, 5.0);
      expect(stats['b2']!.avgRating, 3.0);
    });
  });
}
