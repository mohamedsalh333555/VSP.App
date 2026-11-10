import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('report repository binds submissions to auth and bounded input', () {
    final source = File(
      'lib/core/repositories/report_repository.dart',
    ).readAsStringSync();

    expect(source, contains('_supabase.auth.currentUser?.id'));
    expect(source, contains('currentUserId != cleanReporterId'));
    expect(source, contains('cleanReason.length > 200'));
    expect(source, contains('(cleanDetails?.length ?? 0) > 2000'));
    expect(source, contains("{'user', 'booking', 'match'}"));
    expect(source, contains('_inFlightReportKeys.add(requestKey)'));
    expect(source, contains('_inFlightReportKeys.remove(requestKey)'));
    expect(source, isNot(contains("VSPLogger.e('Error reporting entity on Supabase', e)")));
  });
}
