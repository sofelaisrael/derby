import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'spacing.dart';

class AppTheme {
  AppTheme._();

  static const String _font = 'Plus Jakarta Sans';

  // ── Color schemes (manually composed for full control) ──────────────
  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF1F3D2B),
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFE3EBE2),
    onPrimaryContainer: Color(0xFF1C2620),
    secondary: Color(0xFFA9714B),
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFF3E7DB),
    onSecondaryContainer: Color(0xFF5C3A24),
    tertiary: Color(0xFF7C8B6F),
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFE7ECE2),
    onTertiaryContainer: Color(0xFF2E3A2A),
    error: Color(0xFFDC2626),
    onError: Colors.white,
    errorContainer: Color(0xFFFDE1E1),
    onErrorContainer: Color(0xFF7F1D1D),
    surface: AppColors.surfaceElevated,
    onSurface: AppColors.textPrimary,
    surfaceDim: Color(0xFFE8E3D8),
    surfaceBright: Colors.white,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Color(0xFFF6F3EC),
    surfaceContainer: Color(0xFFEFEAE0),
    surfaceContainerHigh: Color(0xFFE4DFD3),
    surfaceContainerHighest: Color(0xFFD8D2C4),
    onSurfaceVariant: AppColors.textSecondary,
    outline: AppColors.textMuted,
    outlineVariant: AppColors.border,
    shadow: Color(0xFF1C2620),
    scrim: Color(0x991C2620),
    inverseSurface: Color(0xFF1F3D2B),
    onInverseSurface: Color(0xFFF6F3EC),
    inversePrimary: Color(0xFF7FA98C),
    surfaceTint: AppColors.primary,
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF7FA98C),
    onPrimary: Color(0xFF121A16),
    primaryContainer: Color(0xFF22332A),
    onPrimaryContainer: Color(0xFFD6E8DA),
    secondary: Color(0xFFC08A5E),
    onSecondary: Color(0xFF3A2413),
    secondaryContainer: Color(0xFF4A3322),
    onSecondaryContainer: Color(0xFFF0D9C4),
    tertiary: Color(0xFF7C8B6F),
    onTertiary: Color(0xFF1C2620),
    tertiaryContainer: Color(0xFF2E3A2A),
    onTertiaryContainer: Color(0xFFDCE4D4),
    error: Color(0xFFF87171),
    onError: Color(0xFF5F1111),
    errorContainer: Color(0xFF4E2A28),
    onErrorContainer: Color(0xFFF9CCC4),
    surface: AppColorsDark.surfaceElevated,
    onSurface: AppColorsDark.textPrimary,
    surfaceDim: Color(0xFF121A16),
    surfaceBright: Color(0xFF1B2620),
    surfaceContainerLowest: Color(0xFF0E1511),
    surfaceContainerLow: Color(0xFF141D17),
    surfaceContainer: Color(0xFF161F1A),
    surfaceContainerHigh: Color(0xFF1B2620),
    surfaceContainerHighest: Color(0xFF2A352D),
    onSurfaceVariant: AppColorsDark.textSecondary,
    outline: AppColorsDark.textMuted,
    outlineVariant: AppColorsDark.border,
    shadow: Colors.black,
    scrim: Color(0xBF000000),
    inverseSurface: Color(0xFFECF0E8),
    onInverseSurface: Color(0xFF1C2620),
    inversePrimary: Color(0xFF1F3D2B),
    surfaceTint: Color(0xFF7FA98C),
  );

  // ── Button style (single source, reused by all button types) ────────
  static final ButtonStyle _buttonStyle = FilledButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.45),
    disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
    elevation: 0,
    minimumSize: const Size(0, 52),
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.1),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    ),
  );

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: _lightScheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: _font,
      extensions: const [BinColors.light],

      textTheme: _baseText(AppColors.textPrimary),

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: _font,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: AppColors.textPrimary,
        ),
      ),

      cardTheme: _cardTheme(AppColors.surfaceElevated),
      dialogTheme: _dialogTheme(AppColors.surfaceElevated),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderLight,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.primaryLight,
        circularTrackColor: Colors.transparent,
      ),
      switchTheme: _switchTheme(AppColors.primary),
      chipTheme: _chipTheme(AppColors.surfaceElevated, AppColors.primaryLight),
      inputDecorationTheme: _inputTheme(AppColors.surfaceTinted, AppColors.primary, AppColors.error),
      filledButtonTheme: FilledButtonThemeData(style: _buttonStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: _buttonStyle),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radiusMd)),
        ),
        elevation: 0,
      ),
      navigationBarTheme: _navBarTheme(AppColors.primaryLight, AppColors.primary),
      visualDensity: VisualDensity.standard,
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: _darkScheme,
      scaffoldBackgroundColor: AppColorsDark.background,
      fontFamily: _font,
      extensions: const [BinColors.dark],

      textTheme: _baseText(AppColorsDark.textPrimary),

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: _font,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: AppColorsDark.textPrimary,
        ),
      ),

      cardTheme: _cardTheme(AppColorsDark.surfaceElevated),
      dialogTheme: _dialogTheme(AppColorsDark.surfaceElevated),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColorsDark.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColorsDark.borderLight,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColorsDark.textSecondary,
        textColor: AppColorsDark.textPrimary,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColorsDark.primary,
        linearTrackColor: AppColorsDark.primaryLight,
        circularTrackColor: Colors.transparent,
      ),
      switchTheme: _switchTheme(AppColorsDark.primary),
      chipTheme: _chipTheme(AppColorsDark.surfaceElevated, AppColorsDark.primaryLight),
      inputDecorationTheme: _inputTheme(AppColorsDark.surface, AppColorsDark.primary, AppColorsDark.error),
      filledButtonTheme: FilledButtonThemeData(
        style: _buttonStyle.copyWith(backgroundColor: const WidgetStatePropertyAll(AppColorsDark.primary)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _buttonStyle.copyWith(backgroundColor: const WidgetStatePropertyAll(AppColorsDark.primary)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColorsDark.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColorsDark.surfaceElevated,
        contentTextStyle: TextStyle(color: AppColorsDark.textPrimary, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radiusMd)),
        ),
        elevation: 0,
      ),
      navigationBarTheme: _navBarTheme(AppColorsDark.primaryLight, AppColorsDark.primary),
      visualDensity: VisualDensity.standard,
    );
  }

  static TextTheme _baseText(Color ink) {
    return TextTheme(
      displayLarge: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, height: 1.0, letterSpacing: -1.5, color: ink),
      displayMedium: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, height: 1.05, letterSpacing: -1.0, color: ink),
      displaySmall: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.1, letterSpacing: -0.5, color: ink),
      headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: -0.4, color: ink),
      headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.3, color: ink),
      headlineSmall: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.3, color: ink),
      titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.3, color: ink),
      titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.3, color: ink),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.3, color: ink),
      bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, height: 1.5, color: ink),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5, color: ink),
      bodySmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, height: 1.45, color: ink),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.3, color: ink),
      labelMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.3, color: ink),
      labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5, height: 1.3, color: ink),
    ).apply(fontFamily: _font);
  }

  static CardThemeData _cardTheme(Color surface) {
    return CardThemeData(
      color: surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
    );
  }

  static DialogThemeData _dialogTheme(Color surface) {
    return DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
    );
  }

  static SwitchThemeData _switchTheme(Color active) {
    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return active;
        return Colors.white;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return active.withValues(alpha: 0.4);
        return AppColors.border;
      }),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      trackOutlineWidth: const WidgetStatePropertyAll(0),
    );
  }

  static ChipThemeData _chipTheme(Color surface, Color selected) {
    return ChipThemeData(
      backgroundColor: surface,
      selectedColor: selected,
      side: const BorderSide(color: AppColors.border),
      shape: const StadiumBorder(),
      labelStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      elevation: 0,
    );
  }

  static InputDecorationTheme _inputTheme(Color fill, Color focus, Color error) {
    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
      hintStyle: const TextStyle(color: AppColors.textMuted),
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
      floatingLabelStyle: TextStyle(color: focus, fontWeight: FontWeight.w600),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        borderSide: BorderSide(color: focus, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        borderSide: BorderSide(color: error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        borderSide: BorderSide(color: error, width: 2),
      ),
    );
  }

  static NavigationBarThemeData _navBarTheme(Color indicator, Color onIndicator) {
    return NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      indicatorColor: indicator,
      elevation: 0,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: selected ? onIndicator : AppColors.textMuted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? onIndicator : AppColors.textMuted,
          size: 24,
        );
      }),
    );
  }
}