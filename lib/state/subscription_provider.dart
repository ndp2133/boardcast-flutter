/// Subscription state provider — tracks premium status via RevenueCat.
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/subscription_service.dart';

/// The subscription service singleton.
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  final service = SubscriptionService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Whether the user has an active premium subscription.
final isPremiumProvider =
    StateNotifierProvider<_PremiumNotifier, bool>((ref) {
  final service = ref.watch(subscriptionServiceProvider);
  return _PremiumNotifier(service);
});

class _PremiumNotifier extends StateNotifier<bool> {
  final SubscriptionService _service;
  StreamSubscription<bool>? _sub;

  _PremiumNotifier(this._service) : super(false) {
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

/// Available packages for the paywall UI.
final packagesProvider = FutureProvider<List<Package>>((ref) {
  final service = ref.watch(subscriptionServiceProvider);
  return service.getPackages();
});
