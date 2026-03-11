# Boardcast Flutter — Backlog

> Flutter port of the Boardcast PWA. App Store + Play Store submission pending.
> 262 tests passing. Build 14. TestFlight live. RevenueCat production key active.
>
> **Audit updated Mar 11, 2026 — verified every item against actual codebase.**

---

## Remaining Work

### Submission Blockers

| Priority | Task | Effort | Status |
|----------|------|--------|--------|
| 1 | **APP-5: Screenshots + metadata** — 5 phone screenshots (1290x2796), App Store description, keywords, app icon. | Small | Pending |
| 2 | **APP-6: Submit to App Store** — Increment build number (`1.0.0+14` → `+15`), submit for review. | Tiny | Pending |

### Polish (Nice-to-Have Before Launch)

| Priority | Task | Effort | Status |
|----------|------|--------|--------|
| 1 | **PARITY-4: Tide rising/falling colors** — Green fill when tide rising, blue when falling. PWA uses Chart.js segment callbacks. Flutter `TideChart` uses single SplineAreaSeries with uniform color — needs conditional segment coloring. | Medium | Pending |
| 2 | **BUG-4: Multiple sessions grouped into one row** — Planning 6AM and 3PM sessions at same location stores as single session with `selectedHours: [6, 15]` instead of separate entries. Fix in session planning logic. | Medium | Pending |

### Post-Launch Features

| Priority | Task | Effort | Status |
|----------|------|--------|--------|
| 1 | **WDG-5: Widget spot configuration** — Users can't pin a specific location per widget instance. Add `WidgetConfigurationIntent` (iOS) and `GlanceAppWidgetReceiver` configuration (Android). #1 widget feature request. | Large | Pending |
| 2 | **WDG-6: Live Activity completion** — `SurfLiveActivityView.swift` exists with Dynamic Island layout but no start/stop trigger. Wire ActivityKit start when planned session begins, update with live conditions, end on completion. Needs Flutter → native MethodChannel bridge. | Large | Pending |
| 3 | **INT-2: Garmin Connect** — Direct Garmin API if Strava doesn't cover enough. Lower priority since Strava is the common denominator. | Large | Pending |

---

## Completed

### App Store Sprint

| Task | What shipped |
|------|-------------|
| **APP-1: iOS build + TestFlight** | TestFlight builds live. App Store Connect listing populated. |
| **APP-2: Home screen widget (iOS)** | WidgetKit medium (4x2), small (2x2), large (4x4), lock screen rectangular + circular. |
| **APP-3: Push notifications** | `push_notification_service.dart` (195 lines) — FCM with foreground/background handling, token management, local notifications. |
| **APP-4: Geolocation auto-select** | `geolocator` in `location_provider.dart` + `location_picker.dart` — GPS nearest spot on first launch. |
| **APP-7: Subscription paywall** | RevenueCat (`purchases_flutter` + `purchases_ui_flutter`). `paywall.dart` component. Premium entitlement gating on The Call. |
| **APP-8: In-app account deletion** | `auth_service.dart` `deleteAccount()` → Supabase RPC `delete_user`. Dialog in `auth_modal.dart`, button in history_screen. |
| **APP-9: Privacy & legal** | `PrivacyInfo.xcprivacy` manifest with precise location, health, user ID, email, API categories. |
| **APP-10: App config fixes** | `CFBundleDisplayName` = "Boardcast". `ITSAppUsesNonExemptEncryption` = false. |

### PWA Parity

| Task | What shipped |
|------|-------------|
| **PARITY-1: Condition bar** | `condition_bar.dart` — colored hourly segments below forecast chart. Used in `forecast_screen.dart`. |
| **PARITY-2: Alert banner** | `alert_banner.dart` — "Epic conditions coming!" dismissible banner on dashboard. |
| **PARITY-3: Stale badge on forecast** | `StaleBadge` on both dashboard and forecast screen. |
| **PARITY-5: PostHog analytics** | `analytics_service.dart` with `posthog_flutter` SDK. identify/track/screen/reset. |
| **PARITY-6: Metric card explainer** | `MetricCard` has `explainer` parameter (infrastructure ready). Dashboard uses `_UnifiedConditionsCard` instead — explainer content deferred. |

### Android

| Task | What shipped |
|------|-------------|
| **ANDROID-1: Firebase App Distribution** | Firebase project `boardcastsurf`, APK uploads, beta testers. |
| **ANDROID-2: Firebase Analytics** | `google-services.json` + `firebase_options.dart` configured. |
| **ANDROID-3: FCM Push** | `firebase_messaging: ^15.2.4` — shared push service handles both iOS + Android. |

### Integrations

| Task | What shipped |
|------|-------------|
| **INT-1: Strava import** | Full OAuth flow with CSRF state, Supabase Edge Function for server-side token exchange (client secret never shipped), `flutter_secure_storage` for tokens, deep link callback, import modal UI. |

### Bug Fixes

| Task | What shipped |
|------|-------------|
| **BUG-1: Best window overlay** | PlotBand fix shipped Feb 27. |
| **BUG-2: preferredWindDir typo** | Fixed in history_screen.dart. |
| **BUG-3: Keyboard dismiss** | `keyboardDismissBehavior: onDrag` on completion modal ScrollView. |
| **BUG-5: Scoring too generous** | Scoring v2.2 with 5 hard caps: minimum wave energy, power safety, thunderstorm/lightning, strong onshore, tide-sensitive spot. Null values return 0.5 (neutral), not high scores. |

### Design Refinement (Sessions 28-29)

> All 44 design refinement items complete. Full Design Refinement section done.

| Category | Items | Status |
|----------|-------|--------|
| **FL-PAL: Cold ocean palette** | 3/3 | All Done |
| **FL-SURF: Surface system** | 4/4 | All Done |
| **FL-TYPE: Typography** | 3/3 | All Done |
| **FL-MOTION: Interaction** | 4/4 | All Done |
| **FL-NAV: Navigation** | 2/2 | All Done |
| **FL-COPY: Copy voice** | 3/3 | All Done |
| **FL-A11Y: Accessibility** | 4/4 | All Done |
| **FL-DR-3: Sessions tab** | 5/5 | All Done |
| **FL-DR-4: Forecast tab** | 5/5 | All Done |

Key items shipped: Decision-first dashboard hero, cold ocean palette (WCAG AA-lg compliant), scrub strip with haptics, frosted glass nav bar, tab fade transitions, spring lift cards, Material You dynamic color, forecast copy voice rewrite.

### Flutter-Specific UI

| Task | What shipped |
|------|-------------|
| **FL-2: History screen split** | `TabController` with Settings / Sessions tabs. Settings tab: account, theme, prefs, boards, Surf IQ, Wrapped. Sessions tab: session history list. |
| **FL-3: AI onboarding** | Conversational onboarding via `onboarding-chat` Edge Function (Haiku). Visual summary + manual fine-tune fallback. |
| **FL-1: Completion modal progressive steps** | Rewritten as 2-step progressive modal with step indicator (numbered dots + connecting line). Step 1: rate + calibration + "Save & Skip Details" shortcut. Step 2: board picker, tags, notes, Surf IQ nudge. `AnimatedSwitcher` transitions between steps. Reduced initial sheet from 0.85 to 0.75. |
| **FL-4: Feature tour → contextual discovery** | Removed mandatory PageView tour gate from `main.dart`. Created `discovery_hint.dart` — inline dismissible hints with animated entrance (fade+slide). Wired into dashboard (scrub hint), forecast (windows hint), tracking (planning hint). `StoreService` persists seen hints in Hive. |
| **FL-5: Material You** | `dynamic_color` package. `DynamicColorBuilder` wraps MaterialApp. Android 12+ gets wallpaper-derived ColorScheme. |
| **FL-6: Haptic differentiation** | `AppHaptics.forScore()`. Scrub strip: `selectionClick` per bar, `mediumImpact` at best window boundary. |

### Widget + Watch Improvements

| Task | What shipped |
|------|-------------|
| **WDG-1: Small widget color wash** | RadialGradient condition tint on dark navy bg (iOS + Android). |
| **WDG-2: Medium widget hierarchy** | Score 28→34pt, condition label 12→15pt. WCAG palette. |
| **WDG-3: Android widget visual parity** | Trend arrows (↑↓→) on all 3 Glance widgets. Condition-tinted backgrounds. Fixed stale teal ARGB. |
| **WDG-4: Lock screen enhancement** | Trend arrow + wave SF Symbol on circular gauge. |
| **W-1: The Call on wrist** | Verdict-first layout. Score ring shrunk to supporting role. |
| **W-2: Sparkline chart** | `HourlySparkline` area-fill with Bézier curves + teal gradient + time labels. |
| **W-3: Condition color tint** | RadialGradient with conditionColor at 0.10 opacity. |
| **W-4: Complication trends** | All 4 families show ↑↓→. Circular: trend in gauge label. Corner: trend below score. WCAG palette on complication. |

### UX Audit Tier 1 — Premium Feel

| Task | What shipped |
|------|-------------|
| **P1: Shimmer loading skeletons** | `shimmer.dart` with `Shimmer` + `ShimmerBox` widgets (animated left-to-right gradient sweep). Wired into dashboard, forecast, and tracking screen skeleton states. |
| **P2: Score count-up animation** | `TweenAnimationBuilder<int>` on `_DecisionCard` score badge — counts 0→score over 800ms with easeOut curve. |
| **P3: Sticky selection summary** | Floating bottom bar on tracking screen shows "N hours selected" + time range, always visible during hour selection. |
| **P4: Charts crossfade on day switch** | `AnimatedSwitcher` wrapping ForecastChart + ConditionBar + TideChart keyed by `selectedDate` — 300ms crossfade on day card tap. |
| **P5: Touch targets audit** | StarRating: 4px→12px padding (36→44px). DiscoveryHint close: 4px→12px + opaque hit test. LocationPicker favorite: 4px→12px + opaque. StaleBadge refresh: added 8px padding + opaque. |
| **P6: Floating save button** | Save Session button moved from inline (scrolls off-screen) to `Stack` + `Positioned.bottom` floating bar. Always thumb-reachable. |
| **P7: Date chip auto-scroll** | `ScrollController.animateTo()` centers selected date chip on tap. Also fires on best window hero tap. |

### UX Audit Tier 2 — Micro-Interactions

| Task | What shipped |
|------|-------------|
| **P8: Staggered entrance animations** | `stagger_animate.dart` — reusable `StaggerAnimate` widget (per-index delayed slide+fade). Applied to forecast daily cards and weekly window rows. |
| **P9: Haptic expansion** | `HapticFeedback.selectionClick()` on daily card tap and weekly window tap. `mediumImpact` on "Save & Skip Details" in completion modal. |
| **P10: Decision card smoother** | `AnimatedContainer` duration upgraded to `AppDurations.base` with `Curves.easeOut` for pressure state changes. |
| **P11: Completion celebration** | After saving a session, `_step = -1` triggers elastic scale-in celebration (green check, "Session saved", "Nice work out there.") with 1500ms auto-dismiss. |
| **P12: Onboarding chat bubble slide-in** | `TweenAnimationBuilder<double>` on each message bubble — user bubbles slide from right, bot bubbles from left, 350ms easeOutCubic with fade. |
| **P13: Error state personality** | Offline vs server errors distinguished (`SocketException` detection). Different icons (`wifi_off` vs `cloud_off`), contextual copy, `ElevatedButton.icon` with haptic feedback. Applied to dashboard and forecast. |
| **P14: Tide chart dark mode fix** | "Now" marker border changed from `bgPrimary` (invisible) to `bgSecondary` (visible) in dark mode. Width 1.5→2. |
| **P15: Slide-up route distance** | `SlideUpRoute` offset from `0.05` to `0.15` for more perceptible entrance. Fade curve unified to `easeOutCubic`. |

### UX Audit Tier 3 — Deep Polish

| Task | What shipped |
|------|-------------|
| **P16: Metric card press-down** | `AnimatedScale` wrapping card with `onTapDown`/`onTapUp` — scales to 0.97x during press for tactile visual feedback. |
| **P17: Daily card expand arrow** | Arrow rotation upgraded to `AppDurations.base` with `easeInOutCubic`. Expanded state: 18px accent-colored icon vs 16px subdued. Container transitions use `easeOutCubic`. |
| **P18: Star rating elastic bounce** | Scale animation curve changed from `easeOutBack` to `elasticOut` with `AppDurations.base` for bouncier, more delightful star selection. |
| **P19: Wind compass snappier** | TweenAnimationBuilder duration from `slow` → `base` (300→200ms), curve from `easeInOut` → `easeOutCubic` for snappier needle rotation. |
| **P20: Location picker selected highlight** | Selected row gets accent-tinted background (`alpha: 0.08` dark, `0.06` light) via `tileColor` for instant visual identification. |
| **P21: Session history stagger tighten** | Stagger timing reduced from 300+50ms/item to 150+30ms/item. 10 sessions animate in 450ms instead of 800ms — snappier list entrance. |
| **P22: Celebration haptic burst** | Double-tap haptic burst on save celebration: `heavyImpact` immediately + `mediumImpact` at 200ms delay for visceral "done" feel. |
| **P23: Hour tile check animation** | Selected check icon uses `AnimatedOpacity` + `AnimatedScale` (0.5→1.0 with `easeOutBack`) instead of instant show/hide. |
| **P24: Chart axis labels readable** | Forecast chart axis labels upgraded from hardcoded 9px to `AppTypography.textXxs` (11px) across all 3 axes. |

### Cross-Platform Palette Unification

All 4 platforms updated to WCAG-compliant cold ocean palette:
- Epic `#2E8A5E` sage, Good `#3D9189` sea-glass, Fair `#B07A4F` sand, Poor `#9E5E5E` brick
- Updated in: `scoring.dart`, `tokens.dart`, `share_card.dart`, `surf_wrapped.dart`, `best_time_card.dart`, all iOS widget Swift views, all iOS watch/complication Swift views, `SharedSurfData.swift`, `BestTimeSnippetView.swift`, `SurfLiveActivityView.swift`, all Android Kotlin widgets

### Build History

- Phase 0-7: Core app (models, scoring, API, dashboard, onboarding, forecast, tracking, AI, share cards)
- Session 16: P0 polish (haptics, Dynamic Type, VoiceOver, spring animation, skeletons)
- Session 17: P1 polish (empty states, animations, small + lock screen widgets)
- Session 21: Widget overhaul (small/large redesign, Android Glance parity, unified deploy)
- Session 26: Apple Watch (4 complication families, watch app, WatchConnectivity pipeline)
- Session 28: Dashboard rebuild (decision-first hero, scrub strip, reason chips, AI onboarding)
- Session 29: Design polish (WCAG audit, palette unification, tab transitions, spring lifts, forecast voice, Dynamic Type, complication trends, Android widget trends, Material You, contextual discovery, progressive completion modal, UX audit Tier 1 + Tier 2 + Tier 3)
