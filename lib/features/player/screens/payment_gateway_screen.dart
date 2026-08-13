import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../data/models.dart';
import 'booking_success_screen.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/paymob_service.dart';
import '../../../core/utils/vsp_feedback.dart';

class PaymentGatewayScreen extends StatefulWidget {
  final BookingDraft bookingDraft;
  final bool forceFullPayment;

  const PaymentGatewayScreen({
    super.key,
    required this.bookingDraft,
    this.forceFullPayment = false,
  });

  @override
  State<PaymentGatewayScreen> createState() => _PaymentGatewayScreenState();
}

class _PaymentGatewayScreenState extends State<PaymentGatewayScreen> {
  bool _isLoading = false;
  bool _isAwaitingWebhook = false;
  bool _isVerifyingManual = false;
  Booking? _booking;
  StreamSubscription? _bookingSubscription;
  Timer? _webhookTimeoutTimer;
  Timer? _countdownTimer;
  int _remainingSeconds = 600; // 10 minutes hold timer
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
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _countdownTimer?.cancel();
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
    _bookingSubscription?.cancel();
    _bookingSubscription = null;

    // 🛑 تنظيف الحجز المعلق غير المدفوع عند الخروج قبل تأكيد الـ Webhook
    if (!_paymentCompleted &&
        _booking != null &&
        _booking!.status == BookingStatus.pending &&
        !_booking!.isPaid) {
      final bId = _booking!.id;
      if (!bId.startsWith('mock_')) {
        Supabase.instance.client
            .from('bookings')
            .delete()
            .eq('id', bId)
            .then((_) => debugPrint('Pending booking cleaned up on exit.'))
            .catchError((e) => debugPrint('Error cleaning pending booking: $e'));
      }
    }

    super.dispose();
  }

  /// ⚡ الاستعلام المباشر والفوري عن حالة الدفع عند النقر على "تحقق الآن"
  /// ⚡ الاستعلام المباشر والفوري عن حالة الدفع عند النقر على "تحقق الآن"
  Future<void> _verifyPaymentStatusManual() async {
    if (_booking == null || _isVerifyingManual) return;
    setState(() => _isVerifyingManual = true);

    try {
      if (widget.bookingDraft.stadiumName.startsWith('بطولة:')) {
        HapticFeedback.heavyImpact();
        _paymentCompleted = true;
        if (mounted) {
          final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
          final champBooking = await bookingProvider.getBookingById(_booking!.id);
          if (champBooking != null && mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => BookingSuccessScreen(booking: champBooking),
              ),
            );
          } else if (mounted) {
            Navigator.pop(context, true);
          }
        }
        return;
      }

      final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
      final updatedBooking = await bookingProvider.getBookingById(_booking!.id);
      
      if (updatedBooking != null && (updatedBooking.status == BookingStatus.confirmed || updatedBooking.isPaid)) {
        HapticFeedback.heavyImpact();
        _paymentCompleted = true;
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => BookingSuccessScreen(booking: updatedBooking),
            ),
          );
        }
      } else if (kDebugMode && _booking != null) {
        // 🧪 في وضع التطوير والتجربة: تأكيد الحجز ونقل المستخدم لشاشة النجاح فوراً عند عودته من Paymob
        await Supabase.instance.client.from('bookings').update({
          'status': 'confirmed',
          'payment_status': 'paid',
          'is_paid': true,
        }).eq('id', _booking!.id);

        final confirmedBooking = await bookingProvider.getBookingById(_booking!.id);
        if (confirmedBooking != null && mounted) {
          _paymentCompleted = true;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => BookingSuccessScreen(booking: confirmedBooking),
            ),
          );
          return;
        }
      } else {
        if (mounted) {
          final isArabic = Localizations.localeOf(context).languageCode == 'ar';
          VSPFeedback.showWarning(
            context,
            isArabic
                ? 'لم يتم تأكيد السداد بعد، يرجى استكمال عملية التأكيد في البوابة.'
                : 'Payment not confirmed yet. Please complete checkout in gateway.',
          );
        }
      }
    } catch (e) {
      debugPrint('Manual payment verification error: $e');
    } finally {
      if (mounted) setState(() => _isVerifyingManual = false);
    }
  }

  /// إنشاء الحجز البدايات بحالة pending و is_paid = false فقط
  Future<void> _createPendingBooking() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.uid;
    if (userId != null) {
      try {
        if (widget.bookingDraft.stadiumName.startsWith('بطولة:')) {
          _booking = Booking(
            id: 'champ_${DateTime.now().millisecondsSinceEpoch}',
            stadiumId: widget.bookingDraft.stadiumId,
            stadiumName: widget.bookingDraft.stadiumName,
            stadiumImageUrl: widget.bookingDraft.stadiumImageUrl,
            ownerId: widget.bookingDraft.ownerId,
            startTime: widget.bookingDraft.startTime,
            endTime: widget.bookingDraft.endTime,
            bookingType: widget.bookingDraft.bookingType,
            playerTeamId: widget.bookingDraft.playerTeamId,
            playerTeamName: widget.bookingDraft.playerTeamName,
            isPrivate: false,
            rentBall: false,
            totalPrice: widget.bookingDraft.totalPrice,
            paymentMethod: 'paymob',
            status: BookingStatus.confirmed,
            createdByUserId: userId,
            createdAt: DateTime.now(),
          );
          if (mounted) setState(() => _isLoading = false);
          return;
        }

        // 🧹 تنظيف أي حجوزات pending غير مدفوعة للمستخدم على نفس الملعب قبل الإنشاء
        // هذا يمنع مشكلة double booking بسبب حجوزات شبح قديمة
        await _cleanupStalePendingBookings(userId);

        if (!mounted) return;
        final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
        final draft = widget.bookingDraft.copyWith(
          paymentStatus: 'pending',
          paymentMethod: 'paymob',
          isPaid: false, // 🔒 دائماً غير مدفوع في البداية
        );
        final booking = await bookingProvider.createBooking(draft, userId);
        if (booking != null) {
          if (mounted) {
            setState(() {
              _booking = booking;
              _isLoading = false;
            });
            // 📡 بدء التسمع اللحظي لتأكيد السيرفر فقط
            _initBookingRealtimeListener(booking.id);
          }
        } else {
          final err = bookingProvider.errorMessage;
          if (mounted) {
            setState(() => _isLoading = false);
            final isArabic = Localizations.localeOf(context).languageCode == 'ar';
            if (err != null && err.contains('double booking')) {
              _showDoubleBookingDialog();
            } else {
              _showCashLimitDialog(err ?? (isArabic ? 'فشل إنشاء الحجز' : 'Failed to create booking'));
            }
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showCashLimitDialog(e.toString());
        }
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 🧹 حذف الحجوزات الشبح المعلقة (pending) للمستخدم على نفس الملعب
  Future<void> _cleanupStalePendingBookings(String userId) async {
    try {
      await Supabase.instance.client
          .from('bookings')
          .delete()
          .eq('created_by_user_id', userId)
          .eq('stadium_id', widget.bookingDraft.stadiumId)
          .eq('status', 'pending');
      debugPrint('🧹 Stale pending bookings cleaned up for user: $userId');
    } catch (e) {
      debugPrint('⚠️ Cleanup stale bookings failed (non-blocking): $e');
    }
  }


  /// 📡 التسمع اللحظي الحصري: لا يتم الانتقال إلا عندما يغير الـ Webhook في السيرفر حالة الحجز
  void _initBookingRealtimeListener(String bookingId) {
    if (bookingId.startsWith('mock_')) return;
    _bookingSubscription?.cancel();
    _bookingSubscription = Supabase.instance.client
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('id', bookingId)
        .listen((data) async {
      if (data.isNotEmpty) {
        final bookingData = data.first;
        final status = bookingData['status'] as String?;
        final paymentStatus = bookingData['payment_status'] as String?;

        // 🔐 الانتقال المباشر يحدث فقط عند تعديل السيرفر للحالة
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

  /// 🚀 فتح بوابة Paymob أو استدعاء المحاكاة الآمنة بالسيرفر (RPC) في الاختبار
  Future<void> _startPaymobCheckout() async {
    if (_booking == null) return;
    setState(() => _isAwaitingWebhook = true);

    _webhookTimeoutTimer?.cancel();
    _webhookTimeoutTimer = Timer(const Duration(seconds: 90), () {
      if (mounted && _isAwaitingWebhook && !_paymentCompleted) {
        setState(() => _isAwaitingWebhook = false);
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
    final serviceFee = (baseAmount * 0.0475) + 3.0;
    final totalAmount = baseAmount + serviceFee;

    final selectedIntegrationId = _selectedMethod == 'wallet' 
        ? AppConfig.paymobWalletIntegrationId 
        : AppConfig.paymobCardIntegrationId;

    // 🚀 Generate authentic Paymob Payment Token
    final paymentToken = await PaymobService.getPaymentToken(
      amountInEgp: totalAmount,
      bookingId: _booking!.id,
      userEmail: userEmail,
      userName: userName,
      userPhone: userPhone,
      integrationId: selectedIntegrationId,
    );

    if (paymentToken != null && paymentToken.isNotEmpty) {
      String paymobUrl;
      if (_selectedMethod == 'wallet') {
        final walletUrl = await PaymobService.getWalletRedirectUrl(
          paymentToken: paymentToken,
          phone: userPhone,
        );
        paymobUrl = walletUrl ?? 'https://accept.paymob.com/api/acceptance/iframes/${AppConfig.paymobIframeId}?payment_token=$paymentToken';
      } else {
        paymobUrl = 'https://accept.paymob.com/api/acceptance/iframes/${AppConfig.paymobIframeId}?payment_token=$paymentToken';
      }

      final Uri uri = Uri.parse(paymobUrl);

      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
          if (mounted && !_paymentCompleted) {
            setState(() => _isAwaitingWebhook = false);
            _verifyPaymentStatusManual();
          }
        }
      } catch (e) {
        debugPrint('Paymob Launch notice: $e');
        if (mounted) {
          setState(() => _isAwaitingWebhook = false);
        }
      }
    } else {
      if (mounted) {
        setState(() => _isAwaitingWebhook = false);
        final isArabic = Localizations.localeOf(context).languageCode == 'ar';
        VSPFeedback.showError(
          context,
          isArabic 
              ? 'عذراً، متعذر الاتصال ببوابة Paymob حالياً. يرجى التأكد من مفتاح API في السيرفر.' 
              : 'Failed to obtain Paymob checkout token.',
        );
      }
    }
  }



  void _showCashLimitDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: VSPColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VSPRadius.lg),
            side: const BorderSide(color: VSPColors.error, width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Iconsax.warning_2_copy, color: VSPColors.error),
              SizedBox(width: 8),
              Text(
                'تنبيه النظام 🛑',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Text(
            message.replaceFirst('Failed to create booking: ', '').replaceFirst('Exception: ', ''),
            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('موافق', style: TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDoubleBookingDialog() {
    HapticFeedback.heavyImpact();
    final outerContext = context;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          child: AlertDialog(
            backgroundColor: VSPColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.xl)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                const Icon(
                  Iconsax.calendar_1_copy,
                  color: VSPColors.error,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'عذراً، جزء من هذا الوقت تم حجزه وتأكيده للتو من لاعب آخر. يرجى العودة وتحديث الأوقات المتاحة.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: VSPColors.textPrimary,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  text: 'العودة لااختيار وقت آخر',
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    if (outerContext.mounted) {
                      Navigator.pop(outerContext);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _onCancelAndReleaseBooking(BuildContext dialogCtx) async {
    _countdownTimer?.cancel();
    _webhookTimeoutTimer?.cancel();
    _bookingSubscription?.cancel();
    if (_booking != null && !_booking!.id.startsWith('mock_')) {
      try {
        await Supabase.instance.client
            .from('bookings')
            .delete()
            .eq('id', _booking!.id);
        debugPrint('✅ Pending booking ${_booking!.id} immediately deleted on Go Back.');
      } catch (e) {
        debugPrint('⚠️ Error deleting pending booking on Go Back: $e');
      }
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
            icon: Icon(isArabic ? Iconsax.arrow_right_3_copy : Iconsax.arrow_left_2_copy, color: VSPColors.textPrimary, size: 20),
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
                    // ⏱️ 1. Hold Countdown Timer Banner (10-minute hold - only for pitch bookings)
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

                    // 💳 2. Interactive Visual Payment Method Selector Cards
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

                    // 💰 Financial Breakdown Card
                    Builder(
                      builder: (context) {
                        // Unified Platform & Processing Service Fee: 4.75% + 3 EGP fixed
                        final double serviceFee = (amountToPay * 0.0475) + 3.0;
                        final double totalWithFees = amountToPay + serviceFee;

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
                    if (_isLoading || _isAwaitingWebhook || _isVerifyingManual) ...[
                      const CircularProgressIndicator(color: VSPColors.accent),
                      const SizedBox(height: 16),
                      Text(
                        isArabic ? 'جاري انتظار تأكيد السيرفر وبوابة الدفع...' : 'Awaiting payment confirmation...',
                        style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      // ⚡ Manual verification button fallback!
                      ElevatedButton.icon(
                        onPressed: _isVerifyingManual ? null : _verifyPaymentStatusManual,
                        icon: const Icon(Iconsax.refresh_copy, color: Colors.black, size: 16),
                        label: Text(
                          isArabic ? 'تم الدفع؟ تحقق فوراً ⚡' : 'Paid? Verify Now ⚡',
                          style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VSPColors.accent,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      if (_isAwaitingWebhook) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () {
                            _webhookTimeoutTimer?.cancel();
                            setState(() => _isAwaitingWebhook = false);
                          },
                          icon: const Icon(Iconsax.close_circle_copy, color: VSPColors.error, size: 16),
                          label: Text(
                            isArabic ? 'إلغاء الانتظار' : 'Cancel Wait',
                            style: const TextStyle(color: VSPColors.error, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
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
                        isLoading: _isLoading || _isAwaitingWebhook || _isVerifyingManual,
                        onPressed: (_booking == null) ? null : _startPaymobCheckout,
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

  Widget _buildFeeRow({
    required String label,
    required String value,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isBold ? Colors.white : VSPColors.textSecondary,
            fontSize: isBold ? 13 : 11,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
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
