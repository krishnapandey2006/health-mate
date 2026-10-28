import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';

/// Local-only profile persistence. No account, cloud store or network call is
/// involved. Storage failures are surfaced to the provider instead of being
/// presented as a successful save.
class ProfileRepository {
  static const _deviceKey = 'healthmate_profile_v2_device';
  static const _migrationFlag = 'healthmate_profile_v2_migrated';
  static const _setupSkippedKey = 'healthmate_setup_skipped';

  final SharedPreferences? _prefsOverride;

  ProfileRepository({SharedPreferences? prefs}) : _prefsOverride = prefs;

  Future<SharedPreferences> _prefs() async =>
      _prefsOverride ?? await SharedPreferences.getInstance();

  Future<UserProfile?> load() async {
    final prefs = await _prefs();
    final raw = prefs.getString(_deviceKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) return UserProfile.fromMap(map);
      if (map is Map) return UserProfile.fromMap(Map<String, dynamic>.from(map));
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<bool> save(UserProfile profile) async {
    try {
      final prefs = await _prefs();
      return await prefs.setString(_deviceKey, jsonEncode(profile.toMap()));
    } catch (_) {
      return false;
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await _prefs();
      await prefs.remove(_deviceKey);
      await prefs.remove(_setupSkippedKey);
    } catch (_) {
      // The provider still clears its in-memory copy.
    }
  }

  Future<bool> loadSetupSkipped() async {
    try {
      final prefs = await _prefs();
      return prefs.getBool(_setupSkippedKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setSetupSkipped(bool value) async {
    try {
      final prefs = await _prefs();
      await prefs.setBool(_setupSkippedKey, value);
    } catch (_) {
      // A skipped onboarding state is a convenience, not medical data.
    }
  }

  /// Converts the old split SharedPreferences keys into one local profile so
  /// existing users are not asked for their name and age again.
  Future<UserProfile?> migrateLegacy() async {
    final prefs = await _prefs();
    if (prefs.getBool(_migrationFlag) == true) return load();

    final hasLegacy = prefs.containsKey('first_name') ||
        prefs.containsKey('user_name') ||
        prefs.containsKey('user_phone') ||
        prefs.containsKey('user_dob');
    if (!hasLegacy) {
      await prefs.setBool(_migrationFlag, true);
      return null;
    }

    final profile = UserProfile.fromMap({
      'first_name': prefs.getString('first_name'),
      'last_name': prefs.getString('last_name'),
      'user_name': prefs.getString('user_name'),
      'user_phone': prefs.getString('user_phone'),
      'user_dob': prefs.getString('user_dob'),
      'user_gender': prefs.getString('user_gender'),
      'user_state': prefs.getString('user_state'),
      'language_code': prefs.getString('language_code'),
      'needs_assistance': prefs.getBool('needs_assistance'),
      'allow_critical_alerts': prefs.getBool('allow_critical_alerts'),
    });

    if (profile.firstName.isNotEmpty ||
        profile.dateOfBirth != null ||
        profile.phone.isNotEmpty) {
      await save(profile);
    }
    await prefs.setBool(_migrationFlag, true);
    return profile;
  }
}
