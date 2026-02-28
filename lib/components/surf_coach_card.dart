/// AI Surf Coach card — personalized tips + natural language queries
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/tokens.dart';
import '../state/ai_provider.dart';

class SurfCoachCard extends ConsumerStatefulWidget {
  const SurfCoachCard({super.key});

  @override
  ConsumerState<SurfCoachCard> createState() => _SurfCoachCardState();
}

class _SurfCoachCardState extends ConsumerState<SurfCoachCard> {
  final _queryController = TextEditingController();
  bool _hasRequestedTip = false;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _onGetTip() {
    setState(() => _hasRequestedTip = true);
    ref.read(surfTipProvider.notifier).fetchTip();
  }

  void _onSubmitQuery() {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;
    ref.read(surfQueryProvider.notifier).submitQuery(query);
    _queryController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColorsDark.bgSecondary : AppColors.bgSecondary;
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final subColor =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;

    final tipState = ref.watch(surfTipProvider);
    final queryState = ref.watch(surfQueryProvider);

    // Show the most recent response (query takes priority if loaded)
    final displayState =
        queryState.status != AiStatus.idle ? queryState : tipState;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.waves, size: 18, color: AppColors.accent),
              const SizedBox(width: AppSpacing.s2),
              Text(
                'AI Surf Coach',
                style: TextStyle(
                  fontSize: AppTypography.textSm,
                  fontWeight: AppTypography.weightSemibold,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),

          // Response body
          _buildBody(displayState, textColor, subColor),
          const SizedBox(height: AppSpacing.s3),

          // Get Surf Tip button
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed:
                  displayState.status == AiStatus.loading ? null : _onGetTip,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: AppSpacing.s2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              child: Text(
                displayState.status == AiStatus.loading
                    ? 'Thinking...'
                    : _hasRequestedTip
                        ? 'New Tip'
                        : 'Get Surf Tip',
                style: const TextStyle(
                  fontSize: AppTypography.textSm,
                  fontWeight: AppTypography.weightMedium,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s3),

          // Query input row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _queryController,
                  maxLength: 200,
                  enabled: displayState.status != AiStatus.loading,
                  style: TextStyle(
                    fontSize: AppTypography.textSm,
                    color: textColor,
                  ),
                  decoration: InputDecoration(
                    hintText: 'When should I surf tomorrow?',
                    hintStyle: TextStyle(
                      fontSize: AppTypography.textSm,
                      color: subColor,
                    ),
                    counterText: '',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s3,
                      vertical: AppSpacing.s2,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? AppColorsDark.bgTertiary
                        : AppColors.bgTertiary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _onSubmitQuery(),
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              TextButton(
                onPressed: displayState.status == AiStatus.loading
                    ? null
                    : _onSubmitQuery,
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(48, 36),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
                child: const Text(
                  'Ask',
                  style: TextStyle(
                    fontSize: AppTypography.textSm,
                    fontWeight: AppTypography.weightMedium,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AiState displayState, Color textColor, Color subColor) {
    switch (displayState.status) {
      case AiStatus.idle:
        return Text(
          'Tap below for a personalized surf tip, or ask a question about conditions.',
          style: TextStyle(
            fontSize: AppTypography.textSm,
            color: subColor,
            height: 1.4,
          ),
        );
      case AiStatus.loading:
        return Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: AppSpacing.s2),
            Expanded(
              child: Text(
                displayState.text ?? 'Analyzing conditions...',
                style: TextStyle(
                  fontSize: AppTypography.textSm,
                  color: subColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        );
      case AiStatus.loaded:
        return Text(
          displayState.text ?? '',
          style: TextStyle(
            fontSize: AppTypography.textSm,
            color: textColor,
            height: 1.5,
          ),
        );
      case AiStatus.error:
        return Text(
          displayState.error ?? 'Something went wrong.',
          style: TextStyle(
            fontSize: AppTypography.textSm,
            color: AppColors.conditionPoor,
            height: 1.4,
          ),
        );
    }
  }
}
