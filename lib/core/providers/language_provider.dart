import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// مدير اللغة للتطبيق
class LanguageProvider extends ChangeNotifier {
  String _currentLanguage = 'en'; // Default to English as requested
  static const String _prefKey = 'selected_language';
  static const Set<String> _supportedLanguageCodes = {'ar', 'en'};
  int _languageChangeGeneration = 0;

  LanguageProvider() {
    _loadLanguage();
  }

  String get currentLanguage => _currentLanguage;

  Locale get currentLocale => Locale(_currentLanguage);

  bool get isArabic => _currentLanguage == 'ar';

  /// تحميل اللغة المحفوظة
  Future<void> _loadLanguage() async {
    final generation = _languageChangeGeneration;
    final prefs = await SharedPreferences.getInstance();
    final storedLanguage = prefs.getString(_prefKey);
    final language = _supportedLanguageCodes.contains(storedLanguage)
        ? storedLanguage!
        : 'en';
    await initializeDateFormatting(language, null);
    if (generation != _languageChangeGeneration) return;
    _currentLanguage = language;
    Intl.defaultLocale = language;
    notifyListeners();
  }

  /// تغيير اللغة مع الحفظ
  Future<void> changeLanguage(String languageCode) async {
    if (!_supportedLanguageCodes.contains(languageCode) ||
        languageCode == _currentLanguage) {
      return;
    }

    final generation = ++_languageChangeGeneration;
    await initializeDateFormatting(languageCode, null);
    if (generation != _languageChangeGeneration) return;

    _currentLanguage = languageCode;
    Intl.defaultLocale = languageCode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    if (generation == _languageChangeGeneration) {
      await prefs.setString(_prefKey, languageCode);
    }
  }

  /// الحصول على النص بناءً على اللغة الحالية
  String getText(Map<String, String> textMap) {
    return textMap[_currentLanguage] ?? textMap['en'] ?? '';
  }
}
