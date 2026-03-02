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

    // Condition badge — use best-hour score instead of average
    double? bestScore;
    ConditionLabel? condLabel;
    if (prefs != null && location != null && dayHours.isNotEmpty) {
      final bestHour = findBestHours(dayHours, prefs!, location!, day.date);
      if (bestHour != null) {
        bestScore = bestHour.matchScore;
        condLabel = getConditionLabel(bestScore);
      }
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

    // Wave energy (ft² × period)
    final energy = _getEnergyFromHours(dayHours);

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
                  _conditionBadge(condLabel, bestScore!),
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
                if (energy != null)
                  _windBadge(energy.$1, energy.$2),
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

  (String, Color)? _getEnergyFromHours(List<HourlyData> hours) {
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
    final energy = avgWaveFt * avgWaveFt * avgPeriod;
    if (energy >= 100) return ('High Energy', AppColors.conditionEpic);
    if (energy >= 30) return ('Moderate', AppColors.conditionFair);
    return ('Low Energy', AppColors.conditionPoor);
  }

}

Color _scoreColor(double score) {
  if (score >= 0.8) return AppColors.conditionEpic;
  if (score >= 0.6) return AppColors.conditionGood;
  if (score >= 0.4) return AppColors.conditionFair;
  return AppColors.conditionPoor;
}
