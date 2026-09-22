import 'dart:convert';

import 'package:derby_bins/models/bin_schedule.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReminderStore {
  static const _keyEnabled = 'remindersEnabled';

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEnabled) ?? false;
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, value);
  }

  // â”€â”€ Cached area data (for background-fetch) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  static const _keyArea = 'cachedArea';
  static const _keyCouncilSlug = 'cachedCouncilSlug';

  static Future<void> cacheArea(AreaSchedule area) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyArea, jsonEncode(area.toJson()));
  }

  static Future<AreaSchedule?> getCachedArea() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyArea);
    if (raw == null) return null;
    try {
      return AreaSchedule.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> cacheCouncilSlug(String slug) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCouncilSlug, slug);
  }

  static Future<String?> getCachedCouncilSlug() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCouncilSlug);
  }

  // â”€â”€ Delivered notification IDs (for dedup across restarts) â”€â”€â”€

  static const _keyDelivered = 'deliveredNotificationIds';

  static Future<Set<int>> getDeliveredIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keyDelivered);
    if (raw == null) return {};
    return raw.map(int.parse).toSet();
  }

  static Future<void> setDeliveredIds(Set<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyDelivered,
      ids.map((id) => id.toString()).toList(),
    );
  }

  // â”€â”€ Slot scheme version (for notification id migration) â”€â”€â”€â”€â”€â”€â”€

  static const _keySlotScheme = 'slotSchemeVersion';

  static Future<int> getSlotSchemeVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keySlotScheme) ?? 0;
  }

  static Future<void> setSlotSchemeVersion(int version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySlotScheme, version);
  }

  // â”€â”€ Exact-alarm explainer dismissed (don't nag) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static const _keyExactPromptDismissed = 'exactPromptDismissed';

  static Future<bool> exactAlarmPromptDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyExactPromptDismissed) ?? false;
  }

  static Future<void> setExactAlarmPromptDismissed(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyExactPromptDismissed, value);
  }
}
