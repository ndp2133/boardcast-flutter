import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../logic/scoring.dart';
import '../logic/units.dart';
import '../logic/time_utils.dart';
import '../models/session.dart';
import '../models/board.dart';
import '../components/star_rating.dart';
import '../components/empty_state.dart';

class SessionHistoryList extends StatelessWidget {
  final List<Session> sessions;
  final List<Board> boards;
  final bool isDark;
  final Color textColor;
  final Color subColor;
  final bool visible;

  const SessionHistoryList({
    super.key,
    required this.sessions,
    required this.boards,
    required this.isDark,
    required this.textColor,
    required this.subColor,
    this.visible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const EmptyState(
        icon: Icons.surfing,
        title: 'No sessions yet',
        subtitle:
            'The ocean is waiting. Plan your first session from the Track tab.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Session History',
          style: TextStyle(
            fontSize: AppTypography.textSm,
            fontWeight: AppTypography.weightSemibold,
            color: textColor,
          ),
        ),
        const SizedBox(height: AppSpacing.s2),
        ...sessions.asMap().entries.map((entry) {
          final i = entry.key;
          final s = entry.value;
          final delay = i < 10 ? i : 10;
          return AnimatedOpacity(
            duration: Duration(milliseconds: 300 + delay * 50),
            curve: Curves.easeOut,
            opacity: visible ? 1.0 : 0.0,
            child: AnimatedSlide(
              duration: Duration(milliseconds: 300 + delay * 50),
              curve: Curves.easeOut,
              offset: visible ? Offset.zero : const Offset(0, 0.08),
              child: _SessionRow(
                session: s,
                boards: boards,
                isDark: isDark,
                textColor: textColor,
                subColor: subColor,
              ),
            ),
          );
        }),
      ],
    );
  }
}

class SessionStatsGrid extends StatelessWidget {
  final List<Session> completed;
  final bool isDark;
  final Color textColor;
  final Color subColor;

  const SessionStatsGrid({
    super.key,
    required this.completed,
    required this.isDark,
    required this.textColor,
    required this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    final totalSessions = completed.length;
    final rated = completed.where((s) => s.rating != null);
    final avgRating = rated.isNotEmpty
        ? (rated.fold<int>(0, (sum, s) => sum + s.rating!) / rated.length)
        : 0.0;
    final bestRating = rated.isNotEmpty
        ? rated.map((s) => s.rating!).reduce((a, b) => a > b ? a : b)
        : 0;

    final calibrated =
        completed.where((s) => s.calibration != null).toList();
    final aboutRight =
        calibrated.where((s) => s.calibration == 0).length;
    final accuracy = calibrated.isNotEmpty
        ? ((aboutRight / calibrated.length) * 100).round()
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Stats',
          style: TextStyle(
            fontSize: AppTypography.textSm,
            fontWeight: AppTypography.weightSemibold,
            color: textColor,
          ),
        ),
        const SizedBox(height: AppSpacing.s2),
        Row(
          children: [
            _statCell('Sessions', '$totalSessions'),
            _statCell('Avg Rating',
                avgRating > 0 ? avgRating.toStringAsFixed(1) : '\u2014'),
            _statCell(
                'Best', bestRating > 0 ? '$bestRating/5' : '\u2014'),
            _statCell('Accuracy',
                calibrated.isNotEmpty ? '$accuracy%' : '\u2014'),
          ],
        ),
      ],
    );
  }

  Widget _statCell(String label, String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.s2, horizontal: AppSpacing.s2),
        decoration: BoxDecoration(
          color: isDark ? AppColorsDark.bgSecondary : AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: AppTypography.textBase,
                fontWeight: AppTypography.weightBold,
                fontFamily: AppTypography.fontMono,
                color: textColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: subColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  final Session session;
  final List<Board> boards;
  final bool isDark;
  final Color textColor;
  final Color subColor;

  const _SessionRow({
    required this.session,
    required this.boards,
    required this.isDark,
    required this.textColor,
    required this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    final cond = session.conditions;
    final board = session.boardId != null
        ? boards.where((b) => b.id == session.boardId).firstOrNull
        : null;

    final scoreColor = cond?.matchScore != null
        ? _sessionScoreColor(cond!.matchScore!)
        : subColor;
    final label = cond?.matchScore != null
        ? getConditionLabel(cond!.matchScore!).label
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s2),
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: isDark ? AppColorsDark.bgSecondary : AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${formatDate('${session.date}T00:00:00')} \u00b7 ${session.locationId}',
                  style: TextStyle(
                    fontSize: AppTypography.textSm,
                    fontWeight: AppTypography.weightSemibold,
                    color: textColor,
                  ),
                ),
              ),
              if (label.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: AppTypography.textXxs,
                      fontWeight: AppTypography.weightMedium,
                      color: scoreColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s1),
          Row(
            children: [
              if (cond?.waveHeight != null)
                Text(
                  '${formatWaveHeight(cond!.waveHeight)}ft',
                  style: TextStyle(
                    fontSize: AppTypography.textXs,
                    color: subColor,
                  ),
                ),
              if (cond?.windSpeed != null)
                Text(
                  ' \u00b7 ${formatWindSpeed(cond!.windSpeed)}mph',
                  style: TextStyle(
                    fontSize: AppTypography.textXs,
                    color: subColor,
                  ),
                ),
              if (board != null)
                Text(
                  ' \u00b7 ${board.name}',
                  style: TextStyle(
                    fontSize: AppTypography.textXs,
                    color: subColor,
                  ),
                ),
            ],
          ),
          if (session.tags != null && (session.tags as List).isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s1),
            Wrap(
              spacing: AppSpacing.s1,
              children: (session.tags as List<String>).map((t) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.accentBg,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      t,
                      style: TextStyle(fontSize: 9, color: AppColors.accent),
                    ),
                  )).toList(),
            ),
          ],
          if (session.rating != null) ...[
            const SizedBox(height: AppSpacing.s1),
            StarRating(rating: session.rating!, size: AppIconSize.base),
          ],
        ],
      ),
    );
  }
}

Color _sessionScoreColor(double score) {
  if (score >= 0.8) return AppColors.conditionEpic;
  if (score >= 0.6) return AppColors.conditionGood;
  if (score >= 0.4) return AppColors.conditionFair;
  return AppColors.conditionPoor;
}
