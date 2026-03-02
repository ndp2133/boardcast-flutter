/// Paywall — presents RevenueCat's native paywall UI.
/// Falls back to a simple info sheet if RevenueCat isn't initialized.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import '../theme/tokens.dart';
import '../state/subscription_provider.dart';

/// Show the paywall. Uses RevenueCat's native paywall if available,
/// otherwise shows a fallback with pricing info.
Future<void> showPaywall(BuildContext context) async {
  // Try to get the WidgetRef from a ConsumerWidget ancestor if available
  // Otherwise just use the native paywall directly
  final container = ProviderScope.containerOf(context);
  final service = container.read(subscriptionServiceProvider);

  if (service.isInitialized) {
    try {
      // Use RevenueCat's native paywall (remotely configurable from dashboard)
      final result = await service.presentPaywall();

      // Refresh premium state after paywall closes
      container.read(isPremiumProvider.notifier).refresh();

      // If user purchased, no need to do anything else
      if (result == PaywallResult.purchased || result == PaywallResult.restored) {
        return;
      }
    } catch (_) {
      // RevenueCat config error (e.g. Error 23) — show fallback
      if (context.mounted) {
        _showFallbackPaywall(context);
      }
    }
  } else {
    // Fallback: show a simple info sheet
    if (context.mounted) {
      _showFallbackPaywall(context);
    }
  }
}

void _showFallbackPaywall(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final textColor =
      isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
  final subColor =
      isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;

  showModalBottomSheet(
    context: context,
    backgroundColor: isDark ? AppColorsDark.bgPrimary : AppColors.bgPrimary,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.all(AppSpacing.s4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: AppSpacing.s4),
            decoration: BoxDecoration(
              color: subColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
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
          ),
          const SizedBox(height: AppSpacing.s4),
        ],
      ),
    ),
  );
}

const _features = [
  'AI Surf Coach — personalized tips',
  'Unlimited AI condition queries',
  'Push alerts for ideal conditions',
  'Home screen widget',
  'Advanced session analytics',
];

