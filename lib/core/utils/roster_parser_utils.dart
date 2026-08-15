class RosterParserUtils {
  /// Street-smart WhatsApp / Notes multiline squad list parser.
  /// Converts copied raw text lines like:
  /// 1- أحمد محمود
  /// 2. كابتن علي
  /// • محمد شعبان
  /// into a clean list: ["أحمد محمود", "علي", "محمد شعبان"]
  static List<String> parseSquadText(String rawText) {
    if (rawText.trim().isEmpty) return [];

    final lines = rawText.split(RegExp(r'\r?\n'));
    final Set<String> namesSet = {};
    final List<String> result = [];

    // Prefix stripping regexes
    final numberingRegex = RegExp(r'^\s*(?:\(?\d+[\.\-\/\)]|\d+\s*[\-\.]|[•\-\*\+\#\[\]])\s*');
    final captainPrefixRegex = RegExp(r'^(?:كابتن|اللاعب\s*:?|لاعب\s*:?)\s*', caseSensitive: false);

    for (var line in lines) {
      String clean = line.trim();
      if (clean.isEmpty) continue;

      // 1. Strip leading numbering and bullets: 1-, 1., (1), -, •, *, etc.
      clean = clean.replaceAll(numberingRegex, '').trim();

      // 2. Strip title prefixes if present at start: "كابتن أحمد" -> "أحمد", "اللاعب: علي" -> "علي"
      clean = clean.replaceAll(captainPrefixRegex, '').trim();

      // 3. Ignore header/footer lines if they are pure headers (e.g. "تشكيلة الفريق:")
      if (clean.isEmpty) continue;
      if ((clean.startsWith('تشكيلة') || clean.startsWith('قائمة') || clean.startsWith('أسماء')) && clean.endsWith(':')) {
        continue;
      }

      // 4. Clean duplicate spaces inside name
      clean = clean.replaceAll(RegExp(r'\s+'), ' ');

      if (clean.length >= 2 && !namesSet.contains(clean.toLowerCase())) {
        namesSet.add(clean.toLowerCase());
        result.add(clean);
      }
    }

    return result;
  }
}
