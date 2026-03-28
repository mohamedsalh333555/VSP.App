import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// مدير اللغة للتطبيق
class LanguageProvider extends ChangeNotifier {
  String _currentLanguage = 'en'; // Default to English as requested
  static const String _prefKey = 'selected_language';

  LanguageProvider() {
    _loadLanguage();
  }

  String get currentLanguage => _currentLanguage;

  Locale get currentLocale => Locale(_currentLanguage);

  bool get isArabic => _currentLanguage == 'ar';

  /// تحميل اللغة المحفوظة
  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLanguage = prefs.getString(_prefKey) ?? 'en';
    await _updateLocaleSettings();
    notifyListeners();
  }

  Future<void> _updateLocaleSettings() async {
    Intl.defaultLocale = _currentLanguage;
    await initializeDateFormatting(_currentLanguage, null);
  }

  /// تغيير اللغة مع الحفظ
  Future<void> changeLanguage(String languageCode) async {
    _currentLanguage = languageCode;
    await _updateLocaleSettings();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, languageCode);
  }

  /// الحصول على النص بناءً على اللغة الحالية
  String getText(Map<String, String> textMap) {
    return textMap[_currentLanguage] ?? textMap['en'] ?? '';
  }
}
