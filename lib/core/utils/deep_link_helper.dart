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
    if (type == 'collective') return '/collective/$id';
    final invite = queryParams?['invite'] == '1' && type == 'match';
    return '/$type/$id${invite ? '?invite=1' : ''}';
  }
}

/// معالج ومحلل الروابط العميقة الموحد لتطبيق VSP
class DeepLinkHelper {
  static final RegExp _validIdRegex = RegExp(r'^[a-zA-Z0-9_-]{1,128}
  static const Set<String> _validTypes = {
    'match',
    'collective',
    'team',
    'championship',
    'booking',
    'stadium',
    'payment-complete',
    'open',
  };
  static const Set<String> _idOptionalTypes = {'payment-complete', 'open'};
  static const Set<String> _webHosts = {'vspapp.online', 'vsp.app'};
  static const Set<String> _callbackHosts = {
    'login-callback', 'reset-callback',
  };

  static bool _isCustomScheme(Uri uri) =>
      uri.scheme == 'vspapp' || uri.scheme == 'io.supabase.fluttervsp';

  static bool _isTrustedWebUrl(Uri uri) =>
      uri.scheme == 'https' &&
      _webHosts.contains(uri.host) &&
      uri.userInfo.isEmpty &&
      (!uri.hasPort || uri.port == 443);


  /// التحقق من روابط OAuth العائدة من مزودي الخدمة (Google / Apple)
  /// Recognize only registered Supabase mobile callbacks or verified HTTPS
  /// callback paths. The presence of arbitrary \`code\` or token text in an
  /// untrusted URL is NOT proof of an OAuth callback.
  static bool isOAuthCallback(Uri uri) {
    if (uri.userInfo.isNotEmpty) return false;
    if (_isCustomScheme(uri)) {
      return !uri.hasPort &&
          _callbackHosts.contains(uri.host) &&
          (uri.path.isEmpty || uri.path == '/');
    }
    if (!_isTrustedWebUrl(uri) || uri.host != 'vspapp.online') {
      return false;
    }
    const callbackPaths = {
      '/', '/auth/callback', '/callback',
      '/login-callback', '/reset-callback',
    };
    if (!callbackPaths.contains(uri.path.isEmpty ? '/' : uri.path)) {
      return false;
    }
    final query = uri.queryParameters;
    final hasQueryData = (query['code']?.isNotEmpty ?? false) ||
        (query['error']?.isNotEmpty ?? false);
    final hasFragmentData = RegExp(
      r'(^|&)(access_token|refresh_token|error)=',
    ).hasMatch(uri.fragment);
    return hasQueryData || hasFragmentData;
  }

  /// تحليل وفحص أمان المعرف داخل الرابط العميق
  static ParsedDeepLink? parse(Uri uri) {
    try {
      final ids = uri.queryParametersAll['id'];
      if (uri.userInfo.isNotEmpty || uri.fragment.isNotEmpty ||
          (ids != null && ids.length != 1)) {
        return null;
      }
      String? type;
      String? id;
      if (_isCustomScheme(uri)) {
        if (uri.hasPort) return null;
        type = uri.host.toLowerCase();
        final segments = uri.pathSegments
            .where((part) => part.isNotEmpty).toList();
        if (segments.length > 1) return null;
        id = segments.isNotEmpty
            ? segments.single
            : (uri.queryParameters['id'] ?? '');
      } else if (_isTrustedWebUrl(uri)) {
        final segments = uri.pathSegments
            .where((part) => part.isNotEmpty).toList();
        if (segments.isEmpty || segments.length > 2) return null;
        type = segments[0].toLowerCase();
        id = segments.length == 2
            ? segments[1]
            : (uri.queryParameters['id'] ?? '');
      } else {
        return null;
      }
      if (!_validTypes.contains(type)) return null;
      if (id == null || id.isEmpty) {
        if (!_idOptionalTypes.contains(type)) return null;
        id = '';
      } else if (!_validIdRegex.hasMatch(id)) {
        return null;
      }
      return ParsedDeepLink(
        type: type!,
        id: id,
        queryParams: uri.queryParameters,
      );
    } catch (_) {
      return null;
    }
  }

}
