/// Design tokens — ported from variables.css
import 'package:flutter/material.dart';

// --- Colors: Light theme ---
abstract final class AppColors {
  // Core backgrounds
  static const bgPrimary = Color(0xFFF5F7FA);
  static const bgSecondary = Color(0xFFFFFFFF);
  static const bgTertiary = Color(0xFFEEF1F5);
  static const bgSurface = Color(0xFFE8ECF1);

  // Text
  static const textPrimary = Color(0xFF1A1A2E);
  static const textSecondary = Color(0xFF6B7280);
  static const textTertiary = Color(0xFF697183);

  // Accent / Brand — Teal
  static const accent = Color(0xFF4DB8A4);
  static const accentLight = Color(0xFF7DD3C0);
  static const accentDark = Color(0xFF3A9A88);
  static final accentBg = const Color(0xFF4DB8A4).withValues(alpha: 0.08);
  static final accentBgStrong = const Color(0xFF4DB8A4).withValues(alpha: 0.15);

  // Condition quality
  static const conditionEpic = Color(0xFF22C55E);
  static const conditionGood = Color(0xFF4DB8A4);
  static const conditionFair = Color(0xFFF59E0B);
  static const conditionPoor = Color(0xFFEF4444);

  // Utility
  static final border = Colors.black.withValues(alpha: 0.06);
  static final borderStrong = Colors.black.withValues(alpha: 0.10);
}

// --- Colors: Dark theme ---
abstract final class AppColorsDark {
  static const bgPrimary = Color(0xFF0F1923);
  static const bgSecondary = Color(0xFF162230);
  static const bgTertiary = Color(0xFF1E2D3D);
  static const bgSurface = Color(0xFF253545);

  static const textPrimary = Color(0xFFE2E8F0);
  static const textSecondary = Color(0xFF94A3B8);
  static const textTertiary = Color(0xFF8494A7);

  // Accent stays teal
  static final accentBg = const Color(0xFF4DB8A4).withValues(alpha: 0.12);
  static final accentBgStrong = const Color(0xFF4DB8A4).withValues(alpha: 0.20);

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

  static const textXs = 12.0;
  static const textSm = 14.0;
  static const textBase = 16.0;
  static const textLg = 18.0;
  static const textXl = 24.0;
  static const text2xl = 32.0;
  static const text3xl = 48.0;

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

// --- Durations ---
abstract final class AppDurations {
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 300);
}
