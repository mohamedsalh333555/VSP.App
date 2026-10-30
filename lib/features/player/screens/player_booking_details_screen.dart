import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/chat_repository.dart';
import '../../../core/repositories/report_repository.dart';
import '../../../core/ui/vsp_ui.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../data/models.dart';
import '../../../shared/widgets/vsp_back_button.dart';
import '../../../core/utils/vsp_feedback.dart';
import 'chat_screen.dart';

class PlayerBookingDetailsScreen extends StatelessWidget {
  final Booking booking;
  const PlayerBookingDetailsScreen({super.key, required this.booking});

  String _type(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    switch (booking.bookingType) {
      case BookingType.personal: return ar ? 'حجز عادي' : 'Solo Booking';
      case BookingType.team: return ar ? 'حجز فريق' : 'Team Booking';
      case BookingType.challenge: return ar ? 'تحدي' : 'Challenge';
      case BookingType.matchup: return ar ? 'مواجهة' : 'Matchup';
      case BookingType.openJoin: return ar ? 'مباراة تجميعية' : 'Open Join';
      case BookingType.maintenance: return ar ? 'صيانة' : 'Maintenance';
    }
  }

  String _statusLabel(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    switch (booking.status) {
      case BookingStatus.pending:
        return ar ? 'قيد الانتظار' : 'Pending';
      case BookingStatus.confirmed:
      case BookingStatus.upcoming:
        return ar ? 'مؤكد' : 'Confirmed';
      case BookingStatus.completed:
        return ar ? 'مكتمل' : 'Completed';
      case BookingStatus.noShow:
        return ar ? 'عدم حضور' : 'No-show';
      case BookingStatus.cancelled:
        return ar ? 'ملغي' : 'Cancelled';
      case BookingStatus.expired:
        return ar ? 'انتهت مهلة الدفع' : 'Payment expired';
    }
  }

  Future<void> _reportOwnerIssue(BuildContext context) async {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final reasonController = TextEditingController();
    final detailsController = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        backgroundColor: VSPColors.surface,
        title: Text(ar ? 'إبلاغ عن مشكلة بالملعب/المالك' : 'Report Stadium/Owner Issue'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ar ? 'سيتم ربط البلاغ بهذا الحجز لإتاحة المراجعة الإدارية.' : 'The report will be linked to this booking for administrative review.',
              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: VSPSpacing.md),
            TextField(controller: reasonController, decoration: InputDecoration(hintText: ar ? 'سبب البلاغ' : 'Reason')),
            const SizedBox(height: VSPSpacing.sm),
            TextField(controller: detailsController, maxLines: 3, decoration: InputDecoration(hintText: ar ? 'تفاصيل إضافية (اختياري)' : 'Additional details (optional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ar ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, reasonController.text.trim().isNotEmpty),
            style: ElevatedButton.styleFrom(backgroundColor: VSPColors.error, foregroundColor: Colors.white),
            child: Text(ar ? 'إرسال البلاغ' : 'Submit Report'),
          ),
        ],
      ),
    );
    final reason = reasonController.text.trim();
    final details = detailsController.text.trim();
    reasonController.dispose();
    detailsController.dispose();
    if (submitted != true || reason.isEmpty || !context.mounted) return;

    final uid = context.read<AuthProvider>().currentUser?.id;
    if (uid == null || booking.ownerId.isEmpty) return;
    final ok = await ReportRepository().reportEntity(
      reporterId: uid,
      targetId: booking.ownerId,
      targetType: 'user',
      reason: reason,
      details: details.isEmpty ? null : details,
      contextType: 'booking',
      contextId: booking.id,
      bookingId: booking.id,
    );
    if (context.mounted) {
      if (ok) {
        VSPFeedback.showSuccess(
          context,
          ar ? 'تم إرسال البلاغ للمراجعة الإدارية.' : 'Report submitted for administrative review.',
        );
      } else {
        VSPFeedback.showError(
          context,
          ar ? 'تعذر إرسال البلاغ. حاول مرة أخرى.' : 'Could not submit the report. Please try again.',
        );
      }
    }
  }

  Future<void> _openChat(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final me = auth.currentUser?.id;
    if (me == null) return;
    final candidates = <String>[booking.ownerId, booking.createdByUserId, ...booking.joinedUserIds];
    final other = candidates.firstWhere((id) => id.isNotEmpty && id != me, orElse: () => '');
    if (other.isEmpty) {
      VSPFeedback.showError(context, Localizations.localeOf(context).languageCode == 'ar'
          ? 'لا يوجد طرف مؤهل للمحادثة لهذا الحجز.'
          : 'No eligible chat participant exists for this booking.');
      return;
    }
    try {
      final contextType = booking.bookingType == BookingType.challenge ? 'challenge' : 'booking';
      final chat = await ChatRepository().getOrCreateDirectChat(
        otherUserId: other,
        isArabic: Localizations.localeOf(context).languageCode == 'ar',
        contextType: contextType,
        contextId: booking.id,
      );
      final chatId = chat['id']?.toString();
      if (chatId == null || !context.mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ChatScreen(booking: booking, conversationId: chatId, otherUserId: other),
      ));
    } catch (_) {
      if (context.mounted) {
        VSPFeedback.showError(context, Localizations.localeOf(context).languageCode == 'ar'
            ? 'تعذر فتح المحادثة.'
            : 'Could not open the chat.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return VSPScaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background, elevation: 0,
        leading: const VSPBackButton(),
        centerTitle: true,
        title: Text(ar ? 'تفاصيل الحجز' : 'Booking Details'),
      ),
      body: SafeArea(top: false, bottom: true, child: ListView(
        padding: const EdgeInsets.all(VSPSpacing.md),
        children: [
          Container(
            padding: const EdgeInsets.all(VSPSpacing.lg),
            decoration: BoxDecoration(
              color: VSPColors.surface,
              borderRadius: BorderRadius.circular(VSPRadius.card),
              border: Border.all(color: VSPColors.divider),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(booking.stadiumName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: VSPSpacing.xs),
              Text(_type(context), style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold)),
              const SizedBox(height: VSPSpacing.md),
              _row(Iconsax.calendar_1_copy, ar ? 'التاريخ' : 'Date', booking.formattedDate),
              _row(Iconsax.clock_copy, ar ? 'الوقت' : 'Time', booking.formattedTimeRange),
              _row(Iconsax.wallet_1_copy, ar ? 'الإجمالي' : 'Total', '${booking.totalPrice.toInt()} ${booking.currency}'),
              _row(Iconsax.info_circle_copy, ar ? 'الحالة' : 'Status', _statusLabel(context)),
            ]),
          ),
          const SizedBox(height: VSPSpacing.md),
          ElevatedButton.icon(
            onPressed: () => _openChat(context),
            icon: const Icon(Iconsax.message_copy, color: Colors.black),
            label: Text(ar ? 'المحادثة المرتبطة بالحجز' : 'Chat with the related participant'),
            style: ElevatedButton.styleFrom(backgroundColor: VSPColors.accent, foregroundColor: Colors.black),
          ),
          const SizedBox(height: VSPSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => _reportOwnerIssue(context),
            icon: const Icon(Iconsax.flag_copy, color: VSPColors.warning),
            label: Text(ar ? 'الإبلاغ عن مشكلة بالملعب/المالك' : 'Report Stadium/Owner Issue'),
            style: OutlinedButton.styleFrom(
              foregroundColor: VSPColors.warning,
              side: const BorderSide(color: VSPColors.warning),
            ),
          ),
        ],
      )),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: VSPSpacing.sm),
      child: Row(children: [
        Icon(icon, size: 18, color: VSPColors.accent),
        const SizedBox(width: VSPSpacing.sm),
        Text('$label: ', style: const TextStyle(color: VSPColors.textSecondary)),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800))),
      ]),
    );
  }
}
