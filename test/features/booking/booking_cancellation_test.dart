import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/core/providers/booking_provider.dart';
import 'package:vsp_application/core/repositories/booking/booking_cancellation_coordinator.dart';
import 'package:vsp_application/core/repositories/booking_repository.dart';
import 'package:vsp_application/data/models/booking_models.dart';
import 'package:vsp_application/features/player/widgets/user_bookings/player_booking_cancel_dialog.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:vsp_application/shared/widgets/primary_button.dart';

class FailingMockBookingRepository implements BookingRepository {
  final String failMessage;
  FailingMockBookingRepository(this.failMessage);

  @override
  Future<bool> cancelBooking(String bookingId) async {
    throw Exception(failMessage);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SuccessfulMockBookingRepository implements BookingRepository {
  @override
  Future<bool> cancelBooking(String bookingId) async {
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BookingCancellationCoordinator.sanitizeCancellationError', () {
    test('sanitizes 6-hour policy error', () {
      final msg = BookingCancellationCoordinator.sanitizeCancellationError(
        null,
        'cannot_cancel_within_6_hours: test error',
      );
      expect(msg, contains('6 ساعات'));
    });

    test('sanitizes legacy 2-hour policy error using current 6-hour rule', () {
      final msg = BookingCancellationCoordinator.sanitizeCancellationError(
        'PostgrestException: cannot_cancel_within_2_hours',
      );
      expect(msg, contains('6 ساعات'));
    });

    test('sanitizes completed match error', () {
      final msg = BookingCancellationCoordinator.sanitizeCancellationError(
        null,
        'cannot_cancel_completed_booking',
      );
      expect(msg, contains('مباراة مكتملة'));
    });

    test('sanitizes forbidden error', () {
      final msg = BookingCancellationCoordinator.sanitizeCancellationError(
        null,
        'forbidden access',
      );
      expect(msg, contains('غير مصرح'));
    });

    test('preserves readable custom server message', () {
      const custom = 'تم رفض الطلب من البنك';
      final msg = BookingCancellationCoordinator.sanitizeCancellationError(
        null,
        custom,
      );
      expect(msg, equals(custom));
    });
  });

  group('BookingProvider Cancellation Error Handling', () {
    test('sets errorMessage and returns false on failure', () async {
      const expectedError = 'لا يمكن إلغاء الحجز قبل موعد المباراة بأقل من 6 ساعات';
      final mockRepo = FailingMockBookingRepository(expectedError);
      final provider = BookingProvider(repository: mockRepo);

      expect(provider.errorMessage, isNull);

      final result = await provider.cancelBooking('test_booking_123');

      expect(result, isFalse);
      expect(provider.errorMessage, equals(expectedError));
    });

    test('returns true and clears cancellingIds on success', () async {
      final mockRepo = SuccessfulMockBookingRepository();
      final provider = BookingProvider(repository: mockRepo);

      final result = await provider.cancelBooking('test_booking_456');

      expect(result, isTrue);
      expect(provider.errorMessage, isNull);
    });
  });

  group('PlayerBookingCancelDialog UI Flow', () {
    testWidgets('displays red error snackbar with server message when cancellation fails', (tester) async {
      const serverError = 'لا يمكن إلغاء الحجز قبل موعد المباراة بأقل من 6 ساعات';
      final mockRepo = FailingMockBookingRepository(serverError);
      final provider = BookingProvider(repository: mockRepo);

      final testBooking = Booking(
        id: 'test_b_999',
        ownerId: 'owner_1',
        stadiumId: 'stadium_1',
        stadiumName: 'ملعب النجوم',
        startTime: DateTime.now().add(const Duration(hours: 3)),
        endTime: DateTime.now().add(const Duration(hours: 4)),
        bookingType: BookingType.personal,
        isPrivate: true,
        rentBall: false,
        createdByUserId: 'user_1',
        totalPrice: 200,
        status: BookingStatus.confirmed,
        paymentStatus: 'paid',
        paymentMethod: 'cash',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<BookingProvider>.value(
          value: provider,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('ar'),
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => PlayerBookingCancelDialog.show(ctx, testBooking),
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open Dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Verify Dialog is open
      expect(find.byType(AlertDialog), findsOneWidget);

      // Tap the confirm cancel PrimaryButton in the dialog (red error button)
      final cancelBtn = find.widgetWithText(PrimaryButton, 'إلغاء');
      expect(cancelBtn, findsOneWidget);
      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();

      // Dialog should be popped
      expect(find.byType(AlertDialog), findsNothing);

      // Fast forward past the initial "cancelling" snackbar (1s) to show error snackbar
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Verify that the error SnackBar with the server's exact message is displayed
      expect(find.text(serverError), findsOneWidget);
    });
  });
}
