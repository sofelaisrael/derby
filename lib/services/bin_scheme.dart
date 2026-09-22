import 'package:flutter/material.dart';
import '../models/bin_schedule.dart';

/// Council-independent presentation data for a bin: the colour, the
/// council-specific label, the icon, and the guide items. Resolved through
/// [CouncilScheme.resolve].
class BinPresentation {
  final int colorLight;
  final int colorDark;
  final String label;
  final IconData icon;
  final IconData badgeIcon;
  final List<String> items;

  /// Two-tone body/lid colours for swatches. For single-colour bins these
  /// default to the bin colour itself, so a swatch renders as a solid block.
  final Color bodyColor;
  final Color lidColor;
  final Color bodyColorDark;
  final Color lidColorDark;

  BinPresentation({
    required this.colorLight,
    required this.colorDark,
    required this.label,
    required this.icon,
    required this.badgeIcon,
    required this.items,
    Color? bodyColor,
    Color? lidColor,
    Color? bodyColorDark,
    Color? lidColorDark,
  })  : bodyColor = bodyColor ?? Color(colorLight),
        lidColor = lidColor ?? Color(colorLight),
        bodyColorDark = bodyColorDark ?? Color(colorDark),
        lidColorDark = lidColorDark ?? Color(colorDark);

  /// Theme-aware colours. Returns a [BinThemedColors] (a [Color] equal to the
  /// lid colour for backwards compatibility) exposing themed [bodyColor] and
  /// [lidColor] so swatches can render a two-tone body + lid.
  BinThemedColors themed(BuildContext ctx) {
    final dark = Theme.of(ctx).brightness == Brightness.dark;
    return BinThemedColors(
      dark ? colorDark : colorLight,
      bodyColor: dark ? bodyColorDark : bodyColor,
      lidColor: dark ? lidColorDark : lidColor,
    );
  }
}

/// Result of [BinPresentation.themed]: a [Color] (the lid colour, for any
/// caller that still treats the bin as a single colour) that also carries the
/// themed body/lid colours for two-tone swatches.
class BinThemedColors extends Color {
  final Color bodyColor;
  final Color lidColor;

  const BinThemedColors(super.value,
      {required this.bodyColor, required this.lidColor});
}

const _generalItems = <String>[
  'Non-recyclable household waste',
  'Bagged food waste',
  'Polystyrene',
  'Nappies and hygiene products',
  'Broken ceramics',
];

const _recyclingItems = <String>[
  'Paper and card',
  'Plastic bottles, pots, tubs and trays',
  'Tins and cans',
  'Clean foil and foil trays',
  'Cartons and Tetrapak',
];

const _gardenItems = <String>[
  'Grass cuttings and leaves',
  'Weeds and plants',
  'Twigs and small branches',
  'Dead flowers',
];

const _foodItems = <String>[
  'Food waste caddy liners',
  'All cooked and raw food',
  'Tea bags and coffee grounds',
  'Out-of-date food',
];

IconData _iconFor(WasteStream s) {
  switch (s) {
    case WasteStream.general:
      return Icons.delete_outline;
    case WasteStream.recycling:
      return Icons.recycling;
    case WasteStream.garden:
      return Icons.eco;
    case WasteStream.food:
      return Icons.restaurant;
  }
}

BinPresentation _mk(
  int light,
  int dark,
  String label,
  WasteStream stream,
  List<String> items, [
  Color? bodyColor,
  Color? lidColor,
  Color? bodyColorDark,
  Color? lidColorDark,
]) =>
    BinPresentation(
      colorLight: light,
      colorDark: dark,
      label: label,
      icon: _iconFor(stream),
      badgeIcon: _iconFor(stream),
      items: items,
      bodyColor: bodyColor,
      lidColor: lidColor,
      bodyColorDark: bodyColorDark,
      lidColorDark: lidColorDark,
    );

/// Resolves (councilSlug, stream) -> the correct bin presentation for that
/// council's real scheme. Unknown councils fall back to Derby.
class CouncilScheme {
  static BinPresentation resolve(String councilSlug, WasteStream stream) {
    final m = _schemes[councilSlug] ?? _schemes['derby']!;
    return (m[stream] ?? _schemes['derby']![stream])!;
  }

  /// The streams present in a council's scheme. Falls back to Derby for
  /// unknown councils.
  static List<WasteStream> streamsFor(String councilSlug) {
    final m = _schemes[councilSlug] ?? _schemes['derby']!;
    return m.keys.toList();
  }

  static final Map<String, Map<WasteStream, BinPresentation>> _schemes = {
    for (final slug in _councilSlugs)
      slug: {
        WasteStream.general: _derbyGeneral,
        WasteStream.recycling: _derbyRecycling,
        WasteStream.garden: _derbyGarden,
        WasteStream.food: _derbyFood,
      },
  };

  static const List<String> _councilSlugs = [
    'derby',
    'erewash',
    'ambervalley',
    'highpeak',
    'derbyshiredales',
    'bolsover',
    'chesterfield',
    'southderbyshire',
    'northeastderbyshire',
  ];

  // ── Derby (shared across all Derbyshire councils) ───────────
  static final _derbyGeneral = _mk(
      0xFF64748B, 0xFF94A3B8, 'Black bin', WasteStream.general, _generalItems);
  static final _derbyRecycling = _mk(
      0xFF3B82F6, 0xFF60A5FA, 'Blue bin', WasteStream.recycling, _recyclingItems);
  static final _derbyGarden = _mk(
      0xFF10B981, 0xFF34D399, 'Green bin', WasteStream.garden, _gardenItems);
  static final _derbyFood = _mk(
      0xFFF59E0B, 0xFFFBBF24, 'Food caddy', WasteStream.food, _foodItems);
}