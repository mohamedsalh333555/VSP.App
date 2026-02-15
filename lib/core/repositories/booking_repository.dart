import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../data/models.dart';

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
  });
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
      
      final status = draft.paymentMethod == 'cash' 
          ? BookingStatus.pending 
          : BookingStatus.confirmed;

      final booking = Booking.fromDraft(
        id: docRef.id,
        draft: draft,
        userId: userId,
        status: status,
      );

      await docRef.set(booking.toFirestore());

      debugPrint('✅ Booking created successfully: ${docRef.id}');
      return booking;
    } catch (e) {
      debugPrint('❌ Error creating booking: $e');
      rethrow;
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
        'updatedAt': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('❌ Error updating booking status: $e');
      return false;
    }
  }

  @override
  Future<bool> cancelBooking(String bookingId) async {
    return updateBookingStatus(bookingId, BookingStatus.cancelled);
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
    }) async {
      try {
        final docRef = _bookingsCollection.doc(bookingId);
        final doc = await docRef.get();
        if (!doc.exists) return false;

        final data = doc.data() as Map<String, dynamic>;
        final currentMatchStatus = data['matchResultStatus'] ?? 'noResult';
        final submittedBy = data['resultSubmittedByTeamId'];

        if (currentMatchStatus == 'noResult') {
          // First team submitting
          await docRef.update({
            'pendingOutcome': outcome.name,
            'resultSubmittedByTeamId': teamId,
            'matchResultStatus': MatchResultStatus.waitingOpponent.name,
          });
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
            return true;
          } else {
            // Disagreement on result
            await docRef.update({
              'matchResultStatus': MatchResultStatus.disputed.name,
            });
            return false;
          }
        }
        return false;
      } catch (e) {
        debugPrint('❌ Error submitting match result: $e');
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
    
    final status = draft.paymentMethod == 'cash' 
        ? BookingStatus.pending 
        : BookingStatus.confirmed;

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
  Stream<List<Booking>> getUserBookings(String userId) {
    return _controller.stream.map(
      (bookings) => bookings.where((b) => b.createdByUserId == userId).toList(),
    );
  }

  @override
  Stream<List<Booking>> getOwnerBookings(String ownerId) {
    return _controller.stream.map(
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
    // Mock implementation - in real scenario, we'd update the booking
    return true;
  }

  @override
  Future<bool> cancelBooking(String bookingId) async {
    return updateBookingStatus(bookingId, BookingStatus.cancelled);
  }

  @override
  Stream<List<Booking>> getUpcomingBookings(String userId) {
    final now = DateTime.now();
    return _controller.stream.map(
      (bookings) => bookings
          .where((b) =>
              b.createdByUserId == userId &&
              b.status == BookingStatus.confirmed &&
              b.startTime.isAfter(now))
          .toList(),
    );
  }

  @override
  Stream<List<Booking>> getBookingHistory(String userId) {
    return _controller.stream.map(
      (bookings) => bookings
          .where((b) =>
              b.createdByUserId == userId &&
              (b.status == BookingStatus.completed || b.isCompleted))
          .toList(),
    );
  }

  @override
  Future<bool> submitMatchResult({
    required String bookingId,
    required String teamId,
    required MatchOutcome outcome,
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
