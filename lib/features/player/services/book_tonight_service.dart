import 'package:flutter/foundation.dart';
import '../../../core/repositories/booking_repository.dart';
import '../../../core/utils/app_date_formatter.dart';
import '../../../data/models.dart';
import '../widgets/booking/booking_slot_calculator.dart';

/// يمثل فترة مباراة كاملة متاحة للحجز السريع الليلة (افتراضياً 60 دقيقة = شريحتين متتاليتين)
class TonightMatchSlot {
  final String displayTime; // e.g. "09:00 م - 10:00 م"
  final List<String> slotKeys; // e.g. ["09:00 PM", "09:30 PM"]
  final DateTime startDateTime;
  final double price; // سعر الساعة الكامل
  final bool isOneHour;

  const TonightMatchSlot({
    required this.displayTime,
    required this.slotKeys,
    required this.startDateTime,
    required this.price,
    this.isOneHour = true,
  });
}

/// يمثل عرض الملعب والساعات الشاغرة الليلة المتاحة للحجز الفوري
class TonightStadiumOffer {
  final Stadium stadium;
  final DateTime operationalDate;
  final List<TonightMatchSlot> availableSlots;

  const TonightStadiumOffer({
    required this.stadium,
    required this.operationalDate,
    required this.availableSlots,
  });
}

/// خدمة استكشاف الساعات الشاغرة الليلة في الملاعب القريبة بدون إجهاد في التصفح
class BookTonightService {
  final BookingRepository _bookingRepository;

  BookTonightService({BookingRepository? bookingRepository})
      : _bookingRepository = bookingRepository ?? SupabaseBookingRepository();

  /// تفحص الملاعب وتسترجع الساعات الشاغرة الليلة بالتوازي لضمان سرعة استجابة فائقة
  Future<List<TonightStadiumOffer>> findTonightOffers({
    required List<Stadium> stadiums,
    required bool isArabic,
    DateTime? currentTime,
  }) async {
    final now = currentTime ?? DateTime.now();
    final operationalDate = AppDateFormatter.getOperationalDate(now);

    // حصر الفحص بأول 6 ملاعب نشطة لسرعة الاستجابة اللحظية
    final targetStadiums = stadiums.take(6).toList();
    if (targetStadiums.isEmpty) return [];

    final List<TonightStadiumOffer> offers = [];

    // استعلام متوازي لجميع الملاعب
    final futures = targetStadiums.map((stadium) async {
      try {
        final existingBookings = await _bookingRepository.fetchStadiumBookingsDirectly(
          stadium.id,
          operationalDate,
        );
        return MapEntry(stadium, existingBookings);
      } catch (e) {
        debugPrint('Failed to query bookings for stadium ${stadium.id}: $e');
        return MapEntry(stadium, <Booking>[]);
      }
    });

    final results = await Future.wait(futures);

    for (final entry in results) {
      final stadium = entry.key;
      final existingBookings = entry.value;

      final openSlots = extractAvailableSlots(
        stadium: stadium,
        existingBookings: existingBookings,
        operationalDate: operationalDate,
        now: now,
        isArabic: isArabic,
      );

      if (openSlots.isNotEmpty) {
        offers.add(TonightStadiumOffer(
          stadium: stadium,
          operationalDate: operationalDate,
          availableSlots: openSlots,
        ));
      }
    }

    return offers;
  }

  /// يستخرج فترات المباريات المتاحة الليلة (ساعات كاملة متتالية أو شرائح مفردة)
  static List<TonightMatchSlot> extractAvailableSlots({
    required Stadium stadium,
    required List<Booking> existingBookings,
    required DateTime operationalDate,
    required DateTime now,
    required bool isArabic,
  }) {
    final dynamicSlots = BookingSlotCalculator.generateDynamicTimeSlots(
      stadium: stadium,
      isArabic: isArabic,
    );

    final List<int> availableIndices = [];
    // مهلة 15 دقيقة على الأقل للاستعداد والانتقال للملعب
    final cutoffTime = now.add(const Duration(minutes: 15));

    for (int i = 0; i < dynamicSlots.length; i++) {
      final slot = dynamicSlots[i];
      final slotDateTime = BookingSlotCalculator.getSlotDateTime(
        slotKey: slot.key,
        stadium: stadium,
        selectedDate: operationalDate,
      );

      if (slotDateTime.isBefore(cutoffTime)) continue;

      final isBooked = BookingSlotCalculator.isSlotBooked(
        slotKey: slot.key,
        stadium: stadium,
        selectedDate: operationalDate,
        existingBookings: existingBookings,
      );

      if (!isBooked) {
        availableIndices.add(i);
      }
    }

    final List<TonightMatchSlot> matchSlots = [];
    final Set<int> usedIndices = {};

    // تجميع الشرائح المتتالية في مباريات كاملة لمدة ساعة (المعيار الأكثر طلباً للاعبين)
    for (int i = 0; i < availableIndices.length - 1; i++) {
      final idx1 = availableIndices[i];
      final idx2 = availableIndices[i + 1];

      if (usedIndices.contains(idx1)) continue;

      final slot1 = dynamicSlots[idx1];
      final slot2 = dynamicSlots[idx2];

      if (idx2 == idx1 + 1 && slot2.startMinutes == slot1.startMinutes + 30) {
        final startDateTime = BookingSlotCalculator.getSlotDateTime(
          slotKey: slot1.key,
          stadium: stadium,
          selectedDate: operationalDate,
        );

        matchSlots.add(TonightMatchSlot(
          displayTime: '${slot1.startTime} - ${slot2.endTime}',
          slotKeys: [slot1.key, slot2.key],
          startDateTime: startDateTime,
          price: stadium.basePrice,
          isOneHour: true,
        ));

        usedIndices.add(idx1);
        usedIndices.add(idx2);
      }
    }

    // إذا لم تتوفر ساعات كاملة ولكن توجد شرائح نصف ساعة فردية، يتم إضافتها كبديل
    if (matchSlots.isEmpty) {
      for (final idx in availableIndices) {
        final slot = dynamicSlots[idx];
        final startDateTime = BookingSlotCalculator.getSlotDateTime(
          slotKey: slot.key,
          stadium: stadium,
          selectedDate: operationalDate,
        );
        matchSlots.add(TonightMatchSlot(
          displayTime: '${slot.startTime} - ${slot.endTime}',
          slotKeys: [slot.key],
          startDateTime: startDateTime,
          price: stadium.basePrice / 2,
          isOneHour: false,
        ));
      }
    }

    // ترتيب الساعات زمنياً
    matchSlots.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
    return matchSlots;
  }
}
