import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
void main() {
  late final String source;
  setUpAll(() {
    source = File('lib/features/auth/screens/verify_email_screen.dart')
        .readAsStringSync();
  });
  test('OTP errors never log private provider responses or stacks', () {
    expect(source, contains('Email OTP verification failed (details redacted)'));
    expect(source, contains('Email OTP resend failed (details redacted)'));
    expect(source, isNot(contains('debugPrintStack(')));
    expect(source, isNot(contains('failed unexpectedly:')));
  });
  test('OTP failure UI never reflects raw provider error text', () {
    expect(source, isNot(contains('auth.errorMessage')));
    expect(source, contains('Invalid or expired code. Please try again.'));
    expect(source, contains('رمز التفعيل خاطئ أو انتهت صلاحيته'));
  });
  test('secure storage cleanup logs redact error values', () {
    expect(source, contains('Pending verification email cleanup failed (redacted)'));
    expect(source, isNot(contains('cleanup failed: ')));
  });
}
