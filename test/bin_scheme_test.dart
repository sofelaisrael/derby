import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:derby_bins/models/bin_schedule.dart';
import 'package:derby_bins/services/bin_scheme.dart';
import 'package:derby_bins/theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Expectation table
//
// Every value below is stated literally rather than derived from the code under
// test, so the table is a complete, self-documenting spec of what each council
// actually serves. A row with no body/lid values means the swatch is solid:
// body == lid == colorLight (colorDark in dark mode).
//
// For two-tone bins the row states all four swatch colours. Note that the
// implementation passes `null` for the lid in every two-tone case, which makes
// the lid fall back to the light/dark base colour -- so `lid` always equals
// `colorLight`/`colorDark` here. That is spelled out per row rather than
// computed, so a future change to the lid cannot quietly pass.
// ─────────────────────────────────────────────────────────────────────────────

class _Row {
  const _Row(
    this.council,
    this.stream,
    this.label,
    this.colorLight,
    this.colorDark, {
    this.bodyLight,
    this.bodyDark,
    this.lidLight,
    this.lidDark,
  });

  final String council;
  final WasteStream stream;
  final String label;
  final int colorLight;
  final int colorDark;
  final int? bodyLight;
  final int? bodyDark;
  final int? lidLight;
  final int? lidDark;

  bool get isTwoTone => bodyLight != null;

  String get key => '$council/${stream.name}';
}

const List<_Row> _table = <_Row>[
  // ── Derby City Council ───────────────────────────────────────────────────
  _Row('derby', WasteStream.general, 'Black bin', 0xFF343A40, 0xFF4B5563),
  _Row('derby', WasteStream.recycling, 'Blue bin', 0xFF3B82F6, 0xFF60A5FA),
  _Row('derby', WasteStream.garden, 'Brown bin', 0xFF7B4B2A, 0xFFA97C52),
  _Row('derby', WasteStream.food, 'Green food caddy', 0xFF10B981, 0xFF34D399),

  // ── Erewash Borough Council ──────────────────────────────────────────────
  _Row('erewash', WasteStream.general, 'Black bin', 0xFF343A40, 0xFF4B5563),
  _Row('erewash', WasteStream.recycling, 'Blue bin', 0xFF3B82F6, 0xFF60A5FA),
  _Row('erewash', WasteStream.garden, 'Brown bin', 0xFF7B4B2A, 0xFFA97C52),
  _Row(
      'erewash', WasteStream.food, 'Green food caddy', 0xFF10B981, 0xFF34D399),

  // ── Amber Valley Borough Council ─────────────────────────────────────────
  // COLLISION (green body): general vs garden.
  _Row('ambervalley', WasteStream.general, 'Green refuse bin', 0xFF10B981,
      0xFF34D399),
  _Row('ambervalley', WasteStream.recycling, 'Grey bin', 0xFF6B7280, 0xFF9CA3AF),
  _Row(
    'ambervalley',
    WasteStream.garden,
    'Green garden bin',
    0xFF7B4B2A,
    0xFFA97C52,
    bodyLight: 0xFF10B981,
    bodyDark: 0xFF34D399,
    lidLight: 0xFF7B4B2A,
    lidDark: 0xFFA97C52,
  ),
  // Colour never published by AVBC -> neutral `unknown` token, NOT their grey.
  _Row('ambervalley', WasteStream.food, 'Food caddy', 0xFF8E8E93, 0xFFB6B6BD),

  // ── High Peak Borough Council ────────────────────────────────────────────
  // COLLISION (green): garden vs food.
  _Row('highpeak', WasteStream.general, 'Black bin', 0xFF343A40, 0xFF4B5563),
  _Row('highpeak', WasteStream.recycling, 'Brown bin', 0xFF7B4B2A, 0xFFA97C52),
  _Row(
    'highpeak',
    WasteStream.garden,
    'Green garden bin',
    0xFF10B981,
    0xFF34D399,
    bodyLight: 0xFF6B7280,
    bodyDark: 0xFF9CA3AF,
    lidLight: 0xFF10B981,
    lidDark: 0xFF34D399,
  ),
  _Row('highpeak', WasteStream.food, 'Green food caddy', 0xFF10B981, 0xFF34D399),

  // ── Derbyshire Dales District Council ────────────────────────────────────
  // COLLISION (green): garden vs food.
  _Row('derbyshiredales', WasteStream.general, 'Grey refuse bin', 0xFF6B7280,
      0xFF9CA3AF),
  _Row(
    'derbyshiredales',
    WasteStream.recycling,
    'Blue-lidded bin',
    0xFF3B82F6,
    0xFF60A5FA,
    bodyLight: 0xFF6B7280,
    bodyDark: 0xFF9CA3AF,
    lidLight: 0xFF3B82F6,
    lidDark: 0xFF60A5FA,
  ),
  _Row(
    'derbyshiredales',
    WasteStream.garden,
    'Green-lidded bin',
    0xFF10B981,
    0xFF34D399,
    bodyLight: 0xFF6B7280,
    bodyDark: 0xFF9CA3AF,
    lidLight: 0xFF10B981,
    lidDark: 0xFF34D399,
  ),
  _Row('derbyshiredales', WasteStream.food, 'Green food caddy', 0xFF10B981,
      0xFF34D399),

  // ── Bolsover District Council ────────────────────────────────────────────
  _Row('bolsover', WasteStream.general, 'Black bin', 0xFF343A40, 0xFF4B5563),
  _Row('bolsover', WasteStream.recycling, 'Burgundy bin', 0xFF8E1F4B, 0xFFBE5C82),
  _Row('bolsover', WasteStream.garden, 'Green bin', 0xFF10B981, 0xFF34D399),
  _Row('bolsover', WasteStream.food, 'Brown food caddy', 0xFF7B4B2A, 0xFFA97C52),

  // ── Chesterfield Borough Council ─────────────────────────────────────────
  _Row('chesterfield', WasteStream.general, 'Black bin', 0xFF343A40, 0xFF4B5563),
  _Row(
      'chesterfield', WasteStream.recycling, 'Blue bin', 0xFF3B82F6, 0xFF60A5FA),
  _Row('chesterfield', WasteStream.garden, 'Green bin', 0xFF10B981, 0xFF34D399),
  _Row(
      'chesterfield', WasteStream.food, 'Grey food caddy', 0xFF6B7280, 0xFF9CA3AF),

  // ── South Derbyshire District Council ────────────────────────────────────
  // COLLISION (brown): garden vs food.
  _Row('southderbyshire', WasteStream.general, 'Black bin', 0xFF343A40, 0xFF4B5563),
  _Row('southderbyshire', WasteStream.recycling, 'Green bin', 0xFF10B981,
      0xFF34D399),
  _Row('southderbyshire', WasteStream.garden, 'Brown garden bin', 0xFF7B4B2A,
      0xFFA97C52),
  _Row('southderbyshire', WasteStream.food, 'Brown food caddy', 0xFF7B4B2A,
      0xFFA97C52),

  // ── North East Derbyshire District Council ───────────────────────────────
  _Row(
      'northeastderbyshire', WasteStream.general, 'Black bin', 0xFF343A40, 0xFF4B5563),
  _Row('northeastderbyshire', WasteStream.recycling, 'Burgundy bin',
      0xFF8E1F4B, 0xFFBE5C82),
  _Row('northeastderbyshire', WasteStream.garden, 'Green bin', 0xFF10B981,
      0xFF34D399),
  _Row('northeastderbyshire', WasteStream.food, 'Brown food caddy', 0xFF7B4B2A,
      0xFFA97C52),
];

const List<String> _councils = <String>[
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

/// The four colour collisions that exist by real-world necessity, each of which
/// is disambiguated by a distinct label and a distinct icon.
///
/// `onField` names the swatch colour the pair actually shares. This matters:
/// computing collisions on `colorLight` alone finds only THREE of the four,
/// because Amber Valley expresses its collision through the two-tone body
/// override rather than the base colour. Amber Valley's refuse bin and its
/// garden bin are both green -- one as a solid green bin, the other as a green
/// bin with a brown lid -- so the shared colour is `bodyColor`. The other three
/// councils collide on `colorLight` (which is also their lid colour, because
/// every two-tone row passes `null` for the lid and falls back to the base
/// colour).
class _Collision {
  const _Collision(this.council, this.streams, this.onField);

  final String council;
  final List<WasteStream> streams;

  /// 'colorLight' or 'bodyColor'.
  final String onField;

  int field(String council, WasteStream stream, String field) {
    final p = CouncilScheme.resolve(council, stream);
    return field == 'bodyColor' ? p.bodyColor.value : p.colorLight;
  }
}

const List<_Collision> _documentedCollisions = <_Collision>[
  // Amber Valley: green is both the refuse bin and the garden bin's body.
  _Collision('ambervalley', <WasteStream>[WasteStream.general, WasteStream.garden],
      'bodyColor'),
  _Collision('highpeak', <WasteStream>[WasteStream.garden, WasteStream.food],
      'colorLight'),
  _Collision(
      'derbyshiredales', <WasteStream>[WasteStream.garden, WasteStream.food],
      'colorLight'),
  _Collision(
      'southderbyshire', <WasteStream>[WasteStream.garden, WasteStream.food],
      'colorLight'),
];

const List<WasteStream> _allStreams = <WasteStream>[
  WasteStream.general,
  WasteStream.recycling,
  WasteStream.garden,
  WasteStream.food,
];

bool isDocumented(String council, WasteStream a, WasteStream b) => _documentedCollisions.any((c) =>
    c.council == council && c.streams.contains(a) && c.streams.contains(b));

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter =
      firstLuminance > secondLuminance ? firstLuminance : secondLuminance;
  final darker =
      firstLuminance > secondLuminance ? secondLuminance : firstLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('CouncilScheme table', () {
    test('the table covers all 36 council x stream entries', () {
      expect(_table.length, _councils.length * _allStreams.length);
      final keys = _table.map((r) => r.key).toList();
      expect(keys.toSet().length, keys.length, reason: 'duplicate table row');
      for (final council in _councils) {
        for (final stream in _allStreams) {
          expect(keys, contains('$council/${stream.name}'),
              reason: 'missing $council / ${stream.name}');
        }
      }
    });

    for (final row in _table) {
      test('${row.key} is ${row.label}', () {
        final p = CouncilScheme.resolve(row.council, row.stream);
        expect(p.label, row.label);
        expect(p.colorLight, row.colorLight);
        expect(p.colorDark, row.colorDark);

        if (row.isTwoTone) {
          expect(p.bodyColor, Color(row.bodyLight!));
          expect(p.lidColor, Color(row.lidLight!));
          expect(p.bodyColorDark, Color(row.bodyDark!));
          expect(p.lidColorDark, Color(row.lidDark!));
        } else {
          // Solid swatch: body and lid both fall back to the bin colour.
          expect(p.bodyColor, Color(row.colorLight));
          expect(p.lidColor, Color(row.colorLight));
          expect(p.bodyColorDark, Color(row.colorDark));
          expect(p.lidColorDark, Color(row.colorDark));
        }
      });
    }
  });

  group('streamsFor', () {
    test('every council offers all four streams in canonical order', () {
      for (final council in _councils) {
        expect(
          CouncilScheme.streamsFor(council),
          _allStreams,
          reason: council,
        );
      }
    });

    test('unknown council falls back to Derby', () {
      expect(
        CouncilScheme.streamsFor('does-not-exist'),
        CouncilScheme.streamsFor('derby'),
      );
      expect(
        CouncilScheme.resolve('does-not-exist', WasteStream.general).label,
        'Black bin',
      );
    });

    test('every council uses a distinct label per stream', () {
      for (final council in _councils) {
        final labels = CouncilScheme.streamsFor(council)
            .map((s) => CouncilScheme.resolve(council, s).label)
            .toList();
        expect(labels.toSet().length, labels.length,
            reason: '$council reuses a label: $labels');
      }
    });
  });

  group('icons and assets', () {
    test('general uses the bin.svg asset and no icon, for every council', () {
      for (final council in _councils) {
        final general = CouncilScheme.resolve(council, WasteStream.general);
        expect(general.icon, isNull, reason: council);
        expect(general.assetPath, 'assets/icons/bin.svg', reason: council);
      }
    });

    test('recycling, garden and food use distinct icons and no asset', () {
      for (final council in _councils) {
        for (final stream in <WasteStream>[
          WasteStream.recycling,
          WasteStream.garden,
          WasteStream.food,
        ]) {
          final p = CouncilScheme.resolve(council, stream);
          expect(p.icon, isA<IconData>(), reason: '$council/${stream.name}');
          expect(p.assetPath, isNull, reason: '$council/${stream.name}');
        }
      }
    });
  });

group('documented colour collisions', () {
    test('exactly four collisions are documented', () {
      expect(_documentedCollisions.length, 4);
      final keys = _documentedCollisions
          .map((c) => '${c.council}/${c.streams.map((s) => s.name).join('+')}/${c.onField}')
          .toList();
      expect(keys.toSet().length, keys.length, reason: 'duplicate entry');
    });

    // Compute collisions from colorLight across every council. Amber Valley is
    // deliberately absent here: its refuse/garden clash is a bodyColor
    // collision, which is why the documented list records the shared field per
    // pair instead of pretending all four clash the same way.
    test('real colorLight collisions are exactly the three documented ones', () {
      final actual = <String, List<String>>{};
      for (final council in _councils) {
        final byColour = <int, List<String>>{};
        for (final stream in CouncilScheme.streamsFor(council)) {
          final colour = CouncilScheme.resolve(council, stream).colorLight;
          byColour.putIfAbsent(colour, () => <String>[]).add(stream.name);
        }
        final collided = byColour.values
            .where((streams) => streams.length > 1)
            .map((streams) => (streams..sort()).join('+'))
            .toList()
          ..sort();
        if (collided.isNotEmpty) actual[council] = collided;
      }

      final expected = <String, List<String>>{};
      for (final c in _documentedCollisions) {
        if (c.onField != 'colorLight') continue;
        expected[c.council] = [(c.streams.map((s) => s.name).toList()..sort()).join('+')];
      }

      expect(actual, expected,
          reason: 'a council gained or lost a same-colorLight stream pair');
    });

    for (final c in _documentedCollisions) {
      final name =
          '${c.council}: ${c.streams.map((s) => s.name).join(' vs ')}';
      test('$name really collides on ${c.onField}', () {
        expect(c.field(c.council, c.streams[0], c.onField),
            c.field(c.council, c.streams[1], c.onField),
            reason: name);
      });

      test('$name is disambiguated by label and icon', () {
        final a = CouncilScheme.resolve(c.council, c.streams[0]);
        final b = CouncilScheme.resolve(c.council, c.streams[1]);
        expect(a.label, isNot(b.label), reason: name);
        expect(a.icon, isNot(b.icon), reason: name);
      });
    }

    test('Amber Valley collides on the body, not on colorLight', () {
      final general = CouncilScheme.resolve('ambervalley', WasteStream.general);
      final garden = CouncilScheme.resolve('ambervalley', WasteStream.garden);
      expect(general.bodyColor, garden.bodyColor);
      expect(general.bodyColor.value, 0xFF10B981);
      expect(garden.lidColor.value, 0xFF7B4B2A);
      // Distinct base colours: the clash is only visible in the rendered swatch.
      expect(general.colorLight, isNot(garden.colorLight));
    });

    test('no other council has an undocumented body-colour clash', () {
      // Derbyshire Dales gives every container a grey body and identifies them by
      // lid, so three containers share a body colour there and that is not a
      // collision: the lid is what the council uses to tell them apart. Every
      // other council must have its body clashes documented.
      for (final council in _councils) {
        if (council == 'derbyshiredales') continue;
        final byColour = <int, List<WasteStream>>{};
        for (final stream in CouncilScheme.streamsFor(council)) {
          final colour = CouncilScheme.resolve(council, stream).bodyColor.value;
          byColour.putIfAbsent(colour, () => <WasteStream>[]).add(stream);
        }
        for (final group in byColour.values.where((g) => g.length > 1)) {
          for (var i = 0; i < group.length; i++) {
            for (var j = i + 1; j < group.length; j++) {
              expect(
                isDocumented(council, group[i], group[j]),
                isTrue,
                reason: '$council: ${group[i].name} and ${group[j].name} '
                    'share body colour '
                    '${CouncilScheme.resolve(council, group[i]).bodyColor.value.toRadixString(16)} '
                    'but no documented collision covers them',
              );
            }
          }
        }
      }
    });

    test('every documented collision is unique and complete', () {
      // Key on the pair in canonical (sorted) order so the same pair listed the
      // other way round is caught as the duplicate it is. Keying on the raw
      // insertion order, and then asserting that adding both orientations
      // succeeded, could never fail: `Set.add` reports whether *that* element
      // was new, and the two orientations are distinct strings by construction.
      final keys = <String, _Collision>{};
      for (final c in _documentedCollisions) {
        expect(c.streams.length, 2,
            reason: '${c.council} must document exactly one colliding pair, '
                'found ${c.streams.map((s) => s.name).join(' vs ')}');
        final names = c.streams.map((s) => s.name).toList()..sort();
        final key = '${c.council}/${names.join('+')}/${c.onField}';
        final clash = keys[key];
        expect(clash, isNull,
            reason: 'duplicate entry: $key is already documented as '
                '${clash?.streams.map((s) => s.name).join(' vs ')} on '
                '${clash?.onField}');
        keys[key] = c;
      }
      expect(keys.length, _documentedCollisions.length,
          reason: 'a collision entry was lost while keying');
    });

    // South Derbyshire really does issue two visually identical brown
    // containers -- a brown garden bin and a brown kerbside caddy -- so the
    // collision cannot be solved with colour. Pin that fact so a future change
    // that "fixes" the colour silently is caught here.
    test('South Derbyshire garden and food are swatch-identical brown', () {
      final garden = CouncilScheme.resolve('southderbyshire', WasteStream.garden);
      final food = CouncilScheme.resolve('southderbyshire', WasteStream.food);
      expect(garden.bodyColor, food.bodyColor);
      expect(garden.lidColor, food.lidColor);
      expect(garden.colorLight, food.colorLight);
      expect(garden.label, isNot(food.label));
      expect(garden.icon, isNot(food.icon));
    });
  });

  group('Amber Valley food disclosure', () {
    test('food uses the neutral unknown token, not their recycling grey', () {
      final food = CouncilScheme.resolve('ambervalley', WasteStream.food);
      final recycling =
          CouncilScheme.resolve('ambervalley', WasteStream.recycling);
      expect(food.colorLight, 0xFF8E8E93);
      expect(food.colorDark, 0xFFB6B6BD);
      expect(food.colorLight, isNot(recycling.colorLight));
      expect(food.colorLight, isNot(0xFF6B7280));

      final otherColours = CouncilScheme.streamsFor('ambervalley')
          .where((s) => s != WasteStream.food)
          .map((s) => CouncilScheme.resolve('ambervalley', s).colorLight)
          .toSet();
      expect(otherColours, isNot(contains(food.colorLight)));
    });

    test('food guide items disclose the un-published colour and roll-out', () {
      final items = CouncilScheme.resolve('ambervalley', WasteStream.food).items;
      expect(items.any((i) => i.contains('has not published the caddy colour')),
          isTrue);
      expect(items.any((i) => i.contains('phases across 2026')), isTrue);
    });

    test('recycling guide items disclose the green-bag exception', () {
      final items =
          CouncilScheme.resolve('ambervalley', WasteStream.recycling).items;
      expect(items.any((i) => i.contains('green reusable bags')), isTrue);
    });
  });

  // Facts that used to live only in code comments, or that would be easy to
  // drop in a refactor. Pinned here so a later edit cannot quietly remove a
  // disclosure or reintroduce internal research state as user-facing copy.
  group('content-gap disclosures', () {
    // FIX D. OLD: the Derbyshire Dales list told the user "Medium confidence:
    // ... not published". Confidence is our internal research state and a user
    // cannot act on it, so it is now a code comment. NEW: only the sizes
    // DDDC actually publishes are shown.
    test('Derbyshire Dales food states its DDDC-sourced caddy sizes', () {
      final items = CouncilScheme
          .resolve('derbyshiredales', WasteStream.food)
          .items;
      expect(
          items.any((i) =>
              i.contains('23 litre') && i.toLowerCase().contains('outdoor')),
          isTrue);
      expect(
          items.any((i) =>
              i.contains('5 litre') && i.toLowerCase().contains('indoor')),
          isTrue);
    });

    // FIX D, guard across every council and stream: internal research state
    // must never reach the guide items. This is the assertion that would have
    // caught the original "Medium confidence: ... not published" line.
    //
    // The ban is deliberately NARROWED to confidence-phrased forms. It used to
    // also ban the bare substring "not published", which was meant to catch
    // that one internal string but in fact contradicted a required disclosure:
    // Amber Valley genuinely has NOT published its caddy colour, and telling
    // the user so is the correct, actionable copy (see the disclosure test
    // above). A blanket ban could never pass alongside that requirement.
    // So: what is banned is confidence framing and research-state vocabulary,
    // not the honest fact that a council has not published something.
    test('no bin item exposes internal confidence language', () {
      const confidencePhrases = [
        'confidence',
        'medium confidence',
        'low confidence',
        'high confidence',
        'unverified',
      ];
      for (final row in _table) {
        final p = CouncilScheme.resolve(row.council, row.stream);
        for (final item in p.items) {
          final lower = item.toLowerCase();
          for (final phrase in confidencePhrases) {
            expect(lower, isNot(contains(phrase)),
                reason: '${row.key}: "${item}"');
          }
        }
      }
    });

    // The narrowed ban must not have quietly reopened the leak it was written
    // for: a council's own unpublished status is user-facing, but OUR research
    // state is not. Pin that the word "confidence" still cannot appear in any
    // form, so the original "Medium confidence:" prefix stays impossible.
    test('no bin item exposes a raw confidence rating', () {
      for (final row in _table) {
        final p = CouncilScheme.resolve(row.council, row.stream);
        for (final item in p.items) {
          expect(item.toLowerCase(), isNot(contains('confidence')),
              reason: '${row.key}: "${item}"');
        }
      }
    });

    // FIX D: DDDC does not publish its food collection pattern and it varies by
    // area, so no cadence is asserted. Pinned so a later "helpful" addition of
    // "emptied weekly" has to be a deliberate, evidenced change.
    test('Derbyshire Dales food asserts no collection cadence', () {
      final items = CouncilScheme
          .resolve('derbyshiredales', WasteStream.food)
          .items;
      for (final item in items) {
        final lower = item.toLowerCase();
        for (final cadence in ['weekly', 'fortnightly', 'monthly']) {
          expect(lower, isNot(contains(cadence)),
              reason: '"$item" asserts an unverified cadence');
        }
      }
    });

    test('High Peak food mentions the silver indoor kitchen caddy', () {
      final items =
          CouncilScheme.resolve('highpeak', WasteStream.food).items;
      expect(
          items.any((i) =>
              i.contains('silver') && i.toLowerCase().contains('indoor')),
          isTrue);
    });

    test('Bolsover garden states the winter suspension', () {
      final items =
          CouncilScheme.resolve('bolsover', WasteStream.garden).items;
      expect(
          items.any((i) =>
              i.toLowerCase().contains('winter') && i.contains('suspends')),
          isTrue);
    });

    // The shared lists must still be present underneath the additions, so a
    // council-specific list cannot quietly replace the common guidance.
    test('council-specific lists extend, not replace, the shared items', () {
      for (final row in _table) {
        final p = CouncilScheme.resolve(row.council, row.stream);
        expect(p.items, isNotEmpty, reason: row.key);
      }
      // Derby/High Peak food and Chesterfield/Bolsover garden share a base
      // list, so the council-specific variant must be strictly longer.
      expect(
          CouncilScheme.resolve('highpeak', WasteStream.food).items.length,
          greaterThan(
              CouncilScheme.resolve('derby', WasteStream.food).items.length));
      expect(
          CouncilScheme.resolve('bolsover', WasteStream.garden).items.length,
          greaterThan(CouncilScheme
              .resolve('chesterfield', WasteStream.garden)
              .items
              .length));
    });
  });

  // SPEC, NOT IMPLEMENTATION. This group builds its subject from `_table`
  // and asserts `_table` against AppColors, so it passes even if
  // bin_scheme.dart is deleted. It pins the documented hex values, nothing
  // more -- the implementation is covered by the "CouncilScheme table"
  // group above, which calls CouncilScheme.resolve for all 36 rows.
  group('palette constants match the documented hex values', () {
    test('charcoal, blue and green still equal AppColors/AppColorsDark', () {
      final derby = <WasteStream, _Row>{
        for (final row in _table.where((r) => r.council == 'derby')) row.stream: row,
      };
      expect(derby[WasteStream.general]!.colorLight, AppColors.glassBin.value);
      expect(derby[WasteStream.general]!.colorDark, AppColorsDark.glassBin.value);
      expect(derby[WasteStream.recycling]!.colorLight, AppColors.blueBin.value);
      expect(
          derby[WasteStream.recycling]!.colorDark, AppColorsDark.blueBin.value);
      expect(derby[WasteStream.food]!.colorLight, AppColors.greenBin.value);
      expect(derby[WasteStream.food]!.colorDark, AppColorsDark.greenBin.value);
    });
  });

  // NOTE: this is a weak invariant, not real coverage. For any sRGB colour the
  // better of black/white always clears 4.5:1, so neither assertion below can
  // fail for a legal hex. It is kept because it documents the intent of
  // binForeground and would catch a genuinely transparent or nonsensical value.
  group('foreground contrast', () {
    test('binForeground picks the better of black/white for every swatch', () {
      for (final row in _table) {
        final p = CouncilScheme.resolve(row.council, row.stream);
        final swatches = <String, Color>{
          'light': Color(p.colorLight),
          'dark': Color(p.colorDark),
          'bodyLight': p.bodyColor,
          'bodyDark': p.bodyColorDark,
          'lidLight': p.lidColor,
          'lidDark': p.lidColorDark,
        };
        swatches.forEach((name, colour) {
          final blackRatio = _contrastRatio(Colors.black, colour);
          final whiteRatio = _contrastRatio(Colors.white, colour);
          expect(
            binForeground(colour),
            blackRatio >= whiteRatio ? Colors.black : Colors.white,
            reason: '${row.key} $name',
          );
          expect(
            _contrastRatio(binForeground(colour), colour),
            greaterThanOrEqualTo(4.5),
            reason: '${row.key} $name',
          );
        });
      }
    });
  });
}