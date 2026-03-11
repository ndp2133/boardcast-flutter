/// "The Call" — interactive AI Q&A for surf conditions.
/// "What's the call on tomorrow morning?"
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/tokens.dart';
import '../state/ai_provider.dart';
import '../state/subscription_provider.dart';
import '../components/paywall.dart';

class TheCallCard extends ConsumerStatefulWidget {
  const TheCallCard({super.key});

  @override
  ConsumerState<TheCallCard> createState() => _TheCallCardState();
}

class _TheCallCardState extends ConsumerState<TheCallCard> {
  final _queryController = TextEditingController();
  bool _hasAsked = false;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _onQuickCall() {
    if (!ref.read(isPremiumProvider)) {
      showPaywall(context);
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _hasAsked = true);
    ref.read(surfTipProvider.notifier).fetchTip();
  }

  void _onSubmitQuery([String? quickQuery]) {
    final query = quickQuery ?? _queryController.text.trim();
    if (query.isEmpty) return;
    if (!ref.read(isPremiumProvider)) {
      showPaywall(context);
      return;
    }
    HapticFeedback.lightImpact();
    setState(() => _hasAsked = true);
    ref.read(surfQueryProvider.notifier).submitQuery(query);
    _queryController.clear();
    FocusManager.instance.primaryFocus?.unfocus();
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
    final isLoading = displayState.status == AiStatus.loading;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.15),
        ),
        boxShadow: [
          ...AppShadows.base,
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.05),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(Icons.call_made,
                    size: 16, color: AppColors.accent),
              ),
              const SizedBox(width: AppSpacing.s2),
              Text(
                'The Call',
                style: TextStyle(
                  fontSize: AppTypography.textBase,
                  fontWeight: AppTypography.weightSemibold,
                  color: textColor,
                ),
              ),
              const Spacer(),
              if (displayState.status == AiStatus.loaded)
                Text(
                  '\u2726 AI',
                  style: TextStyle(
                    fontSize: AppTypography.textXs,
                    color: AppColors.accent.withValues(alpha: 0.6),
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),

          // Response body
          _buildBody(displayState, textColor, subColor),
          const SizedBox(height: AppSpacing.s3),

          // Quick call CTA
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: isLoading ? null : _onQuickCall,
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
                isLoading
                    ? 'Checking conditions...'
                    : _hasAsked
                        ? 'What\'s the call now?'
                        : 'What\'s the call?',
                style: const TextStyle(
                  fontSize: AppTypography.textSm,
                  fontWeight: AppTypography.weightMedium,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s2),

          // Quick suggestions
          if (!_hasAsked && displayState.status == AiStatus.idle)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s2),
              child: Wrap(
                spacing: AppSpacing.s2,
                runSpacing: AppSpacing.s1,
                children: [
                  _quickChip('Tomorrow morning?', subColor),
                  _quickChip('Best day this week?', subColor),
                  _quickChip('Is it worth it right now?', subColor),
                ],
              ),
            ),

          // Query input row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _queryController,
                  maxLength: 200,
                  enabled: !isLoading,
                  style: TextStyle(
                    fontSize: AppTypography.textSm,
                    color: textColor,
                  ),
                  decoration: InputDecoration(
                    hintText: 'What\'s the call on...',
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
                onPressed: isLoading ? null : () => _onSubmitQuery(),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(48, 36),
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
                child: const Icon(Icons.arrow_upward, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickChip(String label, Color subColor) {
    return GestureDetector(
      onTap: () => _onSubmitQuery(label),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s2,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppTypography.textXs,
            color: AppColors.accent,
          ),
        ),
      ),
    );
  }

  Widget _buildBody(AiState displayState, Color textColor, Color subColor) {
    switch (displayState.status) {
      case AiStatus.idle:
        return Text(
          'Ask about conditions, timing, or what to expect. Your scoring profile shapes every answer.',
          style: TextStyle(
            fontSize: AppTypography.textSm,
            color: subColor,
            height: 1.4,
          ),
        );
      case AiStatus.loading:
        return _ShimmerBlock(subColor: subColor);
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

class _ShimmerBlock extends StatefulWidget {
  final Color subColor;
  const _ShimmerBlock({required this.subColor});

  @override
  State<_ShimmerBlock> createState() => _ShimmerBlockState();
}

class _ShimmerBlockState extends State<_ShimmerBlock>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? AppColorsDark.bgTertiary : AppColors.bgTertiary;
    final highlight = isDark ? AppColorsDark.bgSurface : AppColors.bgSurface;
    final value = _controller.value;
    final pulse = (sin(value * 3.14159 * 2) + 1) / 2;
    final color = Color.lerp(base, highlight, pulse)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          height: AppTypography.textSm,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
        const SizedBox(height: AppSpacing.s2),
        Container(
          width: 200,
          height: AppTypography.textSm,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
        const SizedBox(height: AppSpacing.s2),
        Container(
          width: 140,
          height: AppTypography.textSm,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ],
    );
  }
}
