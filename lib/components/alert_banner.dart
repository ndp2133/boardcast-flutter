/// Alert banner — proactive notification for good upcoming conditions
/// Port of alertBanner.js from PWA
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../models/hourly_data.dart';
import '../models/user_prefs.dart';
import '../models/location.dart';
import '../logic/scoring.dart';
import '../logic/units.dart';
import '../logic/time_utils.dart';

class AlertBanner extends StatefulWidget {
  final List<HourlyData> hourlyData;
  final UserPrefs prefs;
  final Location location;
  final VoidCallback? onTap;

  const AlertBanner({
    super.key,
    required this.hourlyData,
    required this.prefs,
    required this.location,
    this.onTap,
  });

  @override
  State<AlertBanner> createState() => _AlertBannerState();
}

class _AlertBannerState extends State<AlertBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final windows = findTopWindows(
      widget.hourlyData, widget.prefs, widget.location, count: 1,
    );
    if (windows.isEmpty) return const SizedBox.shrink();

    final w = windows.first;
    if (w.avgScore < 0.6) return const SizedBox.shrink();

    // Skip if window end time is in the past
    final endTime = DateTime.tryParse(w.endTime);
    if (endTime != null && endTime.isBefore(DateTime.now())) {
      return const SizedBox.shrink();
    }

    final condition = getConditionLabel(w.avgScore);
    final conditionColor = _parseColor(condition.color);
    final dayLabel = isToday(w.date) ? 'today' : formatDayShort(w.date);
    final startHour = formatHour(w.startTime);
    final endHour = formatHour(w.endTime);
    final waveFt = w.waveHeight != null
        ? formatWaveHeight(w.waveHeight)
        : '--';

    final message = '${condition.label} conditions $dayLabel \u00b7 '
        '$startHour\u2013$endHour \u00b7 ${waveFt}ft waves';

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        setState(() => _dismissed = true);
        widget.onTap?.call();
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.s1),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: conditionColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: AppTypography.textXs,
                  fontWeight: AppTypography.weightMedium,
                  color: conditionColor,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _dismissed = true),
              child: Icon(
                Icons.close,
                size: 14,
                color: isDark
                    ? AppColorsDark.textTertiary
                    : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _parseColor(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}
