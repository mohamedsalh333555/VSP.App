import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/repositories/booking_repository.dart';
import '../../../data/models.dart';

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

 final isArabic = Localizations.localeOf(context).languageCode == 'ar';
 final result = await showDialog<bool>(
 context: context,
 barrierDismissible: false,
 builder: (ctx) => AlertDialog(
 backgroundColor: VSPColors.surface,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
 title: Row(
 children: [
 const Icon(Iconsax.timer_1_copy, color: VSPColors.accent, size: 22),
 const SizedBox(width: 10),
 Expanded(
 child: Text(
 isArabic ? 'الدفع يستغرق وقتاً أطول من المتوقع ' : 'Payment Taking Longer ',
 style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
 ),
 ),
 ],
 ),
 content: Text(
 isArabic
 ? 'عملية التأكيد مع بوابة الدفع تستغرق وقتاً إضافياً. يمكنك مواصلة الانتظار (سنتحقق تلقائياً كل 10 ثوانٍ) أو الإلغاء ورجوع لشاشة الحجز.'
 : 'Payment confirmation is taking longer than expected. You can keep waiting (we will auto-check every 10s) or cancel.',
 style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, height: 1.5),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(ctx, false), // Keep waiting
 child: Text(
 isArabic ? 'استمرار الانتظار' : 'Keep Waiting',
 style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold),
 ),
 ),
 ElevatedButton(
 onPressed: () => Navigator.pop(ctx, true), // Cancel & pop
 style: ElevatedButton.styleFrom(
 backgroundColor: VSPColors.error,
 foregroundColor: Colors.white,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
 ),
 child: Text(isArabic ? 'إلغاء' : 'Cancel'),
 ),
 ],
 ),
 );

 if (!mounted || _isPopped) return;

 if (result == true) {
 _popFailure();
 } else {
 // Set next 3-minute ceiling threshold (e.g. 180s, 360s, 540s...)
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
 debugPrint(' [Paymob WebView PageStarted]: $url');
 if (mounted) setState(() => _isLoading = true);
 _checkCallbackUrl(url);
 },
 onPageFinished: (String url) async {
 debugPrint(' [Paymob WebView PageFinished]: $url');
 if (mounted) setState(() => _isLoading = false);
 _checkCallbackUrl(url);

 // SEC-FIX: لا تحقن أكواد JS إلا إذا كان النطاق يتبع بوابة الدفع أو البنك الآمن
 final lowerUrl = url.toLowerCase();
 final isSafeDomain = lowerUrl.contains('paymob.com') || 
 lowerUrl.contains('nbe.com.eg') || 
 lowerUrl.contains('banquemisr.com') || 
 lowerUrl.contains('cibeg.com');

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
 debugPrint(' [Paymob WebView RESOURCE ERROR]: code=${error.errorCode} desc=${error.description} url=${error.url} isMainFrame=${error.isForMainFrame}');
 },
 onNavigationRequest: (NavigationRequest request) {
 final url = request.url;
 debugPrint(' [Paymob WebView NavRequest]: $url');
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

 final lowerUrl = url.toLowerCase();
 
 // FIX: Ignore bank 3DS ACS domains (e.g. NBE, Banque Misr, CIB, MPGS, etc.)
 // to prevent premature false success/failure triggers during OTP input.
 final isBank3DsDomain = lowerUrl.contains('nbe.com.eg') ||
 lowerUrl.contains('banquemisr.com') ||
 lowerUrl.contains('cibeg.com') ||
 lowerUrl.contains('mpgs') ||
 lowerUrl.contains('acs') ||
 lowerUrl.contains('3dsecure') ||
 lowerUrl.contains('cardholder');
 if (isBank3DsDomain) return;

 final isPaymobEndpoint = lowerUrl.contains('/post_pay') || 
 lowerUrl.contains('accept.paymob.com') || 
 lowerUrl.contains('paymob.com') ||
 lowerUrl.contains('vsp_payment_callback');

 // التقاط حالات نجاح Paymob الصريحة فقط
 final isExplicitSuccess = isPaymobEndpoint &&
 (lowerUrl.contains('success=true') || 
 lowerUrl.contains('txn_response_code=approved') || 
 lowerUrl.contains('txn_response_code=00') ||
 lowerUrl.contains('txn_response_code=0') ||
 lowerUrl.contains('approved=true')) &&
 !lowerUrl.contains('success=false') &&
 !lowerUrl.contains('pending=true');

 final isExplicitFailure = isPaymobEndpoint &&
 (lowerUrl.contains('success=false') || 
 lowerUrl.contains('txn_response_code=declined') || 
 lowerUrl.contains('authentication_not_supported'));

 if (isExplicitSuccess) {
 _popSuccess();
 } else if (isExplicitFailure) {
 if (lowerUrl.contains('authentication_not_supported')) {
 debugPrint(' Paymob returned AUTHENTICATION_NOT_SUPPORTED for card pan.');
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
 ? Center(
 child: Padding(
 padding: const EdgeInsets.all(VSPSpacing.xl),
 child: Column(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 const Icon(Iconsax.card_pos_copy, size: 64, color: VSPColors.accent),
 const SizedBox(height: VSPSpacing.lg),
 Text(
 isArabic ? 'جاري فتح بوابة الدفع الآمنة...' : 'Opening secure payment gateway...',
 style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
 textAlign: TextAlign.center,
 ),
 const SizedBox(height: VSPSpacing.md),
 Text(
 isArabic
 ? 'يرجى إتمام عملية الدفع في النافذة الجديدة، ثم العودة للتطبيق.'
 : 'Please complete the payment in the new browser tab, then return here.',
 style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
 textAlign: TextAlign.center,
 ),
 const SizedBox(height: VSPSpacing.xl),
 ElevatedButton.icon(
 onPressed: () => _launchInWebBrowser(widget.initialUrl),
 icon: const Icon(Iconsax.export_3_copy, size: 18),
 label: Text(isArabic ? 'إعادة فتح نافذة الدفع' : 'Re-open Payment Window'),
 style: ElevatedButton.styleFrom(
 backgroundColor: VSPColors.accent,
 foregroundColor: Colors.black,
 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
 ),
 ),
 const SizedBox(height: 16),
 TextButton.icon(
 onPressed: () async {
 final isConfirmed = await _checkBookingStatusDb();
 if (isConfirmed) {
 _popSuccess();
 } else {
 _showStillWaitingDialog();
 }
 },
 icon: const Icon(Icons.refresh, size: 16, color: VSPColors.accent),
 label: Text(isArabic ? 'التحقق من الدفع يدويًا' : 'Verify Payment Status', style: const TextStyle(color: VSPColors.accent)),
 ),
 ],
 ),
 ),
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
