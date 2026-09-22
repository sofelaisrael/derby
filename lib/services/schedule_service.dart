import 'council_api.dart';
import 'schedule_cache.dart';
import '../models/bin_schedule.dart';

/// Orchestrates fetching collection schedules with caching.
class ScheduleService {
  final CouncilApi _api;
  final ScheduleCache _cache;

  ScheduleService({CouncilApi? api, ScheduleCache? cache})
      : _api = api ?? CouncilApi(),
        _cache = cache ?? ScheduleCache();

  /// Get schedule — tries cache first, falls back to API.
  Future<CollectionSchedule> getSchedule({
    required String uprn,
    required String council,
    String? postcode,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = await _cache.loadSchedule(uprn);
      if (cached != null) return cached;
    }

    final schedule = await _api.fetchSchedule(uprn: uprn, council: council, postcode: postcode);
    await _cache.saveSchedule(schedule);
    return schedule;
  }

  /// Get addresses for a postcode.
  Future<List<Map<String, String>>> lookupAddresses(String postcode) async {
    return _api.lookupAddresses(postcode);
  }

  /// Force refresh a schedule.
  Future<CollectionSchedule> refreshSchedule({
    required String uprn,
    required String council,
    String? postcode,
  }) {
    return getSchedule(uprn: uprn, council: council, postcode: postcode, forceRefresh: true);
  }

  /// Report a missed collection.
  Future<bool> reportMissed({
    required String uprn,
    required String council,
    required String wasteType,
    required String reason,
  }) {
    return _api.reportMissed(
      uprn: uprn,
      council: council,
      wasteType: wasteType,
      reason: reason,
    );
  }

  /// Clear all cached data.
  Future<void> clearCache() => _cache.clearCache();
}
