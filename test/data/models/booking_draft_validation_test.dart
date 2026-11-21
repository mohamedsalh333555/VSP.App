import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models/booking_draft.dart';
import 'package:vsp_application/data/models/booking_enums.dart';

void main() {
  BookingDraft draft({
    DateTime? start,
    DateTime? end,
    double price = 100,
    double deposit = 0,
    int players = 1,
  }) {
    final begin = start ?? DateTime(2026, 11, 8, 18);
    return BookingDraft(
      stadiumId: 'stadium',
      stadiumName: 'Test Stadium',
      ownerId: 'owner',
      startTime: begin,
      endTime: end ?? begin.add(const Duration(hours: 1)),
      bookingType: BookingType.personal,
      isPrivate: false,
      rentBall: false,
      totalPrice: price,
      depositPaid: deposit,
      currentPlayers: players,
    );
  }

  test('valid booking draft passes local checks', () {
    expect(draft().validate(), isEmpty);
  });

  test('rejects invalid booking time range', () {
    final time = DateTime(2026, 11, 8, 18);
    expect(draft(start: time, end: time).validate(), contains('timeRange'));
    expect(draft(start: time, end: time.subtract(const Duration(minutes: 30)))
        .validate(), contains('timeRange'));
  });

  test('rejects invalid prices and deposits', () {
    expect(draft(price: -1).validate(), contains('totalPrice'));
    expect(draft(price: double.nan).validate(), contains('totalPrice'));
    expect(draft(deposit: -1).validate(), contains('depositPaid'));
    expect(draft(deposit: 101).validate(), contains('depositExceedsTotal'));
  });

  test('rejects impossible player counts', () {
    expect(draft(players: -1).validate(), contains('currentPlayers'));
    expect(draft(players: 11).validate(), contains('currentPlayers'));
  });
  test('checked serializer refuses invalid draft', () {
    expect(() => draft(price: -1).toValidatedMap(), throwsFormatException);
    expect(draft().toValidatedMap()['stadiumId'], 'stadium');
  });

  test('restored drafts reject missing or malformed times', () {
    final valid = draft().toMap();
    expect(() => BookingDraft.fromMap({...valid}..remove('startTime')),
        throwsFormatException);
    expect(() => BookingDraft.fromMap({...valid, 'endTime': 'not-a-date'}),
        throwsFormatException);
    expect(() => BookingDraft.fromMap({
      ...valid,
      'endTime': valid['startTime'],
    }), throwsFormatException);
  });

  test('restored drafts reject corrupt payment amounts', () {
    final valid = draft().toMap();
    expect(() => BookingDraft.fromMap({...valid, 'totalPrice': 'NaN'}),
        throwsFormatException);
    expect(() => BookingDraft.fromMap({...valid, 'deposit_paid': -1}),
        throwsFormatException);
  });

  test('restored drafts accept legacy string player counts', () {
    final valid = draft().toMap();
    final restored = BookingDraft.fromMap({
      ...valid,
      'players_per_team': '5',
      'total_field_capacity': '10',
      'currentPlayers': '2',
    });
    expect(restored.playersPerTeam, 5);
    expect(restored.totalFieldCapacity, 10);
    expect(restored.currentPlayers, 2);
  });

  test('restored drafts normalize legacy booking type names', () {
    final valid = draft().toMap();
    expect(
      BookingDraft.fromMap({...valid, 'booking_type': 'open-join-match'}
          ..remove('bookingType')).bookingType,
      BookingType.openJoin,
    );
    expect(
      BookingDraft.fromMap({...valid, 'bookingType': 'BookingType.challenge'})
          .bookingType,
      BookingType.challenge,
    );
  });

}
