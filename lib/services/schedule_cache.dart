import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bin_schedule.dart';

/// Caches collection schedules for offline use.
class ScheduleCache {
  static const _keyPrefix = 'schedule_';
  static const _cacheDuration = Duration(hours: 12);

  Future<void> saveSchedule(CollectionSchedule schedule) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix${schedule.uprn}';
    final data = {
      'schedule': schedule.toJson(),
      'cachedAt': DateTime.now().toIso8601String(),
    };
    await prefs.setString(key, jsonEncode(data));
  }

  Future<CollectionSchedule?> loadSchedule(String uprn) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix$uprn';
    final raw = prefs.getString(key);
    if (raw == null) return null;

    final data = jsonDecode(raw);
    final cachedAt = DateTime.parse(data['cachedAt']);

    // Return null if cache is too old
    if (DateTime.now().difference(cachedAt) > _cacheDuration) {
      await prefs.remove(key);
      return null;
    }

    return CollectionSchedule.fromJson(data['schedule']);
  }

  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_keyPrefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
