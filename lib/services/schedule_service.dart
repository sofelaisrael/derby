import 'package:derby_bins/models/bin_schedule.dart';
import 'package:derby_bins/services/council_api.dart';

class ScheduleError implements Exception {
  final String code;
  final String message;
  ScheduleError(this.code, this.message);
  @override
  String toString() => message;
}

const Map<Frequency, int> _frequencyInterval = {
  Frequency.weekly: 7,
  Frequency.fortnightly: 14,
  Frequency.threeWeekly: 21,
  Frequency.fourWeekly: 28,
  Frequency.sixWeekly: 42,
  Frequency.eightWeekly: 56,
  Frequency.twelveWeekly: 84,
};

final RegExp _ukPostcode = RegExp(r'^[A-Z]{1,2}\d[A-Z\d]?\s?\d[A-Z]{2}$');

String normalizePostcode(String postcode) =>
    postcode.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

String formatPostcode(String postcode) {
  final key = normalizePostcode(postcode);
  if (key.length <= 3) return key;
  return '${key.substring(0, key.length - 3)} ${key.substring(key.length - 3)}';
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

int _diffDays(DateTime a, DateTime b) => b.difference(a).inDays;

int _mod(int n, int m) => ((n % m) + m) % m;

bool _isCollectionOnDate(BinSchedule schedule, DateTime date) {
  final d = _dateOnly(date);
  if (d.weekday != schedule.dayOfWeek) return false;
  final interval = _frequencyInterval[schedule.frequency]!;
  return _mod(_diffDays(schedule.anchorDate, d), interval) == 0;
}

List<DateTime> getUpcomingDates(BinSchedule schedule, int count,
    [DateTime? from]) {
  final start = _dateOnly(from ?? DateTime.now());
  final interval = _frequencyInterval[schedule.frequency]!;
  final limit = interval * count * 2 + 40;
  final results = <DateTime>[];
  for (var i = 0; i < limit && results.length < count; i++) {
    final candidate = DateTime(start.year, start.month, start.day + i);
    if (_isCollectionOnDate(schedule, candidate)) results.add(candidate);
  }
  return results;
}

List<CollectionDay> getNextCollectionDays(
    AreaSchedule area, int count, DateTime from) {
  final byDay = <String, CollectionDay>{};
  for (final schedule in area.schedules) {
    for (final date in getUpcomingDates(schedule, count, from)) {
      final key = '${date.year}-${date.month}-${date.day}';
      final existing = byDay[key];
       final collection = BinCollection(
        date: date,
        schedule: schedule,
      );
      if (existing != null) {
        byDay[key] = CollectionDay(
          date: date,
          collections: [...existing.collections, collection],
        );
      } else {
        byDay[key] = CollectionDay(date: date, collections: [collection]);
      }
    }
  }
  final days = byDay.values.toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  return days.take(count).toList();
}

List<BinCollection> getCollectionsOnDate(AreaSchedule area, DateTime date) {
  final d = _dateOnly(date);
  return area.schedules
      .where((s) => _isCollectionOnDate(s, d))
      .map((s) => BinCollection(date: d, schedule: s))
      .toList();
}

String relativeDayLabel(DateTime date, [DateTime? from]) {
  final base = _dateOnly(from ?? DateTime.now());
  final n = _diffDays(base, _dateOnly(date));
  if (n == 0) return 'Today';
  if (n == 1) return 'Tomorrow';
  if (n < 7) return 'In $n days';
  final months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return '${weekdays[date.weekday - 1]} ${date.day} ${months[date.month - 1]}';
}

String fullDateLabel(DateTime date) {
  final months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  const weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];
  return '${weekdays[date.weekday - 1]} ${date.day} ${months[date.month - 1]}';
}

String monthTitle(int year, int month) {
  final months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  return '${months[month - 1]} $year';
}

/* ------------------------------------------------------------------ */
/* Live-aware resolution                                               */
/* ------------------------------------------------------------------ */

sealed class ResolveResult {
  final String postcode;
  final String councilSlug;
  final String councilName;
  ResolveResult(this.postcode, this.councilSlug, this.councilName);
}

class ResolveReady extends ResolveResult {
  final AreaSchedule area;
  final String? councilId;
  final bool liveCouncil;
  ResolveReady(super.postcode, super.councilSlug, super.councilName, this.area, this.councilId, this.liveCouncil);
}

class ResolveCoverage extends ResolveResult {
  ResolveCoverage(super.postcode, super.councilSlug, super.councilName);
}

class ResolveAddresses extends ResolveResult {
  final List<CouncilAddress> addresses;
  ResolveAddresses(super.postcode, super.councilSlug, super.councilName, this.addresses);
}

class ResolveUncovered extends ResolveResult {
  final bool liveChecked;
  ResolveUncovered(super.postcode, super.councilSlug, super.councilName, this.liveChecked);
}

class ResolveNoData extends ResolveResult {
  final String addressLabel;
  ResolveNoData(super.postcode, super.councilSlug, super.councilName, this.addressLabel);
}

final Map<String, ResolveResult> _resolveCache = {};

void clearResolveCache() => _resolveCache.clear();

/// Resolve a postcode via the multi-council backend.
///
/// [councilSlug] and [councilName] identify the council. Defaults to Derby
/// for backward compatibility.
Future<ResolveResult> resolvePostcode(String postcode,
    {bool force = false, String? uprn, String? addressLabel,
     String councilSlug = 'derby', String councilName = 'Derby City Council'}) async {
  final raw = postcode.trim();
  final hasUprn = uprn != null && uprn.isNotEmpty;
  if (!hasUprn && !_ukPostcode.hasMatch(raw.toUpperCase())) {
    throw ScheduleError('INVALID',
        "That doesn't look like a UK postcode. Try something like DE1 1AA.");
  }

  final normalized = normalizePostcode(raw);
  final pretty = formatPostcode(normalized);
  final key = '$normalized@$councilSlug';

  if (uprn != null && uprn.isNotEmpty) {
    final schedules = await CouncilApi().getCollections(councilSlug, uprn, postcode: pretty);
    if (schedules != null && schedules.isNotEmpty) {
      final area = AreaSchedule(
        postcode: pretty,
        areaName: pretty,
        council: councilName,
        schedules: schedules,
      );
      final result = ResolveReady(pretty, councilSlug, councilName, area, null, true);
      _resolveCache[key] = result;
      return result;
    }
    return ResolveNoData(pretty, councilSlug, councilName, addressLabel ?? pretty);
  }

  if (!force) {
    final cached = _resolveCache[key];
    if (cached != null) return cached;
  }

  final api = CouncilApi();
  try {
    final addresses = await api.lookupAddresses(councilSlug, pretty);
    if (addresses.isEmpty) {
      return ResolveUncovered(pretty, councilSlug, councilName, true);
    }
    final result = ResolveAddresses(pretty, councilSlug, councilName, addresses);
    _resolveCache[key] = result;
    return result;
  } on Exception {
    throw ScheduleError('NETWORK',
        'Couldn\u2019t reach the server. Check your internet connection and try again.');
  }
}

/// Legacy resolver: Derby-only, kept for compatibility with older screens
/// that don't pass council info.
Future<ResolveResult> resolveDerbyPostcode(String postcode,
    {bool force = false, String? uprn, String? addressLabel}) {
  return resolvePostcode(postcode,
      force: force, uprn: uprn, addressLabel: addressLabel,
      councilSlug: 'derby', councilName: 'Derby City Council');
}
