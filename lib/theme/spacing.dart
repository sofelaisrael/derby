class AppSpacing {
  AppSpacing._();

  // Base scale
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
  static const double xxl = 40;

  // Page
  static const double page = 20;

  // Radii
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radiusFull = 999;

  // Legacy aliases
  static const double cardRadius = radiusXl;
  static const double buttonRadius = radiusMd;
}

/// Legacy spacing values (from old theme.dart — tighter spacing)
class Spacing {
  Spacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;
}

/// Legacy radius values (from old theme.dart)
class AppRadius {
  AppRadius._();

  static const double container = 16;
  static const double pill = 999;
}
