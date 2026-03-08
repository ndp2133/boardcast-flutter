---
description: Flutter app architecture and component structure
globs: lib/**
---

# Architecture

Feature-first structure. Pure business logic is separated from UI in `lib/logic/`.

## Key Design Decisions

- **Location passed explicitly** to scoring functions (no global state, unlike JS version)
- **Riverpod** for state management
- **Hive** for local storage (replaces localStorage)
- **Syncfusion charts** (free community license) for dual-axis forecast charts
- All business logic is identical to the PWA (same weights, thresholds, constants)

## Services

- **api_service.dart** -- fetch + normalize for Open-Meteo Marine, Open-Meteo Weather, NOAA Tides. `mergeConditions()` joins all three by time key and filters daily entries with null waveHeightMax.
- **cache_service.dart** -- Hive-backed per-location conditions cache. Cached data always returns with `isStale: true`.
- **conditions_repository.dart** -- Orchestrates API fetch + cache. Memory cache first, Hive fallback, offline-first pattern matching the PWA.
- **supabase_service.dart** -- Client init. Same project/anon key as PWA.
- **auth_service.dart** -- Supabase auth (email/password, Google OAuth, state stream).
- **store_service.dart** -- Write-through persistence: Hive first (instant), Supabase async push. CRUD for prefs, sessions, boards, settings. Sync + guest migration.
- **ai_service.dart** -- Thin wrapper around `supabase.functions.invoke()` for 3 Edge Functions: `surf-coach` (tips), `surf-query` (NL Q&A), `forecast-summary` (LLM summary). Callers handle errors.

## State Management (Riverpod)

All in `lib/state/`:
- `auth_provider` -- auth state stream, isGuest
- `conditions_provider` -- async fetch + cached fallback, auto-refetch on location change
- `preferences_provider` -- read/write with sync
- `sessions_provider` -- CRUD + Supabase sync
- `boards_provider` -- CRUD + sync
- `location_provider` -- selected location ID + derived Location object
- `theme_provider` -- ThemeMode (dark/light/system)
- `store_provider` -- StoreService singleton
- `ai_provider` -- AI feature state: SurfTipNotifier (user-initiated tips), SurfQueryNotifier (NL Q&A), LlmSummaryNotifier (auto-fires on conditions load, guards location change races)

**Important:** `Session` name collides with Supabase's gotrue `Session`. Use `show SupabaseClient` import in store_service.dart.

## Views (`lib/views/`)

- **shell_screen.dart** -- Bottom nav with 4 tabs (Dashboard, Forecast, Track, History). Uses `IndexedStack` to preserve state.
- **dashboard_screen.dart** -- Full dashboard: score ring, 3 metric cards, best time card, forecast summary with LLM crossfade, AI surf coach card, share button in AppBar. ConsumerStatefulWidget with 15-min auto-refresh timer. Pull-to-refresh. Skeleton loading + error states.
- **onboarding_screen.dart** -- 3-step PageView wizard: skill level cards, preference sliders/chips, confirmation summary. Populates defaults from `skillDefaults` map. "Continue as Guest" skips with intermediate defaults.
- **forecast_screen.dart** -- Full forecast: Syncfusion dual-axis chart (wave + wind), tide chart with high/low annotations, daily cards with day selection, weekly best windows. Day card tap updates charts.
- **tracking_screen.dart** -- Session planning: 7-day date chips, hourly grid (6AM-8PM) with condition dots and score labels, multi-hour selection, save session. Upcoming planned sessions with Complete/Cancel actions.
- **history_screen.dart** -- Profile/settings: account section (guest/signed-in), dark mode toggle, preferences summary with edit button, board quiver CRUD, Surf IQ card with progress bar + insight, stats grid, "Share Surf Wrapped" button, completed session history list with condition badges, tags, and star ratings.

## Components (`lib/components/`)

- **score_ring.dart** -- Animated arc (CustomPainter) with 0-100 score + condition label. 900ms ease-out animation.
- **metric_card.dart** -- Expandable card with dot, value, sub-label, sparkline, ideal range, explainer text. Uses AnimatedSize.
- **wind_compass.dart** -- CustomPainter showing wind arrow + beach-facing arc + cardinal labels. Colors: green=offshore, red=onshore, orange=cross.
- **best_time_card.dart** -- Best surf window: day, time range, condition badge, wave height, duration.
- **stale_badge.dart** -- Shows data age with refresh button. Hidden when data is fresh (<15 min).
- **location_picker.dart** -- Modal bottom sheet grouped by region (NY/NJ, CA, FL). Updates selectedLocationIdProvider.
- **preferences_editor.dart** -- Bottom sheet with wave range sliders, wind speed slider, wind dir + tide chips. Save/Cancel buttons.
- **forecast_chart.dart** -- Syncfusion `SfCartesianChart` with wave height (spline area, gradient) on primary Y, wind speed (dashed spline) on secondary Y. Trackball scrubber, "now" line annotation, best window overlay.
- **tide_chart.dart** -- Syncfusion spline area chart for tide height. High/low extrema labels, "now" marker dot.
- **daily_card.dart** -- Forecast card per day: condition badge, temp, tide range, swell period, wind context badge, energy level, moon emoji.
- **weekly_windows.dart** -- Top N best surf windows across the forecast period.
- **star_rating.dart** -- Interactive star rating widget. Used in completion modal and history session rows.
- **completion_modal.dart** -- DraggableScrollableSheet for completing sessions: star rating, accuracy calibration, board picker, tags, notes, Surf IQ nudge.
- **board_modal.dart** -- Bottom sheet for adding/editing boards: board type grid (6 types from boardTypes), optional name field.
- **surf_coach_card.dart** -- AI Surf Coach card: "Get Surf Tip" button, NL query input with "Ask" button, loading/loaded/error states.
- **share_card.dart** -- Off-screen canvas rendering (PictureRecorder + Canvas) for 1080x1350 PNG share images. Two modes: best window and current conditions. Dark/light theme colors.
- **surf_wrapped.dart** -- Canvas approach for monthly/all-time session summary: total sessions/hours, avg rating, favorite spot, longest streak, condition distribution bar.
