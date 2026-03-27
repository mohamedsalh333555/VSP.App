class EgyptGovernorates {
  static const List<String> allGovernorates = [
    'Alexandria',
    'Aswan',
    'Asyut',
    'Beheira',
    'Beni Suef',
    'Cairo',
    'Dakahlia',
    'Damietta',
    'Faiyum',
    'Gharbia',
    'Giza',
    'Ismailia',
    'Kafr El Sheikh',
    'Luxor',
    'Matrouh',
    'Minya',
    'Monufia',
    'New Valley',
    'North Sinai',
    'Port Said',
    'Qalyubia',
    'Qena',
    'Red Sea',
    'Sharqia',
    'Sohag',
    'South Sinai',
    'Suez'
  ];

  static const Map<String, String> _googleToStandard = {
    'al iskandariyah': 'Alexandria',
    'alex': 'Alexandria',
    'aswan': 'Aswan',
    'asyut': 'Asyut',
    'al buhayrah': 'Beheira',
    'bani suwayf': 'Beni Suef',
    'al qahirah': 'Cairo',
    'cairo': 'Cairo',
    'qahirah': 'Cairo',
    'ad daqahliyah': 'Dakahlia',
    'dumyat': 'Damietta',
    'al fayyum': 'Faiyum',
    'al gharbiyah': 'Gharbia',
    'al jizah': 'Giza',
    'giza': 'Giza',
    'al ismailiyah': 'Ismailia',
    'kafr ash shaykh': 'Kafr El Sheikh',
    'al uqsur': 'Luxor',
    'matruh': 'Matrouh',
    'marsa matruh': 'Matrouh',
    'al minya': 'Minya',
    'al minufiyah': 'Monufia',
    'al wadi al jadid': 'New Valley',
    'shimal sina': 'North Sinai',
    'bur said': 'Port Said',
    'al qalyubiyah': 'Qalyubia',
    'qina': 'Qena',
    'al bahr al ahmar': 'Red Sea',
    'red sea': 'Red Sea',
    'ash sharqiyah': 'Sharqia',
    'suhaj': 'Sohag',
    'janub sina': 'South Sinai',
    'as suways': 'Suez',
    'suez': 'Suez',
    
    // Arabic Mappings
    'القاهرة': 'Cairo',
    'الجيزة': 'Giza',
    'الإسكندرية': 'Alexandria',
    'الأسكندرية': 'Alexandria',
    'أسوان': 'Aswan',
    'اسوان': 'Aswan',
    'أسيوط': 'Asyut',
    'اسيوط': 'Asyut',
    'البحيرة': 'Beheira',
    'بني سويف': 'Beni Suef',
    'الدقهلية': 'Dakahlia',
    'دمياط': 'Damietta',
    'الفيوم': 'Faiyum',
    'الغربية': 'Gharbia',
    'الإسماعيلية': 'Ismailia',
    'الاسماعيلية': 'Ismailia',
    'كفر الشيخ': 'Kafr El Sheikh',
    'الأقصر': 'Luxor',
    'الاقصر': 'Luxor',
    'مطروح': 'Matrouh',
    'مرسى مطروح': 'Matrouh',
    'المنيا': 'Minya',
    'المنوفية': 'Monufia',
    'الوادي الجديد': 'New Valley',
    'شمال سيناء': 'North Sinai',
    'بورسعيد': 'Port Said',
    'القليوبية': 'Qalyubia',
    'قنا': 'Qena',
    'البحر الأحمر': 'Red Sea',
    'الشرقية': 'Sharqia',
    'سوهاج': 'Sohag',
    'جنوب سيناء': 'South Sinai',
    'السويس': 'Suez',
  };

  /// Takes a raw string from Google Maps Geocoding API and returns a standard Governorate
  static String resolveGoogleName(String? rawGeocodeName) {
    if (rawGeocodeName == null || rawGeocodeName.isEmpty) {
      return 'Cairo'; // Fallback
    }

    // 1. Convert to lowercase & clean leading/trailing spaces
    String cleanedStr = rawGeocodeName.trim().toLowerCase();

    // 2. Remove common Google Maps suffix terms
    cleanedStr = cleanedStr.replaceAll(' governorate', '');
    cleanedStr = cleanedStr.replaceAll(' mohafazah', '');
    cleanedStr = cleanedStr.replaceAll(' muhafazah', '');

    // 3. Remove Arabic articles ("Al", "Ad", "Ash", etc.)
    // Note: sometimes "Al" is needed for exact map matching, so we check both with and without articles.
    
    // Direct match check first
    if (_googleToStandard.containsKey(cleanedStr)) {
      return _googleToStandard[cleanedStr]!;
    }

    // Aggressive matching strategy
    for (var key in _googleToStandard.keys) {
      if (cleanedStr.contains(key) || key.contains(cleanedStr)) {
        return _googleToStandard[key]!;
      }
    }

    // If completely unknown, return Cairo
    return 'Cairo';
  }
}
