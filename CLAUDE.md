# Boardcast Flutter

Flutter port of the Boardcast PWA surf conditions tracker. Native iOS + Android with home screen widgets, Siri Shortcuts, and Live Activities.

## Tech Stack

Flutter/Dart 3.11+, Riverpod, Hive, Supabase, Syncfusion charts, WidgetKit (iOS), Jetpack Glance (Android).

## Commands

```bash
flutter test                      # Run tests
flutter run -d chrome             # Run on Chrome
flutter run -d macos              # Run on macOS desktop
flutter build apk --release       # Build release APK
flutter build ios --release       # Build iOS (requires Xcode)
```

## Architecture

```
lib/
  models/       — Data classes with fromJson/toJson
  logic/        — Pure functions (scoring, boards, surfiq, moon, units, time, locations, ai_formatters)
  theme/        — Design tokens (colors, spacing, typography)
  services/     — API, cache, conditions repository, Supabase, auth, store, AI, widgets
  state/        — Riverpod providers (auth, conditions, prefs, sessions, boards, location, theme, AI)
  views/        — Screen widgets (dashboard, forecast, tracking, history, onboarding, shell)
  components/   — Reusable widgets (score ring, metrics, charts, surf coach, share cards)
test/
  logic/        — Unit tests for pure functions
  services/     — API normalization, merge, serialization tests
  models/       — Model serialization tests
```

See `.claude/rules/` for component details, AI features, theming, and widgets.

## Dual-Codebase Parity (CRITICAL)

This Flutter app shares business logic with `../boardcast/` (PWA). Any change to scoring, locations, skill defaults, or AI payloads MUST be mirrored in the PWA. See `../shared/` for canonical config and `.claude/rules/parity.md` for details.

## Data Sources

- Open-Meteo Marine + Weather APIs (free, no key; use `cell_selection=sea`)
- NOAA CO-OPS tides
- Supabase backend (shared with PWA -- same tables, same RLS)

## Current Status

262 passing tests. Full feature parity with PWA. Scoring engine v2.2. App Store Connect listing populated, TestFlight builds live, RevenueCat production key active. Pending: App Store submission, Google Play submission.
