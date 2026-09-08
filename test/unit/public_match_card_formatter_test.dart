import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/shared/widgets/match_card/public_match_card_formatter.dart';

void main() {
  group('PublicMatchCardFormatter Unit Tests', () {
    test('formatTimeShort handles standard HH:00 ranges and irregular ranges', () {
      expect(PublicMatchCardFormatter.formatTimeShort('18:00 - 19:00'), equals('18-19'));
      expect(PublicMatchCardFormatter.formatTimeShort('20:00 - 22:00'), equals('20-22'));
      expect(PublicMatchCardFormatter.formatTimeShort('09:00 - 10:30'), equals('09-10:30'));
      expect(PublicMatchCardFormatter.formatTimeShort('Invalid String'), equals('Invalid String'));
    });

    test('getLocalizedBookingType returns accurate localized names in Arabic and English', () {
      expect(
        PublicMatchCardFormatter.getLocalizedBookingType(BookingType.openJoin, isArabic: true),
        equals('تجميعي'),
      );
      expect(
        PublicMatchCardFormatter.getLocalizedBookingType(BookingType.openJoin, isArabic: false),
        equals('OPEN JOIN'),
      );

      expect(
        PublicMatchCardFormatter.getLocalizedBookingType(BookingType.challenge, isArabic: true),
        equals('تحدي'),
      );
      expect(
        PublicMatchCardFormatter.getLocalizedBookingType(BookingType.challenge, isArabic: false),
        equals('CHALLENGE'),
      );

      expect(
        PublicMatchCardFormatter.getLocalizedBookingType(BookingType.personal, isArabic: true),
        equals('حجز عادي'),
      );
      expect(
        PublicMatchCardFormatter.getLocalizedBookingType(BookingType.personal, isArabic: false),
        equals('SOLO'),
      );

      expect(
        PublicMatchCardFormatter.getLocalizedBookingType(BookingType.team, isArabic: true),
        equals('فريق'),
      );
      expect(
        PublicMatchCardFormatter.getLocalizedBookingType(BookingType.team, isArabic: false),
        equals('TEAM'),
      );

      expect(
        PublicMatchCardFormatter.getLocalizedBookingType(BookingType.matchup, isArabic: true),
        equals('مواجهات'),
      );
      expect(
        PublicMatchCardFormatter.getLocalizedBookingType(BookingType.matchup, isArabic: false),
        equals('MATCHUP'),
      );
    });

    test('calculateRemainingSpots safely clamps between 0 and total capacity', () {
      expect(
        PublicMatchCardFormatter.calculateRemainingSpots(totalCapacity: 10, currentPlayers: 6),
        equals(4),
      );
      expect(
        PublicMatchCardFormatter.calculateRemainingSpots(totalCapacity: 10, currentPlayers: 10),
        equals(0),
      );
      // Overflow protection:
      expect(
        PublicMatchCardFormatter.calculateRemainingSpots(totalCapacity: 10, currentPlayers: 15),
        equals(0),
      );
      // Zero capacity protection:
      expect(
        PublicMatchCardFormatter.calculateRemainingSpots(totalCapacity: 0, currentPlayers: 0),
        equals(0),
      );
    });

    test('calculateEntryFee computes rounded division and handles zero capacity', () {
      expect(
        PublicMatchCardFormatter.calculateEntryFee(totalPrice: 600, totalCapacity: 10),
        equals('60'),
      );
      expect(
        PublicMatchCardFormatter.calculateEntryFee(totalPrice: 500, totalCapacity: 15),
        equals('33'),
      );
      expect(
        PublicMatchCardFormatter.calculateEntryFee(totalPrice: 500, totalCapacity: 0),
        equals('0'),
      );
    });
  });
}
