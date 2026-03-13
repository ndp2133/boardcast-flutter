// Score Breakdown Bottom Sheet — StressWatch-inspired "More Insights" overlay
// showing factor-by-factor score transparency.
import 'dart:math' show pi;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../logic/scoring.dart';
import '../logic/score_breakdown_helpers.dart';
import '../logic/units.dart';
import '../models/hourly_data.dart';
import '../models/location.dart';
import '../models/user_prefs.dart';

/// Show the score breakdown as a modal bottom sheet.
/// When [scrubNotifier] is provided, the sheet reactively updates as the user
/// scrubs through hourly data.
void showScoreBreakdown(
  BuildContext context, {
  required ScoreBreakdown breakdown,
  required List<FactorSummary> factors,
  required bool isDark,
  VoidCallback? onAskTheCall,
  ValueNotifier<int?>? scrubNotifier,
  List<HourlyData>? hourlyData,
  HourlyData? currentHour,
  UserPrefs? prefs,
  Location? location,
  TideRange? tideRange,
  ForecastAccuracy? accuracy,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ScoreBreakdownSheet(
      breakdown: breakdown,
      factors: factors,
      isDark: isDark,
      onAskTheCall: onAskTheCall,
      scrubNotifier: scrubNotifier,
      hourlyData: hourlyData,
      currentHour: currentHour,
      prefs: prefs,
      location: location,
      tideRange: tideRange,
      accuracy: accuracy,
    ),
  );
}

class _ScoreBreakdownSheet extends StatefulWidget {
  final ScoreBreakdown breakdown;
  final List<FactorSummary> factors;
  final bool isDark;
  final VoidCallback? onAskTheCall;
  final ValueNotifier<int?>? scrubNotifier;
  final List<HourlyData>? hourlyData;
  final HourlyData? currentHour;
  final UserPrefs? prefs;
  final Location? location;
  final TideRange? tideRange;
  final ForecastAccuracy? accuracy;

  const _ScoreBreakdownSheet({
    required this.breakdown,
    required this.factors,
    required this.isDark,
    this.onAskTheCall,
    this.scrubNotifier,
    this.hourlyData,
    this.currentHour,
    this.prefs,
    this.location,
    this.tideRange,
    this.accuracy,
  });

  @override
  State<_ScoreBreakdownSheet> createState() => _ScoreBreakdownSheetState();
}

class _ScoreBreakdownSheetState extends State<_ScoreBreakdownSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _staggerController.forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  /// Recompute breakdown + factors for a given scrub index, falling back
  /// to the initial static data when scrubNotifier is null or index is null.
  ({ScoreBreakdown breakdown, List<FactorSummary> factors}) _resolve(
      int? scrubIdx) {
    if (scrubIdx != null &&
        widget.hourlyData != null &&
        widget.prefs != null &&
        widget.location != null &&
        scrubIdx >= 0 &&
        scrubIdx < widget.hourlyData!.length) {
      final hData = widget.hourlyData![scrubIdx];
      final bd = computeMatchScoreBreakdown(
        hData,
        widget.prefs,
        widget.location!,
        tideRange: widget.tideRange,
      );
      return (breakdown: bd, factors: buildFactorSummaries(bd));
    }
    return (breakdown: widget.breakdown, factors: widget.factors);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg = isDark ? AppColorsDark.bgSecondary : AppColors.bgSecondary;
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final subColor =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    // If we have a scrub notifier, wrap content so it reacts to scrub changes
    if (widget.scrubNotifier != null) {
      return ValueListenableBuilder<int?>(
        valueListenable: widget.scrubNotifier!,
        builder: (context, scrubIdx, _) {
          final resolved = _resolve(scrubIdx);
          return _buildSheet(
            context,
            breakdown: resolved.breakdown,
            factors: resolved.factors,
            isDark: isDark,
            bg: bg,
            textColor: textColor,
            subColor: subColor,
            reduceMotion: reduceMotion,
          );
        },
      );
    }

    return _buildSheet(
      context,
      breakdown: widget.breakdown,
      factors: widget.factors,
      isDark: isDark,
      bg: bg,
      textColor: textColor,
      subColor: subColor,
      reduceMotion: reduceMotion,
    );
  }

  Widget _buildSheet(
    BuildContext context, {
    required ScoreBreakdown breakdown,
    required List<FactorSummary> factors,
    required bool isDark,
    required Color bg,
    required Color textColor,
    required Color subColor,
    required bool reduceMotion,
  }) {
    final condLabel = getConditionLabel(breakdown.finalScore);
    final condColor = _conditionColor(breakdown.finalScore);
    final scoreInt = (breakdown.finalScore * 100).round();

    // Height for the frosted header (handle + header row + padding)
    const headerHeight = 72.0;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        child: Semantics(
          label: 'Score breakdown: $scoreInt out of 100, ${condLabel.label}. '
              '${factors.length} contributing factors.',
          child: Stack(
            children: [
              // Scrollable content with top padding to clear the header
              ListView(
                controller: scrollController,
                padding: const EdgeInsets.only(
                  left: AppSpacing.s5,
                  right: AppSpacing.s5,
                  top: headerHeight,
                ),
                children: [
                  const SizedBox(height: AppSpacing.s5),

                  // B. Score Summary
                  Center(
                    child: Column(
                      children: [
                        // Animated count-up for score
                        TweenAnimationBuilder<int>(
                          tween: IntTween(
                              begin: reduceMotion ? scoreInt : 0,
                              end: scoreInt),
                          duration: reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 600),
                          curve: Curves.easeOut,
                          builder: (context, value, _) => Text(
                            '$value',
                            style: TextStyle(
                              fontFamily: AppTypography.fontMono,
                              fontSize: AppTypography.text3xl,
                              fontWeight: AppTypography.weightBold,
                              color: condColor,
                              height: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s1),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: condColor.withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            condLabel.label,
                            style: TextStyle(
                              fontSize: AppTypography.textSm,
                              fontWeight: AppTypography.weightSemibold,
                              color: condColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s4),

                  // B. Spectrum bar
                  _SpectrumBar(
                      score: breakdown.finalScore, isDark: isDark),
                  // Spectrum labels
                  Padding(
                    padding: const EdgeInsets.only(
                        top: 4, bottom: AppSpacing.s6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (final label in [
                          'Poor',
                          'Fair',
                          'Good',
                          'Epic'
                        ])
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? AppColorsDark.textTertiary
                                  : AppColors.textTertiary,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // C. Factor Cards — staggered entrance
                  ...factors.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final factor = entry.value;
                    final delayFraction =
                        (0.2 + idx * 0.15).clamp(0.0, 1.0);

                    if (reduceMotion) {
                      return Padding(
                        padding: const EdgeInsets.only(
                            bottom: AppSpacing.s3),
                        child: _FactorCard(
                            factor: factor,
                            isDark: isDark,
                            animateBar: false),
                      );
                    }

                    return AnimatedBuilder(
                      animation: _staggerController,
                      builder: (context, child) {
                        final t = Curves.easeOut.transform(
                          ((_staggerController.value - delayFraction) /
                                  (1 - delayFraction))
                              .clamp(0.0, 1.0),
                        );
                        return Opacity(
                          opacity: t,
                          child: Transform.translate(
                            offset: Offset(0, (1 - t) * 12),
                            child: child,
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(
                            bottom: AppSpacing.s3),
                        child: _FactorCard(
                            factor: factor,
                            isDark: isDark,
                            animateBar: true),
                      ),
                    );
                  }),

                  // D. Hard Cap Section
                  if (breakdown.activeCaps.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.s2),
                    _HardCapSection(
                        caps: breakdown.activeCaps, isDark: isDark),
                  ],

                  // E. Conditions Detail
                  const SizedBox(height: AppSpacing.s4),
                  _ConditionsDetail(breakdown: breakdown, isDark: isDark),

                  // F. Expected vs Potential
                  if (widget.hourlyData != null &&
                      widget.prefs != null &&
                      widget.location != null)
                    Builder(builder: (context) {
                      final evp = computeExpectedVsPotential(
                        widget.hourlyData!, widget.prefs!, widget.location!,
                        tideRange: widget.tideRange,
                      );
                      if (evp == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.s3),
                        child: _EvpSection(evp: evp, isDark: isDark),
                      );
                    }),

                  // G. Forecast Accuracy
                  if (widget.accuracy != null) ...[
                    const SizedBox(height: AppSpacing.s3),
                    Row(
                      children: [
                        Icon(Icons.check_circle_outline, size: 16, color: AppColors.accent),
                        const SizedBox(width: 6),
                        Text(
                          'Matched ${widget.accuracy!.matched} of your last ${widget.accuracy!.total} sessions (${widget.accuracy!.pct}%)',
                          style: TextStyle(
                            fontSize: AppTypography.textXs,
                            fontWeight: AppTypography.weightMedium,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // H. Footer CTA — proper button
                  if (widget.onAskTheCall != null) ...[
                    const SizedBox(height: AppSpacing.s4),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onAskTheCall!();
                        },
                        icon: const Icon(Icons.chevron_right, size: 18),
                        label: const Text(
                            'Want the full picture? Ask The Call'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.accent,
                          side: BorderSide(
                            color: AppColors.accent
                                .withValues(alpha: 0.3),
                          ),
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.s3,
                              horizontal: AppSpacing.s4),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.s8),
                ],
              ),

              // Frosted glass sticky header
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s5),
                      decoration: BoxDecoration(
                        color: bg.withValues(alpha: 0.85),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppRadius.xl),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: AppSpacing.s3),
                          // Handle
                          Center(
                            child: Container(
                              width: 40,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColorsDark.bgTertiary
                                    : AppColors.bgTertiary,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s4),
                          // Header row with mini score ring
                          Row(
                            children: [
                              SizedBox(
                                width: 32,
                                height: 32,
                                child: CustomPaint(
                                  painter: _MiniRingPainter(
                                    progress: breakdown.finalScore,
                                    color: condColor,
                                    trackColor: isDark
                                        ? AppColorsDark.bgTertiary
                                        : AppColors.bgTertiary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s2),
                              Expanded(
                                child: Text(
                                  'Score Breakdown',
                                  style: TextStyle(
                                    fontSize: AppTypography.textLg,
                                    fontWeight: AppTypography.weightBold,
                                    color: textColor,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Icon(Icons.close,
                                    size: 20, color: subColor),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.s3),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Spectrum Bar ---

class _SpectrumBar extends StatelessWidget {
  final double score;
  final bool isDark;

  const _SpectrumBar({required this.score, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return SizedBox(
      height: 24,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final targetDotX = (score * width).clamp(8.0, width - 8.0);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Gradient bar with subtle border in dark mode
              Container(
                height: 10,
                margin: const EdgeInsets.only(top: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.conditionPoor,
                      AppColors.conditionFair,
                      AppColors.conditionGood,
                      AppColors.conditionEpic,
                    ],
                    stops: [0.0, 0.4, 0.6, 0.85],
                  ),
                  border: isDark
                      ? Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                          width: 0.5)
                      : null,
                ),
              ),
              // Animated dot indicator
              TweenAnimationBuilder<double>(
                tween: Tween(
                    begin: reduceMotion ? targetDotX : 8.0,
                    end: targetDotX),
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 500),
                curve: Curves.easeOut,
                builder: (context, dotX, _) => Positioned(
                  left: dotX - 8,
                  top: 4,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? AppColorsDark.textPrimary
                          : AppColors.bgSecondary,
                      border: Border.all(
                        color: _conditionColor(score),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _conditionColor(score).withValues(
                              alpha: isDark ? 0.5 : 0.3),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// --- Factor Card ---

class _FactorCard extends StatefulWidget {
  final FactorSummary factor;
  final bool isDark;
  final bool animateBar;

  const _FactorCard({
    required this.factor,
    required this.isDark,
    this.animateBar = false,
  });

  @override
  State<_FactorCard> createState() => _FactorCardState();
}

class _FactorCardState extends State<_FactorCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final factor = widget.factor;
    final animateBar = widget.animateBar;

    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final subColor =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;
    final bgTertiary =
        isDark ? AppColorsDark.bgTertiary : AppColors.bgTertiary;
    final sColor = statusColor(factor.status, isDark);
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final cardBgColor = isDark
        ? AppColorsDark.bgTertiary.withValues(alpha: 0.8)
        : AppColors.bgPrimary;
    final darkBorderColor = Colors.white.withValues(alpha: 0.04);

    return Semantics(
      label: '${factor.name}: ${factor.value}. ${factor.explanation}. '
          '${factor.status.name}.',
      child: GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        behavior: HitTestBehavior.opaque,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: IntrinsicHeight(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                decoration: BoxDecoration(
                  color: cardBgColor,
                  border: isDark
                      ? Border(
                          top: BorderSide(color: darkBorderColor),
                          right: BorderSide(color: darkBorderColor),
                          bottom: BorderSide(color: darkBorderColor),
                        )
                      : null,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left accent strip
                    Container(width: 3, color: sColor),
                    // Card content
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.s4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header row: dot + status text + name + value + chevron
                            Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: sColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s2),
                                Text(
                                  factor.name,
                                  style: TextStyle(
                                    fontSize: AppTypography.textSm,
                                    fontWeight:
                                        AppTypography.weightSemibold,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s1),
                                // Status text label (accessibility: not color-only)
                                Text(
                                  factor.status == FactorStatus.helping
                                      ? 'Helping'
                                      : factor.status ==
                                              FactorStatus.hurting
                                          ? 'Hurting'
                                          : 'Neutral',
                                  style: TextStyle(
                                    fontSize: AppTypography.textXxs,
                                    color: sColor,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  factor.value,
                                  style: TextStyle(
                                    fontFamily: AppTypography.fontMono,
                                    fontSize: AppTypography.textXs,
                                    fontWeight:
                                        AppTypography.weightMedium,
                                    color: sColor,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s1),
                                AnimatedRotation(
                                  turns: _expanded ? 0.5 : 0.0,
                                  duration:
                                      const Duration(milliseconds: 200),
                                  curve: Curves.easeOut,
                                  child: Icon(
                                    Icons.expand_more,
                                    size: 18,
                                    color: subColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.s2),

                            // Mini progress bar — animated fill
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: SizedBox(
                                height: 6,
                                child: Stack(
                                  children: [
                                    Container(color: bgTertiary),
                                    if (animateBar && !reduceMotion)
                                      TweenAnimationBuilder<double>(
                                        tween: Tween(
                                            begin: 0,
                                            end: factor.barPosition
                                                .clamp(0.0, 1.0)),
                                        duration: const Duration(
                                            milliseconds: 400),
                                        curve: Curves.easeOutCubic,
                                        builder: (context, value, _) =>
                                            FractionallySizedBox(
                                          widthFactor: value,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: sColor,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      3),
                                            ),
                                          ),
                                        ),
                                      )
                                    else
                                      FractionallySizedBox(
                                        widthFactor: factor.barPosition
                                            .clamp(0.0, 1.0),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: sColor,
                                            borderRadius:
                                                BorderRadius.circular(3),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),

                            // Expanded content: explanation + ideal range
                            if (_expanded) ...[
                              const SizedBox(height: AppSpacing.s2),

                              // Explanation
                              Text(
                                factor.explanation,
                                style: TextStyle(
                                  fontSize: AppTypography.textXs,
                                  color: subColor,
                                  height: 1.4,
                                ),
                              ),

                              // Ideal range (if available)
                              if (factor.idealRange != null) ...[
                                const SizedBox(height: AppSpacing.s1),
                                Text(
                                  'Ideal: ${factor.idealRange}',
                                  style: TextStyle(
                                    fontSize: AppTypography.textXxs,
                                    color: isDark
                                        ? AppColorsDark.textSecondary
                                        : AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- Hard Cap Section ---

class _HardCapSection extends StatelessWidget {
  final List<HardCap> caps;
  final bool isDark;

  const _HardCapSection({required this.caps, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final capBg = isDark
        ? AppColors.conditionPoor.withValues(alpha: 0.15)
        : AppColors.conditionPoor.withValues(alpha: 0.08);
    final capBorder = isDark
        ? AppColors.conditionPoor.withValues(alpha: 0.25)
        : AppColors.conditionPoor.withValues(alpha: 0.15);

    return Semantics(
      label: 'Score capped: ${caps.map(hardCapExplanation).join('. ')}',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s3),
        decoration: BoxDecoration(
          color: capBg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border(
            left: BorderSide(
              color: AppColors.conditionPoor,
              width: 4,
            ),
            top: BorderSide(color: capBorder),
            right: BorderSide(color: capBorder),
            bottom: BorderSide(color: capBorder),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 16, color: AppColors.conditionPoor),
                const SizedBox(width: AppSpacing.s2),
                Text(
                  'Score capped',
                  style: TextStyle(
                    fontSize: AppTypography.textSm,
                    fontWeight: AppTypography.weightSemibold,
                    color: textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s2),
            ...caps.map((cap) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s1),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('  \u2022 ',
                          style: TextStyle(
                              fontSize: AppTypography.textXs,
                              color: textColor)),
                      Expanded(
                        child: Text(
                          hardCapExplanation(cap),
                          style: TextStyle(
                            fontSize: AppTypography.textXs,
                            color: isDark
                                ? AppColorsDark.textSecondary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

// --- Mini Ring Painter (static, no animation) ---

class _MiniRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  _MiniRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Fill arc
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(_MiniRingPainter old) =>
      old.progress != progress || old.color != color;
}

Color _conditionColor(double score) {
  if (score >= 0.8) return AppColors.conditionEpic;
  if (score >= 0.6) return AppColors.conditionGood;
  if (score >= 0.4) return AppColors.conditionFair;
  return AppColors.conditionPoor;
}

// =============================================================================
// CONDITIONS DETAIL — raw metrics section (moved from dashboard)
// =============================================================================

class _ConditionsDetail extends StatelessWidget {
  final ScoreBreakdown breakdown;
  final bool isDark;

  const _ConditionsDetail({required this.breakdown, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColorsDark.bgTertiary : AppColors.bgTertiary;
    final textColor = isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final subColor = isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;
    final dividerColor = isDark
        ? AppColorsDark.textTertiary.withValues(alpha: 0.2)
        : AppColors.textTertiary.withValues(alpha: 0.2);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: isDark ? 0.5 : 0.6),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Conditions',
            style: TextStyle(
              fontSize: AppTypography.textXs,
              fontWeight: AppTypography.weightSemibold,
              color: subColor,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(child: _metric(
                  label: 'Waves',
                  value: breakdown.actualWaveHeight != null
                      ? formatWaveHeight(breakdown.actualWaveHeight)
                      : '--',
                  unit: 'ft',
                  detail: breakdown.swellPeriod != null
                      ? '${breakdown.swellPeriod!.round()}s period'
                      : '',
                  textColor: textColor,
                  subColor: subColor,
                )),
                VerticalDivider(width: AppSpacing.s4, thickness: 1, color: dividerColor),
                Expanded(child: _metric(
                  label: 'Wind',
                  value: breakdown.windSpeed != null
                      ? formatWindSpeed(breakdown.windSpeed)
                      : '--',
                  unit: 'mph',
                  detail: breakdown.isOffshore
                      ? 'Offshore'
                      : breakdown.isOnshore
                          ? 'Onshore'
                          : 'Cross-shore',
                  textColor: textColor,
                  subColor: subColor,
                )),
                VerticalDivider(width: AppSpacing.s4, thickness: 1, color: dividerColor),
                Expanded(child: _metric(
                  label: 'Tide',
                  value: breakdown.tideNormalized != null
                      ? _tideLabel(breakdown.tideNormalized!)
                      : '--',
                  unit: '',
                  detail: breakdown.breakType,
                  textColor: textColor,
                  subColor: subColor,
                )),
              ],
            ),
          ),
          // Ideal range row
          if (breakdown.idealMin != null && breakdown.idealMax != null) ...[
            const SizedBox(height: AppSpacing.s2),
            Center(
              child: Text(
                'Ideal range: ${formatWaveHeight(breakdown.idealMin)}–${formatWaveHeight(breakdown.idealMax)}ft',
                style: TextStyle(
                  fontSize: AppTypography.textXs,
                  color: subColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _tideLabel(double normalized) {
    if (normalized < 0.33) return 'Low';
    if (normalized < 0.66) return 'Mid';
    return 'High';
  }

  Widget _metric({
    required String label,
    required String value,
    required String unit,
    required String detail,
    required Color textColor,
    required Color subColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(
          fontSize: AppTypography.textXs,
          fontWeight: AppTypography.weightMedium,
          color: subColor,
        )),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: TextStyle(
              fontFamily: AppTypography.fontMono,
              fontSize: AppTypography.textLg,
              fontWeight: AppTypography.weightBold,
              color: textColor,
            )),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 2),
              Text(unit, style: TextStyle(
                fontSize: AppTypography.textXs,
                color: subColor,
              )),
            ],
          ],
        ),
        if (detail.isNotEmpty)
          Text(detail, style: TextStyle(
            fontSize: AppTypography.textXs,
            color: subColor,
          )),
      ],
    );
  }
}

// =============================================================================
// EXPECTED VS POTENTIAL — moved from dashboard
// =============================================================================

class _EvpSection extends StatelessWidget {
  final ExpectedVsPotential evp;
  final bool isDark;

  const _EvpSection({required this.evp, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColorsDark.bgTertiary : AppColors.bgTertiary;
    final textColor = isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final subColor = isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;

    final expectedLabel = getConditionLabel(evp.expectedScore);
    final potentialLabel = getConditionLabel(evp.potentialScore);
    final expectedColor = _conditionColor(evp.expectedScore);
    final potentialColor = _conditionColor(evp.potentialScore);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: isDark ? 0.5 : 0.6),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          _evpRow('EXPECTED', evp.expectedDescription, expectedLabel,
              expectedColor, textColor, subColor),
          const SizedBox(height: AppSpacing.s1),
          _evpRow('POTENTIAL', evp.potentialDescription, potentialLabel,
              potentialColor, textColor, subColor),
        ],
      ),
    );
  }

  Widget _evpRow(String label, String desc, ConditionLabel condition,
      Color condColor, Color textColor, Color subColor) {
    return Row(
      children: [
        SizedBox(
          width: 68,
          child: Text(label, style: TextStyle(
            fontSize: AppTypography.textXxs,
            fontWeight: AppTypography.weightSemibold,
            color: subColor,
            letterSpacing: 0.3,
          )),
        ),
        Expanded(
          child: Text(desc, style: TextStyle(
            fontSize: AppTypography.textXs,
            color: textColor,
          )),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: condColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(condition.label, style: TextStyle(
            fontSize: AppTypography.textXxs,
            fontWeight: AppTypography.weightSemibold,
            color: condColor,
          )),
        ),
      ],
    );
  }
}
