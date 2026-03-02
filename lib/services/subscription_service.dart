/// Subscription service — wraps RevenueCat for IAP management.
/// Handles initialization, entitlement checks, and purchase flow.
import 'dart:async';
import 'dart:developer';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

const _revenueCatApiKey = 'appl_RdbLMAkPUXjbIRyPlpmoxipQFgQ';

/// RevenueCat entitlement ID (configured in RevenueCat dashboard).
const entitlementId = 'premium';

class SubscriptionService {
  bool _initialized = false;
  final _controller = StreamController<bool>.broadcast();

  bool get isInitialized => _initialized;

  /// Initialize RevenueCat. Call once at app startup.
  Future<void> init() async {
    if (_initialized) return;

    try {
      await Purchases.configure(
        PurchasesConfiguration(_revenueCatApiKey),
      );
      _initialized = true;

      // Listen for customer info changes
      Purchases.addCustomerInfoUpdateListener((info) {
        final premium = _isPremium(info);
        log('RevenueCat: premium=$premium');
        _controller.add(premium);
      });
    } catch (e) {
      log('RevenueCat init error: $e');
      // App continues without subscriptions — fallback paywall will show
    }
  }

  /// Link RevenueCat to authenticated user.
  Future<void> identify(String userId) async {
    if (!_initialized) return;
    try {
      await Purchases.logIn(userId);
    } catch (e) {
      log('RevenueCat identify error: $e');
    }
  }

  /// Unlink on sign-out.
  Future<void> reset() async {
    if (!_initialized) return;
    try {
      await Purchases.logOut();
    } catch (e) {
      log('RevenueCat reset error: $e');
    }
  }

  /// Stream of premium status changes.
  Stream<bool> get onPremiumChange => _controller.stream;

  /// Check if user has active premium entitlement.
  Future<bool> isPremium() async {
    if (!_initialized) return false;
    try {
      final info = await Purchases.getCustomerInfo();
      return _isPremium(info);
    } catch (_) {
      return false;
    }
  }

  /// Present RevenueCat's native paywall UI.
  /// Returns the paywall result (purchased, cancelled, etc).
  Future<PaywallResult> presentPaywall() async {
    final result = await RevenueCatUI.presentPaywallIfNeeded(entitlementId);
    log('Paywall result: $result');
    return result;
  }

  /// Present RevenueCat's Customer Center for subscription management.
  Future<void> presentCustomerCenter() async {
    await RevenueCatUI.presentCustomerCenter();
  }

  /// Get available packages (for custom paywall fallback if needed).
  Future<List<Package>> getPackages() async {
    if (!_initialized) return [];
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.current?.availablePackages ?? [];
    } catch (_) {
      return [];
    }
  }

  /// Restore previous purchases.
  Future<({bool restored, String? error})> restore() async {
    if (!_initialized) return (restored: false, error: 'Not initialized');
    try {
      final info = await Purchases.restorePurchases();
      return (restored: _isPremium(info), error: null);
    } catch (e) {
      return (restored: false, error: e.toString());
    }
  }

  bool _isPremium(CustomerInfo info) {
    return info.entitlements.active.containsKey(entitlementId);
  }

  void dispose() {
    _controller.close();
  }
}
