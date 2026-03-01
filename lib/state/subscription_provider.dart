/// Subscription state provider — tracks premium status via RevenueCat.
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/subscription_service.dart';

/// The subscription service singleton.
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  final service = SubscriptionService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Whether the user has an active premium subscription.
final isPremiumProvider =
    StateNotifierProvider<PremiumNotifier, bool>((ref) {
  final service = ref.watch(subscriptionServiceProvider);
  return PremiumNotifier(service);
});

class PremiumNotifier extends StateNotifier<bool> {
  final SubscriptionService _service;
  StreamSubscription<bool>? _sub;

  PremiumNotifier(this._service) : super(false) {
    _init();
  }

  Future<void> _init() async {
    state = await _service.isPremium();
    _sub = _service.onPremiumChange.listen((premium) {
      state = premium;
    });
  }

  Future<void> refresh() async {
    state = await _service.isPremium();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
