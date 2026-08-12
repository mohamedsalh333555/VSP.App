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
    
    'beheira': 'Beheira',
    'sharqia': 'Sharqia',
    'dakahlia': 'Dakahlia',
    'monufia': 'Monufia',
    'alexandria': 'Alexandria',
    'beni suef': 'Beni Suef',
    'damietta': 'Damietta',
    'faiyum': 'Faiyum',
    'gharbia': 'Gharbia',
    'ismailia': 'Ismailia',
    'kafr el sheikh': 'Kafr El Sheikh',
    'luxor': 'Luxor',
    'matrouh': 'Matrouh',
    'minya': 'Minya',
    'new valley': 'New Valley',
    'north Sinai': 'North Sinai',
    'port said': 'Port Said',
    'qalyubia': 'Qalyubia',
    'qena': 'Qena',
    'sohag': 'Sohag',
    'south sinai': 'South Sinai',
    
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

  /// Map of English standard governorate names to Arabic display names
  static const Map<String, String> governorateToArabic = {
    'Cairo': 'القاهرة',
    'Giza': 'الجيزة',
    'Alexandria': 'الإسكندرية',
    'Aswan': 'أسوان',
    'Luxor': 'الأقصر',
    'Red Sea': 'البحر الأحمر',
    'Dakahlia': 'الدقهلية',
    'Sharqia': 'الشرقية',
    'Gharbia': 'الغربية',
    'Monufia': 'المنوفية',
    'Beheira': 'البحيرة',
    'Suez': 'السويس',
    'Port Said': 'بورسعيد',
    'Ismailia': 'الإسماعيلية',
    'Damietta': 'دمياط',
    'Faiyum': 'الفيوم',
    'Beni Suef': 'بني سويف',
    'Minya': 'المنيا',
    'Asyut': 'أسيوط',
    'Sohag': 'سوهاج',
    'Qena': 'قنا',
    'South Sinai': 'جنوب سيناء',
    'North Sinai': 'شمال سيناء',
    'Matrouh': 'مطروح',
    'New Valley': 'الوادي الجديد',
    'Kafr El Sheikh': 'كفر الشيخ',
    'Qalyubia': 'القليوبية',
  };

  /// Takes a raw string from Google Maps Geocoding API and returns a standard Governorate, or null if unknown
  static String? resolveGoogleName(String? rawGeocodeName) {
    if (rawGeocodeName == null || rawGeocodeName.isEmpty) {
      return null;
    }

    // 1. Convert to lowercase & clean leading/trailing spaces
    String cleanedStr = rawGeocodeName.trim().toLowerCase();

    // 2. Remove common Google Maps suffix terms
    cleanedStr = cleanedStr.replaceAll(' governorate', '');
    cleanedStr = cleanedStr.replaceAll(' mohafazah', '');
    cleanedStr = cleanedStr.replaceAll(' muhafazah', '');

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

    // If completely unknown, return null
    return null;
  }

  /// Smart formatter that converts raw Google Maps placemarks into clean Arabic [Governorate - Markaz/City] format
  /// Example: "Sheyakhah Thalethah, Aswan Governorate" -> "أسوان - المدينة"
  /// Example: "Kom Ombo, Aswan Governorate" -> "أسوان - كوم أمبو"
  /// Example: "Esna, Luxor" -> "الأقصر - إسنا"
  static String formatSmartLocation({
    String? subLocality,
    String? locality,
    String? subAdministrativeArea,
    String? administrativeArea,
    String? rawAddress,
  }) {
    // 1. Resolve Governorate
    final rawGov = administrativeArea ?? subAdministrativeArea ?? locality ?? rawAddress;
    final stdGov = resolveGoogleName(rawGov) ?? 'Aswan';
    final arGov = governorateToArabic[stdGov] ?? stdGov;

    // 2. Resolve Markaz / District / City
    String candidateMarkaz = subAdministrativeArea ?? locality ?? subLocality ?? '';
    if (candidateMarkaz.isEmpty && rawAddress != null) {
      candidateMarkaz = rawAddress;
    }

    // Clean noise terms
    String cleaned = candidateMarkaz.trim();
    cleaned = cleaned.replaceAll(RegExp(r'(governorate|mohafazah|muhafazah|مركز|قسم|حي|مدينة|محافظة)', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'(sheyakhah|sheikha|thalethah|oula|thaniya|1st|2nd|3rd|4th|5th|district)', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'[\d,_\-]+'), '').trim();

    String arMarkaz = 'المدينة';
    final lowerCleaned = cleaned.toLowerCase();

    // Aswan Markazes & Famous Districts
    if (stdGov == 'Aswan') {
      if (lowerCleaned.contains('kima') || lowerCleaned.contains('كيما')) {
        arMarkaz = 'كيما';
      } else if (lowerCleaned.contains('sadaqa') || lowerCleaned.contains('صداقة') || lowerCleaned.contains('الصداقة')) {
        arMarkaz = 'الصداقة';
      } else if (lowerCleaned.contains('aqqad') || lowerCleaned.contains('عقاد') || lowerCleaned.contains('العقاد')) {
        arMarkaz = 'العقاد';
      } else if (lowerCleaned.contains('tameen') || lowerCleaned.contains('تأمين') || lowerCleaned.contains('التأمين')) {
        arMarkaz = 'التأمين';
      } else if (lowerCleaned.contains('jazeera') || lowerCleaned.contains('جزيرة') || lowerCleaned.contains('الجزيرة')) {
        arMarkaz = 'الجزيرة';
      } else if (lowerCleaned.contains('rish') || lowerCleaned.contains('ريش') || lowerCleaned.contains('أبو ريش')) {
        arMarkaz = 'أبو ريش';
      } else if (lowerCleaned.contains('corniche') || lowerCleaned.contains('كورنيش') || lowerCleaned.contains('الكورنيش')) {
        arMarkaz = 'الكورنيش';
      } else if (lowerCleaned.contains('kom') || lowerCleaned.contains('ombo') || lowerCleaned.contains('كوم')) {
        arMarkaz = 'كوم أمبو';
      } else if (lowerCleaned.contains('edfu') || lowerCleaned.contains('ادفو') || lowerCleaned.contains('إدفو')) {
        arMarkaz = 'إدفو';
      } else if (lowerCleaned.contains('nasser') || lowerCleaned.contains('nuba') || lowerCleaned.contains('نوبة')) {
        arMarkaz = 'نصر النوبة';
      } else if (lowerCleaned.contains('daraw') || lowerCleaned.contains('دراو')) {
        arMarkaz = 'دراو';
      } else if (lowerCleaned.contains('simbel') || lowerCleaned.contains('سمبل')) {
        arMarkaz = 'أبو سمبل';
      } else {
        arMarkaz = 'المدينة';
      }
    }
    // Luxor Markazes
    else if (stdGov == 'Luxor') {
      if (lowerCleaned.contains('esna') || lowerCleaned.contains('اسنا') || lowerCleaned.contains('إسنا')) {
        arMarkaz = 'إسنا';
      } else if (lowerCleaned.contains('armant') || lowerCleaned.contains('ارمنت') || lowerCleaned.contains('أرمنت')) {
        arMarkaz = 'أرمنت';
      } else if (lowerCleaned.contains('tod') || lowerCleaned.contains('طود')) {
        arMarkaz = 'الطود';
      } else if (lowerCleaned.contains('qarna') || lowerCleaned.contains('قرنة')) {
        arMarkaz = 'القرنة';
      } else {
        arMarkaz = 'المدينة';
      }
    }
    // Giza Districts
    else if (stdGov == 'Giza') {
      if (lowerCleaned.contains('october') || lowerCleaned.contains('أكتوبر') || lowerCleaned.contains('6')) {
        arMarkaz = '6 أكتوبر';
      } else if (lowerCleaned.contains('zayed') || lowerCleaned.contains('زايد')) {
        arMarkaz = 'الشيخ زايد';
      } else if (lowerCleaned.contains('haram') || lowerCleaned.contains('هرم')) {
        arMarkaz = 'الهرم';
      } else if (lowerCleaned.contains('dokki') || lowerCleaned.contains('دقي')) {
        arMarkaz = 'الدقي';
      } else if (lowerCleaned.contains('agouza') || lowerCleaned.contains('عجوزة')) {
        arMarkaz = 'العجوزة';
      } else if (lowerCleaned.contains('faisal') || lowerCleaned.contains('فيصل')) {
        arMarkaz = 'فيصل';
      } else if (lowerCleaned.contains('ayat') || lowerCleaned.contains('عياط')) {
        arMarkaz = 'العياط';
      } else if (lowerCleaned.contains('badrashein') || lowerCleaned.contains('بدرشين')) {
        arMarkaz = 'البدرشين';
      } else {
        arMarkaz = 'المدينة';
      }
    }
    // Cairo Districts
    else if (stdGov == 'Cairo') {
      if (lowerCleaned.contains('nasr') || lowerCleaned.contains('نصر')) {
        arMarkaz = 'مدينة نصر';
      } else if (lowerCleaned.contains('maadi') || lowerCleaned.contains('معادي')) {
        arMarkaz = 'المعادي';
      } else if (lowerCleaned.contains('heliopolis') || lowerCleaned.contains('مصر الجديدة')) {
        arMarkaz = 'مصر الجديدة';
      } else if (lowerCleaned.contains('tagamoa') || lowerCleaned.contains('تجمع') || lowerCleaned.contains('fifth')) {
        arMarkaz = 'التجمع الخامس';
      } else if (lowerCleaned.contains('shorouk') || lowerCleaned.contains('شروق')) {
        arMarkaz = 'الشروق';
      } else if (lowerCleaned.contains('badr') || lowerCleaned.contains('بدر')) {
        arMarkaz = 'بدر';
      } else if (lowerCleaned.contains('helwan') || lowerCleaned.contains('حلوان')) {
        arMarkaz = 'حلوان';
      } else if (lowerCleaned.contains('zamalek') || lowerCleaned.contains('زمالك')) {
        arMarkaz = 'الزمالك';
      } else {
        arMarkaz = 'المدينة';
      }
    }
    // Alexandria Districts
    else if (stdGov == 'Alexandria') {
      if (lowerCleaned.contains('smouha') || lowerCleaned.contains('سموحة')) {
        arMarkaz = 'سموحة';
      } else if (lowerCleaned.contains('montazah') || lowerCleaned.contains('منتزه')) {
        arMarkaz = 'المنتزه';
      } else if (lowerCleaned.contains('bisher') || lowerCleaned.contains('بشر')) {
        arMarkaz = 'سيدي بشر';
      } else if (lowerCleaned.contains('agami') || lowerCleaned.contains('عجمي')) {
        arMarkaz = 'العجمي';
      } else if (lowerCleaned.contains('borg') || lowerCleaned.contains('برج العرب')) {
        arMarkaz = 'برج العرب';
      } else {
        arMarkaz = 'المدينة';
      }
    }
    // Beheira Markazes
    else if (stdGov == 'Beheira') {
      if (lowerCleaned.contains('damanhour') || lowerCleaned.contains('دمنهور')) {
        arMarkaz = 'المدينة';
      } else if (lowerCleaned.contains('kafr') || lowerCleaned.contains('دوار')) {
        arMarkaz = 'كفر الدوار';
      } else if (lowerCleaned.contains('etay') || lowerCleaned.contains('إيتاي')) {
        arMarkaz = 'إيتاي البارود';
      } else if (lowerCleaned.contains('rashid') || lowerCleaned.contains('رشيد')) {
        arMarkaz = 'رشيد';
      } else {
        arMarkaz = 'المدينة';
      }
    }
    // Dakahlia Markazes
    else if (stdGov == 'Dakahlia') {
      if (lowerCleaned.contains('mansoura') || lowerCleaned.contains('المنصورة')) {
        arMarkaz = 'المدينة';
      } else if (lowerCleaned.contains('mit') || lowerCleaned.contains('ميت غمر')) {
        arMarkaz = 'ميت غمر';
      } else if (lowerCleaned.contains('talkha') || lowerCleaned.contains('طلخا')) {
        arMarkaz = 'طلخا';
      } else {
        arMarkaz = 'المدينة';
      }
    }
    // General fallback if clean string exists
    else if (cleaned.isNotEmpty && cleaned.length <= 20) {
      arMarkaz = cleaned;
    }

    return '$arGov $arMarkaz';
  }
}
