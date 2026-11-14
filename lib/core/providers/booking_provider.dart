import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models.dart';
import '../repositories/booking_repository.dart';
import 'booking/booking_categorization_service.dart';
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
  List<Booking> _publicMatches = []; // Dedicated list for paginated matches
  Booking? _currentBooking;
  BookingDraft? _currentDraft;
  String? _draftOwnerUserId;
  String? _activeOwnerId;
  String? _activeUserId;
  // Every booking-list request owns a generation. Older async work must never
  // repopulate lists or errors for a newer account, role, or refresh.
  int _bookingScopeGeneration = 0;

  bool _isLoading = false;
  int _userBookingLoadCount = 0;
  int _ownerBookingLoadCount = 0;
  bool _hasLoadedOwnerBookings = false;
  String? _ownerBookingsError;
  bool _isLoadingPublicMatches = false;
  bool _hasMoreMatches = true;
  String? _errorMessage;
  final Set<String> _cancellingIds = {};
  final Set<String> _updatingPaymentIds = {};
  final Set<String> _rescheduleRequestIds = {};
  final Set<String> _rescheduleResponseIds = {};
  final Set<String> _joiningMatchKeys = {};
  final Set<String> _leavingMatchKeys = {};
  int _draftRestoreGeneration = 0;
  // Unlike booking refreshes, identity transitions invalidate action locks.
  // An old Future must not unlock a new account's action with the same ID.
  int _actionIdentityGeneration = 0;

  void _resetActionLocksForIdentityChange() {
    _actionIdentityGeneration++;
    _cancellingIds.clear();
    _updatingPaymentIds.clear();
    _rescheduleRequestIds.clear();
    _rescheduleResponseIds.clear();
    _joiningMatchKeys.clear();
    _leavingMatchKeys.clear();
  }

  // Getters - _userBookings is the Single Source of Truth (SSOT)
  List<Booking> get userBookings =>
      _userBookings.where((b) => !_cancellingIds.contains(b.id)).toList();

  List<Booking> get upcomingBookings {
    final active = userBookings;
    return BookingCategorizationService.categorizeUserBookings(
      bookings: active,
      now: DateTime.now(),
    ).upcoming;
  }

  List<Booking> get historyBookings {
    final active = userBookings;
    return BookingCategorizationService.categorizeUserBookings(
      bookings: active,
      now: DateTime.now(),
    ).history;
  }

  List<Booking> get pendingBookings {
    final active = userBookings;
    return BookingCategorizationService.categorizeUserBookings(
      bookings: active,
      now: DateTime.now(),
    ).pending;
  }

  List<Booking> get publicMatches => _publicMatches;
  Booking? get currentBooking => _currentBooking;
  BookingDraft? get currentDraft => _currentDraft;
  bool get isLoading => _isLoading;
  bool get isLoadingUserBookings => _userBookingLoadCount > 0;
  bool get isLoadingOwnerBookings => _ownerBookingLoadCount > 0;
  bool get hasLoadedOwnerBookings => _hasLoadedOwnerBookings;
  String? get ownerBookingsError => _ownerBookingsError;
  bool get isLoadingPublicMatches => _isLoadingPublicMatches;
  bool get isLoadingMoreMatches => _isLoadingPublicMatches;
  bool get hasMoreMatches => _hasMoreMatches;
  String? get errorMessage => _errorMessage;

  BookingProvider({
    BookingRepository? repository,
    BookingMatchCoordinator? matchCoordinator,
  }) {
    _repository = repository ?? SupabaseBookingRepository();
    _syncCoordinator = BookingSyncCoordinator(_repository);
    _matchCoordinator = matchCoordinator ?? BookingMatchCoordinator();
    // Do not restore before authentication has established an identity.
  }

  Future<void> _clearDraftOnAccountScopeChange() async {
    _draftRestoreGeneration++;
    _currentDraft = null;
    _draftOwnerUserId = null;
    await BookingDraftStorage.clear();
  }

  Future<void> _restoreDraft({required String userId}) async {
    final generation = ++_draftRestoreGeneration;
    final scopeGeneration = _bookingScopeGeneration;
    final restored = await BookingDraftStorage.restore(userId: userId);
    if (generation != _draftRestoreGeneration ||
        scopeGeneration != _bookingScopeGeneration ||
        _activeUserId != userId ||
        _currentDraft != null) return;
    if (restored != null) {
      _draftOwnerUserId = userId;
      _currentDraft = restored;
      notifyListeners();
    }
  }

  /// Set the current booking draft (used between screens)
  void setDraft(BookingDraft draft) {
    _draftRestoreGeneration++;
    _draftOwnerUserId = BookingDraftStorage.currentAuthenticatedUserId();
    _currentDraft = draft;
    BookingDraftStorage.save(draft, userId: _draftOwnerUserId ?? '');
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
    String? challengeCode,
  }) {
    if (_currentDraft != null) {
      final currentUser = BookingDraftStorage.currentAuthenticatedUserId();
      if (_draftOwnerUserId == null || _draftOwnerUserId != currentUser) {
        // A draft from an unverified or previous session is never editable.
        clearDraft();
        return;
      }
      _draftRestoreGeneration++;
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
        challengeCode: challengeCode,
      );
      BookingDraftStorage.save(_currentDraft, userId: _draftOwnerUserId ?? '');
      notifyListeners();
    }
  }

  /// Clear the current draft
  void clearDraft() {
    _draftRestoreGeneration++;
    _currentDraft = null;
    _draftOwnerUserId = null;
    BookingDraftStorage.clear();
    notifyListeners();
  }

  /// Create booking after successful payment
  Future<Booking?> createBookingFromDraft(String userId) async {
    final operationScope = _bookingScopeGeneration;
    final actionIdentity = _actionIdentityGeneration;
    if (_currentDraft == null) {
      _errorMessage = 'No booking draft available';
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final submittedDraftGeneration = _draftRestoreGeneration;
      final booking = await _repository.createBooking(_currentDraft!, userId);
      if (operationScope != _bookingScopeGeneration) {
        return actionIdentity == _actionIdentityGeneration ? booking : null;
      }
      _currentBooking = booking;
      BookingListModifier.insertBooking(_userBookings, booking);
      // Successful creation must invalidate both the in-memory draft and its
      // persisted copy. Otherwise restart can offer to submit it again.
      // Do not destroy a newer draft edited while the RPC was in progress.
      if (submittedDraftGeneration == _draftRestoreGeneration) {
        _draftRestoreGeneration++;
        _currentDraft = null;
        _draftOwnerUserId = null;
        unawaited(BookingDraftStorage.clear());
      }

      _isLoading = false;
      notifyListeners();
      return booking;
    } catch (e) {
      if (operationScope != _bookingScopeGeneration) return null;
      // Reuse the domain error translator; never show a raw gateway/RPC body.
      _errorMessage = BookingListModifier.formatCreationError(e);
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Create booking directly with a draft (alternative method)
  Future<Booking?> createBooking(BookingDraft draft, String userId) async {
    final operationScope = _bookingScopeGeneration;
    final actionIdentity = _actionIdentityGeneration;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final booking = await _repository.createBooking(draft, userId);
      if (operationScope != _bookingScopeGeneration) {
        return actionIdentity == _actionIdentityGeneration ? booking : null;
      }
      _currentBooking = booking;
      BookingListModifier.insertBooking(_userBookings, booking);

      _isLoading = false;
      notifyListeners();
      return booking;
    } catch (e) {
      if (operationScope != _bookingScopeGeneration) return null;
      _errorMessage = BookingListModifier.formatCreationError(e);
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Load user's bookings
  Future<bool> loadUserBookings(String userId) async {
    final requestGeneration = ++_bookingScopeGeneration;
    if (_activeUserId != userId) {
      final clearOldDraft = _activeUserId != null || _activeOwnerId != null;
      // Clear the previous scope synchronously *before* any async storage
      // operation. Otherwise a late user-A callback may appear on user-B UI.
      _activeUserId = userId;
      _activeOwnerId = null;
      _resetActionLocksForIdentityChange();
      _userBookings = [];
      _isLoading = false;
      // The selected booking, public-match cache, and pending owner UI are
      // tied to the previous identity and cannot follow another session.
      _currentBooking = null;
      _publicMatches = [];
      _isLoadingPublicMatches = false;
      _hasMoreMatches = true;
      _userBookingLoadCount = 0;
      _ownerBookingLoadCount = 0;
      _hasLoadedOwnerBookings = false;
      _ownerBookingsError = null;
      _errorMessage = null;
      notifyListeners();
      if (clearOldDraft) {
        await _clearDraftOnAccountScopeChange();
        if (requestGeneration != _bookingScopeGeneration) return false;
      } else {
        if (_currentDraft != null && _draftOwnerUserId != userId) {
          // The first established account must not inherit an unscoped or
          // earlier in-memory checkout draft.
          _draftRestoreGeneration++;
          _currentDraft = null;
          _draftOwnerUserId = null;
          unawaited(BookingDraftStorage.clear());
        } else if (_currentDraft == null) {
          unawaited(_restoreDraft(userId: userId));
        }
      }
    }
    if (requestGeneration != _bookingScopeGeneration) return false;

    // Track only the newest request. Older same-account refreshes are
    // superseded and cannot leave a stuck loading spinner.
    _userBookingLoadCount = 1;
    _errorMessage = null;
    notifyListeners();
    try {
      return await _syncCoordinator.syncUserBookings(
        userId: userId,
        onData: (userBookings, _) {
          if (requestGeneration != _bookingScopeGeneration ||
              _activeUserId != userId) return;
          _userBookings = userBookings;
          _errorMessage = null;
          notifyListeners();
        },
        onError: (message) {
          if (requestGeneration != _bookingScopeGeneration ||
              _activeUserId != userId) return;
          _errorMessage = message;
          notifyListeners();
        },
      );
    } finally {
      if (requestGeneration == _bookingScopeGeneration &&
          _activeUserId == userId) {
        _userBookingLoadCount = 0;
        notifyListeners();
      }
    }
  }

  /// Load owner's bookings (for stadium owners)
  Future<void> loadOwnerBookings(
    String ownerId, {
    List<String>? stadiumIds,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _activeOwnerId == ownerId) return;
    final requestGeneration = ++_bookingScopeGeneration;

    if (_activeOwnerId != ownerId || _activeUserId != null) {
      final clearOldDraft = _activeOwnerId != null || _activeUserId != null;
      _activeUserId = null;
      _activeOwnerId = ownerId;
      _resetActionLocksForIdentityChange();
      _userBookings = [];
      _isLoading = false;
      _currentBooking = null;
      _publicMatches = [];
      _isLoadingPublicMatches = false;
      _hasMoreMatches = true;
      _userBookingLoadCount = 0;
      _ownerBookingLoadCount = 0;
      _hasLoadedOwnerBookings = false;
      _ownerBookingsError = null;
      _errorMessage = null;
      notifyListeners();
      if (clearOldDraft) {
        await _clearDraftOnAccountScopeChange();
        if (requestGeneration != _bookingScopeGeneration) return;
      } else {
        // A venue owner must never inherit a player's draft on first login.
        _draftRestoreGeneration++;
        _currentDraft = null;
        _draftOwnerUserId = null;
        unawaited(BookingDraftStorage.clear());
      }
    }
    if (requestGeneration != _bookingScopeGeneration) return;

    _ownerBookingLoadCount = 1;
    _ownerBookingsError = null;
    notifyListeners();

    try {
      await _syncCoordinator.syncOwnerBookings(
        ownerId: ownerId,
        stadiumIds: stadiumIds,
        getCurrentBookings: () => _userBookings,
        cancellingIds: _cancellingIds,
        onData: (merged, _) {
          if (requestGeneration != _bookingScopeGeneration ||
              _activeOwnerId != ownerId) return;
          _userBookings = merged;
          _hasLoadedOwnerBookings = true;
          _ownerBookingsError = null;
          notifyListeners();
        },
        onError: (message) {
          if (requestGeneration != _bookingScopeGeneration ||
              _activeOwnerId != ownerId) return;
          _ownerBookingsError = message;
          notifyListeners();
        },
      );
    } finally {
      if (requestGeneration == _bookingScopeGeneration &&
          _activeOwnerId == ownerId) {
        _ownerBookingLoadCount = 0;
        notifyListeners();
      }
    }
  }

  /// Cancel a booking
  Future<bool> cancelBooking(String bookingId) async {
    final operationScope = _bookingScopeGeneration;
    final actionIdentity = _actionIdentityGeneration;
    // Prevent duplicate cancellation RPCs from rapid taps or concurrent callers.
    if (_cancellingIds.contains(bookingId)) return false;
    _cancellingIds.add(bookingId);
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _repository.cancelBooking(bookingId);
      if (operationScope != _bookingScopeGeneration) {
            return actionIdentity == _actionIdentityGeneration && success;
          }
      if (success) {
        // Keep the cancelled booking in history so a pending/confirmed refund
        // remains visible and trackable from the user's booking record.
        try {
          final updatedBooking = await _repository.getBookingByIdStrict(bookingId);
          if (operationScope != _bookingScopeGeneration) {
            return actionIdentity == _actionIdentityGeneration && success;
          }
          if (updatedBooking != null) {
            BookingListModifier.updateBooking(_userBookings, updatedBooking);
            if (_currentBooking?.id == bookingId) {
              _currentBooking = updatedBooking;
            }
          } else {
            // A successful cancellation must not erase the booking history
            // merely because the follow-up read returned no record.
            final existingIndex =
                _userBookings.indexWhere((item) => item.id == bookingId);
            if (existingIndex >= 0) {
              BookingListModifier.updateBooking(
                _userBookings,
                _userBookings[existingIndex]
                    .copyWith(status: BookingStatus.cancelled),
              );
            }
            if (_currentBooking?.id == bookingId) {
              _currentBooking =
                  _currentBooking!.copyWith(status: BookingStatus.cancelled);
            }
          }
        } catch (_) {
          if (operationScope != _bookingScopeGeneration) {
            return actionIdentity == _actionIdentityGeneration && success;
          }
          // Cancellation is already confirmed. Keep the record in history with
          // a cancelled status while the next strict sync refreshes refund fields.
          final existingIndex = _userBookings.indexWhere((item) => item.id == bookingId);
          if (existingIndex >= 0) {
            BookingListModifier.updateBooking(
              _userBookings,
              _userBookings[existingIndex].copyWith(status: BookingStatus.cancelled),
            );
          }
          if (_currentBooking?.id == bookingId) {
            _currentBooking =
                _currentBooking!.copyWith(status: BookingStatus.cancelled);
          }
          debugPrint('Cancelled booking refresh failed (details redacted)');
        }
        await Future.delayed(const Duration(milliseconds: 300));
      } else {
        _errorMessage ??= 'عذراً، تعذر إلغاء الحجز في الوقت الحالي.';
      }
      return success;
    } catch (e) {
      if (operationScope == _bookingScopeGeneration) {
        _errorMessage = BookingListModifier.formatCreationError(e);
      }
      return false;
    } finally {
      if (actionIdentity == _actionIdentityGeneration) {
        _cancellingIds.remove(bookingId);
        if (operationScope == _bookingScopeGeneration) notifyListeners();
      }
    }
  }

  /// Request booking rescheduling (Owner)
  Future<bool> requestReschedule({
    required String bookingId,
    required DateTime newStartTime,
    required DateTime newEndTime,
  }) async {
    final operationScope = _bookingScopeGeneration;
    final actionIdentity = _actionIdentityGeneration;
    if (_rescheduleRequestIds.contains(bookingId)) return false;
    _rescheduleRequestIds.add(bookingId);
    _errorMessage = null;
    notifyListeners();
    try {
      final success = await _repository.requestReschedule(
        bookingId: bookingId,
        newStartTime: newStartTime,
        newEndTime: newEndTime,
      );
      if (operationScope != _bookingScopeGeneration) {
        return actionIdentity == _actionIdentityGeneration && success;
      }
      if (!success) {
        _errorMessage = 'تعذر إرسال اقتراح الموعد الجديد حالياً.';
      }
      return success;
    } catch (_) {
      if (operationScope == _bookingScopeGeneration) {
        _errorMessage = 'تعذر إرسال اقتراح الموعد الجديد حالياً.';
      }
      return false;
    } finally {
      if (actionIdentity == _actionIdentityGeneration) {
        _rescheduleRequestIds.remove(bookingId);
        if (operationScope == _bookingScopeGeneration) notifyListeners();
      }
    }
  }

  /// Respond to rescheduling request (Player)
  Future<bool> respondToReschedule({
    required String bookingId,
    required bool accept,
  }) async {
    final operationScope = _bookingScopeGeneration;
    final actionIdentity = _actionIdentityGeneration;
    if (_rescheduleResponseIds.contains(bookingId)) return false;
    _rescheduleResponseIds.add(bookingId);
    _errorMessage = null;
    notifyListeners();
    try {
      final success = await _repository.respondToReschedule(
        bookingId: bookingId,
        accept: accept,
      );
      if (operationScope != _bookingScopeGeneration) {
        return actionIdentity == _actionIdentityGeneration && success;
      }
      if (!success) {
        _errorMessage = accept
            ? 'تعذر قبول الموعد المقترح حالياً.'
            : 'تعذر رفض الموعد المقترح حالياً.';
      }
      return success;
    } catch (_) {
      if (operationScope == _bookingScopeGeneration) {
        _errorMessage = accept
            ? 'تعذر قبول الموعد المقترح حالياً.'
            : 'تعذر رفض الموعد المقترح حالياً.';
      }
      return false;
    } finally {
      if (actionIdentity == _actionIdentityGeneration) {
        _rescheduleResponseIds.remove(bookingId);
        if (operationScope == _bookingScopeGeneration) notifyListeners();
      }
    }
  }

  /// Request emergency stadium closure (Owner - 1 per 30 days)
  Future<Map<String, dynamic>> requestEmergencyClosure({
    required String stadiumId,
    required String ownerId,
    required String reason,
    required int durationHours,
  }) async {
    final operationScope = _bookingScopeGeneration;
    final actionIdentity = _actionIdentityGeneration;
    final res = await _repository.requestEmergencyClosure(
      stadiumId: stadiumId,
      ownerId: ownerId,
      reason: reason,
      durationHours: durationHours,
    );
    if (actionIdentity != _actionIdentityGeneration) {
      return {
        'success': false,
        'message': 'تغير الحساب أثناء الطلب. أعد المحاولة من حسابك الحالي.',
      };
    }
    if (operationScope == _bookingScopeGeneration) notifyListeners();
    return res;
  }

  /// Get a specific booking
  Future<Booking?> getBookingById(String bookingId) async {
    return await _repository.getBookingById(bookingId);
  }

  /// Fetch public matches directly from the unified active stream
  Future<void> fetchPublicMatches({bool isRefresh = false}) async {
    final operationScope = _bookingScopeGeneration;
    if (_isLoadingPublicMatches) return;
    // Initial reads and subsequent retries need the same visible loading
    // state. A failed refresh is not an authoritative empty feed.
    _isLoadingPublicMatches = true;
    _errorMessage = null;
    if (isRefresh) {
      _publicMatches = [];
      _hasMoreMatches = true;
    }
    notifyListeners();

    try {
      final matches = await _matchCoordinator.fetchPublicMatches();
      if (operationScope != _bookingScopeGeneration) return;
      _publicMatches = matches;
      _hasMoreMatches = false;
    } catch (_) {
      if (operationScope == _bookingScopeGeneration) {
        _errorMessage = 'تعذر تحميل المباريات حالياً.';
      }
    } finally {
      if (operationScope == _bookingScopeGeneration) {
        _isLoadingPublicMatches = false;
        notifyListeners();
      }
    }
  }

  /// Join a public match
  Future<bool> joinPublicMatch(String bookingId, String userId) async {
    final operationScope = _bookingScopeGeneration;
    final actionIdentity = _actionIdentityGeneration;
    final actionKey = '$bookingId|$userId';
    if (!_joiningMatchKeys.add(actionKey)) return false;
    _errorMessage = null;
    try {
      final res = await _matchCoordinator.joinPublicMatch(
        bookingId: bookingId,
        userId: userId,
      );
      if (operationScope == _bookingScopeGeneration) {
        _errorMessage = res.success ? null : (res.error ?? 'تعذر الانضمام للمباراة حاليًا. أعد المحاولة.');
      }
      return actionIdentity == _actionIdentityGeneration && res.success;
    } finally {
      if (actionIdentity == _actionIdentityGeneration) {
        _joiningMatchKeys.remove(actionKey);
        if (operationScope == _bookingScopeGeneration) notifyListeners();
      }
    }
  }

  /// Leave a public match
  Future<bool> leavePublicMatch(String bookingId, String userId) async {
    final operationScope = _bookingScopeGeneration;
    final actionIdentity = _actionIdentityGeneration;
    final actionKey = '$bookingId|$userId';
    if (!_leavingMatchKeys.add(actionKey)) return false;
    _errorMessage = null;
    try {
      final res = await _matchCoordinator.leavePublicMatch(
        bookingId: bookingId,
        userId: userId,
      );
      if (operationScope == _bookingScopeGeneration) {
        _errorMessage = res.success ? null : (res.error ?? 'تعذر مغادرة المباراة حاليًا. أعد المحاولة.');
      }
      return actionIdentity == _actionIdentityGeneration && res.success;
    } finally {
      if (actionIdentity == _actionIdentityGeneration) {
        _leavingMatchKeys.remove(actionKey);
        if (operationScope == _bookingScopeGeneration) notifyListeners();
      }
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
    final operationScope = _bookingScopeGeneration;
    final actionIdentity = _actionIdentityGeneration;
    _errorMessage = null;

    try {
      final success = await _repository.submitMatchResult(
        bookingId: bookingId,
        teamId: teamId,
        outcome: outcome,
        rating: rating,
        review: review,
      );
      if (operationScope != _bookingScopeGeneration) {
          return actionIdentity == _actionIdentityGeneration && success;
        }

      // A disputed submission may also change the server-side booking state
      // even when the RPC reports no finalized result. Refresh on both paths.
      // A read failure must never change the original submission outcome.
      try {
        final updated = await _repository.getBookingByIdStrict(bookingId);
        if (operationScope != _bookingScopeGeneration) {
          return actionIdentity == _actionIdentityGeneration && success;
        }
        if (updated != null) {
          BookingListModifier.updateBooking(_userBookings, updated);
          if (_currentBooking?.id == bookingId) {
            _currentBooking = updated;
          }
        }
      } catch (_) {
        debugPrint('Match result booking refresh failed (details redacted)');
      }
      if (operationScope != _bookingScopeGeneration) {
          return actionIdentity == _actionIdentityGeneration && success;
        }
      if (!success) {
        _errorMessage = 'Failed to submit result or results do not match.';
      }
      notifyListeners();
      return success;
    } catch (_) {
      if (operationScope != _bookingScopeGeneration) return false;
      _errorMessage = 'تعذر إرسال نتيجة المباراة. أعد المحاولة.';
      notifyListeners();
      return false;
    }
  }

  /// Update payment status
  Future<bool> updatePaymentStatus(String bookingId, bool isPaid) async {
    final operationScope = _bookingScopeGeneration;
    final actionIdentity = _actionIdentityGeneration;
    // Serialize updates for one booking to avoid conflicting payment writes.
    if (!_updatingPaymentIds.add(bookingId)) return false;
    _errorMessage = null;
    try {
      final success = await _repository.updatePaymentStatus(bookingId, isPaid);
      if (operationScope != _bookingScopeGeneration) {
          return actionIdentity == _actionIdentityGeneration && success;
        }
      if (success) {
        BookingListModifier.updatePaymentStatus(_userBookings, bookingId, isPaid);
        if (_currentBooking?.id == bookingId) {
          final current = <Booking>[_currentBooking!];
          BookingListModifier.updatePaymentStatus(current, bookingId, isPaid);
          _currentBooking = current.single;
        }
        // Publish the confirmed write immediately. The server refresh can be
        // slow; owners should not see the previous payment state while waiting.
        notifyListeners();
        // Reconcile the full payment/deposit fields with the server rather
        // than treating the optimistic flag as authoritative.
        try {
          final updated = await _repository.getBookingByIdStrict(bookingId);
          if (operationScope != _bookingScopeGeneration) {
          return actionIdentity == _actionIdentityGeneration && success;
        }
          if (updated != null) {
            final index = _userBookings.indexWhere((b) => b.id == bookingId);
            if (index >= 0) {
              BookingListModifier.updateBooking(_userBookings, updated);
            }
            if (_currentBooking?.id == bookingId) {
              _currentBooking = updated;
            }
          }
        } catch (_) {
          debugPrint('Payment status refresh failed (details redacted)');
        }
      }
      if (operationScope != _bookingScopeGeneration) {
          return actionIdentity == _actionIdentityGeneration && success;
        }
      if (!success) {
        _errorMessage = 'تعذر تحديث حالة الدفع';
      }
      notifyListeners();
      return success;
    } catch (_) {
      if (operationScope != _bookingScopeGeneration) return false;
      // Payment provider responses and trace metadata may contain account,
      // card-processing or booking IDs; never send them to device logs.
      debugPrint('Booking payment-status update failed (details redacted)');
      _errorMessage = 'تعذر تحديث حالة الدفع';
      notifyListeners();
      return false;
    } finally {
      if (actionIdentity == _actionIdentityGeneration) {
        _updatingPaymentIds.remove(bookingId);
      }
    }
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
    final operationScope = _bookingScopeGeneration;
    final actionIdentity = _actionIdentityGeneration;
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
      if (operationScope == _bookingScopeGeneration) {
        _isLoading = false;
        notifyListeners();
      }
      return actionIdentity == _actionIdentityGeneration && success;
    } catch (_) {
      if (operationScope == _bookingScopeGeneration) {
        _errorMessage = 'تعذر تحديث بيانات الحجز حاليًا.';
        _isLoading = false;
        notifyListeners();
      }
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
    // Invalidate all pending reads, mutations and scoped draft restores.
    // No old Future may notify a ChangeNotifier after it has been disposed.
    _bookingScopeGeneration++;
    _draftRestoreGeneration++;
    _actionIdentityGeneration++;
    _syncCoordinator.dispose();
    super.dispose();
  }
}
