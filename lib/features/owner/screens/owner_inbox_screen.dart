import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/material.dart';
import '../../../core/ui/vsp_ui.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/chat_repository.dart';
import '../../../core/repositories/user_repository.dart';
import '../../player/screens/chat_screen.dart';
import '../../../shared/widgets/vsp_empty_state.dart';
import '../../../shared/widgets/vsp_error_state.dart';
import '../../../shared/widgets/vsp_fade_in_item.dart';
import '../../../core/services/support_service.dart';
import '../widgets/inbox/owner_chat_item_card.dart';

class OwnerInboxScreen extends StatefulWidget {
 const OwnerInboxScreen({super.key});

 @override
 State<OwnerInboxScreen> createState() => _OwnerInboxScreenState();
}

class _OwnerInboxScreenState extends State<OwnerInboxScreen> {
 final ChatRepository _chatRepository = ChatRepository();

 /// N+1 FIX: Local in-memory cache of user profiles keyed by user-id.
 /// Populated via a single batch Supabase query whenever the conversation
 /// list changes, so we never fire one getUserData() call per list row.
 final Map<String, Map<String, dynamic>> _userCache = {};
 bool _isFetchingUsers = false;

 /// Batch-fetch profiles for all [userIds] that are not already cached.
 Future<void> _prefetchUsers(List<String> userIds) async {
 final missing = userIds.where((id) => id.isNotEmpty && !_userCache.containsKey(id)).toList();
 if (missing.isEmpty || _isFetchingUsers) return;
 _isFetchingUsers = true;
 try {
 final rows = await UserRepository().getUserSummariesByIds(missing);
 for (final map in rows) {
 _userCache[map['id'].toString()] = map;
 }
 if (mounted) setState(() {});
 } catch (e) {
 debugPrint(' Owner inbox prefetch users notice: $e');
 } finally {
 _isFetchingUsers = false;
 }
 }

 void _openSupportChat(BuildContext context) {
 SupportService().openSupport(context);
 }

 @override
 Widget build(BuildContext context) {
 final auth = Provider.of<AuthProvider>(context, listen: false);
 final ownerId = auth.currentUser?.id ?? '';
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';

 return VSPScaffold(
 backgroundColor: VSPColors.background,
 appBar: AppBar(
 backgroundColor: VSPColors.background,
 elevation: 0,
 automaticallyImplyLeading: false,
 centerTitle: true,
 title: Text(
 isArabic ? 'المحادثات' : 'Chats',
 style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
 ),
 actions: [
 IconButton(
 icon: const Icon(Iconsax.headphone_copy, color: VSPColors.accent),
 onPressed: () => _openSupportChat(context),
 tooltip: isArabic ? 'الاتصال بالدعم' : 'Contact Support',
 ),

 ],
 ),
 body: StreamBuilder<List<Map<String, dynamic>>>(
 stream: _chatRepository.streamUserConversations(ownerId),
 builder: (context, snapshot) {
 if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
 return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
 }

 final conversations = snapshot.data ?? [];
 
 // A failed initial read must not masquerade as a genuinely empty inbox.
 if (snapshot.hasError && !snapshot.hasData) {
   return VSPErrorState(
     customMessage: isArabic
         ? 'تعذر تحميل المحادثات. تحقق من الاتصال ثم أعد المحاولة.'
         : 'Could not load conversations. Check your connection and try again.',
     retryButtonText: isArabic ? 'إعادة المحاولة' : 'Retry',
     onRetry: () {
       if (mounted) setState(() {});
     },
   );
 }


 // N+1 FIX: Collect all other-user IDs and batch-fetch missing profiles once.
 final otherUserIds = conversations
 .map((c) {
 final participants = (c['participant_ids'] as List?)?.map((e) => e.toString()).toList() ?? [];
 return participants.firstWhere((uid) => uid != ownerId, orElse: () => '');
 })
 .where((id) => id.isNotEmpty)
 .toList();
 _prefetchUsers(otherUserIds);

 if (conversations.isEmpty) {
 return VSPEmptyState(
 icon: Iconsax.messages_3_copy,
 title: isArabic ? 'لا توجد محادثات نشطة' : 'No active chats',
 subtitle: isArabic 
 ? 'ستظهر هنا المحادثات مع اللاعبين والدعم الفني.' 
 : 'Chats with players and support will appear here.',
 buttonText: isArabic ? 'تواصل مع الدعم الفني' : 'Contact Support',
 onButtonPressed: () => _openSupportChat(context),
 );
 }

 return ListView.builder(
 padding: VSPScrollPadding.forList(context, hasFloatingNavBar: true),
 itemCount: conversations.length + (snapshot.hasError ? 1 : 0),
 itemBuilder: (context, index) {
 if (snapshot.hasError && index == 0) {
   return Padding(
     padding: const EdgeInsets.only(bottom: VSPSpacing.md),
     child: Container(
       padding: const EdgeInsets.all(VSPSpacing.md),
       decoration: BoxDecoration(
         color: VSPColors.warning.withValues(alpha: 0.10),
         borderRadius: BorderRadius.circular(VSPRadius.md),
         border: Border.all(color: VSPColors.warning.withValues(alpha: 0.35)),
       ),
       child: Row(
         children: [
           const Icon(Iconsax.warning_2_copy, color: VSPColors.warning, size: 18),
           const SizedBox(width: VSPSpacing.sm),
           Expanded(
             child: Text(
               isArabic
                   ? 'تعذر تحديث المحادثات. المعروض هو آخر بيانات تم تحميلها.'
                   : 'Conversations could not be refreshed. Showing the last loaded data.',
               style: const TextStyle(color: VSPColors.textSecondary),
             ),
           ),
           TextButton(
             onPressed: () {
               if (mounted) setState(() {});
             },
             child: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
           ),
         ],
       ),
     ),
   );
 }
 final conversationIndex = index - (snapshot.hasError ? 1 : 0);
 final conv = conversations[conversationIndex];
 final convId = conv['id'].toString();
 final type = conv['type']?.toString() ?? 'direct';
 final participants = (conv['participant_ids'] as List?)?.map((e) => e.toString()).toList() ?? [];
 final otherUserId = participants.firstWhere((uid) => uid != ownerId, orElse: () => '');
 final unreadMap = conv['unread_counts'] as Map<String, dynamic>? ?? {};
 final unreadCount = unreadMap[ownerId] as int? ?? 0;
 final latestTime = DateTime.parse(conv['last_message_time'] ?? conv['created_at']);



 // N+1 FIX: Read from cache — no FutureBuilder, no per-row network call.
 final cachedUser = _userCache[otherUserId];
 final name = cachedUser?['name'] ?? (isArabic ? 'لاعب VSP' : 'VSP Player');
 final avatarUrl = cachedUser?['profile_image_url'] ?? '';

 return VSPFadeInItem(
 index: index,
 child: _buildChatRow(
 context: context,
 conversationId: convId,
 otherUserId: otherUserId,
 type: type,
 ownerId: ownerId,
 title: name,
 subtitle: conv['last_message'] ?? (isArabic ? 'محادثة مباشرة' : 'Direct message'),
 timeStr: _formatTime(latestTime),
 avatar: avatarUrl.isNotEmpty ? avatarUrl : null,
 latestTime: latestTime,
 hasUnread: unreadCount > 0,
 unreadCount: unreadCount,
 reportContextType: conv['context_type']?.toString(),
 reportContextId: conv['context_id']?.toString(),
 reportBookingId: conv['booking_id']?.toString(),
 ),
 );
 },
 );
 },
 ),
 );
 }

  Widget _buildChatRow({
    required BuildContext context,
    required String conversationId,
    required String otherUserId,
    required String type,
    required String ownerId,
    required String title,
    required String subtitle,
    required String timeStr,
    required String? avatar,
    required DateTime latestTime,
    required bool hasUnread,
    required int unreadCount,
    String? reportContextType,
    String? reportContextId,
    String? reportBookingId,
  }) {
    return OwnerChatItemCard(
      title: title,
      subtitle: subtitle,
      timeStr: timeStr,
      avatar: avatar,
      hasUnread: hasUnread,
      unreadCount: unreadCount,
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen.conversation(
              conversationId: conversationId,
              title: title,
              otherUserId: otherUserId.isNotEmpty ? otherUserId : null,
              reportContextType: reportContextType,
              reportContextId: reportContextId,
              reportBookingId: reportBookingId,
            ),
          ),
        );
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  String _formatTime(DateTime date) {
    return DateFormat('hh:mm a').format(date);
  }
}
