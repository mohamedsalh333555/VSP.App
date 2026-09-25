import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/repositories/owner_repository.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/app_date_formatter.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../data/models.dart';
import '../../../shared/widgets/primary_button.dart';
import 'quick_booking/quick_booking_customer_fields.dart';
import 'quick_booking/quick_booking_duration_section.dart';
import 'quick_booking/quick_booking_payment_section.dart';
import 'quick_booking/quick_booking_receipt_sheet.dart';

class QuickPhoneBookingModal extends StatefulWidget {
  final Stadium stadium;
  final DateTime date;
  final String slotTime; // e.g. "08:00 PM - 09:00 PM"
  final DateTime startTime;
  final DateTime endTime;
  final double defaultPrice;
  final int maxAvailableMinutes;
  final String nextObstacleType; // 'break', 'booking', 'closing', 'none'
  final DateTime? nextObstacleTime;

  const QuickPhoneBookingModal({
    super.key,
    required this.stadium,
    required this.date,
    required this.slotTime,
    required this.startTime,
    required this.endTime,
    required this.defaultPrice,
    this.maxAvailableMinutes = 240,
    this.nextObstacleType = 'none',
    this.nextObstacleTime,
  });

  static Future<bool?> show(
    BuildContext context, {
    required Stadium stadium,
    required DateTime date,
    required String slotTime,
    required DateTime startTime,
    required DateTime endTime,
    required double defaultPrice,
    int maxAvailableMinutes = 240,
    String nextObstacleType = 'none',
    DateTime? nextObstacleTime,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickPhoneBookingModal(
        stadium: stadium,
        date: date,
        slotTime: slotTime,
        startTime: startTime,
        endTime: endTime,
        defaultPrice: defaultPrice,
        maxAvailableMinutes: maxAvailableMinutes,
        nextObstacleType: nextObstacleType,
        nextObstacleTime: nextObstacleTime,
      ),
    );
  }

  @override
  State<QuickPhoneBookingModal> createState() => _QuickPhoneBookingModalState();
}

class _QuickPhoneBookingModalState extends State<QuickPhoneBookingModal> {
  final _customerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _paidAmountController = TextEditingController(text: '0');

  int _selectedDurationMinutes = 60;
  bool _isSaving = false;

  List<int> get _availableDurations {
    final allStandard = [60, 90, 120, 150, 180, 240];
    if (widget.maxAvailableMinutes < 60) {
      return [widget.maxAvailableMinutes];
    }
    final list = allStandard.where((mins) => mins <= widget.maxAvailableMinutes).toList();
    if (!list.contains(widget.maxAvailableMinutes) && widget.maxAvailableMinutes > 0 && widget.maxAvailableMinutes <= 360) {
      list.add(widget.maxAvailableMinutes);
      list.sort();
    }
    return list.isNotEmpty ? list : [60];
  }

  @override
  void initState() {
    super.initState();
    final available = _availableDurations;
    final initialDuration = widget.endTime.difference(widget.startTime).inMinutes;
    if (available.contains(initialDuration)) {
      _selectedDurationMinutes = initialDuration;
    } else {
      _selectedDurationMinutes = available.contains(60) ? 60 : available.first;
    }
    _paidAmountController.addListener(_onPaidAmountChanged);
  }

  void _onPaidAmountChanged() {
    if (mounted) setState(() {});
  }

  DateTime get _effectiveEndTime => widget.startTime.add(Duration(minutes: _selectedDurationMinutes));
  double get _totalPrice => (widget.defaultPrice * (_selectedDurationMinutes / 60.0));

  double get _currentPaidAmount {
    final text = _paidAmountController.text.trim();
    if (text.isEmpty) return 0.0;
    return double.tryParse(text) ?? 0.0;
  }

  bool get _isFullyPaid => _currentPaidAmount >= _totalPrice && _totalPrice > 0;
  bool get _isPartiallyPaid => _currentPaidAmount > 0 && !_isFullyPaid;
  double get _remainingBalance => (_totalPrice - _currentPaidAmount).clamp(0.0, _totalPrice);

  @override
  void dispose() {
    _paidAmountController.removeListener(_onPaidAmountChanged);
    _customerNameController.dispose();
    _phoneController.dispose();
    _paidAmountController.dispose();
    super.dispose();
  }

  void _setPaidAmount(double amount) {
    HapticFeedback.selectionClick();
    _paidAmountController.text = amount == amount.toInt() ? '${amount.toInt()}' : '$amount';
  }

  Future<void> _handleQuickBooking() async {
    if (_isSaving) return;

    final customerName = _customerNameController.text.trim();
    final rawPhone = _phoneController.text.trim();
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    if (customerName.isEmpty) {
      HapticFeedback.vibrate();
      VSPFeedback.showError(context, isAr ? 'يرجى إدخال اسم العميل أو الكابتن' : 'Please enter customer or captain name');
      return;
    }

    if (_selectedDurationMinutes > widget.maxAvailableMinutes) {
      HapticFeedback.vibrate();
      VSPFeedback.showError(
        context,
        isAr ? 'المدة المختارة تتجاوز الوقت المتاح قبل فترة الراحة أو الحجز التالي' : 'Selected duration exceeds available consecutive time',
      );
      return;
    }

    final paidAmount = _currentPaidAmount;
    final totalPrice = _totalPrice;

    if (paidAmount > totalPrice) {
      HapticFeedback.vibrate();
      VSPFeedback.showError(
        context,
        isAr
            ? 'المبلغ المقبوض (${paidAmount.toInt()} ج.م) لا يمكن أن يتجاوز إجمالي سعر الحجز (${totalPrice.toInt()} ج.م)'
            : 'Collected amount cannot exceed total booking price',
      );
      return;
    }

    if (rawPhone.isNotEmpty) {
      final digitsOnly = rawPhone.replaceAll(RegExp(r'\D'), '');
      if (digitsOnly.length < 10) {
        HapticFeedback.vibrate();
        VSPFeedback.showError(
          context,
          isAr
              ? 'يرجى إدخال رقم هاتف صحيح (11 رقماً) لإرسال الوصل، أو اترك الحقل فارغاً'
              : 'Please enter a valid phone number or leave blank',
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final ownerId = authProvider.currentUser?.uid ?? widget.stadium.ownerId;
      final bookingRef = 'MAN_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      final cleanPhone = rawPhone.isNotEmpty ? PhoneUtils.normalize(rawPhone) : null;

      final response = await OwnerRepository().createManualBookingAtomic(
        ownerId: ownerId,
        stadiumId: widget.stadium.id,
        startTime: widget.startTime,
        endTime: _effectiveEndTime,
        customerName: customerName,
        customerPhone: cleanPhone,
        totalPrice: totalPrice,
        collectedAmount: paidAmount,
        playerCount: 1,
      );

      if (response is Map && response['success'] == false) {
        throw Exception(response['message']?.toString() ?? (isAr ? 'تعذر حفظ الحجز' : 'Failed to save booking'));
      }

      final createdBookingId = response?['booking_id']?.toString() ?? response?['id']?.toString() ?? bookingRef;

      if (!mounted) return;
      HapticFeedback.lightImpact();

      // Refresh bookings in provider immediately
      Provider.of<BookingProvider>(context, listen: false).loadOwnerBookings(ownerId);

      // Dismiss modal
      Navigator.pop(context, true);

      // If phone was provided, prompt WhatsApp receipt dialog, otherwise show direct success toast
      if (cleanPhone != null && cleanPhone.isNotEmpty) {
        showQuickBookingReceiptSheet(
          context: context,
          stadium: widget.stadium,
          bookingRef: createdBookingId.length >= 8 ? createdBookingId.substring(0, 8).toUpperCase() : createdBookingId,
          customerName: customerName,
          customerPhone: cleanPhone,
          startTime: widget.startTime,
          endTime: _effectiveEndTime,
          totalPrice: totalPrice,
          paidAmount: paidAmount,
          isAr: isAr,
        );
      } else {
        VSPFeedback.showSuccess(
          context,
          isAr ? 'تم تأكيد حجز $customerName بنجاح' : 'Booking confirmed for $customerName',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        final err = e.toString().toLowerCase();
        final isAr = Localizations.localeOf(context).languageCode == 'ar';
        if (err.contains('prevent_double_booking') || err.contains('duplicate') || err.contains('conflict') || err.contains('slot_locked_or_taken')) {
          VSPFeedback.showError(context, isAr ? 'هذا الموعد تم حجزه للتو من لاعب آخر' : 'This slot was just booked by another player');
        } else if (err.contains('invalid_collected_amount')) {
          VSPFeedback.showError(context, isAr ? 'المبلغ المحصل غير صالح أو يتجاوز السعر الإجمالي للمباراة' : 'Invalid collected amount');
        } else if (err.contains('start_time_in_past')) {
          VSPFeedback.showError(context, isAr ? 'هذا الموعد انقضى وقته بالفعل، يرجى اختيار موعد قادم' : 'Slot time has already passed');
        } else if (err.contains('unauthorized') || err.contains('owner_mismatch')) {
          VSPFeedback.showError(context, isAr ? 'غير مصرح لك، يرجى إعادة تسجيل الدخول' : 'Unauthorized operation');
        } else {
          final cleanMsg = e.toString().replaceAll('Exception:', '').trim();
          VSPFeedback.showError(context, cleanMsg.isNotEmpty ? cleanMsg : (isAr ? 'حدث خطأ أثناء حفظ الحجز' : 'Failed to save phone booking'));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final dateStr = AppDateFormatter.formatDayMonth(widget.date, isAr ? 'ar' : 'en');
    final startTimeStr = AppDateFormatter.formatTime(widget.startTime.toLocal(), isAr ? 'ar' : 'en');
    final endTimeStr = AppDateFormatter.formatTime(_effectiveEndTime.toLocal(), isAr ? 'ar' : 'en');
    final dynamicSlotWindow = '$startTimeStr - $endTimeStr';
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.only(
        bottom: bottomInset,
      ),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          VSPSpacing.lg,
          VSPSpacing.lg,
          VSPSpacing.lg,
          bottomInset > 0 ? VSPSpacing.md : (bottomPadding > 0 ? bottomPadding + 16 : 24),
        ),
        decoration: const BoxDecoration(
          color: VSPColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
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
              Text(
                isAr ? 'حجز يدوي' : 'Manual Booking',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),

              // Unified Subtitle Line
              Row(
                children: [
                  const Icon(Iconsax.location_copy, color: VSPColors.textSecondary, size: 13),
                  const SizedBox(width: 4),
                  Text(
                    widget.stadium.name,
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 6),
                  const Text('•', style: TextStyle(color: VSPColors.textSecondary, fontSize: 12)),
                  const SizedBox(width: 6),
                  Text(
                    dateStr,
                    style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(width: 6),
                  const Text('•', style: TextStyle(color: VSPColors.textSecondary, fontSize: 12)),
                  const SizedBox(width: 6),
                  Text(
                    dynamicSlotWindow,
                    style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Duration Selector
              QuickBookingDurationSection(
                availableDurations: _availableDurations,
                selectedDurationMinutes: _selectedDurationMinutes,
                onDurationChanged: (mins) => setState(() => _selectedDurationMinutes = mins),
                maxAvailableMinutes: widget.maxAvailableMinutes,
                nextObstacleType: widget.nextObstacleType,
                nextObstacleTime: widget.nextObstacleTime,
              ),
              const SizedBox(height: 16),

              // Customer Inputs
              QuickBookingCustomerFields(
                customerNameController: _customerNameController,
                phoneController: _phoneController,
              ),
              const SizedBox(height: 16),

              // Payment Section
              QuickBookingPaymentSection(
                paidAmountController: _paidAmountController,
                totalPrice: _totalPrice,
                currentPaidAmount: _currentPaidAmount,
                isFullyPaid: _isFullyPaid,
                isPartiallyPaid: _isPartiallyPaid,
                remainingBalance: _remainingBalance,
                onSelectQuickAmount: _setPaidAmount,
              ),
              const SizedBox(height: 20),

              // Submit Button
              PrimaryButton(
                text: isAr ? 'تأكيد الحجز الفوري' : 'Confirm Instant Booking',
                height: 52,
                isLoading: _isSaving,
                onPressed: _handleQuickBooking,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
