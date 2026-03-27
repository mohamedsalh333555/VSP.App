import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../data/models.dart';
import '../services/database_service.dart';
import '../services/analytics_service.dart';
import '../services/logger_service.dart';

/// Abstract BookingRepository interface
abstract class BookingRepository {
  /// Create a new booking from draft after payment success
  Future<Booking> createBooking(BookingDraft draft, String userId);

  /// Get all bookings for a user
  Stream<List<Booking>> getUserBookings(String userId);

  /// Get all bookings for a stadium owner
  Stream<List<Booking>> getOwnerBookings(String ownerId);

  /// Get a single booking by ID
  Future<Booking?> getBookingById(String bookingId);

  /// Update booking status
  Future<bool> updateBookingStatus(String bookingId, BookingStatus status);

  /// Cancel a booking
  Future<bool> cancelBooking(String bookingId);

  /// Get upcoming bookings for a user
  Stream<List<Booking>> getUpcomingBookings(String userId);

  /// Get completed/history bookings for a user
  Stream<List<Booking>> getBookingHistory(String userId);

  /// Submit match result for Challenge bookings
  Future<bool> submitMatchResult({
    required String bookingId,
    required String teamId,
    required MatchOutcome outcome,
    double? rating,
    String? review,
  });

  /// Update payment status
  Future<bool> updatePaymentStatus(String bookingId, bool isPaid);

  /// Get bookings for a specific stadium and date
  Stream<List<Booking>> getBookingsForStadium(String stadiumId, DateTime date);
}

/// Firestore implementation of BookingRepository
class FirestoreBookingRepository implements BookingRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  CollectionReference get _bookingsCollection => 
      _firestore.collection('bookings');

  @override
  Future<Booking> createBooking(BookingDraft draft, String userId) async {
    try {
      final docRef = _bookingsCollection.doc();
      
      // For the Cash-Only MVP, we auto-confirm all bookings.
      const status = BookingStatus.confirmed;

      final booking = Booking.fromDraft(
        id: docRef.id,
        draft: draft,
        userId: userId,
        status: status,
      );

      final bookingData = booking.toFirestore();
      bookingData['createdAt'] = FieldValue.serverTimestamp(); 
      bookingData['updatedAt'] = FieldValue.serverTimestamp();

      // Logic Fix: Prevent Double Booking (Race Condition) using Transaction
      await _firestore.runTransaction((transaction) async {
        // 1. Query the bookings collection for potential overlaps
        // Note: We check by stadium and status first.
        final snapshot = await _bookingsCollection
            .where('stadiumId', isEqualTo: draft.stadiumId)
            .get();

        final overlappingBookings = snapshot.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          // Skip cancelled bookings
          if (data['status'] == BookingStatus.cancelled.name) return false;

          final bStart = (data['startTime'] as Timestamp).toDate();
          final bEnd = (data['endTime'] as Timestamp).toDate();

          // Condition: (bStart < draft.endTime) AND (bEnd > draft.startTime)
          return bStart.isBefore(draft.endTime) && bEnd.isAfter(draft.startTime);
        });

        // 2. If overlap exists, throw exception
        if (overlappingBookings.isNotEmpty) {
          throw Exception("This slot was just booked by someone else!");
        }

        // 3. If no overlap, proceed to write the new booking document
        transaction.set(docRef, bookingData);
      });

      // ── Challenge Notification Logic ──
      if (draft.bookingType == BookingType.challenge && draft.opponentTeamId != null) {
        _sendChallengeNotification(draft);
      }

      // ── Owner Notification Logic ──
      _sendOwnerNotification(draft, docRef.id);

      AnalyticsService.logStadiumBooked(draft.stadiumId, draft.totalPrice);
      VSPLogger.i('✅ Booking created successfully: ${docRef.id}');
      return booking;
    } catch (e) {
      VSPLogger.e('❌ Error creating booking', e);
      rethrow;
    }
  }

  Future<void> _sendOwnerNotification(BookingDraft draft, String bookingId) async {
    try {
      final db = DatabaseService();
      await db.sendNotification(
        draft.ownerId,
        AppNotification(
          id: '',
          title: 'New Booking Received! 💰',
          body: '${draft.playerTeamName ?? "A player"} booked ${draft.stadiumName} on ${DateFormat('MMM d').format(draft.startTime)} at ${DateFormat('h:mm a').format(draft.startTime)}.',
          type: 'info',
          createdAt: DateTime.now(),
          bookingId: bookingId,
        ),
      );
    } catch (e) {
      debugPrint('Error sending owner notification: $e');
    }
  }

  Future<void> _sendChallengeNotification(BookingDraft draft) async {
    try {
      final db = DatabaseService();
      // 1. Get opponent team to find captain phone
      final teamDoc = await _firestore.collection('teams').doc(draft.opponentTeamId).get();
      if (!teamDoc.exists) return;
      
      final teamData = teamDoc.data() as Map<String, dynamic>;
      final captainPhone = teamData['captainPhone'];
      if (captainPhone == null) return;

      // 2. Find captain user ID by phone
      final captainUser = await db.getUserByPhone(captainPhone);
      if (captainUser == null) return;

      // 3. Send notification
      await db.sendNotification(
        captainUser.uid,
        AppNotification(
          id: '', // Firestore auto-generates
          title: 'Challenge Confirmed!',
          body: 'You are playing against ${draft.playerTeamName ?? "another team"} at ${draft.stadiumName} on ${DateFormat('MMM d').format(draft.startTime)}.',
          type: 'info',
          createdAt: DateTime.now(),
        ),
      );
      AnalyticsService.logChallengeSent(draft.playerTeamId ?? 'unknown', draft.opponentTeamId!);
    } catch (e) {
      VSPLogger.e('Error sending challenge notification', e);
    }
  }

  @override
  Stream<List<Booking>> getUserBookings(String userId) {
    return _bookingsCollection
        .where('createdByUserId', isEqualTo: userId)
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Booking.fromFirestore(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  @override
  Stream<List<Booking>> getOwnerBookings(String ownerId) {
    return _bookingsCollection
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Booking.fromFirestore(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  @override
  Future<Booking?> getBookingById(String bookingId) async {
    try {
      final doc = await _bookingsCollection.doc(bookingId).get();
      if (doc.exists) {
        return Booking.fromFirestore(
            doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting booking: $e');
      return null;
    }
  }

  @override
  Future<bool> updateBookingStatus(
      String bookingId, BookingStatus status) async {
    try {
      await _bookingsCollection.doc(bookingId).update({
        'status': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('❌ Error updating booking status: $e');
      return false;
    }
  }

  @override
  Future<bool> cancelBooking(String bookingId) async {
    try {
      final doc = await _bookingsCollection.doc(bookingId).get();
      if (!doc.exists) return false;

      final data = doc.data() as Map<String, dynamic>;
      final startTime = (data['startTime'] as Timestamp).toDate();

      // Business Rule: Cannot cancel after match starts
      if (DateTime.now().isAfter(startTime)) {
        debugPrint('⚠️ Cannot cancel booking after start time: $bookingId');
        return false;
      }

      await _bookingsCollection.doc(bookingId).update({
        'status': BookingStatus.cancelled.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('❌ Error cancelling booking: $e');
      return false;
    }
  }

  @override
  Stream<List<Booking>> getUpcomingBookings(String userId) {
    final now = DateTime.now();
    return _bookingsCollection
        .where('createdByUserId', isEqualTo: userId)
        .where('status', isEqualTo: BookingStatus.confirmed.name)
        .orderBy('startTime')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Booking.fromFirestore(
                doc.data() as Map<String, dynamic>, doc.id))
            .where((booking) => booking.startTime.isAfter(now))
            .toList());
  }

  @override
  Stream<List<Booking>> getBookingHistory(String userId) {
    return _bookingsCollection
        .where('createdByUserId', isEqualTo: userId)
        .where('status', isEqualTo: BookingStatus.completed.name)
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Booking.fromFirestore(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

    @override
    Future<bool> submitMatchResult({
      required String bookingId,
      required String teamId,
      required MatchOutcome outcome,
      double? rating,
      String? review,
    }) async {
      try {
        final docRef = _bookingsCollection.doc(bookingId);
        final doc = await docRef.get();
        if (!doc.exists) return false;

        final data = doc.data() as Map<String, dynamic>;
        final currentMatchStatus = data['matchResultStatus'] ?? 'noResult';
        final submittedBy = data['resultSubmittedByTeamId'];
        final stadiumId = data['stadiumId'];

        // Helper to save rating if provided
        Future<void> saveRating() async {
          if (rating != null && rating > 0 && stadiumId != null) {
            final stadiumRef = _firestore.collection('stadiums').doc(stadiumId);
            
            // Add review document
            await stadiumRef.collection('reviews').add({
              'bookingId': bookingId,
              'userId': teamId, // using teamId as userId for now
              'rating': rating,
              'reviewText': review ?? '',
              'createdAt': FieldValue.serverTimestamp(),
            });

            // Update stadium aggregate rating
            await _firestore.runTransaction((transaction) async {
              final stadiumDoc = await transaction.get(stadiumRef);
              if (!stadiumDoc.exists) return;
              
              final currentRating = (stadiumDoc.data()?['rating'] ?? 5.0).toDouble();
              final reviewsCount = (stadiumDoc.data()?['reviewsCount'] ?? 0).toInt();
              
              final newReviewsCount = reviewsCount + 1;
              final newRating = ((currentRating * reviewsCount) + rating) / newReviewsCount;
              
              transaction.update(stadiumRef, {
                 'rating': newRating,
                 'reviewsCount': newReviewsCount,
              });
            });
          }
        }

        if (currentMatchStatus == 'noResult') {
          // First team submitting
          await docRef.update({
            'pendingOutcome': outcome.name,
            'resultSubmittedByTeamId': teamId,
            'matchResultStatus': MatchResultStatus.waitingOpponent.name,
          });
          await saveRating();
          return true;
        } else if (currentMatchStatus == 'waitingOpponent' && submittedBy != teamId) {
          // Second team submitting - check if matches
          final pendingOutcomeStr = data['pendingOutcome'];

            if (pendingOutcomeStr == outcome.name) {
              await docRef.update({
                'finalOutcome': outcome.name,
                'matchResultStatus': MatchResultStatus.confirmed.name,
                'status': BookingStatus.completed.name,
                'pendingOutcome': FieldValue.delete(),
                'resultSubmittedByTeamId': FieldValue.delete(),
              });

              // ── Update Global Rankings ──
              final homeTeamId = data['playerTeamId'];
              final awayTeamId = data['opponentTeamId'];
              if (homeTeamId != null && awayTeamId != null) {
                await DatabaseService().updateMatchResult(
                  bookingId, 
                  homeTeamId, 
                  awayTeamId, 
                  outcome
                );
              }
              await saveRating();
              return true;
            } else {
            // Disagreement on result
            await docRef.update({
              'matchResultStatus': MatchResultStatus.disputed.name,
              'requiresAdminIntervention': true,
            });
            await saveRating();
            return false;
          }
        }
        return false;
      } catch (e) {
        debugPrint('❌ Error submitting match result: $e');
        return false;
      }
    }

    @override
    Stream<List<Booking>> getBookingsForStadium(String stadiumId, DateTime date) {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      return _bookingsCollection
          .where('stadiumId', isEqualTo: stadiumId)
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('startTime', isLessThan: Timestamp.fromDate(endOfDay))
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => Booking.fromFirestore(
                  doc.data() as Map<String, dynamic>, doc.id))
              .where((b) => b.status != BookingStatus.cancelled)
              .toList());
    }

    @override
    Future<bool> updatePaymentStatus(String bookingId, bool isPaid) async {
      try {
        await _bookingsCollection.doc(bookingId).update({
          'isPaid': isPaid,
          'paymentStatus': isPaid ? 'paid' : 'pending',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      } catch (e) {
        debugPrint('❌ Error updating payment status: $e');
        return false;
      }
    }
  }

/// Mock implementation for demo/testing
class MockBookingRepository implements BookingRepository {
  final List<Booking> _bookings = [];
  final _controller = StreamController<List<Booking>>.broadcast();

  void _update() {
    _controller.add(List.from(_bookings));
  }

  @override
  Future<Booking> createBooking(BookingDraft draft, String userId) async {
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate network
    
    // For the Cash-Only MVP, we auto-confirm all bookings.
    const status = BookingStatus.confirmed;

    final booking = Booking.fromDraft(
      id: 'mock_${DateTime.now().millisecondsSinceEpoch}',
      draft: draft,
      userId: userId,
      status: status,
    );

    _bookings.add(booking);
    _update();
    debugPrint('✅ Mock Booking created: ${booking.id}');
    return booking;
  }

  @override
  Stream<List<Booking>> getUserBookings(String userId) async* {
    yield _bookings.where((b) => b.createdByUserId == userId).toList();
    yield* _controller.stream.map(
      (bookings) => bookings.where((b) => b.createdByUserId == userId).toList(),
    );
  }

  @override
  Stream<List<Booking>> getOwnerBookings(String ownerId) async* {
    yield _bookings.where((b) => b.ownerId == ownerId).toList();
    yield* _controller.stream.map(
      (bookings) => bookings.where((b) => b.ownerId == ownerId).toList(),
    );
  }

  @override
  Future<Booking?> getBookingById(String bookingId) async {
    try {
      return _bookings.firstWhere((b) => b.id == bookingId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> updateBookingStatus(
      String bookingId, BookingStatus status) async {
    final index = _bookings.indexWhere((b) => b.id == bookingId);
    if (index != -1) {
      _bookings[index] = _bookings[index].copyWith(status: status);
      _update();
    }
    return true;
  }

  @override
  Future<bool> cancelBooking(String bookingId) async {
    return updateBookingStatus(bookingId, BookingStatus.cancelled);
  }

  @override
  Stream<List<Booking>> getUpcomingBookings(String userId) {
    final now = DateTime.now();
    return getUserBookings(userId).map(
      (bookings) => bookings
          .where((b) =>
              b.status == BookingStatus.confirmed &&
              b.startTime.isAfter(now))
          .toList(),
    );
  }

  @override
  Stream<List<Booking>> getBookingHistory(String userId) {
    return getUserBookings(userId).map(
      (bookings) => bookings
          .where((b) =>
              b.status == BookingStatus.completed || b.isCompleted)
          .toList(),
    );
  }

  @override
  Future<bool> submitMatchResult({
    required String bookingId,
    required String teamId,
    required MatchOutcome outcome,
    double? rating,
    String? review,
  }) async {
    final index = _bookings.indexWhere((b) => b.id == bookingId);
    if (index == -1) return false;

    final booking = _bookings[index];
    
    if (booking.matchResultStatus == MatchResultStatus.noResult) {
      _bookings[index] = booking.copyWith(
        pendingOutcome: outcome,
        resultSubmittedByTeamId: teamId,
        matchResultStatus: MatchResultStatus.waitingOpponent,
      );
      _update();
      return true;
    } else if (booking.matchResultStatus == MatchResultStatus.waitingOpponent && 
               booking.resultSubmittedByTeamId != teamId) {
      if (booking.pendingOutcome == outcome) {
        _bookings[index] = booking.copyWith(
          finalOutcome: outcome,
          matchResultStatus: MatchResultStatus.confirmed,
          status: BookingStatus.completed,
          pendingOutcome: null,
          resultSubmittedByTeamId: null,
        );
        
        // ── Update Global Rankings (Mock) ──
        if (booking.playerTeamId != null && booking.opponentTeamId != null) {
          DatabaseService().updateMatchResult(
            bookingId, 
            booking.playerTeamId!, 
            booking.opponentTeamId!, 
            outcome
          );
        }

        _update();
        return true;
      } else {
        _bookings[index] = booking.copyWith(
          matchResultStatus: MatchResultStatus.disputed,
        );
        _update();
        return false;
      }
    }
    return false;
  }

  @override
  Stream<List<Booking>> getBookingsForStadium(String stadiumId, DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return Stream.value(_bookings
        .where((b) =>
            b.stadiumId == stadiumId &&
            b.startTime.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
            b.startTime.isBefore(endOfDay) &&
            b.status != BookingStatus.cancelled)
        .toList());
  }

  @override
  Future<bool> updatePaymentStatus(String bookingId, bool isPaid) async {
    final index = _bookings.indexWhere((b) => b.id == bookingId);
    if (index != -1) {
      _bookings[index] = _bookings[index].copyWith(isPaid: isPaid);
      _update();
    }
    return true;
  }

  /// Add mock bookings for testing
  void addMockBookings() {
    final now = DateTime.now();
    
    // Upcoming booking
    _bookings.add(Booking(
      id: 'mock_1',
      stadiumId: '1',
      stadiumName: 'Santiago Bernabéu',
      stadiumImageUrl: 'https://images.unsplash.com/photo-1556056504-5c7696c4c28d?w=800',
      ownerId: 'owner_1',
      startTime: now.add(const Duration(days: 2, hours: 3)),
      endTime: now.add(const Duration(days: 2, hours: 5)),
      bookingType: BookingType.personal,
      isPrivate: false,
      rentBall: true,
      totalPrice: 140,
      paymentMethod: 'card',
      status: BookingStatus.confirmed,
      createdByUserId: 'demo_user',
      createdAt: now.subtract(const Duration(days: 1)),
    ));

    // Completed booking
    _bookings.add(Booking(
      id: 'mock_2',
      stadiumId: '2',
      stadiumName: 'Camp Nou',
      stadiumImageUrl: 'https://images.unsplash.com/photo-1574629810360-7efbbe195018?w=800',
      ownerId: 'owner_2',
      startTime: now.subtract(const Duration(days: 5, hours: 3)),
      endTime: now.subtract(const Duration(days: 5, hours: 1)),
      bookingType: BookingType.team,
      playerTeamId: 'team_1',
      playerTeamName: 'Real Madrid CF',
      isPrivate: true,
      rentBall: false,
      totalPrice: 180,
      paymentMethod: 'wallet',
      status: BookingStatus.completed,
      createdByUserId: 'demo_user',
      createdAt: now.subtract(const Duration(days: 6)),
    ));
  }
}
