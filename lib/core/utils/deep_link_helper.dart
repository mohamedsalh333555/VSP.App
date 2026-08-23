class ParsedDeepLink {
  final String type; // 'match', 'team', 'championship'
  final String id;

  const ParsedDeepLink({required this.type, required this.id});

  String get routePath => '/$type/$id';
}

/// 🔗 معالج ومحلل الروابط العميقة الموحد لتطبيق VSP
class DeepLinkHelper {
  static final RegExp _validIdRegex = RegExp(r'^[a-zA-Z0-9\-_\s]+$');

  /// التحقق من روابط OAuth العائدة من مزودي الخدمة (Google / Apple)
  static bool isOAuthCallback(Uri uri) {
    return uri.scheme == 'io.supabase.fluttervsp' && uri.host == 'login-callback';
  }

  /// تحليل وفحص أمان المعرف داخل الرابط العميق
  static ParsedDeepLink? parse(Uri uri) {
    try {
      String? type;
      String? id;

      if (uri.scheme == 'io.supabase.fluttervsp') {
        type = uri.host;
        if (uri.pathSegments.isNotEmpty) {
          id = uri.pathSegments.first;
        }
      } else {
        if (uri.pathSegments.length >= 2) {
          type = uri.pathSegments[0]; // match or team or championship
          id = uri.pathSegments[1];
        }
      }

      if (type != null && id != null && id.isNotEmpty) {
        // التحقق من سلامة وصحة المعرف لمنع الاختراق أو الرموز الخبيثة
        if (!_validIdRegex.hasMatch(id)) {
          return null;
        }

        if (type == 'match' || type == 'team' || type == 'championship') {
          return ParsedDeepLink(type: type, id: id);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
