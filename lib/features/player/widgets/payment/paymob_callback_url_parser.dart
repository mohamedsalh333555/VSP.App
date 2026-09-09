/// Represents the interpreted state of a Paymob callback redirect.
enum PaymobCallbackStatus {
  success,
  failure,
  pendingOrIgnored,
}

/// Evaluates URLs encountered during Paymob checkout session redirects.
class PaymobCallbackUrlParser {
  const PaymobCallbackUrlParser._();

  static bool isSafeDomain(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.contains('paymob.com') ||
        lowerUrl.contains('nbe.com.eg') ||
        lowerUrl.contains('banquemisr.com') ||
        lowerUrl.contains('cibeg.com');
  }

  static bool isBank3DsDomain(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.contains('nbe.com.eg') ||
        lowerUrl.contains('banquemisr.com') ||
        lowerUrl.contains('cibeg.com') ||
        lowerUrl.contains('mpgs') ||
        lowerUrl.contains('acs') ||
        lowerUrl.contains('3dsecure') ||
        lowerUrl.contains('cardholder');
  }

  static PaymobCallbackStatus evaluateUrl(String url) {
    if (isBank3DsDomain(url)) {
      return PaymobCallbackStatus.pendingOrIgnored;
    }

    final lowerUrl = url.toLowerCase();
    final isPaymobEndpoint = lowerUrl.contains('/post_pay') ||
        lowerUrl.contains('accept.paymob.com') ||
        lowerUrl.contains('checkout.paymob.com') ||
        lowerUrl.contains('paymob.com') ||
        lowerUrl.contains('vsp_payment_callback') ||
        lowerUrl.contains('/payment-status');

    if (!isPaymobEndpoint) return PaymobCallbackStatus.pendingOrIgnored;

    final isExplicitSuccess = (lowerUrl.contains('success=true') ||
            lowerUrl.contains('txn_response_code=approved') ||
            lowerUrl.contains('txn_response_code=00') ||
            lowerUrl.contains('txn_response_code=0') ||
            lowerUrl.contains('approved=true') ||
            lowerUrl.contains('/payment-status') ||
            lowerUrl.contains('standalone')) &&
        !lowerUrl.contains('success=false') &&
        !lowerUrl.contains('pending=true');

    if (isExplicitSuccess) {
      return PaymobCallbackStatus.success;
    }

    final isExplicitFailure = lowerUrl.contains('success=false') ||
        lowerUrl.contains('txn_response_code=declined') ||
        lowerUrl.contains('authentication_not_supported');

    if (isExplicitFailure) {
      return PaymobCallbackStatus.failure;
    }

    return PaymobCallbackStatus.pendingOrIgnored;
  }
}
