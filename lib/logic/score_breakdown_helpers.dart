/// Score breakdown helpers — translate raw component scores into user-facing factor summaries
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import 'scoring.dart';
import 'units.dart' show metersToFeet;

/// Factor status: how a condition factor affects the overall score
enum FactorStatus { helping, neutral, hurting }

/// User-facing summary of a single scoring factor
class FactorSummary {
  final String name;
  final FactorStatus status;
  final double score;
  final double impact;
  final String explanation;
  final String value;
  final String? idealRange;
  final double barPosition;

  const FactorSummary({
    required this.name,
    required this.status,
    required this.score,
    required this.impact,
    required this.explanation,
    required this.value,
    this.idealRange,
    required this.barPosition,
  });
}

/// Build factor summaries from a score breakdown.
/// Returns 4 factors: Waves, Swell, Wind, Tide — sorted by impact.
List<FactorSummary> buildFactorSummaries(ScoreBreakdown breakdown) {
  final factors = <FactorSummary>[
    _buildWavesFactor(breakdown),
    _buildSwellFactor(breakdown),
    _buildWindFactor(breakdown),
    _buildTideFactor(breakdown),
  ];
  return sortByImpact(factors);
}

/// Sort factors: biggest positive impact first, biggest negative last
List<FactorSummary> sortByImpact(List<FactorSummary> factors) {
  final sorted = List<FactorSummary>.from(factors);
  sorted.sort((a, b) => b.impact.compareTo(a.impact));
  return sorted;
}

/// Human-readable explanation for a hard cap
String hardCapExplanation(HardCap cap) {
  switch (cap) {
    case HardCap.lowEnergy:
      return 'Not enough energy for rideable waves — try a more exposed break';
    case HardCap.powerCap:
      return 'Waves exceed safe power levels — wait for conditions to ease';
    case HardCap.oversizedBeginner:
      return 'Too large for beginners — try when waves drop below 4ft';
    case HardCap.oversizedGeneral:
      return 'Dangerously large waves — experienced surfers only';
    case HardCap.thunderstorm:
      return 'Lightning risk — stay out of the water';
    case HardCap.strongOnshore:
      return 'Strong onshore destroying shape — check again when wind shifts';
    case HardCap.wrongTide:
      return 'Tide is wrong for this break — check the tide chart for better windows';
  }
}

/// Short summary of the highest-priority active cap (for inline display)
String hardCapSummary(List<HardCap> caps) {
  if (caps.isEmpty) return '';
  // Priority order: safety first
  if (caps.contains(HardCap.thunderstorm)) return 'Score capped — lightning risk';
  if (caps.contains(HardCap.oversizedBeginner)) return 'Score capped — too powerful';
  if (caps.contains(HardCap.powerCap)) return 'Score capped — too powerful';
  if (caps.contains(HardCap.oversizedGeneral)) return 'Score capped — oversized';
  if (caps.contains(HardCap.strongOnshore)) return 'Score capped — strong onshore';
  if (caps.contains(HardCap.wrongTide)) return 'Score capped — wrong tide';
  if (caps.contains(HardCap.lowEnergy)) return 'Score capped — low energy';
  return 'Score capped';
}

/// Map factor status to condition color
Color statusColor(FactorStatus status, bool isDark) {
  switch (status) {
    case FactorStatus.helping:
      return AppColors.conditionEpic;
    case FactorStatus.neutral:
      return AppColors.conditionFair;
    case FactorStatus.hurting:
      return AppColors.conditionPoor;
  }
}

// --- Factor builders ---

FactorSummary _buildWavesFactor(ScoreBreakdown breakdown) {
  final hs = breakdown.heightScore;
  final status = hs > 0.7
      ? FactorStatus.helping
      : hs < 0.4
          ? FactorStatus.hurting
          : FactorStatus.neutral;

  final wh = breakdown.actualWaveHeight;
  final whFt = wh != null ? metersToFeet(wh) : null;
  final value = whFt != null ? '${whFt.toStringAsFixed(1)} ft' : '--';

  String? idealRange;
  if (breakdown.idealMin != null && breakdown.idealMax != null) {
    final minFt = metersToFeet(breakdown.idealMin!);
    final maxFt = metersToFeet(breakdown.idealMax!);
    idealRange = '${minFt.toStringAsFixed(1)}–${maxFt.toStringAsFixed(1)} ft';
  }

  String explanation;
  if (wh == null) {
    explanation = 'No wave data available';
  } else if (breakdown.idealMin != null && breakdown.idealMax != null) {
    final valStr = whFt != null ? '${whFt.toStringAsFixed(1)}ft' : '';
    if (wh >= breakdown.idealMin! && wh <= breakdown.idealMax!) {
      explanation = idealRange != null
          ? '$valStr — right in your $idealRange sweet spot'
          : '$valStr — right in your preferred range';
    } else if (wh < breakdown.idealMin!) {
      explanation = '$valStr — smaller than your preferred range';
    } else {
      explanation = '$valStr — larger than your preferred range';
    }
  } else {
    explanation = 'Wave height match';
  }

  // barPosition: where current wave height falls in the ideal range (0-1)
  double barPosition = 0.5;
  if (wh != null && breakdown.idealMin != null && breakdown.idealMax != null) {
    final range = breakdown.idealMax! - breakdown.idealMin!;
    if (range > 0) {
      barPosition = ((wh - breakdown.idealMin!) / range).clamp(0.0, 1.0);
    }
  }

  return FactorSummary(
    name: 'Waves',
    status: status,
    score: hs,
    impact: hs - 0.5, // relative to neutral midpoint
    explanation: explanation,
    value: value,
    idealRange: idealRange,
    barPosition: barPosition,
  );
}

FactorSummary _buildSwellFactor(ScoreBreakdown breakdown) {
  // Combined: 60% quality + 40% direction (matching the weight ratio)
  final combined = 0.6 * breakdown.qualityScore + 0.4 * breakdown.dirScore;
  final status = combined > 0.7
      ? FactorStatus.helping
      : combined < 0.4
          ? FactorStatus.hurting
          : FactorStatus.neutral;

  final period = breakdown.swellPeriod;
  final value = period != null ? '${period.round()}s period' : '--';

  String explanation;
  if (period == null) {
    explanation = 'No swell data available';
  } else if (period >= 12) {
    explanation = '${period.round()}s groundswell — powerful, well-shaped waves';
  } else if (period >= 10) {
    explanation = '${period.round()}s swell — decent wave shape';
  } else if (period >= 8) {
    explanation = '${period.round()}s swell — less wave power';
  } else {
    explanation = '${period.round()}s windswell — choppy, disorganized waves';
  }

  return FactorSummary(
    name: 'Swell',
    status: status,
    score: combined,
    impact: combined - 0.5,
    explanation: explanation,
    value: value,
    barPosition: combined.clamp(0.0, 1.0),
  );
}

FactorSummary _buildWindFactor(ScoreBreakdown breakdown) {
  final wm = breakdown.windMult;
  final status = wm > 0.85
      ? FactorStatus.helping
      : wm < 0.6
          ? FactorStatus.hurting
          : FactorStatus.neutral;

  final ws = breakdown.windSpeed;
  final wsFt = ws != null ? (ws * 0.621371).round() : null; // km/h to mph
  final dirLabel = breakdown.isOffshore
      ? 'offshore'
      : breakdown.isOnshore
          ? 'onshore'
          : 'cross-shore';
  final value = wsFt != null ? '$wsFt mph $dirLabel' : '--';

  String explanation;
  if (ws == null) {
    explanation = 'No wind data available';
  } else if (ws < 8 && breakdown.isOffshore) {
    explanation = '${wsFt}mph offshore — glass conditions';
  } else if (breakdown.isOffshore) {
    explanation = '${wsFt}mph offshore — grooming the waves';
  } else if (ws < 10) {
    explanation = '${wsFt}mph — minimal impact on waves';
  } else if (breakdown.isOnshore) {
    explanation = '${wsFt}mph onshore — degrading wave quality';
  } else {
    explanation = '${wsFt}mph cross-shore — mixed effect on waves';
  }

  return FactorSummary(
    name: 'Wind',
    status: status,
    score: wm,
    impact: wm - 0.7, // wind mult baseline is ~0.7 (moderate impact)
    explanation: explanation,
    value: value,
    barPosition: wm.clamp(0.0, 1.0),
  );
}

FactorSummary _buildTideFactor(ScoreBreakdown breakdown) {
  final tm = breakdown.tideMod;
  final status = tm > 0.02
      ? FactorStatus.helping
      : tm < -0.05
          ? FactorStatus.hurting
          : FactorStatus.neutral;

  final tn = breakdown.tideNormalized;
  String tidePhase;
  if (tn == null) {
    tidePhase = '--';
  } else if (tn < 0.33) {
    tidePhase = 'Low tide';
  } else if (tn < 0.66) {
    tidePhase = 'Mid tide';
  } else {
    tidePhase = 'High tide';
  }

  String explanation;
  if (tn == null) {
    explanation = 'No tide data available';
  } else {
    final breakType = breakdown.breakType;
    if (breakType == 'reef' && tn > 0.8) {
      explanation = '$tidePhase — too high for this reef break';
    } else if (breakType == 'reef' && tn < 0.15) {
      explanation = '$tidePhase — shallow reef exposure';
    } else if (tm > 0.02) {
      explanation = '$tidePhase — working well for this break';
    } else if (tm < -0.05) {
      explanation = '$tidePhase — not ideal for this break type';
    } else {
      explanation = '$tidePhase — minimal effect right now';
    }
  }

  return FactorSummary(
    name: 'Tide',
    status: status,
    score: (tm + 0.15) / 0.23, // normalize -0.15..+0.08 to 0..1
    impact: tm, // tide mod is already a signed contribution
    explanation: explanation,
    value: tidePhase,
    barPosition: tn?.clamp(0.0, 1.0) ?? 0.5,
  );
}
