import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('booking selection keeps navigation valid after closing its modal', () {
    final source = File(
      'lib/features/player/widgets/booking_type_modal.dart',
    ).readAsStringSync();
    final saved = source.indexOf('final navigator = Navigator.of(context);');
    final pop = source.indexOf('navigator.pop();', saved);
    final push = source.indexOf('navigator.push(', pop);
    expect(saved, greaterThanOrEqualTo(0));
    expect(pop, greaterThan(saved));
    expect(push, greaterThan(pop));
    expect(source, isNot(contains('Navigator.push(\n          context,')));
    expect(source, contains('authProvider.currentUser?.id != uid'));
  });

  test('booking preparation errors do not log raw provider responses', () {
    final source = File(
      'lib/features/player/widgets/booking_type_modal.dart',
    ).readAsStringSync();
    expect(
      source,
      contains("debugPrint('Failed to prepare booking type (details redacted)');"),
    );
    expect(source, isNot(contains("debugPrint('Failed to prepare booking type: \$e')")));
  });

  test('stadium prices and deposit labels adapt to narrow and scaled text', () {
    final source = File(
      'lib/features/player/widgets/stadium_details/stadium_bottom_booking_bar.dart',
    ).readAsStringSync();
    expect(source, contains('MediaQuery.textScalerOf(context)'));
    expect(source, contains('constraints.maxWidth < 360'));
    expect(source, contains('child: Text.rich('));
    expect(source, contains('Flexible('));
    expect(source, contains('mainAxisSize: MainAxisSize.min'));
    expect(source, contains('onPressed: bookingEnabled'));
  });

  test('facility labels wrap rather than truncating in Arabic or English', () {
    final source = File(
      'lib/features/player/widgets/stadium_details/stadium_information_tab.dart',
    ).readAsStringSync();
    final start = source.indexOf('class FacilitiesGrid');
    final end = source.indexOf('class StadiumInformationTab');
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final grid = source.substring(start, end);
    expect(grid, contains('softWrap: true'));
    expect(grid, isNot(contains('maxLines: 1')));
  });
}
