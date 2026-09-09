import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/booking_provider.dart';
import '../../../../core/repositories/owner_repository.dart';
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
          uid = authProvider.currentUser?.uid ?? authProvider.firebaseUser?.uid ?? booking.ownerId;
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

      if (context.mounted) {
        VSPFeedback.showSuccess(
          context,
          isArabic ? 'تم تأكيد استلام المبلغ بالملعب واكتمال الحجز بنجاح.' : 'Cash payment confirmed at pitch successfully.',
        );
      }
      if (parentContext.mounted) {
        try {
          final auth = Provider.of<AuthProvider>(parentContext, listen: false);
          final currentUid = currentUserId ?? auth.currentUser?.uid ?? auth.firebaseUser?.uid;
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
    final newEndTime = booking.endTime.add(const Duration(minutes: 30));

    setLoading(true);
    try {
      final repo = ownerRepository ?? OwnerRepository();
      await repo.extendBookingEndTime(
        bookingId: booking.id,
        newEndTime: newEndTime,
      );

      if (context.mounted) {
        VSPFeedback.showSuccess(
          context,
          isArabic ? 'تم تمديد المباراة 30 دقيقة إضافية بنجاح.' : 'Match extended by 30 mins successfully.',
        );
      }
      if (parentContext.mounted) {
        try {
          final auth = Provider.of<AuthProvider>(parentContext, listen: false);
          final currentUid = auth.currentUser?.uid ?? auth.firebaseUser?.uid;
          if (currentUid != null) {
            await Provider.of<BookingProvider>(parentContext, listen: false).loadOwnerBookings(currentUid, forceRefresh: true);
          }
        } catch (_) {}
      }
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) {
        setLoading(false);
        VSPFeedback.showError(context, '${isArabic ? "تعذر تمديد المباراة:" : "Failed to extend match:"} $e');
      }
    }
  }

  /// Cancels booking after user confirmation.
  static Future<void> cancelBooking({
    required BuildContext context,
    required BuildContext parentContext,
    required Booking booking,
    required AppLocalizations l10n,
    required bool isArabic,
    required ValueSetter<bool> setDeleting,
  }) async {
    final nav = Navigator.of(context);
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
        if (!parentContext.mounted) return;
        final uid = Provider.of<AuthProvider>(parentContext, listen: false).currentUser?.uid;
        if (uid != null) {
          await Provider.of<BookingProvider>(parentContext, listen: false).loadOwnerBookings(uid, forceRefresh: true);
        }
      } catch (_) {}
      if (context.mounted) nav.pop();
    }
  }
}
