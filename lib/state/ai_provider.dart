/// AI state providers — surf tip, surf query, LLM summary
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ai_service.dart';
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

// ---------------------------------------------------------------------------
// Surf Tip — user-initiated "Get Surf Tip"
// ---------------------------------------------------------------------------

class SurfTipNotifier extends Notifier<AiState> {
  @override
  AiState build() => const AiState();

  Future<void> fetchTip() async {
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
      final score = computeMatchScore(
        data.hourly.isNotEmpty ? data.hourly.first : null,
        prefs,
        location,
      );
      final condLabel = getConditionLabel(score);

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
        locationName: location.name,
        matchScore: score,
        conditionLabel: condLabel.label,
      );

      state = AiState(status: AiStatus.loaded, text: tip);
    } catch (e) {
      state = AiState(
        status: AiStatus.error,
        error: "Couldn't reach the surf coach. Check your connection.",
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
        locationName: location.name,
        topWindows: windowsStr,
      );

      state = AiState(status: AiStatus.loaded, text: answer);
    } catch (e) {
      state = AiState(
        status: AiStatus.error,
        error: "Couldn't reach the AI coach. Check your connection.",
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
        locationName: location.name,
        ruleBased: ruleBasedSummary,
        bestWindow: bestWindowStr,
      );

      // Race condition guard: if location changed during the fetch
      if (_lastLocationId != locationId) return;

      if (summary != null) {
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
