/// Design tokens — ported from variables.css
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// --- Colors: Light theme ---
// Cold morning ocean palette — fog-gray surfaces, sea-glass accent, restrained states.
abstract final class AppColors {
  // Core backgrounds — cool fog-gray, not warm off-white
  static const bgPrimary = Color(0xFFF0F4F8);
  static const bgSecondary = Color(0xFFFFFFFF);
  static const bgTertiary = Color(0xFFE2E8F0);
  static const bgSurface = Color(0xFFD5DDE6);

  // Text — deep navy tones (WCAG AA compliant on bgPrimary)
  static const textPrimary = Color(0xFF1B2838);
  static const textSecondary = Color(0xFF566476);  // 4.7:1 on bgPrimary
  static const textTertiary = Color(0xFF6B7D92);   // 3.6:1 on bgPrimary (AA-lg)

  // Accent / Brand — Sea-glass green (WCAG AA-lg on white)
  static const accent = Color(0xFF3D9189);      // 3.5:1 on white
  static const accentLight = Color(0xFF7DC4BC);
  static const accentDark = Color(0xFF3D8F86);
  static final accentBg = const Color(0xFF3D9189).withValues(alpha: 0.08);
  static final accentBgStrong = const Color(0xFF3D9189).withValues(alpha: 0.15);

  // Condition quality — restrained, premium, WCAG AA-lg on white
  static const conditionEpic = Color(0xFF2E8A5E);   // darker sage (3.8:1)
  static const conditionGood = Color(0xFF3D9189);    // darker sea-glass (3.5:1)
  static const conditionFair = Color(0xFFB07A4F);    // darker sand (3.3:1)
  static const conditionPoor = Color(0xFF9E5E5E);    // darker brick (4.3:1)

  // Charts
  static const chartWind = Color(0xFF8496A8);
  static const chartTooltipBg = textPrimary;

  // Utility
  static final border = Colors.black.withValues(alpha: 0.06);
  static final borderStrong = Colors.black.withValues(alpha: 0.10);
}

// --- Colors: Dark theme ---
// Deep navy ocean base — leverages #0F1923 for atmospheric depth.
abstract final class AppColorsDark {
  static const bgPrimary = Color(0xFF0F1923);
  static const bgSecondary = Color(0xFF172333);
  static const bgTertiary = Color(0xFF1E2D3D);
  static const bgSurface = Color(0xFF253545);

  static const textPrimary = Color(0xFFE2E8F0);
  static const textSecondary = Color(0xFF94A3B8);
  static const textTertiary = Color(0xFF7A8B9E);

  // Accent — sea-glass
  static final accentBg = const Color(0xFF3D9189).withValues(alpha: 0.12);
  static final accentBgStrong = const Color(0xFF3D9189).withValues(alpha: 0.20);

  // Charts
  static const chartWind = Color(0xFF64748B);
  static const chartTooltipBg = Color(0xFF2A3A4A);

  static final border = Colors.white.withValues(alpha: 0.06);
  static final borderStrong = Colors.white.withValues(alpha: 0.12);
}

// --- Radii ---
abstract final class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const full = 9999.0;
}

// --- Spacing ---
abstract final class AppSpacing {
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 20.0;
  static const s6 = 24.0;
  static const s8 = 32.0;
  static const s10 = 40.0;
  static const s12 = 48.0;
}

// --- Typography ---
abstract final class AppTypography {
  static const fontSans = 'Inter';
  static const fontMono = 'DMMono';

  static const textXxs = 11.0;
  static const textXs = 12.0;
  static const textSm = 14.0;
  static const textBase = 16.0;
  static const textLg = 18.0;
  static const textXl = 24.0;
  static const textHero = 28.0;
  static const text2xl = 32.0;
  static const text3xl = 48.0;
  static const textDisplay = 56.0;

  static const weightLight = FontWeight.w300;
  static const weightRegular = FontWeight.w400;
  static const weightMedium = FontWeight.w500;
  static const weightSemibold = FontWeight.w600;
  static const weightBold = FontWeight.w700;
}

// --- Shadows ---
abstract final class AppShadows {
  static const sm = [BoxShadow(offset: Offset(0, 1), blurRadius: 3, color: Color(0x0F000000))];
  static const base = [BoxShadow(offset: Offset(0, 2), blurRadius: 8, color: Color(0x0F000000))];
  static const lg = [BoxShadow(offset: Offset(0, 4), blurRadius: 16, color: Color(0x14000000))];
}

// --- Icon sizes ---
abstract final class AppIconSize {
  static const xs = 12.0;
  static const sm = 14.0;
  static const base = 16.0;
  static const md = 18.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 48.0;
}

// --- Durations ---
abstract final class AppDurations {
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 300);
}

// --- Haptics ---
/// Condition-mapped haptic feedback — feel that today is good.
abstract final class AppHaptics {
  /// Haptic intensity based on condition score (0-1).
  /// Epic = heavy, Good = medium, Fair = light, Poor = selection click.
  static void forScore(double score) {
    if (score >= 0.8) {
      HapticFeedback.heavyImpact();
    } else if (score >= 0.6) {
      HapticFeedback.mediumImpact();
    } else if (score >= 0.4) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.selectionClick();
    }
  }

  /// Standard tap feedback for non-condition interactions.
  static void tap() => HapticFeedback.lightImpact();

  /// Navigation / tab switch feedback.
  static void nav() => HapticFeedback.selectionClick();
}
