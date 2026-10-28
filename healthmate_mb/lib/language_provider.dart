import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  static const supportedCodes = ['en', 'hi', 'mr', 'bn', 'gu', 'ta'];
  String _languageCode = 'en'; // default English

  String get languageCode => _languageCode;

  Future<void> setLanguage(String code) async {
    if (!supportedCodes.contains(code)) return;
    _languageCode = code;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language_code', code);
    } catch (_) {
      // The in-memory language still updates for this session.
    }
  }

  // Load saved language from SharedPreferences if available
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString('language_code');
      if (code != null && supportedCodes.contains(code)) {
        _languageCode = code;
        notifyListeners();
      }
    } catch (_) {}
  }
}
