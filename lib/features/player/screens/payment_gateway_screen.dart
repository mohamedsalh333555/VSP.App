import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../data/models.dart';
import 'booking_success_screen.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/booking_provider.dart';

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
  bool _isPaymobLoading = false;
  Booking? _booking;
  StreamSubscription? _bookingSubscription;

  @override
  void initState() {
    super.initState();
    _createPendingBooking();
  }

  @override
  void dispose() {
    _bookingSubscription?.cancel();
    _bookingSubscription = null;

    // 🛑 Automatic cleanup: If user exits payment screen and booking is still pending & unpaid, delete it immediately
    if (_booking != null && _booking!.status == BookingStatus.pending && !_booking!.isPaid) {
      final bId = _booking!.id;
      if (!bId.startsWith('mock_')) {
        Supabase.instance.client
            .from('bookings')
            .delete()
            .eq('id', bId)
            .then((_) => debugPrint('Pending booking cleaned up on exit.'))
            .catchError((e) => debugPrint('Error cleaning up pending booking: $e'));
      }
    }

    super.dispose();
  }

  Future<void> _createPendingBooking() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.uid;
    if (userId != null) {
      try {
        final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
        final draft = widget.bookingDraft.copyWith(
          paymentStatus: 'pending',
          paymentMethod: 'paymob',
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

        if (status == 'confirmed' || paymentStatus == 'paid') {
          HapticFeedback.heavyImpact();
          if (mounted) {
            final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
            final updatedBooking = await bookingProvider.getBookingById(bookingId);
            if (updatedBooking != null && mounted) {
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

  Future<void> _startPaymobCheckout() async {
    setState(() => _isPaymobLoading = true);
    await Future.delayed(const Duration(seconds: 1)); // Simulate network load
    setState(() => _isPaymobLoading = false);

    if (!mounted) return;
    
    final amountToPay = widget.bookingDraft.needsDeposit && widget.bookingDraft.depositPaid > 0 
        ? widget.bookingDraft.depositPaid.toInt() 
        : widget.bookingDraft.totalPrice.toInt();

    // ✅ FIXED: Pushing a clean, full-screen route instead of calling showDialog with a Scaffold
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: VSPColors.background,
          appBar: AppBar(
            backgroundColor: VSPColors.background,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white), 
              onPressed: () => Navigator.pop(ctx),
            ),
            title: const Text('Paymob Secure Checkout', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            centerTitle: true,
          ),
          body: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: VSPColors.surface,
                      borderRadius: BorderRadius.circular(VSPRadius.xl),
                      border: Border.all(color: VSPColors.divider),
                    ),
                    child: Column(
                      children: [
                        const Text('PAYMOB', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: VSPColors.accent)),
                        const SizedBox(height: 24),
                        const Text('Total Amount', style: TextStyle(color: VSPColors.textSecondary, fontSize: 14)),
                        Text('$amountToPay EGP', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 32),
                        TextField(
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Card Number', 
                            labelStyle: const TextStyle(color: VSPColors.textSecondary),
                            hintText: '4000 0000 0000 0002', 
                            hintStyle: const TextStyle(color: Colors.white38),
                            filled: true,
                            fillColor: VSPColors.surfaceAlt,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(VSPRadius.md), borderSide: BorderSide.none), 
                            prefixIcon: const Icon(Icons.credit_card, color: VSPColors.accent),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Expiry (MM/YY)', 
                                  labelStyle: const TextStyle(color: VSPColors.textSecondary),
                                  filled: true,
                                  fillColor: VSPColors.surfaceAlt,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(VSPRadius.md), borderSide: BorderSide.none),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextField(
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'CVV', 
                                  labelStyle: const TextStyle(color: VSPColors.textSecondary),
                                  filled: true,
                                  fillColor: VSPColors.surfaceAlt,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(VSPRadius.md), borderSide: BorderSide.none),
                                ),
                                obscureText: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity, 
                          height: 54,
                          child: PrimaryButton(
                            text: 'Pay Securely',
                            onPressed: () async {
                              Navigator.pop(ctx);
                              setState(() => _isPaymobLoading = true);
                              try {
                                if (_booking!.id.startsWith('mock_')) {
                                  final mockConfirmed = _booking!.copyWith(
                                    status: BookingStatus.confirmed,
                                    isPaid: true,
                                    paymentStatus: 'paid',
                                    paymentMethod: 'paymob_test',
                                    paymentTransactionId: 'TEST_${DateTime.now().millisecondsSinceEpoch}',
                                  );
                                  Provider.of<BookingProvider>(context, listen: false).setCurrentBookingForMock(mockConfirmed);
                                } else {
                                  await Supabase.instance.client.from('bookings').update({
                                    'status': 'confirmed', 
                                    'is_paid': true, 
                                    'payment_status': 'paid', 
                                    'payment_method': 'paymob_test', 
                                    'payment_transaction_id': 'TEST_${DateTime.now().millisecondsSinceEpoch}'
                                  }).eq('id', _booking!.id);
                                }
                                
                                HapticFeedback.heavyImpact();
                                if (mounted) {
                                  final updatedBooking = await Provider.of<BookingProvider>(context, listen: false).getBookingById(_booking!.id);
                                  if (updatedBooking != null && mounted) {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(builder: (_) => BookingSuccessScreen(booking: updatedBooking)),
                                    );
                                  }
                                }
                              } catch (_) {
                                setState(() => _isPaymobLoading = false);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Center(child: Text('TEST MODE ENABLED', style: TextStyle(color: VSPColors.warning, fontWeight: FontWeight.bold, letterSpacing: 2))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
              Icon(LucideIcons.alertTriangle, color: VSPColors.error),
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
                  LucideIcons.calendarX,
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
                  text: 'العودة لاختيار وقت آخر',
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final hasDeposit = widget.bookingDraft.needsDeposit && widget.bookingDraft.depositPaid > 0;
    final amountToPay = hasDeposit ? widget.bookingDraft.depositPaid : widget.bookingDraft.totalPrice;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final cancel = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: VSPColors.surface,
            title: Text(isArabic ? 'إلغاء الدفع؟' : 'Cancel Payment?', style: const TextStyle(color: Colors.white)),
            content: Text(isArabic ? 'إذا تراجعت الآن سيتم إلغاء حجزك مؤقتاً.' : 'If you go back now, your temporary booking will be cancelled.', style: const TextStyle(color: VSPColors.textSecondary)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isArabic ? 'استكمال الدفع' : 'Continue Payment', style: const TextStyle(color: VSPColors.accent))),
              TextButton(
                onPressed: () async {
                  if (_booking != null) {
                    await Supabase.instance.client.from('bookings').delete().eq('id', _booking!.id);
                  }
                  if (ctx.mounted) Navigator.pop(ctx, true);
                },
                child: Text(isArabic ? 'تراجع وإلغاء' : 'Cancel Booking', style: const TextStyle(color: VSPColors.error))
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
            icon: const Icon(LucideIcons.chevronLeft, color: VSPColors.textPrimary, size: 20),
            onPressed: () async {
              final cancel = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: VSPColors.surface,
                  title: Text(isArabic ? 'إلغاء الدفع؟' : 'Cancel Payment?', style: const TextStyle(color: Colors.white)),
                  content: Text(isArabic ? 'إذا تراجعت الآن سيتم إلغاء حجزك.' : 'If you go back now, your booking will be cancelled.', style: const TextStyle(color: VSPColors.textSecondary)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isArabic ? 'استكمال الدفع' : 'Continue Payment', style: const TextStyle(color: VSPColors.accent))),
                    TextButton(
                      onPressed: () async {
                        if (_booking != null) {
                          await Supabase.instance.client.from('bookings').delete().eq('id', _booking!.id);
                        }
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      },
                      child: Text(isArabic ? 'إلغاء الحجز' : 'Cancel Booking', style: const TextStyle(color: VSPColors.error))
                    )
                  ]
                )
              );
              if (cancel == true && context.mounted) Navigator.pop(context);
            },
          ),
          centerTitle: true,
          title: Text(l10n.confirmBooking, style: Theme.of(context).textTheme.displaySmall),
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Spacer(),
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: VSPColors.accent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3), width: 2),
                      ),
                      child: const Icon(LucideIcons.shieldCheck, color: VSPColors.accent, size: 44),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      hasDeposit 
                          ? (isArabic ? 'عربون الحجز' : 'Upfront Deposit')
                          : (isArabic ? 'المبلغ الإجمالي المستحق' : 'Total Amount Due'),
                      style: const TextStyle(color: VSPColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${amountToPay.toInt()} ${l10n.egCurrency}',
                      style: const TextStyle(color: VSPColors.accent, fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 24),
                    Container(
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
                              const Icon(LucideIcons.building, color: VSPColors.textSecondary, size: 18),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  widget.bookingDraft.stadiumName,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(LucideIcons.calendar, color: VSPColors.textSecondary, size: 18),
                              const SizedBox(width: 12),
                              Text(
                                DateFormat('yyyy/MM/dd').format(widget.bookingDraft.startTime),
                                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
                              ),
                              const SizedBox(width: 16),
                              const Icon(LucideIcons.clock, color: VSPColors.textSecondary, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('hh:mm a').format(widget.bookingDraft.startTime),
                                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    if (_isLoading || _isPaymobLoading) ...[
                      const CircularProgressIndicator(color: VSPColors.accent),
                      const SizedBox(height: 16),
                      Text(
                        isArabic ? 'جاري تهيئة بوابة الدفع الآمنة...' : 'Initializing secure payment gateway...',
                        style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
                      ),
                    ] else ...[
                      const Icon(LucideIcons.lock, color: VSPColors.textSecondary, size: 16),
                      const SizedBox(height: 8),
                      Text(
                        isArabic ? 'سيتم نقلك الآن لصفحة الدفع الآمنة لإتمام حجزك...' : 'You will be redirected to the secure payment page to complete your booking...',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, height: 1.5),
                      ),
                    ],
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: PrimaryButton(
                        text: isArabic ? 'ادفع الآن' : 'Pay Now',
                        isLoading: _isLoading || _isPaymobLoading,
                        onPressed: (_booking == null) ? null : _startPaymobCheckout,
                      ),
                    ),
                    const SizedBox(height: 24),
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

