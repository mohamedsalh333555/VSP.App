import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/ui/vsp_ui.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../data/models.dart';
import '../../../core/repositories/booking/booking_domain_rules.dart';
import '../services/payment_checkout_coordinator.dart';
import '../services/payment_checkout_service.dart';
import '../../../core/services/paymob_service.dart';
import '../../../core/services/remote_config_service.dart';
import '../../../core/repositories/league_repository.dart';
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
  /// [H-08]: Uses canonical pending expiry policy from BookingDomainRules.
  /// Client-side countdown only — server is the authoritative enforcer.
  int _remainingSeconds = BookingDomainRules.kPendingPaymentWindowMinutes * 60;
  bool _paymentCompleted = false;
  bool _isVerificationModalShowing = false;
  BuildContext? _verificationModalContext;
  final String _selectedMethod = 'card';
  PaymobFeePolicy? _feePolicy;
  bool _isFeePolicyLoading = true;
  String? _paymentUserId;
  bool _hasAccountChanged = false;
  bool _isOnlinePaymentUnavailable = false;
  int _feePolicyRequestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _paymentUserId = Provider.of<AuthProvider>(context, listen: false).currentUser?.id;
    _isOnlinePaymentUnavailable = !Provider.of<RemoteConfigService>(
      context,
      listen: false,
    ).isFeatureEnabled('online_payment_enabled', defaultValue: true);
    if (_isOnlinePaymentUnavailable) return;

    _startCountdownTimer();
    _loadFeePolicy();
    _createPendingBooking();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentUserId = context.watch<AuthProvider>().currentUser?.id;
    if (currentUserId != _paymentUserId && !_hasAccountChanged) {
      _hasAccountChanged = true;
      _coordinator.cancelAllTimers();
      _closeVerificationModalIfShowing();
    }
  }

  Future<void> _loadFeePolicy() async {
    final requestGeneration = ++_feePolicyRequestGeneration;
    if (mounted) {
      setState(() {
        _isFeePolicyLoading = true;
        _feePolicy = null;
      });
    }
    final policy = await PaymobService.fetchFeePolicy();
    if (!mounted || requestGeneration != _feePolicyRequestGeneration) return;
    setState(() {
      _feePolicy = policy;
      _isFeePolicyLoading = false;
    });
  }

  void _startCountdownTimer() {
    _coordinator.startCountdownTimer(
      initialSeconds: _remainingSeconds,
      onTick: (remaining) {
        if (mounted) setState(() => _remainingSeconds = remaining);
      },
      onExpired: () async {
        if (!_paymentCompleted && _booking != null && mounted && !_hasAccountChanged &&
            Provider.of<AuthProvider>(context, listen: false).currentUser?.id == _paymentUserId) {
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          final userId = authProvider.currentUser?.id;
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
          if (mounted && !_hasAccountChanged &&
              Provider.of<AuthProvider>(context, listen: false).currentUser?.id == _paymentUserId) {
            final isArabic = Localizations.localeOf(context).languageCode == 'ar';
            VSPFeedback.showError(
              context,
              isArabic ? 'الموعد تحرّر مؤقتاً. لا تقلق — يمكنك حجزه مجدداً إذا كان متاحاً!' : 'Slot released. No worries — you can book it again if still available!',
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
    final userId = _paymentUserId;
    if (userId == null || authProvider.currentUser?.id != userId || _hasAccountChanged) {
      return;
    }

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

      if (!mounted ||
          _hasAccountChanged ||
          Provider.of<AuthProvider>(context, listen: false).currentUser?.id != userId) {
        // The pending lock was created for the checkout's original account.
        // Do not leave it reserved when that checkout is no longer active.
        if (booking != null) {
          await _coordinator.releaseBookingSafely(
            isTournamentPayment: false,
            booking: booking,
          );
        }
        return;
      }
      setState(() {
        _booking = booking;
        _isLoading = false;
      });
      if (booking != null) {
        _initBookingRealtimeListener(booking.id);
      } else if (!widget.isTournamentPayment) {
        final isArabic = Localizations.localeOf(context).languageCode == 'ar';
        VSPFeedback.showError(
          context,
          isArabic
              ? 'تعذر تأكيد الحجز من الخادم. ارجع وحاول مرة أخرى.'
              : 'The server could not confirm the booking. Go back and retry.',
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted && !_hasAccountChanged &&
          Provider.of<AuthProvider>(context, listen: false).currentUser?.id == userId) {
        final isArabic = Localizations.localeOf(context).languageCode == 'ar';
        debugPrint('Payment gateway booking initialization failed: $e');
        VSPFeedback.showError(
          context,
          isArabic
              ? 'تعذر بدء عملية الحجز. تحقق من الاتصال وحاول مرة أخرى.'
              : 'Could not start booking checkout. Check your connection and retry.',
        );
        Navigator.pop(context);
      }
    }
  }

  void _initBookingRealtimeListener(String bookingId) {
    _coordinator.listenToBookingStatus(
      bookingId: bookingId,
      onStatusUpdated: (bookingData) async {
        if (!mounted || _hasAccountChanged ||
            Provider.of<AuthProvider>(context, listen: false).currentUser?.id != _paymentUserId) {
          return;
        }
        final status = bookingData['status'] as String?;
        final paymentStatus = bookingData['payment_status'] as String?;

        if (PaymentCheckoutService.isPaymentConfirmed(status: status, paymentStatus: paymentStatus)) {
          HapticFeedback.heavyImpact();
          if (mounted) {
            final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
            final updatedBooking = await bookingProvider.getBookingById(bookingId);
            if (updatedBooking != null && mounted && !_hasAccountChanged &&
                Provider.of<AuthProvider>(context, listen: false).currentUser?.id == _paymentUserId) {
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
        if (mounted && !_hasAccountChanged && !_paymentCompleted &&
            Provider.of<AuthProvider>(context, listen: false).currentUser?.id == _paymentUserId) {
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
    final onlinePaymentEnabled = Provider.of<RemoteConfigService>(
      context,
      listen: false,
    ).isFeatureEnabled('online_payment_enabled', defaultValue: true);
    if (!onlinePaymentEnabled) {
      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
      VSPFeedback.showError(
        context,
        isArabic
            ? 'الدفع الإلكتروني غير متاح حالياً. حاول مرة أخرى لاحقاً.'
            : 'Online payment is currently unavailable. Please try again later.',
      );
      return;
    }
    if (_paymentUserId == null || _hasAccountChanged ||
        Provider.of<AuthProvider>(context, listen: false).currentUser?.id != _paymentUserId) {
      return;
    }
    if (_booking == null && !widget.isTournamentPayment) return;
    if (_isFeePolicyLoading || _feePolicy?.isValidForElectronicCheckout != true) {
      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
      VSPFeedback.showError(
        context,
        isArabic
            ? 'تعذر التحقق من رسوم الدفع. أعد تحميل تفاصيل الرسوم قبل المتابعة.'
            : 'Payment fees could not be verified. Reload the fee details before continuing.',
      );
      return;
    }
    if (_isLoading || _isAwaitingWebhook) return;
    setState(() {
      _isLoading = true;
      _isAwaitingWebhook = true;
    });

    _coordinator.startWebhookTimeout(
      timeout: const Duration(minutes: 5),
      onTimeout: () {
        if (mounted && !_hasAccountChanged &&
            Provider.of<AuthProvider>(context, listen: false).currentUser?.id == _paymentUserId &&
            _isAwaitingWebhook && !_paymentCompleted) {
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
    if (user?.id != _paymentUserId || _hasAccountChanged) {
      if (mounted) setState(() { _isLoading = false; _isAwaitingWebhook = false; });
      return;
    }
    final userName = auth.userModel?.name ?? 'Player';
    final userPhone = auth.userModel?.phone ?? '';
    final userEmail = user?.email ?? 'player@vsp.app';

    final bookingNeedsDeposit = _booking?.needsDeposit ?? widget.bookingDraft.needsDeposit;
    final bookingDepositAmount = _booking?.depositAmount ?? widget.bookingDraft.depositPaid;
    final paymentDraft = _booking == null
        ? widget.bookingDraft
        : widget.bookingDraft.copyWith(
            totalPrice: _booking!.totalPrice,
            needsDeposit: !widget.forceFullPayment && _booking!.needsDeposit,
            depositPaid: widget.forceFullPayment ? 0 : _booking!.depositAmount,
          );
    final isFullPayment = widget.forceFullPayment ||
        widget.isTournamentPayment ||
        !bookingNeedsDeposit ||
        bookingDepositAmount <= 0;

    final paymobUrl = await PaymentCheckoutService.requestPaymobCheckoutUrl(
      draft: paymentDraft,
      selectedMethod: _selectedMethod,
      isTournamentPayment: widget.isTournamentPayment,
      bookingId: _booking?.id ?? widget.existingBookingId,
      userEmail: userEmail,
      userName: userName,
      userPhone: userPhone,
      isFullPayment: isFullPayment,
    );

    if (!mounted || _hasAccountChanged ||
        Provider.of<AuthProvider>(context, listen: false).currentUser?.id != _paymentUserId) {
      return;
    }
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

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

        if (mounted && !_hasAccountChanged &&
            Provider.of<AuthProvider>(context, listen: false).currentUser?.id == _paymentUserId &&
            (isPaidSuccess == true)) {
          if (widget.isTournamentPayment) {
            final orderReference = widget.existingBookingId;
            if (orderReference == null || orderReference.isEmpty) {
              if (mounted) {
                setState(() {
                  _isAwaitingWebhook = false;
                  _isLoading = false;
                });
                VSPFeedback.showError(context, isArabic ? 'مرجع الدفع غير متاح.' : 'Payment reference is missing.');
              }
              return;
            }

            // Never trust the Paymob WebView/browser result as proof of payment.
            // The server-side order status is the financial source of truth.
            _coordinator.startTournamentOrderPolling(
              orderReference: orderReference,
              fetchStatus: (ref) async {
                if (ref.startsWith('TOURN_1V1_')) {
                  final paid = await LeagueRepository().is1v1OrderPaid(ref);
                  return {
                    'success': true,
                    'payment_status': paid ? 'paid' : 'pending',
                  };
                }
                final res = await Supabase.instance.client
                    .from('tournament_orders')
                    .select('payment_status')
                    .eq('order_reference', ref)
                    .maybeSingle();
                final status = res?['payment_status']?.toString() ?? 'pending';
                return {
                  'success': true,
                  'payment_status': status,
                };
              },
              onPaid: (_) {
                if (!mounted || _hasAccountChanged || _paymentCompleted ||
                    Provider.of<AuthProvider>(context, listen: false).currentUser?.id != _paymentUserId) {
                  return;
                }
                _paymentCompleted = true;
                _coordinator.cancelAllTimers();
                Navigator.pop(context, true);
              },
            );
            _coordinator.startWebhookTimeout(
              timeout: const Duration(seconds: 90),
              onTimeout: () {
                if (!mounted || _hasAccountChanged || _paymentCompleted ||
                    Provider.of<AuthProvider>(context, listen: false).currentUser?.id != _paymentUserId) {
                  return;
                }
                _coordinator.cancelAllTimers();
                setState(() {
                  _isAwaitingWebhook = false;
                  _isLoading = false;
                });
                VSPFeedback.showInfo(
                  context,
                  isArabic
                      ? 'الدفع ما زال قيد التحقق. لا تعيد الدفع الآن؛ سيتم اعتماد العملية بعد وصول تأكيد الخادم.'
                      : 'Payment is still being verified. Do not pay again; the registration will complete after server confirmation.',
                );
              },
            );
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
        } else if (mounted && !_hasAccountChanged && !_paymentCompleted &&
            Provider.of<AuthProvider>(context, listen: false).currentUser?.id == _paymentUserId) {
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
        if (mounted && !_hasAccountChanged &&
            Provider.of<AuthProvider>(context, listen: false).currentUser?.id == _paymentUserId) {
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
      final userId = authProvider.currentUser?.id;
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
      useSafeArea: true,
      barrierDismissible: false,
      barrierColor: VSPColors.black.withValues(alpha: 0.85),
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
    if (!_isVerificationModalShowing) return;
    _isVerificationModalShowing = false;
    if (_verificationModalContext != null && _verificationModalContext!.mounted) {
      Navigator.of(_verificationModalContext!).pop();
    }
    _verificationModalContext = null;
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
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final currentUserId = context.read<AuthProvider>().currentUser?.id;
    if (_paymentUserId == null || _hasAccountChanged || currentUserId != _paymentUserId) {
      return VSPScaffold(
        backgroundColor: VSPColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(VSPSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isArabic
                        ? 'تغيّر الحساب أثناء عملية الدفع. أوقفنا المتابعة لحماية الحجز.'
                        : 'The account changed during checkout. Payment has been paused to protect the booking.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: VSPColors.textPrimary),
                  ),
                  const SizedBox(height: VSPSpacing.md),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(isArabic ? 'رجوع' : 'Go back'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_isOnlinePaymentUnavailable) {
      return VSPScaffold(
        backgroundColor: VSPColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(VSPSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Iconsax.info_circle_copy, color: VSPColors.warning, size: 32),
                  const SizedBox(height: VSPSpacing.md),
                  Text(
                    isArabic
                        ? 'الدفع الإلكتروني غير متاح حالياً. لم يتم إنشاء حجز مؤقت أو حجز الموعد.'
                        : 'Online payment is currently unavailable. No pending booking or time slot has been created.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: VSPColors.textPrimary, height: 1.4),
                  ),
                  const SizedBox(height: VSPSpacing.md),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(isArabic ? 'رجوع' : 'Go back'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!widget.isTournamentPayment && _booking == null) {
      return VSPScaffold(
        backgroundColor: VSPColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(VSPSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isLoading) ...[
                    const CircularProgressIndicator(color: VSPColors.accent),
                    const SizedBox(height: VSPSpacing.md),
                    Text(
                      isArabic
                          ? 'جارٍ تأكيد الحجز والسعر من الخادم...'
                          : 'Confirming the booking and price with the server...',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: VSPColors.textSecondary),
                    ),
                  ] else ...[
                    Text(
                      isArabic
                          ? 'لم يتم تأكيد الحجز. ارجع وحاول مرة أخرى.'
                          : 'The booking was not confirmed. Go back and try again.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: VSPColors.textPrimary),
                    ),
                    const SizedBox(height: VSPSpacing.md),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(isArabic ? 'رجوع' : 'Go back'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    final l10n = AppLocalizations.of(context)!;
    final isOnlinePaymentEnabled = context
        .watch<RemoteConfigService>()
        .isFeatureEnabled('online_payment_enabled', defaultValue: true);
    final isChampionship = widget.bookingDraft.stadiumName.contains('بطولة:') || widget.bookingDraft.stadiumName.contains('دوري:');
    final effectiveForceFullPayment = widget.forceFullPayment;
    final effectiveDraft = _booking == null
        ? widget.bookingDraft
        : widget.bookingDraft.copyWith(
            totalPrice: _booking!.totalPrice,
            needsDeposit: !widget.forceFullPayment && _booking!.needsDeposit,
            depositPaid: widget.forceFullPayment ? 0 : _booking!.depositAmount,
          );
    final bookingNeedsDeposit = _booking?.needsDeposit ?? widget.bookingDraft.needsDeposit;
    final bookingDepositAmount = _booking?.depositAmount ?? widget.bookingDraft.depositPaid;
    final hasDeposit = !effectiveForceFullPayment &&
        !widget.isTournamentPayment &&
        bookingNeedsDeposit &&
        bookingDepositAmount > 0;
    final amountToPay = hasDeposit
        ? bookingDepositAmount
        : (_booking?.totalPrice ?? widget.bookingDraft.totalPrice);
    final double? totalWithFees = _feePolicy?.isValidForElectronicCheckout == true
        ? _feePolicy!.total(amountToPay)
        : null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final cancel = await _confirmCancel(context, isChampionship, isArabic);
        if (cancel == true && context.mounted) Navigator.pop(context);
      },
      child: VSPScaffold(
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
                      bookingDraft: effectiveDraft,
                      isChampionship: isChampionship,
                      hasDeposit: hasDeposit,
                      amountToPay: amountToPay,
                      isArabic: isArabic,
                      feePolicy: _feePolicy,
                      isFeePolicyLoading: _isFeePolicyLoading,
                      onRetryFeePolicy: _loadFeePolicy,
                    ),
                    const SizedBox(height: VSPSpacing.md),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: VSPSpacing.lg,
                        vertical: VSPSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: VSPColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(VSPRadius.card),
                        border: Border.all(color: VSPColors.divider),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Iconsax.card_copy,
                            color: VSPColors.accent,
                            size: 20,
                          ),
                          const SizedBox(width: VSPSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isArabic ? 'طريقة الدفع' : 'Payment method',
                                  style: const TextStyle(
                                    color: VSPColors.textPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  isArabic
                                      ? 'هتختار وسيلة الدفع المناسبة داخل بوابة Paymob الرسمية.'
                                      : 'Choose your preferred method inside the official Paymob gateway.',
                                  style: const TextStyle(
                                    color: VSPColors.textSecondary,
                                    fontSize: 11.5,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: VSPSpacing.lg),
                    if (!isOnlinePaymentEnabled) ...[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: VSPSpacing.md),
                        padding: const EdgeInsets.all(VSPSpacing.md),
                        decoration: BoxDecoration(
                          color: VSPColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(VSPRadius.md),
                          border: Border.all(
                            color: VSPColors.warning.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          isArabic
                              ? 'الدفع الإلكتروني متوقف حالياً. لم يتم إرسال طلب دفع جديد.'
                              : 'Online payment is currently disabled. No new payment request can be started.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: VSPColors.warning,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                    PaymentSecurityFooter(
                      isLoading: _isLoading,
                      isAwaitingWebhook: _isAwaitingWebhook,
                      isArabic: isArabic,
                      canProceed: isOnlinePaymentEnabled &&
                          !(_booking == null && !widget.isTournamentPayment) &&
                          !_isFeePolicyLoading &&
                          _feePolicy?.isValidForElectronicCheckout == true,
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
