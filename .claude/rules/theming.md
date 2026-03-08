---
description: Theme system and styling conventions
globs: lib/theme/**,lib/views/**
---

# Theming

- **`lib/theme/app_theme.dart`** -- Full `ThemeData` for light + dark. Covers AppBar, BottomNav, Card, Chip, Slider, ElevatedButton, OutlinedButton, TextButton, Divider, TextTheme.
- **`lib/theme/tokens.dart`** -- Raw design tokens (colors, spacing, radii, typography, shadows, durations).
- Theme mode persisted via `themeModeProvider` -> `StoreService` -> Hive. Supports dark/light/system.
- Onboarding gate in `main.dart`: shows onboarding if `!store.isOnboarded`, then transitions to shell.
