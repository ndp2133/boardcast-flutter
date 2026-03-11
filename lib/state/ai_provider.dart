/// AI state providers — surf tip, surf query, LLM summary
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ai_service.dart';
import '../services/ai_limits.dart';
import '../services/supabase_service.dart';
import '../logic/ai_formatters.dart';
import '../logic/scoring.dart';
import '../logic/units.dart';
import 'conditions_provider.dart';
import 'location_provider.dart';
import 'preferences_provider.dart';

/// Simple state for AI responses
class AiState {
  final AiStatus status;
  final String? text;
  final String? error;

  const AiState({this.status = AiStatus.idle, this.text, this.error});

  AiState copyWith({AiStatus? status, String? text, String? error}) => AiState(
        status: status ?? this.status,
        text: text ?? this.text,
        error: error ?? this.error,
      );
}

enum AiStatus { idle, loading, loaded, error }

/// Singleton AI service
final aiServiceProvider = Provider<AiService>((ref) {
  return AiService(supabase);
});

/// AI rate-limiting service (initialized in main, overridden in ProviderScope)
final aiLimitsServiceProvider = Provider<AiLimitsService>((ref) {
  return AiLimitsService();
});

/// Build location payload for AI Edge Functions
Map<String, dynamic> _buildLocationPayload(location) => {
      'name': location.name,
      'breakType': location.breakType,
      'description': location.description,
    };

/// Compute pro perspective scores for AI context
({int score, String label}) _computeProPerspective(
    hourData, location, tideRange) {
  final proScore = computeMatchScore(
    hourData,
    proPrefs,
    location,
    tideRange: tideRange,
  );
  return (
    score: (proScore * 100).round(),
    label: getConditionLabel(proScore).label,
  );
}

// ---------------------------------------------------------------------------
// Surf Tip — user-initiated "Get Surf Tip"
// ---------------------------------------------------------------------------

class SurfTipNotifier extends Notifier<AiState> {
  @override
  AiState build() => const AiState();

  Future<void> fetchTip() async {
    final limits = ref.read(aiLimitsServiceProvider);
    if (!limits.canUseTip()) {
      state = const AiState(
        status: AiStatus.error,
        error: 'Daily tip limit reached. Check back tomorrow!',
      );
      return;
    }

    state = const AiState(status: AiStatus.loading);

    try {
      final conditionsAsync = ref.read(conditionsProvider);
      final data = conditionsAsync.valueOrNull;
      if (data == null) {
        state = const AiState(
            status: AiStatus.error,
            error: 'No conditions data. Try refreshing first.');
        return;
      }

      final location = ref.read(selectedLocationProvider);
      final prefs = ref.read(preferencesProvider);
      final ai = ref.read(aiServiceProvider);

      final current = data.current;
      final tideRange = TideRange.fromHourlyData(data.hourly);
      final currentHour =
          data.hourly.isNotEmpty ? data.hourly.first : null;
      final score = computeMatchScore(
        currentHour,
        prefs,
        location,
        tideRange: tideRange,
      );
      final condLabel = getConditionLabel(score);
      final pro = _computeProPerspective(currentHour, location, tideRange);

      final conditions = {
        'waveHeight': current.waveHeight != null
            ? metersToFeet(current.waveHeight!).toStringAsFixed(1)
            : '--',
        'windSpeed': current.windSpeed != null
            ? kmhToMph(current.windSpeed!).round().toString()
            : '--',
        'windDirection': current.windDirection != null
            ? degreesToCardinal(current.windDirection!)
            : '--',
        'swellPeriod': current.swellPeriod != null
            ? current.swellPeriod!.toStringAsFixed(1)
            : '--',
        'tideHeight': current.tideHeight != null
            ? current.tideHeight!.toStringAsFixed(1)
            : '--',
        'tideTrend': current.tideTrend ?? '--',
      };

      final prefsPayload = buildPrefsPayload(prefs);

      final tip = await ai.fetchSurfTip(
        conditions: conditions,
        prefs: prefsPayload,
        location: _buildLocationPayload(location),
        matchScore: score,
        conditionLabel: condLabel.label,
        proScore: pro.score,
        proCondition: pro.label,
      );

      limits.recordTipUsage();
      state = AiState(status: AiStatus.loaded, text: tip);
    } catch (e) {
      state = AiState(
        status: AiStatus.error,
        error: "Couldn't get The Call right now. Check your connection.",
      );
    }
  }
}

final surfTipProvider =
    NotifierProvider<SurfTipNotifier, AiState>(SurfTipNotifier.new);

// ---------------------------------------------------------------------------
// Surf Query — user-initiated natural language question
// ---------------------------------------------------------------------------

class SurfQueryNotifier extends Notifier<AiState> {
  @override
  AiState build() => const AiState();

  Future<void> submitQuery(String query) async {
    if (query.trim().isEmpty) return;

    final limits = ref.read(aiLimitsServiceProvider);
    if (!limits.canUseQuery()) {
      state = const AiState(
        status: AiStatus.error,
        error: 'Daily question limit reached. Check back tomorrow!',
      );
      return;
    }

    state = AiState(status: AiStatus.loading, text: 'Thinking about "$query"...');

    try {
      final conditionsAsync = ref.read(conditionsProvider);
      final data = conditionsAsync.valueOrNull;
      if (data == null) {
        state = const AiState(
            status: AiStatus.error,
            error: 'No forecast data. Try refreshing first.');
        return;
      }

      final location = ref.read(selectedLocationProvider);
      final prefs = ref.read(preferencesProvider);
      final ai = ref.read(aiServiceProvider);

      final tideRange = TideRange.fromHourlyData(data.hourly);
      final currentHour =
          data.hourly.isNotEmpty ? data.hourly.first : null;
      final pro = _computeProPerspective(currentHour, location, tideRange);

      final currentStr = formatCurrentConditions(data.current);
      final dailyStr = formatDailySummaries(data.daily, data.hourly);
      final windows = findTopWindows(data.hourly, prefs, location, count: 3);
      final windowsStr = formatTopWindows(windows);
      final prefsPayload = buildPrefsPayload(prefs);

      final answer = await ai.fetchSurfQuery(
        query: query,
        current: currentStr,
        dailySummaries: dailyStr,
        prefs: prefsPayload,
        location: _buildLocationPayload(location),
        topWindows: windowsStr,
        proScore: pro.score,
        proCondition: pro.label,
      );

      limits.recordQueryUsage();
      state = AiState(status: AiStatus.loaded, text: answer);
    } catch (e) {
      state = AiState(
        status: AiStatus.error,
        error: "Couldn't get The Call right now. Check your connection.",
      );
    }
  }
}

final surfQueryProvider =
    NotifierProvider<SurfQueryNotifier, AiState>(SurfQueryNotifier.new);

// ---------------------------------------------------------------------------
// LLM Summary — auto-fires when conditions load, crossfades on dashboard
// ---------------------------------------------------------------------------

class LlmSummaryNotifier extends Notifier<AiState> {
  String? _lastLocationId;

  @override
  AiState build() => const AiState();

  Future<void> fetch({
    required String ruleBasedSummary,
    required String locationId,
  }) async {
    // Guard against duplicate/stale requests
    if (state.status == AiStatus.loading && _lastLocationId == locationId) {
      return;
    }

    // Rate limit — silently fall back to rule-based summary
    final limits = ref.read(aiLimitsServiceProvider);
    if (!limits.canUseSummary()) {
      state = const AiState(status: AiStatus.idle);
      return;
    }

    _lastLocationId = locationId;
    state = const AiState(status: AiStatus.loading);

    try {
      final conditionsAsync = ref.read(conditionsProvider);
      final data = conditionsAsync.valueOrNull;
      if (data == null) {
        state = const AiState(status: AiStatus.idle);
        return;
      }

      final location = ref.read(selectedLocationProvider);
      final prefs = ref.read(preferencesProvider);
      final ai = ref.read(aiServiceProvider);

      final tideRange = TideRange.fromHourlyData(data.hourly);
      final currentHour =
          data.hourly.isNotEmpty ? data.hourly.first : null;
      final pro = _computeProPerspective(currentHour, location, tideRange);

      final currentStr = formatCurrentConditions(data.current);
      final dailyStr = formatDailySummaries(data.daily, data.hourly);
      final prefsPayload = buildPrefsPayload(prefs);

      final bestWindow = findBestWindow(data.hourly, prefs, location);
      final bestWindowStr = bestWindow != null
          ? formatTopWindows([bestWindow])
          : null;

      // Race condition guard: if location changed while we were building context
      if (_lastLocationId != locationId) return;

      final summary = await ai.fetchForecastSummary(
        current: currentStr,
        daily: dailyStr,
        prefs: prefsPayload,
        location: _buildLocationPayload(location),
        ruleBased: ruleBasedSummary,
        bestWindow: bestWindowStr,
        proScore: pro.score,
        proCondition: pro.label,
      );

      // Race condition guard: if location changed during the fetch
      if (_lastLocationId != locationId) return;

      if (summary != null) {
        limits.recordSummaryUsage();
        state = AiState(status: AiStatus.loaded, text: summary);
      } else {
        state = const AiState(status: AiStatus.idle);
      }
    } catch (_) {
      // Silently fall back to rule-based summary
      state = const AiState(status: AiStatus.idle);
    }
  }

  void reset() {
    _lastLocationId = null;
    state = const AiState();
  }
}

final llmSummaryProvider =
    NotifierProvider<LlmSummaryNotifier, AiState>(LlmSummaryNotifier.new);
