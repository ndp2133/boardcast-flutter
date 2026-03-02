/// Paywall — custom paywall with RevenueCat purchase flow.
/// Fetches available packages and presents them with buy buttons.
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/tokens.dart';
import '../state/subscription_provider.dart';

/// Show the paywall. Fetches packages from RevenueCat and presents
/// a custom bottom sheet with purchase buttons.
Future<void> showPaywall(BuildContext context) async {
  final container = ProviderScope.containerOf(context);
  final service = container.read(subscriptionServiceProvider);

  if (!context.mounted) return;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor:
        Theme.of(context).brightness == Brightness.dark
            ? AppColorsDark.bgPrimary
            : AppColors.bgPrimary,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (ctx) => _PaywallSheet(service: service, container: container),
  );
}

class _PaywallSheet extends StatefulWidget {
  final dynamic service;
  final ProviderContainer container;

  const _PaywallSheet({required this.service, required this.container});

  @override
  State<_PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends State<_PaywallSheet> {
  List<dynamic>? _packages;
  bool _loading = true;
  bool _purchasing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    try {
      final packages = await widget.service.getPackages();
      log('Paywall: loaded ${packages.length} packages');
      if (mounted) {
        setState(() {
          _packages = packages;
          _loading = false;
          if (packages.isEmpty) {
            _error = 'No subscription plans available yet.';
          }
        });
      }
    } catch (e) {
      log('Paywall: error loading packages: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load subscription plans.';
        });
      }
    }
  }

  Future<void> _purchase(dynamic package) async {
    setState(() => _purchasing = true);
    try {
      final success = await widget.service.purchasePackage(package);
      if (success) {
        widget.container.read(isPremiumProvider.notifier).refresh();
        if (mounted) Navigator.of(context).pop();
      } else {
        if (mounted) setState(() => _purchasing = false);
      }
    } catch (e) {
      log('Paywall: purchase error: $e');
      if (mounted) setState(() => _purchasing = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _purchasing = true);
    final result = await widget.service.restore();
    if (result.restored) {
      widget.container.read(isPremiumProvider.notifier).refresh();
      if (mounted) Navigator.of(context).pop();
    } else {
      if (mounted) {
        setState(() => _purchasing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No previous purchases found.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final subColor =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.s4,
        right: AppSpacing.s4,
        top: AppSpacing.s4,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: AppSpacing.s4),
            decoration: BoxDecoration(
              color: subColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Text(
            'Upgrade to Premium',
            style: TextStyle(
              fontSize: AppTypography.textLg,
              fontWeight: AppTypography.weightBold,
              color: textColor,
            ),
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            'Unlock the full Boardcast experience',
            style: TextStyle(
              fontSize: AppTypography.textSm,
              color: subColor,
            ),
          ),
          const SizedBox(height: AppSpacing.s5),

          // Features list
          ..._features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s2),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 20, color: AppColors.accent),
                    const SizedBox(width: AppSpacing.s2),
                    Text(f,
                        style: TextStyle(
                            fontSize: AppTypography.textSm, color: textColor)),
                  ],
                ),
              )),
          const SizedBox(height: AppSpacing.s5),

          // Purchase buttons
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.s4),
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          else if (_error != null && (_packages == null || _packages!.isEmpty))
            _buildFallbackPricing(textColor, subColor)
          else
            ..._buildPackageButtons(textColor, subColor),

          // Restore purchases
          const SizedBox(height: AppSpacing.s3),
          TextButton(
            onPressed: _purchasing ? null : _restore,
            child: Text(
              'Restore Purchases',
              style: TextStyle(
                fontSize: AppTypography.textXs,
                color: subColor,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s2),
        ],
      ),
    );
  }

  List<Widget> _buildPackageButtons(Color textColor, Color subColor) {
    return _packages!.map<Widget>((package) {
      final product = package.storeProduct;
      final isAnnual = product.identifier.contains('annual') ||
          product.identifier.contains('yearly');
      final intro = product.introductoryPrice;
      final hasTrial = intro != null && intro.price == 0;
      final trialDays = hasTrial ? intro!.periodNumberOfUnits : 0;
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.s2),
        child: SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: _purchasing ? null : () => _purchase(package),
            style: TextButton.styleFrom(
              backgroundColor:
                  isAnnual ? AppColors.accent : Colors.transparent,
              foregroundColor: isAnnual ? Colors.white : AppColors.accent,
              padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.s3, horizontal: AppSpacing.s4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                side: isAnnual
                    ? BorderSide.none
                    : BorderSide(color: AppColors.accent),
              ),
            ),
            child: _purchasing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Column(
                    children: [
                      Text(
                        isAnnual ? 'Yearly — Save 50%' : 'Monthly',
                        style: TextStyle(
                          fontSize: AppTypography.textBase,
                          fontWeight: AppTypography.weightSemibold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasTrial
                            ? '$trialDays-day free trial, then ${product.priceString}${isAnnual ? '/year' : '/month'}'
                            : '${product.priceString}${isAnnual ? '/year' : '/month'}',
                        style: TextStyle(
                          fontSize: AppTypography.textSm,
                          fontWeight: AppTypography.weightMedium,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildFallbackPricing(Color textColor, Color subColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.accent),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Text(
            '\$4.99/month or \$29.99/year',
            style: TextStyle(
              fontSize: AppTypography.textBase,
              fontWeight: AppTypography.weightSemibold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Subscriptions available soon.',
            style: TextStyle(
              fontSize: AppTypography.textXs,
              color: subColor,
            ),
          ),
        ],
      ),
    );
  }
}

const _features = [
  'AI Surf Coach — personalized tips',
  'Unlimited AI condition queries',
  'Push alerts for ideal conditions',
  'Home screen widget',
  'Advanced session analytics',
];
