import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';

void main() {
  group('RefundInfo Model & Smart Refund Tests', () {
    test('Correctly maps wallet refund from booking row', () {
      final row = {
        'display_refund_ref': 'WLT_REF_12345',
        'refund_channel': 'wallet',
        'refund_eta': 'minutes',
        'refund_amount': 250.0,
        'refunded_at': '2026-09-12T20:00:00Z',
      };

      final refund = RefundInfo.fromBookingRow(row);
      expect(refund.channel, RefundChannel.wallet);
      expect(refund.eta, RefundEta.minutes);
      expect(refund.refundAmount, 250.0);
      expect(refund.refundTransactionId, 'WLT_REF_12345');
      expect(refund.hasReference, true);
      expect(refund.badgeText, contains('مسترد للمحفظة'));
      expect(refund.etaText, 'خلال دقائق');
      expect(refund.refundNoticeText('250 جنيه'), contains('محفظتك الإلكترونية'));
    });

    test('Correctly maps bank card refund from booking row', () {
      final row = {
        'display_refund_ref': 'CRD_REF_998877',
        'refund_channel': 'card',
        'refund_eta': '3-5_business_days',
        'refund_amount': 500.0,
        'refunded_at': '2026-09-12T20:00:00Z',
      };

      final refund = RefundInfo.fromBookingRow(row);
      expect(refund.channel, RefundChannel.card);
      expect(refund.eta, RefundEta.businessDays);
      expect(refund.refundAmount, 500.0);
      expect(refund.refundTransactionId, 'CRD_REF_998877');
      expect(refund.badgeText, contains('مسترد بنكياً'));
      expect(refund.etaText, '3–5 أيام عمل');
      expect(refund.refundNoticeText('500 جنيه'), contains('3–5 أيام عمل'));
      expect(refund.refundSuccessText(), contains('3–5 أيام عمل'));
    });

    test('Falls back smartly to cash when channel is undefined', () {
      final row = {
        'refund_amount': 100.0,
        'payment_method': 'cash',
      };

      final refund = RefundInfo.fromBookingRow(row);
      expect(refund.channel, RefundChannel.cash);
      expect(refund.eta, RefundEta.immediate);
      expect(refund.hasReference, false);
      expect(refund.badgeText, contains('مسترد نقداً'));
      expect(refund.refundNoticeText('100 جنيه'), contains('نقداً فور إلغاء الحجز'));
    });

    test('Detects wallet channel from vodafone_cash or instapay payment_method', () {
      final rowVodafone = {
        'payment_method': 'vodafone_cash',
        'refund_amount': 300.0,
        'refund_txn_id': 'TX_VODAFONE_1',
      };

      final refundVodafone = RefundInfo.fromBookingRow(rowVodafone);
      expect(refundVodafone.channel, RefundChannel.wallet);
      expect(refundVodafone.eta, RefundEta.minutes);
      expect(refundVodafone.refundTransactionId, 'TX_VODAFONE_1');
    });

    test('Booking model exposes refundInfo getter seamlessly', () {
      final booking = Booking(
        id: 'b-test-1',
        stadiumId: 's-1',
        stadiumName: 'Cairo Arena',
        ownerId: 'o-1',
        startTime: DateTime.now().add(const Duration(days: 1)),
        endTime: DateTime.now().add(const Duration(days: 1, hours: 1)),
        bookingType: BookingType.personal,
        isPrivate: false,
        rentBall: false,
        totalPrice: 400.0,
        paymentMethod: 'card',
        status: BookingStatus.cancelled,
        createdByUserId: 'u-1',
        createdAt: DateTime.now(),
        refundAmount: 400.0,
        refundTransactionId: 'PAYMOB_REF_777',
        refundChannel: 'card',
        refundEta: '3-5_business_days',
      );

      expect(booking.refundInfo.channel, RefundChannel.card);
      expect(booking.refundInfo.refundAmount, 400.0);
      expect(booking.refundInfo.refundTransactionId, 'PAYMOB_REF_777');
      expect(booking.refundInfo.hasReference, true);
    });
  });
}
