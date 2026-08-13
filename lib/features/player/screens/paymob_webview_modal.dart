import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';

class PaymobWebViewModal extends StatefulWidget {
  final String initialUrl;
  final VoidCallback onPaymentSuccess;

  const PaymobWebViewModal({
    super.key,
    required this.initialUrl,
    required this.onPaymentSuccess,
  });

  @override
  State<PaymobWebViewModal> createState() => _PaymobWebViewModalState();
}

class _PaymobWebViewModalState extends State<PaymobWebViewModal> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasSuccessTriggered = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(VSPColors.background)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) setState(() => _isLoading = true);
            _checkUrlForSuccess(url);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => _isLoading = false);
            _checkUrlForSuccess(url);
          },
          onNavigationRequest: (NavigationRequest request) {
            _checkUrlForSuccess(request.url);
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  void _checkUrlForSuccess(String url) {
    if (_hasSuccessTriggered) return;

    final lowerUrl = url.toLowerCase();
    final isSuccess = lowerUrl.contains('standalone') ||
        lowerUrl.contains('payment-callback') ||
        lowerUrl.contains('success=true') ||
        lowerUrl.contains('txn_response_code=00') ||
        lowerUrl.contains('approved=true');

    if (isSuccess) {
      _hasSuccessTriggered = true;
      debugPrint('🎉 Paymob Success URL Detected in In-App WebView: $url');
      widget.onPaymentSuccess();
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.close_circle_copy, color: Colors.white),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: Text(
          isArabic ? 'بوابة الدفع الآمنة 🔒' : 'Secure Checkout 🔒',
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: VSPColors.accent),
            ),
        ],
      ),
    );
  }
}
