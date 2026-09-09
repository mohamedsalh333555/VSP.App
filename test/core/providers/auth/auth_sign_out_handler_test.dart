import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vsp_application/core/providers/auth/auth_sign_out_handler.dart';
import 'package:vsp_application/core/services/auth_service.dart';
import 'package:vsp_application/core/services/notification_service.dart';

class FakeAuthService implements AuthService {
  bool signOutCalled = false;

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeNotificationService implements NotificationService {
  bool stoppedListening = false;

  @override
  void stopRealtimeNotificationsListener() {
    stoppedListening = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'temp_stadium_draft': 'draft_data',
      'vsp_draft_stadium_user_123_abc': 'draft_data_2',
    });
  });

  test('AuthSignOutHandler.performSignOut triggers cleanup callbacks and teardown', () async {
    final fakeAuth = FakeAuthService();
    final fakeNotif = FakeNotificationService();
    bool realtimeCleared = false;

    await AuthSignOutHandler.performSignOut(
      user: null,
      userModelUid: 'user_123',
      authService: fakeAuth,
      notificationService: fakeNotif,
      onClearRealtime: () {
        realtimeCleared = true;
      },
    );

    expect(realtimeCleared, isTrue);
    expect(fakeNotif.stoppedListening, isTrue);
    expect(fakeAuth.signOutCalled, isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('temp_stadium_draft'), isFalse);
    expect(prefs.containsKey('vsp_draft_stadium_user_123_abc'), isFalse);
  });
}
