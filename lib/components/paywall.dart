/// Paywall bottom sheet — shows subscription options.
/// $4.99/mo or $29.99/yr with feature list and restore button.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../theme/tokens.dart';
import '../state/subscription_provider.dart';

/// Show the paywall as a modal bottom sheet.
void showPaywall(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).brightness == Brightness.dark
        ? AppColorsDark.bgPrimary
        : AppColors.bgPrimary,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (ctx) => const _PaywallContent(),
  );
}

class _PaywallContent extends ConsumerStatefulWidget {
  const _PaywallContent();

  @override
  ConsumerState<_PaywallContent> createState() => _PaywallContentState();
}

class _PaywallContentState extends ConsumerState<_PaywallContent> {
  bool _purchasing = false;
  String? _error;

  Future<void> _handlePurchase(Package package) async {
    setState(() {
      _purchasing = true;
      _error = null;
    });

    final service = ref.read(subscriptionServiceProvider);
    final error = await service.purchase(package);

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _purchasing = false;
        _error = error;
      });
    } else {
      ref.read(isPremiumProvider.notifier).refresh();
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleRestore() async {
    setState(() {
      _purchasing = true;
      _error = null;
    });

    final service = ref.read(subscriptionServiceProvider);
    final result = await service.restore();

    if (!mounted) return;

    if (result.restored) {
      ref.read(isPremiumProvider.notifier).refresh();
      Navigator.of(context).pop();
    } else {
      setState(() {
        _purchasing = false;
        _error = result.error ?? 'No previous purchases found';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final subColor =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;
    final packages = ref.watch(packagesProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
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
          // Feature list
          ..._features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s2),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 20, color: AppColors.accent),
                    const SizedBox(width: AppSpacing.s2),
                    Text(
                      f,
                      style: TextStyle(
                        fontSize: AppTypography.textSm,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: AppSpacing.s5),
          // Pricing options
          packages.when(
            data: (pkgs) => _buildPricingButtons(pkgs, textColor, subColor),
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.s4),
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
            error: (_, __) =>
                _buildFallbackPricing(textColor, subColor),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.s2),
            Text(
              _error!,
              style: TextStyle(
                fontSize: AppTypography.textXs,
                color: AppColors.conditionPoor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppSpacing.s3),
          // Restore + Terms
          TextButton(
            onPressed: _purchasing ? null : _handleRestore,
            child: Text(
              'Restore Purchases',
              style: TextStyle(
                fontSize: AppTypography.textSm,
                color: AppColors.accent,
              ),
            ),
          ),
          Text(
            'Cancel anytime. Subscription auto-renews.',
            style: TextStyle(
              fontSize: AppTypography.textXs,
              color: subColor,
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
        ],
      ),
    );
  }

  Widget _buildPricingButtons(
      List<Package> packages, Color textColor, Color subColor) {
    if (packages.isEmpty) return _buildFallbackPricing(textColor, subColor);

    return Column(
      children: packages.map((pkg) {
        final product = pkg.storeProduct;
        final isAnnual = pkg.packageType == PackageType.annual;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s2),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _purchasing ? null : () => _handlePurchase(pkg),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isAnnual ? AppColors.accent : Colors.transparent,
                foregroundColor: isAnnual ? Colors.white : AppColors.accent,
                side: isAnnual
                    ? null
                    : BorderSide(color: AppColors.accent),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '${product.priceString}/${isAnnual ? "year" : "month"}',
                    style: const TextStyle(
                      fontWeight: AppTypography.weightSemibold,
                    ),
                  ),
                  if (isAnnual)
                    Text(
                      'Save 50%',
                      style: TextStyle(
                        fontSize: AppTypography.textXs,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFallbackPricing(Color textColor, Color subColor) {
    // Show when RevenueCat not configured or packages unavailable
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.s3),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.accent),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            children: [
              Text(
                '\$4.99/month',
                style: TextStyle(
                  fontSize: AppTypography.textBase,
                  fontWeight: AppTypography.weightSemibold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'or \$29.99/year (save 50%)',
                style: TextStyle(
                  fontSize: AppTypography.textXs,
                  color: subColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s3),
        Text(
          'Subscriptions will be available soon.',
          style: TextStyle(
            fontSize: AppTypography.textXs,
            color: subColor,
          ),
        ),
      ],
    );
  }

  static const _features = [
    'AI Surf Coach — personalized tips',
    'Unlimited AI condition queries',
    'Push alerts for ideal conditions',
    'Home screen widget',
    'Advanced session analytics',
  ];
}
