class ParsedDeepLink {
  final String type; // 'match', 'team', 'championship', 'booking', 'stadium', 'payment-complete'
  final String id;
  final Map<String, String>? queryParams;

  const ParsedDeepLink({required this.type, required this.id, this.queryParams});

  String get routePath {
    if (type == 'payment-complete' || type == 'open') {
      return '/player/my-bookings';
    }
    if (id.isEmpty) {
      return '/$type';
    }
    return '/$type/$id';
  }
}

/// معالج ومحلل الروابط العميقة الموحد لتطبيق VSP
class DeepLinkHelper {
  static final RegExp _validIdRegex = RegExp(r'^[a-zA-Z0-9\-_\s]+$');
  static const Set<String> _validTypes = {
    'match',
    'team',
    'championship',
    'booking',
    'stadium',
    'payment-complete',
    'open',
  };

  /// التحقق من روابط OAuth العائدة من مزودي الخدمة (Google / Apple)
  static bool isOAuthCallback(Uri uri) {
    if ((uri.scheme == 'io.supabase.fluttervsp' || uri.scheme == 'vspapp') &&
        uri.host == 'login-callback') {
      return true;
    }
    if (uri.host == 'vspapp.online' && uri.path.contains('callback')) {
      return true;
    }
    if (uri.fragment.contains('access_token') ||
        uri.fragment.contains('refresh_token') ||
        uri.fragment.contains('error') ||
        uri.queryParameters.containsKey('code') ||
        uri.queryParameters.containsKey('error') ||
        uri.path.contains('login-callback')) {
      return true;
    }
    return false;
  }

  /// تحليل وفحص أمان المعرف داخل الرابط العميق
  static ParsedDeepLink? parse(Uri uri) {
    try {
      String? type;
      String? id;

      if (uri.scheme == 'vspapp' || uri.scheme == 'io.supabase.fluttervsp') {
        type = uri.host.toLowerCase();
        if (uri.pathSegments.isNotEmpty) {
          id = uri.pathSegments.first;
        } else {
          id = uri.queryParameters['id'] ?? '';
        }
      } else if (uri.host == 'vspapp.online') {
        if (uri.pathSegments.length >= 2) {
          type = uri.pathSegments[0].toLowerCase();
          id = uri.pathSegments[1];
        } else if (uri.pathSegments.length == 1) {
          type = uri.pathSegments[0].toLowerCase();
          id = uri.queryParameters['id'] ?? '';
        }
      }

      if (type != null && _validTypes.contains(type)) {
        if (id != null && id.isNotEmpty && !_validIdRegex.hasMatch(id)) {
          return null;
        }
        return ParsedDeepLink(type: type, id: id ?? '', queryParams: uri.queryParameters);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
