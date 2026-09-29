import 'package:flutter_test/flutter_test.dart';
import 'package:derby_bins/models/bin_schedule.dart';
import 'package:derby_bins/services/bin_scheme.dart';
import 'package:derby_bins/services/schedule_service.dart';

void main() {
  test('normalizePostcode strips spaces and uppercases', () {
    expect(normalizePostcode('m1 4ga'), 'M14GA');
    expect(formatPostcode('M14GA'), 'M1 4GA');
  });

  test('invalid postcode throws ScheduleError', () {
    expect(
      () => resolvePostcode('NOT A POSTCODE'),
      throwsA(isA<ScheduleError>()),
    );
  });

  test('resolvePostcode never throws for a valid Derby postcode',
      () async {
    // DE1 1AA resolves straight to a ready schedule when the live service is
    // reachable, or degrades gracefully otherwise. We only assert it returns
    // a valid ResolveResult and never throws.
    final result = await resolvePostcode('DE1 1AA');
    expect(result, isA<ResolveResult>());
    expect(result.postcode, 'DE1 1AA');
  });

  test('getUpcomingDates projects weekly dates on the right weekday', () {
    final green = BinSchedule(
      stream: WasteStream.general,
      dayOfWeek: 1,
      frequency: Frequency.weekly,
      anchorDate: DateTime(2025, 7, 14),
    );
    final dates = getUpcomingDates(green, 3);
    expect(dates.length, 3);
    for (final d in dates) {
      expect(d.weekday, 1);
    }
    expect(dates[1].difference(dates[0]).inDays, 7);
  });

  test('getUpcomingDates skips off-weeks for fortnightly', () {
    final brown = BinSchedule(
      stream: WasteStream.garden,
      dayOfWeek: 1,
      frequency: Frequency.fortnightly,
      anchorDate: DateTime(2025, 7, 14),
    );
    final dates = getUpcomingDates(brown, 2);
    expect(dates.length, 2);
    expect(dates[1].difference(dates[0]).inDays, 14);
  });

  test('multi-bin days group collections on the same date', () {
    // Green (weekly Mon) + brown (fortnightly Mon) share Mondays.
    final area = AreaSchedule(
      postcode: 'TEST',
      areaName: 'Test',
      council: 'Test',
      schedules: [
        BinSchedule(
          stream: WasteStream.general,
          dayOfWeek: 1,
          frequency: Frequency.weekly,
          anchorDate: DateTime(2025, 7, 14),
        ),
        BinSchedule(
          stream: WasteStream.garden,
          dayOfWeek: 1,
          frequency: Frequency.fortnightly,
          anchorDate: DateTime(2025, 7, 14),
        ),
      ],
    );
    final days = getNextCollectionDays(area, 4, DateTime(2025, 8, 1));
    final multi = days.where((d) => d.collections.length > 1).toList();
    expect(multi.isNotEmpty, isTrue);
    for (final d in multi) {
      expect(d.collections.map((c) => c.stream), contains(WasteStream.general));
    }
  });

  test(
    'getUpcomingDates falls back to the anchor weekday when dayOfWeek is 0',
    () {
      final mismatched = BinSchedule(
        stream: WasteStream.general,
        dayOfWeek: 0,
        frequency: Frequency.weekly,
        anchorDate: DateTime(2025, 7, 14),
      );
      final dates = getUpcomingDates(mismatched, 3, DateTime(2025, 8, 1));
      expect(dates.length, 3);
      for (final d in dates) {
        expect(d.weekday, DateTime.monday);
      }
    },
  );

  test(
      'getUpcomingDates falls back to the anchor weekday when dayOfWeek '
      'disagrees with the anchor date', () {
    final mismatched = BinSchedule(
      stream: WasteStream.recycling,
      dayOfWeek: DateTime.wednesday,
      frequency: Frequency.weekly,
      anchorDate: DateTime(2025, 7, 14),
    );
    final dates = getUpcomingDates(mismatched, 2, DateTime(2025, 8, 1));
    expect(dates.length, 2);
    expect(dates.every((d) => d.weekday == DateTime.monday), isTrue);
  });

  test(
    'getNextCollectionDays returns days for a stream with a bad weekday',
    () {
      final area = AreaSchedule(
        postcode: 'TEST',
        areaName: 'Test',
        council: 'Test',
        schedules: [
          BinSchedule(
            stream: WasteStream.general,
            dayOfWeek: 9,
            frequency: Frequency.weekly,
            anchorDate: DateTime(2025, 7, 14),
          ),
        ],
      );
      final days = getNextCollectionDays(area, 4, DateTime(2025, 8, 1));
      expect(days.length, 4);
      expect(
        days.every((d) => d.collections.single.stream == WasteStream.general),
        isTrue,
      );
    },
  );

  test('effectiveWeekday keeps a valid, anchor-consistent dayOfWeek', () {
    final consistent = BinSchedule(
      stream: WasteStream.general,
      dayOfWeek: DateTime.monday,
      frequency: Frequency.weekly,
      anchorDate: DateTime(2025, 7, 14),
    );
    expect(effectiveWeekday(consistent), DateTime.monday);

    final garden = BinSchedule(
      stream: WasteStream.garden,
      dayOfWeek: DateTime.sunday,
      frequency: Frequency.fortnightly,
      anchorDate: DateTime(2025, 7, 20),
    );
    expect(effectiveWeekday(garden), DateTime.sunday);
  });

  test('effectiveWeekday replaces a bad dayOfWeek with the anchor weekday', () {
    final outOfRange = BinSchedule(
      stream: WasteStream.general,
      dayOfWeek: 0,
      frequency: Frequency.weekly,
      anchorDate: DateTime(2025, 7, 14),
    );
    expect(effectiveWeekday(outOfRange), DateTime.monday);

    final mismatched = BinSchedule(
      stream: WasteStream.general,
      dayOfWeek: DateTime.friday,
      frequency: Frequency.weekly,
      anchorDate: DateTime(2025, 7, 16),
    );
    expect(effectiveWeekday(mismatched), DateTime.wednesday);
  });

  test('Derby food stream maps to Food caddy label and colour', () {
    final p = CouncilScheme.resolve('derby', WasteStream.food);
    expect(p.label, 'Food caddy');
    expect(p.colorLight, 0xFFF59E0B);
    expect(p.colorDark, 0xFFFBBF24);
  });
}
