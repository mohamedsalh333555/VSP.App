import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/data/models/booking_enums.dart';
import 'package:vsp_application/features/owner/widgets/booking_sheet/booking_sheet_actions.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:vsp_application/shared/widgets/primary_button.dart';

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('ar'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );


Booking _fakeBooking({bool isPaid = false, double depositPaid = 50}) => Booking(
      id: 'bk1',
      stadiumId: 'st1',
      stadiumName: 'Test Stadium',
      ownerId: 'o1',
      startTime: DateTime.now().add(const Duration(hours: 1)),
      endTime: DateTime.now().add(const Duration(hours: 2)),
      bookingType: BookingType.personal,
      isPrivate: false,
      rentBall: false,
      totalPrice: 100,
      paymentMethod: 'cash',
      status: BookingStatus.confirmed,
      createdByUserId: 'u1',
      createdAt: DateTime.now(),
      playerPhone: '01000000000',
      isPaid: isPaid,
      depositPaid: depositPaid,
    );

void main() {
  group('OngoingMatchBanner', () {
    testWidgets('renders timer icon and extend button', (tester) async {
      await tester.pumpWidget(_wrap(
        OngoingMatchBanner(
          booking: _fakeBooking(),
          isSaving: false,
          onExtendMatch: () {},
        ),
      ));
      await tester.pump();
      expect(find.byIcon(Iconsax.timer_start_copy), findsOneWidget);
      expect(find.byIcon(Iconsax.add_circle_copy), findsOneWidget);
    });

    testWidgets('extend button does not fire callback when isSaving=true', (tester) async {
      bool fired = false;
      await tester.pumpWidget(_wrap(
        OngoingMatchBanner(
          booking: _fakeBooking(),
          isSaving: true,
          onExtendMatch: () => fired = true,
        ),
      ));
      await tester.pump();
      // Tap the button area — since it is disabled, callback should NOT fire
      await tester.tap(find.byIcon(Iconsax.add_circle_copy), warnIfMissed: false);
      await tester.pump();
      expect(fired, isFalse);
    });

    testWidgets('extend button fires callback when isSaving=false', (tester) async {
      bool fired = false;
      await tester.pumpWidget(_wrap(
        OngoingMatchBanner(
          booking: _fakeBooking(),
          isSaving: false,
          onExtendMatch: () => fired = true,
        ),
      ));
      await tester.pump();
      // Tap the add_circle icon (the extend button)
      await tester.tap(find.byIcon(Iconsax.add_circle_copy));
      await tester.pump();
      expect(fired, isTrue);
    });
  });

  group('UpcomingOnlinePaidActions', () {
    testWidgets('renders reschedule and emergency close buttons', (tester) async {
      await tester.pumpWidget(_wrap(
        UpcomingOnlinePaidActions(booking: _fakeBooking()),
      ));
      await tester.pump();
      expect(find.byIcon(Iconsax.clock_copy), findsOneWidget);
      expect(find.byIcon(Iconsax.danger_copy), findsOneWidget);
    });

    testWidgets('reschedule and emergency close buttons are visible', (tester) async {
      await tester.pumpWidget(_wrap(
        UpcomingOnlinePaidActions(booking: _fakeBooking()),
      ));
      await tester.pump();
      // OutlinedButton.icon wraps in an _OutlinedButtonWithIcon — find via icons
      expect(find.byIcon(Iconsax.clock_copy), findsOneWidget);
      expect(find.byIcon(Iconsax.danger_copy), findsOneWidget);
    });
  });

  group('BookingSheetBottomActions — default (new booking)', () {
    testWidgets('shows 2 PrimaryButtons for new booking', (tester) async {
      await tester.pumpWidget(_wrap(
        BookingSheetBottomActions(
          booking: null,
          isEdit: false,
          isPastCompleted: false,
          isUpcomingPendingCash: false,
          isUpcomingOnlinePaid: false,
          isSaving: false,
          isDeleting: false,
          onConfirmCashPayment: () {},
          onCancelBooking: () {},
          onConfirmBooking: () {},
        ),
      ));
      await tester.pump();
      expect(find.byType(PrimaryButton), findsNWidgets(2));
    });

    testWidgets('calls onConfirmBooking on confirm tap', (tester) async {
      bool confirmed = false;
      await tester.pumpWidget(_wrap(
        BookingSheetBottomActions(
          booking: null,
          isEdit: false,
          isPastCompleted: false,
          isUpcomingPendingCash: false,
          isUpcomingOnlinePaid: false,
          isSaving: false,
          isDeleting: false,
          onConfirmCashPayment: () {},
          onCancelBooking: () {},
          onConfirmBooking: () => confirmed = true,
        ),
      ));
      await tester.pump();
      await tester.tap(find.byType(PrimaryButton).last);
      await tester.pump();
      expect(confirmed, isTrue);
    });

    testWidgets('online-paid mode shows only 1 PrimaryButton (Report Issue)', (tester) async {
      await tester.pumpWidget(_wrap(
        BookingSheetBottomActions(
          booking: _fakeBooking(),
          isEdit: true,
          isPastCompleted: false,
          isUpcomingPendingCash: false,
          isUpcomingOnlinePaid: true,
          isSaving: false,
          isDeleting: false,
          onConfirmCashPayment: () {},
          onCancelBooking: () {},
          onConfirmBooking: () {},
        ),
      ));
      await tester.pump();
      // Only cancel/report-issue button appears (no confirm button for online-paid)
      expect(find.byType(PrimaryButton), findsOneWidget);
    });
  });

  group('BookingSheetBottomActions — past completed branch', () {
    testWidgets('shows send-receipt and close buttons', (tester) async {
      await tester.pumpWidget(_wrap(
        BookingSheetBottomActions(
          booking: _fakeBooking(isPaid: true),
          isEdit: false,
          isPastCompleted: true,
          isUpcomingPendingCash: false,
          isUpcomingOnlinePaid: false,
          isSaving: false,
          isDeleting: false,
          onConfirmCashPayment: () {},
          onCancelBooking: () {},
          onConfirmBooking: () {},
        ),
      ));
      await tester.pump();
      expect(find.byIcon(Iconsax.document_text_copy), findsOneWidget);
    });

    testWidgets('shows no-show button when unpaid and deposit < total', (tester) async {
      await tester.pumpWidget(_wrap(
        BookingSheetBottomActions(
          booking: _fakeBooking(isPaid: false, depositPaid: 50),
          isEdit: false,
          isPastCompleted: true,
          isUpcomingPendingCash: false,
          isUpcomingOnlinePaid: false,
          isSaving: false,
          isDeleting: false,
          onConfirmCashPayment: () {},
          onCancelBooking: () {},
          onConfirmBooking: () {},
        ),
      ));
      await tester.pump();
      expect(find.byIcon(Iconsax.user_remove_copy), findsOneWidget);
    });
  });

  group('BookingSheetBottomActions — cash pending branch', () {
    testWidgets('shows cash confirm, whatsapp, and cancel buttons', (tester) async {
      await tester.pumpWidget(_wrap(
        BookingSheetBottomActions(
          booking: _fakeBooking(),
          isEdit: false,
          isPastCompleted: false,
          isUpcomingPendingCash: true,
          isUpcomingOnlinePaid: false,
          isSaving: false,
          isDeleting: false,
          onConfirmCashPayment: () {},
          onCancelBooking: () {},
          onConfirmBooking: () {},
        ),
      ));
      await tester.pump();
      expect(find.byIcon(Iconsax.money_send_copy), findsOneWidget);
      expect(find.byIcon(Iconsax.message_copy), findsOneWidget);
      expect(find.byIcon(Iconsax.close_circle_copy), findsOneWidget);
    });

    testWidgets('cash confirm button does not fire when isSaving=true', (tester) async {
      bool fired = false;
      await tester.pumpWidget(_wrap(
        BookingSheetBottomActions(
          booking: _fakeBooking(),
          isEdit: false,
          isPastCompleted: false,
          isUpcomingPendingCash: true,
          isUpcomingOnlinePaid: false,
          isSaving: true,
          isDeleting: false,
          onConfirmCashPayment: () => fired = true,
          onCancelBooking: () {},
          onConfirmBooking: () {},
        ),
      ));
      await tester.pump();
      // While saving, the button intentionally replaces its money icon with a spinner.
      // Tap the disabled button itself to verify the callback remains blocked.
      await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
      await tester.pump();
      expect(fired, isFalse);
    });

    testWidgets('calls onCancelBooking when cancel tapped', (tester) async {
      bool cancelled = false;
      await tester.pumpWidget(_wrap(
        BookingSheetBottomActions(
          booking: _fakeBooking(),
          isEdit: false,
          isPastCompleted: false,
          isUpcomingPendingCash: true,
          isUpcomingOnlinePaid: false,
          isSaving: false,
          isDeleting: false,
          onConfirmCashPayment: () {},
          onCancelBooking: () => cancelled = true,
          onConfirmBooking: () {},
        ),
      ));
      await tester.pump();
      await tester.tap(find.byIcon(Iconsax.close_circle_copy));
      await tester.pump();
      expect(cancelled, isTrue);
    });
  });
}
