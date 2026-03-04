/// Condition bar — colored hourly segments showing condition quality
/// Port of conditionBarPlugin from PWA's forecastChart.js
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../models/hourly_data.dart';
import '../models/user_prefs.dart';
import '../models/location.dart';
import '../logic/scoring.dart';

class ConditionBar extends StatelessWidget {
  final List<HourlyData> hourlyData;
  final UserPrefs? prefs;
  final Location? location;

  const ConditionBar({
    super.key,
    required this.hourlyData,
    this.prefs,
    this.location,
  });

  @override
  Widget build(BuildContext context) {
    if (hourlyData.isEmpty || prefs == null || location == null) {
      return const SizedBox.shrink();
    }

    final tideRange = TideRange.fromHourlyData(hourlyData);
    final scores = hourlyData
        .map((h) => computeMatchScore(h, prefs, location!,
            tideRange: tideRange))
        .toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 7,
        child: Row(
          children: List.generate(scores.length, (i) {
            return Expanded(
              child: Container(color: _conditionColor(scores[i])),
            );
          }),
        ),
      ),
    );
  }

  static Color _conditionColor(double score) {
    if (score >= 0.8) return AppColors.conditionEpic.withValues(alpha: 0.7);
    if (score >= 0.6) return AppColors.conditionGood.withValues(alpha: 0.6);
    if (score >= 0.4) return AppColors.conditionFair.withValues(alpha: 0.5);
    return AppColors.conditionPoor.withValues(alpha: 0.35);
  }
}
