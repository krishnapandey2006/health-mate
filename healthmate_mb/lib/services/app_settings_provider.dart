import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-level preferences (not medical profile data).
class AppSettingsProvider extends ChangeNotifier {
  static const _textScaleKey = 'settings_text_scale';
  static const _readingKey = 'settings_reading_assistance';
  static const _voiceKey = 'settings_voice_guidance';
  static const _notificationsKey = 'settings_notifications_enabled';
  static const _emergencyKey = 'emergency_number';

  double _textScale = 1.0;
  bool _readingAssistance = false;
  bool _voiceGuidance = true;
  bool _notificationsEnabled = true;
  String _emergencyNumber = '112';

  double get textScale => _textScale;
  bool get readingAssistance => _readingAssistance;
  bool get voiceGuidance => _voiceGuidance;
  bool get notificationsEnabled => _notificationsEnabled;
  String get emergencyNumber => _emergencyNumber;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _textScale = prefs.getDouble(_textScaleKey) ?? 1.0;
    _readingAssistance = prefs.getBool(_readingKey) ?? false;
    _voiceGuidance = prefs.getBool(_voiceKey) ?? true;
    _notificationsEnabled = prefs.getBool(_notificationsKey) ?? true;
    _emergencyNumber = prefs.getString(_emergencyKey) ?? '112';
    notifyListeners();
  }

  Future<void> setTextScale(double value) async {
    _textScale = value.clamp(1.0, 1.5);
    await _persistDouble(_textScaleKey, _textScale);
    notifyListeners();
  }

  Future<void> setReadingAssistance(bool value) async {
    _readingAssistance = value;
    // Turning reading assistance on gives an immediate, visible boost without
    // overriding a larger text size the user chose separately.
    if (value && _textScale < 1.15) _textScale = 1.15;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_readingKey, value);
    await prefs.setDouble(_textScaleKey, _textScale);
    notifyListeners();
  }

  Future<void> setVoiceGuidance(bool value) async {
    _voiceGuidance = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_voiceKey, value);
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsKey, value);
    notifyListeners();
  }

  Future<bool> setEmergencyNumber(String value) async {
    final cleaned = value.trim();
    if (!RegExp(r'^[0-9+\- ]{3,15}$').hasMatch(cleaned)) return false;
    _emergencyNumber = cleaned;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emergencyKey, cleaned);
    notifyListeners();
    return true;
  }

  Future<void> _persistDouble(String key, double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(key, value);
  }
}
