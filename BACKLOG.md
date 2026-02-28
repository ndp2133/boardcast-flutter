# Boardcast Flutter — Backlog

> Flutter port of the Boardcast PWA. Feature parity audit completed Feb 27, 2026.
> 71 features at parity. 6 gaps remaining. Xcode installed Feb 28.
>
> **#1 GOAL: App Store submission with sticky features by week of Mar 2.**

---

## App Store Sprint (Week of Mar 2)

| Priority | Task | Effort | Status |
|----------|------|--------|--------|
| 1 | **APP-1: iOS build + TestFlight** — `sudo xcodebuild -license accept`, `flutter build ios`, App Store Connect listing, TestFlight upload. | Medium | Pending |
| 2 | **APP-2: Home screen widget (iOS)** — WidgetKit + `home_widget` package. Score + wave height + wind on lock/home screen. THE sticky feature. | Large | Pending |
| 3 | **APP-3: Push notifications** — FCM "Epic conditions at Rockaway in 2 hours." | Medium | Pending |
| 4 | **APP-4: Geolocation auto-select** — Device GPS → nearest surf spot on first launch. `geolocator` already in pubspec. | Small | Pending |
| 5 | **APP-5: Screenshots + metadata** — 5 phone screenshots + App Store description. | Small | Pending |
| 6 | **APP-6: Submit to App Store** — Submit for review. | Tiny | Pending |

---

## PWA Parity Gaps (close before submission)

| Priority | Task | Effort | Status |
|----------|------|--------|--------|
| 1 | **PARITY-1: Condition bar on forecast chart** — Colored hourly segments below the forecast chart showing condition quality per hour (Epic=green, Good=teal, Fair=yellow, Poor=red). PWA: `conditionBarPlugin` in `forecastChart.js`. Add as a custom series or widget below `ForecastChart` in `forecast_screen.dart`. | Medium | Pending |
| 2 | **PARITY-2: Alert banner** — Proactive "Epic conditions coming!" dismissible banner on dashboard when best window is Epic/Good. PWA: `alertBanner.js`. New `lib/components/alert_banner.dart` + wire into `dashboard_screen.dart`. | Small | Pending |
| 3 | **PARITY-3: Stale badge on forecast** — PWA shows data staleness on both dashboard and forecast. Flutter only has it on dashboard. Add `StaleBadge` to `forecast_screen.dart`. | Tiny | Pending |
| 4 | **PARITY-4: Tide rising/falling colors** — Green fill when tide rising, blue when falling. PWA uses Chart.js segment callbacks. Flutter needs conditional segment colors in Syncfusion `TideChart`. | Medium | Pending |
| 5 | **PARITY-5: PostHog analytics** — Pageview auto-capture + custom events (view_switched, location_changed, session_planned, session_completed, onboarding_completed, signed_in). New `lib/services/analytics_service.dart` + PostHog Flutter SDK. | Medium | Pending |
| 6 | **PARITY-6: Metric card explainer text** — Beginner-friendly explanations in expanded metric cards (what swell period means, why offshore wind matters). Content-only change in `metric_card.dart`. | Small | Pending |

---

---

## Bug Fixes

| Priority | Task | Effort | Status |
|----------|------|--------|--------|
| 1 | ~~**BUG-1: Best window overlay not spanning full range**~~ — PlotBand fix shipped Feb 27. | — | Done |

---

## Completed

- Phase 0: Project setup, models, barrel exports
- Phase 1: Scoring, units, time utils, locations, boards, Surf IQ, moon phase (160 tests)
- Phase 2: API service (Open-Meteo Marine + Weather + NOAA tides), normalization, merge
- Phase 3: Dashboard (score ring, metric cards, best time, wind compass, stale badge, forecast summary)
- Phase 4: Onboarding wizard, preferences editor, full light/dark theming
- Phase 5: Forecast (Syncfusion dual-axis chart, tide chart, daily cards, weekly windows, moon phase, wave energy)
- Phase 6: Tracking (hourly grid, session planning, completion modal, board quiver, Surf IQ, streaks, history)
- Phase 7: AI surf coach, LLM forecast summary crossfade, share cards (conditions + Surf Wrapped)
- BUG-1: Best window PlotBand fix
