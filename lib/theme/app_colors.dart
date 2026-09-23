import 'package:flutter/material.dart';

// ─── Light Colors ─────────────────────────────────────────────

class AppColors {
  AppColors._();

  static const primary = Color(0xFF1F3D2B);
  static const primaryLight = Color(0xFFE3EBE2);
  static const accent = Color(0xFFA9714B);

  static const background = Color(0xFFF6F3EC);
  static const surface = Color(0xFFF6F3EC);
  static const surfaceElevated = Color(0xFFFFFFFF);
  static const surfaceTinted = Color(0xFFEFEAE0);

  static const textPrimary = Color(0xFF1C2620);
  static const textSecondary = Color(0xFF4A564C);
  static const textMuted = Color(0xFF7A8478);

  static const border = Color(0xFFE4DFD3);
  static const borderLight = Color(0xFFECE7DC);

  static const greenBin = Color(0xFF10B981);
  static const blueBin = Color(0xFF3B82F6);
  static const glassBin = Color(0xFF64748B);
  static const foodBin = Color(0xFFF59E0B);

  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFD97706);
  static const error = Color(0xFFDC2626);

  static const calendarToday = Color(0xFF1F3D2B);
  static const calendarDisabled = Color(0xFFEFEAE0);
  static const calendarCollection = Color(0xFFE3EBE2);

  static const textHint = textMuted;
  static const card = surfaceElevated;
  static const shadow = Color.fromRGBO(20, 33, 26, 0.06);
  static const bg = background;
  static const ink = textPrimary;
  static const inkSoft = textSecondary;
  static const inkFaint = textMuted;
  static const line = border;
  static const danger = error;
}

/// Adaptive foreground colour for text/icons sitting ON a bin-colour swatch:
/// dark ink on light bins, white on dark bins, so every label stays legible.
Color binForeground(Color bg) =>
    bg.computeLuminance() > 0.5 ? const Color(0xFF1F2937) : Colors.white;

// ─── Dark Colors ──────────────────────────────────────────────

class AppColorsDark {
  AppColorsDark._();

  // Accent indigo — reserved for buttons, links, selections and highlights,
  // never the page substrate itself.
  static const primary = Color(0xFF7FA98C);
  static const primaryLight = Color(0xFF22332A);
  static const accent = Color(0xFFC08A5E);

  // Neutral near-black surfaces, matching how mainstream apps handle dark
  // mode: a near-black page with subtle outlined elevations. The brand indigo
  // is no longer the base tint.
  static const background = Color(0xFF121A16);
  static const surface = Color(0xFF161F1A);
  static const surfaceElevated = Color(0xFF1B2620);
  static const surfaceTinted = Color(0xFF202B24);

  static const textPrimary = Color(0xFFECF0E8);
  static const textSecondary = Color(0xFFB7C0B4);
  static const textMuted = Color(0xFF808B80);

  static const border = Color(0xFF2A352D);
  static const borderLight = Color(0xFF253028);

  static const greenBin = Color(0xFF34D399);
  static const blueBin = Color(0xFF60A5FA);
  static const glassBin = Color(0xFF94A3B8);
  static const foodBin = Color(0xFFFBBF24);

  static const success = Color(0xFF4ADE80);
  static const warning = Color(0xFFFBBF24);
  static const error = Color(0xFFF87171);

  static const calendarToday = Color(0xFF7FA98C);
  static const calendarDisabled = Color(0xFF1B2620);
  static const calendarCollection = Color(0xFF22332A);

  static const textHint = textMuted;
  static const card = surfaceElevated;
  static const bg = background;
  static const ink = textPrimary;
  static const inkSoft = textSecondary;
  static const inkFaint = textMuted;
  static const line = border;
  static const danger = error;
}

// ─── ThemeExtension for contextual color access ───────────────

class BinColors extends ThemeExtension<BinColors> {
  final Color primary;
  final Color primaryLight;
  final Color accent;

  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceTinted;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  final Color border;
  final Color borderLight;

  final Color greenBin;
  final Color blueBin;
  final Color glassBin;
  final Color foodBin;

  final Color success;
  final Color warning;
  final Color error;

  final Color calendarToday;
  final Color calendarDisabled;
  final Color calendarCollection;

  const BinColors({
    required this.primary,
    required this.primaryLight,
    required this.accent,
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceTinted,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.borderLight,
    required this.greenBin,
    required this.blueBin,
    required this.glassBin,
    required this.foodBin,
    required this.success,
    required this.warning,
    required this.error,
    required this.calendarToday,
    required this.calendarDisabled,
    required this.calendarCollection,
  });

  static const light = BinColors(
    primary: AppColors.primary,
    primaryLight: AppColors.primaryLight,
    accent: AppColors.accent,
    background: AppColors.background,
    surface: AppColors.surface,
    surfaceElevated: AppColors.surfaceElevated,
    surfaceTinted: AppColors.surfaceTinted,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textMuted: AppColors.textMuted,
    border: AppColors.border,
    borderLight: AppColors.borderLight,
    greenBin: AppColors.greenBin,
    blueBin: AppColors.blueBin,
    glassBin: AppColors.glassBin,
    foodBin: AppColors.foodBin,
    success: AppColors.success,
    warning: AppColors.warning,
    error: AppColors.error,
    calendarToday: AppColors.calendarToday,
    calendarDisabled: AppColors.calendarDisabled,
    calendarCollection: AppColors.calendarCollection,
  );

  static const dark = BinColors(
    primary: AppColorsDark.primary,
    primaryLight: AppColorsDark.primaryLight,
    accent: AppColorsDark.accent,
    background: AppColorsDark.background,
    surface: AppColorsDark.surface,
    surfaceElevated: AppColorsDark.surfaceElevated,
    surfaceTinted: AppColorsDark.surfaceTinted,
    textPrimary: AppColorsDark.textPrimary,
    textSecondary: AppColorsDark.textSecondary,
    textMuted: AppColorsDark.textMuted,
    border: AppColorsDark.border,
    borderLight: AppColorsDark.borderLight,
    greenBin: AppColorsDark.greenBin,
    blueBin: AppColorsDark.blueBin,
    glassBin: AppColorsDark.glassBin,
    foodBin: AppColorsDark.foodBin,
    success: AppColorsDark.success,
    warning: AppColorsDark.warning,
    error: AppColorsDark.error,
    calendarToday: AppColorsDark.calendarToday,
    calendarDisabled: AppColorsDark.calendarDisabled,
    calendarCollection: AppColorsDark.calendarCollection,
  );

  @override
  BinColors copyWith({
    Color? primary,
    Color? primaryLight,
    Color? accent,
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceTinted,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? border,
    Color? borderLight,
    Color? greenBin,
    Color? blueBin,
    Color? glassBin,
    Color? foodBin,
    Color? success,
    Color? warning,
    Color? error,
    Color? calendarToday,
    Color? calendarDisabled,
    Color? calendarCollection,
  }) {
    return BinColors(
      primary: primary ?? this.primary,
      primaryLight: primaryLight ?? this.primaryLight,
      accent: accent ?? this.accent,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceTinted: surfaceTinted ?? this.surfaceTinted,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      borderLight: borderLight ?? this.borderLight,
      greenBin: greenBin ?? this.greenBin,
      blueBin: blueBin ?? this.blueBin,
      glassBin: glassBin ?? this.glassBin,
      foodBin: foodBin ?? this.foodBin,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      calendarToday: calendarToday ?? this.calendarToday,
      calendarDisabled: calendarDisabled ?? this.calendarDisabled,
      calendarCollection: calendarCollection ?? this.calendarCollection,
    );
  }

  @override
  BinColors lerp(ThemeExtension<BinColors>? other, double t) {
    if (other is! BinColors) return this;
    return BinColors(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceTinted: Color.lerp(surfaceTinted, other.surfaceTinted, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderLight: Color.lerp(borderLight, other.borderLight, t)!,
      greenBin: Color.lerp(greenBin, other.greenBin, t)!,
      blueBin: Color.lerp(blueBin, other.blueBin, t)!,
      glassBin: Color.lerp(glassBin, other.glassBin, t)!,
      foodBin: Color.lerp(foodBin, other.foodBin, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      calendarToday: Color.lerp(calendarToday, other.calendarToday, t)!,
      calendarDisabled: Color.lerp(calendarDisabled, other.calendarDisabled, t)!,
      calendarCollection: Color.lerp(calendarCollection, other.calendarCollection, t)!,
    );
  }
}

extension BuildContextColors on BuildContext {
  BinColors get binColors => Theme.of(this).extension<BinColors>()!;
}
