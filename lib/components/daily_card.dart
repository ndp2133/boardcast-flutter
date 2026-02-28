import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../models/daily_data.dart';
import '../models/hourly_data.dart';
import '../models/user_prefs.dart';
import '../models/location.dart';
import '../logic/units.dart';
import '../logic/time_utils.dart';
import '../logic/scoring.dart';
import '../logic/moon_phase.dart';

class DailyCard extends StatelessWidget {
  final DailyData day;
  final List<HourlyData> dayHours;
  final UserPrefs? prefs;
  final Location? location;
  final bool isSelected;
  final VoidCallback? onTap;

  const DailyCard({
    super.key,
    required this.day,
    required this.dayHours,
    this.prefs,
    this.location,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColorsDark.bgSecondary : AppColors.bgSecondary;
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final subColor =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;

    // Condition badge
    double? avgScore;
    ConditionLabel? condLabel;
    if (prefs != null && location != null && dayHours.isNotEmpty) {
      var total = 0.0;
      for (final h in dayHours) {
        total += computeMatchScore(h, prefs, location!);
      }
      avgScore = total / dayHours.length;
      condLabel = getConditionLabel(avgScore);
    }

    // Wind context
    final windContext = _getWindContext(dayHours, location);

    // Tide range
    final tideRange = _getTideRange(dayHours);

    // Swell info
    final swellInfo = _getSwellInfo(day);

    // Water temp
    final waterTemps = dayHours
        .where((h) => h.seaSurfaceTemp != null)
        .map((h) => h.seaSurfaceTemp!)
        .toList();
    final avgWaterTemp = waterTemps.isNotEmpty
        ? waterTemps.reduce((a, b) => a + b) / waterTemps.length
        : null;

    // Moon
    final moonEmoji = getMoonPhase(day.date).emoji;

    // Wave energy
    final energy = _getEnergy(day);

    final dayLabel = isToday(day.date) ? 'Today' : formatDayFull(day.date);
    final waveMaxFt = day.waveHeightMax != null
        ? formatWaveHeight(day.waveHeightMax)
        : '--';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        padding: const EdgeInsets.all(AppSpacing.s3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected ? AppColors.accent : Colors.transparent,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? AppShadows.base : AppShadows.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: day label + condition badge + wave max
            Row(
              children: [
                Expanded(
                  child: Text(
                    dayLabel,
                    style: TextStyle(
                      fontSize: AppTypography.textSm,
                      fontWeight: AppTypography.weightSemibold,
                      color: textColor,
                    ),
                  ),
                ),
                if (condLabel != null) ...[
                  _conditionBadge(condLabel, avgScore!),
                  const SizedBox(width: 6),
                ],
                Text(
                  '$waveMaxFt ft',
                  style: TextStyle(
                    fontFamily: AppTypography.fontMono,
                    fontSize: AppTypography.textSm,
                    fontWeight: AppTypography.weightBold,
                    color: textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Detail row
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                // Temp
                if (day.tempMax != null)
                  _chip(
                    '${formatTemp(day.tempMax)}°/${formatTemp(day.tempMin)}°',
                    subColor,
                  ),
                // Water temp
                if (avgWaterTemp != null)
                  _chip('${formatTemp(avgWaterTemp)}° water', subColor),
                // Tide range
                if (tideRange != null) _chip(tideRange, subColor),
                // Swell
                if (swellInfo != null) _chip(swellInfo, subColor),
                // Wind context
                if (windContext != null)
                  _windBadge(windContext.$1, windContext.$2),
                // Energy
                if (energy != null) _chip(energy, subColor),
                // Moon
                _chip(moonEmoji, subColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _conditionBadge(ConditionLabel label, double score) {
    final color = _scoreColor(score);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: AppTypography.weightMedium,
          color: color,
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Text(
      text,
      style: TextStyle(fontSize: AppTypography.textXs, color: color),
    );
  }

  Widget _windBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: AppTypography.textXs,
          fontWeight: AppTypography.weightMedium,
          color: color,
        ),
      ),
    );
  }

  (String, Color)? _getWindContext(
      List<HourlyData> hours, Location? loc) {
    if (loc == null || hours.isEmpty) return null;

    var offshore = 0;
    var onshore = 0;
    var light = 0;
    var total = 0;

    for (final h in hours) {
      if (h.windDirection == null || h.windSpeed == null) continue;
      total++;
      if (h.windSpeed! < 10) {
        light++;
      } else if (isOffshoreWind(h.windDirection!, loc)) {
        offshore++;
      } else if (isOnshoreWind(h.windDirection!, loc)) {
        onshore++;
      }
    }
    if (total == 0) return null;

    if (light > total * 0.6) {
      return ('Light', AppColors.conditionEpic);
    }
    if (offshore > onshore) {
      return ('Offshore', AppColors.conditionEpic);
    }
    if (onshore > offshore) {
      return ('Onshore', AppColors.conditionPoor);
    }
    return ('Cross-shore', AppColors.conditionFair);
  }

  String? _getTideRange(List<HourlyData> hours) {
    final tides = hours
        .where((h) => h.tideHeight != null)
        .map((h) => h.tideHeight!)
        .toList();
    if (tides.isEmpty) return null;
    final mn = tides.reduce((a, b) => a < b ? a : b);
    final mx = tides.reduce((a, b) => a > b ? a : b);
    return "${mn.toStringAsFixed(1)}–${mx.toStringAsFixed(1)}'";
  }

  String? _getSwellInfo(DailyData d) {
    if (d.wavePeriodMax == null) return null;
    final dir = d.waveDirectionDominant != null
        ? degreesToCardinal(d.waveDirectionDominant!)
        : '';
    return '$dir ${d.wavePeriodMax!.round()}s';
  }

  String? _getEnergy(DailyData d) {
    if (d.waveHeightMax == null || d.wavePeriodMax == null) return null;
    final energy = d.waveHeightMax! * d.wavePeriodMax!;
    if (energy >= 15) return 'High Energy';
    if (energy >= 8) return 'Moderate';
    return 'Low Energy';
  }

}

Color _scoreColor(double score) {
  if (score >= 0.8) return AppColors.conditionEpic;
  if (score >= 0.6) return AppColors.conditionGood;
  if (score >= 0.4) return AppColors.conditionFair;
  return AppColors.conditionPoor;
}
