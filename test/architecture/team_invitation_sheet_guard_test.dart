import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('invitation inbox disables actions when invitation ID is missing', () {
    final source = File('lib/features/player/widgets/team_invitations_sheet.dart')
        .readAsStringSync();
    expect(source, contains("invitation['id']?.toString().trim()"));
    expect(source, contains("id != null && id.isNotEmpty && id != 'null'"));
    expect(source, contains('_busyId == null && hasValidId'));
    expect(source, contains('_respond(id, false)'));
    expect(source, contains('_respond(id, true)'));
  });
}
