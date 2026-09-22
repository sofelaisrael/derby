class AppSpacing {
  AppSpacing._();

  // Base scale
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  // Page
  static const double page = 24;

  // Radii
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 20;
  static const double radiusXl = 24;
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
