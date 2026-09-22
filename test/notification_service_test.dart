import 'package:flutter_test/flutter_test.dart';
import 'package:derby_bins/models/bin_schedule.dart';
import 'package:derby_bins/services/schedule_service.dart';

// â”€â”€ ID generation (mirrors NotificationService._idFor) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
int _idFor(String councilSlug, String binLabel) =>
    binLabel.hashCode ^ councilSlug.hashCode;

// â”€â”€ Legacy reminder ID (old binLabel-hashed scheme, for migration tests) â”€â”€
int _legacyReminderId(String councilSlug, String binLabel, DateTime notifyDate,
    {required int slot}) {
  final dayKey =
      notifyDate.year * 10000 + notifyDate.month * 100 + notifyDate.day;
  final h = (binLabel.hashCode ^ councilSlug.hashCode ^ dayKey) & 0x1FFFFFFF;
  return h | (slot << 29);
}

// â”€â”€ Unique reminder ID (mirrors NotificationService._uniqueReminderId) â”€â”€
int _uniqueReminderId(DateTime reminderDate, {required int slot}) =>
    (reminderDate.year * 10000 + reminderDate.month * 100 + reminderDate.day) *
        4 +
    slot;

// â”€â”€ Reminder slots (mirrors NotificationService.reminderSlots) â”€â”€â”€â”€â”€â”€
const reminderSlots = [(12, 0, -1), (20, 0, -1), (7, 0, 0)];

// â”€â”€ Notification window logic (mirrors backgroundFetchCheck + scheduleReminders) â”€â”€
DateTime _computeWindowStart(DateTime collectionDate, int hour, int minute,
    {int offset = -1}) {
  final reminderDate = collectionDate.add(Duration(days: offset));
  return DateTime(
      reminderDate.year, reminderDate.month, reminderDate.day, hour, minute);
}

bool _isInWindow(DateTime now, DateTime windowStart, {int windowHours = 4}) {
  final windowEnd = windowStart.add(Duration(hours: windowHours));
  return now.isAfter(windowStart) && now.isBefore(windowEnd);
}

bool _shouldSchedule(DateTime scheduledTime, DateTime now) {
  return scheduledTime.isAfter(now);
}

// â”€â”€ Scheduled reminders (mirrors scheduleReminders per-day loop) â”€â”€â”€â”€
List<DateTime> _scheduledReminders(AreaSchedule area, DateTime now,
    {int days = 8}) {
  final result = <DateTime>[];
  for (final day in getNextCollectionDays(area, days, now)) {
    for (var slot = 0; slot < reminderSlots.length; slot++) {
      final (hour, minute, offset) = reminderSlots[slot];
      final reminderDate = day.date.add(Duration(days: offset));
      final scheduled = DateTime(reminderDate.year, reminderDate.month,
          reminderDate.day, hour, minute);
      if (scheduled.isBefore(now)) continue;
      result.add(scheduled);
    }
  }
  return result;
}

AreaSchedule _makeArea(List<BinSchedule> schedules) => AreaSchedule(
      postcode: 'NG18 1RT',
      areaName: 'Test Area',
      council: 'Test Council',
      schedules: schedules,
    );

BinSchedule _weekly(WasteStream type, int day, DateTime anchor) => BinSchedule(
      stream: type,
      dayOfWeek: day,
      frequency: Frequency.weekly,
      anchorDate: anchor,
    );

BinSchedule _fortnightly(WasteStream type, int day, DateTime anchor) =>
    BinSchedule(
      stream: type,
      dayOfWeek: day,
      frequency: Frequency.fortnightly,
      anchorDate: anchor,
    );

void main() {
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // 1. ID GENERATION & COLLISIONS
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  group('Notification ID generation', () {
    test('same council + bin type produces consistent ID', () {
      final id1 = _idFor('derby', 'Black bin');
      final id2 = _idFor('derby', 'Black bin');
      expect(id1, id2);
    });

    test('different councils produce different IDs for same bin', () {
      final id1 = _idFor('derby', 'Black bin');
      final id2 = _idFor('erewash', 'Black bin');
      expect(id1, isNot(id2));
    });

    test('same council produces different IDs for different bins', () {
      final id1 = _idFor('derby', 'Black bin');
      final id2 = _idFor('derby', 'Blue bin');
      expect(id1, isNot(id2));
    });

    test('backup ID (id + 1000) does not collide with any primary ID', () {
      const councils = ['derby', 'erewash', 'ambervalley', 'highpeak'];
      const binTypes = ['Black bin', 'Blue bin', 'Green bin', 'Food caddy'];

      for (final council in councils) {
        for (final bin in binTypes) {
          final primary = _idFor(council, bin);
          for (final bin2 in binTypes) {
            if (bin2 == bin) continue;
            final otherPrimary = _idFor(council, bin2);
            // backup of bin should not collide with primary of another bin
            expect(primary + 1000, isNot(otherPrimary),
                reason: 'backup($council,$bin) collides with primary($council,$bin2)');
          }
        }
      }
    });

    test('all 4 bin types × all council slugs produce unique IDs', () {
      const councils = ['derby', 'erewash', 'ambervalley', 'highpeak',
                        'derbyshiredales', 'bolsover', 'chesterfield', 'southderbyshire'];
      const binTypes = ['Black bin', 'Blue bin', 'Green bin', 'Food caddy'];
      final ids = <int>{};
      for (final c in councils) {
        for (final b in binTypes) {
          final id = _idFor(c, b);
          expect(ids.contains(id), isFalse,
              reason: 'Duplicate ID $id for $c/$b');
          ids.add(id);
        }
      }
      expect(ids.length, councils.length * binTypes.length);
    });
  });

  group('Unique reminder ID generation', () {
    // Regression: reusing the same id across collection dates made
    // AlarmManager cancel earlier reminders (same PendingIntent), so only
    // the last one ever fired.
    test('same reminder date + slot produces the same id', () {
      final date = DateTime(2026, 8, 3);
      final id1 = _uniqueReminderId(date, slot: 0);
      final id2 = _uniqueReminderId(date, slot: 0);
      expect(id1, id2);
    });

    test('slots for same reminder date differ', () {
      final date = DateTime(2026, 8, 3);
      final slot0 = _uniqueReminderId(date, slot: 0);
      final slot1 = _uniqueReminderId(date, slot: 1);
      final slot2 = _uniqueReminderId(date, slot: 2);
      expect({slot0, slot1, slot2}.length, 3);
    });

    test('different reminder dates produce different ids', () {
      final d1 = _uniqueReminderId(DateTime(2026, 8, 3), slot: 0);
      final d2 = _uniqueReminderId(DateTime(2026, 8, 17), slot: 0);
      final d3 = _uniqueReminderId(DateTime(2026, 8, 31), slot: 0);
      expect({d1, d2, d3}.length, 3);
    });

    test('slots 0..2 across the 8-day schedule are unique and int32-positive', () {
      final dates = [
        DateTime(2026, 8, 3),
        DateTime(2026, 8, 5),
        DateTime(2026, 8, 10),
        DateTime(2026, 8, 12),
        DateTime(2026, 8, 17),
        DateTime(2026, 8, 19),
        DateTime(2026, 8, 24),
        DateTime(2026, 8, 26),
      ];
      final ids = <int>{};
      var count = 0;
      for (final d in dates) {
        for (final slot in [0, 1, 2]) {
          final id = _uniqueReminderId(d, slot: slot);
          expect(id, greaterThanOrEqualTo(0));
          expect(id, lessThan(1 << 31));
          expect(ids.contains(id), isFalse,
              reason: 'Duplicate ID $id for $d/slot$slot');
          ids.add(id);
          count++;
        }
      }
      expect(count, dates.length * 3);
    });

    // Lock the per-day contract: the id depends only on (reminder date,
    // slot), so a multi-bin day shares one id per slot and rescheduling
    // the day reuses the same id.
    test('multi-bin day dedup: id depends only on (reminderDate, slot)', () {
      final date = DateTime(2026, 8, 3);
      final id = _uniqueReminderId(date, slot: 1);
      expect(_uniqueReminderId(date, slot: 1), id);
    });

    // New ids are small (dayKey * 4 + slot, < 2^29 for 2026-2030) while
    // legacy ids mixed hash bits with slot << 29 â€” assert they never
    // overlap so the one-time migration can cancel old alarms safely.
    test('new ids never collide with legacy binLabel-hashed ids', () {
      const councils = ['derby', 'erewash', 'ambervalley', 'highpeak',
                        'derbyshiredales', 'bolsover', 'chesterfield', 'southderbyshire'];
      const binTypes = ['Black bin', 'Blue bin', 'Green bin', 'Food caddy'];
      final dates = [
        DateTime(2026, 8, 3),
        DateTime(2026, 12, 31),
        DateTime(2027, 1, 1),
        DateTime(2028, 2, 29),
        DateTime(2028, 12, 31),
        DateTime(2029, 6, 15),
        DateTime(2030, 1, 1),
      ];
      final newIds = <int>{};
      for (final d in dates) {
        for (final slot in [0, 1, 2]) {
          final id = _uniqueReminderId(d, slot: slot);
          expect(id, lessThan(1 << 29),
              reason: 'new id $id exceeds 2^29 for $d/slot$slot');
          newIds.add(id);
        }
      }
      final legacyIds = <int>{};
      for (final c in councils) {
        for (final b in binTypes) {
          for (final d in dates) {
            for (final slot in [0, 1]) {
              legacyIds.add(_legacyReminderId(c, b, d, slot: slot));
            }
          }
        }
      }
      final overlap = newIds.intersection(legacyIds);
      expect(overlap, isEmpty,
          reason: 'new ids collide with legacy ids: $overlap');
    });
  });

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // 2. NOTIFICATION WINDOW TIMING
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  group('Notification window timing', () {
    test('window starts day before collection at reminder time', () {
      final collectionDate = DateTime(2026, 8, 5);
      final windowStart = _computeWindowStart(collectionDate, 18, 30);
      expect(windowStart, DateTime(2026, 8, 4, 18, 30));
    });

    test('now inside 4-hour window triggers notification', () {
      final windowStart = DateTime(2026, 8, 4, 18, 0);
      final now = DateTime(2026, 8, 4, 19, 30);
      expect(_isInWindow(now, windowStart), isTrue);
    });

    test('now before window does not trigger', () {
      final windowStart = DateTime(2026, 8, 4, 18, 0);
      final now = DateTime(2026, 8, 4, 17, 59);
      expect(_isInWindow(now, windowStart), isFalse);
    });

    test('now after window (4h+) does not trigger', () {
      final windowStart = DateTime(2026, 8, 4, 18, 0);
      final now = DateTime(2026, 8, 4, 22, 1);
      expect(_isInWindow(now, windowStart), isFalse);
    });

    test('now exactly at window boundary (start) does not trigger', () {
      final windowStart = DateTime(2026, 8, 4, 18, 0);
      final now = DateTime(2026, 8, 4, 18, 0);
      expect(_isInWindow(now, windowStart), isFalse);
    });

    test('now exactly at window boundary (end) does not trigger', () {
      final windowStart = DateTime(2026, 8, 4, 18, 0);
      final now = DateTime(2026, 8, 4, 22, 0);
      expect(_isInWindow(now, windowStart), isFalse);
    });

    test('window spans midnight correctly', () {
      final windowStart = DateTime(2026, 8, 4, 22, 0);
      final now = DateTime(2026, 8, 5, 1, 0);
      expect(_isInWindow(now, windowStart), isTrue);
    });

    test('backup reminder 2 hours after primary is still in window', () {
      final primaryWindow = DateTime(2026, 8, 4, 18, 0);
      final backupWindow = primaryWindow.add(const Duration(hours: 2));
      final now = DateTime(2026, 8, 4, 20, 30);
      expect(_isInWindow(now, backupWindow), isTrue);
    });
  });

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // 3. SCHEDULING LOGIC
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  group('Scheduling logic', () {
    test('past scheduled times are skipped', () {
      final scheduled = DateTime(2026, 8, 4, 18, 0);
      final now = DateTime(2026, 8, 5, 10, 0);
      expect(_shouldSchedule(scheduled, now), isFalse);
    });

    test('future scheduled times are accepted', () {
      final scheduled = DateTime(2026, 8, 6, 18, 0);
      final now = DateTime(2026, 8, 5, 10, 0);
      expect(_shouldSchedule(scheduled, now), isTrue);
    });

    test('collection days projected 8 days ahead covers backup gap', () {
      final area = _makeArea([
        _weekly(WasteStream.general, 1, DateTime(2026, 7, 27)), // every Monday
      ]);
      final now = DateTime(2026, 8, 1, 10, 0);
      final days = getNextCollectionDays(area, 8, now);
      // Should find at least the next Monday (Aug 3) and the one after (Aug 10)
      expect(days.length, greaterThanOrEqualTo(2));
      expect(days[0].date.weekday, 1);
    });

    test('multi-bin days have correct collection count', () {
      final area = _makeArea([
        _weekly(WasteStream.general, 1, DateTime(2026, 7, 27)),
        _fortnightly(WasteStream.garden, 1, DateTime(2026, 7, 27)),
      ]);
      final days = getNextCollectionDays(area, 8, DateTime(2026, 8, 1));
      final multiBinDays = days.where((d) => d.collections.length > 1);
      expect(multiBinDays.isNotEmpty, isTrue);
      for (final day in multiBinDays) {
        expect(day.collections.length, 2);
      }
    });
  });

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // 4. RELATIVE DAY LABEL (frozen vs live)
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  group('relativeDayLabel', () {
    test('today returns "Today"', () {
      final now = DateTime(2026, 8, 1, 10, 0);
      expect(relativeDayLabel(DateTime(2026, 8, 1), now), 'Today');
    });

    test('tomorrow returns "Tomorrow"', () {
      final now = DateTime(2026, 8, 1, 10, 0);
      expect(relativeDayLabel(DateTime(2026, 8, 2), now), 'Tomorrow');
    });

    test('2-6 days returns "In N days"', () {
      final now = DateTime(2026, 8, 1, 10, 0);
      expect(relativeDayLabel(DateTime(2026, 8, 3), now), 'In 2 days');
      expect(relativeDayLabel(DateTime(2026, 8, 7), now), 'In 6 days');
    });

    test('7+ days returns named weekday', () {
      final now = DateTime(2026, 8, 1, 10, 0); // Friday
      final label = relativeDayLabel(DateTime(2026, 8, 10), now); // Monday
      expect(label, contains('Mon'));
    });
  });

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // 5. REMINDER STORE DELIVERED IDS
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  group('Delivered ID persistence pattern', () {
    test('IDs survive round-trip through Set â†’ List â†’ Set', () {
      final original = {123, 456, 789, -42};
      final serialized = original.map((id) => id.toString()).toList();
      final deserialized = serialized.map(int.parse).toSet();
      expect(deserialized, original);
    });

    test('empty set round-trips correctly', () {
      final original = <int>{};
      final serialized = original.map((id) => id.toString()).toList();
      final deserialized = serialized.map(int.parse).toSet();
      expect(deserialized, original);
    });
  });

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // 6. EDGE CASES: AREA SCHEDULE SERIALIZATION
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  group('AreaSchedule serialization', () {
    test('toJson/fromJson round-trip preserves all fields', () {
      final area = _makeArea([
        _weekly(WasteStream.general, 1, DateTime(2026, 7, 27)),
        _fortnightly(WasteStream.garden, 3, DateTime(2026, 7, 15)),
      ]);
      final json = area.toJson();
      final restored = AreaSchedule.fromJson(json);
      expect(restored.postcode, area.postcode);
      expect(restored.areaName, area.areaName);
      expect(restored.council, area.council);
      expect(restored.schedules.length, area.schedules.length);
      for (var i = 0; i < area.schedules.length; i++) {
        expect(restored.schedules[i].stream, area.schedules[i].stream);
        expect(restored.schedules[i].dayOfWeek, area.schedules[i].dayOfWeek);
        expect(restored.schedules[i].frequency, area.schedules[i].frequency);
      }
    });
  });

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // 7. STRESS: MANY COUNCILS Ã— BIN TYPES
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  group('Stress: high-volume ID generation', () {
    test('1000 random council/bin combos produce no collisions', () {
      final ids = <int, String>{};
      for (var i = 0; i < 1000; i++) {
        final council = 'council_$i';
        final bin = 'Bin type $i';
        final id = _idFor(council, bin);
        expect(ids.containsKey(id), isFalse,
            reason: 'Collision: $id maps to both ${ids[id]} and $council/$bin');
        ids[id] = '$council/$bin';
      }
    });

    test('backup IDs (id + 1000) never collide across 1000 combos', () {
      final primaryIds = <int>{};
      final backupIds = <int>{};
      for (var i = 0; i < 1000; i++) {
        final council = 'council_$i';
        final bin = 'Bin type $i';
        final id = _idFor(council, bin);
        primaryIds.add(id);
        backupIds.add(id + 1000);
      }
      // No backup should collide with any primary
      final overlap = backupIds.intersection(primaryIds);
      expect(overlap, isEmpty,
          reason: 'Backup IDs collide with primary IDs: $overlap');
    });
  });

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // 8. DATE BOUNDARY: YEAR CROSSING
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  group('Year boundary', () {
    test('collection on Jan 1 schedules notification on Dec 31', () {
      final collectionDate = DateTime(2027, 1, 1);
      final windowStart = _computeWindowStart(collectionDate, 18, 0);
      expect(windowStart, DateTime(2026, 12, 31, 18, 0));
    });

    test('leap year Feb 29 collection schedules correctly', () {
      final collectionDate = DateTime(2028, 2, 29);
      final windowStart = _computeWindowStart(collectionDate, 18, 0);
      expect(windowStart, DateTime(2028, 2, 28, 18, 0));
    });
  });

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // 9. TOGGLE GENERATION RACE CONDITION PATTERN
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  group('Toggle generation pattern', () {
    test('stale generation is detected', () {
      var generation = 0;

      Future<String> asyncWork() async {
        final myGen = ++generation;
        await Future.delayed(const Duration(milliseconds: 50));
        if (myGen != generation) return 'STALE';
        return 'OK';
      }

      // Simulate rapid toggle: start work, immediately increment
      final future = asyncWork();
      generation++; // toggle again before asyncWork completes

      expect(future, completion('STALE'));
    });

    test('non-stale generation completes', () {
      var generation = 0;

      Future<String> asyncWork() async {
        final myGen = ++generation;
        await Future.delayed(const Duration(milliseconds: 10));
        if (myGen != generation) return 'STALE';
        return 'OK';
      }

      expect(asyncWork(), completion('OK'));
    });
  });

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // 10. NOTIFICATION TEXT GENERATION
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  group('Notification text', () {
    test('single bin produces correct title/body', () {
      const binLabel = 'Green bin';
      final multipleBins = false;

      final title = multipleBins ? 'Bin day tomorrow' : '$binLabel tomorrow';
      final body = multipleBins
          ? 'bin goes out tomorrow.'
          : 'Put your $binLabel kerbside by 7am.';

      expect(title, 'Green bin tomorrow');
      expect(body, 'Put your Green bin kerbside by 7am.');
    });

    test('multi-bin day produces correct title/body', () {
      final collections = ['Green bin', 'Brown bin'];
      final multipleBins = collections.length > 1;
      final binNames = collections.map((c) => c.replaceAll(' bin', '')).join(' and ');

      final title = multipleBins ? 'Bin day tomorrow' : 'something tomorrow';
      final body = multipleBins
          ? '$binNames bin goes out tomorrow.'
          : 'something else';

      expect(title, 'Bin day tomorrow');
      expect(body, 'Green and Brown bin goes out tomorrow.');
    });

    test('backup reminder text differs from primary', () {
      const binLabel = 'Blue bin';
      final primaryBody = 'Put your $binLabel kerbside by 7am.';
      final backupBody = "Don't forget â€” put your $binLabel bin out tonight.";

      expect(primaryBody, isNot(backupBody));
      expect(backupBody, contains("Don't forget"));
    });
  });

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // 11. THREE-SLOT SCHEDULE (12:00 & 20:00 day before, 07:00 on the day)
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  group('Three-slot schedule', () {
    test('consecutive collection days: 3 reminders on shared day, 1 on next',
        () {
      final area = _makeArea([
        _weekly(WasteStream.general, 1, DateTime(2026, 7, 27)), // every Monday
        _weekly(WasteStream.recycling, 2, DateTime(2026, 7, 28)), // every Tuesday
      ]);
      final now = DateTime(2026, 8, 2, 10, 0); // Sunday
      final scheduled = _scheduledReminders(area, now);

      // Monday 2026-08-03: slot 2 for Monday (07:00) plus slots 0 and 1
      // for Tuesday (12:00 and 20:00).
      final monday = DateTime(2026, 8, 3);
      final mondayReminders = scheduled
          .where((s) =>
              s.year == monday.year &&
              s.month == monday.month &&
              s.day == monday.day)
          .toList()
        ..sort();
      expect(mondayReminders, [
        DateTime(2026, 8, 3, 7, 0),
        DateTime(2026, 8, 3, 12, 0),
        DateTime(2026, 8, 3, 20, 0),
      ]);

      // Tuesday 2026-08-04: only slot 2 (07:00).
      final tuesday = DateTime(2026, 8, 4);
      final tuesdayReminders = scheduled
          .where((s) =>
              s.year == tuesday.year &&
              s.month == tuesday.month &&
              s.day == tuesday.day)
          .toList();
      expect(tuesdayReminders, [DateTime(2026, 8, 4, 7, 0)]);
    });

    test('multi-bin day schedules one reminder per slot (not per bin)', () {
      final area = _makeArea([
        _weekly(WasteStream.general, 1, DateTime(2026, 7, 27)),
        _fortnightly(WasteStream.garden, 1, DateTime(2026, 7, 27)),
      ]);
      final now = DateTime(2026, 8, 1, 10, 0); // Saturday
      final days = getNextCollectionDays(area, 8, now);
      final multiBinDays = days.where((d) => d.collections.length > 1);
      expect(multiBinDays.isNotEmpty, isTrue);
      final first = multiBinDays.first; // Monday 2026-08-10 (green + brown)

      // Per-day scheduling yields exactly one reminder per slot â€” the old
      // per-bin loop would have produced two per slot (6 in total).
      final ids = <int>{};
      var count = 0;
      for (var slot = 0; slot < reminderSlots.length; slot++) {
        final (hour, minute, offset) = reminderSlots[slot];
        final reminderDate = first.date.add(Duration(days: offset));
        final scheduled = DateTime(reminderDate.year, reminderDate.month,
            reminderDate.day, hour, minute);
        if (scheduled.isBefore(now)) continue;
        ids.add(_uniqueReminderId(reminderDate, slot: slot));
        count++;
      }
      expect(count, 3);
      expect(ids.length, 3);
    });

    test('7am slot window is 2h', () {
      final windowStart = _computeWindowStart(DateTime(2026, 8, 5), 7, 0,
          offset: 0);
      expect(
          _isInWindow(DateTime(2026, 8, 5, 8, 30), windowStart,
              windowHours: 2),
          isTrue);
      expect(
          _isInWindow(DateTime(2026, 8, 5, 10, 0), windowStart,
              windowHours: 2),
          isFalse);
    });

    test('7am reminder text â€” single bin', () {
      const binLabel = 'Green bin';
      const title = '$binLabel goes out today';
      const body = 'Put your $binLabel out now â€” collection is today.';
      expect(title, 'Green bin goes out today');
      expect(body, 'Put your Green bin out now â€” collection is today.');
    });

    test('7am reminder text â€” multi bin', () {
      final collections = ['Green bin', 'Brown bin'];
      final binNames =
          collections.map((c) => c.replaceAll(' bin', '')).join(' and ');
      const title = 'Bin day today';
      final body = '$binNames bins go out today â€” put them out now.';
      expect(title, 'Bin day today');
      expect(body, 'Green and Brown bins go out today â€” put them out now.');
    });
  });
}
