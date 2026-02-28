/// Theme preference provider
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'store_provider.dart';

/// Theme mode notifier: dark, light, or system (null).
class ThemeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final store = ref.read(storeServiceProvider);
    final pref = store.getThemePref();
    return _fromString(pref);
  }

  Future<void> setTheme(ThemeMode mode) async {
    final store = ref.read(storeServiceProvider);
    await store.setThemePref(_toString(mode));
    state = mode;
  }

  Future<void> toggle() async {
    final next =
        state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setTheme(next);
  }

  static ThemeMode _fromString(String? s) {
    switch (s) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }

  static String? _toString(ThemeMode m) {
    switch (m) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.light:
        return 'light';
      case ThemeMode.system:
        return null;
    }
  }
}

final themeModeProvider =
    NotifierProvider<ThemeNotifier, ThemeMode>(ThemeNotifier.new);
