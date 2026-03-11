import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/tokens.dart';
import '../logic/units.dart';
import '../models/user_prefs.dart';
import '../services/store_service.dart';
import '../state/preferences_provider.dart';
import '../state/store_provider.dart';
import '../state/health_import_provider.dart';
import '../state/ai_provider.dart';
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
  String _tide = 'mid';
  Map<String, double>? _weights;
  String? _surfStyle;

  // AI chat state
  bool _useAiChat = true;
  final List<Map<String, String>> _chatMessages = [];
  final _chatController = TextEditingController();
  final _chatScrollController = ScrollController();
  bool _isAiLoading = false;
  int _userMessageCount = 0;
  bool _isExtracting = false;
  bool _aiPrefsApplied = false;

  // Manual fallback
  bool _skillCardsVisible = false;

  // Summary fine-tune disclosure
  bool _showFineTune = false;

  /// Step layout:
  /// AI path:     [chat] → [health?] → [summary+finetune]
  /// Manual path: [skill] → [health?] → [sliders] → [confirm]
  int get _totalSteps {
    if (_useAiChat || _aiPrefsApplied) {
      return _healthAvailable ? 3 : 2;
    }
    return _healthAvailable ? 4 : 3;
  }

  int get _healthStep => 1;
  int get _prefsStep => _healthAvailable ? 2 : 1;
  int get _confirmStep {
    if (_useAiChat || _aiPrefsApplied) return _prefsStep; // summary IS the last step
    return _healthAvailable ? 3 : 2;
  }

  @override
  void initState() {
    super.initState();
    _checkHealthAvailability();
    _startAiChat();
  }

  Future<void> _checkHealthAvailability() async {
    try {
      final available =
          await ref.read(healthImportProvider.notifier).isAvailable();
      if (mounted) setState(() => _healthAvailable = available);
    } catch (_) {}
  }

  // ---- AI Chat Logic ----

  Future<void> _startAiChat() async {
    setState(() => _isAiLoading = true);

    try {
      final ai = ref.read(aiServiceProvider);
      final result = await ai.onboardingChat(
        messages: [
          {'role': 'user', 'content': 'Hi, I want to set up my surf profile.'},
        ],
        mode: 'chat',
      );

      if (!mounted) return;

      final reply = result['reply'] as String?;
      if (reply != null) {
        setState(() {
          _chatMessages.add({'role': 'assistant', 'content': reply});
          _isAiLoading = false;
        });
        _scrollToBottom();
      } else {
        _fallbackToManual();
      }
    } catch (_) {
      if (mounted) _fallbackToManual();
    }
  }

  void _fallbackToManual() {
    setState(() {
      _useAiChat = false;
      _isAiLoading = false;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _skillCardsVisible = true);
    });
  }

  Future<void> _sendChatMessage(String text) async {
    if (text.trim().isEmpty || _isAiLoading) return;

    _chatController.clear();
    HapticFeedback.lightImpact();

    setState(() {
      _chatMessages.add({'role': 'user', 'content': text.trim()});
      _userMessageCount++;
      _isAiLoading = true;
    });
    _scrollToBottom();

    // After 3 user messages, extract prefs and advance
    if (_userMessageCount >= 3) {
      await _extractAndAdvance();
      return;
    }

    try {
      final ai = ref.read(aiServiceProvider);
      final apiMessages = _chatMessages
          .map((m) => {'role': m['role']!, 'content': m['content']!})
          .toList();

      final result = await ai.onboardingChat(
        messages: apiMessages,
        mode: 'chat',
      );

      if (!mounted) return;

      final reply = result['reply'] as String?;
      if (reply != null) {
        setState(() {
          _chatMessages.add({'role': 'assistant', 'content': reply});
          _isAiLoading = false;
        });
        _scrollToBottom();
      } else {
        if (_userMessageCount >= 2) {
          await _extractAndAdvance();
        } else {
          _fallbackToManual();
        }
      }
    } catch (_) {
      if (mounted) {
        if (_userMessageCount >= 2) {
          await _extractAndAdvance();
        } else {
          _fallbackToManual();
        }
      }
    }
  }

  Future<void> _extractAndAdvance() async {
    if (!mounted) return;

    setState(() {
      _isExtracting = true;
      _isAiLoading = true;
    });

    try {
      final ai = ref.read(aiServiceProvider);
      final apiMessages = _chatMessages
          .map((m) => {'role': m['role']!, 'content': m['content']!})
          .toList();

      final result = await ai.onboardingChat(
        messages: apiMessages,
        mode: 'extract',
      );

      if (!mounted) return;

      final prefs = result['prefs'] as Map<String, dynamic>?;
      if (prefs != null) {
        _applyAiPrefs(prefs);
      } else {
        _applyDefaults('intermediate');
      }
    } catch (_) {
      _applyDefaults('intermediate');
    }

    if (!mounted) return;

    setState(() {
      _isExtracting = false;
      _isAiLoading = false;
    });

    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) _next();
  }

  void _applyAiPrefs(Map<String, dynamic> prefs) {
    setState(() {
      _skillLevel = prefs['skillLevel'] as String? ?? 'intermediate';

      final minWH = (prefs['minWaveHeight'] as num?)?.toDouble();
      if (minWH != null) _minWave = minWH;

      final maxWH = (prefs['maxWaveHeight'] as num?)?.toDouble();
      if (maxWH != null) _maxWave = maxWH;

      final maxWS = (prefs['maxWindSpeed'] as num?)?.toDouble();
      if (maxWS != null) _maxWind = maxWS;

      final tide = prefs['preferredTide'] as String?;
      if (tide != null) _tide = tide;

      final rawWeights = prefs['weights'] as Map<String, dynamic>?;
      if (rawWeights != null) {
        _weights = rawWeights
            .map((k, v) => MapEntry(k, (v as num).toDouble()));
      }

      _surfStyle = prefs['surfStyle'] as String?;

      if (_maxWave < _minWave + 0.2) _maxWave = _minWave + 0.2;

      _aiPrefsApplied = true;
    });
  }

  void _applyDefaults(String skill) {
    _skillLevel = skill;
    final defaults = skillDefaults[skill]!;
    _minWave = defaults.minWaveHeight ?? 0.3;
    _maxWave = defaults.maxWaveHeight ?? 1.0;
    _maxWind = defaults.maxWindSpeed ?? 20.0;
    _tide = defaults.preferredTide ?? 'mid';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: AppDurations.base,
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ---- Manual Fallback Logic ----

  void _selectSkill(String skill) {
    HapticFeedback.selectionClick();
    setState(() {
      _applyDefaults(skill);
    });
  }

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
      if (p.preferredTide != null) _tide = p.preferredTide!;
    });
  }

  // ---- Navigation ----

  void _next() {
    if (_currentStep < _totalSteps - 1) {
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
    _skillLevel = 'intermediate';
    _finish();
  }

  Future<void> _finish() async {
    final prefs = UserPrefs(
      skillLevel: _skillLevel,
      minWaveHeight: _minWave,
      maxWaveHeight: _maxWave,
      maxWindSpeed: _maxWind,
      preferredTide: _tide,
      weights: _weights,
      surfStyle: _surfStyle,
    );
    await ref.read(preferencesProvider.notifier).update(prefs);
    await ref.read(storeServiceProvider).setOnboarded();
    widget.onComplete();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  // ---- Bottom Bar Logic ----

  String get _nextLabel {
    if (_currentStep == 0) {
      if (_useAiChat) return '';
      return _skillLevel != null ? 'Continue' : 'Select a Level';
    }
    if (_healthAvailable && _currentStep == _healthStep) return '';
    if (_currentStep == _prefsStep) {
      if (_aiPrefsApplied && !_showFineTune) return 'Looks Good';
      if (_aiPrefsApplied) return 'Start Surfing';
      return 'Review';
    }
    return 'Start Surfing';
  }

  bool get _showBottomButtons {
    if (_currentStep == 0 && _useAiChat) return false;
    if (_healthAvailable && _currentStep == _healthStep) return false;
    return true;
  }

  // ---- Build ----

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
            // Top bar with dot indicators
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
                  // Step 0: AI Chat or Skill Cards
                  _useAiChat
                      ? _buildChatStep(textColor, subColor, isDark)
                      : _buildSkillStep(textColor, subColor, isDark),
                  // Step 1 (optional): HealthKit
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
                  // Step 2: AI Summary or Manual Sliders
                  _aiPrefsApplied
                      ? _buildSummaryStep(textColor, subColor, isDark)
                      : _buildPrefsStep(textColor, subColor),
                  // Step 3 (manual only): Confirm
                  if (!_useAiChat && !_aiPrefsApplied)
                    _buildConfirmStep(textColor, subColor),
                ],
              ),
            ),

            // Bottom buttons
            if (_showBottomButtons)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.s4),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_currentStep == 0 && !_useAiChat && _skillLevel == null)
                            ? null
                            : () {
                                // On AI summary, "Looks Good" or "Start Surfing" finishes
                                if (_aiPrefsApplied && _currentStep == _prefsStep) {
                                  _finish();
                                } else {
                                  _next();
                                }
                              },
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

  // ===========================================================================
  // Step 0A: AI Chat
  // ===========================================================================

  Widget _buildChatStep(Color textColor, Color subColor, bool isDark) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.s2),
              Icon(Icons.waves, size: 32, color: AppColors.accent),
              const SizedBox(height: AppSpacing.s2),
              Text(
                'Tell us about your surfing',
                style: TextStyle(
                  fontSize: AppTypography.textLg,
                  fontWeight: AppTypography.weightBold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Quick chat to personalize your scoring',
                style: TextStyle(
                  fontSize: AppTypography.textSm,
                  color: subColor,
                ),
              ),
              const SizedBox(height: AppSpacing.s3),
            ],
          ),
        ),

        // Messages
        Expanded(
          child: ListView.builder(
            controller: _chatScrollController,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
            itemCount: _chatMessages.length + (_isAiLoading ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == _chatMessages.length) {
                return _buildLoadingBubble(isDark);
              }
              return _buildMessageBubble(_chatMessages[i], isDark);
            },
          ),
        ),

        // Extracting indicator
        if (_isExtracting)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.s3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: AppSpacing.s2),
                Text(
                  'Setting up your profile...',
                  style: TextStyle(
                    fontSize: AppTypography.textSm,
                    color: AppColors.accent,
                    fontWeight: AppTypography.weightMedium,
                  ),
                ),
              ],
            ),
          ),

        // Input bar
        if (!_isExtracting)
          _buildChatInput(isDark, subColor),

        // Skip links
        if (!_isExtracting)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: _fallbackToManual,
                  child: Text(
                    'Set up manually instead',
                    style: TextStyle(
                      fontSize: AppTypography.textXs,
                      color: subColor,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s4),
                TextButton(
                  onPressed: _skipAsGuest,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      fontSize: AppTypography.textXs,
                      color: subColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildChatInput(bool isDark, Color subColor) {
    final bgColor = isDark ? AppColorsDark.bgSecondary : AppColors.bgSecondary;
    final inputColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s4,
        vertical: AppSpacing.s2,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: AppShadows.sm,
              ),
              child: TextField(
                controller: _chatController,
                style: TextStyle(
                  fontSize: AppTypography.textSm,
                  color: inputColor,
                ),
                decoration: InputDecoration(
                  hintText: _userMessageCount == 0
                      ? 'Tell me about your surfing...'
                      : 'Type your answer...',
                  hintStyle: TextStyle(
                    fontSize: AppTypography.textSm,
                    color: subColor,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s4,
                    vertical: AppSpacing.s3,
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: _sendChatMessage,
                enabled: !_isAiLoading,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s2),
          GestureDetector(
            onTap: _isAiLoading
                ? null
                : () => _sendChatMessage(_chatController.text),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _isAiLoading
                    ? AppColors.accent.withValues(alpha: 0.3)
                    : AppColors.accent,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_upward,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, String> message, bool isDark) {
    final isUser = message['role'] == 'user';
    final bgColor = isUser
        ? AppColors.accent
        : (isDark ? AppColorsDark.bgSecondary : AppColors.bgSecondary);
    final textColor = isUser
        ? Colors.white
        : (isDark ? AppColorsDark.textPrimary : AppColors.textPrimary);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Transform.translate(
        offset: Offset((isUser ? 1 : -1) * 24 * (1 - value), 0),
        child: Opacity(opacity: value, child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.s2),
        child: Row(
          mainAxisAlignment:
              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isUser) const SizedBox(width: 4),
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s3,
                  vertical: AppSpacing.s2,
                ),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(AppRadius.md),
                    topRight: const Radius.circular(AppRadius.md),
                    bottomLeft: Radius.circular(isUser ? AppRadius.md : 4),
                    bottomRight: Radius.circular(isUser ? 4 : AppRadius.md),
                  ),
                  boxShadow: AppShadows.sm,
                ),
                child: Text(
                  message['content'] ?? '',
                  style: TextStyle(
                    fontSize: AppTypography.textSm,
                    color: textColor,
                    height: 1.4,
                  ),
                ),
              ),
            ),
            if (isUser) const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingBubble(bool isDark) {
    final bgColor =
        isDark ? AppColorsDark.bgSecondary : AppColors.bgSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s4,
              vertical: AppSpacing.s3,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.md),
                topRight: Radius.circular(AppRadius.md),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(AppRadius.md),
              ),
              boxShadow: AppShadows.sm,
            ),
            child: _TypingDots(color: AppColors.accent),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Step 0B: Skill Level (manual fallback)
  // ===========================================================================

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
    return SingleChildScrollView(
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

  // ===========================================================================
  // Step 2A: AI Summary (with fine-tune disclosure)
  // ===========================================================================

  String _waveDescription() {
    final maxFt = metersToFeet(_maxWave);
    if (maxFt <= 2) return 'Small, mellow waves';
    if (maxFt <= 4) return 'Moderate, fun-sized waves';
    if (maxFt <= 6) return 'Solid, head-high+ waves';
    return 'Big, powerful waves';
  }

  String _windDescription() {
    final mph = kmhToMph(_maxWind);
    if (mph <= 10) return 'Glassy to light breeze';
    if (mph <= 20) return 'Up to moderate wind';
    if (mph <= 35) return 'Handles breezy conditions';
    return 'Any wind conditions';
  }

  String _tideDescription() {
    switch (_tide) {
      case 'low':
        return 'Prefers low tide';
      case 'mid':
        return 'Best at mid tide';
      case 'high':
        return 'Prefers high tide';
      default:
        return 'Any tide works';
    }
  }

  String _weightEmphasis() {
    if (_weights == null) return '';
    final h = _weights!['height'] ?? 0.4;
    final d = _weights!['swellDir'] ?? 0.3;
    final q = _weights!['swellQuality'] ?? 0.3;
    final max = [h, d, q].reduce((a, b) => a > b ? a : b);
    if (max == h) return 'Tuned for wave size';
    if (max == q) return 'Tuned for wave quality';
    return 'Tuned for swell direction';
  }

  Widget _buildSummaryStep(Color textColor, Color subColor, bool isDark) {
    final cardBg = isDark ? AppColorsDark.bgSecondary : AppColors.bgSecondary;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.s4),
          Center(
            child: _buildStepIcon(Icons.auto_awesome, AppColors.accent),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            'Here\'s your surf profile',
            style: TextStyle(
              fontSize: AppTypography.textXl,
              fontWeight: AppTypography.weightBold,
              color: textColor,
            ),
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            'Based on our chat, here\'s your personalized setup.',
            style: TextStyle(
              fontSize: AppTypography.textSm,
              color: subColor,
            ),
          ),
          const SizedBox(height: AppSpacing.s5),

          // Skill + Style card
          _prefSummaryCard(
            icon: Icons.person,
            title: '${(_skillLevel ?? 'intermediate').capitalize()} surfer',
            detail: _surfStyle != null
                ? '${_surfStyle!.capitalize()} style'
                : null,
            cardBg: cardBg,
            textColor: textColor,
            subColor: subColor,
          ),
          const SizedBox(height: AppSpacing.s3),

          // Wave
          _prefSummaryCard(
            icon: Icons.waves,
            title: _waveDescription(),
            detail:
                '${formatWaveHeight(_minWave)} – ${formatWaveHeight(_maxWave)} ft',
            cardBg: cardBg,
            textColor: textColor,
            subColor: subColor,
          ),
          const SizedBox(height: AppSpacing.s3),

          // Wind
          _prefSummaryCard(
            icon: Icons.air,
            title: _windDescription(),
            detail: 'Up to ${formatWindSpeed(_maxWind)} mph',
            cardBg: cardBg,
            textColor: textColor,
            subColor: subColor,
          ),
          const SizedBox(height: AppSpacing.s3),

          // Tide
          _prefSummaryCard(
            icon: Icons.water,
            title: _tideDescription(),
            detail: _tide == 'any' ? 'Any' : '${_tide.capitalize()} tide',
            cardBg: cardBg,
            textColor: textColor,
            subColor: subColor,
          ),

          // Weight emphasis badge
          if (_weights != null) ...[
            const SizedBox(height: AppSpacing.s4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_awesome,
                    size: 14, color: AppColors.accent),
                const SizedBox(width: AppSpacing.s1),
                Text(
                  _weightEmphasis(),
                  style: TextStyle(
                    fontSize: AppTypography.textSm,
                    color: AppColors.accent,
                    fontWeight: AppTypography.weightMedium,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: AppSpacing.s5),

          // Fine-tune disclosure
          if (!_showFineTune)
            Center(
              child: TextButton.icon(
                onPressed: () => setState(() => _showFineTune = true),
                icon: Icon(Icons.tune, size: 16, color: subColor),
                label: Text(
                  'Fine-tune these settings',
                  style: TextStyle(
                    fontSize: AppTypography.textSm,
                    color: subColor,
                  ),
                ),
              ),
            ),

          // Expanded sliders when fine-tune is tapped
          if (_showFineTune) ...[
            const Divider(),
            const SizedBox(height: AppSpacing.s3),
            Text(
              'Adjust your preferences',
              style: TextStyle(
                fontSize: AppTypography.textBase,
                fontWeight: AppTypography.weightSemibold,
                color: textColor,
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
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
            _chipGroup(
              label: 'Tide',
              options: const ['low', 'mid', 'high', 'any'],
              display: const ['Low', 'Mid', 'High', 'Any'],
              selected: _tide,
              textColor: textColor,
              onSelected: (v) => setState(() => _tide = v),
            ),
          ],

          const SizedBox(height: AppSpacing.s6),
        ],
      ),
    );
  }

  Widget _prefSummaryCard({
    required IconData icon,
    required String title,
    required String? detail,
    required Color cardBg,
    required Color textColor,
    required Color subColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.accent),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: AppTypography.textSm,
                    fontWeight: AppTypography.weightMedium,
                    color: textColor,
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: TextStyle(
                      fontFamily: AppTypography.fontMono,
                      fontSize: AppTypography.textXs,
                      color: subColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Step 2B: Preference Sliders (manual path)
  // ===========================================================================

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

  // ===========================================================================
  // Step 3: Confirmation (manual path only)
  // ===========================================================================

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
            'Here\'s your scoring profile.',
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

  // ===========================================================================
  // Shared Widgets
  // ===========================================================================

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
              onSelected: (_) {
                HapticFeedback.selectionClick();
                onSelected(options[i]);
              },
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

/// Animated typing dots indicator
class _TypingDots extends StatefulWidget {
  final Color color;
  const _TypingDots({required this.color});

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final t = (_controller.value - delay).clamp(0.0, 1.0);
            final scale = 0.5 + 0.5 * (1 - (2 * t - 1).abs());
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.3 + 0.7 * scale),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

extension _StringCap on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
