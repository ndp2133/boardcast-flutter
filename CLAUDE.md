# Boardcast Flutter

Flutter port of the Boardcast PWA surf conditions tracker. Native iOS + Android with home screen widgets.

## Commands

```bash
# Run tests
flutter test

# Run app on Chrome (no Xcode needed)
flutter run -d chrome

# Run app on macOS desktop (requires Xcode CLI: xcode-select --install)
flutter run -d macos

# Build release APK
flutter build apk --release

# Build iOS (requires Xcode)
flutter build ios --release
```

## Architecture

Feature-first structure. Pure business logic is separated from UI in `lib/logic/`.

### Directory Structure

```
lib/
  models/       — Data classes with fromJson/toJson (Location, HourlyData, Session, etc.)
  logic/        — Pure functions (scoring, boards, surfiq, moon, units, time, locations, ai_formatters)
  theme/        — Design tokens (colors, spacing, typography from PWA variables.css)
  services/     — API fetch/normalize/merge, Supabase client, Hive cache, conditions repository, AI service
  state/        — Riverpod providers (auth, conditions, prefs, sessions, boards, location, theme, AI)
  views/        — Screen widgets (dashboard, forecast, tracking, history, onboarding, shell)
  components/   — Reusable widgets (score ring, metrics, charts, surf coach, share cards, etc.)
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
- **ai_service.dart** — Thin wrapper around `supabase.functions.invoke()` for 3 Edge Functions: `surf-coach` (tips), `surf-query` (NL Q&A), `forecast-summary` (LLM summary). Callers handle errors.

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
- `ai_provider` — AI feature state: SurfTipNotifier (user-initiated tips), SurfQueryNotifier (NL Q&A), LlmSummaryNotifier (auto-fires on conditions load, guards location change races)

**Important:** `Session` name collides with Supabase's gotrue `Session`. Use `show SupabaseClient` import in store_service.dart.

## Views & Components (Phase 3+)

### Views (`lib/views/`)
- **shell_screen.dart** — Bottom nav with 4 tabs (Dashboard, Forecast, Track, History). Uses `IndexedStack` to preserve state.
- **dashboard_screen.dart** — Full dashboard: score ring, 3 metric cards, best time card, forecast summary with LLM crossfade, AI surf coach card, share button in AppBar. ConsumerStatefulWidget with 15-min auto-refresh timer. Pull-to-refresh. Skeleton loading + error states.
- **onboarding_screen.dart** — 3-step PageView wizard: skill level cards → preference sliders/chips → confirmation summary. Populates defaults from `skillDefaults` map. "Continue as Guest" skips with intermediate defaults.
- **forecast_screen.dart** — Full forecast: Syncfusion dual-axis chart (wave + wind), tide chart with high/low annotations, daily cards with day selection, weekly best windows. Day card tap updates charts.
- **tracking_screen.dart** — Session planning: 7-day date chips, hourly grid (6AM-8PM) with condition dots and score labels, multi-hour selection, save session. Upcoming planned sessions with Complete/Cancel actions.
- **history_screen.dart** — Profile/settings: account section (guest/signed-in), dark mode toggle, preferences summary with edit button, board quiver CRUD, Surf IQ card with progress bar + insight, stats grid (sessions, avg rating, best, accuracy), "Share Surf Wrapped" button, completed session history list with condition badges, tags, and star ratings.

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
- **star_rating.dart** — Interactive star rating widget with configurable max rating and size. Used in completion modal and history session rows.
- **completion_modal.dart** — DraggableScrollableSheet for completing sessions: star rating, forecast accuracy calibration (worse/about right/better), board picker, tags, notes, Surf IQ nudge display.
- **board_modal.dart** — Bottom sheet for adding/editing boards: board type grid (6 types from boardTypes), optional name field.
- **surf_coach_card.dart** — AI Surf Coach card: "Get Surf Tip" button (becomes "New Tip"), NL query input with "Ask" button, loading/loaded/error states. Reads conditions + prefs via providers.
- **share_card.dart** — Off-screen canvas rendering (PictureRecorder + Canvas, not CustomPainter) for 1080x1350 PNG share images. Two modes: best window (hero time range, condition badge, 2x2 metric grid) and current conditions fallback (hero wave height, condition badge, metric grid). Dark/light theme colors. Writes to temp file via path_provider, shares via Share.shareXFiles().
- **surf_wrapped.dart** — Same canvas approach for monthly/all-time session summary: total sessions/hours, avg rating, favorite spot, longest streak, condition distribution bar (epic/good/fair/poor segments with legend), go-to board, wave footer decorations.

## AI Features (Phase 7)

Three Supabase Edge Functions (source in Supabase dashboard, not this repo):
- **surf-coach** — Claude Sonnet for personalized coaching tips based on current conditions + user prefs
- **surf-query** — Claude Haiku for natural language Q&A with full forecast context (current + daily + top windows)
- **forecast-summary** — Claude for LLM-enhanced forecast summary (crossfades from rule-based on dashboard)

Flutter-side architecture:
- `lib/logic/ai_formatters.dart` — Pure functions to format conditions/daily/windows into compact AI payloads. Converts metric→imperial, builds prefs map.
- `lib/services/ai_service.dart` — Thin async wrapper around `supabase.functions.invoke()`.
- `lib/state/ai_provider.dart` — Three Riverpod Notifiers (not FutureProvider, since tips/queries are user-initiated).
  - `LlmSummaryNotifier` auto-fires when conditions resolve, guards against location change race conditions.

## Theming

- **`lib/theme/app_theme.dart`** — Full `ThemeData` for light + dark. Covers AppBar, BottomNav, Card, Chip, Slider, ElevatedButton, OutlinedButton, TextButton, Divider, TextTheme.
- **`lib/theme/tokens.dart`** — Raw design tokens (colors, spacing, radii, typography, shadows, durations).
- Theme mode persisted via `themeModeProvider` → `StoreService` → Hive. Supports dark/light/system.
- Onboarding gate in `main.dart`: shows onboarding if `!store.isOnboarded`, then transitions to shell.

## Home Screen Widget (iOS)

Native WidgetKit extension in `ios/BoardcastWidget/`. Medium widget (4x2) showing surf score area-fill timeline.

### Architecture
- **Flutter side**: `lib/services/widget_service.dart` pre-computes hourly scores and writes to shared UserDefaults via `home_widget` package. `lib/state/widget_provider.dart` auto-triggers updates when conditions change.
- **iOS side**: `ios/BoardcastWidget/` contains SwiftUI widget with `StaticConfiguration`, `TimelineProvider` (15-min refresh), and `MediumWidgetView` with a custom `ScoreFillChart`.
- **Data flow**: Flutter app → `HomeWidget.saveWidgetData()` → App Groups UserDefaults → WidgetKit reads on timeline reload.
- **App Group ID**: `group.com.boardcast.boardcastFlutter`
- **Widget kind**: `BoardcastWidget`

### Xcode Setup Required
See `ios/BoardcastWidget/XCODE_SETUP.md` for step-by-step instructions to add the widget extension target, configure App Groups, and include DM Mono fonts.

### Widget Data Keys (UserDefaults)
`score` (int 0-100), `conditionLabel`, `locationName`, `waveHeight`, `windSpeed`, `windDir`, `windContext`, `fetchedAt`, `hourlyScores` (JSON array of `{h, s, c}`), `bestWindowStart`, `bestWindowEnd`, `bestWindowScore`, `bestWindowLabel`

## Current Status

Phase 7 complete + chart fixes + widget extension scaffolded. 171 passing tests. 93% feature parity with PWA (6 gaps in BACKLOG.md). Xcode installed, ready for iOS builds. Widget extension needs Xcode target setup (see XCODE_SETUP.md). Next: App Store sprint with sticky features (push notifications, geolocation). See BACKLOG.md for full plan.
