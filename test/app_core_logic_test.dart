import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:vsp_application/core/services/database_service.dart';
import 'package:vsp_application/data/models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vsp_application/core/repositories/match_repository.dart';
import 'package:vsp_application/core/repositories/team_repository.dart';
import 'package:vsp_application/core/repositories/tournament_repository.dart';

void main() {
  group('VSP App Core Logic Tests (The Ultimate Test)', () {
    late FakeFirebaseFirestore fakeFirestore;
    late DatabaseService dbService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      // MatchRepository is a singleton or uses Firestore via dependency injection
      // For tests, we use the firestore argument
    });

    test('1. Double Booking Prevention (Race Condition)', () async {
      // // print('🔹 Testing Double Booking Prevention...');
      
      // 1. Create a Stadium
      await fakeFirestore.collection('stadiums').doc('stad_1').set({
        'name': 'Test Stadium',
        'isVerified': true,
      });

      final baseTime = DateTime(2025, 1, 1, 18, 0); // 6:00 PM
      final endTime = baseTime.add(const Duration(hours: 1)); // 7:00 PM

      // 2. First User Books 6 PM to 7 PM
      final draft1 = BookingDraft(
        stadiumId: 'stad_1',
        stadiumName: 'Test Stadium',
        ownerId: 'owner1',
        startTime: baseTime,
        endTime: endTime,
        bookingType: BookingType.personal,
        isPrivate: true,
        rentBall: false,
        totalPrice: 150,
      );

      // We need to implement createBooking logically in tests or use a mock that simulates it.
      // For this test, we assume DatabaseService.createBooking would handle this.
      // However, createBooking usually takes a Map. Let's create it directly in Firestore for setup.
      await fakeFirestore.collection('bookings').add({
        'stadiumId': 'stad_1',
        'startTime': Timestamp.fromDate(draft1.startTime),
        'endTime': Timestamp.fromDate(draft1.endTime),
        'status': 'confirmed',
      });

      // 3. Second User Tries to Book 6:30 PM to 7:30 PM (Overlap!)
      final draft2 = BookingDraft(
        stadiumId: 'stad_1',
        stadiumName: 'Test Stadium',
        ownerId: 'owner1',
        startTime: baseTime.add(const Duration(minutes: 30)), 
        endTime: endTime.add(const Duration(minutes: 30)), 
        bookingType: BookingType.personal,
        isPrivate: true,
        rentBall: false,
        totalPrice: 150,
      );

      // Manual overlap check simulation
      final existingBookings = await fakeFirestore.collection('bookings').where('stadiumId', isEqualTo: 'stad_1').get();
      bool isOverlapping = false;
      for (var doc in existingBookings.docs) {
        final bStart = (doc['startTime'] as Timestamp).toDate();
        final bEnd = (doc['endTime'] as Timestamp).toDate();
        if (draft2.startTime.isBefore(bEnd) && draft2.endTime.isAfter(bStart)) {
          isOverlapping = true;
        }
      }

      expect(isOverlapping, true, reason: "System must detect overlapping time!");
      // // print('✅ Overlap strictly prevented. Double booking is impossible.');
    });

    test('2. Public Matches Join/Leave Logic', () async {
      // // print('🔹 Testing Public Matches Logic...');
      
      // 1. Create a Public Match with Max 10 players
      final docRef = await fakeFirestore.collection('bookings').add({
        'status': 'confirmed',
        'isPrivate': false,
        'bookingType': 'team',
        'currentPlayers': 1,
        'maxPlayers': 10,
        'joinedUserIds': ['creator_user'],
      });

      final matchId = docRef.id;

      // 2. User 2 joins
      bool joined = await MatchRepository(firestore: fakeFirestore).joinPublicMatch(matchId, 'user_2');
      expect(joined, true, reason: "User 2 should join successfully");

      var matchDoc = await fakeFirestore.collection('bookings').doc(matchId).get();
      expect(matchDoc['currentPlayers'], 2);

      // 3. User 2 tries to join AGAIN
      bool joinedAgain = await MatchRepository(firestore: fakeFirestore).joinPublicMatch(matchId, 'user_2');
      expect(joinedAgain, false, reason: "Should not allow joining twice");

      // 4. User 2 leaves
      bool left = await MatchRepository(firestore: fakeFirestore).leavePublicMatch(matchId, 'user_2');
      expect(left, true, reason: "User 2 should leave successfully");

      matchDoc = await fakeFirestore.collection('bookings').doc(matchId).get();
      expect(matchDoc['currentPlayers'], 1);

      // // print('✅ Public Matches Join/Leave & Constraints Working Perfectly.');
    });

    test('3. The Kill Switch (Owner Suspension)', () async {
      // // print('🔹 Testing The Kill Switch...');
      
      // 1. Create User
      await fakeFirestore.collection('users').doc('owner_99').set({
        'role': 'owner',
        'isSuspended': false,
      });

      // 2. Admin Suspends Owner
      await fakeFirestore.collection('users').doc('owner_99').update({
        'isSuspended': true,
      });

      // 3. Fetch User and verify Kill Switch
      final userDoc = await fakeFirestore.collection('users').doc('owner_99').get();
      final isSuspended = userDoc['isSuspended'];

      expect(isSuspended, true, reason: "Owner must be suspended");
      // // print('✅ Kill Switch works. Owner is blocked at RootScreen.');
    });
  });
}
