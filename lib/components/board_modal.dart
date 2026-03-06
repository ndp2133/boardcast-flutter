import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/tokens.dart';
import '../models/board.dart';
import '../logic/board_recommendation.dart';
import '../state/boards_provider.dart';

void showBoardModal(BuildContext context, WidgetRef ref, {Board? existing}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (_) => _BoardModalSheet(ref: ref, existing: existing),
  );
}

class _BoardModalSheet extends StatefulWidget {
  final WidgetRef ref;
  final Board? existing;
  const _BoardModalSheet({required this.ref, this.existing});

  @override
  State<_BoardModalSheet> createState() => _BoardModalSheetState();
}

class _BoardModalSheetState extends State<_BoardModalSheet> {
  String? _type;
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _type = widget.existing!.type;
      _nameController.text = widget.existing!.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _hasUnsavedChanges {
    if (widget.existing != null) {
      return _type != widget.existing!.type ||
          _nameController.text != widget.existing!.name;
    }
    return _type != null || _nameController.text.isNotEmpty;
  }

  void _showDiscardDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Keep Editing'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final isEdit = widget.existing != null;

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _showDiscardDialog();
      },
      child: SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.s4,
          AppSpacing.s4,
          AppSpacing.s4,
          MediaQuery.of(context).viewInsets.bottom + AppSpacing.s6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColorsDark.bgSurface : AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              isEdit ? 'Edit Board' : 'Add Board',
              style: TextStyle(
                fontSize: AppTypography.textLg,
                fontWeight: AppTypography.weightSemibold,
                color: textColor,
              ),
            ),
            const SizedBox(height: AppSpacing.s4),

            // Board type grid
            Wrap(
              spacing: AppSpacing.s2,
              runSpacing: AppSpacing.s2,
              children: boardTypes.map((bt) {
                final selected = _type == bt.id;
                return Semantics(
                  label: '${bt.name}: ${bt.bestFor}',
                  selected: selected,
                  button: true,
                  child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _type = bt.id);
                  },
                  child: AnimatedContainer(
                    duration: AppDurations.fast,
                    curve: Curves.easeOut,
                    width: (MediaQuery.of(context).size.width - 48) / 3,
                    padding: const EdgeInsets.all(AppSpacing.s2),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColorsDark.bgSecondary
                          : AppColors.bgSecondary,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: selected
                            ? AppColors.accent
                            : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: selected
                          ? [BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.25),
                              blurRadius: 8,
                              spreadRadius: 1,
                            )]
                          : null,
                    ),
                    child: Column(
                      children: [
                        Text(
                          bt.name,
                          style: TextStyle(
                            fontSize: AppTypography.textXs,
                            fontWeight: AppTypography.weightSemibold,
                            color: selected ? AppColors.accent : textColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          bt.bestFor,
                          style: TextStyle(
                            fontSize: 9,
                            color: isDark
                                ? AppColorsDark.textTertiary
                                : AppColors.textTertiary,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.s4),

            // Name field
            TextField(
              controller: _nameController,
              maxLength: 50,
              decoration: InputDecoration(
                labelText: 'Board name (optional)',
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s5),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _type != null ? _save : null,
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  void _save() {
    final name = _nameController.text.isNotEmpty
        ? _nameController.text
        : boardTypes.firstWhere((bt) => bt.id == _type).name;

    if (widget.existing != null) {
      widget.ref.read(boardsProvider.notifier).update(
            widget.existing!.id,
            widget.existing!.copyWith(type: _type!, name: name),
          );
    } else {
      widget.ref.read(boardsProvider.notifier).add(Board(
            id: 'board_${DateTime.now().millisecondsSinceEpoch}',
            name: name,
            type: _type!,
          ));
    }
    Navigator.pop(context);
  }
}
