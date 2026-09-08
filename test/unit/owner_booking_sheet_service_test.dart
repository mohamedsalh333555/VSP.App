import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/owner/widgets/booking_sheet/owner_booking_sheet_service.dart';

void main() {
  group('OwnerBookingSheetService Unit Tests', () {
    final baseStadium = Stadium(
      id: 'std_test_1',
      name: 'Bernabeu Giza',
      location: 'Giza, Egypt',
      imageUrl: 'https://vsp.app/img.png',
      type: 'Football',
      size: '5 VS 5',
      baths: 1,
      cafeteria: 1,
      playersPerTeam: 5,
      totalFieldCapacity: 10,
      pricePerHour: 300.0,
      basePrice: 300.0,
      area: '800 m²',
      openingTime: '16:00',
      closingTime: '23:00',
      ballPrice: 50.0,
    );

    test('calculateBookingPrice computes base and extra durations and ball fee correctly', () {
      // 1 hour without ball
      expect(OwnerBookingSheetService.calculateBookingPrice(
        stadium: baseStadium,
        durationMinutes: 60,
        rentBall: false,
      ), 300.0);

      // 1.5 hours without ball
      expect(OwnerBookingSheetService.calculateBookingPrice(
        stadium: baseStadium,
        durationMinutes: 90,
        rentBall: false,
      ), 450.0);

      // 2 hours with ball (+50 EGP)
      expect(OwnerBookingSheetService.calculateBookingPrice(
        stadium: baseStadium,
        durationMinutes: 120,
        rentBall: true,
      ), 650.0);
    });

    test('calculateMaxAvailableMinutes limits duration by closing time', () {
      // Slot at 21:00, closing at 23:00 -> max 120 minutes
      final slotTime = DateTime(2026, 9, 10, 21, 0);
      final maxMins = OwnerBookingSheetService.calculateMaxAvailableMinutes(
        stadium: baseStadium,
        slotTime: slotTime,
        existingBookings: [],
      );

      expect(maxMins, 120);
    });

    test('calculateMaxAvailableMinutes limits duration by subsequent booking', () {
      // Slot at 17:00, stadium closes at 23:00, but another booking starts at 18:30
      final slotTime = DateTime(2026, 9, 10, 17, 0);
      final nextBooking = Booking(
        id: 'bk_next',
        stadiumId: 'std_test_1',
        stadiumName: 'Bernabeu Giza',
        stadiumImageUrl: '',
        ownerId: 'own_1',
        startTime: DateTime(2026, 9, 10, 18, 30),
        endTime: DateTime(2026, 9, 10, 19, 30),
        bookingType: BookingType.personal,
        playerTeamName: 'FC Pyramids',
        playerPhone: '01012345678',
        totalPrice: 300.0,
        currentPlayers: 10,
        status: BookingStatus.confirmed,
        paymentStatus: 'paid',
        paymentMethod: 'cash',
        isPaid: true,
        isPrivate: true,
        rentBall: false,
        createdByUserId: 'own_1',
        createdAt: DateTime(2026, 9, 10),
      );

      final maxMins = OwnerBookingSheetService.calculateMaxAvailableMinutes(
        stadium: baseStadium,
        slotTime: slotTime,
        existingBookings: [nextBooking],
      );

      // 17:00 to 18:30 is 90 minutes
      expect(maxMins, 90);
    });

    test('calculateMaxAvailableMinutes limits duration by split-shift break', () {
      final stadiumWithBreak = Stadium(
        id: 'std_break',
        name: 'Camp Nou',
        location: 'Cairo',
        imageUrl: '',
        type: 'Football',
        size: '5 VS 5',
        baths: 1,
        cafeteria: 1,
        playersPerTeam: 5,
        totalFieldCapacity: 10,
        pricePerHour: 200.0,
        basePrice: 200.0,
        area: '600 m²',
        openingTime: '14:00',
        closingTime: '23:00',
        isSplitShift: true,
        breakStartTime: '18:00',
        breakEndTime: '19:00',
      );

      final slotTime = DateTime(2026, 9, 10, 16, 30);
      final maxMins = OwnerBookingSheetService.calculateMaxAvailableMinutes(
        stadium: stadiumWithBreak,
        slotTime: slotTime,
        existingBookings: [],
      );

      // From 16:30 to 18:00 is 90 minutes
      expect(maxMins, 90);
    });

    test('checkBookingsOverlap detects active overlaps and ignores cancelled or self bookings', () {
      final existingBooking = Booking(
        id: 'bk_active',
        stadiumId: 'std_test_1',
        stadiumName: 'Bernabeu',
        stadiumImageUrl: '',
        ownerId: 'own_1',
        startTime: DateTime(2026, 9, 10, 18, 0),
        endTime: DateTime(2026, 9, 10, 19, 0),
        bookingType: BookingType.personal,
        playerTeamName: 'FC Cairo',
        playerPhone: '01000000000',
        totalPrice: 300.0,
        currentPlayers: 10,
        status: BookingStatus.confirmed,
        paymentStatus: 'paid',
        paymentMethod: 'cash',
        isPaid: true,
        isPrivate: true,
        rentBall: false,
        createdByUserId: 'own_1',
        createdAt: DateTime(2026, 9, 10),
      );

      final cancelledBooking = Booking(
        id: 'bk_cancelled',
        stadiumId: 'std_test_1',
        stadiumName: 'Bernabeu',
        stadiumImageUrl: '',
        ownerId: 'own_1',
        startTime: DateTime(2026, 9, 10, 19, 0),
        endTime: DateTime(2026, 9, 10, 20, 0),
        bookingType: BookingType.personal,
        playerTeamName: 'FC Giza',
        playerPhone: '01000000000',
        totalPrice: 300.0,
        currentPlayers: 10,
        status: BookingStatus.cancelled,
        paymentStatus: 'refunded',
        paymentMethod: 'cash',
        isPaid: false,
        isPrivate: true,
        rentBall: false,
        createdByUserId: 'own_1',
        createdAt: DateTime(2026, 9, 10),
      );

      // Overlaps with bk_active
      expect(
        OwnerBookingSheetService.checkBookingsOverlap(
          startTime: DateTime(2026, 9, 10, 18, 30),
          endTime: DateTime(2026, 9, 10, 19, 30),
          bookings: [existingBooking, cancelledBooking],
        ),
        isTrue,
      );

      // Overlaps with bk_cancelled, but status is cancelled so it returns false
      expect(
        OwnerBookingSheetService.checkBookingsOverlap(
          startTime: DateTime(2026, 9, 10, 19, 15),
          endTime: DateTime(2026, 9, 10, 19, 45),
          bookings: [existingBooking, cancelledBooking],
        ),
        isFalse,
      );

      // Same booking ID ignored (e.g. when extending own booking)
      expect(
        OwnerBookingSheetService.checkBookingsOverlap(
          startTime: DateTime(2026, 9, 10, 18, 0),
          endTime: DateTime(2026, 9, 10, 19, 30),
          bookings: [existingBooking],
          ignoreBookingId: 'bk_active',
        ),
        isFalse,
      );
    });

    test('formatBookingErrorMessage provides friendly Arabic and English messages', () {
      expect(
        OwnerBookingSheetService.formatBookingErrorMessage(
          'Exception: prevent_double_booking triggered',
          isArabic: true,
        ),
        contains('هذا الموعد محجوز بالفعل'),
      );

      expect(
        OwnerBookingSheetService.formatBookingErrorMessage(
          'PostgrestException: overlap error occurred',
          isArabic: false,
        ),
        contains('Booking duration overlaps'),
      );
    });

    test('buildManualBookingDraft constructs valid manual draft', () {
      final start = DateTime(2026, 9, 10, 18, 0);
      final end = DateTime(2026, 9, 10, 19, 0);
      final draft = OwnerBookingSheetService.buildManualBookingDraft(
        stadium: baseStadium,
        uid: 'owner_user_1',
        startTime: start,
        endTime: end,
        customerName: 'فريق النجوم',
        customerPhone: '01012345678',
        notes: 'حجز يدوي تجريبي',
        totalPrice: 300.0,
        collectedAmount: 300.0,
        playerCount: 10,
      );

      expect(draft.stadiumId, baseStadium.id);
      expect(draft.playerTeamName, 'فريق النجوم');
      expect(draft.playerPhone, '01012345678');
      expect(draft.totalPrice, 300.0);
      expect(draft.isPaid, isTrue);
      expect(draft.paymentStatus, 'paid');
      expect(draft.paymentMethod, 'cash');
      expect(draft.paymentTransactionId, startsWith('MANUAL_'));
    });

    test('buildBookingUpdateMap constructs expected payload', () {
      final end = DateTime(2026, 9, 10, 20, 0);
      final updateMap = OwnerBookingSheetService.buildBookingUpdateMap(
        endTime: end,
        customerName: 'فريق الصقور',
        customerPhone: '01099999999',
        notes: 'ملاحظة',
        playerCount: 12,
        collectedAmount: 150.0,
        finalTotal: 300.0,
        originalTotal: 250.0,
      );

      expect(updateMap['end_time'], end.toUtc().toIso8601String());
      expect(updateMap['player_team_name'], 'فريق الصقور');
      expect(updateMap['player_phone'], '01099999999');
      expect(updateMap['current_players'], 12);
      expect(updateMap['deposit_paid'], 150.0);
      expect(updateMap['is_paid'], isFalse);
      expect(updateMap['payment_status'], 'partially_paid');
      expect(updateMap['total_price'], 300.0);
    });
  });
}

