import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../data/models.dart';
import '../services/payment_checkout_coordinator.dart';
import '../services/payment_checkout_service.dart';
import '../../../core/services/paymob_service.dart';
import '../widgets/payment/payment_background_glow.dart';
import '../widgets/payment/payment_breakdown_card.dart';
import '../widgets/payment/payment_cancel_dialog.dart';
import '../widgets/payment/payment_countdown_header.dart';
import '../widgets/payment/payment_security_footer.dart';
import 'booking_success_screen.dart';
import 'paymob_web_view_screen.dart';
import 'player_home_screen.dart';
import '../widgets/payment/payment_verification_modal.dart';
import '../../../shared/widgets/vsp_back_button.dart';

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
  int _remainingSeconds = 480; // 8 minutes atomic hold timer
  bool _paymentCompleted = false;
  bool _isVerificationModalShowing = false;
  BuildContext? _verificationModalContext;
  final String _selectedMethod = 'card';
  PaymobFeePolicy? _feePolicy;
  bool _serverForcedFullPayment = false;

  @override
  void initState() {
    super.initState();
    _startCountdownTimer();
    _loadFeePolicy();
    _createPendingBooking();
  }

  Future<void> _resolveActiveCashRestriction() async {
    if (widget.isTournamentPayment || widget.forceFullPayment || _booking == null) return;
    final userId = Provider.of<AuthProvider>(context, listen: false).currentUser?.id;
    if (userId == null) return;

    try {
      final rows = await SupabaseBookingRepository().getUserBookingsDirectly(userId);
      final hasPriorActiveCash = rows.any((b) =>
          b.id != _booking!.id &&
          b.paymentMethod.toLowerCase() == 'cash' &&
          (b.status == BookingStatus.pending || b.status == BookingStatus.confirmed) &&
          b.endTime.isAfter(DateTime.now()));
      if (!mounted) return;
      if (hasPriorActiveCash) {
        setState(() => _serverForcedFullPayment = true);
      }
    } catch (_) {
      // Server-side create_booking_atomic remains the final authority.
    }
  }

  Future<void> _loadFeePolicy() async {
    final policy = await PaymobService.fetchFeePolicy();
    if (!mounted) return;
    setState(() => _feePolicy = policy);
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
          if (widget.isTournamentPayment) {
            await _coordinator.releaseBookingSafely(
              isTournamentPayment: true,
              booking: _booking,
              paymentOrderReference: widget.existingBookingId,
            );
          } else if (userId != null && PaymentCheckoutService.shouldCleanupStaleBookings(
            isTournamentPayment: false,
            existingBookingId: widget.existingBookingId,
          )) {
            await _coordinator.cleanupStaleBookings(
              isTournamentPayment: false,
              userId: userId,
              stadiumId: widget.bookingDraft.stadiumId,
            );
          }
          if (mounted) {
            final isArabic = Localizations.localeOf(context).languageCode == 'ar';
            VSPFeedback.showError(
              context,
              isArabic ? 'انتهت مهلة حجز الوقت (8 دقائق).' : 'Booking reservation timeout (8 mins).',
            );
            Navigator.pop(context);
          }
        }
      },
    );
  }

  @override
  void dispose() {
    _closeVerificationModalIfShowing();
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
      await _resolveActiveCashRestriction();

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
              _closeVerificationModalIfShowing();
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
          _closeVerificationModalIfShowing();
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
      timeout: const Duration(minutes: 5),
      onTimeout: () {
        if (mounted && _isAwaitingWebhook && !_paymentCompleted) {
          if (_isVerificationModalShowing) {
            debugPrint('Webhook timeout elapsed but verification modal is still showing.');
            return;
          }
          setState(() {
            _isAwaitingWebhook = false;
            _isLoading = false;
          });
        }
      },
    );

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    final userName = auth.userModel?.name ?? 'Player';
    final userPhone = auth.userModel?.phone ?? '';
    final userEmail = user?.email ?? 'player@vsp.app';

    final isFullPayment = widget.forceFullPayment ||
        _serverForcedFullPayment ||
        !widget.bookingDraft.needsDeposit ||
        widget.bookingDraft.depositPaid <= 0;

    final paymobUrl = await PaymentCheckoutService.requestPaymobCheckoutUrl(
      draft: widget.bookingDraft,
      selectedMethod: _selectedMethod,
      isTournamentPayment: widget.isTournamentPayment,
      bookingId: _booking?.id ?? widget.existingBookingId,
      userEmail: userEmail,
      userName: userName,
      userPhone: userPhone,
      isFullPayment: isFullPayment,
    );

    final isArabic = mounted ? Localizations.localeOf(context).languageCode == 'ar' : true;

    if (paymobUrl != null && paymobUrl.isNotEmpty) {
      try {
        if (!mounted) return;
        _coordinator.cancelCountdownTimer();
        final isPaidSuccess = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => PaymobWebViewScreen(
              initialUrl: paymobUrl,
              title: isArabic ? 'بوابة الدفع الإلكتروني' : 'Secure Online Payment',
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
            _showVerificationModal(bookingId, isArabic);
            _startFallbackPollingTimer(bookingId);
          }
        } else if (mounted && !_paymentCompleted) {
          _startCountdownTimer();
          setState(() {
            _isAwaitingWebhook = false;
            _isLoading = false;
          });
          VSPFeedback.showError(
            context,
            isArabic
                ? 'لم تكتمل عملية الدفع. يمكنك إعادة المحاولة في أي وقت.'
                : 'Payment was not completed. You can try again anytime.',
          );
        }
      } catch (e) {
        debugPrint('Paymob Launch notice: $e');
        if (mounted) {
          if (!_paymentCompleted) _startCountdownTimer();
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
        final l10n = AppLocalizations.of(context);
        VSPFeedback.showError(
          context,
          l10n?.paymentGatewayUnavailable ??
              (isArabic
                  ? 'عذراً، تعذر الاتصال ببوابة الدفع حالياً. يرجى المحاولة مرة أخرى لاحقاً.'
                  : 'Failed to connect to payment gateway. Please try again later.'),
        );
      }
    }
  }

  Future<void> _onCancelAndReleaseBooking(BuildContext dialogCtx) async {
    await _coordinator.releaseBookingSafely(
      isTournamentPayment: widget.isTournamentPayment,
      booking: _booking,
      paymentOrderReference: widget.isTournamentPayment ? widget.existingBookingId : null,
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

  void _showVerificationModal(String bookingId, bool isArabic) {
    if (_isVerificationModalShowing || !mounted) return;
    _isVerificationModalShowing = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (modalCtx) {
        _verificationModalContext = modalCtx;
        return PaymentVerificationModal(
          bookingId: bookingId,
          isArabic: isArabic,
          onGoToBookings: () {
            _closeVerificationModalIfShowing();
            _paymentCompleted = true;
            _coordinator.cancelCountdownTimer();
            Navigator.of(context).popUntil((route) => route.isFirst);
            playerHomeScreenKey.currentState?.switchToTab(3);
          },
        );
      },
    ).then((_) {
      _verificationModalContext = null;
      _isVerificationModalShowing = false;
    });
  }

  void _closeVerificationModalIfShowing() {
    if (_isVerificationModalShowing) {
      _isVerificationModalShowing = false;
      if (_verificationModalContext != null && _verificationModalContext!.mounted) {
        Navigator.of(_verificationModalContext!).pop();
        _verificationModalContext = null;
      } else if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  AppBar _buildAppBar(BuildContext context, AppLocalizations l10n, bool isArabic, bool isChampionship) {
    return AppBar(
      backgroundColor: VSPColors.background,
      elevation: 0,
      leading: VSPBackButton(
        onTap: () async {
          final cancel = await _confirmCancel(context, isChampionship, isArabic);
          if (cancel == true && context.mounted) Navigator.pop(context);
        },
      ),
      centerTitle: true,
      title: Text(
        isChampionship
            ? (isArabic
                ? (widget.bookingDraft.stadiumName.contains('دوري:') ? 'تأكيد اشتراك الدوري' : 'تأكيد اشتراك البطولة')
                : (widget.bookingDraft.stadiumName.contains('دوري:') ? 'League Payment' : 'Championship Payment'))
            : l10n.confirmBooking,
        style: Theme.of(context).textTheme.displaySmall,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isChampionship = widget.bookingDraft.stadiumName.contains('بطولة:') || widget.bookingDraft.stadiumName.contains('دوري:');
    final effectiveForceFullPayment = widget.forceFullPayment || _serverForcedFullPayment;
    final hasDeposit = !effectiveForceFullPayment && widget.bookingDraft.needsDeposit && widget.bookingDraft.depositPaid > 0;
    final amountToPay = hasDeposit ? widget.bookingDraft.depositPaid : widget.bookingDraft.totalPrice;
    final double? totalWithFees = _feePolicy?.total(amountToPay);

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
                      totalAmountWithFees: totalWithFees,
                      isChampionship: isChampionship,
                      hasDeposit: hasDeposit,
                      currency: l10n.egCurrency,
                      isArabic: isArabic,
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
                      totalAmount: totalWithFees,
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
