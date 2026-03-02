/// Location picker — modal bottom sheet grouped by region
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
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

class _LocationPickerSheet extends StatefulWidget {
  final WidgetRef ref;
  const _LocationPickerSheet({required this.ref});

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  bool _locating = false;

  static const _regions = {
    'New York / New Jersey': ['rockaway', 'longbeach', 'asbury', 'belmar'],
    'California': ['huntington', 'santacruz', 'oceanbeach'],
    'Florida': ['clearwater', 'cocoa', 'jacksonville', 'miami'],
  };

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Enable location in Settings')),
          );
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 5),
        ),
      );
      final nearest = findNearestLocation(pos.latitude, pos.longitude);
      widget.ref.read(selectedLocationIdProvider.notifier).select(nearest.id);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't get location")),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.ref.watch(selectedLocationIdProvider);
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
            // Use My Location button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _locating ? null : _useMyLocation,
                  icon: _locating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location, size: 18),
                  label: Text(_locating ? 'Locating...' : 'Use My Location'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: BorderSide(color: AppColors.accent.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
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
              HapticFeedback.selectionClick();
              widget.ref.read(selectedLocationIdProvider.notifier).select(id);
              Navigator.pop(context);
            },
          );
        }),
      ],
    );
  }
}
