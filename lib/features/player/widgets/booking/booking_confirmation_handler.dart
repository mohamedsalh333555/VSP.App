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
import 'package:uuid/uuid.dart';
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
    String? verifiedChallengeCode,
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
    if (selectedTimeSlots.isEmpty ||
        selectedTimeSlots.any((slot) => slot.trim().isEmpty)) {
      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
      VSPFeedback.showError(
        context,
        isArabic
            ? 'اختار موعد الحجز الأول قبل التأكيد.'
            : 'Select at least one booking time slot before confirming.',
      );
      onLoadingChanged(false);
      return;
    }

    // A deep link or stale booking screen must not bypass venue blocking.
    if (stadium.isBlocked) {
      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
      VSPFeedback.showError(
        context,
        isArabic
            ? 'الملعب غير متاح للحجز حاليًا.'
            : 'This venue is currently unavailable for booking.',
      );
      onSlotsCleared();
      onLoadingChanged(false);
      return;
    }

    onLoadingChanged(true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.id;
    final currentUserModel = authProvider.userModel;
    if (currentUserModel == null || userId == null || currentUserModel.uid != userId) {
      onLoadingChanged(false);
      return;
    }
    bool isSameUser() =>
        Provider.of<AuthProvider>(context, listen: false).currentUser?.id == userId;

    final nav = Navigator.of(context);
    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);

    // Smart location check: determines whether cash booking is eligible
    // or if the player must confirm via online payment/deposit (to protect venues against no-shows).
    bool isCrossGovernorate = false;
    String? crossGovMessage;

    try {
      final (position, resolvedGovernorate) =
          await LocationService().getThrottledLocation(force: true);
      if (!context.mounted) return;
      if (!isSameUser()) {
        onLoadingChanged(false);
        return;
      }

      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
      if (resolvedGovernorate == 'mock_location_detected') {
        isCrossGovernorate = true;
        crossGovMessage = isArabic
            ? 'تم رصد موقع غير دقيق. لتأكيد الحجز بأمان يا كابتن، يرجى السداد الإلكتروني أو العربون.'
            : 'Inaccurate location detected. Please confirm via electronic payment or deposit.';
      } else if (position == null || resolvedGovernorate == null || resolvedGovernorate.trim().isEmpty) {
        isCrossGovernorate = true;
        crossGovMessage = isArabic
            ? 'تعذر التحقق من موقعك بدقة. يمكنك تأكيد حجزك فوراً بالسداد الإلكتروني أو دفع العربون يا كابتن.'
            : 'Could not verify exact location. You can confirm via electronic payment or deposit.';
      } else {
        final stadiumGovRaw = stadium.governorate?.trim() ?? '';
        final playerGovernorate =
            EgyptGovernorates.resolveGoogleName(resolvedGovernorate) ??
                resolvedGovernorate.trim().toLowerCase();
        final stadiumGovernorate =
            EgyptGovernorates.resolveGoogleName(stadiumGovRaw) ??
                stadiumGovRaw.toLowerCase();

        final pGov = playerGovernorate.toLowerCase();
        final sGov = stadiumGovernorate.toLowerCase();
        // Allow cross-booking within Greater Cairo metropolitan area (Cairo, Giza, Qalyubia)
        final isGreaterCairo = (pGov == 'cairo' || pGov == 'giza' || pGov == 'qalyubia') &&
                               (sGov == 'cairo' || sGov == 'giza' || sGov == 'qalyubia');

        if (stadiumGovRaw.isNotEmpty && pGov != sGov && !isGreaterCairo) {
          isCrossGovernorate = true;
          final stadiumName = EgyptGovernorates.getLocalizedName(
            EgyptGovernorates.resolveGoogleName(stadiumGovRaw) ?? stadiumGovRaw,
            isArabic,
          );
          final playerName = EgyptGovernorates.getLocalizedName(
            EgyptGovernorates.resolveGoogleName(resolvedGovernorate) ?? resolvedGovernorate,
            isArabic,
          );
          crossGovMessage = isArabic
              ? 'أهلاً بك يا كابتن! نظراً لوجودك في محافظة $playerName والملعب في $stadiumName، الحجز النقدي متاح فقط للمتواجدين داخل المحافظة لحماية مواعيد الملعب. تقدر تأكد حجزك دلوقتي فوراً بالدفع الإلكتروني أو العربون.'
              : 'Notice: Cash booking is reserved for in-governorate players ($playerName vs $stadiumName). You can confirm instantly via online payment or deposit.';
        }
      }
    } catch (_) {
      VSPLogger.w('Location verification fallback to online-preferred (details redacted)');
      isCrossGovernorate = true;
      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
      crossGovMessage = isArabic
          ? 'تعذر التحقق من موقعك حالياً. لتأكيد الحجز، يرجى اختيار الدفع الإلكتروني أو دفع العربون.'
          : 'We could not verify your location right now. Please use online payment or pay the deposit to confirm your booking.';
    }

    if (!context.mounted) return;
    if (!isSameUser()) {
      onLoadingChanged(false);
      return;
    }

    // ── Pre-confirmation double-check ────────────────────────────────────────
    try {
      // Always query the authoritative booking-slot RPC at confirmation time.
      // The polling stream can retain a previously verified snapshot after a
      // refresh error, so its first event is not suitable for final validation.
      final currentBookings = await SupabaseBookingRepository()
          .fetchStadiumBookingsDirectly(stadium.id, selectedDate)
          .timeout(const Duration(seconds: 10));

      if (!context.mounted) return;
      if (!isSameUser()) {
        onLoadingChanged(false);
        return;
      }

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

      final selectedStarts = sortedCheck.map(
        (slot) => BookingSlotCalculator.getSlotDateTime(
          slotKey: slot,
          stadium: stadium,
          selectedDate: selectedDate,
        ),
      ).toList();
      // Do not pass a temporarily closed slot into any payment path, even if
      // it came from a stale deep link. The server validates again on write.
      if (selectedStarts.any((start) =>
          BookingSlotCalculator.isVenueSlotClosed(
            stadium: stadium, slotStart: start))) {
        onSlotsCleared();
        onLoadingChanged(false);
        if (context.mounted) {
          final isArabic = Localizations.localeOf(context).languageCode == 'ar';
          VSPFeedback.showError(
            context,
            isArabic
                ? 'الموعد داخل فترة إغلاق الملعب. اختر موعدًا آخر.'
                : 'Selected slot is within a venue closure. Choose another time.',
          );
        }
        return;
      }

      // Initial route selections and stale selections may bypass the UI
      // range picker. Never turn non-adjacent keys into a longer interval
      // that silently reserves unselected times.
      if (!BookingSlotCalculator.areContiguousHalfHourStarts(selectedStarts) ||
          selectedStarts.any((start) => !start.isAfter(DateTime.now()))) {
        onSlotsCleared();
        onLoadingChanged(false);
        if (context.mounted) {
          final isAr = Localizations.localeOf(context).languageCode == 'ar';
          VSPFeedback.showError(
            context,
            isAr
                ? 'المواعيد المحددة غير متصلة أو انتهت. اختر مواعيد متتالية متاحة.'
                : 'Selected times are expired or not consecutive. Choose available consecutive slots.',
          );
        }
        return;
      }

      // Every selected half-hour must still be free at confirmation time.
      // Checking only the first slot allowed a later slot in a multi-slot
      // booking to be taken between selection and submission.
      final isConflict = sortedCheck.any(
        (slotKey) => BookingSlotCalculator.isSlotBooked(
          slotKey: slotKey,
          stadium: stadium,
          selectedDate: selectedDate,
          existingBookings: currentBookings,
        ),
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
    } catch (_) {
      VSPLogger.e('Slot availability validation failed (details redacted)');
      if (!context.mounted) return;
      if (!isSameUser()) {
        onLoadingChanged(false);
        return;
      }
      onLoadingChanged(false);
      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
      VSPFeedback.showError(
        context,
        isArabic
            ? 'تعذر التحقق من إتاحة الموعد حالياً. لم يتم إرسال الحجز؛ حاول مرة أخرى.'
            : 'Could not verify this time slot right now. No booking was submitted; please try again.',
      );
      return;
    }

    if (!context.mounted) return;
    if (!isSameUser()) {
      onLoadingChanged(false);
      return;
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

    // This challenge must carry the exact verified opponent code. Never
    // borrow a stale code from another draft, captain, or logged-in account.
    if (bType == BookingType.challenge &&
        (verifiedChallengeCode == null ||
            verifiedChallengeCode.trim().isEmpty)) {
      onLoadingChanged(false);
      if (context.mounted) {
        final isArabic = Localizations.localeOf(context).languageCode == 'ar';
        VSPFeedback.showError(
          context,
          isArabic
              ? 'لا يوجد كود تحدي مُتحقق منه. ارجع وتحقق من كود الفريق المنافس.'
              : 'No verified challenge code. Return and verify the opposing team code.',
        );
      }
      return;
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
      isPrivate: isOpenJoin(bookingType) ? true : isPrivate,
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
      challengeCode: bType == BookingType.challenge
          ? verifiedChallengeCode
          : null,
      idempotencyKey: const Uuid().v4(),
    );

    onLoadingChanged(false);

    // Collective bookings are host-paid and must be fully paid online.
    // They never enter the payment-choice sheet.
    if (isOpenJoin(bookingType)) {
      if (!context.mounted) return;
      final collectiveDraft = draft.copyWith(
        paymentMethod: 'paymob',
        paymentStatus: 'pending',
        needsDeposit: false,
        depositPaid: 0.0,
        isDepositPaid: false,
        isPaid: false,
        isPrivate: true,
      );
      nav.push(
        MaterialPageRoute(
          builder: (_) => PaymentGatewayScreen(
            bookingDraft: collectiveDraft,
            forceFullPayment: true,
          ),
        ),
      );
      return;
    }

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
    List<Booking> existingUserBookings;
    try {
      // This read gates a payment policy. Never interpret a query failure as
      // an empty booking history, or an active cash booking could be bypassed.
      existingUserBookings =
          await directRepo.getUserBookingsDirectlyStrict(userId);
    } catch (_) {
      VSPLogger.e('Cash booking payment-policy verification failed (details redacted)');
      if (!context.mounted) return;
      if (!isSameUser()) {
        onLoadingChanged(false);
        return;
      }
      onLoadingChanged(false);
      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
      VSPFeedback.showError(
        context,
        isArabic
            ? 'تعذر التحقق من حجوزاتك الحالية. لم يتم إرسال الحجز؛ حاول مرة أخرى.'
            : 'Could not verify your current bookings. No booking was submitted; please try again.',
      );
      return;
    }
    if (!context.mounted) return;
    if (!isSameUser()) {
      onLoadingChanged(false);
      return;
    }

    final hasActiveCashBooking = existingUserBookings.any((b) =>
        b.paymentMethod.toLowerCase() == 'cash' &&
        !b.isPaid &&
        (b.status == BookingStatus.pending || b.status == BookingStatus.confirmed) &&
        b.endTime.isAfter(DateTime.now()));

    if (hasActiveCashBooking) {
      HapticFeedback.lightImpact();
      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
      VSPFeedback.showInfo(
        context,
        isArabic
            ? 'عندك حجز كاش قائم، فالحجز الجديد لازم يتدفع بالكامل أونلاين.'
            : 'You have an active cash booking, so this booking must be paid in full online.',
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
      isCrossGovernorate: isCrossGovernorate,
      crossGovMessage: crossGovMessage,
    );
  }
}
