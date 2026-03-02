import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/tokens.dart';
import '../models/session.dart';
import '../models/user_prefs.dart';
import '../logic/surf_iq.dart';
import '../logic/units.dart';
import '../state/sessions_provider.dart';
import '../state/boards_provider.dart';
import '../state/preferences_provider.dart';
import '../state/conditions_provider.dart';
import 'star_rating.dart';

void showCompletionModal(BuildContext context, WidgetRef ref, Session session) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (_) => _CompletionSheet(ref: ref, session: session),
  );
}

class _CompletionSheet extends StatefulWidget {
  final WidgetRef ref;
  final Session session;
  const _CompletionSheet({required this.ref, required this.session});

  @override
  State<_CompletionSheet> createState() => _CompletionSheetState();
}

class _CompletionSheetState extends State<_CompletionSheet> {
  int _rating = 0;
  int? _calibration;
  String? _boardId;
  bool _nudgeApplied = false;
  final _selectedTags = <String>{};
  final _notesController = TextEditingController();

  static const _tagOptions = [
    'Great waves',
    'Clean wind',
    'Good tide',
    'Not crowded',
    'Fun session',
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final subColor =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;
    final boards = widget.ref.read(boardsProvider);

    // Conditions summary
    final cond = widget.session.conditions;

    // Nudge
    final sessions = widget.ref.read(sessionsProvider);
    final prefs = widget.ref.read(preferencesProvider);
    final nudgeResult = generateNudge(sessions, prefs);

    // Forecast vs Actual comparison
    final forecastComparison = _computeForecastComparison();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.s4, AppSpacing.s4, AppSpacing.s4, AppSpacing.s8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color:
                        isDark ? AppColorsDark.bgSurface : AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                'Complete Session',
                style: TextStyle(
                  fontSize: AppTypography.textLg,
                  fontWeight: AppTypography.weightSemibold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: AppSpacing.s2),

              // Conditions summary
              if (cond != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s4),
                  child: Row(
                    children: [
                      if (cond.waveHeight != null)
                        _infoChip(
                            '${formatWaveHeight(cond.waveHeight)} ft waves',
                            subColor),
                      if (cond.windSpeed != null) ...[
                        const SizedBox(width: 8),
                        _infoChip(
                            '${formatWindSpeed(cond.windSpeed)} mph wind',
                            subColor),
                      ],
                    ],
                  ),
                ),

              // Star rating
              Text('How was it?',
                  style: TextStyle(
                    fontSize: AppTypography.textSm,
                    fontWeight: AppTypography.weightMedium,
                    color: textColor,
                  )),
              const SizedBox(height: AppSpacing.s2),
              Center(
                child: StarRating(
                  rating: _rating,
                  size: 36,
                  onChanged: (r) => setState(() => _rating = r),
                ),
              ),
              const SizedBox(height: AppSpacing.s5),

              // Calibration
              Text('Forecast accuracy',
                  style: TextStyle(
                    fontSize: AppTypography.textSm,
                    fontWeight: AppTypography.weightMedium,
                    color: textColor,
                  )),
              const SizedBox(height: AppSpacing.s2),
              Row(
                children: [
                  _calibrationButton('Worse', -1, '\u{1F44E}'),
                  const SizedBox(width: 8),
                  _calibrationButton('About right', 0, '\u{1F44C}'),
                  const SizedBox(width: 8),
                  _calibrationButton('Better', 1, '\u{1F919}'),
                ],
              ),
              const SizedBox(height: AppSpacing.s5),

              // Forecast vs Actual
              if (forecastComparison != null)
                _buildForecastComparison(forecastComparison, textColor, subColor),

              // Board picker
              if (boards.isNotEmpty) ...[
                Text('Board used',
                    style: TextStyle(
                      fontSize: AppTypography.textSm,
                      fontWeight: AppTypography.weightMedium,
                      color: textColor,
                    )),
                const SizedBox(height: AppSpacing.s2),
                Wrap(
                  spacing: 8,
                  children: boards.map((b) {
                    final selected = b.id == _boardId;
                    return ChoiceChip(
                      label: Text(b.name),
                      selected: selected,
                      onSelected: (_) => setState(
                          () => _boardId = selected ? null : b.id),
                      selectedColor: AppColors.accentBgStrong,
                      labelStyle: TextStyle(
                        color: selected ? AppColors.accent : textColor,
                        fontSize: AppTypography.textSm,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.s5),
              ],

              // Tags
              Text('Tags',
                  style: TextStyle(
                    fontSize: AppTypography.textSm,
                    fontWeight: AppTypography.weightMedium,
                    color: textColor,
                  )),
              const SizedBox(height: AppSpacing.s2),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _tagOptions.map((tag) {
                  final selected = _selectedTags.contains(tag);
                  return FilterChip(
                    label: Text(tag),
                    selected: selected,
                    onSelected: (v) => setState(() {
                      if (v) {
                        _selectedTags.add(tag);
                      } else {
                        _selectedTags.remove(tag);
                      }
                    }),
                    selectedColor: AppColors.accentBgStrong,
                    labelStyle: TextStyle(
                      color: selected ? AppColors.accent : textColor,
                      fontSize: AppTypography.textSm,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.s5),

              // Notes
              Text('Notes',
                  style: TextStyle(
                    fontSize: AppTypography.textSm,
                    fontWeight: AppTypography.weightMedium,
                    color: textColor,
                  )),
              const SizedBox(height: AppSpacing.s2),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'How was your session?',
                  hintStyle: TextStyle(color: subColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s4),

              // Nudge with Apply button
              if (nudgeResult != null)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s3),
                  margin: const EdgeInsets.only(bottom: AppSpacing.s4),
                  decoration: BoxDecoration(
                    color: AppColors.accentBg,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    children: [
                      const Text('\u{1F4A1}', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          nudgeResult.message,
                          style: TextStyle(
                            fontSize: AppTypography.textXs,
                            color: textColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _nudgeApplied
                          ? Text(
                              'Applied',
                              style: TextStyle(
                                fontSize: AppTypography.textXs,
                                color: subColor,
                                fontWeight: AppTypography.weightMedium,
                              ),
                            )
                          : SizedBox(
                              height: 28,
                              child: TextButton(
                                onPressed: () => _applyNudge(nudgeResult, prefs),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.accent,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  textStyle: TextStyle(
                                    fontSize: AppTypography.textXs,
                                    fontWeight: AppTypography.weightSemibold,
                                  ),
                                ),
                                child: const Text('Apply'),
                              ),
                            ),
                    ],
                  ),
                ),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  child: const Text('Save Session'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _calibrationButton(String label, int value, String emoji) {
    final selected = _calibration == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _calibration = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
          decoration: BoxDecoration(
            color: selected ? AppColors.accentBgStrong : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.bgTertiary,
            ),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: selected
                      ? AppColors.accent
                      : AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(text, style: TextStyle(fontSize: AppTypography.textXs, color: color)),
    );
  }

  _ForecastComparison? _computeForecastComparison() {
    final cond = widget.session.conditions;
    if (cond == null || cond.waveHeight == null || cond.windSpeed == null) {
      return null;
    }

    final cached = widget.ref.read(cachedConditionsProvider);
    if (cached == null) return null;

    final sessionDate = widget.session.date;
    final selectedHours = widget.session.selectedHours;
    if (selectedHours == null || selectedHours.isEmpty) return null;

    final relevantHours = cached.hourly.where((h) {
      if (!h.time.startsWith(sessionDate)) return false;
      final hour = int.tryParse(h.time.split('T')[1].split(':')[0]) ?? -1;
      return selectedHours.contains(hour);
    }).toList();

    if (relevantHours.isEmpty) return null;

    final actualWaves = relevantHours
        .where((h) => h.waveHeight != null)
        .map((h) => h.waveHeight!)
        .toList();
    final actualWinds = relevantHours
        .where((h) => h.windSpeed != null)
        .map((h) => h.windSpeed!)
        .toList();

    if (actualWaves.isEmpty || actualWinds.isEmpty) return null;

    final actualWaveAvg = actualWaves.reduce((a, b) => a + b) / actualWaves.length;
    final actualWindAvg = actualWinds.reduce((a, b) => a + b) / actualWinds.length;

    double metricAccuracy(double forecast, double actual) {
      final mx = forecast > actual ? forecast : actual;
      if (mx == 0) return 1.0;
      return 1 - (forecast - actual).abs() / mx;
    }

    final waveAcc = metricAccuracy(cond.waveHeight!, actualWaveAvg);
    final windAcc = metricAccuracy(cond.windSpeed!, actualWindAvg);
    final overall = ((waveAcc + windAcc) / 2).clamp(0.0, 1.0);

    return _ForecastComparison(
      forecastWave: cond.waveHeight!,
      actualWave: actualWaveAvg,
      forecastWind: cond.windSpeed!,
      actualWind: actualWindAvg,
      accuracy: overall,
    );
  }

  Widget _buildForecastComparison(
      _ForecastComparison comp, Color textColor, Color subColor) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      margin: const EdgeInsets.only(bottom: AppSpacing.s5),
      decoration: BoxDecoration(
        color: subColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Forecast vs Actual',
            style: TextStyle(
              fontSize: AppTypography.textSm,
              fontWeight: AppTypography.weightMedium,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          _comparisonRow(
            'Waves',
            '${formatWaveHeight(comp.actualWave)} ft',
            'forecast ${formatWaveHeight(comp.forecastWave)} ft',
            subColor,
          ),
          const SizedBox(height: 4),
          _comparisonRow(
            'Wind',
            '${formatWindSpeed(comp.actualWind)} mph',
            'forecast ${formatWindSpeed(comp.forecastWind)} mph',
            subColor,
          ),
          const SizedBox(height: 8),
          Text(
            'Forecast accuracy: ${(comp.accuracy * 100).round()}%',
            style: TextStyle(
              fontSize: AppTypography.textXs,
              fontWeight: AppTypography.weightMedium,
              color: comp.accuracy >= 0.8
                  ? AppColors.conditionEpic
                  : comp.accuracy >= 0.6
                      ? AppColors.conditionFair
                      : AppColors.conditionPoor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _comparisonRow(
      String label, String actual, String forecast, Color subColor) {
    return Row(
      children: [
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: TextStyle(fontSize: AppTypography.textXs, color: subColor),
          ),
        ),
        Text(
          actual,
          style: TextStyle(
            fontSize: AppTypography.textXs,
            fontWeight: AppTypography.weightMedium,
            color: subColor,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'vs $forecast',
          style: TextStyle(fontSize: AppTypography.textXs, color: subColor.withValues(alpha: 0.6)),
        ),
      ],
    );
  }

  void _applyNudge(PreferenceNudge nudge, UserPrefs prefs) {
    UserPrefs newPrefs;
    switch (nudge.prefKey) {
      case 'minWaveHeight':
        newPrefs = prefs.copyWith(minWaveHeight: nudge.suggestedValue);
      case 'maxWaveHeight':
        newPrefs = prefs.copyWith(maxWaveHeight: nudge.suggestedValue);
      case 'maxWindSpeed':
        newPrefs = prefs.copyWith(maxWindSpeed: nudge.suggestedValue);
      default:
        return;
    }
    widget.ref.read(preferencesProvider.notifier).update(newPrefs);
    setState(() => _nudgeApplied = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${nudge.formatLabel} updated to ${nudge.suggestedValue}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _save() {
    // Store forecast accuracy if available
    final comparison = _computeForecastComparison();
    final conditions = comparison != null && widget.session.conditions != null
        ? widget.session.conditions!.copyWith(forecastAccuracy: comparison.accuracy)
        : widget.session.conditions;

    final updated = widget.session.copyWith(
      status: 'completed',
      rating: _rating > 0 ? _rating : null,
      calibration: _calibration,
      boardId: _boardId,
      tags: _selectedTags.isNotEmpty ? _selectedTags.toList() : null,
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      conditions: conditions,
    );
    widget.ref.read(sessionsProvider.notifier).update(widget.session.id, updated);
    Navigator.pop(context);
  }
}

class _ForecastComparison {
  final double forecastWave;
  final double actualWave;
  final double forecastWind;
  final double actualWind;
  final double accuracy;

  const _ForecastComparison({
    required this.forecastWave,
    required this.actualWave,
    required this.forecastWind,
    required this.actualWind,
    required this.accuracy,
  });
}
