import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/tokens.dart';
import '../logic/units.dart';
import '../models/user_prefs.dart';
import '../state/preferences_provider.dart';

void showPreferencesEditor(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (_) => _PreferencesEditorSheet(ref: ref),
  );
}

class _PreferencesEditorSheet extends StatefulWidget {
  final WidgetRef ref;
  const _PreferencesEditorSheet({required this.ref});

  @override
  State<_PreferencesEditorSheet> createState() =>
      _PreferencesEditorSheetState();
}

class _PreferencesEditorSheetState extends State<_PreferencesEditorSheet> {
  late double _minWave;
  late double _maxWave;
  late double _maxWind;
  late String _windDir;
  late String _tide;

  @override
  void initState() {
    super.initState();
    final prefs = widget.ref.read(preferencesProvider);
    _minWave = prefs.minWaveHeight ?? 0.3;
    _maxWave = prefs.maxWaveHeight ?? 2.0;
    _maxWind = prefs.maxWindSpeed ?? 25.0;
    _windDir = prefs.preferredWindDir ?? 'any';
    _tide = prefs.preferredTide ?? 'any';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final subColor =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.s4, AppSpacing.s4, AppSpacing.s4, AppSpacing.s6),
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
            Text(
              'Preferences',
              style: TextStyle(
                fontSize: AppTypography.textLg,
                fontWeight: AppTypography.weightSemibold,
                color: textColor,
              ),
            ),
            const SizedBox(height: AppSpacing.s5),

            // Min wave height
            _buildSliderGroup(
              label: 'Min Wave Height',
              value: _minWave,
              min: 0.0,
              max: 3.0,
              divisions: 30,
              formatValue: () =>
                  '${formatWaveHeight(_minWave)} ft',
              contextLabels: 'Flat / Ankle / Knee / Waist',
              subColor: subColor,
              textColor: textColor,
              onChanged: (v) => setState(() {
                _minWave = v;
                if (_maxWave < _minWave + 0.2) _maxWave = _minWave + 0.2;
              }),
            ),
            const SizedBox(height: AppSpacing.s4),

            // Max wave height
            _buildSliderGroup(
              label: 'Max Wave Height',
              value: _maxWave,
              min: 0.5,
              max: 6.0,
              divisions: 55,
              formatValue: () =>
                  '${formatWaveHeight(_maxWave)} ft',
              contextLabels: 'Knee / Chest / Head / Overhead+',
              subColor: subColor,
              textColor: textColor,
              onChanged: (v) => setState(() {
                _maxWave = v;
                if (_minWave > _maxWave - 0.2) _minWave = _maxWave - 0.2;
              }),
            ),
            const SizedBox(height: AppSpacing.s4),

            // Max wind speed
            _buildSliderGroup(
              label: 'Max Wind Speed',
              value: _maxWind,
              min: 0.0,
              max: 60.0,
              divisions: 60,
              formatValue: () =>
                  '${formatWindSpeed(_maxWind)} mph',
              contextLabels: 'Glass / Light / Moderate / Strong',
              subColor: subColor,
              textColor: textColor,
              onChanged: (v) => setState(() => _maxWind = v),
            ),
            const SizedBox(height: AppSpacing.s5),

            // Wind direction chips
            _buildChipGroup(
              label: 'Wind Direction',
              options: const ['offshore', 'onshore', 'any'],
              displayLabels: const ['Offshore', 'Onshore', 'Any'],
              selected: _windDir,
              textColor: textColor,
              onSelected: (v) => setState(() => _windDir = v),
            ),
            const SizedBox(height: AppSpacing.s4),

            // Tide preference chips
            _buildChipGroup(
              label: 'Tide',
              options: const ['low', 'mid', 'high', 'any'],
              displayLabels: const ['Low', 'Mid', 'High', 'Any'],
              selected: _tide,
              textColor: textColor,
              onSelected: (v) => setState(() => _tide = v),
            ),
            const SizedBox(height: AppSpacing.s6),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _save,
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderGroup({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String Function() formatValue,
    required String contextLabels,
    required Color subColor,
    required Color textColor,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: AppTypography.textSm,
                fontWeight: AppTypography.weightMedium,
                color: textColor,
              ),
            ),
            Text(
              formatValue(),
              style: TextStyle(
                fontFamily: AppTypography.fontMono,
                fontSize: AppTypography.textSm,
                fontWeight: AppTypography.weightSemibold,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
        Text(
          contextLabels,
          style: TextStyle(
            fontSize: AppTypography.textXs,
            color: subColor,
          ),
        ),
      ],
    );
  }

  Widget _buildChipGroup({
    required String label,
    required List<String> options,
    required List<String> displayLabels,
    required String selected,
    required Color textColor,
    required ValueChanged<String> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: AppTypography.textSm,
            fontWeight: AppTypography.weightMedium,
            color: textColor,
          ),
        ),
        const SizedBox(height: AppSpacing.s2),
        Wrap(
          spacing: AppSpacing.s2,
          children: List.generate(options.length, (i) {
            final isSelected = options[i] == selected;
            return ChoiceChip(
              label: Text(displayLabels[i]),
              selected: isSelected,
              onSelected: (_) => onSelected(options[i]),
              selectedColor: AppColors.accentBgStrong,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.accent : textColor,
                fontWeight: isSelected
                    ? AppTypography.weightSemibold
                    : AppTypography.weightRegular,
                fontSize: AppTypography.textSm,
              ),
            );
          }),
        ),
      ],
    );
  }

  void _save() {
    final prefs = widget.ref.read(preferencesProvider);
    widget.ref.read(preferencesProvider.notifier).update(
          prefs.copyWith(
            minWaveHeight: _minWave,
            maxWaveHeight: _maxWave,
            maxWindSpeed: _maxWind,
            preferredWindDir: _windDir,
            preferredTide: _tide,
          ),
        );
    Navigator.pop(context);
  }
}
