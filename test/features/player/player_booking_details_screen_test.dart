import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/player/screens/player_booking_details_screen.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

Widget _app(Booking booking, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: PlayerBookingDetailsScreen(booking: booking),
  );
}

Booking _booking({
  BookingStatus status = BookingStatus.confirmed,
  String paymentMethod = 'paymob',
  String paymentStatus = 'deposit_paid',
  double depositPaid = 50.25,
  String? cancellationReason,
}) {
  return Booking(
    id: 'BK-DETAIL-1001',
    stadiumId: 'stadium-1',
    stadiumName: 'Nile Arena',
    ownerId: 'owner-1',
    startTime: DateTime(2026, 11, 12, 18),
    endTime: DateTime(2026, 11, 12, 19),
    bookingType: BookingType.personal,
    isPrivate: true,
    rentBall: false,
    totalPrice: 250.75,
    currency: 'EGP',
    paymentMethod: paymentMethod,
    paymentStatus: paymentStatus,
    depositPaid: depositPaid,
    isDepositPaid: depositPaid > 0,
    status: status,
    cancellationReason: cancellationReason,
    createdByUserId: 'player-1',
    createdAt: DateTime(2026, 11, 10, 12),
  );
}

void main() {
  testWidgets('shows booking reference and truthful financial details',
      (tester) async {
    await tester.pumpWidget(_app(_booking()));
    await tester.pumpAndSettle();

    expect(find.text('Booking Details'), findsOneWidget);
    expect(find.text('Nile Arena'), findsOneWidget);
    expect(find.text('BK-DETAIL-1001'), findsOneWidget);
    expect(find.text('250.75 EGP'), findsOneWidget);
    expect(find.text('Online payment'), findsOneWidget);
    expect(find.text('Deposit paid'), findsOneWidget);
    expect(find.text('50.25 EGP'), findsOneWidget);
    expect(find.text('200.50 EGP'), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget);
  });

  testWidgets('shows cancellation and refund state in Arabic', (tester) async {
    await tester.pumpWidget(
      _app(
        _booking(
          status: BookingStatus.cancelled,
          paymentStatus: 'refunded',
          depositPaid: 250.75,
          cancellationReason: 'ألغاه اللاعب',
        ),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('تفاصيل الحجز'), findsOneWidget);
    expect(find.text('تم الاسترداد'), findsOneWidget);
    expect(find.text('ملغي'), findsOneWidget);
    expect(find.text('ألغاه اللاعب'), findsOneWidget);
  });
}
