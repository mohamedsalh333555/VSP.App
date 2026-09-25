import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/booking_provider.dart';
import '../../../../core/repositories/owner_repository.dart';
import '../../../../core/services/notification_handler.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../data/models.dart';
import '../../../../l10n/app_localizations.dart';
import 'booking_sheet_cancel_dialog.dart';

/// Coordinator executing transactional booking actions (cash confirmation, extension, and cancellation) for the owner booking sheet.
class OwnerBookingSheetCoordinator {
  const OwnerBookingSheetCoordinator._();

  /// Confirms cash payment at pitch atomically.
  static Future<void> confirmCashPayment({
    required BuildContext context,
    required BuildContext parentContext,
    required Booking booking,
    required Stadium selectedStadium,
    required bool isArabic,
    required ValueSetter<bool> setLoading,
    OwnerRepository? ownerRepository,
    String? currentUserId,
  }) async {
    setLoading(true);
    try {
      final repo = ownerRepository ?? OwnerRepository();
      final totalPrice = booking.totalPrice > 0 ? booking.totalPrice : selectedStadium.basePrice;
      
      String? uid = currentUserId;
      if (uid == null) {
        try {
          final authProvider = Provider.of<AuthProvider>(parentContext, listen: false);
          uid = authProvider.currentUser?.id ?? booking.ownerId;
        } catch (_) {
          uid = booking.ownerId;
        }
      }

      final rpcRes = await repo.confirmCashBookingAtomic(
        bookingId: booking.id,
        ownerId: uid,
        totalPrice: totalPrice,
      );

      if (rpcRes is Map && rpcRes['success'] == false) {
        throw Exception(rpcRes['message']?.toString() ?? 'Failed to confirm cash payment');
      }

      final isAlreadyConfirmed = rpcRes is Map && rpcRes['already_confirmed'] == true;

      if (!isAlreadyConfirmed) {
        final double remainingCash = (booking.totalPrice - booking.depositPaid).clamp(0.0, 999999.0);
        final double actualCashPaid = (remainingCash > 0 && booking.depositPaid > 0) ? remainingCash : totalPrice;
        final String playerUserId = booking.userId;
        if (playerUserId.isNotEmpty && playerUserId != uid) {
          try {
            await NotificationHandler.notifyPaymentReceived(
              recipientId: playerUserId,
              userName: selectedStadium.name,
              amount: actualCashPaid,
              bookingId: booking.id,
            );
          } catch (_) {}
        }
      }

      if (context.mounted) {
        VSPFeedback.showSuccess(
          context,
          isAlreadyConfirmed
              ? (isArabic ? 'الحجز مؤكد ومسدد بالفعل مسبقاً.' : 'Booking is already confirmed and paid.')
              : (isArabic ? 'تم تأكيد استلام المبلغ بالملعب واكتمال الحجز بنجاح.' : 'Cash payment confirmed at pitch successfully.'),
        );
      }
      if (parentContext.mounted) {
        try {
          final auth = Provider.of<AuthProvider>(parentContext, listen: false);
          final currentUid = currentUserId ?? auth.currentUser?.id;
          if (currentUid != null) {
            await Provider.of<BookingProvider>(parentContext, listen: false).loadOwnerBookings(currentUid, forceRefresh: true);
          }
        } catch (_) {}
      }
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) {
        setLoading(false);
        VSPFeedback.showError(context, '${isArabic ? "تعذر تأكيد الدفع:" : "Failed to confirm cash:"} $e');
      }
    }
  }

  /// Extends ongoing match end time by 30 minutes.
  static Future<void> extendOngoingMatch({
    required BuildContext context,
    required BuildContext parentContext,
    required Booking booking,
    required bool isArabic,
    required ValueSetter<bool> setLoading,
    OwnerRepository? ownerRepository,
  }) async {
    setLoading(true);
    try {
      final repo = ownerRepository ?? OwnerRepository();
      final res = await repo.extendOngoingMatchAtomic(
        bookingId: booking.id,
        addedMinutes: 30,
      );

      if (res is Map && res['success'] == false) {
        if (context.mounted) {
          setLoading(false);
          final msg = res['message']?.toString() ??
              (isArabic
                  ? 'لا يمكن تمديد المباراة، يوجد حجز آخر يبدأ في هذا الوقت.'
                  : 'Cannot extend match, another booking starts soon.');
          VSPFeedback.showWarning(context, msg);
        }
        return;
      }

      if (context.mounted) {
        VSPFeedback.showSuccess(
          context,
          isArabic ? 'تم تمديد المباراة 30 دقيقة إضافية بنجاح.' : 'Match extended by 30 mins successfully.',
        );
      }
      if (parentContext.mounted) {
        try {
          final auth = Provider.of<AuthProvider>(parentContext, listen: false);
          final currentUid = auth.currentUser?.id;
          if (currentUid != null) {
            await Provider.of<BookingProvider>(parentContext, listen: false).loadOwnerBookings(currentUid, forceRefresh: true);
          }
        } catch (_) {}
      }
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) {
        setLoading(false);
        final cleanMsg = e.toString().replaceAll('Exception:', '').trim();
        VSPFeedback.showError(context, '${isArabic ? "تعذر تمديد المباراة:" : "Failed to extend match:"} $cleanMsg');
      }
    }
  }

  /// Cancels booking after user confirmation, with deposit reconciliation for manual bookings.
  static Future<void> cancelBooking({
    required BuildContext context,
    required BuildContext parentContext,
    required Booking booking,
    required AppLocalizations l10n,
    required bool isArabic,
    required ValueSetter<bool> setDeleting,
  }) async {
    final nav = Navigator.of(context);
    final isManual = (booking.paymentTransactionId?.contains('MANUAL') ?? false) ||
        booking.bookingType == BookingType.personal;

    // If manual booking with a deposit, prompt the owner for deposit reconciliation:
    if (isManual && booking.depositPaid > 0) {
      final decision = await BookingSheetCancelDialog.showManualDepositOptions(
        context: context,
        depositAmount: booking.depositPaid,
        isArabic: isArabic,
      );

      if (decision == ManualBookingCancelDecision.abort) {
        return;
      }

      if (!context.mounted || !parentContext.mounted) return;
      setDeleting(true);
      try {
        final auth = Provider.of<AuthProvider>(parentContext, listen: false);
        final uid = auth.currentUser?.id ?? booking.ownerId;
        final bool refund = decision == ManualBookingCancelDecision.refund;

        final res = await OwnerRepository().cancelManualBookingAtomic(
          bookingId: booking.id,
          ownerId: uid,
          refundDeposit: refund,
        );

        if (res is Map && res['success'] == false) {
          throw Exception(res['message']?.toString() ?? 'Failed to cancel manual booking');
        }

        if (context.mounted) {
          VSPFeedback.showSuccess(
            context,
            refund
                ? (isArabic
                    ? 'تم إلغاء الحجز ورد العربون (${booking.depositPaid.toInt()} ج.م) وتسجيل الاسترداد في الدفتر.'
                    : 'Booking cancelled & deposit refund recorded.')
                : (isArabic
                    ? 'تم إلغاء الحجز وتثبيت العربون كشرط جزائي لصالحك.'
                    : 'Booking cancelled & deposit retained as penalty.'),
          );
        }

        if (parentContext.mounted) {
          await Provider.of<BookingProvider>(parentContext, listen: false).loadOwnerBookings(uid, forceRefresh: true);
        }
      } catch (e) {
        if (context.mounted) {
          VSPFeedback.showError(context, e.toString().replaceAll('Exception:', '').trim());
        }
      } finally {
        setDeleting(false);
      }
      if (context.mounted) nav.pop();
      return;
    }

    // Default cancellation flow (for online bookings or manual with 0 deposit):
    final confirm = await BookingSheetCancelDialog.show(
      context: context,
      title: l10n.cancelBooking,
      content: l10n.cancelBookingConfirm,
      cancelBtn: l10n.cancelBtn,
      confirmBtn: l10n.confirmBtn,
    );

    if (confirm == true && context.mounted) {
      setDeleting(true);
      if (!parentContext.mounted) return;
      try {
        final auth = Provider.of<AuthProvider>(parentContext, listen: false);
        final uid = auth.currentUser?.id ?? booking.ownerId;

        if (isManual) {
          final res = await OwnerRepository().cancelManualBookingAtomic(
            bookingId: booking.id,
            ownerId: uid,
            refundDeposit: false,
          );
          if (res is Map && res['success'] == false) {
            throw Exception(res['message']?.toString() ?? 'Failed to cancel manual booking');
          }
        } else {
          final success = await Provider.of<BookingProvider>(parentContext, listen: false).cancelBooking(booking.id);
          if (!context.mounted) return;
          if (!success) {
            final err = Provider.of<BookingProvider>(context, listen: false).errorMessage;
            VSPFeedback.showError(
              context,
              err ?? (isArabic ? 'عذراً، تعذر إلغاء الحجز ' : 'Failed to cancel booking '),
            );
            return;
          }
        }

        if (parentContext.mounted) {
          await Provider.of<BookingProvider>(parentContext, listen: false).loadOwnerBookings(uid, forceRefresh: true);
        }
      } catch (e) {
        if (context.mounted) {
          VSPFeedback.showError(context, e.toString().replaceAll('Exception:', '').trim());
        }
      } finally {
        setDeleting(false);
      }
      if (context.mounted) nav.pop();
    }
  }
}
