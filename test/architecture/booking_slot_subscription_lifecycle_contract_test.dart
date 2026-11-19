import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('booking slot stream remains stable on selection-only rebuilds', () {
    final source = File(
      'lib/features/player/widgets/booking/booking_slot_stream_section.dart',
    ).readAsStringSync();
    expect(source, contains('class BookingSlotStreamSection extends StatefulWidget'));
    expect(source, contains('late Stream<List<Booking>> _bookingsStream;'));
    expect(source, contains('void initState() {'));
    expect(source, contains('void didUpdateWidget(covariant BookingSlotStreamSection oldWidget)'));
    expect(source, contains('oldWidget.stadiumId != widget.stadiumId'));
    expect(source, contains('oldWidget.selectedDate != widget.selectedDate'));
    expect(source, contains('stream: _bookingsStream,'));
    expect(source, isNot(contains('stream: Provider.of<BookingProvider>')));
  });

  test('retry replaces failed availability subscription explicitly', () {
    final source = File(
      'lib/features/player/widgets/booking/booking_slot_stream_section.dart',
    ).readAsStringSync();
    expect(source, contains('void _retry() {'));
    expect(source, contains('setState(_subscribe);'));
    expect(source, contains('onRetry: _retry'));
  });
}
