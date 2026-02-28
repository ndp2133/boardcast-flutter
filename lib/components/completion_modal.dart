import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/tokens.dart';
import '../models/session.dart';
import '../logic/surf_iq.dart';
import '../logic/units.dart';
import '../state/sessions_provider.dart';
import '../state/boards_provider.dart';
import '../state/preferences_provider.dart';
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
    final nudge = nudgeResult?.message;

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

              // Nudge
              if (nudge != null)
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
                          nudge,
                          style: TextStyle(
                            fontSize: AppTypography.textXs,
                            color: textColor,
                          ),
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

  void _save() {
    final updated = widget.session.copyWith(
      status: 'completed',
      rating: _rating > 0 ? _rating : null,
      calibration: _calibration,
      boardId: _boardId,
      tags: _selectedTags.isNotEmpty ? _selectedTags.toList() : null,
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
    );
    widget.ref.read(sessionsProvider.notifier).update(widget.session.id, updated);
    Navigator.pop(context);
  }
}
