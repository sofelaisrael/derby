import 'package:flutter/material.dart';

/// Color system for Derby Bins.
/// Premium, modern palette with Derby County-inspired dark theme.
class AppColors {
  AppColors._();

  // ── Brand ──
  static const Color primary = Color(0xFF1E293B);       // Dark charcoal
  static const Color primaryLight = Color(0xFF334155);   // Lighter charcoal
  static const Color accent = Color(0xFF6366F1);         // Indigo accent
  static const Color accentLight = Color(0xFF818CF8);    // Light indigo
  static const Color accentDark = Color(0xFF4F46E5);     // Dark indigo

  // ── Success / Info / Warning / Error ──
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);

  // ── Bin stream colors ──
  static const Color binGeneral = Color(0xFF64748B);
  static const Color binRecycling = Color(0xFF3B82F6);
  static const Color binGarden = Color(0xFF10B981);
  static const Color binFood = Color(0xFFF59E0B);

  // ── Light theme surfaces ──
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF1F5F9);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightCardBorder = Color(0xFFE2E8F0);

  // ── Dark theme surfaces ──
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkSurfaceVariant = Color(0xFF334155);
  static const Color darkCard = Color(0xFF1E293B);
  static const Color darkCardBorder = Color(0xFF334155);

  // ── Text ──
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextTertiary = Color(0xFF94A3B8);

  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextTertiary = Color(0xFF64748B);

  // ── Divider / Border ──
  static const Color lightDivider = Color(0xFFE2E8F0);
  static const Color darkDivider = Color(0xFF334155);

  // ── Glassmorphism ──
  static const Color glassLight = Color(0x40FFFFFF);     // 25% white
  static const Color glassDark = Color(0x401E293B);      // 25% charcoal
  static const Color glassBorderLight = Color(0x30FFFFFF);
  static const Color glassBorderDark = Color(0x30334155);

  // ── Gradient presets ──
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [accent, accentDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkSurfaceGradient = LinearGradient(
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Get the color for a waste stream name.
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
