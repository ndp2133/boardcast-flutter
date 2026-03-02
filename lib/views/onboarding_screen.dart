import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/tokens.dart';
import '../logic/units.dart';
import '../models/user_prefs.dart';
import '../services/store_service.dart';
import '../state/preferences_provider.dart';
import '../state/store_provider.dart';
import '../state/health_import_provider.dart';
import 'health_import_step.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentStep = 0;
  bool _healthAvailable = false;

  // Prefs state
  String? _skillLevel;
  double _minWave = 0.3;
  double _maxWave = 1.0;
  double _maxWind = 20.0;
  String _windDir = 'offshore';
  String _tide = 'mid';

  bool _skillCardsVisible = false;

  /// Total steps: 3 without health, 4 with health
  int get _totalSteps => _healthAvailable ? 4 : 3;

  /// Step indices adjusted for health availability
  int get _healthStep => 1; // Only used when _healthAvailable
  int get _prefsStep => _healthAvailable ? 2 : 1;
  int get _confirmStep => _healthAvailable ? 3 : 2;

  @override
  void initState() {
    super.initState();
    _checkHealthAvailability();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _skillCardsVisible = true);
    });
  }

  Future<void> _checkHealthAvailability() async {
    try {
      final available =
          await ref.read(healthImportProvider.notifier).isAvailable();
      if (mounted) setState(() => _healthAvailable = available);
    } catch (_) {
      // Health not available — keep 3-step flow
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectSkill(String skill) {
    setState(() {
      _skillLevel = skill;
      final defaults = skillDefaults[skill]!;
      _minWave = defaults.minWaveHeight ?? 0.3;
      _maxWave = defaults.maxWaveHeight ?? 1.0;
      _maxWind = defaults.maxWindSpeed ?? 20.0;
      _windDir = defaults.preferredWindDir ?? 'offshore';
      _tide = defaults.preferredTide ?? 'mid';
    });
  }

  /// Apply inferred prefs from HealthKit import to pre-fill sliders
  void _applyInferredPrefs() {
    final importState = ref.read(healthImportProvider);
    final inferred = importState.inferredPrefs;
    if (inferred == null) return;

    final p = inferred.prefs;
    setState(() {
      if (p.skillLevel != null) _skillLevel = p.skillLevel;
      if (p.minWaveHeight != null) _minWave = p.minWaveHeight!;
      if (p.maxWaveHeight != null) _maxWave = p.maxWaveHeight!;
      if (p.maxWindSpeed != null) _maxWind = p.maxWindSpeed!;
      if (p.preferredWindDir != null) _windDir = p.preferredWindDir!;
      if (p.preferredTide != null) _tide = p.preferredTide!;
    });
  }

  void _next() {
    if (_currentStep < _confirmStep) {
      _pageController.nextPage(
        duration: AppDurations.slow,
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _back() {
    _pageController.previousPage(
      duration: AppDurations.slow,
      curve: Curves.easeInOut,
    );
  }

  void _skipAsGuest() {
    // Use intermediate defaults
    _skillLevel = 'intermediate';
    _finish();
  }

  Future<void> _finish() async {
    final prefs = UserPrefs(
      skillLevel: _skillLevel,
      minWaveHeight: _minWave,
      maxWaveHeight: _maxWave,
      maxWindSpeed: _maxWind,
      preferredWindDir: _windDir,
      preferredTide: _tide,
    );
    await ref.read(preferencesProvider.notifier).update(prefs);
    await ref.read(storeServiceProvider).setOnboarded();
    widget.onComplete();
  }

  String get _nextLabel {
    if (_currentStep == 0) {
      return _skillLevel != null ? 'Continue' : 'Select a Level';
    }
    // Health import step has its own buttons — this label won't show
    if (_healthAvailable && _currentStep == _healthStep) return '';
    if (_currentStep == _prefsStep) return 'Review';
    return 'Start Surfing';
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
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s4,
                vertical: AppSpacing.s3,
              ),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    GestureDetector(
                      onTap: _back,
                      child: Icon(Icons.arrow_back_ios,
                          size: 20, color: textColor),
                    )
                  else
                    const SizedBox(width: 20),
                  const Spacer(),
                  // Dot indicators
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(_totalSteps, (i) {
                      final isActive = i == _currentStep;
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
                  const SizedBox(width: 20),
                ],
              ),
            ),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentStep = i),
                children: [
                  _buildSkillStep(textColor, subColor, isDark),
                  if (_healthAvailable)
                    HealthImportStep(
                      homeLocationId: null,
                      userId: null,
                      onSkip: _next,
                      onComplete: () {
                        _applyInferredPrefs();
                        _next();
                      },
                    ),
                  _buildPrefsStep(textColor, subColor),
                  _buildConfirmStep(textColor, subColor),
                ],
              ),
            ),

            // Bottom buttons (hidden on health import step — it has its own)
            if (!(_healthAvailable && _currentStep == _healthStep))
              Padding(
                padding: const EdgeInsets.all(AppSpacing.s4),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            (_currentStep == 0 && _skillLevel == null)
                                ? null
                                : _next,
                        child: Text(_nextLabel),
                      ),
                    ),
                    if (_currentStep == 0) ...[
                      const SizedBox(height: AppSpacing.s3),
                      TextButton(
                        onPressed: _skipAsGuest,
                        child: Text(
                          'Continue as Guest',
                          style: TextStyle(color: subColor),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---- Step 0: Skill Level ----

  Widget _staggeredCard({required int delay, required Widget child}) {
    final offset = _skillCardsVisible ? Offset.zero : const Offset(0, 0.15);
    final opacity = _skillCardsVisible ? 1.0 : 0.0;
    return AnimatedOpacity(
      duration: Duration(milliseconds: 300 + delay * 80),
      curve: Curves.easeOut,
      opacity: opacity,
      child: AnimatedSlide(
        duration: Duration(milliseconds: 300 + delay * 80),
        curve: Curves.easeOut,
        offset: offset,
        child: child,
      ),
    );
  }

  Widget _buildStepIcon(IconData icon, Color color) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: AppDurations.slow,
      curve: Curves.easeOut,
      builder: (_, val, child) => Opacity(
        opacity: val,
        child: Transform.scale(
          scale: 0.8 + 0.2 * val,
          child: child,
        ),
      ),
      child: Icon(icon, size: 48, color: color),
    );
  }

  Widget _buildSkillStep(Color textColor, Color subColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.s4),
          Center(child: _buildStepIcon(Icons.waves, AppColors.accent)),
          const SizedBox(height: AppSpacing.s4),
          Text(
            'What\'s your skill level?',
            style: TextStyle(
              fontSize: AppTypography.textXl,
              fontWeight: AppTypography.weightBold,
              color: textColor,
            ),
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            'We\'ll personalize your conditions scoring.',
            style: TextStyle(
              fontSize: AppTypography.textSm,
              color: subColor,
            ),
          ),
          const SizedBox(height: AppSpacing.s6),
          _staggeredCard(
            delay: 0,
            child: _buildSkillCard(
              'Beginner',
              'Learning to catch waves. Prefer smaller, gentle conditions.',
              'beginner',
              isDark,
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          _staggeredCard(
            delay: 1,
            child: _buildSkillCard(
              'Intermediate',
              'Comfortable in varied conditions. Looking for fun waves.',
              'intermediate',
              isDark,
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          _staggeredCard(
            delay: 2,
            child: _buildSkillCard(
              'Advanced',
              'Seek bigger, more powerful waves. Handle any conditions.',
              'advanced',
              isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillCard(
      String title, String desc, String value, bool isDark) {
    final isSelected = _skillLevel == value;
    final bg = isDark ? AppColorsDark.bgSecondary : AppColors.bgSecondary;

    return GestureDetector(
      onTap: () => _selectSkill(value),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        padding: const EdgeInsets.all(AppSpacing.s4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected ? AppColors.accent : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected ? AppShadows.base : AppShadows.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: AppTypography.textBase,
                      fontWeight: AppTypography.weightSemibold,
                      color: isSelected
                          ? AppColors.accent
                          : (isDark
                              ? AppColorsDark.textPrimary
                              : AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: AppTypography.textSm,
                      color: isDark
                          ? AppColorsDark.textSecondary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: AppColors.accent, size: 24),
          ],
        ),
      ),
    );
  }

  // ---- Step 1: Fine-tune Preferences ----

  Widget _buildPrefsStep(Color textColor, Color subColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.s4),
          Center(child: _buildStepIcon(Icons.tune, AppColors.accent)),
          const SizedBox(height: AppSpacing.s4),
          Text(
            'Fine-tune your preferences',
            style: TextStyle(
              fontSize: AppTypography.textXl,
              fontWeight: AppTypography.weightBold,
              color: textColor,
            ),
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            'Adjust the defaults or keep them as-is.',
            style: TextStyle(
              fontSize: AppTypography.textSm,
              color: subColor,
            ),
          ),
          const SizedBox(height: AppSpacing.s6),

          // Min wave
          _sliderGroup(
            label: 'Min Wave Height',
            value: _minWave,
            min: 0.0,
            max: 3.0,
            divisions: 30,
            formatted: '${formatWaveHeight(_minWave)} ft',
            context: 'Flat / Ankle / Knee / Waist',
            textColor: textColor,
            subColor: subColor,
            onChanged: (v) => setState(() {
              _minWave = v;
              if (_maxWave < _minWave + 0.2) _maxWave = _minWave + 0.2;
            }),
          ),
          const SizedBox(height: AppSpacing.s4),

          // Max wave
          _sliderGroup(
            label: 'Max Wave Height',
            value: _maxWave,
            min: 0.5,
            max: 6.0,
            divisions: 55,
            formatted: '${formatWaveHeight(_maxWave)} ft',
            context: 'Knee / Chest / Head / Overhead+',
            textColor: textColor,
            subColor: subColor,
            onChanged: (v) => setState(() {
              _maxWave = v;
              if (_minWave > _maxWave - 0.2) _minWave = _maxWave - 0.2;
            }),
          ),
          const SizedBox(height: AppSpacing.s4),

          // Max wind
          _sliderGroup(
            label: 'Max Wind Speed',
            value: _maxWind,
            min: 0.0,
            max: 60.0,
            divisions: 60,
            formatted: '${formatWindSpeed(_maxWind)} mph',
            context: 'Glass / Light / Moderate / Strong',
            textColor: textColor,
            subColor: subColor,
            onChanged: (v) => setState(() => _maxWind = v),
          ),
          const SizedBox(height: AppSpacing.s5),

          // Wind direction
          _chipGroup(
            label: 'Wind Direction',
            options: const ['offshore', 'onshore', 'any'],
            display: const ['Offshore', 'Onshore', 'Any'],
            selected: _windDir,
            textColor: textColor,
            onSelected: (v) => setState(() => _windDir = v),
          ),
          const SizedBox(height: AppSpacing.s4),

          // Tide
          _chipGroup(
            label: 'Tide',
            options: const ['low', 'mid', 'high', 'any'],
            display: const ['Low', 'Mid', 'High', 'Any'],
            selected: _tide,
            textColor: textColor,
            onSelected: (v) => setState(() => _tide = v),
          ),
          const SizedBox(height: AppSpacing.s6),
        ],
      ),
    );
  }

  Widget _sliderGroup({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String formatted,
    required String context,
    required Color textColor,
    required Color subColor,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: AppTypography.textSm,
                fontWeight: AppTypography.weightMedium,
                color: textColor,
              ),
            ),
            Text(
              formatted,
              style: TextStyle(
                fontFamily: AppTypography.fontMono,
                fontSize: AppTypography.textSm,
                fontWeight: AppTypography.weightSemibold,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
        Text(
          context,
          style: TextStyle(fontSize: AppTypography.textXs, color: subColor),
        ),
      ],
    );
  }

  Widget _chipGroup({
    required String label,
    required List<String> options,
    required List<String> display,
    required String selected,
    required Color textColor,
    required ValueChanged<String> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: AppTypography.textSm,
            fontWeight: AppTypography.weightMedium,
            color: textColor,
          ),
        ),
        const SizedBox(height: AppSpacing.s2),
        Wrap(
          spacing: AppSpacing.s2,
          children: List.generate(options.length, (i) {
            final isActive = options[i] == selected;
            return ChoiceChip(
              label: Text(display[i]),
              selected: isActive,
              onSelected: (_) => onSelected(options[i]),
              selectedColor: AppColors.accentBgStrong,
              labelStyle: TextStyle(
                color: isActive ? AppColors.accent : textColor,
                fontWeight: isActive
                    ? AppTypography.weightSemibold
                    : AppTypography.weightRegular,
                fontSize: AppTypography.textSm,
              ),
            );
          }),
        ),
      ],
    );
  }

  // ---- Step 2: Confirmation ----

  Widget _buildConfirmStep(Color textColor, Color subColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.s4),
          Center(
            child: _buildStepIcon(
                Icons.check_circle_outline, AppColors.conditionEpic),
          ),
          const SizedBox(height: AppSpacing.s4),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.9, end: 1.0),
            duration: AppDurations.slow,
            curve: Curves.elasticOut,
            builder: (_, scale, child) => Transform.scale(
              scale: scale,
              child: child,
            ),
            child: Text(
              'You\'re all set!',
              style: TextStyle(
                fontSize: AppTypography.textXl,
                fontWeight: AppTypography.weightBold,
                color: textColor,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            'Here\'s your personalized scoring profile.',
            style: TextStyle(
              fontSize: AppTypography.textSm,
              color: subColor,
            ),
          ),
          const SizedBox(height: AppSpacing.s6),
          _summaryRow('Skill Level',
              (_skillLevel ?? 'intermediate').capitalize(), textColor, subColor),
          _summaryRow(
              'Wave Height',
              '${formatWaveHeight(_minWave)} – ${formatWaveHeight(_maxWave)} ft',
              textColor,
              subColor),
          _summaryRow('Max Wind', '${formatWindSpeed(_maxWind)} mph',
              textColor, subColor),
          _summaryRow(
              'Wind Direction',
              _windDir == 'any'
                  ? 'Any'
                  : _windDir == 'offshore'
                      ? 'Offshore'
                      : 'Onshore',
              textColor,
              subColor),
          _summaryRow(
              'Tide',
              _tide == 'any'
                  ? 'Any'
                  : '${_tide.capitalize()} tide',
              textColor,
              subColor),
        ],
      ),
    );
  }

  Widget _summaryRow(
      String label, String value, Color textColor, Color subColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: AppTypography.textSm,
              color: subColor,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: AppTypography.textSm,
              fontWeight: AppTypography.weightSemibold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

extension _StringCap on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
