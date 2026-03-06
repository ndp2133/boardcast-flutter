/// Pure function: infers UserPrefs from imported session conditions.
import 'dart:math';
import '../models/session.dart';
import '../models/user_prefs.dart';

class InferredPrefs {
  final UserPrefs prefs;
  final double confidence; // 0-1 based on session count
  final String inferredSkill;

  const InferredPrefs({
    required this.prefs,
    required this.confidence,
    required this.inferredSkill,
  });
}

/// Infer preferences from imported sessions with conditions.
///
/// With 5+ sessions with conditions: full inference (wave range, wind, skill).
/// With 2-4 sessions: infer skill level only from wave heights, use skill defaults for rest.
/// With 0-1 sessions: return null (fall back to skill defaults).
InferredPrefs? inferPrefsFromSessions(List<Session> sessions) {
  // Filter to sessions with conditions
  final withConditions =
      sessions.where((s) => s.conditions != null).toList();
  if (withConditions.length < 2) return null;

  // Collect wave heights from sessions
  final waveHeights = withConditions
      .map((s) => s.conditions!.waveHeight)
      .whereType<double>()
      .toList()
    ..sort();

  if (waveHeights.isEmpty) return null;

  // Infer skill level from max wave height
  final maxWave = waveHeights.last;
  final inferredSkill = maxWave > 2.5
      ? 'advanced'
      : maxWave > 1.2
          ? 'intermediate'
          : 'beginner';

  // With only 2-4 sessions, return skill-only inference
  if (withConditions.length < 5) {
    return InferredPrefs(
      prefs: UserPrefs(skillLevel: inferredSkill),
      confidence: withConditions.length / 10,
      inferredSkill: inferredSkill,
    );
  }

  // Full inference with 5+ sessions

  // Wave range: P10-P90 of actual wave heights surfed
  final p10Index = (waveHeights.length * 0.1).floor();
  final p90Index = min((waveHeights.length * 0.9).floor(), waveHeights.length - 1);
  final minWave = waveHeights[p10Index];
  final maxWaveInferred = waveHeights[p90Index];

  // Wind tolerance: P90 of actual wind speeds
  final windSpeeds = withConditions
      .map((s) => s.conditions!.windSpeed)
      .whereType<double>()
      .toList()
    ..sort();
  final maxWind = windSpeeds.isNotEmpty
      ? windSpeeds[min((windSpeeds.length * 0.9).floor(), windSpeeds.length - 1)]
      : 25.0;

  // Confidence scales with session count (5 sessions = 0.5, 20+ = 1.0)
  final confidence = min(1.0, withConditions.length / 20);

  return InferredPrefs(
    prefs: UserPrefs(
      skillLevel: inferredSkill,
      minWaveHeight: minWave,
      maxWaveHeight: maxWaveInferred,
      maxWindSpeed: maxWind,
      preferredTide: 'any', // HealthKit doesn't capture this
    ),
    confidence: confidence,
    inferredSkill: inferredSkill,
  );
}
