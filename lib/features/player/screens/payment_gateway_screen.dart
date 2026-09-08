import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/repositories/booking_repository.dart';
import '../../../core/services/paymob_service.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../data/models.dart';
import '../widgets/payment/payment_breakdown_card.dart';
import '../widgets/payment/payment_countdown_header.dart';
import '../widgets/payment/payment_method_selector.dart';
import '../widgets/payment/payment_security_footer.dart';
import 'booking_success_screen.dart';
import 'paymob_web_view_screen.dart';

/// Secure checkout and payment gateway screen for pitches and tournament entries.
/// Manages atomic slot locks, Paymob webview checkout flow, and realtime webhook status updates.
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
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          final userId = authProvider.currentUser?.uid;
          if (userId != null && !widget.isTournamentPayment && widget.existingBookingId == null) {
            await _cleanupStalePendingBookings(userId);
          }
          if (mounted) {
            final isArabic = Localizations.localeOf(context).languageCode == 'ar';
            VSPFeedback.showError(
              context,
              isArabic ? 'انتهت مهلة حجز الوقت (5 دقائق).' : 'Booking reservation timeout (5 mins).',
            );
            Navigator.pop(context);
          }
        }
      }
    });
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

  /// Creates booking in pending state or resumes existing booking
  Future<void> _createPendingBooking() async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    final userId = authProvider.currentUser?.uid;

    setState(() => _isLoading = true);

    if (widget.isTournamentPayment) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

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
        await _cleanupStalePendingBookings(userId);

        if (!mounted) return;
        final draft = widget.bookingDraft.copyWith(
          paymentStatus: 'pending',
          paymentMethod: 'paymob',
          isPaid: false,
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
            final errorMsg = bookingProvider.errorMessage ??
                (isArabic ? 'تعذر إنشاء الحجز في قاعدة البيانات' : 'Failed to create booking in database');
            VSPFeedback.showError(context, errorMsg);
            Navigator.pop(context);
          }
        }
      } catch (e) {
        if (mounted) {
          final isArabic = Localizations.localeOf(context).languageCode == 'ar';
          VSPFeedback.showError(
            context,
            isArabic ? 'تعذر بدء عملية الحجز: $e' : 'Failed to initialize booking: $e',
          );
          Navigator.pop(context);
        }
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cleanupStalePendingBookings(String userId) async {
    if (widget.isTournamentPayment) return;
    await SupabaseBookingRepository().cleanupStalePendingBookings(
      userId: userId,
      stadiumId: widget.bookingDraft.stadiumId,
    );
  }

  void _initBookingRealtimeListener(String bookingId) {
    if (bookingId.startsWith('mock_')) return;
    _bookingSubscription?.cancel();
    _bookingSubscription = SupabaseBookingRepository().streamBookingStatus(bookingId).listen((data) async {
      if (data.isNotEmpty) {
        final bookingData = data.first;
        final status = bookingData['status'] as String?;
        final paymentStatus = bookingData['payment_status'] as String?;

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

        if (userId != null && mounted) {
          final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
          bookingProvider.loadUserBookings(userId);
        }
      }
    } catch (e) {
      debugPrint('Error releasing booking slot safely on Go Back: $e');
    }

    if (dialogCtx.mounted) Navigator.pop(dialogCtx, true);
  }

  Future<bool?> _showCancelDialog(BuildContext context, bool isChampionship, bool isArabic) {
    final dialogTitle = isChampionship
        ? (isArabic ? 'التراجع عن التسجيل في البطولة؟' : 'Cancel Championship Registration?')
        : (isArabic ? 'التراجع عن عملية الحجز؟' : 'Cancel Booking Checkout?');

    final dialogContent = isChampionship
        ? (isArabic
            ? 'إذا تراجعت الآن، لن يتم استكمال التسجيل في البطولة وسيمكنك العودة في أي وقت.'
            : 'If you go back now, your tournament registration will not be completed.')
        : (isArabic
            ? 'إذا تراجعت الآن، لن يتم خصم أي مبالغ وسيمكنك مراجعة حجزك وتعديله في أي وقت.'
            : 'If you go back now, no charges will be made and you can review your checkout anytime.');

    final dialogContinueText = isChampionship
        ? (isArabic ? 'متابعة التسجيل' : 'Continue Registration')
        : (isArabic ? 'متابعة الدفع' : 'Continue Checkout');

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
        title: Text(dialogTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(dialogContent, style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(dialogContinueText, style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => _onCancelAndReleaseBooking(ctx),
            child: Text(isArabic ? 'الرجوع للخلف' : 'Go Back', style: const TextStyle(color: VSPColors.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isChampionship = widget.bookingDraft.stadiumName.contains('بطولة:');
    final hasDeposit = widget.bookingDraft.needsDeposit && widget.bookingDraft.depositPaid > 0;
    final amountToPay = hasDeposit ? widget.bookingDraft.depositPaid : widget.bookingDraft.totalPrice;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final cancel = await _showCancelDialog(context, isChampionship, isArabic);
        if (cancel == true && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: VSPColors.background,
        appBar: AppBar(
          backgroundColor: VSPColors.background,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              isArabic ? Iconsax.arrow_right_1_copy : Iconsax.arrow_left_2_copy,
              color: VSPColors.textPrimary,
              size: 20,
            ),
            onPressed: () async {
              final cancel = await _showCancelDialog(context, isChampionship, isArabic);
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
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(shape: BoxShape.circle, color: VSPColors.accent.withValues(alpha: 0.12)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 1. Hold Countdown Timer Banner & Amount Header
                    PaymentCountdownHeader(
                      remainingSeconds: _remainingSeconds,
                      amountToPay: amountToPay,
                      isChampionship: isChampionship,
                      hasDeposit: hasDeposit,
                      currency: l10n.egCurrency,
                      isArabic: isArabic,
                    ),

                    const SizedBox(height: 16),

                    // 2. Interactive Payment Method Selector
                    PaymentMethodSelector(
                      selectedMethod: _selectedMethod,
                      isArabic: isArabic,
                      onMethodChanged: (val) => setState(() => _selectedMethod = val),
                    ),

                    const SizedBox(height: 16),

                    // 3. Financial Breakdown Card
                    PaymentBreakdownCard(
                      bookingDraft: widget.bookingDraft,
                      isChampionship: isChampionship,
                      hasDeposit: hasDeposit,
                      amountToPay: amountToPay,
                      isArabic: isArabic,
                    ),

                    const SizedBox(height: 20),

                    // 4. Security Guarantee and CTA Button
                    PaymentSecurityFooter(
                      isLoading: _isLoading,
                      isAwaitingWebhook: _isAwaitingWebhook,
                      isArabic: isArabic,
                      canProceed: !(_booking == null && !widget.isTournamentPayment),
                      onProceed: _startPaymobCheckout,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
