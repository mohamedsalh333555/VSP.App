class PhoneUtils {
  /// Normalizes a phone number to a consistent format for database storage and searching.
  /// Removes all non-digit characters and ensures common Egyptian formats are handled.
  static String normalize(String phone) {
    // 1. Remove all non-digit characters
    String normalized = phone.replaceAll(RegExp(r'\D'), '');

    // 2. Handle common Egyptian prefix scenarios
    // If it starts with '20' and is exactly 12 digits (e.g. 201012345678)
    if (normalized.startsWith('20') && normalized.length == 12) {
      normalized = normalized.substring(2);
    }
    
    // Ensure it starts with '0' if it's a 10-digit number and starts with a valid Egyptian operator code (10, 11, 12, 15)
    if (normalized.length == 10 && normalized.startsWith(RegExp(r'1[0125]'))) {
      normalized = '0$normalized';
    }

    return normalized;
  }

  /// Compares two phone numbers after normalization.
  static bool compare(String phone1, String phone2) {
    return normalize(phone1) == normalize(phone2);
  }
}
