import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vsp_application/core/services/notification/notification_ui_helper.dart';
import 'package:vsp_application/core/repositories/booking_repository.dart';
import 'package:vsp_application/data/models.dart';

class MockBookingRepo implements BookingRepository {
  final Booking? returnBooking;
  MockBookingRepo({this.returnBooking});

  @override
  Future<Booking?> getBookingById(String id) async => returnBooking;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'notif_sound': false});
  });

  group('NotificationUiHelper Tests', () {
    testWidgets('showInAppAlert renders floating SnackBar with message details', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  NotificationUiHelper.showInAppAlert(
                    context: context,
                    message: const RemoteMessage(
                      notification: RemoteNotification(
                        title: 'Test Notification Title',
                        body: 'Test Notification Body Content',
                      ),
                      data: {'type': 'system'},
                    ),
                  );
                },
                child: const Text('Trigger Alert'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger Alert'));
      await tester.pump(); // Start animation
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Test Notification Title'), findsOneWidget);
      expect(find.text('Test Notification Body Content'), findsOneWidget);
    });

    testWidgets('navigateToChat and navigateToBooking gracefully handle null bookings', (tester) async {
      final mockRepo = MockBookingRepo(returnBooking: null);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  NotificationUiHelper.navigateToChat(context, 'invalid_id', repository: mockRepo);
                  NotificationUiHelper.navigateToBooking(context, 'invalid_id', repository: mockRepo);
                },
                child: const Text('Test Navigation'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Test Navigation'));
      await tester.pumpAndSettle();

      expect(find.text('Test Navigation'), findsOneWidget);
    });
  });
}
