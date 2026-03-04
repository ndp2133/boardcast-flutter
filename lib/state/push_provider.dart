import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/push_notification_service.dart';

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
