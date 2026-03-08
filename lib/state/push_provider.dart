import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/push_notification_service.dart';
import 'store_provider.dart';

/// Singleton provider — overridden in main.dart with pre-initialized instance
final pushServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService();
});

/// Whether push notifications are enabled (persisted in Hive via store)
final pushEnabledProvider =
    StateNotifierProvider<PushEnabledNotifier, bool>((ref) {
  return PushEnabledNotifier(ref);
});

class PushEnabledNotifier extends StateNotifier<bool> {
  final Ref ref;

  PushEnabledNotifier(this.ref) : super(false);

  void setEnabled(bool value) => state = value;

  Future<bool> toggle() async {
    final service = ref.read(pushServiceProvider);
    if (state) {
      await service.unsubscribe();
      state = false;
    } else {
      final success = await service.subscribe();
      state = success;
    }
    return state;
  }
}

/// Minimum score threshold for push alerts (0=every day, 40=fair+, 60=good+, 80=epic)
final pushMinScoreProvider =
    NotifierProvider<PushMinScoreNotifier, int>(PushMinScoreNotifier.new);

class PushMinScoreNotifier extends Notifier<int> {
  @override
  int build() => ref.read(storeServiceProvider).getPushMinScore();

  Future<void> setScore(int score) async {
    await ref.read(storeServiceProvider).setPushMinScore(score);
    state = score;
  }
}
