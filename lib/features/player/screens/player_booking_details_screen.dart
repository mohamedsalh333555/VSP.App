import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/chat_repository.dart';
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
      body: ListView(
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
              _row(Iconsax.wallet_1_copy, ar ? 'الإجمالي' : 'Total', booking.totalPrice.toInt().toString() + ' ' + booking.currency),
              _row(Iconsax.info_circle_copy, ar ? 'الحالة' : 'Status', booking.status.name),
            ]),
          ),
          const SizedBox(height: VSPSpacing.md),
          ElevatedButton.icon(
            onPressed: () => _openChat(context),
            icon: const Icon(Iconsax.message_copy, color: Colors.black),
            label: Text(ar ? 'المحادثة المرتبطة بالحجز' : 'Chat with the related participant'),
            style: ElevatedButton.styleFrom(backgroundColor: VSPColors.accent, foregroundColor: Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: VSPSpacing.sm),
      child: Row(children: [
        Icon(icon, size: 18, color: VSPColors.accent),
        const SizedBox(width: VSPSpacing.sm),
        Text(label + ': ', style: const TextStyle(color: VSPColors.textSecondary)),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800))),
      ]),
    );
  }
}
