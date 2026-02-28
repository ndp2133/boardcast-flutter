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
  services/     — API fetch/normalize/merge, Supabase client, Hive cache, conditions repository
  state/        — Riverpod providers (Phase 2+)
  views/        — Screen widgets (Phase 3+)
  components/   — Reusable widgets (Phase 3+)
test/
  logic/        — Unit tests for all pure functions
  services/     — API normalization, merge, serialization round-trip tests
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

## Services Architecture

- **api_service.dart** — fetch + normalize for Open-Meteo Marine, Open-Meteo Weather, NOAA Tides. `mergeConditions()` joins all three by time key and filters daily entries with null waveHeightMax.
- **cache_service.dart** — Hive-backed per-location conditions cache. Cached data always returns with `isStale: true`.
- **conditions_repository.dart** — Orchestrates API fetch + cache. Memory cache first, Hive fallback, offline-first pattern matching the PWA.
- **supabase_service.dart** — Client init. Same project/anon key as PWA.
- **auth_service.dart** — Supabase auth (email/password, Google OAuth, state stream).
- **store_service.dart** — Write-through persistence: Hive first (instant), Supabase async push. CRUD for prefs, sessions, boards, settings. Sync + guest migration.

## State Management (Riverpod)

All in `lib/state/`:
- `auth_provider` — auth state stream, isGuest
- `conditions_provider` — async fetch + cached fallback, auto-refetch on location change
- `preferences_provider` — read/write with sync
- `sessions_provider` — CRUD + Supabase sync
- `boards_provider` — CRUD + sync
- `location_provider` — selected location ID + derived Location object
- `theme_provider` — ThemeMode (dark/light/system)
- `store_provider` — StoreService singleton

**Important:** `Session` name collides with Supabase's gotrue `Session`. Use `show SupabaseClient` import in store_service.dart.

## Current Status

Phase 2 complete: auth, write-through persistence, Riverpod providers, 160 passing tests.
