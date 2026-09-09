import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../core/repositories/tournament_repository.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/repositories/booking_repository.dart';
import '../../../data/models.dart';
import '../widgets/payment/paymob_callback_url_parser.dart';
import '../widgets/payment/paymob_still_waiting_dialog.dart';
import '../widgets/payment/paymob_web_fallback_view.dart';

class PaymobWebViewScreen extends StatefulWidget {
 final String initialUrl;
 final String title;
 final String? bookingId;

 const PaymobWebViewScreen({
 super.key,
 required this.initialUrl,
 this.title = 'سداد الحجز الآمن ',
 this.bookingId,
 });

 @override
 State<PaymobWebViewScreen> createState() => _PaymobWebViewScreenState();
}

class _PaymobWebViewScreenState extends State<PaymobWebViewScreen> {
 WebViewController? _controller;
 bool _isLoading = true;
 int _loadingProgress = 0;
 bool _isPopped = false;

 Timer? _initialTimeoutTimer;
 Timer? _pollingTimer;
 late final DateTime _sessionStartTime;
 int _nextDialogThresholdSeconds = 180; // 3 minutes total ceiling from start

 @override
 void initState() {
 super.initState();
 _sessionStartTime = DateTime.now();
 if (kIsWeb) {
 WidgetsBinding.instance.addPostFrameCallback((_) {
 _launchInWebBrowser(widget.initialUrl);
 });
 _startInitial90sTimer();
 } else {
 _initWebView();
 _startInitial90sTimer();
 }
 }

 Future<void> _launchInWebBrowser(String url) async {
 try {
 final uri = Uri.tryParse(url);
 if (uri != null) {
 await launchUrl(uri, mode: LaunchMode.externalApplication);
 }
 } catch (e) {
 debugPrint('Error launching web URL: $e');
 }
 }

 void _cancelAllTimers() {
 _initialTimeoutTimer?.cancel();
 _initialTimeoutTimer = null;
 _pollingTimer?.cancel();
 _pollingTimer = null;
 }

 void _popSuccess() {
 if (_isPopped) return;
 _isPopped = true;
 _cancelAllTimers();
 HapticFeedback.heavyImpact();
 if (mounted) Navigator.pop(context, true);
 }

 void _popFailure() {
 if (_isPopped) return;
 _isPopped = true;
 _cancelAllTimers();
 HapticFeedback.vibrate();
 if (mounted) Navigator.pop(context, false);
 }

 void _startInitial90sTimer() {
 _initialTimeoutTimer?.cancel();
 _initialTimeoutTimer = Timer(const Duration(seconds: 90), _onInitialTimeoutFired);
 }

 Future<void> _onInitialTimeoutFired() async {
 if (!mounted || _isPopped) return;

 final isConfirmed = await _checkBookingStatusDb();
 if (!mounted || _isPopped) return;

 if (isConfirmed) {
 _popSuccess();
 return;
 }

 _showStillWaitingDialog();
 }

  Future<bool> _checkBookingStatusDb() async {
    if (widget.bookingId == null ||
        widget.bookingId!.isEmpty ||
        widget.bookingId!.startsWith('mock_')) {
      return false;
    }
    try {
      if (widget.bookingId!.startsWith('TOURN_1V1_')) {
        return await TournamentRepository().is1v1OrderPaid(widget.bookingId!);
      }

      final booking = await SupabaseBookingRepository().getBookingById(widget.bookingId!);
      if (booking != null &&
          (booking.status == BookingStatus.confirmed ||
              booking.isPaid ||
              booking.paymentStatus == 'paid')) {
        return true;
      }
    } catch (e) {
      debugPrint('Notice checking booking DB status: $e');
    }
    return false;
  }

 void _start10sPolling() {
 _pollingTimer?.cancel();
 _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) => _pollBookingStatus());
 }

 Future<void> _pollBookingStatus() async {
 if (!mounted || _isPopped) {
 _cancelAllTimers();
 return;
 }

 final isConfirmed = await _checkBookingStatusDb();
 if (!mounted || _isPopped) return;

 if (isConfirmed) {
 _popSuccess();
 return;
 }

 // Check 3-minute total ceiling from session start
 final elapsedSeconds = DateTime.now().difference(_sessionStartTime).inSeconds;
 if (elapsedSeconds >= _nextDialogThresholdSeconds) {
 _pollingTimer?.cancel();
 _pollingTimer = null;
 _showStillWaitingDialog();
 }
 }

  Future<void> _showStillWaitingDialog() async {
    _pollingTimer?.cancel();
    _pollingTimer = null;

    final result = await PaymobStillWaitingDialog.show(context);
    if (!mounted || _isPopped) return;

    if (result == true) {
      _popFailure();
    } else {
      final elapsed = DateTime.now().difference(_sessionStartTime).inSeconds;
      _nextDialogThresholdSeconds = ((elapsed ~/ 180) + 1) * 180;
      _start10sPolling();
    }
  }

 @override
 void dispose() {
 _cancelAllTimers();
 super.dispose();
 }

 void _initWebView() {
 final WebViewController controller = WebViewController();
 controller
 ..setJavaScriptMode(JavaScriptMode.unrestricted)
 ..setBackgroundColor(VSPColors.background)
 ..setUserAgent('Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36')
 ..addJavaScriptChannel(
 'FlutterConsole',
 onMessageReceived: (JavaScriptMessage message) {
 debugPrint(' [Paymob Page Console]: ${message.message}');
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
 if (kDebugMode) {
 final uri = Uri.tryParse(url);
 final cleanUrl = uri != null ? '${uri.scheme}://${uri.host}${uri.path}' : '[URL]';
 debugPrint(' [Paymob WebView PageStarted]: $cleanUrl');
 }
 if (mounted) setState(() => _isLoading = true);
 _checkCallbackUrl(url);
 },
 onPageFinished: (String url) async {
 if (kDebugMode) {
 final uri = Uri.tryParse(url);
 final cleanUrl = uri != null ? '${uri.scheme}://${uri.host}${uri.path}' : '[URL]';
 debugPrint(' [Paymob WebView PageFinished]: $cleanUrl');
 }
 if (mounted) setState(() => _isLoading = false);
 _checkCallbackUrl(url);

  // SEC-FIX: لا تحقن أكواد JS إلا إذا كان النطاق يتبع بوابة الدفع أو البنك الآمن
  final isSafeDomain = PaymobCallbackUrlParser.isSafeDomain(url);

 if (isSafeDomain) {
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
 }
 },
 onWebResourceError: (WebResourceError error) {
 if (kDebugMode) {
 debugPrint(' [Paymob WebView RESOURCE ERROR]: code=${error.errorCode} desc=${error.description}');
 }
 },
 onNavigationRequest: (NavigationRequest request) {
 final url = request.url;
 if (kDebugMode) {
 final uri = Uri.tryParse(url);
 final cleanUrl = uri != null ? '${uri.scheme}://${uri.host}${uri.path}' : '[URL]';
 debugPrint(' [Paymob WebView NavRequest]: $cleanUrl');
 }
 _checkCallbackUrl(url);
 return NavigationDecision.navigate;
 },
 ),
 );

 controller.loadRequest(Uri.parse(widget.initialUrl));
 _controller = controller;
 }

  void _checkCallbackUrl(String url) {
    if (_isPopped) return;

    final status = PaymobCallbackUrlParser.evaluateUrl(url);
    if (status == PaymobCallbackStatus.success) {
      _popSuccess();
    } else if (status == PaymobCallbackStatus.failure) {
      if (url.toLowerCase().contains('authentication_not_supported')) {
        debugPrint('[Paymob] returned AUTHENTICATION_NOT_SUPPORTED for card pan.');
      }
      _popFailure();
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
 _popFailure();
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
 body: kIsWeb || _controller == null
 ? PaymobWebFallbackView(
     onReopen: () => _launchInWebBrowser(widget.initialUrl),
     onManualVerify: () async {
       final isConfirmed = await _checkBookingStatusDb();
       if (isConfirmed) {
         _popSuccess();
       } else {
         _showStillWaitingDialog();
       }
     },
   )
 : Stack(
 children: [
 WebViewWidget(controller: _controller!),
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
