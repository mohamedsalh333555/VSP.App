import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models.dart';
import '../repositories/booking_repository.dart';
import '../services/database_service.dart';

/// Booking Provider for state management
class BookingProvider with ChangeNotifier {
  late final BookingRepository _repository;

  List<Booking> _userBookings = [];
  List<Booking> _upcomingBookings = [];
  List<Booking> _historyBookings = [];
  List<Booking> _publicMatches = []; // ✅ Dedicated list for paginated matches
  Booking? _currentBooking;
  BookingDraft? _currentDraft;
  StreamSubscription? _bookingSubscription; // ✅ Added tracking

  bool _isLoading = false;
  final bool _isLoadingMoreParticipants = false;
  final bool _isLoadingMoreMatches = false;
  bool _hasMoreMatches = true;
  String? _errorMessage;
  final Set<String> _cancellingIds = {};

  // Getters
  List<Booking> get userBookings =>
      _userBookings.where((b) => !_cancellingIds.contains(b.id)).toList();
  List<Booking> get upcomingBookings =>
      _upcomingBookings.where((b) => !_cancellingIds.contains(b.id)).toList();
  List<Booking> get historyBookings =>
      _historyBookings.where((b) => !_cancellingIds.contains(b.id)).toList();
  List<Booking> get publicMatches => _publicMatches;
  Booking? get currentBooking => _currentBooking;
  BookingDraft? get currentDraft => _currentDraft;
  bool get isLoading => _isLoading;
  bool get isLoadingMoreMatches => _isLoadingMoreMatches;
  bool get hasMoreMatches => _hasMoreMatches;
  String? get errorMessage => _errorMessage;

  BookingProvider() {
    _repository = SupabaseBookingRepository();
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
    String? playerTeamId,
    String? playerTeamName,
    int? currentPlayers,
    int? maxPlayers,
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
        playerTeamId: playerTeamId,
        currentPlayers: currentPlayers,
        totalFieldCapacity: maxPlayers,
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
    _repository.autoExpirePendingChallenges();
    _repository.autoReconcileSingleEntryResults();
    _repository.autoNudgePostMatchResults();

    _bookingSubscription?.cancel();
    _bookingSubscription = _repository
        .getUserBookings(userId)
        .listen(
          (bookings) {
            _userBookings = bookings;
            // Split into upcoming and history
            final now = DateTime.now();
            _upcomingBookings = bookings
                .where(
                  (b) =>
                      b.status == BookingStatus.confirmed &&
                      b.endTime.isAfter(now),
                )
                .toList();
            _historyBookings = bookings
                .where(
                  (b) =>
                      b.status == BookingStatus.completed ||
                      b.status == BookingStatus.cancelled ||
                      (b.status == BookingStatus.confirmed &&
                          b.endTime.isBefore(now)),
                )
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
  void loadOwnerBookings(String ownerId, {List<String>? stadiumIds}) {
    _repository.autoExpirePendingChallenges();
    _repository.autoReconcileSingleEntryResults();
    _repository.autoNudgePostMatchResults();

    _bookingSubscription?.cancel();
    _bookingSubscription = _repository
        .getOwnerBookings(ownerId, stadiumIds: stadiumIds)
        .listen(
          (bookings) {
            _userBookings = bookings;
            final now = DateTime.now();
            _upcomingBookings = bookings
                .where(
                  (b) =>
                      b.status == BookingStatus.confirmed &&
                      b.endTime.isAfter(now),
                )
                .toList();
            _historyBookings = bookings
                .where(
                  (b) =>
                      b.status == BookingStatus.completed ||
                      b.status == BookingStatus.cancelled ||
                      (b.status == BookingStatus.confirmed &&
                          b.endTime.isBefore(now)),
                )
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
      // Find the booking in local state to check time early for UI feedback
      final booking = _userBookings.cast<Booking?>().firstWhere(
        (b) => b?.id == bookingId,
        orElse: () => null,
      );

      if (booking != null && DateTime.now().isAfter(booking.startTime)) {
        _errorMessage =
            "لا يمكن إلغاء الحجز بعد بدء وقت اللعب. تواصل مع صاحب الملعب.";
        _cancellingIds.remove(bookingId);
        notifyListeners();
        return false;
      }

      final success = await _repository.cancelBooking(bookingId);
      if (success) {
        _upcomingBookings.removeWhere((b) => b.id == bookingId);
        _userBookings.removeWhere((b) => b.id == bookingId);
        _historyBookings.removeWhere((b) => b.id == bookingId);
        // Keep in set for a moment to allow Firestore to sync.
        await Future.delayed(const Duration(seconds: 1));
      } else {
        _errorMessage =
            'لا يمكن إلغاء الحجز في الوقت الحالي. قد يكون وقت المباراة قد بدأ بالفعل.';
      }
      _cancellingIds.remove(bookingId);
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = 'فشل في إلغاء الحجز: $e';
      _cancellingIds.remove(bookingId);
      notifyListeners();
      return false;
    }
  }

  /// Get a specific booking
  Future<Booking?> getBookingById(String bookingId) async {
    return await _repository.getBookingById(bookingId);
  }

  /// Fetch public matches directly from the unified active stream to avoid pagination mismatch
  Future<void> fetchPublicMatches({bool isRefresh = false}) async {
    if (_isLoading) return;

    if (isRefresh) {
      _setLoading(true);
    }

    try {
      // Use the exact same stream function as the Home view for 100% consistency
      final stream = DatabaseService().getPublicMatches();
      final matches = await stream.first;

      _publicMatches = List<Booking>.from(matches);
      _hasMoreMatches =
          false; // Disable pagination as we fetch all valid upcoming
    } catch (e) {
      _errorMessage = 'Failed to fetch public matches: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Join a public match
  Future<bool> joinPublicMatch(String bookingId, String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await DatabaseService().joinPublicMatch(
        bookingId,
        userId,
      );
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('time_conflict')) {
        _errorMessage = 'time_conflict';
      } else {
        _errorMessage = errorStr.replaceAll('Exception: ', '');
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Leave a public match
  Future<bool> leavePublicMatch(String bookingId, String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await DatabaseService().leavePublicMatch(
        bookingId,
        userId,
      );
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = 'Error leaving match: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
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

  /// Update payment status
  Future<bool> updatePaymentStatus(String bookingId, bool isPaid) async {
    final success = await _repository.updatePaymentStatus(bookingId, isPaid);
    if (success) {
      final index = _userBookings.indexWhere((b) => b.id == bookingId);
      if (index != -1) {
        _userBookings[index] = _userBookings[index].copyWith(isPaid: isPaid);
        notifyListeners();
      }
    }
    return success;
  }

  /// Update manual booking details (owner operation)
  Future<bool> updateManualBooking({
    required String bookingId,
    required String name,
    required String phone,
    required String notes,
    required bool isDepositPaid,
    required double depositPaid,
    required String paymentStatus,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _repository.updateManualBooking(
        bookingId: bookingId,
        name: name,
        phone: phone,
        notes: notes,
        isDepositPaid: isDepositPaid,
        depositPaid: depositPaid,
        paymentStatus: paymentStatus,
      );
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = e.toString();
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
