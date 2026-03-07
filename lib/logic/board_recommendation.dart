/// Board types, recommendation, and performance stats — port of utils/boards.js
import 'dart:math';
import '../models/board.dart';
import '../models/session.dart';
import 'units.dart';

class BoardType {
  final String id;
  final String name;
  final String description;
  final String bestFor;
  final (double, double) idealWave; // ft
  final (double, double) idealWind; // mph
  final (double, double) idealPeriod; // seconds

  const BoardType({
    required this.id,
    required this.name,
    required this.description,
    required this.bestFor,
    required this.idealWave,
    required this.idealWind,
    required this.idealPeriod,
  });
}

const boardTypes = <BoardType>[
  BoardType(
    id: 'shortboard',
    name: 'Shortboard',
    description: '5\'6"-6\'6", performance-oriented, thin rails',
    bestFor: 'Overhead+ waves, clean conditions',
    idealWave: (4, 15),
    idealWind: (0, 15),
    idealPeriod: (8, 25),
  ),
  BoardType(
    id: 'fish',
    name: 'Fish',
    description: '5\'4"-6\'2", wide/flat, twin or quad fin',
    bestFor: 'Small-medium waves, mushy conditions',
    idealWave: (1, 4),
    idealWind: (0, 40),
    idealPeriod: (5, 25),
  ),
  BoardType(
    id: 'hybrid',
    name: 'Hybrid / Egg',
    description: '6\'0"-7\'0", blend of short + fish',
    bestFor: 'Medium waves, variable conditions',
    idealWave: (2, 5),
    idealWind: (0, 40),
    idealPeriod: (0, 25),
  ),
  BoardType(
    id: 'funboard',
    name: 'Funboard',
    description: '7\'0"-8\'0", stable, versatile mid-length',
    bestFor: 'Small-medium waves, any wind',
    idealWave: (1, 4),
    idealWind: (0, 40),
    idealPeriod: (0, 25),
  ),
  BoardType(
    id: 'longboard',
    name: 'Longboard',
    description: '8\'0"-10\'0", classic noseriding shape',
    bestFor: 'Small waves, clean/glassy',
    idealWave: (0.5, 3),
    idealWind: (0, 20),
    idealPeriod: (5, 25),
  ),
  BoardType(
    id: 'softTop',
    name: 'Soft-top / Foamie',
    description: '6\'0"-9\'0", foam construction, beginner-friendly',
    bestFor: 'Tiny waves, any conditions',
    idealWave: (0.5, 2),
    idealWind: (0, 40),
    idealPeriod: (0, 25),
  ),
];

BoardType? getBoardType(String typeId) {
  try {
    return boardTypes.firstWhere((t) => t.id == typeId);
  } catch (_) {
    return null;
  }
}

/// Score how well a value fits within an ideal range. Returns 0-1.
double _rangeScore(double value, double min, double max) {
  if (value >= min && value <= max) return 1;
  if (value < min) {
    final dist = min - value;
    return (1 - dist / (min > 0 ? min : 1)).clamp(0.0, 1.0);
  }
  // value > max
  final dist = value - max;
  return (1 - dist / (max > 0 ? max : 1)).clamp(0.0, 1.0);
}

class BoardRecommendation {
  final Board board;
  final double score;
  final String reason;

  const BoardRecommendation({
    required this.board,
    required this.score,
    required this.reason,
  });
}

/// Conditions for board recommendation (raw metric units from API)
class BoardConditions {
  final double? waveHeight; // meters
  final double? windSpeed; // km/h
  final double? wavePeriod; // seconds
  final double? swellPeriod; // seconds

  const BoardConditions({
    this.waveHeight,
    this.windSpeed,
    this.wavePeriod,
    this.swellPeriod,
  });
}

/// Recommend the best board from a quiver given current conditions.
BoardRecommendation? recommendBoard(
    List<Board> boards, BoardConditions conditions) {
  if (boards.isEmpty) return null;

  final waveHeightFt =
      conditions.waveHeight != null ? metersToFeet(conditions.waveHeight!) : 0.0;
  final windSpeedMph =
      conditions.windSpeed != null ? kmhToMph(conditions.windSpeed!) : 0.0;
  final wavePeriod = conditions.wavePeriod ?? conditions.swellPeriod ?? 0.0;

  Board? bestBoard;
  double bestScore = -1;
  BoardType? bestType;

  for (final board in boards) {
    final type = getBoardType(board.type);
    if (type == null) continue;

    final waveScore =
        _rangeScore(waveHeightFt, type.idealWave.$1, type.idealWave.$2);
    final windScore =
        _rangeScore(windSpeedMph, type.idealWind.$1, type.idealWind.$2);
    final periodScore =
        _rangeScore(wavePeriod, type.idealPeriod.$1, type.idealPeriod.$2);

    final score = waveScore * 0.5 + windScore * 0.3 + periodScore * 0.2;

    if (score > bestScore) {
      bestBoard = board;
      bestScore = score;
      bestType = type;
    }
  }

  if (bestBoard == null || bestType == null) return null;

  final reason = _generateReason(bestType, waveHeightFt);
  return BoardRecommendation(board: bestBoard, score: bestScore, reason: reason);
}

/// Generate comparative board insights from session data.
/// Returns list of insight strings when 2+ boards have rated sessions.
List<String> generateBoardInsights(List<Session> sessions, List<Board> boards) {
  final insights = <String>[];
  if (sessions.isEmpty || boards.length < 2) return insights;

  final completed = sessions
      .where((s) => s.status == 'completed' && s.boardId != null && s.rating != null)
      .toList();
  if (completed.length < 3) return insights;

  // Per-board data
  final boardData = <String, ({
    Board board,
    String name,
    int count,
    double avgRating,
    Map<String, List<int>> bySize,
  })>{};

  for (final board in boards) {
    final sess = completed.where((s) => s.boardId == board.id).toList();
    if (sess.isEmpty) continue;
    final avgRating = sess.fold<double>(0, (sum, s) => sum + s.rating!) / sess.length;

    final bySize = <String, List<int>>{'small': [], 'medium': [], 'large': []};
    for (final s in sess) {
      final wh = s.conditions?.waveHeight;
      if (wh == null) continue;
      final ft = metersToFeet(wh);
      if (ft < 2) {
        bySize['small']!.add(s.rating!);
      } else if (ft < 4) {
        bySize['medium']!.add(s.rating!);
      } else {
        bySize['large']!.add(s.rating!);
      }
    }

    final name = board.name.isNotEmpty
        ? board.name
        : (getBoardType(board.type)?.name ?? board.type);

    boardData[board.id] = (
      board: board,
      name: name,
      count: sess.length,
      avgRating: avgRating,
      bySize: bySize,
    );
  }

  final entries = boardData.values.toList()
    ..sort((a, b) => b.avgRating.compareTo(a.avgRating));
  if (entries.length < 2) return insights;

  // Insight 1: Overall comparison
  final top = entries[0];
  final runner = entries[1];
  final diff = top.avgRating - runner.avgRating;
  if (diff >= 0.3 && top.count >= 2 && runner.count >= 2) {
    insights.add(
        'Your ${top.name} averages ${top.avgRating.toStringAsFixed(1)}\u2605 vs your ${runner.name} at ${runner.avgRating.toStringAsFixed(1)}\u2605');
  }

  // Insight 2: Board that excels in specific wave size
  for (final entry in entries) {
    for (final MapEntry(key: label, value: ratings) in entry.bySize.entries) {
      if (ratings.length < 2) continue;
      final avg = ratings.fold<double>(0, (s, r) => s + r) / ratings.length;
      if (avg >= 4.0) {
        final sizeLabel =
            label == 'small' ? 'under 2ft' : label == 'medium' ? '2-4ft' : '4ft+';
        insights.add(
            'Your ${entry.name} shines in $sizeLabel surf (${avg.toStringAsFixed(1)}\u2605 avg)');
        break;
      }
    }
    if (insights.length >= 3) break;
  }

  return insights.take(3).toList();
}

String _generateReason(BoardType type, double waveHeightFt) {
  final name = type.name.toLowerCase();
  if (waveHeightFt < 1) return 'Great for small surf on a $name';
  if (waveHeightFt <= 3) return 'Perfect conditions for your $name';
  if (waveHeightFt <= 5) return 'Good wave size for a $name';
  return 'Solid swell \u2014 $name will perform';
}

/// Per-board performance stats aggregated from completed sessions
class BoardStats {
  final int count;
  final double? avgRating;
  final String? bestRange;

  const BoardStats({required this.count, this.avgRating, this.bestRange});
}

/// Aggregate per-board performance stats from completed sessions.
/// Returns Map<boardId, BoardStats?> — null means no sessions for that board.
Map<String, BoardStats?> aggregateBoardStats(
    List<Session> sessions, List<Board> boards) {
  final stats = <String, BoardStats?>{};
  if (sessions.isEmpty || boards.isEmpty) return stats;

  final completed =
      sessions.where((s) => s.status == 'completed' && s.boardId != null);

  for (final board in boards) {
    final boardSessions =
        completed.where((s) => s.boardId == board.id).toList();
    if (boardSessions.isEmpty) {
      stats[board.id] = null;
      continue;
    }

    final count = boardSessions.length;
    final rated = boardSessions.where((s) => s.rating != null).toList();
    final avgRating = rated.isNotEmpty
        ? rated.fold<double>(0, (sum, s) => sum + s.rating!) / rated.length
        : null;

    // Wave height bucketing: 1ft increments, find range with highest avg rating
    String? bestRange;
    if (rated.isNotEmpty) {
      final buckets = <String, (double total, int count)>{};
      for (final s in rated) {
        final wh = s.conditions?.waveHeight;
        if (wh == null) continue;
        final ft = metersToFeet(wh).floor();
        final key = '$ft-${ft + 1}ft';
        final prev = buckets[key] ?? (0.0, 0);
        buckets[key] = (prev.$1 + s.rating!, prev.$2 + 1);
      }
      var bestAvg = 0.0;
      for (final entry in buckets.entries) {
        final avg = entry.value.$1 / entry.value.$2;
        if (avg > bestAvg) {
          bestAvg = avg;
          bestRange = entry.key;
        }
      }
    }

    stats[board.id] = BoardStats(
        count: count, avgRating: avgRating, bestRange: bestRange);
  }

  return stats;
}
