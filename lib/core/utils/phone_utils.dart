class PhoneUtils {
  /// Normalizes a phone number to a consistent format for database storage and searching.
  /// Standardizes local and international phone formats (E.164 support).
  /// Returns null if phone is empty or contains no digits to prevent DB unique constraint conflicts.
  static String? normalize(String? phone) {
    if (phone == null || phone.isEmpty) return null;

    // 1. Convert Arabic/Eastern numerals to Western numerals
    String result = _convertEasternToWesternDigits(phone);

    // 2. Remove all non-digit characters except leading '+' if present
    final hasPlus = result.trim().startsWith('+');
    result = result.replaceAll(RegExp(r'\D'), '');

    if (result.isEmpty) return null;

    // 3. Handle Egyptian national vs international formats
    if (result.startsWith('20') && result.length == 12) {
      result = '0${result.substring(2)}';
    } else if (result.length == 10 && result.startsWith(RegExp(r'1[0125]'))) {
      result = '0$result';
    } else if (hasPlus) {
      result = '+$result';
    }

    return result;
  }

  /// Converts a phone number to international E.164 format (e.g. +201012345678)
  static String toE164(String phone, {String defaultCountryCode = '20'}) {
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.isEmpty) return '';

    if (cleaned.startsWith(defaultCountryCode)) {
      return '+$cleaned';
    } else if (cleaned.startsWith('0')) {
      return '+$defaultCountryCode${cleaned.substring(1)}';
    } else {
      return '+$defaultCountryCode$cleaned';
    }
  }

  /// Compares two phone numbers after normalization.
  static bool compare(String phone1, String phone2) {
    if (phone1.isEmpty || phone2.isEmpty) return false;
    final n1 = normalize(phone1);
    final n2 = normalize(phone2);
    if (n1 == null || n2 == null) return false;
    return n1 == n2 || toE164(phone1) == toE164(phone2);
  }

  static String _convertEasternToWesternDigits(String input) {
    const eastern = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const western = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];

    String output = input;
    for (int i = 0; i < eastern.length; i++) {
      output = output.replaceAll(eastern[i], western[i]);
    }
    return output;
  }
}

