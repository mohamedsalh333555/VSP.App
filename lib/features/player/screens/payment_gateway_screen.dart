import 'dart:async';
import '../../../core/repositories/booking_repository.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../data/models.dart';
import 'booking_success_screen.dart';
import 'paymob_web_view_screen.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/paymob_service.dart';
import '../../../core/utils/vsp_feedback.dart';

class PaymentGatewayScreen extends StatefulWidget {
 final BookingDraft bookingDraft;
 final bool forceFullPayment;
 final bool isTournamentPayment;
 final String? existingBookingId;
 final Booking? existingBooking;

 const PaymentGatewayScreen({
 super.key,
 required this.bookingDraft,
 this.forceFullPayment = false,
 this.isTournamentPayment = false,
 this.existingBookingId,
 this.existingBooking,
 });

 @override
 State<PaymentGatewayScreen> createState() => _PaymentGatewayScreenState();
}

class _PaymentGatewayScreenState extends State<PaymentGatewayScreen> {
 bool _isLoading = false;
 bool _isAwaitingWebhook = false;
 Booking? _booking;
 StreamSubscription? _bookingSubscription;
 Timer? _webhookTimeoutTimer;
 Timer? _fallbackPollingTimer;
 Timer? _countdownTimer;
 int _remainingSeconds = 300; // 5 minutes atomic hold timer
 bool _paymentCompleted = false;
 String _selectedMethod = 'card'; // 'card', 'wallet'

 @override
 void initState() {
 super.initState();
 _startCountdownTimer();
 _createPendingBooking();
 }

 void _startCountdownTimer() {
 _countdownTimer?.cancel();
 _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
 if (!mounted) return;
 if (_remainingSeconds > 0) {
 setState(() => _remainingSeconds--);
 } else {
 _countdownTimer?.cancel();
 if (!_paymentCompleted && _booking != null) {
 if (!mounted) return;
    if (!mounted) return;
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
 final userId = authProvider.currentUser?.uid;
 if (userId != null && !widget.isTournamentPayment && widget.existingBookingId == null) {
 await _cleanupStalePendingBookings(userId);
 }
 if (mounted) {
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';
 VSPFeedback.showError(context, isArabic ? 'انتهت مهلة حجز الوقت (5 دقائق).' : 'Booking reservation timeout (5 mins).');
 Navigator.pop(context);
 }
 }
 }
 });
 }

 String _formatCountdown(int totalSeconds) {
 final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
 final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
 return '$minutes:$seconds';
 }

 @override
 void dispose() {
 _countdownTimer?.cancel();
 _webhookTimeoutTimer?.cancel();
 _fallbackPollingTimer?.cancel();
 _bookingSubscription?.cancel();
 _bookingSubscription = null;
 super.dispose();
 }

  /// إنشاء الحجز بحالة pending و is_paid = false فقط أو استئناف حجز قائم
  Future<void> _createPendingBooking() async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    final userId = authProvider.currentUser?.uid;

    setState(() => _isLoading = true);

    if (widget.isTournamentPayment) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    // استئناف حجز قائم ممرر مسبقاً
    if (widget.existingBooking != null) {
      if (mounted) {
        setState(() {
          _booking = widget.existingBooking;
          _isLoading = false;
        });
        _initBookingRealtimeListener(widget.existingBooking!.id);
      }
      return;
    } else if (widget.existingBookingId != null) {
      final existing = await bookingProvider.getBookingById(widget.existingBookingId!);
      if (existing != null && mounted) {
        setState(() {
          _booking = existing;
          _isLoading = false;
        });
        _initBookingRealtimeListener(existing.id);
        return;
      }
    }
    
    if (userId != null) {
      try {
        // تنظيف أي حجوزات pending غير مدفوعة للمستخدم على نفس الملعب قبل الإنشاء
        await _cleanupStalePendingBookings(userId);

        if (!mounted) return;
        final draft = widget.bookingDraft.copyWith(
          paymentStatus: 'pending',
          paymentMethod: 'paymob',
          isPaid: false, // دائماً غير مدفوع في البداية
        );
        final booking = await bookingProvider.createBooking(draft, userId);
        if (booking != null) {
          if (mounted) {
            setState(() {
              _booking = booking;
              _isLoading = false;
            });
            _initBookingRealtimeListener(booking.id);
          }
        } else {
          if (mounted) {
            final isArabic = Localizations.localeOf(context).languageCode == 'ar';
            final errorMsg = bookingProvider.errorMessage ?? (isArabic ? 'تعذر إنشاء الحجز في قاعدة البيانات' : 'Failed to create booking in database');
            VSPFeedback.showError(context, errorMsg);
            Navigator.pop(context);
          }
        }
      } catch (e) {
        if (mounted) {
          final isArabic = Localizations.localeOf(context).languageCode == 'ar';
          VSPFeedback.showError(context, isArabic ? 'تعذر بدء عملية الحجز: $e' : 'Failed to initialize booking: $e');
          Navigator.pop(context);
        }
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

 Future<void> _cleanupStalePendingBookings(String userId) async {
    if (widget.isTournamentPayment) return;
    await SupabaseBookingRepository().cleanupStalePendingBookings(
      userId: userId,
      stadiumId: widget.bookingDraft.stadiumId,
    );
  }


  /// التسمع اللحظي الحصري: لا يتم الانتقال إلا عندما يغير الـ Webhook في السيرفر حالة الحجز
 void _initBookingRealtimeListener(String bookingId) {
 if (bookingId.startsWith('mock_')) return;
 _bookingSubscription?.cancel();
 _bookingSubscription = SupabaseBookingRepository()
        .streamBookingStatus(bookingId).listen((data) async {
 if (data.isNotEmpty) {
 final bookingData = data.first;
 final status = bookingData['status'] as String?;
 final paymentStatus = bookingData['payment_status'] as String?;

 // الانتقال المباشر يحدث فقط عند تعديل السيرفر للحالة
 if (status == 'confirmed' || paymentStatus == 'paid') {
 HapticFeedback.heavyImpact();
 if (mounted) {
 final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
 final updatedBooking = await bookingProvider.getBookingById(bookingId);
 if (updatedBooking != null && mounted) {
 _paymentCompleted = true;
 Navigator.pushReplacement(
 context,
 MaterialPageRoute(
 builder: (context) => BookingSuccessScreen(booking: updatedBooking),
 ),
 );
 }
 }
 }
 }
 }, onError: (err) {
 debugPrint('Real-time listener error: $err');
 });
 }

 void _startFallbackPollingTimer(String bookingId) {
 _fallbackPollingTimer?.cancel();
 _fallbackPollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
 if (!mounted || _paymentCompleted) {
 timer.cancel();
 return;
 }
 try {
 final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
 final booking = await bookingProvider.getBookingById(bookingId);
 if (booking != null && (booking.status == BookingStatus.confirmed || booking.isPaid)) {
 timer.cancel();
 _webhookTimeoutTimer?.cancel();
 _fallbackPollingTimer?.cancel();
 if (mounted && !_paymentCompleted) {
 _paymentCompleted = true;
 HapticFeedback.heavyImpact();
 Navigator.pushReplacement(
 context,
 MaterialPageRoute(
 builder: (context) => BookingSuccessScreen(booking: booking),
 ),
 );
 }
 }
 } catch (e) {
 debugPrint('Fallback polling notice: $e');
 }
 });
 }

 /// فتح بوابة Paymob أو استدعاء المحاكاة الآمنة بالسيرفر (RPC) في الاختبار
 Future<void> _startPaymobCheckout() async {
 if (_booking == null && !widget.isTournamentPayment) return;
 if (_isLoading || _isAwaitingWebhook) return;
 setState(() {
 _isLoading = true;
 _isAwaitingWebhook = true;
 });

 _webhookTimeoutTimer?.cancel();
 _webhookTimeoutTimer = Timer(const Duration(seconds: 90), () {
 if (mounted && _isAwaitingWebhook && !_paymentCompleted) {
 setState(() {
 _isAwaitingWebhook = false;
 _isLoading = false;
 });
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(
 isArabic
 ? 'لم يصل تأكيد الدفع الإلكتروني بعد. يمكنك المحاولة مجدداً أو اختيار وسيلة دفع أخرى.'
 : 'Webhook response timed out. You can retry or choose another method.',
 ),
 backgroundColor: VSPColors.error,
 ),
 );
 }
 });

 final auth = Provider.of<AuthProvider>(context, listen: false);
 final user = auth.currentUser;
 final userName = auth.userModel?.name ?? 'Player';
 final userPhone = auth.userModel?.phone ?? '';
 final userEmail = user?.email ?? 'player@vsp.app';

 final baseAmount = widget.bookingDraft.needsDeposit && widget.bookingDraft.depositPaid > 0 
 ? widget.bookingDraft.depositPaid 
 : widget.bookingDraft.totalPrice;
 // DUP-FIX: استخدام الدالة المركزية لحساب المبلغ الإجمالي مع العمولة
 final totalAmount = PaymobService.calculateTotalAmount(baseAmount);

    final selectedIntegrationId = _selectedMethod == 'wallet' 
        ? AppConfig.paymobWalletIntegrationId 
        : AppConfig.paymobCardIntegrationId;

    final paymentRefId = widget.isTournamentPayment
        ? 'TOURN_${widget.bookingDraft.playerTeamId ?? 'TEAM'}_${DateTime.now().millisecondsSinceEpoch}'
        : (_booking?.id ?? 'BK_${DateTime.now().millisecondsSinceEpoch}');

    final paymobUrl = await PaymobService.getCheckoutUrlFromServer(
      amountInEgp: totalAmount,
      bookingId: paymentRefId,
      userEmail: userEmail,
      userName: userName,
      userPhone: userPhone,
      integrationId: selectedIntegrationId,
      isTournamentPayment: widget.isTournamentPayment,
    );

    final isArabic = mounted ? Localizations.localeOf(context).languageCode == 'ar' : true;

    if (paymobUrl != null && paymobUrl.isNotEmpty) {
      try {
        if (!mounted) return;
        setState(() {
          _remainingSeconds += 300; // 5 minutes additional grace period for 3DS OTP entry
        });
        final isPaidSuccess = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => PaymobWebViewScreen(
              initialUrl: paymobUrl,
              title: isArabic ? 'سداد الحجز بالفيزا ' : 'Pay via Card ',
              bookingId: _booking?.id,
            ),
          ),
        );

        if (mounted && (isPaidSuccess == true)) {
          if (widget.isTournamentPayment) {
            _paymentCompleted = true;
            _countdownTimer?.cancel();
            Navigator.pop(context, true);
            return;
          }

          setState(() {
            _isAwaitingWebhook = true;
            _isLoading = true;
          });

          if (_booking != null) {
            final bookingId = _booking!.id;
            // Test Mode: تأكيد الحجز فورياً عبر stored procedure في حالة عدم رفع الويب هوك بالسيرفر
            await SupabaseBookingRepository().simulateTestPaymentWebhook(bookingId);
            _startFallbackPollingTimer(bookingId);
          }
        } else if (mounted && !_paymentCompleted) {
          setState(() {
            _isAwaitingWebhook = false;
            _isLoading = false;
          });
          VSPFeedback.showError(
            context,
            isArabic 
                ? 'لم تكتمل عملية الدفع بالبطاقة. يمكنك إعادة المحاولة أو اختيار وسيلة دفع أخرى.' 
                : 'Payment was not completed. You can try again or select another payment method.',
          );
        }
      } catch (e) {
        debugPrint('Paymob Launch notice: $e');
        if (mounted) {
          setState(() {
            _isAwaitingWebhook = false;
            _isLoading = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isAwaitingWebhook = false;
          _isLoading = false;
        });
        VSPFeedback.showError(
          context,
          isArabic 
              ? 'عذراً، متعذر الاتصال ببوابة Paymob حالياً. يرجى التأكد من مفتاح API في السيرفر.' 
              : 'Failed to obtain Paymob checkout token.',
        );
      }
    }
  }





 Future<void> _onCancelAndReleaseBooking(BuildContext dialogCtx) async {
 _countdownTimer?.cancel();
 _webhookTimeoutTimer?.cancel();
 _bookingSubscription?.cancel();
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.uid;

      if (!widget.isTournamentPayment) {
        if (_booking != null && !_booking!.id.startsWith('mock_')) {
          await SupabaseBookingRepository().releaseBookingLock(_booking!.id);
        }

        if (userId != null) {
          if (mounted) {
            final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
            bookingProvider.loadUserBookings(userId);
          }
        }
      }

 debugPrint(' Slot successfully released with status=cancelled/expired (Row preserved for audit safety).');
 } catch (e) {
 debugPrint(' Error releasing booking slot safely on Go Back: $e');
 }

 if (dialogCtx.mounted) Navigator.pop(dialogCtx, true);
 }

 @override
 Widget build(BuildContext context) {
 final l10n = AppLocalizations.of(context)!;
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';
 final isChampionship = widget.bookingDraft.stadiumName.contains('بطولة:');
 final hasDeposit = widget.bookingDraft.needsDeposit && widget.bookingDraft.depositPaid > 0;
 final amountToPay = hasDeposit ? widget.bookingDraft.depositPaid : widget.bookingDraft.totalPrice;

 final dialogTitle = isChampionship 
 ? (isArabic ? 'التراجع عن التسجيل في البطولة؟' : 'Cancel Championship Registration?')
 : (isArabic ? 'التراجع عن عملية الحجز؟' : 'Cancel Booking Checkout?');

 final dialogContent = isChampionship
 ? (isArabic ? 'إذا تراجعت الآن، لن يتم استكمال التسجيل في البطولة وسيمكنك العودة في أي وقت.' : 'If you go back now, your tournament registration will not be completed.')
 : (isArabic ? 'إذا تراجعت الآن، لن يتم خصم أي مبالغ وسيمكنك مراجعة حجزك وتعديله في أي وقت.' : 'If you go back now, no charges will be made and you can review your checkout anytime.');

 final dialogContinueText = isChampionship
 ? (isArabic ? 'متابعة التسجيل' : 'Continue Registration')
 : (isArabic ? 'متابعة الدفع' : 'Continue Checkout');

 return PopScope(
 canPop: false,
 onPopInvokedWithResult: (didPop, result) async {
 if (didPop) return;
 final cancel = await showDialog<bool>(
 context: context,
 builder: (ctx) => AlertDialog(
 backgroundColor: VSPColors.surface,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
 title: Text(dialogTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
 content: Text(dialogContent, style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, height: 1.5)),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(ctx, false), 
 child: Text(dialogContinueText, style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold))
 ),
 TextButton(
 onPressed: () => _onCancelAndReleaseBooking(ctx),
 child: Text(isArabic ? 'الرجوع للخلف' : 'Go Back', style: const TextStyle(color: VSPColors.error))
 )
 ]
 )
 );
 if (cancel == true && context.mounted) Navigator.pop(context);
 },
 child: Scaffold(
 backgroundColor: VSPColors.background,
 appBar: AppBar(
 backgroundColor: VSPColors.background,
 elevation: 0,
 leading: IconButton(
 icon: Icon(isArabic ? Iconsax.arrow_right_1_copy : Iconsax.arrow_left_2_copy, color: VSPColors.textPrimary, size: 20),
 onPressed: () async {
 final cancel = await showDialog<bool>(
 context: context,
 builder: (ctx) => AlertDialog(
 backgroundColor: VSPColors.surface,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
 title: Text(dialogTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
 content: Text(dialogContent, style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, height: 1.5)),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(ctx, false), 
 child: Text(dialogContinueText, style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold))
 ),
 TextButton(
 onPressed: () => _onCancelAndReleaseBooking(ctx),
 child: Text(isArabic ? 'الرجوع للخلف' : 'Go Back', style: const TextStyle(color: VSPColors.error))
 )
 ]
 )
 );
 if (cancel == true && context.mounted) Navigator.pop(context);
 },
 ),
 centerTitle: true,
 title: Text(
 isChampionship 
 ? (isArabic ? 'تأكيد اشتراك البطولة' : 'Championship Payment')
 : l10n.confirmBooking, 
 style: Theme.of(context).textTheme.displaySmall,
 ),
 ),
 body: Stack(
 children: [
 Positioned(
 top: -100, right: -100,
 child: Container(
 width: 300, height: 300,
 decoration: BoxDecoration(shape: BoxShape.circle, color: VSPColors.accent.withValues(alpha: 0.12)),
 child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(color: Colors.transparent)),
 ),
 ),
 SafeArea(
 child: SingleChildScrollView(
 physics: const BouncingScrollPhysics(),
 padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 // ⏱ 1. Hold Countdown Timer Banner (10-minute hold - only for pitch bookings)
 if (!isChampionship) ...[
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
 decoration: BoxDecoration(
 color: VSPColors.accent.withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(VSPRadius.lg),
 border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3), width: 1),
 ),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Row(
 children: [
 const Icon(Iconsax.timer_1_copy, color: VSPColors.accent, size: 18),
 const SizedBox(width: 8),
 Text(
 isArabic
 ? 'تم تثبيت الوقت لك مؤقتاً لمدة:'
 : 'Slot temporarily held for:',
 style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
 ),
 ],
 ),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
 decoration: BoxDecoration(
 color: VSPColors.accent,
 borderRadius: BorderRadius.circular(8),
 ),
 child: Text(
 _formatCountdown(_remainingSeconds),
 style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w900),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 16),
 ],

 // Amount Header Card
 Container(
 width: double.infinity,
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: const Color(0xFF18181B),
 borderRadius: BorderRadius.circular(VSPRadius.xl),
 border: Border.all(color: const Color(0xFF27272A), width: 1.2),
 ),
 child: Column(
 children: [
 Text(
 isChampionship
 ? (isArabic ? 'رسوم الاشتراك المطلوبة' : 'Entry Fee Required')
 : (hasDeposit 
 ? (isArabic ? 'عربون الحجز المطلوب أونلاين' : 'Upfront Deposit Required')
 : (isArabic ? 'المبلغ الإجمالي المطلوب' : 'Total Checkout Amount')),
 style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
 ),
 const SizedBox(height: 4),
 Text(
 '${amountToPay.toInt()} ${l10n.egCurrency}',
 style: const TextStyle(color: VSPColors.accent, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 0.5),
 ),
 ],
 ),
 ),

 const SizedBox(height: 16),

 // 2. Interactive Visual Payment Method Selector Cards
 Align(
 alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
 child: Text(
 isArabic ? 'اختر وسيلة الدفع المناسبة لك:' : 'Select Payment Method:',
 style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
 ),
 ),
 const SizedBox(height: 10),

 _buildPaymentMethodCard(
 id: 'wallet',
 title: isArabic ? 'محفظة إلكترونية' : 'Mobile Wallet',
 subtitle: isArabic ? 'فودافون كاش، أورنج، اتصالات، وي كاش ومحافظ البنوك' : 'Pay with Vodafone Cash, Orange, Etisalat & Bank Wallets',
 ),
 const SizedBox(height: 10),

 _buildPaymentMethodCard(
 id: 'card',
 title: isArabic ? 'بطاقة بنكية / كارت ميزة' : 'Bank Card / Meeza Card',
 subtitle: isArabic ? 'دفع آمن بالفيزا أو الماستركارد أو كارت ميزة' : 'Secure payment via Debit/Credit card',
 ),

 const SizedBox(height: 16),

 // Financial Breakdown Card
 Builder(
 builder: (context) {
 // DUP-FIX: استخدام الدالة المركزية
 final double serviceFee = PaymobService.calculateServiceFee(amountToPay);
 final double totalWithFees = PaymobService.calculateTotalAmount(amountToPay);

 final String displayStadiumName = (widget.bookingDraft.stadiumName.trim().isEmpty || widget.bookingDraft.stadiumName.trim() == 'Mo')
 ? (isArabic ? 'الملعب الرئيسي' : 'Main Pitch')
 : widget.bookingDraft.stadiumName;

 return Container(
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: VSPColors.surface,
 borderRadius: BorderRadius.circular(VSPRadius.xl),
 border: Border.all(color: VSPColors.divider),
 ),
 child: Column(
 children: [
 Row(
 children: [
 Icon(isChampionship ? Iconsax.cup_copy : Iconsax.building_copy, color: VSPColors.textSecondary, size: 16),
 const SizedBox(width: 10),
 Expanded(
 child: Text(
 displayStadiumName,
 style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
 ),
 ),
 ],
 ),
 const SizedBox(height: 8),
 Row(
 children: [
 const Icon(Iconsax.calendar_1_copy, color: VSPColors.textSecondary, size: 14),
 const SizedBox(width: 8),
 Text(
 DateFormat('yyyy/MM/dd').format(widget.bookingDraft.startTime),
 style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
 ),
 const SizedBox(width: 14),
 const Icon(Iconsax.clock_copy, color: VSPColors.textSecondary, size: 14),
 const SizedBox(width: 6),
 Text(
 DateFormat('hh:mm a').format(widget.bookingDraft.startTime),
 style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
 ),
 ],
 ),
 const Divider(color: VSPColors.divider, height: 20),
 _buildFeeRow(
 label: isChampionship
 ? (isArabic ? 'رسوم اشتراك البطولة' : 'Championship Entry Fee')
 : (hasDeposit 
 ? (isArabic ? 'عربون حجز الملعب' : 'Stadium Deposit') 
 : (isArabic ? 'إجمالي سعر حجز الملعب' : 'Stadium Total Price')),
 value: '${amountToPay.toInt()} ${isArabic ? 'ج.م' : 'EGP'}',
 isBold: false,
 ),
 const SizedBox(height: 6),
 _buildFeeRow(
 label: isArabic ? 'رسوم خدمات المنصة' : 'Platform Service Fee',
 value: '${serviceFee.toStringAsFixed(1)} ${isArabic ? 'ج.م' : 'EGP'}',
 isBold: false,
 onInfoTap: () => _showFeeTransparencyModal(context, isArabic),
 ),
 const SizedBox(height: 6),
 _buildFeeRow(
 label: isArabic ? 'إجمالي الدفع النهائي' : 'Total Checkout Amount',
 value: '${totalWithFees.toStringAsFixed(1)} ${isArabic ? 'ج.م' : 'EGP'}',
 isBold: true,
 ),
 if (hasDeposit && (widget.bookingDraft.totalPrice - amountToPay) > 0) ...[
 const SizedBox(height: 6),
 _buildFeeRow(
 label: isArabic ? 'المتبقي وسداده كاش بالملعب' : 'Remaining Pay at Pitch',
 value: '${(widget.bookingDraft.totalPrice - amountToPay).toInt()} ${isArabic ? 'ج.م' : 'EGP'}',
 ),
 ]
 ],
 ),
 );
 },
 ),
 const SizedBox(height: 20),
 if (_isLoading || _isAwaitingWebhook) ...[
 const SizedBox(height: 10),
 const CircularProgressIndicator(
 color: VSPColors.accent,
 strokeWidth: 3,
 ),
 const SizedBox(height: 16),
 Text(
 isArabic ? 'جاري إصدار وتأكيد تذكرة الحجز... ' : 'Issuing your booking ticket... ',
 style: const TextStyle(
 color: Colors.white,
 fontSize: 14,
 fontWeight: FontWeight.bold,
 ),
 ),
 const SizedBox(height: 6),
 Text(
 isArabic ? 'لحظات وننقلك لتفاصيل الحجز' : 'Redirecting in a moment...',
 style: const TextStyle(
 color: VSPColors.textSecondary,
 fontSize: 12,
 ),
 ),
 const SizedBox(height: 10),
 ] else ...[
 const Icon(Iconsax.lock_copy, color: VSPColors.textSecondary, size: 16),
 const SizedBox(height: 6),
 Text(
 isArabic ? 'جميع المعاملات تشفير آمن 100% ومحمية بواسطة بوابة الدفع المعتمدة.' : '100% secure encrypted payment via licensed Payment Gateway.',
 textAlign: TextAlign.center,
 style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12, height: 1.4),
 ),
 ],
 const SizedBox(height: 20),
 SizedBox(
 width: double.infinity,
 height: 54,
 child: PrimaryButton(
 text: isArabic ? 'الانتقال للدفع الآمن' : 'Proceed to Secure Checkout',
 isLoading: _isLoading || _isAwaitingWebhook,
 onPressed: (_booking == null && !widget.isTournamentPayment) ? null : _startPaymobCheckout,
 ),
 ),
 const SizedBox(height: 20),
 ],
 ),
 ),
 ),
 ],
 ),
 ),
 );
 }

  void _showFeeTransparencyModal(BuildContext context, bool isArabic) {
    showModalBottomSheet(
      context: context,
      backgroundColor: VSPColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: VSPColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: VSPColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Iconsax.info_circle_copy, color: VSPColors.accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isArabic ? 'شفافية رسوم خدمات المنصة' : 'Platform Service Fee Transparency',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                isArabic
                    ? 'رسوم خدمات المنصة تغطي تكاليف المعاملات البنكية المشفرة، والتثبيت الذري الفوري للمواعيد (منع التكرار)، وخدمة العملاء والدعم الفني المباشر على مدار الساعة.'
                    : 'The platform service fee covers end-to-end encrypted payment processing, instant atomic slot locking (zero double-bookings), and 24/7 priority customer support.',
                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13.5, height: 1.6),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VSPColors.accent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(isArabic ? 'فهمت ذلك' : 'Got it', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeeRow({
    required String label,
    required String value,
    bool isBold = false,
    VoidCallback? onInfoTap,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isBold ? Colors.white : VSPColors.textSecondary,
                fontSize: isBold ? 13 : 11,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (onInfoTap != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onInfoTap,
                child: const Icon(
                  Iconsax.info_circle_copy,
                  size: 14,
                  color: VSPColors.accent,
                ),
              ),
            ],
          ],
        ),
        Text(
          value,
          style: TextStyle(
            color: isBold ? VSPColors.accent : Colors.white,
            fontSize: isBold ? 14 : 11,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
          ),
        ),
      ],
    );
  }

 Widget _buildPaymentMethodCard({
 required String id,
 required String title,
 required String subtitle,
 }) {
 final bool isSelected = _selectedMethod == id;

 return InkWell(
 onTap: () => setState(() => _selectedMethod = id),
 borderRadius: BorderRadius.circular(VSPRadius.lg),
 child: AnimatedContainer(
 duration: const Duration(milliseconds: 180),
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
 decoration: BoxDecoration(
 color: isSelected ? VSPColors.accent.withValues(alpha: 0.08) : VSPColors.surface,
 borderRadius: BorderRadius.circular(VSPRadius.lg),
 border: Border.all(
 color: isSelected ? VSPColors.accent : VSPColors.divider,
 width: isSelected ? 1.5 : 0.8,
 ),
 ),
 child: Row(
 children: [
 AnimatedContainer(
 duration: const Duration(milliseconds: 180),
 width: 22,
 height: 22,
 decoration: BoxDecoration(
 shape: BoxShape.circle,
 color: isSelected ? VSPColors.accent : Colors.transparent,
 border: Border.all(
 color: isSelected ? VSPColors.accent : VSPColors.textSecondary.withValues(alpha: 0.5),
 width: 2,
 ),
 ),
 child: isSelected ? const Icon(Icons.check, color: Colors.black, size: 14) : null,
 ),
 const SizedBox(width: 14),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 title,
 style: TextStyle(
 color: isSelected ? VSPColors.accent : Colors.white,
 fontSize: 14,
 fontWeight: FontWeight.bold,
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 const SizedBox(height: 3),
 Text(
 subtitle,
 style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11.5),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 );
 }
}
