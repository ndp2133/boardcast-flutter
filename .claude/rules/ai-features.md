---
description: AI integration patterns and payload formatting
globs: lib/services/ai_*.dart,lib/utils/ai_*.dart
---

# AI Features

Three Supabase Edge Functions (source in Supabase dashboard, not this repo):
- **surf-coach** -- Claude Sonnet for personalized coaching tips based on current conditions + user prefs
- **surf-query** -- Claude Haiku for natural language Q&A with full forecast context (current + daily + top windows)
- **forecast-summary** -- Claude for LLM-enhanced forecast summary (crossfades from rule-based on dashboard)

## Flutter-side Architecture

- `lib/logic/ai_formatters.dart` -- Pure functions to format conditions/daily/windows into compact AI payloads. Converts metric to imperial, builds prefs map.
- `lib/services/ai_service.dart` -- Thin async wrapper around `supabase.functions.invoke()`.
- `lib/state/ai_provider.dart` -- Three Riverpod Notifiers (not FutureProvider, since tips/queries are user-initiated).
  - `LlmSummaryNotifier` auto-fires when conditions resolve, guards against location change race conditions.
