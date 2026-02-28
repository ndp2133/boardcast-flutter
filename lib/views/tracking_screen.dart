import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/tokens.dart';
import '../models/session.dart';
import '../models/hourly_data.dart';
import '../logic/scoring.dart';
import '../logic/units.dart';
import '../logic/time_utils.dart';
import '../state/conditions_provider.dart';
import '../state/location_provider.dart';
import '../state/preferences_provider.dart';
import '../state/sessions_provider.dart';
import '../components/completion_modal.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  late String _selectedDate;
  final _selectedHours = <int>{};

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now().toIso8601String().split('T')[0];
  }

  @override
  Widget build(BuildContext context) {
    final conditionsAsync = ref.watch(conditionsProvider);
    final location = ref.watch(selectedLocationProvider);
    final prefs = ref.watch(preferencesProvider);
    final sessions = ref.watch(sessionsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final subColor =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;

    final planned =
        sessions.where((s) => s.status == 'planned').toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    return Scaffold(
      backgroundColor: isDark ? AppColorsDark.bgPrimary : AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor:
            isDark ? AppColorsDark.bgPrimary : AppColors.bgPrimary,
        elevation: 0,
        title: Text(
          'Plan a Session',
          style: TextStyle(
            fontSize: AppTypography.textBase,
            fontWeight: AppTypography.weightSemibold,
            color: textColor,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
        children: [
          // Date chips
          _buildDateChips(isDark, textColor),
          const SizedBox(height: AppSpacing.s4),

          // Hour grid
          conditionsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
            error: (_, __) => Center(
              child: Column(
                children: [
                  Text('No conditions data',
                      style: TextStyle(color: subColor)),
                  TextButton(
                    onPressed: () => ref.invalidate(conditionsProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            data: (data) {
              final dayHours = data.hourly
                  .where((h) => h.time.startsWith(_selectedDate))
                  .where((h) {
                final hour = int.parse(h.time.split('T')[1].split(':')[0]);
                return hour >= 6 && hour <= 20;
              }).toList();

              if (dayHours.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.s8),
                  child: Text(
                    'No forecast data for this day.',
                    style: TextStyle(color: subColor),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return Column(
                children: [
                  ...dayHours.map((h) => _buildHourTile(
                        h, prefs, location, isDark, textColor, subColor)),
                  if (_selectedHours.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.s4),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _saveSession(dayHours),
                        child: Text(
                          'Save Session Plan (${_selectedHours.length} ${_selectedHours.length == 1 ? "hour" : "hours"})',
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),

          // Upcoming sessions
          if (planned.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s6),
            Text(
              'Upcoming Sessions',
              style: TextStyle(
                fontSize: AppTypography.textSm,
                fontWeight: AppTypography.weightSemibold,
                color: textColor,
              ),
            ),
            const SizedBox(height: AppSpacing.s2),
            ...planned.map((s) =>
                _buildSessionCard(s, isDark, textColor, subColor)),
          ],

          const SizedBox(height: AppSpacing.s8),
        ],
      ),
    );
  }

  Widget _buildDateChips(bool isDark, Color textColor) {
    final now = DateTime.now();
    return SizedBox(
      height: 56,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        itemBuilder: (context, i) {
          final date = now.add(Duration(days: i));
          final dateStr =
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          final isSelected = dateStr == _selectedDate;
          final dayLabel = i == 0 ? 'TODAY' : formatDayShort(dateStr);

          return GestureDetector(
            onTap: () => setState(() {
              _selectedDate = dateStr;
              _selectedHours.clear();
            }),
            child: Container(
              width: 52,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.accent
                    : (isDark
                        ? AppColorsDark.bgSecondary
                        : AppColors.bgSecondary),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: AppTypography.weightSemibold,
                      color: isSelected ? Colors.white : textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: AppTypography.textLg,
                      fontWeight: AppTypography.weightBold,
                      color: isSelected ? Colors.white : textColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHourTile(HourlyData h, prefs, location, bool isDark,
      Color textColor, Color subColor) {
    final hour = int.parse(h.time.split('T')[1].split(':')[0]);
    final isSelected = _selectedHours.contains(hour);
    final score = computeMatchScore(h, prefs, location);
    final label = getConditionLabel(score);
    final dotColor = _scoreColor(score);

    return GestureDetector(
      onTap: () => setState(() {
        if (isSelected) {
          _selectedHours.remove(hour);
        } else {
          _selectedHours.add(hour);
        }
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s3,
          vertical: AppSpacing.s2,
        ),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Text(
                formatHour(h.time),
                style: TextStyle(
                  fontFamily: AppTypography.fontMono,
                  fontSize: AppTypography.textSm,
                  color: textColor,
                ),
              ),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${formatWaveHeight(h.waveHeight)} ft · ${formatWindSpeed(h.windSpeed)} mph${h.windDirection != null ? ' ${degreesToCardinal(h.windDirection!)}' : ''}',
                style: TextStyle(
                  fontSize: AppTypography.textXs,
                  color: subColor,
                ),
              ),
            ),
            Text(
              label.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: AppTypography.weightMedium,
                color: dotColor,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Icon(Icons.check, size: 16, color: AppColors.accent),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(
      Session s, bool isDark, Color textColor, Color subColor) {
    final hoursText = s.selectedHours != null
        ? s.selectedHours!.map((h) => formatHour(
              '${s.date}T${h.toString().padLeft(2, '0')}:00',
            )).join(', ')
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
                  '${isToday(s.date) ? "Today" : formatDate('${s.date}T00:00:00')} · ${s.locationId}',
                  style: TextStyle(
                    fontSize: AppTypography.textSm,
                    fontWeight: AppTypography.weightSemibold,
                    color: textColor,
                  ),
                ),
              ),
              Text(
                getRelativeTime('${s.date}T${(s.selectedHours?.first ?? 8).toString().padLeft(2, '0')}:00:00'),
                style: TextStyle(
                  fontSize: AppTypography.textXs,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          if (hoursText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              hoursText,
              style: TextStyle(
                fontSize: AppTypography.textXs,
                color: subColor,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.s2),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () =>
                      showCompletionModal(context, ref, s),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Complete'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () =>
                    ref.read(sessionsProvider.notifier).delete(s.id),
                icon: Icon(Icons.delete_outline,
                    size: 16, color: AppColors.conditionPoor),
                label: Text('Cancel',
                    style: TextStyle(color: AppColors.conditionPoor)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _saveSession(List<HourlyData> dayHours) {
    final locationId = ref.read(selectedLocationIdProvider);
    final prefs = ref.read(preferencesProvider);
    final location = ref.read(selectedLocationProvider);

    // Get conditions from first selected hour
    final firstHour = _selectedHours.toList()..sort();
    HourlyData? firstHourData;
    for (final h in dayHours) {
      final hour = int.parse(h.time.split('T')[1].split(':')[0]);
      if (hour == firstHour.first) {
        firstHourData = h;
        break;
      }
    }

    final score = firstHourData != null
        ? computeMatchScore(firstHourData, prefs, location)
        : null;

    final session = Session(
      id: 'sess_${DateTime.now().millisecondsSinceEpoch}',
      locationId: locationId,
      date: _selectedDate,
      status: 'planned',
      selectedHours: firstHour,
      conditions: firstHourData != null
          ? SessionConditions(
              waveHeight: firstHourData.waveHeight,
              windSpeed: firstHourData.windSpeed,
              windDirection: firstHourData.windDirection,
              swellDirection: firstHourData.swellDirection,
              swellPeriod: firstHourData.swellPeriod,
              matchScore: score,
            )
          : null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    ref.read(sessionsProvider.notifier).add(session);
    setState(() => _selectedHours.clear());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Session planned!'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

Color _scoreColor(double score) {
  if (score >= 0.8) return AppColors.conditionEpic;
  if (score >= 0.6) return AppColors.conditionGood;
  if (score >= 0.4) return AppColors.conditionFair;
  return AppColors.conditionPoor;
}
