import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('result dialog disables submit button before match end', () {
    final source = File(
      'lib/features/player/widgets/match_result_modal.dart',
    ).readAsStringSync();
    final button = source.substring(
      source.indexOf("text: isArabic ? 'إرسال النتيجة'"),
      source.indexOf('bool get _isParticipatingTeam'),
    );
    expect(button, contains('widget.booking.endTime.isAfter(VSPTimeService.now)'));
    expect(button, contains('!_isParticipatingTeam'));
    expect(button, contains(': _handleSubmit'));
  });

  test('result dialog checks match end time before submitting', () {
    final source = File(
      'lib/features/player/widgets/match_result_modal.dart',
    ).readAsStringSync();
    final start = source.indexOf('Future<void> _handleSubmit() async {');
    final end = source.indexOf('Widget _buildRatingSection(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final submit = source.substring(start, end);
    expect(submit, contains('widget.booking.endTime.isAfter(VSPTimeService.now)'));
    expect(submit, contains('يمكن تسجيل النتيجة بعد انتهاء المباراة.'));
    expect(submit, contains('You can submit the result after the match ends.'));
    expect(submit.indexOf('widget.booking.endTime.isAfter(VSPTimeService.now)'),
        lessThan(submit.indexOf('widget.onConfirm(')));
  });
}
