import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:derby_bins/models/bin_schedule.dart';

class CouncilInfo {
  final String id;
  final String name;
  final String slug;
  final bool calendarBased;
  const CouncilInfo({
    required this.id,
    required this.name,
    required this.slug,
    this.calendarBased = false,
  });
}

class CouncilAddress {
  final String uprn;
  final String label;
  const CouncilAddress({required this.uprn, required this.label});
}

/// Generic client for the multi-council backend at [proxyBaseUrl]/bins.
///
/// Every call is defensive: timeouts and 5xx collapse to empty / null so the
/// app degrades gracefully.
class CouncilApi {
  static http.Client client = http.Client();
  static String proxyBaseUrl = 'https://derby-d6e5.onrender.com';
  static const Duration _timeout = Duration(milliseconds: 10000);
  static const Duration _cacheTtl = Duration(hours: 24);
  static const Map<String, String> _headers = {
    'Accept': 'application/json',
    'User-Agent': 'Derby Bins/1.0 (bin-collection-app)',
  };

  static Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  static String _cacheKey(String council, String uprn) =>
      'api_cache_${council}_$uprn';

  static Future<String?> _readCache(String key) async {
    final prefs = await _prefs();
    final json = prefs.getString('${key}_data');
    final ts = prefs.getInt('${key}_ts');
    if (json == null || ts == null) return null;
    final age = DateTime.now().millisecondsSinceEpoch - ts;
    if (age > _cacheTtl.inMilliseconds) return null;
    return json;
  }

  static Future<void> _writeCache(String key, String json) async {
    final prefs = await _prefs();
    await prefs.setString('${key}_data', json);
    await prefs.setInt('${key}_ts', DateTime.now().millisecondsSinceEpoch);
  }

  /// Hardcoded council list as offline fallback.
  static const List<CouncilInfo> _fallbackCouncils = [
    CouncilInfo(id: 'DCC', name: 'Derby City Council', slug: 'derby'),
    CouncilInfo(id: 'EBC', name: 'Erewash Borough Council', slug: 'erewash'),
    CouncilInfo(
        id: 'AVBC', name: 'Amber Valley Borough Council', slug: 'ambervalley'),
    CouncilInfo(
        id: 'HPBC', name: 'High Peak Borough Council', slug: 'highpeak'),
    CouncilInfo(
        id: 'DDDC',
        name: 'Derbyshire Dales District Council',
        slug: 'derbyshiredales'),
    CouncilInfo(id: 'BDC', name: 'Bolsover District Council', slug: 'bolsover'),
    CouncilInfo(
        id: 'CBC', name: 'Chesterfield Borough Council', slug: 'chesterfield'),
    CouncilInfo(
        id: 'SDDC',
        name: 'South Derbyshire District Council',
        slug: 'southderbyshire'),
    CouncilInfo(
        id: 'NEDDC',
        name: 'North East Derbyshire District Council',
        slug: 'northeastderbyshire'),
  ];

  /// Slugs of councils that use a calendar-based (no postcode) flow. Applied
  /// to every council list on its way out, cached and fetched alike.
  static const Set<String> _calendarBasedSlugs = {
    'bolsover',
    'northeastderbyshire'
  };

  static List<CouncilInfo> _applyCalendarFlags(List<CouncilInfo> councils) => [
        for (final c in councils)
          CouncilInfo(
            id: c.id,
            name: c.name,
            slug: c.slug,
            calendarBased:
                c.calendarBased || _calendarBasedSlugs.contains(c.slug),
          ),
      ];

  static const String _councilListKey = 'council_list';
  static List<CouncilInfo> _councilListMirror = const [];

  static const Map<String, String> _councilWebsites = {
    'derby': 'https://www.derby.gov.uk',
    'erewash': 'https://www.erewash.gov.uk',
    'ambervalley': 'https://www.ambervalley.gov.uk',
    'highpeak': 'https://www.highpeak.gov.uk',
    'derbyshiredales': 'https://www.derbyshiredales.gov.uk',
    'bolsover': 'https://www.bolsover.gov.uk',
    'chesterfield': 'https://www.chesterfield.gov.uk',
    'southderbyshire': 'https://www.southderbyshire.gov.uk',
    'northeastderbyshire': 'https://www.ne-derbyshire.gov.uk',
  };

  static String? websiteFor(String slug) => _councilWebsites[slug];

  /// List councils supported by the backend.
  static Future<List<CouncilInfo>> listCouncils() async {
    await primeCouncilCache();
    return await refreshCouncils() ?? cachedCouncils();
  }

  static List<CouncilInfo> _decodeCouncils(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map || decoded['councils'] is! List) return const [];
      return [
        for (final item in decoded['councils'])
          if (item is Map && item['slug'] != null && item['name'] != null)
            CouncilInfo(
              id: item['id']?.toString() ?? '',
              name: item['name'].toString(),
              slug: item['slug'].toString(),
              calendarBased: item['calendarBased'] == true,
            ),
      ];
    } on Exception {
      return const [];
    }
  }

  static Future<_StoredCouncils?> _readStoredCouncils() async {
    final prefs = await _prefs();
    final json = prefs.getString('${_councilListKey}_data');
    final ts = prefs.getInt('${_councilListKey}_ts');
    if (json == null || ts == null) return null;
    final councils = _decodeCouncils(json);
    if (councils.isEmpty) return null;
    final age = DateTime.now().millisecondsSinceEpoch - ts;
    return _StoredCouncils(councils, isStale: age > _cacheTtl.inMilliseconds);
  }

  /// Best known council list, available without any I/O. Never empty.
  static List<CouncilInfo> cachedCouncils() => _applyCalendarFlags(
      _councilListMirror.isNotEmpty ? _councilListMirror : _fallbackCouncils);

  /// Hydrate the in-memory list from prefs so a persisted list is used in
  /// preference to the hardcoded fallback. A stored list is used even when
  /// older than the cache TTL.
  static Future<List<CouncilInfo>> primeCouncilCache() async {
    final stored = await _readStoredCouncils();
    if (stored != null) _councilListMirror = stored.councils;
    return cachedCouncils();
  }

  /// Fetch the council list from the proxy, skipping the network when the
  /// stored copy is still within the cache TTL. Returns null when the fetch
  /// fails so the caller can keep whatever it is already showing.
  static Future<List<CouncilInfo>?> refreshCouncils() async {
    final stored = await _readStoredCouncils();
    if (stored != null) {
      _councilListMirror = stored.councils;
      if (!stored.isStale) return _applyCalendarFlags(stored.councils);
    }
    try {
      final uri = Uri.parse('$proxyBaseUrl/bins');
      final res = await client.get(uri, headers: _headers).timeout(_timeout);
      if (res.statusCode != 200) return null;
      final list = _decodeCouncils(res.body);
      if (list.isEmpty) return null;
      _councilListMirror = list;
      try {
        await _writeCache(_councilListKey, res.body);
      } catch (_) {}
      return _applyCalendarFlags(list);
    } on Exception {
      return null;
    }
  }

  /// Look up addresses for a postcode in the given council.
  Future<List<CouncilAddress>> lookupAddresses(
      String councilSlug, String postcode) async {
    final uri = Uri.parse('$proxyBaseUrl/bins').replace(
        queryParameters: {'council': councilSlug, 'postcode': postcode});
    final res = await client.get(uri, headers: _headers).timeout(_timeout);
    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['addresses'] is List) {
        final list = [
          for (final item in decoded['addresses'])
            if (item is Map && item['uprn'] != null && item['label'] != null)
              CouncilAddress(
                uprn: item['uprn'].toString(),
                label: item['label'].toString(),
              ),
        ];
        if (list.isNotEmpty) return list;
      }
    }
    return const [];
  }

  Future<List<BinSchedule>?> getCollections(String councilSlug, String uprn,
      {String? postcode}) async {
    final key = _cacheKey(councilSlug, uprn);
    final cached = await _readCache(key);
    if (cached != null) {
      try {
        final decoded = jsonDecode(cached);
        if (decoded is Map && decoded['collections'] is List) {
          final raw = decoded['collections'] as List;
          if (raw.isNotEmpty) return _parseCollections(raw);
        }
      } catch (_) {}
    }

    try {
      final params = <String, String>{'council': councilSlug, 'uprn': uprn};
      if (postcode != null && postcode.isNotEmpty)
        params['postcode'] = postcode;
      final uri =
          Uri.parse('$proxyBaseUrl/bins').replace(queryParameters: params);
      final res = await client.get(uri, headers: _headers).timeout(_timeout);
      if (res.statusCode == 501) return null;
      if (res.statusCode == 200) {
        await _writeCache(key, res.body);
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded['collections'] is List) {
          final raw = decoded['collections'] as List;
          if (raw.isNotEmpty) return _parseCollections(raw);
        }
      }
    } on Exception {
      // backend unreachable
    }
    return null;
  }

  static int _anchorWeekday(Object? dayFromApi, DateTime anchorDate) {
    final anchorWeekday = anchorDate.weekday;
    final declaredMatchesAnchor = dayFromApi is int &&
        dayFromApi >= DateTime.monday &&
        dayFromApi <= DateTime.sunday &&
        dayFromApi == anchorWeekday;
    return declaredMatchesAnchor ? dayFromApi : anchorWeekday;
  }

  List<BinSchedule> _parseCollections(List<dynamic> raw) {
    final byService = <String, _ServiceDates>{};
    for (final item in raw.cast<Map<String, dynamic>>()) {
      final stream = _streamFromString(item['stream']?.toString() ?? '');
      final dayStr = item['dayOfWeek'];
      final dateStr = item['anchorDate']?.toString() ?? '';
      final freqStr = item['frequency']?.toString() ?? '';
      if (stream == null || dateStr.isEmpty) continue;
      final date = DateTime.tryParse(dateStr);
      if (date == null) continue;
      final dayOfWeek = _anchorWeekday(dayStr, date);
      final freq = _frequencyFromString(freqStr);
      byService[stream.name] = _ServiceDates(stream)
        ..dayOfWeek = dayOfWeek
        ..dates.add(date)
        ..frequency = freq;
    }
    return byService.values
        .where((b) => b.dates.isNotEmpty)
        .map((b) => BinSchedule(
              stream: b.stream!,
              dayOfWeek: b.dayOfWeek ?? b.dates.first.weekday,
              frequency: b.frequency ?? Frequency.weekly,
              anchorDate: b.dates.first,
            ))
        .toList();
  }

  WasteStream? _streamFromString(String s) {
    switch (s.toLowerCase()) {
      case 'general':
        return WasteStream.general;
      case 'recycling':
        return WasteStream.recycling;
      case 'garden':
        return WasteStream.garden;
      case 'food':
        return WasteStream.food;
      default:
        return null;
    }
  }

  Frequency? _frequencyFromString(String s) {
    switch (s.toLowerCase()) {
      case 'weekly':
        return Frequency.weekly;
      case 'fortnightly':
        return Frequency.fortnightly;
      case 'threeweekly':
        return Frequency.threeWeekly;
      case 'fourweekly':
        return Frequency.fourWeekly;
      case 'sixweekly':
        return Frequency.sixWeekly;
      case 'eightweekly':
        return Frequency.eightWeekly;
      case 'twelveweekly':
        return Frequency.twelveWeekly;
      default:
        return null;
    }
  }
}

class _ServiceDates {
  final WasteStream? stream;
  final List<DateTime> dates = [];
  int? dayOfWeek;
  Frequency? frequency;
  _ServiceDates(this.stream);
}

class _StoredCouncils {
  final List<CouncilInfo> councils;
  final bool isStale;
  const _StoredCouncils(this.councils, {required this.isStale});
}
