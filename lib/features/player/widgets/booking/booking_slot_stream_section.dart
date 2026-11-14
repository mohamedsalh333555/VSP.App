import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import '../../../../core/providers/booking_provider.dart';
import '../../../../core/services/vsp_time_service.dart';
import '../../../../core/ui/vsp_ui.dart';
import '../../../../data/models.dart';
import 'booking_slot_calculator.dart';
import 'booking_slot_card.dart';
import 'booking_slot_models.dart';
import 'booking_stream_freshness.dart';

/// Renders the real-time slot grid for [BookingConfirmationScreen].
///
/// Subscribes to the [BookingProvider] stream for the given [stadiumId] and
/// [selectedDate] and maps each [TimeSlotItem] to a [BookingSlotCard],
/// highlighting past, booked, selected, and next-available slots.
class BookingSlotStreamSection extends StatefulWidget {
  final String stadiumId;
  final Stadium stadium;
  final DateTime selectedDate;
  final List<TimeSlotItem> timeSlots;
  final List<String> selectedTimeSlots;

  /// Called when the user taps a slot.
  /// Provides the [slotKey] and the current [existingBookings] list so the
  /// parent state can recompute the selection.
  final void Function(String slotKey, List<Booking> existingBookings) onSlotTap;

  /// Optional callback for the "Retry" button shown in the error state.
  final VoidCallback? onRetry;

  const BookingSlotStreamSection({
    super.key,
    required this.stadiumId,
    required this.stadium,
    required this.selectedDate,
    required this.timeSlots,
    required this.selectedTimeSlots,
    required this.onSlotTap,
    this.onRetry,
  });

  @override
  State<BookingSlotStreamSection> createState() => _BookingSlotStreamSectionState();
}

class _BookingSlotStreamSectionState extends State<BookingSlotStreamSection> {
  late Stream<List<Booking>> _bookingsStream;

  void _subscribe() {
    _bookingsStream = Provider.of<BookingProvider>(context, listen: false)
        .getBookingsForStadium(widget.stadiumId, widget.selectedDate);
  }

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant BookingSlotStreamSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stadiumId != widget.stadiumId ||
        oldWidget.selectedDate != widget.selectedDate) {
      _subscribe();
    }
  }

  void _retry() {
    setState(_subscribe);
    widget.onRetry?.call();
  }

  bool _isSlotBooked(String slotKey, List<Booking> existingBookings) {
    return BookingSlotCalculator.isSlotBooked(
      slotKey: slotKey,
      stadium: widget.stadium,
      selectedDate: widget.selectedDate,
      existingBookings: existingBookings,
    );
  }

  bool _isSlotClosed(String slotKey) =>
      BookingSlotCalculator.isVenueSlotClosed(
        stadium: widget.stadium,
        slotStart: _getSlotDateTime(slotKey),
      );

  DateTime _getSlotDateTime(String slotKey) {
    return BookingSlotCalculator.getSlotDateTime(
      slotKey: slotKey,
      stadium: widget.stadium,
      selectedDate: widget.selectedDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Booking>>(
      stream: _bookingsStream,
      builder: (context, snapshot) {
        final isArabic = Localizations.localeOf(context).languageCode == 'ar';

        // StreamBuilder retains the *previous date's data* when its stream
        // changes (none -> waiting). Do not offer stale slots while the new
        // day's availability subscription has not emitted a fresh event.
        if (BookingStreamFreshness.isAwaitingCurrentStream(snapshot)) {
          return VSPStateView(
            state: VSPUiState.loading,
            title: isArabic ? 'جاري تحميل المواعيد' : 'Loading availability',
            message: isArabic
                ? 'بنحدّث المواعيد المتاحة قبل ما تختار.'
                : 'We are refreshing available slots before you choose.',
          );
        }

        // Fail closed on stream errors, even when stale bookings are cached.
        // Rendering stale availability as selectable could enable double-booking.
        if (snapshot.hasError) {
          return VSPStateView(
            state: VSPUiState.error,
            title: isArabic ? 'تعذر تحميل المواعيد' : 'Could not load availability',
            message: isArabic
                ? 'تعذر التأكد من الحجوزات الحالية. حاول مرة تانية قبل اختيار موعد.'
                : 'Current bookings could not be verified. Retry before choosing a slot.',
            onRetry: _retry,
          );
        }

        // A completed stream without a verified bookings payload is not proof
        // that the venue has zero bookings. Never offer selectable slots.
        if (!snapshot.hasData) {
          return VSPStateView(
            state: VSPUiState.error,
            title: isArabic ? 'تعذر التحقق من المواعيد' : 'Availability not verified',
            message: isArabic
                ? 'لم تصل بيانات الحجوزات. أعد المحاولة قبل اختيار موعد.'
                : 'Booking data was not received. Retry before choosing a slot.',
            onRetry: _retry,
          );
        }

        final existingBookings = snapshot.data!;

        if (widget.stadium.isBlocked) {
          return VSPStateView(
            state: VSPUiState.empty,
            icon: Iconsax.lock_copy,
            title: isArabic ? 'الملعب غير متاح للحجز' : 'Venue unavailable',
            message: isArabic
                ? 'تم إيقاف الحجوزات لهذا الملعب حاليًا. تواصل مع إدارة الملعب.'
                : 'Bookings are temporarily disabled for this venue. Contact the venue.',
          );
        }

        if (widget.timeSlots.isEmpty) {
          // Dynamic slots are generated from the venue's operating hours,
          // independent of the selected date. No generated slots means the
          // venue schedule is missing or invalid, NOT that today's bookings
          // have been checked and all slots are occupied.
          return VSPStateView(
            state: VSPUiState.error,
            icon: Iconsax.clock_copy,
            title: isArabic ? 'جدول مواعيد الملعب غير متاح' : 'Venue schedule unavailable',
            message: isArabic
                ? 'ساعات العمل غير مكتملة أو جدول الملعب بحاجة لتحديث. لا يمكن تأكيد موعد حاليًا؛ تواصل مع إدارة الملعب.'
                : 'Venue operating hours are missing or invalid. A booking time cannot be verified; contact the venue.',
          );
        }
        final now = VSPTimeService.now;
        final bool isToday = widget.selectedDate.year == now.year &&
            widget.selectedDate.month == now.month &&
            widget.selectedDate.day == now.day;

        // A day can have a mixture of past and booked slots. Do not show a
        // selectable-looking schedule when none remains available.
        final allSlotsPassed = widget.timeSlots.every(
          (slot) => !_getSlotDateTime(slot.key).isAfter(now),
        );
        if (allSlotsPassed) {
          return VSPStateView(
            state: VSPUiState.empty,
            icon: Iconsax.clock_copy,
            title: isArabic ? 'انتهت مواعيد اليوم' : 'All slots have passed',
            message: isArabic
                ? 'كل مواعيد اليوم أصبحت في الماضي. اختر يومًا آخر.'
                : 'All available times for this date have passed. Choose another day.',
          );
        }
        final allSlotsClosed = widget.timeSlots.every(
          (slot) => _isSlotClosed(slot.key),
        );
        if (allSlotsClosed) {
          return VSPStateView(
            state: VSPUiState.empty,
            icon: Iconsax.clock_copy,
            title: isArabic ? 'الملعب مغلق مؤقتًا' : 'Venue temporarily closed',
            message: isArabic
                ? 'المواعيد المختارة تقع ضمن فترة الإغلاق. جرّب تاريخًا أو وقتًا آخر.'
                : 'These slots fall within a closure. Try another time or date.',
          );
        }
        final allSlotsBooked = widget.timeSlots.every(
          (slot) => _isSlotBooked(slot.key, existingBookings),
        );
        if (allSlotsBooked) {
          return VSPStateView(
            state: VSPUiState.empty,
            icon: Iconsax.clock_copy,
            title: isArabic ? 'كل المواعيد محجوزة' : 'All slots are booked',
            message: isArabic
                ? 'مواعيد اليوم محجوزة بالفعل. جرّب تاريخًا آخر.'
                : 'All slots for this date are booked. Try another date.',
          );
        }
        final hasBookableSlot = widget.timeSlots.any(
          (slot) => _getSlotDateTime(slot.key).isAfter(now) &&
              !_isSlotBooked(slot.key, existingBookings) &&
              !_isSlotClosed(slot.key),
        );
        if (!hasBookableSlot) {
          return VSPStateView(
            state: VSPUiState.empty,
            icon: Iconsax.clock_copy,
            title: isArabic ? 'لا توجد مواعيد متبقية' : 'No slots remaining',
            message: isArabic
                ? 'لا توجد فترات قابلة للحجز الآن؛ قد تكون محجوزة أو مغلقة أو انتهت. جرّب يومًا آخر.'
                : 'No bookable times remain; slots may be booked, closed or past. Try another date.',
          );
        }

        String? firstUpcomingSlotKey;
        if (isToday) {
          for (final item in widget.timeSlots) {
            final dt = _getSlotDateTime(item.key);
            final booked = _isSlotBooked(item.key, existingBookings);
            if (dt.isAfter(now) && !booked && !_isSlotClosed(item.key)) {
              firstUpcomingSlotKey = item.key;
              break;
            }
          }
        }

        return Column(
          children: List.generate(widget.timeSlots.length, (index) {
            final slotItem = widget.timeSlots[index];
            final isBooked = _isSlotBooked(slotItem.key, existingBookings);
            final isClosed = _isSlotClosed(slotItem.key);
            final isSelected = widget.selectedTimeSlots.contains(slotItem.key);
            final slotDateTime = _getSlotDateTime(slotItem.key);
            final slotEndDateTime = slotDateTime.add(const Duration(minutes: 30));
            final isPast = slotDateTime.isBefore(now);
            final isCurrentOngoing =
                isToday && now.isAfter(slotDateTime) && now.isBefore(slotEndDateTime);
            final isNextAvailable = isToday && slotItem.key == firstUpcomingSlotKey;

            final isOvernightSlot = slotItem.startMinutes >= 1440;
            final bool isFirstOvernightSlot =
                isOvernightSlot && (index == 0 || widget.timeSlots[index - 1].startMinutes < 1440);
            final String nextDayName = isOvernightSlot
                ? DateFormat('EEEE', Localizations.localeOf(context).toString())
                    .format(slotDateTime)
                : '';

            return BookingSlotCard(
              slotItem: slotItem,
              isBooked: isBooked,
              isClosed: isClosed,
              isPast: isPast,
              isSelected: isSelected,
              isCurrentOngoing: isCurrentOngoing,
              isNextAvailable: isNextAvailable,
              isFirstOvernightSlot: isFirstOvernightSlot,
              nextDayName: nextDayName,
              onTap: () => widget.onSlotTap(slotItem.key, existingBookings),
            );
          }),
        );
      },
    );
  }
}
