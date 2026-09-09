import 'package:intl/intl.dart';
import '../../../../core/utils/app_date_formatter.dart';
import '../../../../core/utils/phone_utils.dart';
import '../../../../data/models.dart';

/// Pure domain helper and business logic service for the owner pitch booking sheet.
class OwnerBookingSheetService {
  const OwnerBookingSheetService._();

  /// Calculates maximum allowable duration (in minutes, clamped between 30 and 720)
  /// considering pitch closing time, split-shift break intervals, and subsequent bookings.
  static int calculateMaxAvailableMinutes({
    required Stadium stadium,
    required DateTime? slotTime,
    required List<Booking> existingBookings,
    String? currentBookingId,
  }) {
    if (slotTime == null) return 720; // 12 hours max

    final int slotMin = slotTime.hour * 60 + slotTime.minute;
    int maxMins = 720;

    // 1. Closing time constraint
    final int closingMin = AppDateFormatter.parseTimeToMinutes(stadium.closingTime);
    final int openingMin = AppDateFormatter.parseTimeToMinutes(stadium.openingTime);
    if (openingMin != closingMin) {
      int minsToClosing;
      if (closingMin > slotMin) {
        minsToClosing = closingMin - slotMin;
      } else {
        minsToClosing = (closingMin + 24 * 60) - slotMin;
      }
      if (minsToClosing > 0 && minsToClosing < maxMins) {
        maxMins = minsToClosing;
      }
    }

    // 2. Break time constraint
    if (stadium.isSplitShift) {
      final int bStartMin = AppDateFormatter.parseTimeToMinutes(stadium.breakStartTime);
      final int bEndMin = AppDateFormatter.parseTimeToMinutes(stadium.breakEndTime);
      if (bStartMin != bEndMin) {
        int minsToBreak;
        if (bStartMin > slotMin) {
          minsToBreak = bStartMin - slotMin;
        } else {
          minsToBreak = (bStartMin + 24 * 60) - slotMin;
        }
        if (minsToBreak > 0 && minsToBreak < maxMins) {
          maxMins = minsToBreak;
        }
      }
    }

    // 3. Existing active bookings constraint
    for (final b in existingBookings) {
      if (currentBookingId != null && b.id == currentBookingId) continue;
      if (b.status == BookingStatus.cancelled) continue;
      
      final bStartLocal = b.startTime.toLocal();
      if (bStartLocal.year != slotTime.year ||
          bStartLocal.month != slotTime.month ||
          bStartLocal.day != slotTime.day) {
        continue;
      }

      final int bStartMin = bStartLocal.hour * 60 + bStartLocal.minute;
      if (bStartMin > slotMin) {
        final minsToBooking = bStartMin - slotMin;
        if (minsToBooking < maxMins) {
          maxMins = minsToBooking;
        }
      }
    }

    return maxMins.clamp(30, 720);
  }

  /// Determines whether a proposed interval overlaps with stadium break schedule.
  static bool checkBreakOverlap({
    required Stadium stadium,
    required DateTime startTime,
    required DateTime endTime,
  }) {
    if (!stadium.isSplitShift) return false;

    final int breakStartMin = AppDateFormatter.parseTimeToMinutes(stadium.breakStartTime);
    final int breakEndMin = AppDateFormatter.parseTimeToMinutes(stadium.breakEndTime);
    final int startMin = startTime.hour * 60 + startTime.minute;
    final int endMin = endTime.hour * 60 + endTime.minute;

    if (breakStartMin < breakEndMin) {
      return startMin < breakEndMin && endMin > breakStartMin;
    } else if (breakStartMin != breakEndMin) {
      return startMin >= breakStartMin || endMin > breakStartMin;
    }
    return false;
  }

  /// Determines whether a proposed interval overlaps with any active bookings.
  static bool checkBookingsOverlap({
    required DateTime startTime,
    required DateTime endTime,
    required List<Booking> bookings,
    String? ignoreBookingId,
  }) {
    for (final b in bookings) {
      if (ignoreBookingId != null && b.id == ignoreBookingId) continue;
      if (b.status == BookingStatus.cancelled) continue;

      final bStartLocal = b.startTime.toLocal();
      final bEndLocal = b.endTime.toLocal();

      if (startTime.isBefore(bEndLocal) && endTime.isAfter(bStartLocal)) {
        return true;
      }
    }
    return false;
  }

  /// Calculates total booking price based on hourly rate, duration, and optional ball rental.
  static double calculateBookingPrice({
    required Stadium stadium,
    required int durationMinutes,
    bool rentBall = false,
    double collectedAmount = 0.0,
  }) {
    final double ballFee = rentBall ? stadium.ballPrice : 0.0;
    final double calculatedPrice = (stadium.pricePerHour * (durationMinutes / 60.0)) + ballFee;
    return calculatedPrice > 0 ? calculatedPrice : (collectedAmount > 0 ? collectedAmount : stadium.basePrice);
  }

  /// Cleans and localizes error messages from database constraints or business logic.
  static String formatBookingErrorMessage(dynamic error, {required bool isArabic}) {
    final cleanErr = error.toString();
    final lower = cleanErr.toLowerCase();
    if (lower.contains('prevent_double_booking') || lower.contains('duplicate key value')) {
      return isArabic ? 'هذا الموعد محجوز بالفعل على الملعب! يرجى اختيار موعد آخر.' : 'Time slot is already booked on this stadium!';
    } else if (lower.contains('overlap')) {
      return isArabic ? 'مدة الحجز تتداخل مع حجز آخر نشط على الملعب! يرجى تقليل المدة أو اختيار موعد آخر.' : 'Booking duration overlaps with another active booking!';
    }
    return cleanErr
        .replaceAll('Exception:', '')
        .replaceAll('PostgrestException', '')
        .replaceAll('(message:', '')
        .replaceAll('Failed to create booking:', '')
        .trim();
  }

  /// Returns localized modal title depending on booking lifecycle status.
  static String getModalTitle({
    required bool isNewSlot,
    required bool isPastCompleted,
    required bool isUpcomingOnlinePaid,
    required bool isUpcomingPendingCash,
    required bool isArabic,
    required String manualBookingTitle,
  }) {
    if (isNewSlot) {
      return manualBookingTitle;
    } else if (isPastCompleted) {
      return isArabic ? 'تفاصيل الحجز (مكتمل)' : 'Booking Details (Completed)';
    } else if (isUpcomingOnlinePaid) {
      return isArabic ? 'تفاصيل الحجز (أونلاين مؤكد)' : 'Booking Details (Online Paid)';
    } else if (isUpcomingPendingCash) {
      return isArabic ? 'تفاصيل الحجز (كاش معلق)' : 'Booking Details (Pending Cash)';
    } else {
      return isArabic ? 'تفاصيل الحجز اليدوي' : 'Manual Booking Details';
    }
  }

  /// Builds the BookingDraft model for a manual owner booking.
  static BookingDraft buildManualBookingDraft({
    required Stadium stadium,
    required String uid,
    required DateTime startTime,
    required DateTime endTime,
    required String customerName,
    required String customerPhone,
    required String notes,
    required double totalPrice,
    required double collectedAmount,
    required int playerCount,
  }) {
    return BookingDraft(
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
      currentPlayers: playerCount,
      isPaid: collectedAmount >= totalPrice,
      depositPaid: collectedAmount,
      isDepositPaid: collectedAmount > 0,
      paymentStatus: collectedAmount >= totalPrice
          ? 'paid'
          : (collectedAmount > 0 ? 'partially_paid' : 'pending'),
      paymentMethod: 'cash',
      paymentTransactionId: 'MANUAL_${DateTime.now().millisecondsSinceEpoch}',
      needsDeposit: false,
    );
  }

  /// Builds the update map for updating an existing booking.
  static Map<String, dynamic> buildBookingUpdateMap({
    required DateTime endTime,
    required String customerName,
    required String customerPhone,
    required String notes,
    required int playerCount,
    required double collectedAmount,
    required double finalTotal,
    required double originalTotal,
  }) {
    final updateMap = <String, dynamic>{
      'end_time': endTime.toUtc().toIso8601String(),
      'player_team_name': customerName,
      'player_phone': customerPhone.isNotEmpty ? PhoneUtils.normalize(customerPhone) : null,
      'notes': notes,
      'current_players': playerCount,
      'deposit_paid': collectedAmount,
      'is_deposit_paid': collectedAmount > 0,
      'is_paid': collectedAmount >= finalTotal,
      'payment_status': collectedAmount >= finalTotal
          ? 'paid'
          : (collectedAmount > 0 ? 'partially_paid' : 'pending'),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (finalTotal != originalTotal) {
      updateMap['total_price'] = finalTotal;
    }

    return updateMap;
  }

  /// Evaluates and groups state flags for UI rendering and interactions.
  static BookingSheetStateFlags resolveStateFlags({
    required bool isEditProp,
    required Booking? booking,
    DateTime? now,
  }) {
    final currentNow = now ?? DateTime.now();
    final bool isEdit = isEditProp && booking != null;
    final bool isPastCompleted = isEdit &&
        (currentNow.isAfter(booking.endTime) || booking.status == BookingStatus.completed);
    final bool isManualBooking = isEdit &&
        (booking.paymentTransactionId?.startsWith('MANUAL') == true ||
            (booking.paymentMethod == 'cash' && booking.createdByUserId == booking.ownerId));
    final bool isOnlinePaid = isEdit && !isManualBooking && (booking.isPaid || booking.paymentStatus == 'paid');
    final bool isUpcomingOnlinePaid = isEdit && isOnlinePaid && !isPastCompleted;
    final bool isOwnerManual = isEdit && isManualBooking;
    final bool isUpcomingPendingCash = isEdit && !isOnlinePaid && !isPastCompleted && !isOwnerManual;
    final bool isNewSlot = !isEditProp || booking == null;
    final bool isOngoingActiveMatch = isEdit && !isPastCompleted && currentNow.isAfter(booking.startTime) && currentNow.isBefore(booking.endTime);
    final bool isReadOnly = isPastCompleted || isUpcomingOnlinePaid;

    return BookingSheetStateFlags(
      isEdit: isEdit,
      isPastCompleted: isPastCompleted,
      isManualBooking: isManualBooking,
      isOnlinePaid: isOnlinePaid,
      isUpcomingOnlinePaid: isUpcomingOnlinePaid,
      isOwnerManual: isOwnerManual,
      isUpcomingPendingCash: isUpcomingPendingCash,
      isNewSlot: isNewSlot,
      isOngoingActiveMatch: isOngoingActiveMatch,
      isReadOnly: isReadOnly,
    );
  }

  /// Formats the header slot time string.
  static String formatSlotTime({
    required bool isEdit,
    required Booking? booking,
    required DateTime baseDate,
    required int selectedDayIndex,
    required Map<String, dynamic> slot,
  }) {
    if (isEdit && booking != null) {
      final local = booking.startTime.toLocal();
      return '${DateFormat('hh:mm a').format(local)} - ${DateFormat('EEEE').format(local)}';
    }
    final targetDate = baseDate.add(Duration(days: selectedDayIndex));
    final start = targetDate.add(Duration(
      hours: slot['hour'] as int,
      minutes: slot['minute'] as int,
    ));
    return '${DateFormat('hh:mm a').format(start)} - ${DateFormat('EEEE').format(targetDate)}';
  }
}

/// Holds all evaluated state flags for the booking sheet modal.
class BookingSheetStateFlags {
  final bool isEdit;
  final bool isPastCompleted;
  final bool isManualBooking;
  final bool isOnlinePaid;
  final bool isUpcomingOnlinePaid;
  final bool isOwnerManual;
  final bool isUpcomingPendingCash;
  final bool isNewSlot;
  final bool isOngoingActiveMatch;
  final bool isReadOnly;

  const BookingSheetStateFlags({
    required this.isEdit,
    required this.isPastCompleted,
    required this.isManualBooking,
    required this.isOnlinePaid,
    required this.isUpcomingOnlinePaid,
    required this.isOwnerManual,
    required this.isUpcomingPendingCash,
    required this.isNewSlot,
    required this.isOngoingActiveMatch,
    required this.isReadOnly,
  });
}

