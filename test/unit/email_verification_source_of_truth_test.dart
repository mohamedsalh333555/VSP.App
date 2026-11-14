import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('email verification remains sourced from Supabase Auth', () {
    final migration = File(
      'supabase/migrations/20261104235900_sync_real_email_verification.sql',
    ).readAsStringSync();

    expect(
      migration,
      contains('new.email_confirmed_at is not null'),
    );
    expect(
      migration,
      contains('after insert or update of email_confirmed_at'),
    );
    expect(
      migration,
      contains('before update of is_email_verified'),
    );
  });

  test('unconfirmed signup does not invoke authenticated completion RPC', () {
    final source = File(
      'lib/core/providers/auth/auth_registration_service.dart',
    ).readAsStringSync();

    expect(source, contains('final isEmailConfirmed ='));
    expect(source, contains('if (isEmailConfirmed) {'));
    expect(source, contains('isEmailVerified: isEmailConfirmed'));
  });
}
