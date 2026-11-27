import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models.dart';
import '../ui/tokens/vsp_design_tokens.dart';

/// Centralized financial, date/time, and status formatter for VSP.
/// Prevents raw backend enums ('confirmed'), raw currency codes ('EGP' in Arabic),
/// and mixed RTL date/time strings from appearing in UI screens.
abstract final class VSPFinancialFormatter {
  static String formatCurrency(
    double amount, {
    required bool isArabic,
    int? decimals,
  }) {
    final resolvedDecimals = decimals ?? (amount == amount.roundToDouble() ? 0 : 2);
    final numStr = amount.toStringAsFixed(resolvedDecimals);
    final unit = isArabic ? 'ج.م' : 'EGP';
    return '$numStr $unit';
  }

  static String formatDate(DateTime dt, {required bool isArabic}) {
    final local = dt.toLocal();
    final locale = isArabic ? 'ar' : 'en';
    return DateFormat('d MMMM yyyy', locale).format(local);
  }

  static String formatTimeRange(
    DateTime start,
    DateTime end, {
    required bool isArabic,
  }) {
    final locale = isArabic ? 'ar' : 'en';
    final s = DateFormat('h:mm a', locale).format(start.toLocal());
    final e = DateFormat('h:mm a', locale).format(end.toLocal());
    return '$s - $e';
  }

  static String localizeBookingStatus(
    BookingStatus status, {
    required bool isArabic,
  }) {
    switch (status) {
      case BookingStatus.confirmed:
        return isArabic ? 'مؤكد' : 'Confirmed';
      case BookingStatus.pending:
        return isArabic ? 'قيد الانتظار' : 'Pending';
      case BookingStatus.completed:
        return isArabic ? 'مكتمل' : 'Completed';
      case BookingStatus.cancelled:
        return isArabic ? 'ملغي' : 'Cancelled';
      case BookingStatus.expired:
        return isArabic ? 'منتهي' : 'Expired';
      case BookingStatus.noShow:
        return isArabic ? 'لم يحضر' : 'No-Show';
      case BookingStatus.upcoming:
        return isArabic ? 'قادم' : 'Upcoming';
    }
  }

  static Color statusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.confirmed:
      case BookingStatus.completed:
      case BookingStatus.upcoming:
        return VSPDSSemanticColors.success;
      case BookingStatus.pending:
        return VSPDSSemanticColors.warning;
      case BookingStatus.cancelled:
      case BookingStatus.expired:
      case BookingStatus.noShow:
        return VSPDSSemanticColors.error;
    }
  }

  static String localizePaymentStatus(
    String paymentStatus, {
    required bool isArabic,
  }) {
    switch (paymentStatus.toLowerCase().trim()) {
      case 'paid':
        return isArabic ? 'مدفوع بالكامل' : 'Paid in Full';
      case 'partially_paid':
        return isArabic ? 'مدفوع جزئياً' : 'Partially Paid';
      case 'refunded':
        return isArabic ? 'تم الاسترداد' : 'Refunded';
      case 'refund_pending':
        return isArabic ? 'جاري الاسترداد' : 'Refund Pending';
      case 'failed':
        return isArabic ? 'فشل الدفع' : 'Payment Failed';
      case 'pending':
      default:
        return isArabic ? 'بانتظار السداد' : 'Awaiting Payment';
    }
  }
}
