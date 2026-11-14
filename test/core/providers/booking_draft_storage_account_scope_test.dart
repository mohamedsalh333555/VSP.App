import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vsp_application/core/providers/booking/booking_draft_storage.dart';
import 'package:vsp_application/data/models.dart';

BookingDraft _draft(String title) {
  final start = DateTime.now().add(const Duration(days: 1));
  return BookingDraft(
    stadiumId: 'private-pitch',
    stadiumName: title,
    ownerId: 'owner',
    startTime: start,
    endTime: start.add(const Duration(hours: 1)),
    bookingType: BookingType.personal,
    isPrivate: true,
    rentBall: false,
    totalPrice: 120,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('matching account can restore its own future booking draft', () async {
    await BookingDraftStorage.save(_draft('owner A draft'), userId: 'user-A');
    final restored = await BookingDraftStorage.restore(userId: 'user-A');
    expect(restored?.stadiumName, 'owner A draft');
  });

  test('another account never receives a locally saved booking draft', () async {
    await BookingDraftStorage.save(_draft('user A secret'), userId: 'user-A');
    expect(await BookingDraftStorage.restore(userId: 'user-B'), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('vsp_draft_booking'), isNull);
  });

  test('startup without authenticated identity does not consume another valid scoped draft',
      () async {
    await BookingDraftStorage.save(_draft('private'), userId: 'user-A');
    expect(await BookingDraftStorage.restore(userId: ''), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('vsp_draft_booking'), isNotNull);
    expect((await BookingDraftStorage.restore(userId: 'user-A'))?.stadiumName,
        'private');
  });

  test('legacy unscoped draft is rejected instead of being assigned to user B',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'vsp_draft_booking',
      json.encode(_draft('legacy private').toMap()),
    );
    expect(await BookingDraftStorage.restore(userId: 'user-B'), isNull);
    expect(prefs.getString('vsp_draft_booking'), isNull);
  });

  test('an unknown identity cannot persist or retrieve sensitive drafts',
      () async {
    await BookingDraftStorage.save(_draft('unscoped'), userId: '');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('vsp_draft_booking'), isNull);
    expect(await BookingDraftStorage.restore(userId: ''), isNull);
  });
}
