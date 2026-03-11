import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/tokens.dart';
import '../models/daily_data.dart';
import '../models/hourly_data.dart';
import '../models/user_prefs.dart';
import '../models/location.dart';
import '../logic/units.dart';
import '../logic/time_utils.dart';
import '../logic/scoring.dart';
import '../logic/moon_phase.dart';

class DailyCard extends StatefulWidget {
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
  State<DailyCard> createState() => _DailyCardState();
}

class _DailyCardState extends State<DailyCard> {
  bool _expanded = false;

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
    if (widget.prefs != null && widget.location != null && widget.dayHours.isNotEmpty) {
      final bestHour = findBestHours(widget.dayHours, widget.prefs!, widget.location!, widget.day.date);
      if (bestHour != null) {
        bestScore = bestHour.matchScore;
        condLabel = getConditionLabel(bestScore);
      }
    }

    // Wind context
    final windContext = _getWindContext(widget.dayHours, widget.location);

    // Tide range
    final tideRange = _getTideRange(widget.dayHours);

    // Swell info
    final swellInfo = _getSwellInfo(widget.day);

    // Water temp
    final waterTemps = widget.dayHours
        .where((h) => h.seaSurfaceTemp != null)
        .map((h) => h.seaSurfaceTemp!)
        .toList();
    final avgWaterTemp = waterTemps.isNotEmpty
        ? waterTemps.reduce((a, b) => a + b) / waterTemps.length
        : null;

    // Moon
    final moonEmoji = getMoonPhase(widget.day.date).emoji;

    // Wave energy (ft² × period)
    final energy = _getEnergyFromHours(widget.dayHours);

    final dayLabel = isToday(widget.day.date) ? 'Today' : formatDayFull(widget.day.date);
    final waveMaxFt = widget.day.waveHeightMax != null
        ? formatWaveHeight(widget.day.waveHeightMax)
        : '--';

    final semanticLabel = '$dayLabel: ${condLabel?.label ?? ''} conditions, $waveMaxFt ft waves';

    // Condition-tinted background for mood
    final condColor = bestScore != null ? _scoreColor(bestScore) : null;
    final tintedBg = condColor != null
        ? Color.lerp(bg, condColor, isDark ? 0.08 : 0.05)!
        : bg;

    return Semantics(
      label: semanticLabel,
      button: true,
      child: GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _expanded = !_expanded);
        widget.onTap?.call();
      },
      child: AnimatedContainer(
        duration: AppDurations.base,
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(AppSpacing.s3),
        decoration: BoxDecoration(
          color: tintedBg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border(
            left: BorderSide(
              color: condColor?.withValues(alpha: widget.isSelected ? 0.8 : 0.5) ?? Colors.transparent,
              width: 3,
            ),
            top: BorderSide(
              color: widget.isSelected ? AppColors.accent : Colors.transparent,
              width: widget.isSelected ? 1.5 : 0,
            ),
            right: BorderSide(
              color: widget.isSelected ? AppColors.accent : Colors.transparent,
              width: widget.isSelected ? 1.5 : 0,
            ),
            bottom: BorderSide(
              color: widget.isSelected ? AppColors.accent : Colors.transparent,
              width: widget.isSelected ? 1.5 : 0,
            ),
          ),
          boxShadow: widget.isSelected ? AppShadows.base : AppShadows.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: day label + condition badge + wind context + wave max
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
                // Wind context inline in collapsed view
                if (windContext != null && !_expanded) ...[
                  _windBadge(windContext.$1, windContext.$2),
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
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: AppDurations.base,
                  curve: Curves.easeInOutCubic,
                  child: Icon(
                    Icons.expand_more,
                    size: _expanded ? 18 : 16,
                    color: _expanded ? AppColors.accent : subColor,
                  ),
                ),
              ],
            ),
            // Expanded detail
            AnimatedSize(
              duration: AppDurations.base,
              curve: Curves.easeInOut,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          // Temp
                          if (widget.day.tempMax != null)
                            _chip(
                              '${formatTemp(widget.day.tempMax)}\u00b0/${formatTemp(widget.day.tempMin)}\u00b0',
                              subColor,
                            ),
                          // Water temp
                          if (avgWaterTemp != null)
                            _chip('${formatTemp(avgWaterTemp)}\u00b0 water', subColor),
                          // Tide range
                          if (tideRange != null) _chip(tideRange, subColor),
                          // Swell
                          if (swellInfo != null) _chip(swellInfo, subColor),
                          // Wind context (in expanded)
                          if (windContext != null)
                            _windBadge(windContext.$1, windContext.$2),
                          // Energy
                          if (energy != null)
                            _windBadge(energy.$1, energy.$2),
                          // Moon
                          _chip(moonEmoji, subColor),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
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
          fontSize: AppTypography.textXxs,
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
    return "${mn.toStringAsFixed(1)}\u2013${mx.toStringAsFixed(1)}'";
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
