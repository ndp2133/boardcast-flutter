# Boardcast Flutter

Flutter port of the Boardcast PWA surf conditions tracker. Native iOS + Android with home screen widgets.

## Commands

```bash
# Run tests
flutter test

# Run app on connected device/emulator
flutter run

# Build release APK
flutter build apk --release

# Build iOS
flutter build ios --release
```

## Architecture

Feature-first structure. Pure business logic is separated from UI in `lib/logic/`.

### Directory Structure

```
lib/
  models/       — Data classes with fromJson/toJson (Location, HourlyData, Session, etc.)
  logic/        — Pure functions (scoring, boards, surfiq, moon, units, time, locations)
  theme/        — Design tokens (colors, spacing, typography from PWA variables.css)
  services/     — API, Supabase, Hive (Phase 1+)
  state/        — Riverpod providers (Phase 2+)
  views/        — Screen widgets (Phase 3+)
  components/   — Reusable widgets (Phase 3+)
test/
  logic/        — Unit tests for all pure functions
  models/       — Model serialization tests
```

### Key Design Decisions

- **Location passed explicitly** to scoring functions (no global state, unlike JS version)
- **Riverpod** for state management
- **Hive** for local storage (replaces localStorage)
- **Syncfusion charts** (free community license) for dual-axis forecast charts
- All business logic is identical to the PWA (same weights, thresholds, constants)

## Data Sources

Same as PWA:
- Open-Meteo Marine + Weather APIs (free, no key)
- NOAA CO-OPS tides
- Supabase backend (shared with PWA — same tables, same RLS)

## Code Conventions

- Dart 3.11+, null safety throughout
- No semicolons... wait, Dart requires them. Standard Dart style.
- Models use `const` constructors where possible
- Logic functions are pure (no side effects, testable in isolation)
- 11 surf locations across NY/NJ, CA, FL

## Current Status

Phase 0 complete: scaffolding, models, logic, theme tokens, 122 passing tests.
