/// User preferences provider with write-through sync
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_prefs.dart';
import 'store_provider.dart';

class PreferencesNotifier extends Notifier<UserPrefs> {
  @override
  UserPrefs build() {
    final store = ref.read(storeServiceProvider);
    return store.getPrefs();
  }

  Future<void> update(UserPrefs prefs) async {
    final store = ref.read(storeServiceProvider);
    await store.savePrefs(prefs);
    state = prefs;
  }

  /// Refresh from store (e.g. after sync).
  void refresh() {
    final store = ref.read(storeServiceProvider);
    state = store.getPrefs();
  }
}

final preferencesProvider =
    NotifierProvider<PreferencesNotifier, UserPrefs>(PreferencesNotifier.new);
