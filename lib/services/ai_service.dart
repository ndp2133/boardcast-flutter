/// AI service — thin wrapper around Supabase Edge Functions.
/// Three endpoints: surf-coach (tips), surf-query (NL Q&A), forecast-summary (LLM summary).
import 'package:supabase_flutter/supabase_flutter.dart';

class AiService {
  final SupabaseClient _supabase;

  AiService(this._supabase);

  /// Get a personalized surf tip from the surf-coach Edge Function.
  Future<String> fetchSurfTip({
    required Map<String, dynamic> conditions,
    required Map<String, dynamic> prefs,
    required Map<String, dynamic> location,
    required double matchScore,
    required String conditionLabel,
    required int proScore,
    required String proCondition,
  }) async {
    final response = await _supabase.functions.invoke(
      'surf-coach',
      body: {
        'conditions': conditions,
        'prefs': prefs,
        'location': location,
        'matchScore': matchScore,
        'conditionLabel': conditionLabel,
        'proScore': proScore,
        'proCondition': proCondition,
      },
    );

    final data = response.data as Map<String, dynamic>?;
    return data?['tip'] as String? ??
        'No tip available right now. Check back later!';
  }

  /// Get an answer to a natural-language surf question from surf-query.
  Future<String> fetchSurfQuery({
    required String query,
    required String current,
    required String dailySummaries,
    Map<String, dynamic>? prefs,
    required Map<String, dynamic> location,
    required String topWindows,
    required int proScore,
    required String proCondition,
  }) async {
    final response = await _supabase.functions.invoke(
      'surf-query',
      body: {
        'query': query,
        'current': current,
        'dailySummaries': dailySummaries,
        'prefs': prefs,
        'location': location,
        'topWindows': topWindows,
        'proScore': proScore,
        'proCondition': proCondition,
      },
    );

    final data = response.data as Map<String, dynamic>?;
    return data?['answer'] as String? ??
        "Couldn't generate an answer. Try rephrasing!";
  }

  /// Onboarding chat — multi-turn conversation for preference extraction.
  /// [mode] is 'chat' for conversation or 'extract' for structured pref extraction.
  Future<Map<String, dynamic>> onboardingChat({
    required List<Map<String, String>> messages,
    required String mode,
  }) async {
    final response = await _supabase.functions.invoke(
      'onboarding-chat',
      body: {
        'messages': messages,
        'mode': mode,
      },
    );

    return response.data as Map<String, dynamic>? ?? {};
  }

  /// Get an LLM-enhanced forecast summary from forecast-summary.
  /// Returns null if the Edge Function fails (caller falls back to rule-based).
  Future<String?> fetchForecastSummary({
    required String current,
    required String daily,
    Map<String, dynamic>? prefs,
    required Map<String, dynamic> location,
    required String ruleBased,
    String? bestWindow,
    required int proScore,
    required String proCondition,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'forecast-summary',
        body: {
          'current': current,
          'daily': daily,
          'prefs': prefs,
          'location': location,
          'ruleBased': ruleBased,
          if (bestWindow != null) 'bestWindow': bestWindow,
          'proScore': proScore,
          'proCondition': proCondition,
        },
      );

      final data = response.data as Map<String, dynamic>?;
      return data?['summary'] as String?;
    } catch (_) {
      return null;
    }
  }
}
