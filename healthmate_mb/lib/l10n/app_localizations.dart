import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';

class AppLocalizations {
  final Locale locale;
  Map<String, String> _strings = {};

  static final Map<String, Map<String, String>> _cache = {};
  static Map<String, String>? _englishFallback;

  AppLocalizations(this.locale);

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static const supportedLanguageCodes = ['en', 'hi', 'mr', 'bn', 'gu', 'ta'];

  static AppLocalizations of(BuildContext context) {
    final loc = Localizations.of<AppLocalizations>(context, AppLocalizations);
    if (loc != null) return loc;
    final fallback = AppLocalizations(const Locale('en'));
    fallback._strings = _englishFallback ?? {};
    return fallback;
  }

  /// Loads the locale file and overlays it on English. Missing translations
  /// therefore show readable English instead of raw keys.
  Future<bool> loadFromAssets() async {
    final code = locale.languageCode;
    try {
      final english = _englishFallback ?? await _readAsset('en');
      _englishFallback = english;
      if (code == 'en') {
        _strings = english;
        return true;
      }
      final localized = await _readAsset(code);
      _strings = {...english, ...localized};
      return true;
    } catch (_) {
      _strings = _englishFallback ?? {};
      return false;
    }
  }

  Future<Map<String, String>> _readAsset(String code) async {
    final cached = _cache[code];
    if (cached != null) return cached;
    final data = await rootBundle.loadString('lib/l10n/intl_$code.arb');
    final decoded = jsonDecode(data);
    final map = <String, String>{};
    if (decoded is Map) {
      decoded.forEach((key, value) {
        if (!key.toString().startsWith('@') && value is String) {
          map[key.toString()] = value;
        }
      });
    }
    _cache[code] = map;
    return map;
  }

  Future<bool> load(BuildContext context) => loadFromAssets();

  String t(String key) {
    final value = _strings[key];
    if (value != null && value.isNotEmpty) return value;
    final english = _englishFallback?[key];
    if (english != null && english.isNotEmpty) return english;
    return key;
  }

  String tr(String key, Map<String, String> values) {
    var value = t(key);
    values.forEach((name, replacement) {
      value = value.replaceAll('{$name}', replacement);
    });
    return value;
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLanguageCodes.contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final loc = AppLocalizations(locale);
    await loc.loadFromAssets();
    return loc;
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}
