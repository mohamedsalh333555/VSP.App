import 'package:flutter/material.dart';

/// مدير اللغة للتطبيق
class LanguageProvider extends ChangeNotifier {
  String _currentLanguage = 'en'; // Default to English as requested

  String get currentLanguage => _currentLanguage;

  Locale get currentLocale => Locale(_currentLanguage);

  bool get isArabic => _currentLanguage == 'ar';

  /// تغيير اللغة
  void changeLanguage(String languageCode) {
    _currentLanguage = languageCode;
    notifyListeners();
  }

  /// الحصول على النص بناءً على اللغة الحالية
  String getText(Map<String, String> textMap) {
    return textMap[_currentLanguage] ?? textMap['en'] ?? '';
  }
}
