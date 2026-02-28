import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../theme/tokens.dart';
import '../models/hourly_data.dart';
import '../logic/time_utils.dart';

class TideChart extends StatelessWidget {
  final List<HourlyData> hourlyData;
  final bool isToday;
  final int? currentHourIndex;

  const TideChart({
    super.key,
    required this.hourlyData,
    this.isToday = false,
    this.currentHourIndex,
  });

  @override
  Widget build(BuildContext context) {
    final tidePoints = <_TidePoint>[];
    for (var i = 0; i < hourlyData.length; i++) {
      final h = hourlyData[i];
      if (h.tideHeight == null) continue;
      tidePoints.add(_TidePoint(
        index: i,
        height: h.tideHeight!,
        label: formatHour(h.time),
        hour: h.time,
      ));
    }

    if (tidePoints.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Find high/low extrema for annotations
    final extrema = _findExtrema(tidePoints);

    return SizedBox(
      height: 80,
      child: SfCartesianChart(
        margin: const EdgeInsets.only(top: 14, right: 4, bottom: 0, left: 4),
        plotAreaBorderWidth: 0,
        primaryXAxis: CategoryAxis(
          isVisible: false,
          majorGridLines: const MajorGridLines(width: 0),
        ),
        primaryYAxis: NumericAxis(
          isVisible: false,
          rangePadding: ChartRangePadding.additional,
          majorGridLines: const MajorGridLines(width: 0),
        ),
        trackballBehavior: TrackballBehavior(
          enable: true,
          activationMode: ActivationMode.singleTap,
          tooltipSettings: InteractiveTooltip(
            color: isDark ? AppColorsDark.bgTertiary : const Color(0xFF1A1A2E),
            textStyle: const TextStyle(fontSize: 10, color: Colors.white),
            borderColor: Colors.transparent,
          ),
          lineWidth: 1,
          lineDashArray: const [3, 3],
          lineColor: AppColors.accent.withValues(alpha: 0.5),
          markerSettings: const TrackballMarkerSettings(
            markerVisibility: TrackballVisibilityMode.visible,
            height: 6,
            width: 6,
            color: AppColors.accent,
          ),
        ),
        annotations: _buildAnnotations(extrema, tidePoints, isDark),
        series: [
          // Rising segments (green)
          SplineAreaSeries<_TidePoint, String>(
            dataSource: tidePoints,
            xValueMapper: (p, _) => p.label,
            yValueMapper: (p, _) => p.height,
            borderColor: const Color(0xFF22C55E),
            borderWidth: 1.5,
            color: isDark
                ? const Color(0x2E22C55E)
                : const Color(0x2622C55E),
            splineType: SplineType.monotonic,
            name: 'Tide',
          ),
        ],
      ),
    );
  }

  List<CartesianChartAnnotation> _buildAnnotations(
    List<_Extremum> extrema,
    List<_TidePoint> tidePoints,
    bool isDark,
  ) {
    final annotations = <CartesianChartAnnotation>[];
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;

    // High/low labels
    for (final ext in extrema) {
      if (ext.index >= tidePoints.length) continue;
      final pt = tidePoints[ext.index];
      final heightStr = pt.height.toStringAsFixed(1);
      final hourStr = _compactHour(pt.hour);

      annotations.add(CartesianChartAnnotation(
        widget: Text(
          "$heightStr' $hourStr",
          style: TextStyle(
            fontFamily: AppTypography.fontMono,
            fontSize: 9,
            fontWeight: AppTypography.weightBold,
            color: textColor,
          ),
        ),
        coordinateUnit: CoordinateUnit.point,
        x: pt.label,
        y: pt.height,
        verticalAlignment:
            ext.isHigh ? ChartAlignment.far : ChartAlignment.near,
      ));
    }

    // "Now" marker
    if (isToday &&
        currentHourIndex != null &&
        currentHourIndex! < tidePoints.length) {
      final pt = tidePoints[currentHourIndex!];
      annotations.add(CartesianChartAnnotation(
        widget: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? AppColorsDark.bgPrimary : Colors.white,
              width: 1.5,
            ),
          ),
        ),
        coordinateUnit: CoordinateUnit.point,
        x: pt.label,
        y: pt.height,
      ));
    }

    return annotations;
  }

  List<_Extremum> _findExtrema(List<_TidePoint> points) {
    if (points.length < 3) return [];

    final result = <_Extremum>[];
    int? lastDrawn;

    for (var i = 1; i < points.length - 1; i++) {
      final prev = points[i - 1].height;
      final curr = points[i].height;
      final next = points[i + 1].height;

      final isHigh = curr >= prev && curr >= next && (curr > prev || curr > next);
      final isLow = curr <= prev && curr <= next && (curr < prev || curr < next);

      if (isHigh || isLow) {
        // Skip if too close to last drawn (within 3 points)
        if (lastDrawn != null && (i - lastDrawn) < 3) continue;
        result.add(_Extremum(i, isHigh));
        lastDrawn = i;
      }
    }
    return result;
  }

  String _compactHour(String isoTime) {
    final dt = DateTime.parse(isoTime);
    final h = dt.hour;
    final ampm = h >= 12 ? 'P' : 'A';
    final hour = h % 12 == 0 ? 12 : h % 12;
    return '$hour$ampm';
  }
}

class _TidePoint {
  final int index;
  final double height;
  final String label;
  final String hour;
  _TidePoint({
    required this.index,
    required this.height,
    required this.label,
    required this.hour,
  });
}

class _Extremum {
  final int index;
  final bool isHigh;
  _Extremum(this.index, this.isHigh);
}
