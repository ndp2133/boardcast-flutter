---
description: Dual-codebase parity rules for Flutter and PWA
globs: lib/logic/**,lib/services/store_service.dart,lib/services/ai_*.dart,lib/utils/ai_*.dart
---

# Flutter ↔ PWA Parity

Boardcast has two codebases that MUST stay in sync on all business logic:
- **Flutter**: `~/workspace/vibecoding/boardcast_flutter/` (Dart)
- **PWA**: `~/workspace/vibecoding/boardcast/` (vanilla JS)

## Canonical Config (source of truth)

`~/workspace/vibecoding/shared/` contains the canonical values:
- `scoring-config.json` — thresholds, weights, break defaults, wind model, hard caps, taglines, pro prefs
- `locations.json` — all 21 locations with coords, angles, break types, overrides, descriptions
- `skill-defaults.json` — beginner/intermediate/advanced preference defaults

## What must stay in sync

| Domain | Flutter file | PWA file |
|--------|--------------|----------|
| Scoring engine | `lib/logic/scoring.dart` | `js/utils/conditions.js` |
| Locations | `lib/logic/locations.dart` | `js/utils/locations.js` |
| Skill defaults | `lib/services/store_service.dart` (skillDefaults) | `js/store.js` (SKILL_DEFAULTS) |
| AI payloads | `lib/logic/ai_formatters.dart` + `lib/services/ai_service.dart` | `js/components/surfCoach.js` |
| Forecast summary | `lib/logic/forecast_summary.dart` | `js/utils/conditions.js` (generateForecastSummary) |

## Rules

1. **When changing any value in the table above**: also change the counterpart file AND update `shared/*.json` if the canonical value changed.
2. **When adding a new location**: add to both `locations.dart` and `locations.js` AND `shared/locations.json`.
3. **When adding/removing a user preference field**: update models, store, onboarding, preferences editor, and AI formatters in BOTH codebases.
4. **When changing scoring logic** (weights, formulas, caps): update both scoring files AND `shared/scoring-config.json`.
5. **Run Flutter tests** (`flutter test`) after any shared logic change.
6. **Run PWA syntax check** (`node --check js/*.js js/**/*.js` in boardcast/) after any JS change.
