import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/utils/email_address_validator.dart';

void main() {
  test('common valid addresses pass across every auth entrypoint', () {
    for (final email in [
      'player@example.com',
      'player+team@vspapp.online',
      ' owner@stadium.example ',
      'MIXED.Case@EXAMPLE.COM',
    ]) {
      expect(EmailAddressValidator.isValid(email), isTrue, reason: email);
    }
  });

  test('incomplete and malformed addresses are rejected', () {
    for (final email in [
      '', ' ', '@', 'player', 'player@', '@example.com',
      'player@host', 'player@host.', 'player@host.c',
      'player@@example.com', 'player name@example.com',
      'player@example.com extra',
    ]) {
      expect(EmailAddressValidator.isValid(email), isFalse, reason: email);
    }
    final tooLongEmail = '${List.filled(250, 'a').join()}@example.com';
    expect(EmailAddressValidator.isValid(tooLongEmail), isFalse);
  });
}
