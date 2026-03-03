// Paywall — premium paywall with RevenueCat purchase flow.
// Fetches available packages and presents them with buy buttons.
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    HapticFeedback.mediumImpact();
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
    HapticFeedback.lightImpact();
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

    return Semantics(
      label: 'Premium subscription paywall',
      child: Padding(
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
            margin: const EdgeInsets.only(bottom: AppSpacing.s5),
            decoration: BoxDecoration(
              color: subColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
          ),

          // Premium icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.accent,
                  AppColors.accentDark,
                ],
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
          ),
          const SizedBox(height: AppSpacing.s4),

          // Header
          Text(
            'Unlock Your Full Potential',
            style: TextStyle(
              fontSize: AppTypography.textXl,
              fontWeight: AppTypography.weightBold,
              color: textColor,
            ),
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            'Know exactly when to paddle out with AI coaching, smart alerts, and widgets.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppTypography.textSm,
              color: subColor,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.s6),

          // Features list
          ..._features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(f.$1, size: AppIconSize.base, color: AppColors.accent),
                    ),
                    const SizedBox(width: AppSpacing.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            f.$2,
                            style: TextStyle(
                              fontSize: AppTypography.textSm,
                              fontWeight: AppTypography.weightSemibold,
                              color: textColor,
                            ),
                          ),
                          Text(
                            f.$3,
                            style: TextStyle(
                              fontSize: AppTypography.textXs,
                              color: subColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: AppSpacing.s5),

          // Purchase buttons
          if (_loading)
            _buildLoadingSkeleton(isDark)
          else if (_error != null && (_packages == null || _packages!.isEmpty))
            _buildFallbackPricing(textColor, subColor)
          else
            ..._buildPackageButtons(textColor, subColor, isDark),

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
    ),
    );
  }

  Widget _buildLoadingSkeleton(bool isDark) {
    final shimmer = isDark ? AppColorsDark.bgTertiary : AppColors.bgTertiary;
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 72,
          decoration: BoxDecoration(
            color: shimmer,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        const SizedBox(height: AppSpacing.s2),
        Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: shimmer,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildPackageButtons(
      Color textColor, Color subColor, bool isDark) {
    // Sort so annual comes first
    final sorted = List.of(_packages!);
    sorted.sort((a, b) {
      final aAnnual = a.storeProduct.identifier.contains('annual') ||
          a.storeProduct.identifier.contains('yearly');
      return aAnnual ? -1 : 1;
    });

    return sorted.map<Widget>((package) {
      final product = package.storeProduct;
      final isAnnual = product.identifier.contains('annual') ||
          product.identifier.contains('yearly');
      final intro = product.introductoryPrice;
      final hasTrial = intro != null && intro.price == 0;
      final trialDays = hasTrial ? intro!.periodNumberOfUnits : 0;

      if (isAnnual) {
        // Annual — primary CTA with "Best Value" badge
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s2),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.accent,
                        AppColors.accentDark,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextButton(
                    onPressed: _purchasing ? null : () => _purchase(package),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.s4, horizontal: AppSpacing.s4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
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
                                'Yearly — Save 50%',
                                style: TextStyle(
                                  fontSize: AppTypography.textBase,
                                  fontWeight: AppTypography.weightBold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.s1),
                              Text(
                                hasTrial
                                    ? '$trialDays-day free trial, then ${product.priceString}/year'
                                    : '${product.priceString}/year',
                                style: TextStyle(
                                  fontSize: AppTypography.textSm,
                                  fontWeight: AppTypography.weightMedium,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              // "Best Value" badge
              Positioned(
                top: -10,
                right: AppSpacing.s4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s3, vertical: AppSpacing.s1),
                  decoration: BoxDecoration(
                    color: AppColors.conditionEpic,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    boxShadow: AppShadows.sm,
                  ),
                  child: Text(
                    'Best Value',
                    style: TextStyle(
                      fontSize: AppTypography.textXs,
                      fontWeight: AppTypography.weightBold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        // Monthly — secondary option
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s2),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _purchasing ? null : () => _purchase(package),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.s3, horizontal: AppSpacing.s4),
              ),
              child: _purchasing
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.accent),
                    )
                  : Column(
                      children: [
                        Text(
                          'Monthly',
                          style: TextStyle(
                            fontSize: AppTypography.textBase,
                            fontWeight: AppTypography.weightSemibold,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s1),
                        Text(
                          hasTrial
                              ? '$trialDays-day free trial, then ${product.priceString}/month'
                              : '${product.priceString}/month',
                          style: TextStyle(
                            fontSize: AppTypography.textSm,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );
      }
    }).toList();
  }

  Widget _buildFallbackPricing(Color textColor, Color subColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s4),
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
          const SizedBox(height: AppSpacing.s1),
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

const _features = <(IconData, String, String)>[
  (Icons.psychology, 'AI Surf Coach', 'Personalized tips based on your style'),
  (Icons.chat_bubble_outline, 'Unlimited AI Queries', 'Ask anything about conditions'),
  (Icons.notifications_active, 'Smart Alerts', 'Never miss epic conditions'),
  (Icons.widgets, 'Home Screen Widget', 'Check the score at a glance'),
  (Icons.insights, 'Session Analytics', 'Track your Surf IQ progression'),
];
