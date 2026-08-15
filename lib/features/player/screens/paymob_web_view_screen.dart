import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
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
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is AndroidWebViewPlatform) {
      params = AndroidWebViewControllerCreationParams();
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller = WebViewController.fromPlatformCreationParams(params);

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(VSPColors.background)
      ..setUserAgent('Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36')
      ..addJavaScriptChannel(
        'FlutterConsole',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('📟 [Paymob Page Console]: ${message.message}');
        },
      )
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
            debugPrint('🌐 [Paymob WebView PageStarted]: $url');
            if (mounted) setState(() => _isLoading = true);
            _checkCallbackUrl(url);
          },
          onPageFinished: (String url) async {
            debugPrint('✅ [Paymob WebView PageFinished]: $url');
            if (mounted) setState(() => _isLoading = false);
            _checkCallbackUrl(url);

            // Inject JS error handler & window.open interceptor
            try {
              await controller.runJavaScript('''
                window.onerror = function(msg, url, line) {
                  if (window.FlutterConsole) {
                    FlutterConsole.postMessage("JS ERROR: " + msg + " at " + url + ":" + line);
                  }
                };
                window.open = function(url) {
                  if (window.FlutterConsole) {
                    FlutterConsole.postMessage("WINDOW.OPEN INTERCEPTED: " + url);
                  }
                  if (url) {
                    window.location.href = url;
                  }
                  return {
                    focus: function() {},
                    blur: function() {},
                    close: function() {},
                    postMessage: function() {}
                  };
                };
              ''');
            } catch (e) {
              debugPrint('Notice injecting JS: $e');
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('🚨 [Paymob WebView RESOURCE ERROR]: code=${error.errorCode} desc=${error.description} url=${error.url} isMainFrame=${error.isForMainFrame}');
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            debugPrint('➡️ [Paymob WebView NavRequest]: $url');
            _checkCallbackUrl(url);
            return NavigationDecision.navigate;
          },
        ),
      );

    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      final androidController = controller.platform as AndroidWebViewController;
      androidController.setOnShowFileSelector((params) async => []);
    }

    controller.loadRequest(Uri.parse(widget.initialUrl));
    _controller = controller;
  }

  bool _isPopped = false;

  void _checkCallbackUrl(String url) {
    if (_isPopped) return;

    final lowerUrl = url.toLowerCase();
    
    // ✅ التقاط حالات نجاح Paymob الصريحة فقط (تجاهل كلمة callback الظاهرة في روابط الصفحة الأولى)
    final isExplicitSuccess = (lowerUrl.contains('success=true') || 
            lowerUrl.contains('txn_response_code=approved') || 
            lowerUrl.contains('txn_response_code=0') ||
            lowerUrl.contains('approved=true')) &&
        !lowerUrl.contains('success=false') &&
        !lowerUrl.contains('pending=true');

    final isExplicitFailure = lowerUrl.contains('success=false') || 
        lowerUrl.contains('txn_response_code=declined') || 
        lowerUrl.contains('authentication_not_supported');

    if (isExplicitSuccess) {
      _isPopped = true;
      HapticFeedback.heavyImpact();
      if (mounted) Navigator.pop(context, true);
    } else if (isExplicitFailure) {
      _isPopped = true;
      HapticFeedback.vibrate();
      if (lowerUrl.contains('authentication_not_supported')) {
        debugPrint('⚠️ Paymob returned AUTHENTICATION_NOT_SUPPORTED for card pan.');
      }
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
