/// Location picker — modal bottom sheet grouped by region
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/tokens.dart';
import '../logic/locations.dart';
import '../state/location_provider.dart';

void showLocationPicker(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (_) => _LocationPickerSheet(ref: ref),
  );
}

class _LocationPickerSheet extends StatelessWidget {
  final WidgetRef ref;
  const _LocationPickerSheet({required this.ref});

  static const _regions = {
    'New York / New Jersey': ['rockaway', 'longbeach', 'asbury', 'belmar'],
    'California': ['huntington', 'santacruz', 'oceanbeach'],
    'Florida': ['clearwater', 'cocoa', 'jacksonville', 'miami'],
  };

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedLocationIdProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColorsDark.bgSurface : AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
              child: Text(
                'Select Location',
                style: TextStyle(
                  fontSize: AppTypography.textLg,
                  fontWeight: AppTypography.weightSemibold,
                  color:
                      isDark ? AppColorsDark.textPrimary : AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s3),
            ..._regions.entries.map((region) => _buildRegion(
                  context,
                  region.key,
                  region.value,
                  selected,
                  isDark,
                )),
            const SizedBox(height: AppSpacing.s4),
          ],
        ),
      ),
    );
  }

  Widget _buildRegion(BuildContext context, String regionName,
      List<String> locationIds, String selected, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s4,
            vertical: AppSpacing.s2,
          ),
          child: Text(
            regionName,
            style: TextStyle(
              fontSize: AppTypography.textXs,
              fontWeight: AppTypography.weightSemibold,
              color: isDark
                  ? AppColorsDark.textTertiary
                  : AppColors.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...locationIds.map((id) {
          final loc = getLocationById(id);
          final isSelected = id == selected;
          return ListTile(
            dense: true,
            title: Text(
              loc.name,
              style: TextStyle(
                fontSize: AppTypography.textSm,
                fontWeight: isSelected
                    ? AppTypography.weightSemibold
                    : AppTypography.weightRegular,
                color: isSelected
                    ? AppColors.accent
                    : isDark
                        ? AppColorsDark.textPrimary
                        : AppColors.textPrimary,
              ),
            ),
            trailing: isSelected
                ? Icon(Icons.check, color: AppColors.accent, size: 18)
                : null,
            onTap: () {
              ref.read(selectedLocationIdProvider.notifier).select(id);
              Navigator.pop(context);
            },
          );
        }),
      ],
    );
  }
}
