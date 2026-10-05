import 'package:flutter/material.dart';
import '../../features/player/screens/support_tickets_screen.dart';
import '../../data/models.dart';

class SupportService {
  static final SupportService _instance = SupportService._internal();
  factory SupportService() => _instance;
  SupportService._internal();

  Future<void> openSupport(
    BuildContext context, {
    String? category,
    Booking? booking,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupportTicketsScreen(
          initialCategory: category == null ? null : _normalizeCategory(category),
          contextBooking: booking,
        ),
      ),
    );
  }

  String _normalizeCategory(String value) {
    final v = value.toLowerCase();
    if (v.contains('refund') || v.contains('استرد')) return 'refund';
    if (v.contains('payment') || v.contains('دفع') || v.contains('تحصيل')) return 'payment';
    if (v.contains('booking') || v.contains('حجز')) return 'booking';
    if (v.contains('tournament') || v.contains('بطول')) return 'tournament';
    if (v.contains('report') || v.contains('بلاغ')) return 'report';
    if (v.contains('account') || v.contains('حساب')) return 'account';
    return 'general';
  }
}
