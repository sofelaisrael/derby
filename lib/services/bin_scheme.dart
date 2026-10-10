import 'package:flutter/material.dart';
import '../models/bin_schedule.dart';

/// Council-independent presentation data for a bin: the colour, the
/// council-specific label, the icon, and the guide items. Resolved through
/// [CouncilScheme.resolve].
class BinPresentation {
  final int colorLight;
  final int colorDark;
  final String label;
  final IconData? icon;
  final String? assetPath;
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
    this.icon,
    this.assetPath,
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

/// Amber Valley is the one council whose food container colour has never been
/// published, and the service is still phasing in through 2026. This list is
/// the user-facing disclosure; the swatch uses the neutral `unknown` token.
const _amberValleyFoodItems = <String>[
  'Your caddy is a 23L outdoor caddy with a 5L indoor kitchen caddy',
  'Amber Valley has not published the caddy colour, so it is shown in neutral grey',
  'Weekly collections are being rolled out in phases across 2026',
  'If food dates appear for your address, your property is in the roll-out',
  'If they show as "Unknown", your property is not included yet',
  'Compostable caddy liners certified to EN 13432 only',
  'No packaging, no plastic bin liners, no liquids',
];

/// Amber Valley runs green bags instead of a recycling bin at some properties.
const _amberValleyRecyclingItems = <String>[
  ..._recyclingItems,
  'Some properties use green reusable bags instead of a grey bin',
  'Glass goes in the inner caddy, not loose in the bin',
];

/// HIGH confidence, upgraded from MEDIUM. DDDC's own collection calendar PDF
/// contains the literal cell value "Green food caddy" -- a council-stated
/// colour rather than a photo inference or a third-party tracker. The same
/// source set states: "All households are provided with a 5 litre internal
/// kitchen food caddy and a 23 litre kerbside caddy to dispose of food waste,
/// free of charge", and "a 140 litre grey bin" for household waste (the general
/// stream, already correct above).
///
/// No collection frequency is stated, and that is unchanged and still
/// deliberate: the pattern varies by area and we have no sourced cadence, so
/// any "emptied weekly" shown to a user would be an assertion we cannot back.
/// See the cadence test in test/bin_scheme_test.dart. (Confidence is research
/// state, not something a user can act on -- it lives here, not in the list.)
const _derbyshireDalesFoodItems = <String>[
  ..._foodItems,
  'Green 23 litre outdoor caddy',
  'With a smaller 5 litre indoor kitchen caddy',
  'Derbyshire Dales provides both caddies free of charge, so you only need to buy liners',
];

/// High Peak issues a silver indoor kitchen caddy as well as the green outdoor
/// one. Not shown as its own stream: it is the indoor half of the same service.
const _highPeakFoodItems = <String>[
  ..._foodItems,
  'High Peak also issues a silver indoor kitchen caddy',
];

/// Bolsover's green garden collection stops over winter.
const _bolsoverGardenItems = <String>[
  ..._gardenItems,
  'Bolsover suspends green garden collections over winter',
];

IconData? _iconFor(WasteStream s) {
  switch (s) {
    case WasteStream.general:
      return null;
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
      assetPath: stream == WasteStream.general ? 'assets/icons/bin.svg' : null,
      items: items,
      bodyColor: bodyColor,
      lidColor: lidColor,
      bodyColorDark: bodyColorDark,
      lidColorDark: lidColorDark,
    );

// ── Palette ────────────────────────────────────────────────────────────────
// charcoal / blue / green mirror the existing theme tokens, which stay the
// single source of truth for those three.

const _charcoal = 0xFF343A40;
const _charcoalDark = 0xFF4B5563;
const _blue = 0xFF3B82F6;
const _blueDark = 0xFF60A5FA;
const _green = 0xFF10B981;
const _greenDark = 0xFF34D399;

/// hue ~25 deg. Kept distinct from the accent colour so a bin never reads as a
/// button, and ~55 deg away from [_burgundy].
const _brown = 0xFF7B4B2A;
const _brownDark = 0xFFA97C52;

/// hue ~340 deg. Bolsover and North East Derbyshire each run a burgundy
/// recycling bin alongside a brown food caddy; the hue gap is the only thing
/// separating them at a glance, so it must not narrow.
const _burgundy = 0xFF8E1F4B;
const _burgundyDark = 0xFFBE5C82;

const _grey = 0xFF6B7280;
const _greyDark = 0xFF9CA3AF;

/// Deliberately hue-less neutral for containers whose colour no council has
/// published. See [_amberValleyFoodItems].
const _unknown = 0xFF8E8E93;
const _unknownDark = 0xFFB6B6BD;

/// Resolves (councilSlug, stream) -> the correct bin presentation for that
/// council's real scheme. Unknown councils fall back to Derby, as does an
/// unknown stream within a known council.
class CouncilScheme {
  static BinPresentation resolve(String councilSlug, WasteStream stream) {
    final m = _schemes[councilSlug] ?? _schemes['derby']!;
    return (m[stream] ?? _schemes['derby']![stream])!;
  }

  /// The streams this council actually offers, in canonical order. Falls back
  /// to Derby for unknown councils.
  static List<WasteStream> streamsFor(String councilSlug) {
    final m = _schemes[councilSlug] ?? _schemes['derby']!;
    return [
      for (final stream in _streamOrder)
        if (m.containsKey(stream)) stream
    ];
  }

  static const List<WasteStream> _streamOrder = [
    WasteStream.general,
    WasteStream.recycling,
    WasteStream.garden,
    WasteStream.food,
  ];

  // ── Derby City Council ───────────────────────────────────────────────────
  // Black refuse, blue recycling, brown garden, green 23L outdoor food caddy.
  static final _derby = <WasteStream, BinPresentation>{
    WasteStream.general: _mk(_charcoal, _charcoalDark, 'Black bin',
        WasteStream.general, _generalItems),
    WasteStream.recycling: _mk(_blue, _blueDark, 'Blue bin',
        WasteStream.recycling, _recyclingItems),
    WasteStream.garden: _mk(_brown, _brownDark, 'Brown bin',
        WasteStream.garden, _gardenItems),
    WasteStream.food: _mk(_green, _greenDark, 'Green food caddy',
        WasteStream.food, _foodItems),
  };

  // ── Erewash Borough Council ──────────────────────────────────────────────
  static final _erewash = <WasteStream, BinPresentation>{
    WasteStream.general: _mk(_charcoal, _charcoalDark, 'Black bin',
        WasteStream.general, _generalItems),
    WasteStream.recycling: _mk(_blue, _blueDark, 'Blue bin',
        WasteStream.recycling, _recyclingItems),
    WasteStream.garden: _mk(_brown, _brownDark, 'Brown bin',
        WasteStream.garden, _gardenItems),
    WasteStream.food: _mk(_green, _greenDark, 'Green food caddy',
        WasteStream.food, _foodItems),
  };

  // ── Amber Valley Borough Council ─────────────────────────────────────────
  // COLLISION: green is both refuse and garden. Refuse is a green 240/140L
  // wheeled bin; garden is the same green with a BROWN LID.
  static final _ambervalley = <WasteStream, BinPresentation>{
    WasteStream.general: _mk(_green, _greenDark, 'Green refuse bin',
        WasteStream.general, _generalItems),
    WasteStream.recycling: _mk(_grey, _greyDark, 'Grey bin',
        WasteStream.recycling, _amberValleyRecyclingItems),
    WasteStream.garden: _mk(
      _brown, _brownDark, 'Green garden bin', WasteStream.garden, _gardenItems,
      Color(_green), null, Color(_greenDark), null,
    ),
    WasteStream.food: _mk(_unknown, _unknownDark, 'Food caddy',
        WasteStream.food, _amberValleyFoodItems),
  };

  // ── High Peak Borough Council ────────────────────────────────────────────
  // COLLISION: green is both the food caddy and the opt-in garden bin.
  //
  // ASSUMPTION, NOT RESEARCHED FACT: High Peak's garden container is described
  // in the source material as "Green-lidded" with NO body colour stated, unlike
  // Derbyshire Dales (below), whose grey body IS sourced. `Color(_grey)` here is
  // a neutral placeholder chosen so the swatch reads as two-tone rather than
  // inventing a brand colour. Confirm against High Peak's own bin page before
  // treating this body colour as fact.
  static final _highpeak = <WasteStream, BinPresentation>{
    WasteStream.general: _mk(_charcoal, _charcoalDark, 'Black bin',
        WasteStream.general, _generalItems),
    WasteStream.recycling: _mk(_brown, _brownDark, 'Brown bin',
        WasteStream.recycling, _recyclingItems),
    WasteStream.garden: _mk(
      _green, _greenDark, 'Green garden bin', WasteStream.garden, _gardenItems,
      Color(_grey), null, Color(_greyDark), null,
    ),
    WasteStream.food: _mk(_green, _greenDark, 'Green food caddy',
        WasteStream.food, _highPeakFoodItems),
  };

  // ── Derbyshire Dales District Council ────────────────────────────────────
  // Every container is a grey body; only the lid identifies recycling and
  // garden. COLLISION: the green garden lid and the green food caddy.
  static final _derbyshiredales = <WasteStream, BinPresentation>{
    WasteStream.general: _mk(_grey, _greyDark, 'Grey refuse bin',
        WasteStream.general, _generalItems),
    WasteStream.recycling: _mk(
      _blue, _blueDark, 'Blue-lidded bin', WasteStream.recycling,
      _recyclingItems, Color(_grey), null, Color(_greyDark), null,
    ),
    WasteStream.garden: _mk(
      _green, _greenDark, 'Green-lidded bin', WasteStream.garden, _gardenItems,
      Color(_grey), null, Color(_greyDark), null,
    ),
    WasteStream.food: _mk(_green, _greenDark, 'Green food caddy',
        WasteStream.food, _derbyshireDalesFoodItems),
  };

  // ── Bolsover District Council ────────────────────────────────────────────
  // Calendar A/B by town. Green garden suspends over winter.
  static final _bolsover = <WasteStream, BinPresentation>{
    WasteStream.general: _mk(_charcoal, _charcoalDark, 'Black bin',
        WasteStream.general, _generalItems),
    WasteStream.recycling: _mk(_burgundy, _burgundyDark, 'Burgundy bin',
        WasteStream.recycling, _recyclingItems),
    WasteStream.garden: _mk(_green, _greenDark, 'Green bin',
        WasteStream.garden, _bolsoverGardenItems),
    WasteStream.food: _mk(_brown, _brownDark, 'Brown food caddy',
        WasteStream.food, _foodItems),
  };

  // ── Chesterfield Borough Council ─────────────────────────────────────────
  static final _chesterfield = <WasteStream, BinPresentation>{
    WasteStream.general: _mk(_charcoal, _charcoalDark, 'Black bin',
        WasteStream.general, _generalItems),
    WasteStream.recycling: _mk(_blue, _blueDark, 'Blue bin',
        WasteStream.recycling, _recyclingItems),
    WasteStream.garden: _mk(_green, _greenDark, 'Green bin',
        WasteStream.garden, _gardenItems),
    WasteStream.food: _mk(_grey, _greyDark, 'Grey food caddy',
        WasteStream.food, _foodItems),
  };

  // ── South Derbyshire District Council ────────────────────────────────────
  // COLLISION: brown is BOTH the garden bin and the kerbside food caddy.
  static final _southderbyshire = <WasteStream, BinPresentation>{
    WasteStream.general: _mk(_charcoal, _charcoalDark, 'Black bin',
        WasteStream.general, _generalItems),
    WasteStream.recycling: _mk(_green, _greenDark, 'Green bin',
        WasteStream.recycling, _recyclingItems),
    WasteStream.garden: _mk(_brown, _brownDark, 'Brown garden bin',
        WasteStream.garden, _gardenItems),
    WasteStream.food: _mk(_brown, _brownDark, 'Brown food caddy',
        WasteStream.food, _foodItems),
  };

  // ── North East Derbyshire District Council ───────────────────────────────
  // North/South calendars.
  static final _northeastderbyshire = <WasteStream, BinPresentation>{
    WasteStream.general: _mk(_charcoal, _charcoalDark, 'Black bin',
        WasteStream.general, _generalItems),
    WasteStream.recycling: _mk(_burgundy, _burgundyDark, 'Burgundy bin',
        WasteStream.recycling, _recyclingItems),
    WasteStream.garden: _mk(_green, _greenDark, 'Green bin',
        WasteStream.garden, _gardenItems),
    WasteStream.food: _mk(_brown, _brownDark, 'Brown food caddy',
        WasteStream.food, _foodItems),
  };

  static final Map<String, Map<WasteStream, BinPresentation>> _schemes = {
    'derby': _derby,
    'erewash': _erewash,
    'ambervalley': _ambervalley,
    'highpeak': _highpeak,
    'derbyshiredales': _derbyshiredales,
    'bolsover': _bolsover,
    'chesterfield': _chesterfield,
    'southderbyshire': _southderbyshire,
    'northeastderbyshire': _northeastderbyshire,
  };
}
