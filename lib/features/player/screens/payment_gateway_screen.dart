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
  Booking? _booking;
  StreamSubscription? _bookingSubscription;
  Timer? _webhookTimeoutTimer;
  bool _paymentCompleted = false;

  @override
  void initState() {
    super.initState();
    _createPendingBooking();
  }

  @override
  void dispose() {
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

  /// إنشاء الحجز البدايات بحالة pending و is_paid = false فقط
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

    final amountToPay = widget.bookingDraft.needsDeposit && widget.bookingDraft.depositPaid > 0 
        ? widget.bookingDraft.depositPaid.toInt() 
        : widget.bookingDraft.totalPrice.toInt();

    // 1. في البيئة الفعلية: فتح صفحة Paymob بـ Iframe ID الصحيح من AppConfig
    final paymobUrl = 'https://accept.paymob.com/api/acceptance/iframes/${AppConfig.paymobIframeId}?payment_token=${_booking!.id}';
    final Uri uri = Uri.parse(paymobUrl);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (kDebugMode) {
        // 🔒 خيار الاختبار فقط في وضع التطوير (kDebugMode): محاكاة الـ Webhook بالسيرفر
        await Supabase.instance.client.rpc('simulate_paymob_webhook', params: {
          'p_booking_id': _booking!.id,
          'p_amount': amountToPay,
        });
      } else {
        debugPrint('Paymob URL launch failed in production mode.');
      }
    } catch (e) {
      debugPrint('Paymob Launch / RPC Simulation notice: $e');
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
                onPressed: () async {
                  if (_booking != null && !_booking!.id.startsWith('mock_')) {
                    await Supabase.instance.client.from('bookings').delete().eq('id', _booking!.id);
                  }
                  if (ctx.mounted) Navigator.pop(ctx, true);
                },
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
                      onPressed: () async {
                        if (_booking != null && !_booking!.id.startsWith('mock_')) {
                          await Supabase.instance.client.from('bookings').delete().eq('id', _booking!.id);
                        }
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      },
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
                      child: Icon(
                        isChampionship ? Iconsax.cup_copy : Iconsax.security_safe_copy, 
                        color: VSPColors.accent, 
                        size: 44,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      isChampionship
                          ? (isArabic ? 'رسوم الاشتراك المطلوبة' : 'Entry Fee Required')
                          : (hasDeposit 
                              ? (isArabic ? 'عربون الحجز المطلوب' : 'Upfront Deposit Required')
                              : (isArabic ? 'المبلغ الإجمالي المطلوب' : 'Total Checkout Amount')),
                      style: const TextStyle(color: VSPColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${amountToPay.toInt()} ${l10n.egCurrency}',
                      style: const TextStyle(color: VSPColors.accent, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 20),
                    // 💰 Financial Breakdown Card (3% Net VSP App Commission Model)
                    Builder(
                      builder: (context) {
                        final double netCommission = amountToPay * 0.03;
                        final double totalWithCommission = amountToPay + netCommission;
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
                                      widget.bookingDraft.stadiumName,
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
                                  ? (isArabic ? 'قيمة رسوم اشتراك البطولة' : 'Championship Entry Fee')
                                  : (hasDeposit 
                                      ? (isArabic ? 'قيمة العربون المطلوبة للملعب' : 'Stadium Deposit') 
                                      : (isArabic ? 'إجمالي سعر حجز الملعب' : 'Stadium Total Price')),
                                value: '${amountToPay.toInt()} ج.م',
                                isBold: false,
                              ),
                              const SizedBox(height: 6),
                              _buildFeeRow(
                                label: isArabic ? 'رسوم خدمة المنصة والتشغيل (3%)' : 'Platform Service Fee (3%)',
                                value: '${netCommission.toStringAsFixed(1)} ج.م',
                                isBold: false,
                              ),
                              const SizedBox(height: 6),
                              _buildFeeRow(
                                label: isArabic ? 'المبلغ الإجمالي للسداد أونلاين' : 'Total Checkout Amount',
                                value: '${totalWithCommission.toStringAsFixed(1)} ج.م',
                                isBold: true,
                              ),
                              if (hasDeposit) ...[
                                const SizedBox(height: 6),
                                _buildFeeRow(
                                  label: isArabic ? 'المتبقي وسداده كاش بالملعب' : 'Remaining Pay at Pitch',
                                  value: '${(widget.bookingDraft.totalPrice - amountToPay).toInt()} ج.م',
                                ),
                              ]
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    if (_isLoading || _isAwaitingWebhook) ...[
                      const CircularProgressIndicator(color: VSPColors.accent),
                      const SizedBox(height: 16),
                      Text(
                        isArabic ? 'جاري انتظار تأكيد السيرفر وبوابة الدفع (Webhook)...' : 'Awaiting server webhook confirmation...',
                        style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
                      ),
                      if (_isAwaitingWebhook) ...[
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: () {
                            _webhookTimeoutTimer?.cancel();
                            setState(() => _isAwaitingWebhook = false);
                          },
                          icon: const Icon(Iconsax.close_circle_copy, color: VSPColors.error, size: 16),
                          label: Text(
                            isArabic ? 'إلغاء الانتظار وإعادة المحاولة' : 'Cancel Wait & Retry',
                            style: const TextStyle(color: VSPColors.error, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ] else ...[
                      const Icon(Iconsax.lock_copy, color: VSPColors.textSecondary, size: 16),
                      const SizedBox(height: 8),
                      Text(
                        isArabic ? 'سيتم تحويلك الآن لبوابة Paymob. التأكيد يتطلب رد الـ Webhook الرسمي.' : 'You will be redirected to Paymob. Confirmation relies strictly on Webhook API.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, height: 1.5),
                      ),
                    ],
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: PrimaryButton(
                        text: isArabic ? 'الانتقال للدفع الآمن (Paymob)' : 'Proceed to Paymob',
                        isLoading: _isLoading || _isAwaitingWebhook,
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
}
