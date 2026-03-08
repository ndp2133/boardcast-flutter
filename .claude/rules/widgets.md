---
description: iOS home screen widget implementation
globs: ios/BoardcastWidget/**,lib/services/widget_*.dart
---

# Home Screen Widgets

## iOS (WidgetKit)

Native WidgetKit extension in `ios/BoardcastWidget/`. 4 widget families: medium (4x2 area-fill timeline), small (2x2 score dominant), lock screen rectangular (2-line summary), lock screen circular (gauge).

## Android (Jetpack Glance)

Kotlin Glance widgets in `android/app/src/main/kotlin/com/boardcast/boardcast_flutter/`. 2 sizes: small (2x2 score + condition), medium (4x2 with hourly bar chart + best window).

## Architecture

- **Flutter side**: `lib/services/widget_service.dart` pre-computes hourly scores and writes via `home_widget` package. `lib/state/widget_provider.dart` auto-triggers updates when conditions change.
- **iOS side**: SwiftUI widgets read from App Groups UserDefaults (`group.com.boardcast.app`).
- **Android side**: Glance widgets read from SharedPreferences via `HomeWidgetGlanceStateDefinition`.
- **Data flow**: Flutter -> `HomeWidget.saveWidgetData()` -> native widgets read on reload.

## Widget Data Keys (shared across platforms)

`score` (int 0-100), `conditionLabel`, `locationName`, `waveHeight`, `windSpeed`, `windDir`, `windContext`, `fetchedAt`, `hourlyScores` (JSON array of `{h, s, c}`), `bestWindowStart`, `bestWindowEnd`, `bestWindowScore`, `bestWindowLabel`
