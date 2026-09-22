import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:derby_bins/models/bin_schedule.dart';
import 'package:derby_bins/services/bin_scheme.dart';

void main() {
  group('CouncilScheme.resolve', () {
    test('Derby general is Black bin with slate colour', () {
      final p = CouncilScheme.resolve('derby', WasteStream.general);
      expect(p.label, 'Black bin');
      expect(p.colorLight, 0xFF64748B);
      expect(p.colorDark, 0xFF94A3B8);
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
      expect(p.colorLight, 0xFF64748B);
      expect(p.bodyColor, const Color(0xFF64748B));
      expect(p.lidColor, const Color(0xFF64748B));
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

    test('icon and badgeIcon match per stream', () {
      expect(
          CouncilScheme.resolve('derby', WasteStream.general).icon,
          CouncilScheme.resolve('derby', WasteStream.general).badgeIcon);
      expect(CouncilScheme.resolve('derby', WasteStream.general).icon,
          isA<IconData>());
    });
  });
}