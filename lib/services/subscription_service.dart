/// Subscription service — wraps RevenueCat for IAP management.
/// Handles initialization, entitlement checks, and purchase flow.
import 'dart:async';
import 'package:purchases_flutter/purchases_flutter.dart';

/// TODO: Replace with your RevenueCat API key from https://app.revenuecat.com
const _revenueCatApiKey = 'REPLACE_WITH_REVENUECAT_API_KEY';

/// RevenueCat entitlement ID (configured in RevenueCat dashboard).
const entitlementId = 'premium';

/// Product identifiers (configured in App Store Connect + RevenueCat).
const monthlyProductId = 'boardcast_monthly_499';
const annualProductId = 'boardcast_annual_2999';

class SubscriptionService {
  bool _initialized = false;
  final _controller = StreamController<bool>.broadcast();

  /// Initialize RevenueCat. Call once at app startup.
  Future<void> init() async {
    if (_revenueCatApiKey == 'REPLACE_WITH_REVENUECAT_API_KEY') {
      // Skip initialization if API key not configured yet
      return;
    }
    if (_initialized) return;

    await Purchases.configure(
      PurchasesConfiguration(_revenueCatApiKey),
    );
    _initialized = true;

    // Listen for customer info changes
    Purchases.addCustomerInfoUpdateListener((info) {
      _controller.add(_isPremium(info));
    });
  }

  /// Link RevenueCat to authenticated user.
  Future<void> identify(String userId) async {
    if (!_initialized) return;
    await Purchases.logIn(userId);
  }

  /// Unlink on sign-out.
  Future<void> reset() async {
    if (!_initialized) return;
    await Purchases.logOut();
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

  /// Get available packages for display in paywall.
  Future<List<Package>> getPackages() async {
    if (!_initialized) return [];
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.current?.availablePackages ?? [];
    } catch (_) {
      return [];
    }
  }

  /// Purchase a package. Returns null on success, error string on failure.
  Future<String?> purchase(Package package) async {
    try {
      await Purchases.purchasePackage(package);
      return null;
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) {
        return null; // User cancelled — not an error
      }
      return e.toString();
    } catch (e) {
      return e.toString();
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
