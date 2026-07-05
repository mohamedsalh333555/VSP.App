import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/ui/components/vsp_card.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../data/models.dart';
import '../../player/screens/chat_screen.dart';
import '../../../shared/widgets/vsp_empty_state.dart';
import '../../../shared/widgets/vsp_fade_in_item.dart';

class OwnerInboxScreen extends StatelessWidget {
  const OwnerInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final ownerId = auth.currentUser?.id ?? '';
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text(
          isArabic ? 'المحادثات' : 'Chats',
          style: Theme.of(context).textTheme.displayLarge,
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Supabase.instance.client
            .from('bookings')
            .stream(primaryKey: ['id'])
            .eq('owner_id', ownerId)
            .order('last_message_time', ascending: false)
            .map((list) => list),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
          }

          final rawBookings = snapshot.data ?? [];
          final now = DateTime.now();

          final bookings = rawBookings.map((data) {
            return {
              'booking': Booking.fromFirestore(data, data['id'].toString()),
              'unread_counts': data['unread_counts'] as Map<String, dynamic>? ?? {},
            };
          }).where((item) {
            final b = item['booking'] as Booking;
            final unreadMap = item['unread_counts'] as Map<String, dynamic>;
            final unreadCount = unreadMap[ownerId] as int? ?? 0;
            final isRecent = b.endTime.add(const Duration(hours: 24)).isAfter(now);
            return b.notes != null && (isRecent || unreadCount > 0);
          }).toList();

          if (bookings.isEmpty) {
            return VSPEmptyState(
              icon: LucideIcons.messageSquare,
              title: isArabic ? 'لا توجد محادثات نشطة' : 'No active chats',
              subtitle: isArabic 
                  ? 'ستظهر هنا المحادثات الواردة من اللاعبين بخصوص الحجوزات.' 
                  : 'Chats from players regarding bookings will appear here.',
            );
          }

          return ListView.builder(
            padding: EdgeInsets.fromLTRB(
              VSPSpacing.md, 
              VSPSpacing.md, 
              VSPSpacing.md, 
              MediaQuery.of(context).padding.bottom + 110
            ),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final bookingMap = bookings[index];
              final booking = bookingMap['booking'] as Booking;
              final unreadMap = bookingMap['unread_counts'] as Map<String, dynamic>;
              final unreadCount = unreadMap[ownerId] as int? ?? 0;
              final hasUnread = unreadCount > 0;

              return VSPFadeInItem(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: VSPSpacing.sm),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ChatScreen(booking: booking)),
                      );
                    },
                    borderRadius: BorderRadius.circular(VSPRadius.lg),
                    child: VSPCard(
                      padding: const EdgeInsets.all(16),
                      border: hasUnread ? Border.all(color: VSPColors.accent, width: 1.5) : null,
                      color: hasUnread ? VSPColors.accent.withOpacity(0.05) : VSPColors.surface,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: VSPColors.surfaceAlt,
                            backgroundImage: (booking.hostAvatarUrl != null && booking.hostAvatarUrl!.isNotEmpty)
                                ? NetworkImage(booking.hostAvatarUrl!)
                                : null,
                            child: (booking.hostAvatarUrl == null || booking.hostAvatarUrl!.isEmpty)
                                ? Icon(LucideIcons.user, color: VSPColors.accent)
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      booking.hostName ?? (isArabic ? 'لاعب' : 'Player'),
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                    Text(
                                      _formatTime(booking.startTime),
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: VSPColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  booking.stadiumName,
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: VSPColors.accent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (hasUnread) ...[
                            const SizedBox(width: 12),
                            CircleAvatar(
                              radius: 10,
                              backgroundColor: VSPColors.accent,
                              child: Text(
                                '',
                                style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTime(DateTime date) {
    return DateFormat('hh:mm a').format(date);
  }
}
