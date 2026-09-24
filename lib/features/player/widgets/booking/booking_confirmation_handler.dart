import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/constants/egypt_governorates.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/providers/booking_provider.dart';
import '../../../../core/repositories/booking_repository.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../data/models.dart';
import 'booking_payment_method_sheet.dart';
import 'booking_slot_calculator.dart';
import 'booking_slot_models.dart';
import '../../screens/payment_gateway_screen.dart';

/// Encapsulates all logic for the "Confirm Booking" action that was previously
/// inline in [BookingConfirmationScreen._handleBookingConfirmation].
///
/// Call [run] to trigger the full confirmation flow: availability re-check,
/// draft construction, payment-method routing.
class BookingConfirmationHandler {
  static String _normalizeType(String bookingType) =>
      bookingType.toLowerCase().replaceAll(' ', '').replaceAll('_', '');

  static bool isOpenJoin(String bookingType) {
    final t = _normalizeType(bookingType);
    return t == 'openjoin' || t == 'openjoinmatch';
  }

  static bool isChallenge(String bookingType) {
    final t = _normalizeType(bookingType);
    return t == 'challenge' || t == 'challengematch';
  }

  static bool isMatchup(String bookingType) {
    final t = _normalizeType(bookingType);
    return t == 'matchup' || t == 'matchups' || t == 'matchupmatch';
  }

  /// Runs the full booking-confirmation flow.
  ///
  /// [onLoadingChanged] is called with `true` before async work and `false`
  /// when finished (or on early return) so the screen can show/hide its loader.
  /// [onSlotsCleared] is called when a conflict is detected and the selection
  /// must be reset.
  static Future<void> run({
    required BuildContext context,
    required Stadium stadium,
    required String bookingType,
    required Team? opponentTeam,
    required List<String> selectedTimeSlots,
    required DateTime selectedDate,
    required List<TimeSlotItem> timeSlots,
    required bool isBallRented,
    required bool isPrivate,
    required double totalPrice,
    required int initialPlayersCount,
    required int currentPlayers,
    required String? userTeamId,
    required String? userTeamName,
    required ValueChanged<bool> onLoadingChanged,
    required VoidCallback onSlotsCleared,
  }) async {
    onLoadingChanged(true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserModel = authProvider.userModel;
    if (currentUserModel == null) {
      onLoadingChanged(false);
      return;
    }

    final nav = Navigator.of(context);
    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);

    // Mandatory anti-manipulation location check: the player must be physically
    // located in the same Egyptian governorate as the selected stadium.
    try {
      final (position, resolvedGovernorate) =
          await LocationService().getThrottledLocation(force: true);
      if (!context.mounted) return;

      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
      if (resolvedGovernorate == 'mock_location_detected') {
        VSPFeedback.showError(
          context,
          isArabic
              ? 'لا يمكن إتمام الحجز باستخدام موقع وهمي. فعّل الموقع الحقيقي على جهازك.'
              : 'Booking cannot continue with a mock location. Please enable your real device location.',
        );
        onLoadingChanged(false);
        return;
      }

      if (position == null || resolvedGovernorate == null || resolvedGovernorate.trim().isEmpty) {
        VSPFeedback.showError(
          context,
          isArabic
              ? 'لا يمكن إتمام الحجز بدون تحديد موقعك الفعلي. فعّل صلاحية الموقع وحاول مرة أخرى.'
              : 'Booking requires your current location. Please enable location permission and try again.',
        );
        onLoadingChanged(false);
        return;
      }

      final stadiumGovRaw = stadium.governorate?.trim() ?? '';
      final playerGovernorate =
          EgyptGovernorates.resolveGoogleName(resolvedGovernorate) ??
              resolvedGovernorate.trim().toLowerCase();
      final stadiumGovernorate =
          EgyptGovernorates.resolveGoogleName(stadiumGovRaw) ??
              stadiumGovRaw.toLowerCase();

      if (stadiumGovRaw.isNotEmpty &&
          playerGovernorate.toLowerCase() != stadiumGovernorate.toLowerCase()) {
        final stadiumName = EgyptGovernorates.getLocalizedName(
          EgyptGovernorates.resolveGoogleName(stadiumGovRaw) ??
              stadiumGovRaw,
          isArabic,
        );
        final playerName = EgyptGovernorates.getLocalizedName(
          EgyptGovernorates.resolveGoogleName(resolvedGovernorate) ??
              resolvedGovernorate,
          isArabic,
        );
        VSPFeedback.showError(
          context,
          isArabic
              ? 'لا يمكن إتمام الحجز لأنك موجود حالياً في محافظة $playerName بينما الملعب موجود في $stadiumName. يجب أن تكون داخل نفس المحافظة لإتمام الحجز.'
              : 'Booking is unavailable because you are currently in $playerName while this stadium is in $stadiumName. You must be in the same governorate to book.',
        );
        onLoadingChanged(false);
        return;
      }
    } catch (e) {
      VSPLogger.w('Mandatory location validation failed closed: $e');
      if (context.mounted) {
        final isArabic = Localizations.localeOf(context).languageCode == 'ar';
        VSPFeedback.showError(
          context,
          isArabic
              ? 'تعذر التحقق من موقعك الحالي. فعّل GPS وحاول مرة أخرى.'
              : 'Unable to verify your current location. Please enable GPS and try again.',
        );
      }
      onLoadingChanged(false);
      return;
    }

    // ── Pre-confirmation double-check ────────────────────────────────────────
    try {
      List<Booking> currentBookings = [];
      try {
        currentBookings = await bookingProvider
            .getBookingsForStadium(stadium.id, selectedDate)
            .first
            .timeout(const Duration(seconds: 4));
      } catch (_) {
        final repo = SupabaseBookingRepository();
        currentBookings = await repo.fetchStadiumBookingsDirectly(stadium.id, selectedDate);
      }

      if (!context.mounted) return;

      final sortedCheck = List<String>.from(selectedTimeSlots)
        ..sort((a, b) => BookingSlotCalculator.getSlotDateTime(
              slotKey: a,
              stadium: stadium,
              selectedDate: selectedDate,
            ).compareTo(BookingSlotCalculator.getSlotDateTime(
              slotKey: b,
              stadium: stadium,
              selectedDate: selectedDate,
            )));

      final isConflict = BookingSlotCalculator.isSlotBooked(
        slotKey: sortedCheck.first,
        stadium: stadium,
        selectedDate: selectedDate,
        existingBookings: currentBookings,
      );

      if (isConflict) {
        HapticFeedback.vibrate();
        onSlotsCleared();
        onLoadingChanged(false);
        if (context.mounted) {
          final isAr = Localizations.localeOf(context).languageCode == 'ar';
          VSPFeedback.showError(
            context,
            isAr
                ? 'عذراً، تم حجز وتأكيد هذه الساعة للتو بواسطة لاعب آخر. تم تحديث الجدول تلقائياً.'
                : 'Sorry, this slot was just booked by another player! Schedule updated automatically.',
          );
        }
        return;
      }
    } catch (e, stack) {
      VSPLogger.e('Error checking slot availability before booking', e, stack);
    }

    HapticFeedback.mediumImpact();

    // ── Build the booking draft ──────────────────────────────────────────────
    final sortedSlots = List<String>.from(selectedTimeSlots)
      ..sort((a, b) => BookingSlotCalculator.getSlotDateTime(
            slotKey: a,
            stadium: stadium,
            selectedDate: selectedDate,
          ).compareTo(BookingSlotCalculator.getSlotDateTime(
            slotKey: b,
            stadium: stadium,
            selectedDate: selectedDate,
          )));

    final firstSlot = sortedSlots.first;
    final startTime = BookingSlotCalculator.getSlotDateTime(
      slotKey: firstSlot,
      stadium: stadium,
      selectedDate: selectedDate,
    );
    final endTime = startTime.add(Duration(minutes: selectedTimeSlots.length * 30));

    BookingType bType;
    if (isOpenJoin(bookingType)) {
      bType = BookingType.openJoin;
    } else if (isChallenge(bookingType)) {
      bType = BookingType.challenge;
    } else if (isMatchup(bookingType)) {
      bType = BookingType.matchup;
    } else {
      bType = BookingType.personal;
    }

    final depositAmount = stadium.depositAmount;
    final fieldCapacity = stadium.totalFieldCapacity > 0
        ? stadium.totalFieldCapacity
        : (stadium.seatsCapacity > 0 ? stadium.seatsCapacity * 2 : 10);

    final draft = BookingDraft(
      stadiumId: stadium.id,
      stadiumName: stadium.name,
      stadiumImageUrl: stadium.imageUrl,
      ownerId: stadium.ownerId,
      startTime: startTime,
      endTime: endTime,
      bookingType: bType,
      playerTeamId:
          (bType == BookingType.team || bType == BookingType.challenge) ? userTeamId : null,
      playerTeamName: (bType == BookingType.team || bType == BookingType.challenge)
          ? userTeamName
          : currentUserModel.name,
      opponentTeamId: opponentTeam?.id,
      opponentTeamName: opponentTeam?.name,
      totalPrice: totalPrice,
      isPaid: false,
      isPrivate: isPrivate,
      rentBall: isBallRented,
      currentPlayers: (bType == BookingType.openJoin) ? initialPlayersCount : currentPlayers,
      playersPerTeam: stadium.playersPerTeam,
      totalFieldCapacity: fieldCapacity,
      depositPaid: depositAmount,
      isDepositPaid: false,
      needsDeposit: stadium.needsDeposit,
      instapay: stadium.features is Map ? stadium.features['instapay'] : null,
      vodafoneCash: stadium.features is Map ? stadium.features['vodafoneCash'] : null,
      binanceId: stadium.features is Map ? stadium.features['binanceId'] : null,
    );

    onLoadingChanged(false);

    // ── Route to payment ─────────────────────────────────────────────────────
    final bool requiresDeposit = stadium.needsDeposit && depositAmount > 0;

    if (!context.mounted) return;
    final isCashLocked = currentUserModel.noShowCount >= 2;
    if (isCashLocked && !requiresDeposit) {
      HapticFeedback.vibrate();
      final isAr = Localizations.localeOf(context).languageCode == 'ar';
      VSPFeedback.showError(
        context,
        isAr
            ? 'حسابك مقيد من الحجز النقدي لعدم الحضور السابق. يرجى الدفع أونلاين 100٪.'
            : 'Cash bookings restricted due to missed attendance. Please pay 100% online.',
      );
      nav.push(MaterialPageRoute(
        builder: (_) => PaymentGatewayScreen(bookingDraft: draft, forceFullPayment: true),
      ));
      return;
    }

    if (!context.mounted) return;

    // Business rule: while the player has an active unpaid cash booking,
    // any additional booking must be paid in full online. This is mirrored
    // by the database trigger as the final authority.
    final directRepo = SupabaseBookingRepository();
    final existingUserBookings = await directRepo.getUserBookingsDirectly(currentUserModel.uid);
    if (!context.mounted) return;

    final hasActiveCashBooking = existingUserBookings.any((b) =>
        b.paymentMethod.toLowerCase() == 'cash' &&
        !b.isPaid &&
        (b.status == BookingStatus.pending || b.status == BookingStatus.confirmed) &&
        b.endTime.isAfter(DateTime.now()));

    if (hasActiveCashBooking) {
      HapticFeedback.lightImpact();
      VSPFeedback.showInfo(
        context,
        'عندك حجز كاش قائم، فالحجز الجديد لازم يتدفع بالكامل أونلاين.',
      );

      final forcedFullDraft = draft.copyWith(
        paymentMethod: 'paymob',
        needsDeposit: false,
        depositPaid: 0.0,
        isDepositPaid: false,
      );

      nav.push(MaterialPageRoute(
        builder: (_) => PaymentGatewayScreen(
          bookingDraft: forcedFullDraft,
          forceFullPayment: true,
        ),
      ));
      return;
    }

    showBookingPaymentMethodSheet(
      context: context,
      draft: draft,
      totalPrice: totalPrice,
      depositAmount: depositAmount,
      requiresDeposit: requiresDeposit,
      currentUserModel: currentUserModel,
      bookingProvider: bookingProvider,
      nav: nav,
    );
  }
}
