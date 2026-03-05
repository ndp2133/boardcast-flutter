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
| 2 | **APP-2: Home screen widget (iOS)** — WidgetKit + `home_widget` package. Medium (4x2) score area-fill timeline chart. | Large | **Done** |
| 3 | **APP-3: Push notifications** — FCM "Epic conditions at Rockaway in 2 hours." | Medium | Pending |
| 4 | **APP-4: Geolocation auto-select** — Device GPS → nearest surf spot on first launch. `geolocator` already in pubspec. | Small | Pending |
| 5 | **APP-5: Screenshots + metadata** — 5 phone screenshots (1290x2796), App Store description, keywords, app icon. | Small | Pending |
| 6 | **APP-6: Submit to App Store** — Submit for review. | Tiny | Pending |
| 7 | **APP-7: Subscription paywall** — RevenueCat integration, paywall UI (price, features, restore, ToS/PP links, cancel info). $4.99/mo + $29.99/yr. | Medium | Pending |
| 8 | **APP-8: In-app account deletion** — Apple requires this. Delete Supabase data + Hive + sign out. | Small | Pending |
| 9 | **APP-9: Privacy & legal** — Update privacy policy (location, AI disclosure, GDPR/CCPA), PrivacyInfo.xcprivacy manifest, nutrition labels. | Medium | Pending |
| 10 | **APP-10: App config fixes** — CFBundleDisplayName→"Boardcast", ITSAppUsesNonExemptEncryption=false, widget version match. | Tiny | Pending |

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

## Android

| Priority | Task | Effort | Status |
|----------|------|--------|--------|
| 1 | **ANDROID-1: Firebase App Distribution** — Firebase project, CLI login, APK upload, beta tester invited. Build 7 shipped. | Small | **Done** |
| 2 | **ANDROID-2: Firebase Analytics** — FlutterFire CLI setup, `google-services.json`, Firebase Analytics SDK. Mirror PostHog events (view_switched, location_changed, session_planned, etc.). Consider replacing PostHog with Firebase on Android to avoid dual SDKs. | Medium | Pending |
| 3 | **ANDROID-3: Push notifications (FCM)** — Firebase Cloud Messaging for Android. "Epic conditions at Rockaway in 2 hours." Pairs with APP-3 (iOS push). | Medium | Pending |

---

## Integrations (Post-Launch)

| Priority | Task | Effort | Status |
|----------|------|--------|--------|
| 1 | **INT-1: Strava import** — OAuth2 + Strava API to auto-import surf sessions (duration, GPS, HR). Catches Garmin, Apple Watch, Wahoo users. Feeds Surf IQ without manual logging. Beta tester uses Garmin → Strava workflow. | Large | Pending |
| 2 | **INT-2: Garmin Connect** — Direct Garmin API if Strava doesn't cover enough. Lower priority since Strava is the common denominator. | Large | Pending |

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
- APP-2: Home screen widget — WidgetKit medium (4x2) score area-fill timeline, Flutter widget_service + widget_provider, SwiftUI MediumWidgetView, Xcode target setup
- BUG-2: preferredWindDir typo in history_screen.dart (was preferredWindDirection)
- FIX: Xcode build cycle — reordered build phases (Embed App Extensions before Thin Binary)
- Session 16: P0 polish — haptics, Dynamic Type, VoiceOver, spring animation, skeletons + 29 new tests
- Session 17: P1 polish — empty states with personality, dashboard cross-fade + metric number morphing, onboarding animation refinements (animated dots, hero icons, staggered cards, confirm pop), small widget (2×2), lock screen rectangular + circular widgets. 8 new tests (221 total). Plan written for Siri Shortcuts + Live Activities.
- Session 21: WIDGET-1 small widget redesign (score ring + micro-sparkline + best hour), WIDGET-2 large widget (4×4 dashboard: score timeline, wave/tide chart, best window card, upcoming windows). Android parity for large widget (Jetpack Glance). Unified deploy skill (PWA + TestFlight + Firebase). Fixed pre-existing Dart type error in history_screen. 284 tests. Build 10 deployed to all platforms.
