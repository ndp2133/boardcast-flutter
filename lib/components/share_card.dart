/// Canvas-rendered 1080x1350 share image — best window or current conditions.
/// Uses dart:ui PictureRecorder + Canvas for off-screen image generation.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/current_conditions.dart';
import '../models/hourly_data.dart';
import '../models/location.dart';
import '../models/user_prefs.dart';
import '../logic/scoring.dart';
import '../logic/units.dart';
import '../logic/time_utils.dart';

const _w = 1080.0;
const _h = 1350.0;

/// Generate and share a surf conditions report card.
/// If [bestWindow] and [hourlyData] are provided, renders the "Best Time" variant.
/// Otherwise renders current conditions.
Future<void> generateAndShareCard({
  required CurrentConditions current,
  required Location location,
  required bool isDark,
  UserPrefs? prefs,
  TopWindow? bestWindow,
  List<HourlyData>? hourlyData,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, _w, _h));

  final colors = _CardColors.from(isDark);

  // Background
  canvas.drawRect(
    Rect.fromLTWH(0, 0, _w, _h),
    Paint()..color = colors.bg,
  );

  _drawHeader(canvas, location, colors);

  if (bestWindow != null && hourlyData != null) {
    _drawBestWindowCard(canvas, bestWindow, hourlyData, location, prefs, colors);
  } else {
    _drawCurrentConditionsCard(canvas, current, prefs, location, colors);
  }

  _drawFooter(canvas, colors);

  final picture = recorder.endRecording();
  final image = await picture.toImage(_w.toInt(), _h.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) return;

  final bytes = byteData.buffer.asUint8List();
  await _shareImage(bytes, location.name, bestWindow != null
      ? 'Best Time to Surf'
      : 'Boardcast Surf Report');
}

// --- Drawing helpers ---

void _drawHeader(Canvas canvas, Location location, _CardColors colors) {
  // Wave icon
  final wavePaint = Paint()
    ..color = colors.accent
    ..strokeWidth = 4
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  final wavePath = Path();
  for (var x = 0.0; x <= 40; x++) {
    final y = 72 + sin((x / 40) * pi * 2) * 8;
    if (x == 0) {
      wavePath.moveTo(60 + x, y);
    } else {
      wavePath.lineTo(60 + x, y);
    }
  }
  canvas.drawPath(wavePath, wavePaint);

  // "Boardcast" title
  _drawText(canvas, 'Boardcast', 115, 90,
      color: colors.textPrimary,
      fontSize: 48,
      fontWeight: FontWeight.bold);

  // Location name
  _drawText(canvas, location.name, 60, 145,
      color: colors.textSecondary,
      fontSize: 32,
      fontWeight: FontWeight.w500);
}

void _drawBestWindowCard(
  Canvas canvas,
  TopWindow window,
  List<HourlyData> hourlyData,
  Location location,
  UserPrefs? prefs,
  _CardColors colors,
) {
  final condLabel = getConditionLabel(window.avgScore);
  final condColor = _parseColor(condLabel.color);
  final dayLabel = isToday(window.date) ? 'Today' : formatDayFull(window.date);
  final startHour = formatHour(window.startTime);
  final endHour = formatHour(window.endTime);

  // Date line
  _drawText(canvas, '$dayLabel \u00b7 ${window.hours}h window', 60, 190,
      color: colors.textSecondary, fontSize: 28);

  // Divider
  canvas.drawRect(
    Rect.fromLTWH(60, 220, _w - 120, 1),
    Paint()..color = colors.textPrimary.withValues(alpha: 0.06),
  );

  // "BEST TIME TO SURF" label
  _drawText(canvas, 'BEST TIME TO SURF', _w / 2, 280,
      color: colors.accent,
      fontSize: 28,
      fontWeight: FontWeight.bold,
      textAlign: TextAlign.center);

  // Time window (large)
  _drawText(canvas, '$startHour\u2013$endHour', _w / 2, 420,
      color: colors.textPrimary,
      fontSize: 100,
      fontWeight: FontWeight.bold,
      textAlign: TextAlign.center);

  // Condition badge
  final intScore = (window.avgScore * 100).round();
  final badgeText = '${condLabel.label.toUpperCase()} \u00b7 $intScore%';
  _drawBadge(canvas, badgeText, _w / 2, 460, condColor);

  // Avg wave height
  final avgWaveFt = window.waveHeight != null
      ? metersToFeet(window.waveHeight!).toStringAsFixed(1)
      : '--';
  _drawText(canvas, '$avgWaveFt ft avg wave height', _w / 2, 570,
      color: colors.textSecondary,
      fontSize: 32,
      textAlign: TextAlign.center);

  // Metrics grid
  // Compute avg conditions during window hours
  final windowStart = int.parse(window.startTime.split('T')[1].split(':')[0]);
  final windowEnd = int.parse(window.endTime.split('T')[1].split(':')[0]);
  final windowHours = hourlyData.where((h) {
    if (!h.time.startsWith(window.date)) return false;
    final hr = int.parse(h.time.split('T')[1].split(':')[0]);
    return hr >= windowStart && hr <= windowEnd;
  }).toList();

  double avgWindMph = 0;
  double avgSwellPeriod = 0;
  double? avgTide;
  String windDirStr = '';

  if (windowHours.isNotEmpty) {
    final winds = windowHours.where((h) => h.windSpeed != null);
    if (winds.isNotEmpty) {
      avgWindMph = winds.map((h) => kmhToMph(h.windSpeed!)).reduce((a, b) => a + b) / winds.length;
    }
    final swells = windowHours.where((h) => h.swellPeriod != null);
    if (swells.isNotEmpty) {
      avgSwellPeriod = swells.map((h) => h.swellPeriod!).reduce((a, b) => a + b) / swells.length;
    }
    final tides = windowHours.where((h) => h.tideHeight != null);
    if (tides.isNotEmpty) {
      avgTide = tides.map((h) => h.tideHeight!).reduce((a, b) => a + b) / tides.length;
    }
    final windDirs = windowHours.where((h) => h.windDirection != null).toList();
    if (windDirs.isNotEmpty) {
      windDirStr = degreesToCardinal(windDirs[windDirs.length ~/ 2].windDirection!);
    }
  }

  final swellDirStr = windowHours.isNotEmpty && windowHours.first.swellDirection != null
      ? degreesToCardinal(windowHours.first.swellDirection!)
      : '';

  final metrics = [
    _Metric('WAVES', '$avgWaveFt ft', '$swellDirStr ${avgSwellPeriod > 0 ? '${avgSwellPeriod.round()}s' : ''}'),
    _Metric('WIND', '${avgWindMph.round()} mph', windDirStr),
    _Metric('TIDE', avgTide != null ? '${avgTide.toStringAsFixed(1)} ft' : '--', 'avg during window'),
    _Metric('PERIOD', avgSwellPeriod > 0 ? '${avgSwellPeriod.round()}s' : '--', '$swellDirStr swell'),
  ];

  _drawMetricGrid(canvas, metrics, 630, colors);
}

void _drawCurrentConditionsCard(
  Canvas canvas,
  CurrentConditions current,
  UserPrefs? prefs,
  Location location,
  _CardColors colors,
) {
  // Date line
  final now = DateTime.now();
  final dateStr =
      '${_weekdayName(now.weekday)}, ${_monthName(now.month)} ${now.day}';
  _drawText(canvas, dateStr, 60, 190,
      color: colors.textSecondary, fontSize: 28);

  // Divider
  canvas.drawRect(
    Rect.fromLTWH(60, 220, _w - 120, 1),
    Paint()..color = colors.textPrimary.withValues(alpha: 0.06),
  );

  // Hero wave height
  final waveHFt = current.waveHeight != null
      ? metersToFeet(current.waveHeight!).toStringAsFixed(1)
      : '--';
  _drawText(canvas, waveHFt, _w / 2, 440,
      color: colors.textPrimary,
      fontSize: 160,
      fontWeight: FontWeight.bold,
      textAlign: TextAlign.center);

  _drawText(canvas, 'ft wave height', _w / 2, 500,
      color: colors.textSecondary,
      fontSize: 42,
      textAlign: TextAlign.center);

  // Condition badge
  if (prefs != null) {
    final hourData = HourlyData(
      time: current.timestamp,
      waveHeight: current.waveHeight,
      windSpeed: current.windSpeed,
      windDirection: current.windDirection,
      swellDirection: current.swellDirection,
    );
    final score = computeMatchScore(hourData, prefs, location);
    final condLabel = getConditionLabel(score);
    final condColor = _parseColor(condLabel.color);
    _drawBadge(canvas, condLabel.label.toUpperCase(), _w / 2, 530, condColor);
  }

  // Metrics grid
  final metrics = [
    _Metric(
      'SWELL',
      current.swellHeight != null
          ? '${formatWaveHeight(current.swellHeight)} ft'
          : '--',
      current.swellPeriod != null
          ? '${current.swellPeriod!.toStringAsFixed(1)}s period'
          : '',
    ),
    _Metric(
      'WIND',
      '${formatWindSpeed(current.windSpeed)} mph',
      current.windDirection != null
          ? degreesToCardinal(current.windDirection!)
          : '',
    ),
    _Metric(
      'TIDE',
      current.tideHeight != null
          ? '${current.tideHeight!.toStringAsFixed(1)} ft'
          : '--',
      current.tideTrend ?? '',
    ),
    _Metric(
      'PERIOD',
      current.wavePeriod != null
          ? '${current.wavePeriod!.toStringAsFixed(1)}s'
          : '--',
      current.swellDirection != null
          ? '${degreesToCardinal(current.swellDirection!)} swell'
          : '',
    ),
  ];

  _drawMetricGrid(canvas, metrics, 630, colors);
}

void _drawFooter(Canvas canvas, _CardColors colors) {
  // Wave decorations
  for (final (yOff, alpha, amp, period) in [
    (140.0, 0.06, 20.0, 180.0),
    (110.0, 0.10, 15.0, 220.0),
    (80.0, 0.16, 10.0, 160.0),
  ]) {
    final path = Path();
    path.moveTo(0, _h - yOff);
    for (var x = 0.0; x <= _w; x += 2) {
      path.lineTo(x, _h - yOff + sin((x / period) * pi * 2) * amp);
    }
    path.lineTo(_w, _h);
    path.lineTo(0, _h);
    path.close();
    canvas.drawPath(
      path,
      Paint()..color = colors.accent.withValues(alpha: alpha),
    );
  }

  // URL
  _drawText(canvas, 'myboardcast.vercel.app', _w / 2, _h - 30,
      color: colors.textSecondary, fontSize: 24, textAlign: TextAlign.center);
}

void _drawMetricGrid(
    Canvas canvas, List<_Metric> metrics, double gridY, _CardColors colors) {
  const cellW = (_w - 180) / 2;
  const cellH = 180.0;
  const gap = 24.0;

  for (var i = 0; i < metrics.length; i++) {
    final col = i % 2;
    final row = i ~/ 2;
    final x = 60 + col * (cellW + gap);
    final y = gridY + row * (cellH + gap);

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, cellW, cellH),
      const Radius.circular(20),
    );
    canvas.drawRRect(rrect, Paint()..color = colors.cardBg);

    final m = metrics[i];
    _drawText(canvas, m.label, x + 28, y + 42,
        color: colors.textSecondary, fontSize: 20, fontWeight: FontWeight.w600);
    _drawText(canvas, m.value, x + 28, y + 105,
        color: colors.textPrimary,
        fontSize: 44,
        fontWeight: FontWeight.bold,
        fontFamily: 'DMMono');
    _drawText(canvas, m.sub, x + 28, y + 145,
        color: colors.textSecondary, fontSize: 24);
  }
}

void _drawBadge(Canvas canvas, String text, double cx, double badgeY, Color color) {
  // Measure text width estimate (rough: fontSize * 0.6 * chars)
  final badgeW = text.length * 17.0 + 60;
  const badgeH = 56.0;
  final badgeX = cx - badgeW / 2;

  final rrect = RRect.fromRectAndRadius(
    Rect.fromLTWH(badgeX, badgeY, badgeW, badgeH),
    const Radius.circular(28),
  );
  canvas.drawRRect(rrect, Paint()..color = color.withValues(alpha: 0.12));

  _drawText(canvas, text, cx, badgeY + 38,
      color: color,
      fontSize: 28,
      fontWeight: FontWeight.bold,
      textAlign: TextAlign.center);
}

void _drawText(
  Canvas canvas,
  String text,
  double x,
  double y, {
  required Color color,
  required double fontSize,
  FontWeight fontWeight = FontWeight.w400,
  TextAlign textAlign = TextAlign.left,
  String fontFamily = 'Inter',
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontFamily: fontFamily,
      ),
    ),
    textDirection: TextDirection.ltr,
  );
  tp.layout(maxWidth: _w - 120);

  final dx = switch (textAlign) {
    TextAlign.center => x - tp.width / 2,
    TextAlign.right => x - tp.width,
    _ => x,
  };
  tp.paint(canvas, Offset(dx, y - fontSize * 0.8));
}

Future<void> _shareImage(Uint8List bytes, String locationName, String title) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/boardcast-report.png');
  await file.writeAsBytes(bytes);

  await Share.shareXFiles(
    [XFile(file.path)],
    subject: title,
    text: 'Surf conditions at $locationName',
  );
}

Color _parseColor(String hex) {
  final h = hex.replaceFirst('#', '');
  return Color(int.parse('FF$h', radix: 16));
}

String _weekdayName(int wd) =>
    const ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][wd];

String _monthName(int m) =>
    const ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m];

class _Metric {
  final String label;
  final String value;
  final String sub;
  const _Metric(this.label, this.value, this.sub);
}

class _CardColors {
  final Color bg;
  final Color cardBg;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;

  const _CardColors({
    required this.bg,
    required this.cardBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
  });

  factory _CardColors.from(bool isDark) {
    if (isDark) {
      return const _CardColors(
        bg: Color(0xFF0F1923),
        cardBg: Color(0xFF162230),
        textPrimary: Color(0xFFE2E8F0),
        textSecondary: Color(0xFF94A3B8),
        accent: Color(0xFF4DB8A4),
      );
    }
    return const _CardColors(
      bg: Color(0xFFF5F7FA),
      cardBg: Color(0xFFFFFFFF),
      textPrimary: Color(0xFF1A1A2E),
      textSecondary: Color(0xFF6B7280),
      accent: Color(0xFF4DB8A4),
    );
  }
}
