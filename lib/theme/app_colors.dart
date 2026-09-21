import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF006239);
  static const Color primaryLight = Color(0xFF2D9B6E);
  static const Color accent = Color(0xFF7BAED7);
  static const Color accentLight = Color(0xFF9EC5E0);
  static const Color accentDark = Color(0xFF5A93C0);

  static const Color success = Color(0xFF006239);
  static const Color successLight = Color(0xFFD1F2E5);
  static const Color info = Color(0xFF7BAED7);
  static const Color infoLight = Color(0xFFE8F2FA);
  static const Color warning = Color(0xFFF7C900);
  static const Color warningLight = Color(0xFFFEF5CC);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);

  static const Color binGeneral = Color(0xFF7BAED7);
  static const Color binRecycling = Color(0xFF006239);
  static const Color binGarden = Color(0xFF1A7A52);
  static const Color binFood = Color(0xFFF7C900);

  static const Color lightBackground = Color(0xFFF0F7FC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF0FAF5);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightCardBorder = Color(0xFFD6E8F0);

  static const Color darkBackground = Color(0xFF0B1E16);
  static const Color darkSurface = Color(0xFF142D21);
  static const Color darkSurfaceVariant = Color(0xFF1C3A2C);
  static const Color darkCard = Color(0xFF142D21);
  static const Color darkCardBorder = Color(0xFF2A4F3C);

  static const Color lightTextPrimary = Color(0xFF0C1911);
  static const Color lightTextSecondary = Color(0xFF3D5249);
  static const Color lightTextTertiary = Color(0xFF7A8F86);

  static const Color darkTextPrimary = Color(0xFFF0F7F4);
  static const Color darkTextSecondary = Color(0xFFA8C4B8);
  static const Color darkTextTertiary = Color(0xFF6B8C7E);

  static const Color lightDivider = Color(0xFFD6E8F0);
  static const Color darkDivider = Color(0xFF2A4F3C);

  static const Color glassLight = Color(0x40FFFFFF);
  static const Color glassDark = Color(0x40142D21);
  static const Color glassBorderLight = Color(0x30FFFFFF);
  static const Color glassBorderDark = Color(0x301C3A2C);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [accent, primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [primary, Color(0xFFF7C900)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkSurfaceGradient = LinearGradient(
    colors: [darkSurface, darkBackground],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static Color forWasteStream(String name) {
    switch (name.toLowerCase()) {
      case 'general':
        return binGeneral;
      case 'recycling':
        return binRecycling;
      case 'garden':
        return binGarden;
      case 'food':
        return binFood;
      default:
        return binGeneral;
    }
  }
}
