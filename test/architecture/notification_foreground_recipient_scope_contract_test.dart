import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FCM sender explicitly scopes foreground payload and token cleanup', () {
    final sender = File('supabase/functions/fcm_push/index.ts').readAsStringSync();
    expect(sender, contains('recipientUserId: String(userId)'));
    expect(sender, contains('.delete().eq("user_id", userId).in("token", invalidTokens)'));
  });

  test('foreground display requires current account both before and after async work', () {
    final ui = File('lib/core/services/notification/notification_ui_helper.dart')
        .readAsStringSync();
    final method = ui.indexOf('static Future<void> showInAppAlert(');
    final next = ui.indexOf('static bool canOpenBookingForUser', method);
    final body = ui.substring(method, next);
    final first = body.indexOf('isRecipientCurrentUser(');
    final asyncStep = body.indexOf('await SharedPreferences.getInstance()');
    final recheck = body.indexOf('currentUser?.id != requestUserId', asyncStep);
    final scoped = body.indexOf('shouldShowNotificationForUser(', asyncStep);
    final last = body.lastIndexOf('currentUser?.id != requestUserId');
    final show = body.indexOf('showSnackBar(');
    expect(first, greaterThanOrEqualTo(0));
    expect(asyncStep, greaterThan(first));
    expect(recheck, greaterThan(asyncStep));
    expect(scoped, greaterThan(recheck));
    expect(last, greaterThan(scoped));
    expect(show, greaterThan(last));
    expect(body, isNot(contains("prefs.getBool('notif_sound')")));
  });
}
