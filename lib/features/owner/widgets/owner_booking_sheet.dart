import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/repositories/owner_repository.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../data/models.dart';
import '../../../l10n/app_localizations.dart';
import 'booking_sheet/booking_sheet_actions.dart';
import 'booking_sheet/booking_sheet_duration_selector.dart';
import 'booking_sheet/booking_sheet_form_fields.dart';
import 'booking_sheet/owner_booking_sheet_service.dart';

/// Shows the dedicated bottom sheet modal for owner booking management.
Future<void> showOwnerBookingModal({
  required BuildContext context,
  required bool isEdit,
  required Map<String, dynamic> slot,
  required Stadium selectedStadium,
  DateTime? baseDate,
  int? selectedDayIndex,
  required BuildContext parentContext,
}) {
  final now = DateTime.now();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (modalContext) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: OwnerBookingSheet(
        isEdit: isEdit,
        slot: slot,
        selectedStadium: selectedStadium,
        baseDate: baseDate ?? now,
        selectedDayIndex: selectedDayIndex ?? 0,
        parentContext: parentContext,
      ),
    ),
  );
}

/// Dedicated bottom sheet modal allowing owners to manually create, inspect,
/// extend, cash-confirm, or update pitch bookings.
class OwnerBookingSheet extends StatefulWidget {
  final bool isEdit;
  final Map<String, dynamic> slot;
  final Stadium selectedStadium;
  final DateTime baseDate;
  final int selectedDayIndex;
  final BuildContext parentContext;

  const OwnerBookingSheet({
    super.key,
    required this.isEdit,
    required this.slot,
    required this.selectedStadium,
    required this.baseDate,
    required this.selectedDayIndex,
    required this.parentContext,
  });

  @override
  State<OwnerBookingSheet> createState() => _OwnerBookingSheetState();
}

class _OwnerBookingSheetState extends State<OwnerBookingSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _noteController;
  late final TextEditingController _collectedAmountController;
  bool _isSaving = false;
  bool _isDeleting = false;
  int _selectedMinutes = 60;
  int _playerCount = 1;

  @override
  void initState() {
    super.initState();
    final booking = widget.slot['booking'] as Booking?;
    _nameController = TextEditingController(text: widget.isEdit ? (widget.slot['name'] ?? '') : '');
    _phoneController = TextEditingController(text: widget.isEdit ? (booking?.playerPhone ?? '') : '');
    _noteController = TextEditingController(text: widget.isEdit ? (booking?.notes ?? '') : '');

    double initialAmount = 0.0;
    if (widget.isEdit && booking != null) {
      initialAmount = booking.depositPaid > 0 ? booking.depositPaid : (booking.isPaid ? booking.totalPrice : 0.0);
      _playerCount = booking.currentPlayers;
    }
    _collectedAmountController = TextEditingController(text: initialAmount == 0.0 ? '' : initialAmount.toStringAsFixed(0));

    if (widget.isEdit && booking != null) {
      _selectedMinutes = booking.endTime.difference(booking.startTime).inMinutes;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    _collectedAmountController.dispose();
    super.dispose();
  }

  int _getMaxAvailableMinutes() {
    List<Booking> bookings = [];
    try {
      final bookingProvider = Provider.of<BookingProvider>(widget.parentContext, listen: false);
      bookings = bookingProvider.userBookings;
    } catch (_) {}

    return OwnerBookingSheetService.calculateMaxAvailableMinutes(
      stadium: widget.selectedStadium,
      slotTime: widget.slot['slotTime'] as DateTime?,
      existingBookings: bookings,
      currentBookingId: (widget.slot['booking'] as Booking?)?.id,
    );
  }

  Future<void> _handleConfirmCashPayment(Booking booking, bool isArabic) async {
    setState(() => _isSaving = true);
    try {
      final parentCtx = widget.parentContext;
      final totalPrice = booking.totalPrice > 0 ? booking.totalPrice : widget.selectedStadium.basePrice;
      final authProvider = Provider.of<AuthProvider>(parentCtx, listen: false);
      final uid = authProvider.currentUser?.uid ?? authProvider.firebaseUser?.uid ?? booking.ownerId;

      final rpcRes = await OwnerRepository().confirmCashBookingAtomic(
        bookingId: booking.id,
        ownerId: uid,
        totalPrice: totalPrice,
      );

      if (rpcRes is Map && rpcRes['success'] == false) {
        throw Exception(rpcRes['message']?.toString() ?? 'Failed to confirm cash payment');
      }

      if (mounted) {
        VSPFeedback.showSuccess(
          context,
          isArabic ? 'تم تأكيد استلام المبلغ بالملعب واكتمال الحجز بنجاح.' : 'Cash payment confirmed at pitch successfully.',
        );
      }
      if (parentCtx.mounted) {
        final auth = Provider.of<AuthProvider>(parentCtx, listen: false);
        final currentUid = auth.currentUser?.uid ?? auth.firebaseUser?.uid;
        if (currentUid != null) {
          await Provider.of<BookingProvider>(parentCtx, listen: false).loadOwnerBookings(currentUid, forceRefresh: true);
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        VSPFeedback.showError(context, '${isArabic ? "تعذر تأكيد الدفع:" : "Failed to confirm cash:"} $e');
      }
    }
  }

  Future<void> _handleExtendOngoingMatch(Booking booking, bool isArabic) async {
    final parentCtx = widget.parentContext;
    final newEndTime = booking.endTime.add(const Duration(minutes: 30));

    setState(() => _isSaving = true);
    try {
      await OwnerRepository().extendBookingEndTime(
        bookingId: booking.id,
        newEndTime: newEndTime,
      );

      if (mounted) {
        VSPFeedback.showSuccess(
          context,
          isArabic ? 'تم تمديد المباراة 30 دقيقة إضافية بنجاح.' : 'Match extended by 30 mins successfully.',
        );
      }
      if (parentCtx.mounted) {
        final auth = Provider.of<AuthProvider>(parentCtx, listen: false);
        final currentUid = auth.currentUser?.uid ?? auth.firebaseUser?.uid;
        if (currentUid != null) {
          await Provider.of<BookingProvider>(parentCtx, listen: false).loadOwnerBookings(currentUid, forceRefresh: true);
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        VSPFeedback.showError(context, '${isArabic ? "تعذر تمديد المباراة:" : "Failed to extend match:"} $e');
      }
    }
  }

  Future<void> _handleConfirmBooking(AppLocalizations l10n, bool isArabic) async {
    final String customerName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : (isArabic ? 'حجز يدوي' : 'Manual Booking');

    setState(() => _isSaving = true);

    try {
      final bookingProvider = Provider.of<BookingProvider>(widget.parentContext, listen: false);
      final authProvider = Provider.of<AuthProvider>(widget.parentContext, listen: false);

      final uid = authProvider.currentUser?.uid ?? authProvider.firebaseUser?.uid;
      if (uid == null) {
        throw Exception(isArabic ? 'انتهت الجلسة، يرجى إعادة تسجيل الدخول' : 'Session expired');
      }

      final stadium = widget.selectedStadium;
      final customerPhone = _phoneController.text.trim();
      final notes = _noteController.text.trim();
      final double collectedAmount = double.tryParse(_collectedAmountController.text.trim()) ?? 0.0;

      if (!widget.isEdit) {
        final selectedDate = widget.baseDate.add(Duration(days: widget.selectedDayIndex));
        final DateTime startTime = (widget.slot['slotTime'] as DateTime?) ??
            DateTime(
              selectedDate.year,
              selectedDate.month,
              selectedDate.day,
              widget.slot['hour'] as int,
              widget.slot['minute'] as int,
            );
        final endTime = startTime.add(Duration(minutes: _selectedMinutes));

        final bookings = bookingProvider.userBookings.where((b) {
          final bStartLocal = b.startTime.toLocal();
          return b.stadiumId.toLowerCase().trim() == stadium.id.toLowerCase().trim() &&
              b.status != BookingStatus.cancelled &&
              bStartLocal.year == selectedDate.year &&
              bStartLocal.month == selectedDate.month &&
              bStartLocal.day == selectedDate.day;
        }).toList();

        if (OwnerBookingSheetService.checkBreakOverlap(
          stadium: stadium,
          startTime: startTime,
          endTime: endTime,
        )) {
          throw Exception(isArabic ? "عذراً، هذا الموعد يتعارض مع فترة استراحة الملعب " : "Booking overlaps with stadium break time ");
        }

        if (OwnerBookingSheetService.checkBookingsOverlap(
          startTime: startTime,
          endTime: endTime,
          bookings: bookings,
        )) {
          throw Exception(isArabic ? "هذا الوقت متداخل مع حجز آخر نشط " : "Time slot overlaps with another booking ");
        }

        final booking = widget.slot['booking'] as Booking?;
        final double totalPrice = OwnerBookingSheetService.calculateBookingPrice(
          stadium: stadium,
          durationMinutes: _selectedMinutes,
          rentBall: booking?.rentBall == true,
          collectedAmount: collectedAmount,
        );

        final draft = BookingDraft(
          stadiumId: stadium.id,
          stadiumName: stadium.name,
          stadiumImageUrl: stadium.imageUrl,
          ownerId: stadium.ownerId.isNotEmpty ? stadium.ownerId : uid,
          startTime: startTime,
          endTime: endTime,
          bookingType: BookingType.personal,
          playerTeamName: customerName,
          playerPhone: customerPhone.isNotEmpty ? PhoneUtils.normalize(customerPhone) : '',
          notes: notes,
          isPrivate: true,
          rentBall: false,
          totalPrice: totalPrice,
          currentPlayers: _playerCount,
          isPaid: collectedAmount >= totalPrice,
          depositPaid: collectedAmount,
          isDepositPaid: collectedAmount > 0,
          paymentStatus: collectedAmount >= totalPrice ? 'paid' : (collectedAmount > 0 ? 'partially_paid' : 'pending'),
          paymentMethod: 'cash',
          paymentTransactionId: 'MANUAL_${DateTime.now().millisecondsSinceEpoch}',
          needsDeposit: false,
        );

        bool rpcSuccess = false;
        try {
          final res = await OwnerRepository().createManualBookingAtomic(
            ownerId: uid,
            stadiumId: stadium.id,
            startTime: startTime,
            endTime: endTime,
            customerName: customerName,
            customerPhone: customerPhone.isNotEmpty ? PhoneUtils.normalize(customerPhone) : null,
            notes: notes.isNotEmpty ? notes : null,
            totalPrice: totalPrice,
            collectedAmount: collectedAmount,
            playerCount: _playerCount,
          );
          if (res != null && res['success'] == true) {
            rpcSuccess = true;
          }
        } catch (_) {
          rpcSuccess = false;
        }

        if (!rpcSuccess) {
          final createdBooking = await bookingProvider.createBooking(draft, uid);
          if (createdBooking == null) {
            final errMsg = bookingProvider.errorMessage ?? (isArabic ? 'عذراً، فشل حفظ الحجز في قاعدة البيانات' : 'Failed to save booking');
            throw Exception(errMsg);
          }
        }
        await bookingProvider.loadOwnerBookings(uid, forceRefresh: true);
      } else {
        final booking = widget.slot['booking'] as Booking?;
        if (booking != null) {
          final startTime = booking.startTime.toLocal();
          final endTime = startTime.add(Duration(minutes: _selectedMinutes));

          final bookings = bookingProvider.userBookings.where((b) {
            final bStartLocal = b.startTime.toLocal();
            return b.id != booking.id &&
                b.stadiumId.toLowerCase().trim() == stadium.id.toLowerCase().trim() &&
                b.status != BookingStatus.cancelled &&
                bStartLocal.year == startTime.year &&
                bStartLocal.month == startTime.month &&
                bStartLocal.day == startTime.day;
          }).toList();

          if (OwnerBookingSheetService.checkBookingsOverlap(
            startTime: startTime,
            endTime: endTime,
            bookings: bookings,
            ignoreBookingId: booking.id,
          )) {
            throw Exception(isArabic ? "مدة الحجز المعدلة تتداخل مع حجز آخر نشط " : "Updated duration overlaps with another active booking ");
          }

          final double calculatedPrice = OwnerBookingSheetService.calculateBookingPrice(
            stadium: stadium,
            durationMinutes: _selectedMinutes,
            rentBall: booking.rentBall,
          );
          final bool isManual = booking.paymentTransactionId?.contains('MANUAL') ?? false;
          final double finalTotal = isManual
              ? (calculatedPrice > 0 ? calculatedPrice : booking.totalPrice)
              : (calculatedPrice > booking.totalPrice ? calculatedPrice : booking.totalPrice);

          final updateMap = <String, dynamic>{
            'end_time': endTime.toUtc().toIso8601String(),
            'player_team_name': customerName,
            'player_phone': customerPhone.isNotEmpty ? PhoneUtils.normalize(customerPhone) : null,
            'notes': notes,
            'current_players': _playerCount,
            'deposit_paid': collectedAmount,
            'is_deposit_paid': collectedAmount > 0,
            'is_paid': collectedAmount >= finalTotal,
            'payment_status': collectedAmount >= finalTotal ? 'paid' : (collectedAmount > 0 ? 'partially_paid' : 'pending'),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          };

          if (finalTotal != booking.totalPrice) {
            updateMap['total_price'] = finalTotal;
          }

          await OwnerRepository().updateBookingDetails(booking.id, updateMap);
          await bookingProvider.loadOwnerBookings(uid);
        }
      }

      if (mounted) {
        final parentCtx = widget.parentContext;
        final nav = Navigator.of(context);
        nav.pop();
        if (parentCtx.mounted) {
          VSPFeedback.showSuccess(
            parentCtx,
            widget.isEdit
                ? (isArabic ? 'تم تحديث تفاصيل وزيادة مدة الحجز بنجاح ' : 'Booking duration updated successfully')
                : (isArabic ? 'تم تأكيد الحجز اليدوي بنجاح ' : 'Manual booking confirmed successfully'),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final cleanErr = OwnerBookingSheetService.formatBookingErrorMessage(e, isArabic: isArabic);
        VSPFeedback.showError(context, cleanErr);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _handleCancelBooking(Booking booking, AppLocalizations l10n, bool isArabic) async {
    final parentCtx = widget.parentContext;
    final nav = Navigator.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        title: Text(l10n.cancelBooking),
        content: Text(l10n.cancelBookingConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancelBtn)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.confirmBtn, style: const TextStyle(color: VSPColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isDeleting = true);
      if (!parentCtx.mounted) return;
      final success = await Provider.of<BookingProvider>(parentCtx, listen: false).cancelBooking(booking.id);
      if (!mounted) return;
      if (!success) {
        final err = Provider.of<BookingProvider>(context, listen: false).errorMessage;
        VSPFeedback.showError(
          context,
          err ?? (isArabic ? 'عذراً، تعذر إلغاء الحجز ' : 'Failed to cancel booking '),
        );
        return;
      }
      if (!parentCtx.mounted) return;
      final uid = Provider.of<AuthProvider>(parentCtx, listen: false).currentUser?.uid;
      if (uid != null) {
        await Provider.of<BookingProvider>(parentCtx, listen: false).loadOwnerBookings(uid, forceRefresh: true);
      }
      if (mounted) nav.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final booking = widget.slot['booking'] as Booking?;
    final now = DateTime.now();

    final bool isEdit = widget.isEdit && booking != null;
    final bool isPastCompleted = isEdit && (now.isAfter(booking.endTime) || booking.status == BookingStatus.completed);
    final bool isManualBooking = isEdit &&
        (booking.paymentTransactionId?.startsWith('MANUAL') == true ||
            (booking.paymentMethod == 'cash' && booking.createdByUserId == booking.ownerId));
    final bool isOnlinePaid = isEdit && !isManualBooking && (booking.isPaid || booking.paymentStatus == 'paid');
    final bool isUpcomingOnlinePaid = isEdit && isOnlinePaid && !isPastCompleted;
    final bool isOwnerManual = isEdit && isManualBooking;
    final bool isUpcomingPendingCash = isEdit && !isOnlinePaid && !isPastCompleted && !isOwnerManual;
    final bool isNewSlot = !widget.isEdit || booking == null;
    final bool isOngoingActiveMatch = isEdit && !isPastCompleted && now.isAfter(booking.startTime) && now.isBefore(booking.endTime);
    final bool isReadOnly = isPastCompleted || isUpcomingOnlinePaid;

    final modalTitle = OwnerBookingSheetService.getModalTitle(
      isNewSlot: isNewSlot,
      isPastCompleted: isPastCompleted,
      isUpcomingOnlinePaid: isUpcomingOnlinePaid,
      isUpcomingPendingCash: isUpcomingPendingCash,
      isArabic: isArabic,
      manualBookingTitle: l10n.manualBookingTitle,
    );

    final double systemBottomPadding = MediaQuery.of(context).padding.bottom;
    final double keyboardPadding = MediaQuery.of(context).viewInsets.bottom;
    final int maxMins = _getMaxAvailableMinutes();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.fromLTRB(
        VSPSpacing.md,
        VSPSpacing.md,
        VSPSpacing.md,
        systemBottomPadding + keyboardPadding + 16,
      ),
      decoration: const BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(VSPRadius.xl),
          topRight: Radius.circular(VSPRadius.xl),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: VSPColors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  modalTitle,
                  style: Theme.of(context).textTheme.displaySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if ((isOwnerManual && !isPastCompleted) || isUpcomingPendingCash)
                IconButton(
                  icon: const Icon(Iconsax.trash_copy, color: VSPColors.error),
                  onPressed: _isDeleting
                      ? null
                      : () => _handleCancelBooking(booking, l10n, isArabic),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isUpcomingOnlinePaid)
                    UpcomingOnlinePaidActions(booking: booking),
                  if (isOngoingActiveMatch)
                    OngoingMatchBanner(
                      booking: booking,
                      isSaving: _isSaving,
                      onExtendMatch: () => _handleExtendOngoingMatch(booking, isArabic),
                    ),
                  InputLabel(l10n.timeAndStadium),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: VSPColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                      border: Border.all(color: VSPColors.divider, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Iconsax.clock_copy, color: VSPColors.accent, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.isEdit && booking != null
                                ? '${DateFormat('hh:mm a').format(booking.startTime.toLocal())} - ${DateFormat('EEEE').format(booking.startTime.toLocal())}'
                                : '${DateFormat('hh:mm a').format(widget.baseDate.add(Duration(days: widget.selectedDayIndex)).add(Duration(hours: widget.slot['hour'] as int, minutes: widget.slot['minute'] as int)))} - ${DateFormat('EEEE').format(widget.baseDate.add(Duration(days: widget.selectedDayIndex)))}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  InputLabel(isArabic ? "مدة الحجز" : "Booking Duration"),
                  BookingSheetDurationSelector(
                    selectedMinutes: _selectedMinutes,
                    maxMins: maxMins,
                    isCompletedBooking: isPastCompleted,
                    onDurationChanged: (newMins) => setState(() => _selectedMinutes = newMins),
                  ),
                  const SizedBox(height: 14),
                  InputLabel(isArabic ? "عدد اللاعبين الحاضرين (تليفون / خارجي)" : "Joined Players Count"),
                  PlayerCounterField(
                    playerCount: _playerCount,
                    maxPlayers: widget.selectedStadium.playersPerTeam * 2,
                    isReadOnly: isReadOnly,
                    onIncrement: () => setState(() => _playerCount++),
                    onDecrement: () => setState(() => _playerCount--),
                  ),
                  const SizedBox(height: 14),
                  InputLabel(l10n.customerName),
                  PillTextField(
                    controller: _nameController,
                    hint: isArabic ? 'اسم الفريق / اللاعب' : 'Customer / Team Name',
                    keyboardType: TextInputType.name,
                    enabled: !isReadOnly,
                  ),
                  const SizedBox(height: 14),
                  InputLabel(isArabic ? "رقم الهاتف" : "Phone Number"),
                  PillTextField(
                    controller: _phoneController,
                    hint: isArabic ? "رقم الهاتف (اختياري)" : "Phone Number (Optional)",
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    enabled: !isReadOnly,
                  ),
                  const SizedBox(height: 14),
                  InputLabel(l10n.internalNotes),
                  PillTextField(
                    controller: _noteController,
                    hint: isArabic ? 'أدخل أي ملاحظات إضافية عن الحجز...' : 'Enter internal notes...',
                    keyboardType: TextInputType.text,
                    enabled: !isReadOnly,
                  ),
                  const SizedBox(height: 14),
                  InputLabel(isArabic ? "المبلغ المحصل (ج.م)" : "Collected Amount (EGP)"),
                  PillTextField(
                    controller: _collectedAmountController,
                    hint: isArabic ? "أدخل المبلغ المحصل (0 للإيجار غير المدفوع)" : "Enter amount (0 for unpaid)",
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))],
                    enabled: !isReadOnly,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          BookingSheetBottomActions(
            booking: booking,
            isEdit: widget.isEdit,
            isPastCompleted: isPastCompleted,
            isUpcomingPendingCash: isUpcomingPendingCash,
            isUpcomingOnlinePaid: isUpcomingOnlinePaid,
            isSaving: _isSaving,
            isDeleting: _isDeleting,
            onConfirmCashPayment: () {
              if (booking != null) _handleConfirmCashPayment(booking, isArabic);
            },
            onCancelBooking: () {
              if (booking != null) _handleCancelBooking(booking, l10n, isArabic);
            },
            onConfirmBooking: () => _handleConfirmBooking(l10n, isArabic),
          ),
        ],
      ),
    );
  }
}
