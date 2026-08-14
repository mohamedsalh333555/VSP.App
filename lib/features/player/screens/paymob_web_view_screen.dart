import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';

class PaymobWebViewScreen extends StatefulWidget {
  final String initialUrl;
  final String title;

  const PaymobWebViewScreen({
    super.key,
    required this.initialUrl,
    this.title = 'سداد الحجز الآمن 💳',
  });

  @override
  State<PaymobWebViewScreen> createState() => _PaymobWebViewScreenState();
}

class _PaymobWebViewScreenState extends State<PaymobWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  int _loadingProgress = 0;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(VSPColors.background)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                _loadingProgress = progress;
                if (progress >= 90) _isLoading = false;
              });
            }
          },
          onPageStarted: (String url) {
            if (mounted) setState(() => _isLoading = true);
            _checkCallbackUrl(url);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => _isLoading = false);
            _checkCallbackUrl(url);
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('Paymob WebView Error (${error.errorCode}): ${error.description}');
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            _checkCallbackUrl(url);
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  void _checkCallbackUrl(String url) {
    final lowerUrl = url.toLowerCase();
    // Paymob callback redirect parameters
    if (lowerUrl.contains('success=true') || lowerUrl.contains('txn_response_code=approved')) {
      HapticFeedback.heavyImpact();
      if (mounted) Navigator.pop(context, true);
    } else if (lowerUrl.contains('success=false') || lowerUrl.contains('txn_response_code=declined')) {
      HapticFeedback.vibrate();
      if (mounted) Navigator.pop(context, false);
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
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Iconsax.close_circle_copy, color: Colors.white),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context, false);
          },
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Iconsax.security_card_copy, color: VSPColors.accent, size: 20),
            const SizedBox(width: 8),
            Text(
              isArabic ? 'بوابة الدفع الإلكتروني' : 'Secure Checkout',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: _loadingProgress > 0 ? _loadingProgress / 100 : null,
                backgroundColor: VSPColors.surfaceAlt,
                color: VSPColors.accent,
                minHeight: 3,
              ),
            ),
        ],
      ),
    );
  }
}
