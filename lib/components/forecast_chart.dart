import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../theme/tokens.dart';
import '../models/hourly_data.dart';
import '../logic/units.dart';
import '../logic/time_utils.dart';
import '../logic/scoring.dart';
import '../models/user_prefs.dart';
import '../models/location.dart';

class ForecastChart extends StatelessWidget {
  final List<HourlyData> hourlyData;
  final UserPrefs? prefs;
  final Location? location;
  final bool isToday;
  final int? currentHourIndex;
  final ValueNotifier<int?>? scrubberNotifier;

  const ForecastChart({
    super.key,
    required this.hourlyData,
    this.prefs,
    this.location,
    this.isToday = false,
    this.currentHourIndex,
    this.scrubberNotifier,
  });

  @override
  Widget build(BuildContext context) {
    if (hourlyData.isEmpty) {
      return const SizedBox(height: 200);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Build chart data
    final waveData = <_ChartPoint>[];
    final windData = <_ChartPoint>[];
    final matchScores = <double>[];

    for (var i = 0; i < hourlyData.length; i++) {
      final h = hourlyData[i];
      final label = formatHour(h.time);
      final wave = h.waveHeight != null ? metersToFeet(h.waveHeight!) : 0.0;
      final wind = h.windSpeed != null ? kmhToMph(h.windSpeed!) : 0.0;
      waveData.add(_ChartPoint(i, wave, label));
      windData.add(_ChartPoint(i, wind, label));

      if (prefs != null && location != null) {
        matchScores.add(computeMatchScore(h, prefs, location!));
      }
    }

    // Best window overlay
    BestWindowIndices? bestWindow;
    if (matchScores.isNotEmpty) {
      bestWindow = findBestWindowIndices(matchScores);
    }

    final gridColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);
    final tickColor =
        isDark ? AppColorsDark.textTertiary : AppColors.textTertiary;

    // Build plot bands for best window + now line
    final plotBands = <PlotBand>[];

    if (bestWindow != null &&
        bestWindow.startIndex < waveData.length &&
        bestWindow.endIndex < waveData.length) {
      plotBands.add(PlotBand(
        start: bestWindow.startIndex,
        end: bestWindow.endIndex,
        color: AppColors.accent.withValues(alpha: 0.10),
        borderColor: AppColors.accent.withValues(alpha: 0.5),
        borderWidth: 1,
      ));
    }

    if (isToday &&
        currentHourIndex != null &&
        currentHourIndex! < waveData.length) {
      plotBands.add(PlotBand(
        start: currentHourIndex!,
        end: currentHourIndex!,
        borderColor: isDark
            ? Colors.white.withValues(alpha: 0.4)
            : Colors.black.withValues(alpha: 0.3),
        borderWidth: 1.5,
        dashArray: const [4, 4],
      ));
    }

    return SizedBox(
      height: 210,
      child: SfCartesianChart(
        margin: const EdgeInsets.only(top: 8, right: 4, bottom: 0, left: 4),
        plotAreaBorderWidth: 0,
        primaryXAxis: CategoryAxis(
          majorGridLines: const MajorGridLines(width: 0),
          labelStyle: TextStyle(
            fontFamily: AppTypography.fontMono,
            fontSize: 9,
            color: tickColor,
          ),
          labelPlacement: LabelPlacement.onTicks,
          interval: 3,
          plotBands: plotBands,
        ),
        primaryYAxis: NumericAxis(
          minimum: 0,
          majorGridLines: MajorGridLines(width: 0.5, color: gridColor),
          labelStyle: TextStyle(
            fontFamily: AppTypography.fontMono,
            fontSize: 9,
            color: tickColor,
          ),
          axisLine: const AxisLine(width: 0),
          labelFormat: '{value} ft',
        ),
        axes: [
          NumericAxis(
            name: 'windAxis',
            opposedPosition: true,
            minimum: 0,
            majorGridLines: const MajorGridLines(width: 0),
            labelStyle: TextStyle(
              fontFamily: AppTypography.fontMono,
              fontSize: 9,
              color: tickColor,
            ),
            axisLine: const AxisLine(width: 0),
            labelFormat: '{value} mph',
          ),
        ],
        trackballBehavior: TrackballBehavior(
          enable: true,
          activationMode: ActivationMode.singleTap,
          tooltipDisplayMode: TrackballDisplayMode.groupAllPoints,
          tooltipSettings: InteractiveTooltip(
            color: isDark ? AppColorsDark.bgTertiary : const Color(0xFF1A1A2E),
            textStyle: const TextStyle(fontSize: 11, color: Colors.white),
            borderColor: Colors.transparent,
            borderWidth: 0,
          ),
          lineWidth: 1,
          lineColor: tickColor.withValues(alpha: 0.5),
          lineDashArray: const [4, 4],
          markerSettings: const TrackballMarkerSettings(
            markerVisibility: TrackballVisibilityMode.visible,
            height: 6,
            width: 6,
          ),
        ),
        series: [
          // Wave height — area series with gradient
          SplineAreaSeries<_ChartPoint, String>(
            name: 'Waves',
            dataSource: waveData,
            xValueMapper: (p, _) => p.label,
            yValueMapper: (p, _) => p.value,
            borderColor: AppColors.accent,
            borderWidth: 2,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.accent.withValues(alpha: isDark ? 0.35 : 0.25),
                AppColors.accent.withValues(alpha: 0.02),
              ],
            ),
            splineType: SplineType.monotonic,
          ),
          // Wind speed — dashed line on secondary axis
          SplineSeries<_ChartPoint, String>(
            name: 'Wind',
            dataSource: windData,
            xValueMapper: (p, _) => p.label,
            yValueMapper: (p, _) => p.value,
            yAxisName: 'windAxis',
            color:
                isDark ? const Color(0xFF64748B) : const Color(0xFF9CA3AF),
            width: 1.5,
            dashArray: const [5, 3],
            splineType: SplineType.monotonic,
          ),
        ],
      ),
    );
  }

}

class _ChartPoint {
  final int index;
  final double value;
  final String label;
  _ChartPoint(this.index, this.value, this.label);
}
