import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/tokens.dart';
import '../models/session.dart';
import '../models/hourly_data.dart';
import '../models/merged_conditions.dart';
import '../logic/scoring.dart';
import '../logic/units.dart';
import '../logic/time_utils.dart';
import '../state/conditions_provider.dart';
import '../state/location_provider.dart';
import '../state/preferences_provider.dart';
import '../state/sessions_provider.dart';
import '../components/completion_modal.dart';
import '../components/empty_state.dart';
import '../components/discovery_hint.dart';
import '../state/store_provider.dart';
import '../components/shimmer.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  late String _selectedDate;
  final _selectedHours = <int>{};
  late Set<String> _seenHints;
  final _dateChipController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now().toIso8601String().split('T')[0];
    _seenHints = ref.read(storeServiceProvider).getSeenHints();
  }

  @override
  void dispose() {
    _dateChipController.dispose();
    super.dispose();
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
      body: Stack(
        children: [
          RefreshIndicator(
            color: AppColors.accent,
            onRefresh: () async {
              HapticFeedback.mediumImpact();
              ref.invalidate(conditionsProvider);
              ref.invalidate(sessionsProvider);
              await ref.read(conditionsProvider.future);
            },
            child: ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.s4, 0, AppSpacing.s4,
              _selectedHours.isNotEmpty ? 80 : AppSpacing.s8,
            ),
            children: [
              // Best window hero — guidance before the grid
              conditionsAsync.whenOrNull(
                data: (data) {
                  final bestWindow = findBestWindow(data.hourly, prefs, location);
                  if (bestWindow == null) return const SizedBox.shrink();
                  final label = getConditionLabel(bestWindow.avgScore);
                  final color = _scoreColor(bestWindow.avgScore);
                  final dayLabel = isToday(bestWindow.date)
                      ? 'Today'
                      : formatDayShort(bestWindow.date);
                  final waveText = bestWindow.waveHeight != null
                      ? '${formatWaveHeight(bestWindow.waveHeight)} ft'
                      : '';
                  return GestureDetector(
                    onTap: () => _selectDate(bestWindow.date),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.s4),
                      padding: const EdgeInsets.all(AppSpacing.s4),
                      decoration: BoxDecoration(
                        color: Color.lerp(
                          isDark ? AppColorsDark.bgSecondary : AppColors.bgSecondary,
                          color,
                          isDark ? 0.12 : 0.08,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.15),
                            blurRadius: 16,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.star, color: color, size: 24),
                          const SizedBox(width: AppSpacing.s3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Best window this week',
                                  style: TextStyle(
                                    fontSize: AppTypography.textXs,
                                    fontWeight: AppTypography.weightMedium,
                                    color: isDark ? AppColorsDark.textSecondary : AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$dayLabel ${formatHour(bestWindow.startTime)} – ${formatHour(bestWindow.endTime)}${waveText.isNotEmpty ? ' · $waveText' : ''}',
                                  style: TextStyle(
                                    fontSize: AppTypography.textBase,
                                    fontWeight: AppTypography.weightBold,
                                    color: isDark ? AppColorsDark.textPrimary : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              label.label,
                              style: TextStyle(
                                fontSize: AppTypography.textXs,
                                fontWeight: AppTypography.weightSemibold,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ) ?? const SizedBox.shrink(),

              // Discovery hint
              DiscoveryHint(
                id: 'sessions_plan',
                message: 'Tap hours to plan your session. Boardcast tracks conditions so you can review later.',
                icon: Icons.calendar_today,
                seenHints: _seenHints,
                onDismiss: (id) {
                  _seenHints.add(id);
                  ref.read(storeServiceProvider).markHintSeen(id);
                },
              ),

              // Date chips
              _buildDateChips(isDark, textColor, conditionsAsync.valueOrNull),
              const SizedBox(height: AppSpacing.s4),

              // Hour grid
              conditionsAsync.when(
                loading: () => _buildHourGridSkeleton(isDark),
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
                    return const EmptyState(
                      icon: Icons.cloud_off_outlined,
                      title: 'No forecast available',
                      subtitle: 'Conditions data isn\'t available this far out. Try a closer date.',
                    );
                  }

                  // Check if any hour is Good+ for empty state guidance
                  double bestDayScore = 0;
                  for (final h in dayHours) {
                    final s = computeMatchScore(h, prefs, location);
                    if (s > bestDayScore) bestDayScore = s;
                  }

                  // Find a better day to suggest
                  String? betterDaySuggestion;
                  if (bestDayScore < 0.5) {
                    final now = DateTime.now();
                    for (var d = 1; d <= 6; d++) {
                      final checkDate = now.add(Duration(days: d));
                      final checkDateStr =
                          '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
                      if (checkDateStr == _selectedDate) continue;
                      final checkHours = data.hourly.where((h) => h.time.startsWith(checkDateStr)).toList();
                      for (final h in checkHours) {
                        final s = computeMatchScore(h, prefs, location);
                        if (s >= 0.6) {
                          betterDaySuggestion = formatDayShort(checkDateStr);
                          break;
                        }
                      }
                      if (betterDaySuggestion != null) break;
                    }
                  }

                  return Column(
                    children: [
                      _buildTimeBlockedHours(
                          dayHours, prefs, location, isDark, textColor, subColor),
                      // Empty state guidance for poor days
                      if (bestDayScore < 0.5 && betterDaySuggestion != null)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.s3),
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.s3),
                            decoration: BoxDecoration(
                              color: isDark ? AppColorsDark.bgSecondary : AppColors.bgSecondary,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.wb_sunny_outlined, size: 20, color: AppColors.conditionFair),
                                const SizedBox(width: AppSpacing.s3),
                                Expanded(
                                  child: Text(
                                    'Not a great day — $betterDaySuggestion looks much better',
                                    style: TextStyle(
                                      fontSize: AppTypography.textSm,
                                      color: subColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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

              const SizedBox(height: AppSpacing.s4),
            ],
          ),
          ),
          // Floating selection summary + save button (P3 + P6)
          if (_selectedHours.isNotEmpty)
            Positioned(
              left: AppSpacing.s4,
              right: AppSpacing.s4,
              bottom: MediaQuery.of(context).padding.bottom + AppSpacing.s3,
              child: _buildFloatingBar(isDark, conditionsAsync),
            ),
        ],
      ),
    );
  }

  void _selectDate(String dateStr) {
    setState(() {
      _selectedDate = dateStr;
      _selectedHours.clear();
    });
    // Auto-scroll date chips to center the selected date (P7)
    final now = DateTime.now();
    final selected = DateTime.parse(dateStr);
    final dayIndex = selected.difference(DateTime(now.year, now.month, now.day)).inDays;
    if (dayIndex >= 0 && dayIndex < 7) {
      final chipWidth = 52.0 + AppSpacing.s2; // chip width + margin
      final viewportWidth = MediaQuery.of(context).size.width - AppSpacing.s4 * 2;
      final targetOffset = (dayIndex * chipWidth - (viewportWidth - chipWidth) / 2)
          .clamp(0.0, (7 * chipWidth - viewportWidth).clamp(0.0, double.infinity));
      _dateChipController.animateTo(
        targetOffset,
        duration: AppDurations.slow,
        curve: Curves.easeOut,
      );
    }
  }

  Widget _buildFloatingBar(bool isDark, AsyncValue<MergedConditions> conditionsAsync) {
    final sorted = _selectedHours.toList()..sort();
    final timeLabel = sorted.length == 1
        ? formatHour('2000-01-01T${sorted.first.toString().padLeft(2, '0')}:00')
        : '${formatHour('2000-01-01T${sorted.first.toString().padLeft(2, '0')}:00')} – ${formatHour('2000-01-01T${sorted.last.toString().padLeft(2, '0')}:00')}';

    return AnimatedSize(
      duration: AppDurations.base,
      curve: Curves.easeOut,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4, vertical: AppSpacing.s3),
        decoration: BoxDecoration(
          color: isDark ? AppColorsDark.bgSecondary : AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.lg,
          border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_selectedHours.length} ${_selectedHours.length == 1 ? "hour" : "hours"} selected',
                    style: TextStyle(
                      fontSize: AppTypography.textSm,
                      fontWeight: AppTypography.weightSemibold,
                      color: isDark ? AppColorsDark.textPrimary : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    timeLabel,
                    style: TextStyle(
                      fontSize: AppTypography.textXs,
                      color: isDark ? AppColorsDark.textSecondary : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final data = conditionsAsync.valueOrNull;
                if (data == null) return;
                final dayHours = data.hourly
                    .where((h) => h.time.startsWith(_selectedDate))
                    .where((h) {
                  final hour = int.parse(h.time.split('T')[1].split(':')[0]);
                  return hour >= 6 && hour <= 20;
                }).toList();
                _saveSession(dayHours);
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4, vertical: AppSpacing.s3),
              ),
              child: const Text('Save Plan'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateChips(bool isDark, Color textColor, MergedConditions? data) {
    final now = DateTime.now();
    final prefs = ref.read(preferencesProvider);
    final location = ref.read(selectedLocationProvider);

    return SizedBox(
      height: 62,
      child: ListView.builder(
        controller: _dateChipController,
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        itemBuilder: (context, i) {
          final date = now.add(Duration(days: i));
          final dateStr =
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          final isSelected = dateStr == _selectedDate;
          final dayLabel = i == 0 ? 'TODAY' : formatDayShort(dateStr);

          // Compute best score for this day for condition dot
          Color? condDot;
          if (data != null) {
            final dayHours = data.hourly.where((h) => h.time.startsWith(dateStr)).toList();
            if (dayHours.isNotEmpty) {
              double bestScore = 0;
              for (final h in dayHours) {
                final s = computeMatchScore(h, prefs, location);
                if (s > bestScore) bestScore = s;
              }
              condDot = _scoreColor(bestScore);
            }
          }

          return GestureDetector(
            onTap: () => _selectDate(dateStr),
            child: Container(
              width: 52,
              margin: const EdgeInsets.only(right: AppSpacing.s2),
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
                      fontSize: AppTypography.textXxs,
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
                  const SizedBox(height: 3),
                  // Condition quality dot
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.8)
                          : (condDot ?? Colors.transparent),
                      shape: BoxShape.circle,
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

  Widget _buildTimeBlockedHours(List<HourlyData> dayHours, prefs, location,
      bool isDark, Color textColor, Color subColor) {
    const blocks = [
      ('Dawn Patrol', 6, 7),
      ('Morning', 8, 10),
      ('Midday', 11, 13),
      ('Afternoon', 14, 16),
      ('Evening', 17, 20),
    ];
    final widgets = <Widget>[];
    for (final (name, startHour, endHour) in blocks) {
      final blockHours = dayHours.where((h) {
        final hour = int.parse(h.time.split('T')[1].split(':')[0]);
        return hour >= startHour && hour <= endHour;
      }).toList();
      if (blockHours.isEmpty) continue;

      double bestScore = 0;
      for (final h in blockHours) {
        final s = computeMatchScore(h, prefs, location);
        if (s > bestScore) bestScore = s;
      }
      final color = _scoreColor(bestScore);

      widgets.add(Padding(
        padding: EdgeInsets.only(
          top: widgets.isEmpty ? 0 : AppSpacing.s3,
          bottom: AppSpacing.s1,
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              name,
              style: TextStyle(
                fontSize: AppTypography.textXs,
                fontWeight: AppTypography.weightSemibold,
                color: textColor,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                getConditionLabel(bestScore).label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: AppTypography.weightMedium,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ));

      for (final h in blockHours) {
        widgets.add(
          _buildHourTile(h, prefs, location, isDark, textColor, subColor),
        );
      }
    }
    return Column(children: widgets);
  }

  Widget _buildHourTile(HourlyData h, prefs, location, bool isDark,
      Color textColor, Color subColor) {
    final hour = int.parse(h.time.split('T')[1].split(':')[0]);
    final isSelected = _selectedHours.contains(hour);
    final score = computeMatchScore(h, prefs, location);
    final label = getConditionLabel(score);
    final dotColor = _scoreColor(score);

    return GestureDetector(
      onTap: () {
        // Condition-aware haptic — feel that the hour is good
        AppHaptics.forScore(score);
        setState(() {
          if (isSelected) {
            _selectedHours.remove(hour);
          } else {
            _selectedHours.add(hour);
          }
        });
      },
      child: AnimatedContainer(
        duration: AppDurations.fast,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s3,
          vertical: AppSpacing.s2,
        ),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: isSelected
              ? Color.lerp(AppColors.accent.withValues(alpha: 0.08), dotColor, 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: isSelected
              ? Border.all(color: dotColor.withValues(alpha: 0.4), width: 1.5)
              : null,
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
            const SizedBox(width: AppSpacing.s2),
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
                fontSize: AppTypography.textXxs,
                fontWeight: AppTypography.weightMedium,
                color: dotColor,
              ),
            ),
            AnimatedOpacity(
              opacity: isSelected ? 1.0 : 0.0,
              duration: AppDurations.fast,
              child: AnimatedScale(
                scale: isSelected ? 1.0 : 0.5,
                duration: AppDurations.fast,
                curve: Curves.easeOutBack,
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(Icons.check, size: AppIconSize.base, color: AppColors.accent),
                ),
              ),
            ),
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
            const SizedBox(height: AppSpacing.s1),
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
                  icon: const Icon(Icons.check, size: AppIconSize.base),
                  label: const Text('Complete'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              TextButton.icon(
                onPressed: () =>
                    ref.read(sessionsProvider.notifier).delete(s.id),
                icon: Icon(Icons.delete_outline,
                    size: AppIconSize.base, color: AppColors.conditionPoor),
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

  Widget _buildHourGridSkeleton(bool isDark) {
    return Shimmer(
      child: Column(
        children: List.generate(6, (_) => const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.s2),
          child: ShimmerBox(height: 48, radius: AppRadius.sm),
        )),
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
