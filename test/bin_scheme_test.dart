import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:derby_bins/models/bin_schedule.dart';
import 'package:derby_bins/services/bin_scheme.dart';
import 'package:derby_bins/theme/app_colors.dart';

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
  test('all Derby bin colours use a WCAG AA black or white foreground', () {
    for (final presentation in CouncilScheme.streamsFor('derby')
        .map((stream) => CouncilScheme.resolve('derby', stream))) {
      final themedColours = [
        (name: 'light', colour: Color(presentation.colorLight)),
        (name: 'dark', colour: Color(presentation.colorDark)),
      ];
      for (final themed in themedColours) {
        final blackRatio = _contrastRatio(Colors.black, themed.colour);
        final whiteRatio = _contrastRatio(Colors.white, themed.colour);
        final expected = blackRatio >= whiteRatio ? Colors.black : Colors.white;
        expect(
          binForeground(themed.colour),
          expected,
          reason: '${presentation.label} ${themed.name}',
        );
        expect(
          _contrastRatio(binForeground(themed.colour), themed.colour),
          greaterThanOrEqualTo(4.5),
          reason: '${presentation.label} ${themed.name}',
        );
      }
    }
  });

  group('CouncilScheme.resolve', () {
    test('Derby general is Black bin with charcoal colour', () {
      final p = CouncilScheme.resolve('derby', WasteStream.general);
      expect(p.label, 'Black bin');
      expect(p.colorLight, 0xFF343A40);
      expect(p.colorDark, 0xFF4B5563);
      expect(Color(p.colorLight), AppColors.glassBin);
      expect(Color(p.colorDark), AppColorsDark.glassBin);
    });

    test('Derby recycling is Blue bin with blue colour', () {
      final p = CouncilScheme.resolve('derby', WasteStream.recycling);
      expect(p.label, 'Blue bin');
      expect(p.colorLight, 0xFF3B82F6);
      expect(p.colorDark, 0xFF60A5FA);
    });

    test('Derby garden is Green bin with green colour', () {
      final p = CouncilScheme.resolve('derby', WasteStream.garden);
      expect(p.label, 'Green bin');
      expect(p.colorLight, 0xFF10B981);
      expect(p.colorDark, 0xFF34D399);
    });

    test('Derby food is Food caddy with amber colour', () {
      final p = CouncilScheme.resolve('derby', WasteStream.food);
      expect(p.label, 'Food caddy');
      expect(p.colorLight, 0xFFF59E0B);
      expect(p.colorDark, 0xFFFBBF24);
    });

    test('Single-colour bins keep a uniform body/lid', () {
      final p = CouncilScheme.resolve('derby', WasteStream.general);
      expect(p.colorLight, 0xFF343A40);
      expect(p.bodyColor, const Color(0xFF343A40));
      expect(p.lidColor, const Color(0xFF343A40));
    });

    test('All nine councils share the same four-stream scheme', () {
      const slugs = [
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
      for (final slug in slugs) {
        final streams = CouncilScheme.streamsFor(slug);
        expect(streams.contains(WasteStream.general), isTrue,
            reason: '$slug missing general');
        expect(streams.contains(WasteStream.recycling), isTrue,
            reason: '$slug missing recycling');
        expect(streams.contains(WasteStream.garden), isTrue,
            reason: '$slug missing garden');
        expect(streams.contains(WasteStream.food), isTrue,
            reason: '$slug missing food');
      }
    });

    test('Unknown council falls back to Derby', () {
      final p = CouncilScheme.resolve('does-not-exist', WasteStream.general);
      expect(p.label, 'Black bin');
    });

    test('icons and assets are configured per stream', () {
      final general = CouncilScheme.resolve('derby', WasteStream.general);
      expect(general.icon, isNull);
      expect(general.assetPath, 'assets/icons/bin.svg');

      for (final stream in [
        WasteStream.recycling,
        WasteStream.garden,
        WasteStream.food,
      ]) {
        final presentation = CouncilScheme.resolve('derby', stream);
        expect(presentation.icon, isA<IconData>());
        expect(presentation.assetPath, isNull);
      }
    });
  });
}
