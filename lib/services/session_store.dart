import 'package:shared_preferences/shared_preferences.dart';

class SavedSession {
  final String councilSlug;
  final String councilName;
  final String postcode;
  final String uprn;
  final String addressLabel;

  const SavedSession({
    required this.councilSlug,
    required this.councilName,
    required this.postcode,
    required this.uprn,
    required this.addressLabel,
  });
}

class SessionStore {
  static const _keyCouncilSlug = 'councilSlug';
  static const _keyCouncilName = 'councilName';
  static const _keyPostcode = 'postcode';
  static const _keyUprn = 'uprn';
  static const _keyAddressLabel = 'addressLabel';

  static Future<void> save(SavedSession s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCouncilSlug, s.councilSlug);
    await prefs.setString(_keyCouncilName, s.councilName);
    await prefs.setString(_keyPostcode, s.postcode);
    await prefs.setString(_keyUprn, s.uprn);
    await prefs.setString(_keyAddressLabel, s.addressLabel);
  }

  static Future<SavedSession?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final slug = prefs.getString(_keyCouncilSlug);
    final name = prefs.getString(_keyCouncilName);
    final pc = prefs.getString(_keyPostcode);
    final uprn = prefs.getString(_keyUprn);
    final label = prefs.getString(_keyAddressLabel);
    if (slug == null || name == null || pc == null || uprn == null || label == null) {
      return null;
    }
    return SavedSession(
      councilSlug: slug,
      councilName: name,
      postcode: pc,
      uprn: uprn,
      addressLabel: label,
    );
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCouncilSlug);
    await prefs.remove(_keyCouncilName);
    await prefs.remove(_keyPostcode);
    await prefs.remove(_keyUprn);
    await prefs.remove(_keyAddressLabel);
  }
}
