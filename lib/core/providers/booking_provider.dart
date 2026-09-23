import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models.dart';
import '../repositories/booking_repository.dart';
import 'booking/booking_draft_storage.dart';
import 'booking/booking_list_modifier.dart';
import 'booking/booking_match_coordinator.dart';
import 'booking/booking_sync_coordinator.dart';

/// Booking Provider for state management
class BookingProvider with ChangeNotifier {
  late final BookingRepository _repository;
  late final BookingSyncCoordinator _syncCoordinator;
  late final BookingMatchCoordinator _matchCoordinator;

  List<Booking> _userBookings = [];
  List<Booking> _upcomingBookings = [];
  List<Booking> _historyBookings = [];
  List<Booking> _pendingBookings = [];
  List<Booking> _publicMatches = []; // Dedicated list for paginated matches
  Booking? _currentBooking;
  BookingDraft? _currentDraft;
  String? _activeOwnerId;

  bool _isLoading = false;
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
  List<Booking> get pendingBookings =>
      _pendingBookings.where((b) => !_cancellingIds.contains(b.id)).toList();
  List<Booking> get publicMatches => _publicMatches;
  Booking? get currentBooking => _currentBooking;
  BookingDraft? get currentDraft => _currentDraft;
  bool get isLoading => _isLoading;
  bool get isLoadingMoreMatches => _isLoadingMoreMatches;
  bool get hasMoreMatches => _hasMoreMatches;
  String? get errorMessage => _errorMessage;

  BookingProvider({
    BookingRepository? repository,
    BookingMatchCoordinator? matchCoordinator,
  }) {
    _repository = repository ?? SupabaseBookingRepository();
    _syncCoordinator = BookingSyncCoordinator(_repository);
    _matchCoordinator = matchCoordinator ?? BookingMatchCoordinator();
    _restoreDraft();
  }

  Future<void> _restoreDraft() async {
    final restored = await BookingDraftStorage.restore();
    if (restored != null) {
      _currentDraft = restored;
      notifyListeners();
    }
  }

  /// Set the current booking draft (used between screens)
  void setDraft(BookingDraft draft) {
    _currentDraft = draft;
    BookingDraftStorage.save(draft);
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
      _currentDraft = BookingListModifier.applyDraftUpdates(
        _currentDraft!,
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
        playerTeamName: playerTeamName,
        currentPlayers: currentPlayers,
        maxPlayers: maxPlayers,
      );
      BookingDraftStorage.save(_currentDraft);
      notifyListeners();
    }
  }

  /// Clear the current draft
  void clearDraft() {
    _currentDraft = null;
    BookingDraftStorage.clear();
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
      BookingListModifier.insertBooking(_upcomingBookings, booking);
      BookingListModifier.insertBooking(_userBookings, booking);
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
      BookingListModifier.insertBooking(_upcomingBookings, booking);
      BookingListModifier.insertBooking(_userBookings, booking);

      _isLoading = false;
      notifyListeners();
      return booking;
    } catch (e) {
      _errorMessage = BookingListModifier.formatCreationError(e);
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Load user's bookings
  void loadUserBookings(String userId) {
    _syncCoordinator.syncUserBookings(
      userId: userId,
      onData: (userBookings, categorized) {
        _userBookings = userBookings;
        _upcomingBookings = categorized.upcoming;
        _pendingBookings = categorized.pending;
        _historyBookings = categorized.history;
        notifyListeners();
      },
      onError: (e) {
        _errorMessage = e;
        notifyListeners();
      },
    );
  }

  /// Load owner's bookings (for stadium owners)
  Future<void> loadOwnerBookings(String ownerId, {List<String>? stadiumIds, bool forceRefresh = false}) async {
    if (!forceRefresh && _activeOwnerId == ownerId) {
      return;
    }
    _activeOwnerId = ownerId;

    await _syncCoordinator.syncOwnerBookings(
      ownerId: ownerId,
      stadiumIds: stadiumIds,
      getCurrentBookings: () => _userBookings,
      cancellingIds: _cancellingIds,
      onData: (merged, categorized) {
        _userBookings = merged;
        _upcomingBookings = categorized.upcoming;
        _historyBookings = categorized.history;
        notifyListeners();
      },
      onError: (e) {
        _errorMessage = e;
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
        BookingListModifier.removeBooking(_upcomingBookings, bookingId);
        BookingListModifier.removeBooking(_userBookings, bookingId);
        BookingListModifier.removeBooking(_historyBookings, bookingId);
        await Future.delayed(const Duration(milliseconds: 300));
      } else {
        _errorMessage ??= 'عذراً، تعذر إلغاء الحجز في الوقت الحالي.';
      }
      return success;
    } catch (e) {
      _errorMessage = e is Exception
          ? e.toString().replaceFirst('Exception: ', '').trim()
          : 'عذراً، تعذر إلغاء الحجز في الوقت الحالي.';
      return false;
    } finally {
      _cancellingIds.remove(bookingId);
      notifyListeners();
    }
  }

  /// Request booking rescheduling (Owner)
  Future<bool> requestReschedule({
    required String bookingId,
    required DateTime newStartTime,
    required DateTime newEndTime,
  }) async {
    final success = await _repository.requestReschedule(
      bookingId: bookingId,
      newStartTime: newStartTime,
      newEndTime: newEndTime,
    );
    if (success) notifyListeners();
    return success;
  }

  /// Respond to rescheduling request (Player)
  Future<bool> respondToReschedule({
    required String bookingId,
    required bool accept,
  }) async {
    final success = await _repository.respondToReschedule(
      bookingId: bookingId,
      accept: accept,
    );
    if (success) notifyListeners();
    return success;
  }

  /// Request emergency stadium closure (Owner - 1 per 30 days)
  Future<Map<String, dynamic>> requestEmergencyClosure({
    required String stadiumId,
    required String ownerId,
    required String reason,
    required int durationHours,
  }) async {
    final res = await _repository.requestEmergencyClosure(
      stadiumId: stadiumId,
      ownerId: ownerId,
      reason: reason,
      durationHours: durationHours,
    );
    notifyListeners();
    return res;
  }

  /// Get a specific booking
  Future<Booking?> getBookingById(String bookingId) async {
    return await _repository.getBookingById(bookingId);
  }

  /// Fetch public matches directly from the unified active stream
  Future<void> fetchPublicMatches({bool isRefresh = false}) async {
    if (_isLoading) return;
    if (isRefresh) _setLoading(true);

    try {
      _publicMatches = await _matchCoordinator.fetchPublicMatches();
      _hasMoreMatches = false;
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

    final res = await _matchCoordinator.joinPublicMatch(bookingId: bookingId, userId: userId);
    _isLoading = false;
    _errorMessage = res.error;
    notifyListeners();
    return res.success;
  }

  /// Leave a public match
  Future<bool> leavePublicMatch(String bookingId, String userId) async {
    _isLoading = true;
    notifyListeners();

    final res = await _matchCoordinator.leavePublicMatch(bookingId: bookingId, userId: userId);
    _isLoading = false;
    _errorMessage = res.error;
    notifyListeners();
    return res.success;
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
      BookingListModifier.updatePaymentStatus(_userBookings, bookingId, isPaid);
      BookingListModifier.updatePaymentStatus(_upcomingBookings, bookingId, isPaid);
      BookingListModifier.updatePaymentStatus(_historyBookings, bookingId, isPaid);
      notifyListeners();
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
    _syncCoordinator.dispose();
    super.dispose();
  }
}
