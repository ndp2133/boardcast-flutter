/// Board types and recommendation — direct port of utils/boards.js
import 'dart:math';
import '../models/board.dart';
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

String _generateReason(BoardType type, double waveHeightFt) {
  final name = type.name.toLowerCase();
  if (waveHeightFt < 1) return 'Great for small surf on a $name';
  if (waveHeightFt <= 3) return 'Perfect conditions for your $name';
  if (waveHeightFt <= 5) return 'Good wave size for a $name';
  return 'Solid swell \u2014 $name will perform';
}
