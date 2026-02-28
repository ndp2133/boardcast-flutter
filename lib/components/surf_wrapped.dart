/// Surf Wrapped — canvas-rendered monthly/all-time summary share image.
/// 1080x1350 (4:5 Instagram ratio).
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/session.dart';
import '../models/board.dart';
import '../logic/scoring.dart';
import '../logic/locations.dart';

const _w = 1080.0;
const _h = 1350.0;

/// Generate and share a Surf Wrapped summary card.
/// [period] is 'all' or 'month'.
Future<bool> generateAndShareWrapped({
  required List<Session> sessions,
  required List<Board> boards,
  required bool isDark,
  String period = 'all',
}) async {
  final completed = sessions.where((s) => s.status == 'completed').toList();
  if (completed.isEmpty) return false;

  // Filter by period
  List<Session> filtered;
  String periodLabel;

  if (period == 'month') {
    final now = DateTime.now();
    final monthPrefix =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    filtered =
        completed.where((s) => s.date.startsWith(monthPrefix)).toList();
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    periodLabel = '${months[now.month]} ${now.year}';
    if (filtered.isEmpty) return false;
  } else {
    filtered = completed;
    periodLabel = 'All Time';
  }

  final colors = _WrappedColors.from(isDark);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, _w, _h));

  // Background
  canvas.drawRect(
    Rect.fromLTWH(0, 0, _w, _h),
    Paint()..color = colors.bg,
  );

  // --- Header ---
  _drawText(canvas, 'YOUR SURF WRAPPED', _w / 2, 60,
      color: colors.accent,
      fontSize: 28,
      fontWeight: FontWeight.bold,
      textAlign: TextAlign.center);

  _drawText(canvas, periodLabel, _w / 2, 120,
      color: colors.textPrimary,
      fontSize: 48,
      fontWeight: FontWeight.bold,
      textAlign: TextAlign.center);

  // Wave decoration under title
  final wavePaint = Paint()
    ..color = colors.accent
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  final wavePath = Path();
  for (var x = _w / 2 - 80; x <= _w / 2 + 80; x++) {
    final y = 150 + sin(((x - _w / 2 + 80) / 160) * pi * 3) * 6;
    if (x == _w / 2 - 80) {
      wavePath.moveTo(x, y);
    } else {
      wavePath.lineTo(x, y);
    }
  }
  canvas.drawPath(wavePath, wavePaint);

  // --- Compute stats ---
  final totalSessions = filtered.length;
  final totalHours =
      filtered.fold<int>(0, (s, sess) => s + (sess.selectedHours?.length ?? 0));

  // Favorite spot
  final spotCounts = <String, int>{};
  for (final s in filtered) {
    spotCounts[s.locationId] = (spotCounts[s.locationId] ?? 0) + 1;
  }
  final favSpotId = spotCounts.entries
      .reduce((a, b) => a.value >= b.value ? a : b)
      .key;
  final favSpotLoc = locations.where((l) => l.id == favSpotId).firstOrNull;
  final favSpot = favSpotLoc?.name ?? favSpotId;

  // Average rating
  final rated = filtered.where((s) => s.rating != null).toList();
  final avgRating = rated.isNotEmpty
      ? (rated.fold<int>(0, (s, sess) => s + sess.rating!) / rated.length)
          .toStringAsFixed(1)
      : '--';

  // Condition distribution
  final condCounts = {'epic': 0, 'good': 0, 'fair': 0, 'poor': 0};
  for (final s in filtered) {
    final score = s.conditions?.matchScore;
    if (score != null) {
      final label = getConditionLabel(score);
      final key = label.label.toLowerCase();
      condCounts[key] = (condCounts[key] ?? 0) + 1;
    }
  }
  final totalCond = condCounts.values.fold<int>(0, (a, b) => a + b);

  // Longest streak
  final dates = filtered
      .map((s) => s.date.split('T')[0])
      .toSet()
      .toList()
    ..sort();
  var longestStreak = dates.isNotEmpty ? 1 : 0;
  var run = 1;
  for (var i = 1; i < dates.length; i++) {
    final prev = DateTime.parse('${dates[i - 1]}T00:00:00');
    final next = DateTime.parse('${dates[i]}T00:00:00');
    if (next.difference(prev).inDays == 1) {
      run++;
      if (run > longestStreak) longestStreak = run;
    } else {
      run = 1;
    }
  }

  // Board usage
  final boardUsage = <String, int>{};
  for (final s in filtered) {
    final boardId = s.boardId;
    if (boardId != null) boardUsage[boardId] = (boardUsage[boardId] ?? 0) + 1;
  }
  String? topBoardName;
  int? topBoardCount;
  if (boardUsage.isNotEmpty) {
    final topEntry =
        boardUsage.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final board = boards.where((b) => b.id == topEntry.key).firstOrNull;
    topBoardName = board?.name ?? board?.type;
    topBoardCount = topEntry.value;
  }

  // --- Draw stat cards ---
  const cardW = (_w - 180) / 2;
  const cardH = 155.0;
  const gap = 24.0;
  const startY = 190.0;

  // Row 1: Sessions + Avg Rating
  _drawStatCard(canvas, 60, startY, cardW, cardH, 'SESSIONS',
      '$totalSessions', '${totalHours}h in the water', colors);
  _drawStatCard(canvas, 60 + cardW + gap, startY, cardW, cardH, 'AVG RATING',
      avgRating == '--' ? '--' : '$avgRating/5',
      rated.isNotEmpty ? 'from ${rated.length} rated' : '', colors);

  // Row 2: Favorite Spot + Streak
  const row2Y = startY + cardH + gap;
  _drawStatCard(
      canvas, 60, row2Y, cardW, cardH, 'FAVORITE SPOT', '', '', colors);
  // Redraw value for spot name (possibly smaller font for long names)
  final spotFontSize = favSpot.length > 12 ? 32.0 : 44.0;
  final displaySpot =
      favSpot.length > 18 ? '${favSpot.substring(0, 16)}..' : favSpot;
  _drawText(canvas, displaySpot, 88, row2Y + 95,
      color: colors.accent, fontSize: spotFontSize, fontWeight: FontWeight.bold,
      fontFamily: 'DMMono');

  _drawStatCard(canvas, 60 + cardW + gap, row2Y, cardW, cardH, 'BEST STREAK',
      longestStreak > 0 ? '$longestStreak days' : '--',
      longestStreak > 1 ? 'consecutive sessions' : '', colors);

  // --- Condition distribution bar ---
  final barY = row2Y + cardH + gap + 20;
  _drawText(canvas, 'CONDITIONS SURFED', 60, barY,
      color: colors.textSecondary, fontSize: 22, fontWeight: FontWeight.w600);

  if (totalCond > 0) {
    _drawConditionBar(canvas, 60, barY + 16, _w - 120, 32, condCounts, totalCond);

    // Legend
    final legendY = barY + 70.0;
    final legendItems = [
      ('Epic', const Color(0xFF22C55E), condCounts['epic']!),
      ('Good', const Color(0xFF4DB8A4), condCounts['good']!),
      ('Fair', const Color(0xFFF59E0B), condCounts['fair']!),
      ('Poor', const Color(0xFFEF4444), condCounts['poor']!),
    ].where((item) => item.$3 > 0).toList();

    var lx = 60.0;
    for (final (label, color, count) in legendItems) {
      canvas.drawCircle(
        Offset(lx + 8, legendY),
        8,
        Paint()..color = color,
      );
      final text = '$label ($count)';
      _drawText(canvas, text, lx + 22, legendY + 6,
          color: colors.textSecondary, fontSize: 20);
      lx += text.length * 11.0 + 50;
    }
  }

  // --- Board usage ---
  if (topBoardName != null) {
    final boardY = barY + 120;
    _drawText(canvas, 'GO-TO BOARD', 60, boardY,
        color: colors.textSecondary, fontSize: 22, fontWeight: FontWeight.w600);
    _drawText(canvas, topBoardName, 60, boardY + 48,
        color: colors.textPrimary, fontSize: 36, fontWeight: FontWeight.bold);
    _drawText(canvas, '$topBoardCount session${topBoardCount! > 1 ? 's' : ''}',
        60, boardY + 84,
        color: colors.textSecondary, fontSize: 22);
  }

  // --- Footer ---
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

  _drawText(canvas, 'myboardcast.vercel.app', _w / 2, _h - 30,
      color: colors.textSecondary, fontSize: 24, textAlign: TextAlign.center);

  // --- Export ---
  final picture = recorder.endRecording();
  final image = await picture.toImage(_w.toInt(), _h.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) return false;

  final bytes = byteData.buffer.asUint8List();
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/boardcast-wrapped.png');
  await file.writeAsBytes(bytes);

  await Share.shareXFiles(
    [XFile(file.path)],
    subject: 'My Surf Wrapped',
    text: 'My Surf Wrapped - $periodLabel',
  );

  return true;
}

// --- Drawing helpers ---

void _drawStatCard(Canvas canvas, double x, double y, double w, double h,
    String label, String value, String sub, _WrappedColors colors) {
  final rrect = RRect.fromRectAndRadius(
    Rect.fromLTWH(x, y, w, h),
    const Radius.circular(20),
  );
  canvas.drawRRect(rrect, Paint()..color = colors.cardBg);

  _drawText(canvas, label, x + 28, y + 36,
      color: colors.textSecondary, fontSize: 20, fontWeight: FontWeight.w600);

  if (value.isNotEmpty) {
    _drawText(canvas, value, x + 28, y + 100,
        color: colors.accent, fontSize: 52, fontWeight: FontWeight.bold,
        fontFamily: 'DMMono');
  }

  if (sub.isNotEmpty) {
    _drawText(canvas, sub, x + 28, y + 135,
        color: colors.textSecondary, fontSize: 22);
  }
}

void _drawConditionBar(Canvas canvas, double x, double y, double w, double h,
    Map<String, int> counts, int total) {
  // Background
  final bgRRect = RRect.fromRectAndRadius(
    Rect.fromLTWH(x, y, w, h),
    Radius.circular(h / 2),
  );
  canvas.drawRRect(bgRRect, Paint()..color = const Color(0x201A1A2E));

  // Clip to rounded rect for segments
  canvas.save();
  canvas.clipRRect(bgRRect);

  final order = ['epic', 'good', 'fair', 'poor'];
  final segColors = {
    'epic': const Color(0xFF22C55E),
    'good': const Color(0xFF4DB8A4),
    'fair': const Color(0xFFF59E0B),
    'poor': const Color(0xFFEF4444),
  };

  var cx = x;
  for (final key in order) {
    final count = counts[key] ?? 0;
    if (count == 0) continue;
    final segW = (count / total) * w;
    canvas.drawRect(
      Rect.fromLTWH(cx, y, segW + 1, h),
      Paint()..color = segColors[key]!,
    );
    cx += segW;
  }

  canvas.restore();
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

class _WrappedColors {
  final Color bg;
  final Color cardBg;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;

  const _WrappedColors({
    required this.bg,
    required this.cardBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
  });

  factory _WrappedColors.from(bool isDark) {
    if (isDark) {
      return const _WrappedColors(
        bg: Color(0xFF0F1923),
        cardBg: Color(0xFF162230),
        textPrimary: Color(0xFFE2E8F0),
        textSecondary: Color(0xFF94A3B8),
        accent: Color(0xFF4DB8A4),
      );
    }
    return const _WrappedColors(
      bg: Color(0xFFF5F7FA),
      cardBg: Color(0xFFFFFFFF),
      textPrimary: Color(0xFF1A1A2E),
      textSecondary: Color(0xFF6B7280),
      accent: Color(0xFF4DB8A4),
    );
  }
}
