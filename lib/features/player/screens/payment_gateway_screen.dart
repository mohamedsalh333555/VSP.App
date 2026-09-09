import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../data/models.dart';
import '../services/payment_checkout_coordinator.dart';
import '../services/payment_checkout_service.dart';
import '../widgets/payment/payment_background_glow.dart';
import '../widgets/payment/payment_breakdown_card.dart';
import '../widgets/payment/payment_cancel_dialog.dart';
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
  final PaymentCheckoutCoordinator _coordinator = PaymentCheckoutCoordinator();
  bool _isLoading = false;
  bool _isAwaitingWebhook = false;
  Booking? _booking;
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
    _coordinator.startCountdownTimer(
      initialSeconds: _remainingSeconds,
      onTick: (remaining) {
        if (mounted) setState(() => _remainingSeconds = remaining);
      },
      onExpired: () async {
        if (!_paymentCompleted && _booking != null && mounted) {
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          final userId = authProvider.currentUser?.uid;
          if (userId != null && PaymentCheckoutService.shouldCleanupStaleBookings(
            isTournamentPayment: widget.isTournamentPayment,
            existingBookingId: widget.existingBookingId,
          )) {
            await _coordinator.cleanupStaleBookings(
              isTournamentPayment: widget.isTournamentPayment,
              userId: userId,
              stadiumId: widget.bookingDraft.stadiumId,
            );
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
      },
    );
  }

  @override
  void dispose() {
    _coordinator.dispose();
    super.dispose();
  }

  /// Creates booking in pending state or resumes existing booking
  Future<void> _createPendingBooking() async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    final userId = authProvider.currentUser?.uid;

    setState(() => _isLoading = true);

    try {
      final booking = await _coordinator.resolveInitialBooking(
        isTournamentPayment: widget.isTournamentPayment,
        existingBooking: widget.existingBooking,
        existingBookingId: widget.existingBookingId,
        userId: userId,
        bookingDraft: widget.bookingDraft,
        fetchBookingById: bookingProvider.getBookingById,
        createBooking: bookingProvider.createBooking,
      );

      if (!mounted) return;
      setState(() {
        _booking = booking;
        _isLoading = false;
      });

      if (booking != null) {
        _initBookingRealtimeListener(booking.id);
      } else if (!widget.isTournamentPayment) {
        final isArabic = Localizations.localeOf(context).languageCode == 'ar';
        final errorMsg = bookingProvider.errorMessage ??
            (isArabic ? 'تعذر إنشاء الحجز في قاعدة البيانات' : 'Failed to create booking in database');
        VSPFeedback.showError(context, errorMsg);
        Navigator.pop(context);
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
  }

  void _initBookingRealtimeListener(String bookingId) {
    _coordinator.listenToBookingStatus(
      bookingId: bookingId,
      onStatusUpdated: (bookingData) async {
        final status = bookingData['status'] as String?;
        final paymentStatus = bookingData['payment_status'] as String?;

        if (PaymentCheckoutService.isPaymentConfirmed(status: status, paymentStatus: paymentStatus)) {
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
      },
      onError: (err) => debugPrint('Real-time listener error: $err'),
    );
  }

  void _startFallbackPollingTimer(String bookingId) {
    _coordinator.startFallbackPolling(
      bookingId: bookingId,
      fetchBooking: (id) => Provider.of<BookingProvider>(context, listen: false).getBookingById(id),
      onConfirmed: (booking) {
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
      },
    );
  }

  Future<void> _startPaymobCheckout() async {
    if (_booking == null && !widget.isTournamentPayment) return;
    if (_isLoading || _isAwaitingWebhook) return;
    setState(() {
      _isLoading = true;
      _isAwaitingWebhook = true;
    });

    _coordinator.startWebhookTimeout(
      onTimeout: () {
        if (mounted && _isAwaitingWebhook && !_paymentCompleted) {
          setState(() {
            _isAwaitingWebhook = false;
            _isLoading = false;
          });
          _showWebhookTimeoutMessage();
        }
      },
    );

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    final userName = auth.userModel?.name ?? 'Player';
    final userPhone = auth.userModel?.phone ?? '';
    final userEmail = user?.email ?? 'player@vsp.app';

    final paymobUrl = await PaymentCheckoutService.requestPaymobCheckoutUrl(
      draft: widget.bookingDraft,
      selectedMethod: _selectedMethod,
      isTournamentPayment: widget.isTournamentPayment,
      bookingId: _booking?.id,
      userEmail: userEmail,
      userName: userName,
      userPhone: userPhone,
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
            _coordinator.cancelCountdownTimer();
            Navigator.pop(context, true);
            return;
          }

          setState(() {
            _isAwaitingWebhook = true;
            _isLoading = true;
          });

          if (_booking != null) {
            final bookingId = _booking!.id;
            if (kDebugMode) {
              await _coordinator.simulateTestPaymentWebhook(bookingId);
            }
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
    await _coordinator.releaseBookingSafely(
      isTournamentPayment: widget.isTournamentPayment,
      booking: _booking,
    );
    if (!widget.isTournamentPayment && mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.uid;
      if (userId != null && mounted) {
        Provider.of<BookingProvider>(context, listen: false).loadUserBookings(userId);
      }
    }

    if (dialogCtx.mounted) Navigator.pop(dialogCtx, true);
  }

  Future<bool?> _confirmCancel(BuildContext context, bool isChampionship, bool isArabic) {
    return PaymentCancelDialog.show(
      context: context,
      isChampionship: isChampionship,
      isArabic: isArabic,
      onConfirmCancel: _onCancelAndReleaseBooking,
    );
  }

  void _showWebhookTimeoutMessage() {
    if (!mounted) return;
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

  AppBar _buildAppBar(BuildContext context, AppLocalizations l10n, bool isArabic, bool isChampionship) {
    return AppBar(
      backgroundColor: VSPColors.background,
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          isArabic ? Iconsax.arrow_right_1_copy : Iconsax.arrow_left_2_copy,
          color: VSPColors.textPrimary,
          size: 20,
        ),
        onPressed: () async {
          final cancel = await _confirmCancel(context, isChampionship, isArabic);
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
        final cancel = await _confirmCancel(context, isChampionship, isArabic);
        if (cancel == true && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: VSPColors.background,
        appBar: _buildAppBar(context, l10n, isArabic, isChampionship),
        body: Stack(
          children: [
            const PaymentBackgroundGlow(),
            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    PaymentCountdownHeader(
                      remainingSeconds: _remainingSeconds,
                      amountToPay: amountToPay,
                      isChampionship: isChampionship,
                      hasDeposit: hasDeposit,
                      currency: l10n.egCurrency,
                      isArabic: isArabic,
                    ),
                    const SizedBox(height: 16),
                    PaymentMethodSelector(
                      selectedMethod: _selectedMethod,
                      isArabic: isArabic,
                      onMethodChanged: (val) => setState(() => _selectedMethod = val),
                    ),
                    const SizedBox(height: 16),
                    PaymentBreakdownCard(
                      bookingDraft: widget.bookingDraft,
                      isChampionship: isChampionship,
                      hasDeposit: hasDeposit,
                      amountToPay: amountToPay,
                      isArabic: isArabic,
                    ),
                    const SizedBox(height: 20),
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
