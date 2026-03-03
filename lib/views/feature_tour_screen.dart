// Post-onboarding feature tour — 4 animated slides showcasing key differentiators
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/tokens.dart';
import '../components/score_ring.dart';
import '../state/store_provider.dart';
import '../state/preferences_provider.dart';

class FeatureTourScreen extends ConsumerStatefulWidget {
  final VoidCallback? onComplete;
  final bool isReplay;

  const FeatureTourScreen({
    super.key,
    this.onComplete,
    this.isReplay = false,
  });

  @override
  ConsumerState<FeatureTourScreen> createState() => _FeatureTourScreenState();
}

class _FeatureTourScreenState extends ConsumerState<FeatureTourScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  final _slideVisible = [true, false, false, false];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    HapticFeedback.lightImpact();
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: AppDurations.slow,
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _skip() {
    HapticFeedback.lightImpact();
    _finish();
  }

  Future<void> _finish() async {
    await ref.read(storeServiceProvider).setFeatureTourSeen();
    if (widget.isReplay) {
      if (mounted) Navigator.pop(context);
    } else {
      widget.onComplete?.call();
    }
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
      if (!_slideVisible[page]) {
        _slideVisible[page] = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final subColor =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;

    return Scaffold(
      backgroundColor: isDark ? AppColorsDark.bgPrimary : AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: dots + skip
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s4,
                vertical: AppSpacing.s3,
              ),
              child: Row(
                children: [
                  const SizedBox(width: 48), // balance skip button
                  const Spacer(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(4, (i) {
                      final isActive = i == _currentPage;
                      return AnimatedContainer(
                        duration: AppDurations.fast,
                        curve: Curves.easeInOut,
                        width: isActive ? 20 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.accent
                              : (isDark
                                  ? AppColorsDark.bgTertiary
                                  : AppColors.bgTertiary),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _skip,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: AppTypography.textSm,
                        color: subColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Page view
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: _onPageChanged,
                children: [
                  _buildSlide1(textColor, subColor, isDark),
                  _buildSlide2(textColor, subColor, isDark),
                  _buildSlide3(textColor, subColor, isDark),
                  _buildSlide4(textColor, subColor, isDark),
                ],
              ),
            ),

            // Bottom button
            Padding(
              padding: const EdgeInsets.all(AppSpacing.s4),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  child: Text(_currentPage < 3 ? 'Next' : 'Get Started'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Slide 1: Score Ring
  // ---------------------------------------------------------------------------

  Widget _buildSlide1(Color textColor, Color subColor, bool isDark) {
    final prefs = ref.read(preferencesProvider);
    final skill = prefs.skillLevel ?? 'intermediate';
    final skillLabel = skill[0].toUpperCase() + skill.substring(1);

    return _slideLayout(
      hero: _slideVisible[0]
          ? const ScoreRing(score: 0.78, size: 160)
          : const SizedBox(width: 160, height: 160),
      title: 'Your Conditions, Scored for You',
      subtitle: 'One glance tells you if it\'s worth paddling out. '
          'Tuned for $skillLabel surfers.',
      badge: 'Personalized scoring',
      textColor: textColor,
      subColor: subColor,
      isDark: isDark,
    );
  }

  // ---------------------------------------------------------------------------
  // Slide 2: Best Time Window
  // ---------------------------------------------------------------------------

  Widget _buildSlide2(Color textColor, Color subColor, bool isDark) {
    return _slideLayout(
      hero: _slideVisible[1]
          ? _buildHourlyBlocks(isDark)
          : const SizedBox(height: 120),
      title: 'Know Exactly When to Go',
      subtitle: 'We find the best window so you don\'t waste a session '
          'on bad timing.',
      badge: 'Smart scheduling',
      textColor: textColor,
      subColor: subColor,
      isDark: isDark,
    );
  }

  Widget _buildHourlyBlocks(bool isDark) {
    final hours = ['6 AM', '7 AM', '8 AM', '9 AM', '10 AM', '11 AM'];
    final highlighted = {2, 3, 4}; // middle 3 = best window

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(hours.length, (i) {
          final isHighlighted = highlighted.contains(i);
          return AnimatedOpacity(
            duration: Duration(milliseconds: 300 + i * 80),
            curve: Curves.easeOut,
            opacity: _slideVisible[1] ? 1.0 : 0.0,
            child: AnimatedSlide(
              duration: Duration(milliseconds: 300 + i * 80),
              curve: Curves.easeOut,
              offset: _slideVisible[1] ? Offset.zero : const Offset(0, 0.3),
              child: Container(
                width: 48,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.s3, horizontal: AppSpacing.s1),
                decoration: BoxDecoration(
                  color: isHighlighted
                      ? AppColors.accent.withValues(alpha: 0.15)
                      : (isDark
                          ? AppColorsDark.bgSecondary
                          : AppColors.bgSecondary),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: isHighlighted
                      ? Border.all(color: AppColors.accent, width: 1.5)
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isHighlighted
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      size: 18,
                      color: isHighlighted
                          ? AppColors.accent
                          : (isDark
                              ? AppColorsDark.textTertiary
                              : AppColors.textTertiary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hours[i],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isHighlighted
                            ? AppTypography.weightSemibold
                            : AppTypography.weightRegular,
                        color: isHighlighted
                            ? AppColors.accent
                            : (isDark
                                ? AppColorsDark.textSecondary
                                : AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Slide 3: Surf IQ
  // ---------------------------------------------------------------------------

  Widget _buildSlide3(Color textColor, Color subColor, bool isDark) {
    return _slideLayout(
      hero: _slideVisible[2]
          ? _buildSurfIQProgress(isDark)
          : const SizedBox(height: 100),
      title: 'Gets Smarter Every Session',
      subtitle: 'Rate your sessions and Boardcast learns what conditions '
          'actually work for you.',
      badge: 'Surf IQ',
      textColor: textColor,
      subColor: subColor,
      isDark: isDark,
    );
  }

  Widget _buildSurfIQProgress(bool isDark) {
    const levels = ['Grom', 'Rookie', 'Regular', 'Ripper', 'Waterman'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated counter
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 35),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOut,
            builder: (_, val, child) => Text(
              'Surf IQ: ${val.round()}',
              style: TextStyle(
                fontFamily: AppTypography.fontMono,
                fontSize: AppTypography.text2xl,
                fontWeight: AppTypography.weightBold,
                color: AppColors.accent,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s4),

          // Progress bar
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 0.35),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOut,
            builder: (_, val, child) => ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: LinearProgressIndicator(
                value: val,
                minHeight: 8,
                backgroundColor:
                    isDark ? AppColorsDark.bgTertiary : AppColors.bgTertiary,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.accent),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s3),

          // Level labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: levels
                .map((l) => Text(
                      l,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? AppColorsDark.textTertiary
                            : AppColors.textTertiary,
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Slide 4: Widgets + Siri
  // ---------------------------------------------------------------------------

  Widget _buildSlide4(Color textColor, Color subColor, bool isDark) {
    return _slideLayout(
      hero: _slideVisible[3]
          ? _buildWidgetSiriDemo(isDark)
          : const SizedBox(height: 120),
      title: 'Always Within Reach',
      subtitle: 'Check conditions from your home screen or just ask Siri.',
      badge: 'Widget + Siri',
      textColor: textColor,
      subColor: subColor,
      isDark: isDark,
    );
  }

  Widget _buildWidgetSiriDemo(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Widget card from left
          AnimatedSlide(
            duration: AppDurations.slow,
            curve: Curves.easeOut,
            offset: _slideVisible[3] ? Offset.zero : const Offset(-0.5, 0),
            child: AnimatedOpacity(
              duration: AppDurations.slow,
              opacity: _slideVisible[3] ? 1.0 : 0.0,
              child: Container(
                width: 140,
                padding: const EdgeInsets.all(AppSpacing.s3),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColorsDark.bgSecondary
                      : AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: AppShadows.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.waves, size: AppIconSize.sm, color: AppColors.accent),
                        const SizedBox(width: AppSpacing.s1),
                        Text(
                          'Boardcast',
                          style: TextStyle(
                            fontSize: AppTypography.textXxs,
                            fontWeight: AppTypography.weightSemibold,
                            color: isDark
                                ? AppColorsDark.textSecondary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    Text(
                      '72',
                      style: TextStyle(
                        fontFamily: AppTypography.fontMono,
                        fontSize: AppTypography.textXl,
                        fontWeight: AppTypography.weightBold,
                        color: AppColors.conditionGood,
                      ),
                    ),
                    Text(
                      'Good',
                      style: TextStyle(
                        fontSize: AppTypography.textSm,
                        fontWeight: AppTypography.weightMedium,
                        color: AppColors.conditionGood,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s1),
                    Text(
                      '3-4 ft \u2022 Offshore',
                      style: TextStyle(
                        fontSize: AppTypography.textXxs,
                        color: isDark
                            ? AppColorsDark.textTertiary
                            : AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s4),

          // Siri bubble from right
          AnimatedSlide(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            offset: _slideVisible[3] ? Offset.zero : const Offset(0.5, 0),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 500),
              opacity: _slideVisible[3] ? 1.0 : 0.0,
              child: Container(
                width: 140,
                padding: const EdgeInsets.all(AppSpacing.s3),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColorsDark.bgSecondary
                      : AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: AppShadows.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF6366F1),
                            Color(0xFFEC4899),
                            Color(0xFFF97316),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: const Icon(Icons.mic,
                          color: Colors.white, size: AppIconSize.lg),
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    Text(
                      '"How\'s the surf?"',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: AppTypography.textSm,
                        fontStyle: FontStyle.italic,
                        color: isDark
                            ? AppColorsDark.textPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s1),
                    Text(
                      'Siri Shortcuts',
                      style: TextStyle(
                        fontSize: AppTypography.textXxs,
                        color: isDark
                            ? AppColorsDark.textTertiary
                            : AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared slide layout
  // ---------------------------------------------------------------------------

  Widget _slideLayout({
    required Widget hero,
    required String title,
    required String subtitle,
    required String badge,
    required Color textColor,
    required Color subColor,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
      child: Column(
        children: [
          // Hero area — top 55%
          Expanded(
            flex: 55,
            child: Center(child: hero),
          ),
          // Text area — bottom 45%
          Expanded(
            flex: 45,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: AppTypography.textXl,
                    fontWeight: AppTypography.weightBold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: AppSpacing.s2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: AppTypography.textBase,
                    color: subColor,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s3,
                    vertical: AppSpacing.s1 + 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: AppTypography.textSm,
                      fontWeight: AppTypography.weightMedium,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
