import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vsp_application/core/providers/booking/booking_list_modifier.dart';
import 'package:vsp_application/core/repositories/user_repository.dart';
import 'package:vsp_application/data/models/booking_enums.dart';
import 'package:vsp_application/data/models/booking_mapper.dart';
import 'package:vsp_application/data/models/booking_models.dart';

void main() {
  group('Stage 4 — Error Formatter Machine Tokens (Test F)', () {
    test('Formats STADIUM_LIMIT_EXCEEDED machine token', () {
      const error = 'STADIUM_LIMIT_EXCEEDED: وصلت للحد الأقصى للملاعب في باقتك الحالية (1 ملعب)';
      final formatted = BookingListModifier.formatCreationError(error);
      expect(formatted, contains('تم تجاوز الحد الأقصى للملاعب'));
    });

    test('Formats SLOT_LOCKED_OR_TAKEN machine token', () {
      const error = 'SLOT_LOCKED_OR_TAKEN: الوقت المحدد محجوز بالفعل';
      final formatted = BookingListModifier.formatCreationError(error);
      expect(formatted, contains('الوقت المحدد محجوز بالفعل'));
    });

    test('Formats CANNOT_CONFIRM_CANCELLED_BOOKING machine token', () {
      const error = 'CANNOT_CONFIRM_CANCELLED_BOOKING: لا يمكن تحصيل حجز ملغي';
      final formatted = BookingListModifier.formatCreationError(error);
      expect(formatted, contains('لا يمكن تحصيل حجز ملغي'));
    });

    test('Suppresses raw PostgrestException technical details from reaching user', () {
      final error = PostgrestException(
        message: 'syntax error at or near "SELECT"',
        code: '42601',
        details: 'PostgreSQL syntax error in internal query',
      );
      final formatted = BookingListModifier.formatCreationError(error);
      expect(formatted, contains('حدث خطأ في النظام'));
      expect(formatted, isNot(contains('syntax error')));
      expect(formatted, isNot(contains('42601')));
    });

    test('Handles PostgrestException with recognized token in message', () {
      final error = PostgrestException(
        message: 'STADIUM_LIMIT_EXCEEDED: تم تجاوز الحد الأقصى للملاعب',
        code: 'P0002',
        details: 'LIMIT_REACHED',
      );
      final formatted = BookingListModifier.formatCreationError(error);
      expect(formatted, contains('تم تجاوز الحد الأقصى للملاعب'));
    });
  });

  group('Stage 4 — Booking Status Serialization (Test G)', () {
    test('BookingStatus.upcoming toDbValue() resolves to confirmed', () {
      expect(BookingStatus.upcoming.toDbValue(), equals('confirmed'));
      expect(BookingStatus.confirmed.toDbValue(), equals('confirmed'));
      expect(BookingStatus.pending.toDbValue(), equals('pending'));
      expect(BookingStatus.cancelled.toDbValue(), equals('cancelled'));
      expect(BookingStatus.completed.toDbValue(), equals('completed'));
    });

    test('BookingMapper.toFirestore serializes upcoming status as confirmed', () {
      final booking = Booking(
        id: 'test-booking-id',
        stadiumId: 'stadium-1',
        stadiumName: 'Main Stadium',
        stadiumImageUrl: 'https://example.com/stadium.jpg',
        ownerId: 'owner-1',
        startTime: DateTime.now().add(const Duration(hours: 2)),
        endTime: DateTime.now().add(const Duration(hours: 3)),
        totalPrice: 250.0,
        bookingType: BookingType.personal,
        isPrivate: false,
        rentBall: false,
        paymentMethod: 'cash',
        status: BookingStatus.upcoming,
        createdByUserId: 'user-1',
        createdAt: DateTime.now(),
      );

      final map = BookingMapper.toFirestore(booking);
      expect(map['status'], equals('confirmed'));
      expect(map['status'], isNot(equals('upcoming')));
    });
  });

  group('Stage 4 — Owner Document Whitelist Protection (Test H)', () {
    test('UserRepository rejects unauthorized document field names with ArgumentError', () async {
      final repo = UserRepository();

      const maliciousKeys = [
        'role',
        'is_admin',
        'isAdmin',
        'subscription_plan',
        'is_verified',
        'wallet_balance',
        'points',
      ];

      for (final badKey in maliciousKeys) {
        expect(
          () => repo.updateOwnerVerificationDocument(
            uid: 'fake-user-id',
            docFieldName: badKey,
            fileUrl: 'https://example.com/exploit.jpg',
          ),
          throwsA(isA<ArgumentError>()),
          reason: 'Field $badKey should have been blocked by the whitelist',
        );
      }
    });

    test('OwnerDocumentType enum values map only to approved whitelisted keys', () {
      expect(OwnerDocumentType.values.length, equals(6));
      expect(OwnerDocumentType.values, contains(OwnerDocumentType.nationalId));
      expect(OwnerDocumentType.values, contains(OwnerDocumentType.nationalIdFront));
      expect(OwnerDocumentType.values, contains(OwnerDocumentType.nationalIdBack));
      expect(OwnerDocumentType.values, contains(OwnerDocumentType.commercialRegister));
      expect(OwnerDocumentType.values, contains(OwnerDocumentType.taxCard));
      expect(OwnerDocumentType.values, contains(OwnerDocumentType.stadiumOwnershipProof));
    });
  });
}
