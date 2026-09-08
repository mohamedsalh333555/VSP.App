import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/repositories/owner_repository.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../core/utils/app_date_formatter.dart';
import '../../../core/utils/vsp_quick_booking_receipt_formatter.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../data/models.dart';

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
      VSPFeedback.showError(context, isAr ? 'يرجى كتابة اسم العميل (مثال: كابتن زياد)' : 'Please enter customer name');
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

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final ownerId = authProvider.currentUser?.uid ?? widget.stadium.ownerId;
      final bookingRef = 'MAN_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      final cleanPhone = rawPhone.isNotEmpty ? PhoneUtils.normalize(rawPhone) : null;
      final paidAmount = _currentPaidAmount;
      final totalPrice = _totalPrice;
      final isFullyPaid = _isFullyPaid;
      final isPartiallyPaid = _isPartiallyPaid;

      final newBooking = {
        'stadium_id': widget.stadium.id,
        'stadium_name': widget.stadium.name,
        'owner_id': ownerId,
        'user_id': ownerId,
        'created_by_user_id': ownerId,
        'host_name': customerName,
        'player_phone': cleanPhone,
        'start_time': widget.startTime.toUtc().toIso8601String(),
        'end_time': _effectiveEndTime.toUtc().toIso8601String(),
        'status': 'confirmed',
        'is_paid': isFullyPaid,
        'payment_status': isFullyPaid ? 'paid' : (isPartiallyPaid ? 'partially_paid' : 'pending'),
        'payment_method': 'cash',
        'total_price': totalPrice,
        'deposit_paid': paidAmount,
        'is_deposit_paid': paidAmount > 0,
        'booking_type': 'personal',
        'is_private': true,
        'payment_transaction_id': 'MANUAL_PHONE_$bookingRef',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      final response = await OwnerRepository().insertManualPhoneBooking(newBooking);

      final createdBookingId = response['id']?.toString() ?? bookingRef;

      if (!mounted) return;
      HapticFeedback.lightImpact();

      // Refresh bookings in provider immediately
      Provider.of<BookingProvider>(context, listen: false).loadOwnerBookings(ownerId);

      // Dismiss modal
      Navigator.pop(context, true);

      // If phone was provided, prompt WhatsApp receipt dialog, otherwise show direct success toast
      if (cleanPhone != null && cleanPhone.isNotEmpty) {
        _showReceiptActionDialog(
          context: context,
          bookingRef: createdBookingId.length >= 8 ? createdBookingId.substring(0, 8).toUpperCase() : createdBookingId,
          customerName: customerName,
          customerPhone: cleanPhone,
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
        if (err.contains('prevent_double_booking') || err.contains('duplicate')) {
          VSPFeedback.showError(context, isAr ? 'هذا الموعد تم حجزه للتو من لاعب آخر' : 'This slot was just booked by another player');
        } else {
          VSPFeedback.showError(context, isAr ? 'حدث خطأ أثناء حفظ الحجز' : 'Failed to save phone booking');
        }
      }
    }
  }

  void _showReceiptActionDialog({
    required BuildContext context,
    required String bookingRef,
    required String customerName,
    required String customerPhone,
    required double totalPrice,
    required double paidAmount,
    required bool isAr,
  }) {
    final receiptMsg = VSPQuickBookingReceiptFormatter.buildReceiptMessage(
      stadiumName: widget.stadium.name,
      bookingRef: bookingRef,
      customerName: customerName,
      startTime: widget.startTime,
      endTime: _effectiveEndTime,
      totalPrice: totalPrice,
      depositPaid: paidAmount,
      googleMapsUrl: widget.stadium.googleMapsUrl,
      stadiumPhone: widget.stadium.phone,
      isArabic: isAr,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          padding: const EdgeInsets.all(VSPSpacing.lg),
          decoration: const BoxDecoration(
            color: VSPColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: VSPColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),

              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: VSPColors.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Iconsax.tick_circle_copy, color: VSPColors.accent, size: 30),
              ),
              const SizedBox(height: 12),

              Text(
                isAr ? 'تم تأكيد الحجز بنجاح!' : 'Booking Confirmed!',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 6),

              Text(
                isAr 
                    ? 'هل تود إرسال إيصال وتفاصيل الحجز للكابتن $customerName عبر واتساب؟'
                    : 'Would you like to send WhatsApp confirmation receipt to $customerName?',
                textAlign: TextAlign.center,
                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),

              PrimaryButton(
                text: isAr ? 'إرسال إيصال الحجز عبر واتساب' : 'Send WhatsApp Receipt',
                height: 48,
                icon: Iconsax.message_copy,
                onPressed: () async {
                  Navigator.pop(sheetCtx);
                  await VSPQuickBookingReceiptFormatter.sendReceiptToCustomer(
                    context: context,
                    phone: customerPhone,
                    receiptMessage: receiptMsg,
                  );
                },
              ),
              const SizedBox(height: 10),

              TextButton(
                onPressed: () => Navigator.pop(sheetCtx),
                child: Text(
                  isAr ? 'تم / إغلاق' : 'Done / Close',
                  style: const TextStyle(color: VSPColors.textSecondary),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDurationLabel(int minutes, bool isAr) {
    if (minutes == 30) return isAr ? 'نصف ساعة (30 د)' : '30 Mins';
    if (minutes == 60) return isAr ? 'ساعة (60 د)' : '1 Hour';
    if (minutes == 90) return isAr ? 'ساعة ونصف (90 د)' : '1.5 Hours';
    if (minutes == 120) return isAr ? 'ساعتان (120 د)' : '2 Hours';
    if (minutes == 150) return isAr ? 'ساعتان ونصف' : '2.5 Hours';
    if (minutes == 180) return isAr ? '3 ساعات' : '3 Hours';
    if (minutes == 240) return isAr ? '4 ساعات' : '4 Hours';
    final double hours = minutes / 60.0;
    final str = hours == hours.toInt() ? '${hours.toInt()}' : hours.toStringAsFixed(1);
    return isAr ? '$str ساعة' : '$str Hours';
  }

  Widget _buildDurationChip(int minutes, String label, {bool isExpanded = false}) {
    final isSelected = _selectedDurationMinutes == minutes;
    final widgetChild = GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedDurationMinutes = minutes;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? VSPColors.accent : const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(VSPRadius.full),
          border: Border.all(
            color: isSelected ? VSPColors.accent : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ),
    );

    if (isExpanded) {
      return Expanded(child: widgetChild);
    }
    return widgetChild;
  }

  Widget _buildQuickAmountChip({
    required String label,
    required double amount,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => _setPaidAmount(amount),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? VSPColors.accent : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(VSPRadius.full),
          border: Border.all(
            color: isSelected ? VSPColors.accent : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  String _getObstacleHelperText(bool isAr) {
    final hours = widget.maxAvailableMinutes / 60.0;
    final hoursStr = hours == hours.toInt() ? '${hours.toInt()}' : hours.toStringAsFixed(1);
    final nextTimeStr = widget.nextObstacleTime != null
        ? AppDateFormatter.formatTime(widget.nextObstacleTime!.toLocal(), isAr ? 'ar' : 'en')
        : '';

    if (widget.nextObstacleType == 'break') {
      return isAr 
          ? 'المتاح حتى فترة الراحة: $hoursStr ساعة${nextTimeStr.isNotEmpty ? ' (حتى $nextTimeStr)' : ''}'
          : 'Available until Break Time: $hoursStr hrs${nextTimeStr.isNotEmpty ? ' (until $nextTimeStr)' : ''}';
    } else if (widget.nextObstacleType == 'booking') {
      return isAr 
          ? 'المتاح قبل الحجز التالي: $hoursStr ساعة${nextTimeStr.isNotEmpty ? ' (حتى $nextTimeStr)' : ''}'
          : 'Available before next booking: $hoursStr hrs${nextTimeStr.isNotEmpty ? ' (until $nextTimeStr)' : ''}';
    } else if (widget.nextObstacleType == 'closing') {
      return isAr 
          ? 'المتاح حتى نهاية ساعات العمل: $hoursStr ساعة${nextTimeStr.isNotEmpty ? ' (حتى $nextTimeStr)' : ''}'
          : 'Available until closing: $hoursStr hrs${nextTimeStr.isNotEmpty ? ' (until $nextTimeStr)' : ''}';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final dateStr = AppDateFormatter.formatDayMonth(widget.date, isAr ? 'ar' : 'en');
    final startTimeStr = AppDateFormatter.formatTime(widget.startTime.toLocal(), isAr ? 'ar' : 'en');
    final endTimeStr = AppDateFormatter.formatTime(_effectiveEndTime.toLocal(), isAr ? 'ar' : 'en');
    final dynamicSlotWindow = '$startTimeStr - $endTimeStr';
    final availableDurations = _availableDurations;
    final obstacleText = _getObstacleHelperText(isAr);

    final totalPrice = _totalPrice;
    final paidAmount = _currentPaidAmount;
    final isFullyPaid = _isFullyPaid;
    final isPartiallyPaid = _isPartiallyPaid;
    final remaining = _remainingBalance;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(VSPSpacing.lg),
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
              // Clean Minimalist Title (Option 2)
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

              // Duration Selector Chips
              Text(
                isAr ? 'مدة الحجز (عدد الساعات)' : 'Booking Duration',
                style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // Evenly spaced chips if <= 3, otherwise horizontally scrollable
              if (availableDurations.length <= 3)
                Row(
                  children: availableDurations.map((mins) {
                    final index = availableDurations.indexOf(mins);
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: isAr ? (index > 0 ? 6 : 0) : 0,
                          left: isAr ? 0 : (index > 0 ? 6 : 0),
                        ),
                        child: _buildDurationChip(mins, _formatDurationLabel(mins, isAr)),
                      ),
                    );
                  }).toList(),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: availableDurations.map((mins) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildDurationChip(mins, _formatDurationLabel(mins, isAr)),
                      );
                    }).toList(),
                  ),
                ),

              // Obstacle warning note if any
              if (obstacleText.isNotEmpty && widget.maxAvailableMinutes <= 360) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        widget.nextObstacleType == 'break' ? Iconsax.coffee_copy : Iconsax.clock_copy,
                        color: VSPColors.accent,
                        size: 13,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          obstacleText,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Customer Name
              Text(
                isAr ? 'اسم العميل / الكابتن *' : 'Captain Name *',
                style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              CustomTextField(
                controller: _customerNameController,
                hintText: isAr ? 'مثال: كابتن زياد' : 'e.g. Captain Ziad',
                prefixIcon: Iconsax.user_copy,
              ),
              const SizedBox(height: 14),

              // Customer WhatsApp Phone (Optional)
              Text(
                isAr ? 'رقم الواتساب (لإرسال إيصال الحجز)' : 'WhatsApp Phone (for receipt)',
                style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              CustomTextField(
                controller: _phoneController,
                hintText: '010xxxxxxxxx',
                prefixIcon: Iconsax.call_copy,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),

              // Payment & Received Amount Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isAr ? 'المبلغ المستلم / المدفوع (ج.م)' : 'Amount Received (EGP)',
                    style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(VSPRadius.full),
                    ),
                    child: Text(
                      '${isAr ? "الإجمالي" : "Total"}: ${totalPrice.toInt()} ${isAr ? "ج.م" : "EGP"}',
                      style: const TextStyle(
                        color: VSPColors.accent,
                        fontWeight: FontWeight.w900,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Quick Amount Selection Chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildQuickAmountChip(
                    label: isAr ? '0 (كاش عند الحضور)' : '0 (Cash on Arrival)',
                    amount: 0,
                    isSelected: paidAmount == 0,
                  ),
                  if (totalPrice >= 100)
                    _buildQuickAmountChip(
                      label: isAr ? '50 ج.م' : '50 EGP',
                      amount: 50,
                      isSelected: paidAmount == 50,
                    ),
                  if (totalPrice >= 200)
                    _buildQuickAmountChip(
                      label: isAr ? '100 ج.م' : '100 EGP',
                      amount: 100,
                      isSelected: paidAmount == 100,
                    ),
                  _buildQuickAmountChip(
                    label: '${isAr ? "دفع كامل" : "Full"}: ${totalPrice.toInt()} ${isAr ? "ج" : ""}',
                    amount: totalPrice,
                    isSelected: paidAmount == totalPrice,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Custom Paid Amount Input
              CustomTextField(
                controller: _paidAmountController,
                hintText: '0',
                prefixIcon: Iconsax.wallet_check_copy,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),

              // Real-time Status Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isFullyPaid
                      ? VSPColors.accent.withValues(alpha: 0.12)
                      : (isPartiallyPaid ? const Color(0xFF38BDF8).withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.04)),
                  borderRadius: BorderRadius.circular(VSPRadius.md),
                  border: Border.all(
                    color: isFullyPaid
                        ? VSPColors.accent.withValues(alpha: 0.3)
                        : (isPartiallyPaid ? const Color(0xFF38BDF8).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.08)),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isFullyPaid
                          ? Iconsax.tick_circle_copy
                          : (isPartiallyPaid ? Iconsax.receipt_2_copy : Iconsax.money_copy),
                      color: isFullyPaid
                          ? VSPColors.accent
                          : (isPartiallyPaid ? const Color(0xFF38BDF8) : VSPColors.textSecondary),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isFullyPaid
                            ? (isAr ? 'تم دفع الحجز بالكامل مسبقاً (${totalPrice.toInt()} ج.م)' : 'Fully Paid in Advance (${totalPrice.toInt()} EGP)')
                            : (isPartiallyPaid
                                ? (isAr ? 'عربون مسدد: ${paidAmount.toInt()} ج.م • المتبقي عند الحضور: ${remaining.toInt()} ج.م' : 'Deposit: ${paidAmount.toInt()} EGP • Remaining: ${remaining.toInt()} EGP')
                                : (isAr ? 'حجز كاش مؤكد • التحصيل بالكامل عند الحضور (${totalPrice.toInt()} ج.م)' : 'Cash Booking • Collect ${totalPrice.toInt()} EGP on arrival')),
                        style: TextStyle(
                          color: isFullyPaid
                              ? VSPColors.accent
                              : (isPartiallyPaid ? const Color(0xFF38BDF8) : Colors.white70),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
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
