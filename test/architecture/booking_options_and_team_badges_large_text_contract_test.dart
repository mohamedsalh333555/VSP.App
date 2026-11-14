import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('booking option sheet allows subtitles to wrap in large text', () {
    final source = File(
      'lib/features/player/widgets/booking_type_modal.dart',
    ).readAsStringSync();
    final card = source.substring(source.indexOf('Widget _buildOptionCard('));
    expect(card, contains('softWrap: true'));
    expect(card, isNot(contains('maxLines: 2')));
    expect(card, isNot(contains('maxLines: 3')));
    expect(card, isNot(contains('TextOverflow.ellipsis')));
    expect(source, contains('SingleChildScrollView('));
    expect(source, contains('useSafeArea: true'));
  });

  test('verified team achievement labels are not clipped', () {
    final source = File(
      'lib/features/player/widgets/my_team/team_achievement_badges.dart',
    ).readAsStringSync();
    final badge = source.substring(source.indexOf('Widget _badge('));
    expect(badge, contains('softWrap: true'));
    expect(badge, isNot(contains('TextOverflow.ellipsis')));
    expect(badge, contains('Flexible('));
    expect(source, contains('Semantics('));
  });
}
