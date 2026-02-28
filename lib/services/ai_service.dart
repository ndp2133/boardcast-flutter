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
    required String locationName,
    required double matchScore,
    required String conditionLabel,
  }) async {
    final response = await _supabase.functions.invoke(
      'surf-coach',
      body: {
        'conditions': conditions,
        'prefs': prefs,
        'location': locationName,
        'matchScore': matchScore,
        'conditionLabel': conditionLabel,
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
    required String locationName,
    required String topWindows,
  }) async {
    final response = await _supabase.functions.invoke(
      'surf-query',
      body: {
        'query': query,
        'current': current,
        'dailySummaries': dailySummaries,
        'prefs': prefs,
        'location': {'name': locationName},
        'topWindows': topWindows,
      },
    );

    final data = response.data as Map<String, dynamic>?;
    return data?['answer'] as String? ??
        "Couldn't generate an answer. Try rephrasing!";
  }

  /// Get an LLM-enhanced forecast summary from forecast-summary.
  /// Returns null if the Edge Function fails (caller falls back to rule-based).
  Future<String?> fetchForecastSummary({
    required String current,
    required String daily,
    Map<String, dynamic>? prefs,
    required String locationName,
    required String ruleBased,
    String? bestWindow,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'forecast-summary',
        body: {
          'current': current,
          'daily': daily,
          'prefs': prefs,
          'location': {'name': locationName},
          'ruleBased': ruleBased,
          if (bestWindow != null) 'bestWindow': bestWindow,
        },
      );

      final data = response.data as Map<String, dynamic>?;
      return data?['summary'] as String?;
    } catch (_) {
      return null;
    }
  }
}
