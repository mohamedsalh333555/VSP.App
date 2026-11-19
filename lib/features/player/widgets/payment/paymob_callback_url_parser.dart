/// Represents the interpreted state of a Paymob callback redirect.
enum PaymobCallbackStatus {
  success,
  failure,
  pendingOrIgnored,
}

/// Evaluates URLs encountered during Paymob checkout session redirects.
class PaymobCallbackUrlParser {
  const PaymobCallbackUrlParser._();

  static const _trustedPaymentDomains = <String>[
    'paymob.com',
    'vspapp.online',
  ];

  static const _bank3dsDomains = <String>[
    'nbe.com.eg',
    'banquemisr.com',
    'cibeg.com',
  ];

  static bool _isDomainOrSubdomain(String host, String domain) {
    return host == domain || host.endsWith('.$domain');
  }

  static Uri? _httpUri(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      return null;
    }
    return uri;
  }

  static bool isSafeDomain(String url) {
    final uri = _httpUri(url);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    return _trustedPaymentDomains.any(
      (domain) => _isDomainOrSubdomain(host, domain),
    ) ||
        _bank3dsDomains.any(
          (domain) => _isDomainOrSubdomain(host, domain),
        );
  }

  static bool isBank3DsDomain(String url) {
    final uri = _httpUri(url);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    return _bank3dsDomains.any(
          (domain) => _isDomainOrSubdomain(host, domain),
        ) ||
        host.contains('mpgs') ||
        host.startsWith('acs.') ||
        host.contains('3dsecure') ||
        host.contains('cardholder') ||
        path.contains('3dsecure') ||
        path.contains('/3ds') ||
        path.contains('challenge');
  }

  static PaymobCallbackStatus evaluateUrl(String url) {
    final uri = _httpUri(url);
    if (uri == null) return PaymobCallbackStatus.pendingOrIgnored;

    final host = uri.host.toLowerCase();
    final isTrustedPaymentHost = _trustedPaymentDomains.any(
      (domain) => _isDomainOrSubdomain(host, domain),
    );
    if (!isTrustedPaymentHost || isBank3DsDomain(url)) {
      return PaymobCallbackStatus.pendingOrIgnored;
    }

    final path = uri.path.toLowerCase();
    final isPaymentEndpoint = path.contains('/post_pay') ||
        path.contains('payment-callback') ||
        path.contains('vsp_payment_callback') ||
        path.contains('/payment-status') ||
        host == 'accept.paymob.com' ||
        host == 'checkout.paymob.com';
    if (!isPaymentEndpoint) return PaymobCallbackStatus.pendingOrIgnored;

    final params = uri.queryParametersAll.map(
      (key, values) => MapEntry(key.toLowerCase(), values.map((v) => v.toLowerCase()).toList()),
    );
    String? firstValue(String key) {
      final values = params[key];
      return values == null || values.isEmpty ? null : values.first;
    }

    final success = firstValue('success');
    final approved = firstValue('approved');
    final responseCode = firstValue('txn_response_code');
    final status = firstValue('status') ?? firstValue('payment_status');

    final isExplicitFailure = success == 'false' ||
        approved == 'false' ||
        responseCode == 'declined' ||
        responseCode == 'authentication_not_supported' ||
        status == 'failed' ||
        status == 'declined' ||
        status == 'cancelled' ||
        status == 'canceled' ||
        status == 'error' ||
        status == 'rejected' ||
        firstValue('authentication_not_supported') == 'true';

    if (isExplicitFailure) return PaymobCallbackStatus.failure;

    final isExplicitSuccess = success == 'true' ||
        approved == 'true' ||
        responseCode == 'approved' ||
        responseCode == '00' ||
        responseCode == '0' ||
        status == 'success' ||
        status == 'paid' ||
        status == 'approved' ||
        status == 'completed';

    if (isExplicitSuccess) return PaymobCallbackStatus.success;

    return PaymobCallbackStatus.pendingOrIgnored;
  }
}
