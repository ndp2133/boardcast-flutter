/// Location picker — modal bottom sheet grouped by region with favorites + near you
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
  List<({Location loc, double distance})>? _nearbyLocations;

  static const _regions = {
    'New York / New Jersey': ['rockaway', 'longbeach', 'montauk', 'manasquan', 'asbury', 'belmar'],
    'California': ['oceanbeach', 'santacruz', 'pleasurepoint', 'rincon', 'malibu', 'huntington', 'trestles'],
    'Florida': ['jacksonville', 'staugustine', 'newsmyrna', 'cocoa', 'sebastian', 'jupiter', 'clearwater', 'miami'],
  };

  @override
  void initState() {
    super.initState();
    _detectNearby();
  }

  Future<void> _detectNearby() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 3),
        ),
      );
      final nearby = findLocationsWithinRadius(pos.latitude, pos.longitude);
      if (nearby.isNotEmpty && mounted) {
        setState(() => _nearbyLocations = nearby);
      }
    } catch (_) {
      // Silent — just don't show Near You
    }
  }

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
    final favorites = widget.ref.watch(favoritesProvider);
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
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Near You section
                    if (_nearbyLocations != null && _nearbyLocations!.isNotEmpty)
                      _buildNearYou(context, _nearbyLocations!, selected, favorites, isDark),
                    // Favorites section
                    if (favorites.isNotEmpty)
                      _buildFavorites(context, favorites, selected, isDark),
                    // Regions
                    ..._regions.entries.map((region) => _buildRegion(
                          context,
                          region.key,
                          region.value,
                          selected,
                          favorites,
                          isDark,
                        )),
                    const SizedBox(height: AppSpacing.s4),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNearYou(BuildContext context,
      List<({Location loc, double distance})> nearby, String selected,
      List<String> favorites, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRegionHeader('Near You', isDark),
        ...nearby.map((item) {
          final miles = (item.distance * 0.621371).round();
          return _buildLocationTile(
            context, item.loc, selected, favorites, isDark,
            trailing: Text(
              '$miles mi',
              style: TextStyle(
                fontSize: AppTypography.textXs,
                color: isDark ? AppColorsDark.textTertiary : AppColors.textTertiary,
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFavorites(BuildContext context, List<String> favorites,
      String selected, bool isDark) {
    final favLocs = favorites
        .map((id) => getLocationById(id))
        .where((l) => l.id != 'rockaway' || favorites.contains('rockaway'))
        .toList();
    if (favLocs.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRegionHeader('Favorites', isDark),
        ...favLocs.map((loc) =>
            _buildLocationTile(context, loc, selected, favorites, isDark)),
      ],
    );
  }

  Widget _buildRegion(BuildContext context, String regionName,
      List<String> locationIds, String selected, List<String> favorites,
      bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRegionHeader(regionName, isDark),
        ...locationIds.map((id) {
          final loc = getLocationById(id);
          return _buildLocationTile(context, loc, selected, favorites, isDark);
        }),
      ],
    );
  }

  Widget _buildRegionHeader(String name, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s4,
        vertical: AppSpacing.s2,
      ),
      child: Text(
        name,
        style: TextStyle(
          fontSize: AppTypography.textXs,
          fontWeight: AppTypography.weightSemibold,
          color: isDark
              ? AppColorsDark.textTertiary
              : AppColors.textTertiary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildLocationTile(BuildContext context, Location loc,
      String selected, List<String> favorites, bool isDark,
      {Widget? trailing}) {
    final isSelected = loc.id == selected;
    final isFav = favorites.contains(loc.id);
    return ListTile(
      dense: true,
      title: Row(
        children: [
          Expanded(
            child: Text(
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
          ),
          if (trailing != null) ...[
            const SizedBox(width: 4),
            trailing,
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              widget.ref.read(favoritesProvider.notifier).toggle(loc.id);
            },
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                isFav ? Icons.favorite : Icons.favorite_border,
                size: 18,
                color: isFav
                    ? AppColors.accent
                    : isDark
                        ? AppColorsDark.textTertiary
                        : AppColors.textTertiary,
              ),
            ),
          ),
          if (isSelected) ...[
            const SizedBox(width: 4),
            Icon(Icons.check, color: AppColors.accent, size: 18),
          ],
        ],
      ),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.ref.read(selectedLocationIdProvider.notifier).select(loc.id);
        Navigator.pop(context);
      },
    );
  }
}
