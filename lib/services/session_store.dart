import 'package:shared_preferences/shared_preferences.dart';

/// Stores the user's selected address and council preference.
class SessionStore {
  static const _keyAddress = 'session_address';
  static const _keyUprn = 'session_uprn';
  static const _keyCouncil = 'session_council';
  static const _keyPostcode = 'session_postcode';

  Future<void> saveSession({
    required String uprn,
    required String address,
    required String council,
    required String postcode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUprn, uprn);
    await prefs.setString(_keyAddress, address);
    await prefs.setString(_keyCouncil, council);
    await prefs.setString(_keyPostcode, postcode);
  }

  Future<Map<String, String>?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final uprn = prefs.getString(_keyUprn);
    final address = prefs.getString(_keyAddress);
    final council = prefs.getString(_keyCouncil);
    final postcode = prefs.getString(_keyPostcode);

    if (uprn == null || address == null || council == null) return null;

    return {
      'uprn': uprn,
      'address': address,
      'council': council,
      'postcode': postcode ?? '',
    };
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUprn);
    await prefs.remove(_keyAddress);
    await prefs.remove(_keyCouncil);
    await prefs.remove(_keyPostcode);
  }

  Future<bool> hasSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_keyUprn);
  }
}
