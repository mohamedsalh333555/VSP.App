import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models.dart';
import '../repositories/booking_repository.dart';
import '../config/app_config.dart';

/// Booking Provider for state management
class BookingProvider with ChangeNotifier {
  late final BookingRepository _repository;
  
  List<Booking> _userBookings = [];
  List<Booking> _upcomingBookings = [];
  List<Booking> _historyBookings = [];
  Booking? _currentBooking;
  BookingDraft? _currentDraft;
  StreamSubscription? _bookingSubscription; // ✅ Added tracking
  
  bool _isLoading = false;
  String? _errorMessage;
  final Set<String> _cancellingIds = {};

  // Getters
  List<Booking> get userBookings => _userBookings.where((b) => !_cancellingIds.contains(b.id)).toList();
  List<Booking> get upcomingBookings => _upcomingBookings.where((b) => !_cancellingIds.contains(b.id)).toList();
  List<Booking> get historyBookings => _historyBookings.where((b) => !_cancellingIds.contains(b.id)).toList();
  Booking? get currentBooking => _currentBooking;
  BookingDraft? get currentDraft => _currentDraft;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  BookingProvider() {
    // Use mock repository in demo mode, Firestore in production
    if (AppConfig.demoMode) {
      final mockRepo = MockBookingRepository();
      mockRepo.addMockBookings(); // Add sample data
      _repository = mockRepo;
    } else {
      _repository = FirestoreBookingRepository();
    }
  }

  /// Set the current booking draft (used between screens)
  void setDraft(BookingDraft draft) {
    _currentDraft = draft;
    notifyListeners();
  }

  /// Update the current draft with new values
  void updateDraft({
    String? paymentMethod,
    String? paymentTransactionId,
    bool? isPrivate,
    bool? rentBall,
    double? totalPrice,
    DateTime? startTime,
    DateTime? endTime,
    BookingType? bookingType,
    String? opponentTeamId,
    String? opponentTeamName,
  }) {
    if (_currentDraft != null) {
      _currentDraft = _currentDraft!.copyWith(
        paymentMethod: paymentMethod,
        paymentTransactionId: paymentTransactionId,
        isPrivate: isPrivate,
        rentBall: rentBall,
        totalPrice: totalPrice,
        startTime: startTime,
        endTime: endTime,
        bookingType: bookingType,
        opponentTeamId: opponentTeamId,
        opponentTeamName: opponentTeamName,
      );
      notifyListeners();
    }
  }

  /// Clear the current draft
  void clearDraft() {
    _currentDraft = null;
    notifyListeners();
  }

  /// Create booking after successful payment
  Future<Booking?> createBookingFromDraft(String userId) async {
    if (_currentDraft == null) {
      _errorMessage = 'No booking draft available';
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final booking = await _repository.createBooking(_currentDraft!, userId);
      _currentBooking = booking;
      _upcomingBookings.insert(0, booking);
      _userBookings.insert(0, booking);
      _currentDraft = null; // Clear draft after successful creation
      
      _isLoading = false;
      notifyListeners();
      return booking;
    } catch (e) {
      _errorMessage = 'Failed to create booking: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Create booking directly with a draft (alternative method)
  Future<Booking?> createBooking(BookingDraft draft, String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final booking = await _repository.createBooking(draft, userId);
      _currentBooking = booking;
      _upcomingBookings.insert(0, booking);
      _userBookings.insert(0, booking);
      
      _isLoading = false;
      notifyListeners();
      return booking;
    } catch (e) {
      _errorMessage = 'Failed to create booking: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Load user's bookings
  void loadUserBookings(String userId) {
    _bookingSubscription?.cancel();
    _bookingSubscription = _repository.getUserBookings(userId).listen(
      (bookings) {
        _userBookings = bookings;
        // Split into upcoming and history
        final now = DateTime.now();
        _upcomingBookings = bookings
            .where((b) => 
                b.status == BookingStatus.confirmed && 
                b.endTime.isAfter(now))
            .toList();
        _historyBookings = bookings
            .where((b) => 
                b.status == BookingStatus.completed || 
                b.status == BookingStatus.cancelled ||
                (b.status == BookingStatus.confirmed && b.endTime.isBefore(now)))
            .toList();
        notifyListeners();
      },
      onError: (e) {
        _errorMessage = 'Failed to load bookings: $e';
        notifyListeners();
      },
    );
  }

  /// Load owner's bookings (for stadium owners)
  void loadOwnerBookings(String ownerId) {
    _bookingSubscription?.cancel();
    _bookingSubscription = _repository.getOwnerBookings(ownerId).listen(
      (bookings) {
        _userBookings = bookings;
        final now = DateTime.now();
        _upcomingBookings = bookings
            .where((b) => 
                b.status == BookingStatus.confirmed && 
                b.endTime.isAfter(now))
            .toList();
        _historyBookings = bookings
            .where((b) => 
                b.status == BookingStatus.completed || 
                b.status == BookingStatus.cancelled ||
                (b.status == BookingStatus.confirmed && b.endTime.isBefore(now)))
            .toList();
        notifyListeners();
      },
      onError: (e) {
        _errorMessage = 'Failed to load bookings: $e';
        notifyListeners();
      },
    );
  }

  /// Cancel a booking
  Future<bool> cancelBooking(String bookingId) async {
    _cancellingIds.add(bookingId);
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _repository.cancelBooking(bookingId);
      if (success) {
        _upcomingBookings.removeWhere((b) => b.id == bookingId);
        _userBookings.removeWhere((b) => b.id == bookingId);
        _historyBookings.removeWhere((b) => b.id == bookingId);
        // Keep in set for a moment to allow Firestore to sync.
        await Future.delayed(const Duration(seconds: 1));
      } else {
        _errorMessage = 'Failed to cancel on server';
      }
      _cancellingIds.remove(bookingId);
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = 'Failed to cancel booking: $e';
      _cancellingIds.remove(bookingId);
      notifyListeners();
      return false;
    }
  }

  /// Get a specific booking
  Future<Booking?> getBookingById(String bookingId) async {
    return await _repository.getBookingById(bookingId);
  }

  /// Submit match result for Challenge bookings
  Future<bool> submitMatchResult({
    required String bookingId,
    required String teamId,
    required MatchOutcome outcome,
    double? rating,
    String? review,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _repository.submitMatchResult(
        bookingId: bookingId,
        teamId: teamId,
        outcome: outcome,
        rating: rating,
        review: review,
      );
      
      if (!success) {
        _errorMessage = 'Failed to submit result or results do not match.';
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = 'Error submitting result: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Get bookings for a specific stadium and date (Stream)
  Stream<List<Booking>> getBookingsForStadium(String stadiumId, DateTime date) {
    return _repository.getBookingsForStadium(stadiumId, date);
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _bookingSubscription?.cancel();
    super.dispose();
  }
}
