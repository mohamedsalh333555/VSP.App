import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/utils/app_error_handler.dart';

void main() {
  test('known cancellation six-hour policy is safe, consistent and localized', () {
    final source = Exception('cannot_cancel_within_6_hours');
    final ar = AppErrorHandler.formatError(source, isArabic: true);
    final en = AppErrorHandler.formatError(source, isArabic: false);
    expect(ar, contains('6 ساعات'));
    expect(ar, contains('20 دقيقة'));
    expect(en, contains('6 hours'));
    expect(en, contains('20 minutes'));
    expect(ar, isNot(contains('Exception:')));
    expect(en, isNot(contains('cannot_cancel_within_6_hours')));
  });

  test('unknown technical exceptions do not expose sensitive query details', () {
    const raw = 'Exception: relation customer_booking_secret does not exist';
    final ar = AppErrorHandler.formatError(Exception(raw));
    final en = AppErrorHandler.formatError(Exception(raw), isArabic: false);
    expect(ar, isNot(contains('customer_booking_secret')));
    expect(en, isNot(contains('customer_booking_secret')));
  });

  test('completed and already-cancelled booking states stay actionable', () {
    expect(
      AppErrorHandler.formatError(Exception('cannot_cancel_completed_booking')),
      contains('مباراة مكتملة'),
    );
    expect(
      AppErrorHandler.formatError(Exception('already_cancelled')),
      contains('ملغي بالفعل'),
    );
  });
}
