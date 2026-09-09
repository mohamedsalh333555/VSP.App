import 'dart:ui';
import 'package:flutter/material.dart';
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
import 'booking_sheet/booking_sheet_details_form.dart';
import 'booking_sheet/booking_sheet_duration_selector.dart';
import 'booking_sheet/booking_sheet_form_fields.dart';
import 'booking_sheet/booking_sheet_header.dart';
import 'booking_sheet/booking_sheet_time_stadium_card.dart';
import 'booking_sheet/owner_booking_sheet_coordinator.dart';
import 'booking_sheet/owner_booking_sheet_service.dart';

export 'booking_sheet/owner_booking_modal.dart';


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

  Future<void> _handleConfirmCashPayment(Booking booking, bool isArabic) =>
      OwnerBookingSheetCoordinator.confirmCashPayment(
        context: context,
        parentContext: widget.parentContext,
        booking: booking,
        selectedStadium: widget.selectedStadium,
        isArabic: isArabic,
        setLoading: (v) => setState(() => _isSaving = v),
      );

  Future<void> _handleExtendOngoingMatch(Booking booking, bool isArabic) =>
      OwnerBookingSheetCoordinator.extendOngoingMatch(
        context: context,
        parentContext: widget.parentContext,
        booking: booking,
        isArabic: isArabic,
        setLoading: (v) => setState(() => _isSaving = v),
      );

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

        final draft = OwnerBookingSheetService.buildManualBookingDraft(
          stadium: stadium,
          uid: uid,
          startTime: startTime,
          endTime: endTime,
          customerName: customerName,
          customerPhone: customerPhone,
          notes: notes,
          totalPrice: totalPrice,
          collectedAmount: collectedAmount,
          playerCount: _playerCount,
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

          final updateMap = OwnerBookingSheetService.buildBookingUpdateMap(
            endTime: endTime,
            customerName: customerName,
            customerPhone: customerPhone,
            notes: notes,
            playerCount: _playerCount,
            collectedAmount: collectedAmount,
            finalTotal: finalTotal,
            originalTotal: booking.totalPrice,
          );

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

  Future<void> _handleCancelBooking(Booking booking, AppLocalizations l10n, bool isArabic) =>
      OwnerBookingSheetCoordinator.cancelBooking(
        context: context,
        parentContext: widget.parentContext,
        booking: booking,
        l10n: l10n,
        isArabic: isArabic,
        setDeleting: (v) => setState(() => _isDeleting = v),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final booking = widget.slot['booking'] as Booking?;
    final flags = OwnerBookingSheetService.resolveStateFlags(
      isEditProp: widget.isEdit,
      booking: booking,
    );

    final modalTitle = OwnerBookingSheetService.getModalTitle(
      isNewSlot: flags.isNewSlot,
      isPastCompleted: flags.isPastCompleted,
      isUpcomingOnlinePaid: flags.isUpcomingOnlinePaid,
      isUpcomingPendingCash: flags.isUpcomingPendingCash,
      isArabic: isArabic,
      manualBookingTitle: l10n.manualBookingTitle,
    );

    final double systemBottomPadding = MediaQuery.of(context).padding.bottom;
    final double keyboardPadding = MediaQuery.of(context).viewInsets.bottom;
    final int maxMins = _getMaxAvailableMinutes();

    final formattedSlotTime = OwnerBookingSheetService.formatSlotTime(
      isEdit: widget.isEdit,
      booking: booking,
      baseDate: widget.baseDate,
      selectedDayIndex: widget.selectedDayIndex,
      slot: widget.slot,
    );

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
          BookingSheetHeader(
            title: modalTitle,
            showDeleteButton: (flags.isOwnerManual && !flags.isPastCompleted) || flags.isUpcomingPendingCash,
            isDeleting: _isDeleting,
            onDelete: () => _handleCancelBooking(booking!, l10n, isArabic),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (flags.isUpcomingOnlinePaid)
                    UpcomingOnlinePaidActions(booking: booking!),
                  if (flags.isOngoingActiveMatch)
                    OngoingMatchBanner(
                      booking: booking!,
                      isSaving: _isSaving,
                      onExtendMatch: () => _handleExtendOngoingMatch(booking, isArabic),
                    ),
                  InputLabel(l10n.timeAndStadium),
                  BookingSheetTimeStadiumCard(formattedTime: formattedSlotTime),
                  const SizedBox(height: 14),
                  InputLabel(isArabic ? "مدة الحجز" : "Booking Duration"),
                  BookingSheetDurationSelector(
                    selectedMinutes: _selectedMinutes,
                    maxMins: maxMins,
                    isCompletedBooking: flags.isPastCompleted,
                    onDurationChanged: (newMins) => setState(() => _selectedMinutes = newMins),
                  ),
                  const SizedBox(height: 14),
                  InputLabel(isArabic ? "عدد اللاعبين الحاضرين (تليفون / خارجي)" : "Joined Players Count"),
                  PlayerCounterField(
                    playerCount: _playerCount,
                    maxPlayers: widget.selectedStadium.playersPerTeam * 2,
                    isReadOnly: flags.isReadOnly,
                    onIncrement: () => setState(() => _playerCount++),
                    onDecrement: () => setState(() => _playerCount--),
                  ),
                  const SizedBox(height: 14),
                  BookingSheetDetailsForm(
                    nameController: _nameController,
                    phoneController: _phoneController,
                    noteController: _noteController,
                    collectedAmountController: _collectedAmountController,
                    isReadOnly: flags.isReadOnly,
                    isArabic: isArabic,
                    customerNameLabel: l10n.customerName,
                    internalNotesLabel: l10n.internalNotes,
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
            isPastCompleted: flags.isPastCompleted,
            isUpcomingPendingCash: flags.isUpcomingPendingCash,
            isUpcomingOnlinePaid: flags.isUpcomingOnlinePaid,
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
