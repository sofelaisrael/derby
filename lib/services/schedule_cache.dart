import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bin_schedule.dart';

/// Caches the last-resolved schedule locally so the app works offline.
class ScheduleCache {
  static const _keyPrefix = 'cached_schedule_';

  /// Bump when the cached schedule schema changes so stale payloads are
  /// discarded and re-fetched. v2: schedules serialise a `stream` key
  /// (WasteStream) instead of the old `binType` enum.
  static const int _schemaVersion = 2;

  /// Save a resolved schedule for a UPRN.
  static Future<void> save({
    required String uprn,
    required String postcode,
    required String councilSlug,
    required String councilName,
    required AreaSchedule area,
    required bool isLive,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'schemaVersion': _schemaVersion,
      'postcode': postcode,
      'councilSlug': councilSlug,
      'councilName': councilName,
      'isLive': isLive,
      'area': _encodeArea(area),
      'cachedAt': DateTime.now().toIso8601String(),
    };
    await prefs.setString('$_keyPrefix$uprn', jsonEncode(data));
  }

  /// Load a cached schedule. Returns null if not cached, stale (>7 days old),
  /// or stored under an incompatible schema version.
  static Future<CachedSchedule?> load(String uprn) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_keyPrefix$uprn');
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['schemaVersion'] != _schemaVersion) return null;
      final cachedAt = DateTime.parse(data['cachedAt'] as String);
      if (DateTime.now().difference(cachedAt).inDays > 7) return null;
      return CachedSchedule(
        postcode: data['postcode'] as String,
        councilSlug: data['councilSlug'] as String,
        councilName: data['councilName'] as String,
        isLive: data['isLive'] as bool,
        area: _decodeArea(data['area'] as Map<String, dynamic>),
      );
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _encodeArea(AreaSchedule area) {
    return {
      'postcode': area.postcode,
      'areaName': area.areaName,
      'council': area.council,
      'schedules': area.schedules.map((s) => {
        'stream': s.stream.name,
        'dayOfWeek': s.dayOfWeek,
        'frequency': s.frequency.index,
        'anchorDate': s.anchorDate.toIso8601String(),
      }).toList(),
    };
  }

  static AreaSchedule _decodeArea(Map<String, dynamic> data) {
    final schedules = <BinSchedule>[];
    for (final s in (data['schedules'] as List)) {
      final map = s as Map<String, dynamic>;
      // Skip a malformed schedule rather than nulling the whole area.
      try {
        final stream =
            WasteStream.values.byName(map['stream'] as String);
        schedules.add(BinSchedule(
          stream: stream,
          dayOfWeek: map['dayOfWeek'] as int,
          frequency: Frequency.values[map['frequency'] as int],
          anchorDate: DateTime.parse(map['anchorDate'] as String),
        ));
      } catch (_) {
        // drop malformed schedule
      }
    }
    return AreaSchedule(
      postcode: data['postcode'] as String,
      areaName: data['areaName'] as String,
      council: data['council'] as String,
      schedules: schedules,
    );
  }
}

class CachedSchedule {
  final String postcode;
  final String councilSlug;
  final String councilName;
  final bool isLive;
  final AreaSchedule area;

  const CachedSchedule({
    required this.postcode,
    required this.councilSlug,
    required this.councilName,
    required this.isLive,
    required this.area,
  });
}
