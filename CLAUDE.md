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

## Views & Components (Phase 3+)

### Views (`lib/views/`)
- **shell_screen.dart** — Bottom nav with 4 tabs (Dashboard, Forecast, Track, History). Uses `IndexedStack` to preserve state.
- **dashboard_screen.dart** — Full dashboard: score ring, 3 metric cards, best time card, forecast summary, stale badge. ConsumerStatefulWidget with 15-min auto-refresh timer. Pull-to-refresh. Skeleton loading + error states.
- **onboarding_screen.dart** — 3-step PageView wizard: skill level cards → preference sliders/chips → confirmation summary. Populates defaults from `skillDefaults` map. "Continue as Guest" skips with intermediate defaults.
- **forecast_screen.dart** — Full forecast: Syncfusion dual-axis chart (wave + wind), tide chart with high/low annotations, daily cards with day selection, weekly best windows. Day card tap updates charts.

### Components (`lib/components/`)
- **score_ring.dart** — Animated arc (CustomPainter) with 0-100 score + condition label. 900ms ease-out animation.
- **metric_card.dart** — Expandable card with dot, value, sub-label, sparkline (CustomPainter), ideal range, explainer text. Uses AnimatedSize.
- **wind_compass.dart** — CustomPainter showing wind arrow + beach-facing arc + cardinal labels. Colors: green=offshore, red=onshore, orange=cross.
- **best_time_card.dart** — Best surf window: day, time range, condition badge, wave height, duration.
- **stale_badge.dart** — Shows data age with refresh button. Hidden when data is fresh (<15 min).
- **location_picker.dart** — Modal bottom sheet grouped by region (NY/NJ, CA, FL). Updates selectedLocationIdProvider.
- **preferences_editor.dart** — Bottom sheet with wave range sliders, wind speed slider, wind dir + tide chips. Save/Cancel buttons. Real-time label updates.
- **forecast_chart.dart** — Syncfusion `SfCartesianChart` with wave height (spline area, gradient) on primary Y, wind speed (dashed spline) on secondary Y. Trackball scrubber, "now" line annotation, best window overlay.
- **tide_chart.dart** — Syncfusion spline area chart for tide height. High/low extrema labels (monospace), "now" marker dot. Trackball synced.
- **daily_card.dart** — Forecast card per day: condition badge, temp, tide range, swell period, wind context badge (Offshore/Onshore/Cross/Light), energy level, moon emoji. Tap selects day for charts.
- **weekly_windows.dart** — Top N best surf windows across the forecast period. Rows with day, time range, condition badge, wave height. Tap navigates to that day.

## Theming

- **`lib/theme/app_theme.dart`** — Full `ThemeData` for light + dark. Covers AppBar, BottomNav, Card, Chip, Slider, ElevatedButton, OutlinedButton, TextButton, Divider, TextTheme.
- **`lib/theme/tokens.dart`** — Raw design tokens (colors, spacing, radii, typography, shadows, durations).
- Theme mode persisted via `themeModeProvider` → `StoreService` → Hive. Supports dark/light/system.
- Onboarding gate in `main.dart`: shows onboarding if `!store.isOnboarded`, then transitions to shell.

## Current Status

Phase 5 complete: forecast view with Syncfusion charts, daily cards, weekly windows. 160 passing tests.
