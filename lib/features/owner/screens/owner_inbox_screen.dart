import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/ui/components/vsp_card.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/chat_repository.dart';
import '../../../core/models/user_model.dart';
import '../../../data/models.dart';
import '../../player/screens/chat_screen.dart';
import '../../../shared/widgets/vsp_empty_state.dart';
import '../../../shared/widgets/vsp_fade_in_item.dart';
import '../../../core/services/support_service.dart';
import '../../../core/utils/vsp_feedback.dart';

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
 final rows = await Supabase.instance.client
 .from('users')
 .select('id, name, profile_image_url')
 .inFilter('id', missing);
 for (final row in (rows as List<dynamic>)) {
 final map = row as Map<String, dynamic>;
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

 Future<void> _startNewChat(BuildContext context, String currentUserId) async {
 final auth = Provider.of<AuthProvider>(context, listen: false);
 final userRole = auth.userModel?.role ?? auth.userType ?? 'owner';

 final selectedUser = await showSearch<UserModel?>(
 context: context,
 delegate: UserSearchDelegate(currentUserId: currentUserId, currentUserRole: userRole),
 );

 if (selectedUser == null || !context.mounted) return;

 showDialog(
 context: context,
 barrierDismissible: false,
 builder: (context) => const Center(child: CircularProgressIndicator(color: VSPColors.accent)),
 );

 try {
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';
 final chatData = await _chatRepository.getOrCreateDirectChat(currentUserId, selectedUser.uid, isArabic);
 final chatId = chatData['id'].toString();
 final booking = Booking.fromFirestore(chatData, chatId);

 if (context.mounted) {
 Navigator.pop(context);
 Navigator.push(
 context,
 MaterialPageRoute(builder: (_) => ChatScreen(booking: booking)),
 );
 }
 } catch (e) {
 debugPrint('Error starting direct chat: ');
 if (context.mounted) {
 Navigator.pop(context);
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';
 VSPFeedback.showError(
 context,
 isArabic 
 ? 'حدث خطأ أثناء فتح المحادثة، يرجى المحاولة لاحقاً.' 
 : 'Error opening chat, please try again later.',
 );
 }
 }
 }

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
 style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
 ),
 actions: [
 IconButton(
 icon: const Icon(Iconsax.headphone_copy, color: VSPColors.accent),
 onPressed: () => _openSupportChat(context),
 tooltip: isArabic ? 'الاتصال بالدعم' : 'Contact Support',
 ),
 IconButton(
 icon: const Icon(Iconsax.search_normal_1_copy, color: VSPColors.accent),
 onPressed: () => _startNewChat(context, ownerId),
 tooltip: isArabic ? 'بحث عن لاعبين' : 'Search Players',
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
 itemCount: conversations.length,
 itemBuilder: (context, index) {
 final conv = conversations[index];
 final convId = conv['id'].toString();
 final type = conv['type']?.toString() ?? 'direct';
 final participants = (conv['participant_ids'] as List?)?.map((e) => e.toString()).toList() ?? [];
 final otherUserId = participants.firstWhere((uid) => uid != ownerId, orElse: () => '');
 final unreadMap = conv['unread_counts'] as Map<String, dynamic>? ?? {};
 final unreadCount = unreadMap[ownerId] as int? ?? 0;
 final latestTime = DateTime.parse(conv['last_message_time'] ?? conv['created_at']);

 if (type == 'support' || otherUserId.isEmpty) {
 return VSPFadeInItem(
 index: index,
 child: _buildChatRow(
 context: context,
 conversationId: convId,
 otherUserId: '',
 type: type,
 ownerId: ownerId,
 title: isArabic ? 'الدعم الفني VSP' : 'VSP Support',
 subtitle: conv['last_message'] ?? (isArabic ? 'مرحباً بك في الدعم الفني' : 'Welcome to Support'),
 timeStr: _formatTime(latestTime),
 avatar: null,
 latestTime: latestTime,
 hasUnread: unreadCount > 0,
 unreadCount: unreadCount,
 ),
 );
 }

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
 }) {
 return Padding(
 padding: const EdgeInsets.only(bottom: VSPSpacing.sm),
 child: InkWell(
 onTap: () async {
 final isSupport = type == 'support' || otherUserId.isEmpty;
 final dummyBooking = Booking(
 id: conversationId,
 stadiumId: isSupport ? 'support_chat' : 'direct_chat',
 stadiumName: title,
 ownerId: ownerId,
 startTime: latestTime,
 endTime: latestTime.add(const Duration(hours: 1)),
 bookingType: BookingType.personal,
 isPrivate: false,
 rentBall: false,
 totalPrice: 0,
 paymentMethod: 'none',
 status: BookingStatus.confirmed,
 createdByUserId: ownerId,
 createdAt: latestTime,
 joinedUserIds: [ownerId, if (otherUserId.isNotEmpty) otherUserId],
 );
 await Navigator.push(
 context,
 MaterialPageRoute(builder: (_) => ChatScreen(booking: dummyBooking)),
 );
 if (mounted) {
 setState(() {});
 }
 },
 borderRadius: BorderRadius.circular(VSPRadius.lg),
 child: VSPCard(
 padding: const EdgeInsets.all(16),
 border: hasUnread ? Border.all(color: VSPColors.accent, width: 1.5) : null,
 color: hasUnread ? VSPColors.accent.withValues(alpha: 0.05) : VSPColors.surface,
 child: Row(
 children: [
 CircleAvatar(
 radius: 24,
 backgroundColor: VSPColors.surfaceAlt,
 backgroundImage: avatar != null ? NetworkImage(avatar) : null,
 child: avatar == null
 ? const Icon(Iconsax.user_copy, color: VSPColors.accent)
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
 Expanded(
 child: Text(
 title,
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 style: Theme.of(context).textTheme.titleSmall?.copyWith(
 fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
 ),
 ),
 ),
 const SizedBox(width: 8),
 Text(
 timeStr,
 style: Theme.of(context).textTheme.labelSmall?.copyWith(
 color: VSPColors.textSecondary,
 ),
 ),
 ],
 ),
 const SizedBox(height: 4),
 Text(
 subtitle,
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
 unreadCount > 0 ? '$unreadCount' : '',
 style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
 ),
 ),
 ],
 ],
 ),
 ),
 ),
 );
 }

 String _formatTime(DateTime date) {
 return DateFormat('hh:mm a').format(date);
 }
}

class UserSearchDelegate extends SearchDelegate<UserModel?> {
 final String currentUserId;
 final String currentUserRole;

 UserSearchDelegate({required this.currentUserId, required this.currentUserRole});

 @override
 String? get searchFieldLabel => 'بحث عن لاعبين...';

 @override
 ThemeData appBarTheme(BuildContext context) {
 return Theme.of(context).copyWith(
 appBarTheme: const AppBarTheme(
 backgroundColor: VSPColors.surface,
 iconTheme: IconThemeData(color: VSPColors.textPrimary),
 ),
 inputDecorationTheme: const InputDecorationTheme(
 hintStyle: TextStyle(color: VSPColors.textSecondary),
 focusedBorder: InputBorder.none,
 enabledBorder: InputBorder.none,
 ),
 );
 }

 @override
 List<Widget>? buildActions(BuildContext context) {
 return [
 IconButton(
 icon: const Icon(Iconsax.close_circle_copy),
 onPressed: () {
 query = '';
 },
 ),
 ];
 }

 @override
 Widget? buildLeading(BuildContext context) {
 return IconButton(
 icon: Icon(Localizations.localeOf(context).languageCode == 'ar' ? Iconsax.arrow_right_1_copy : Iconsax.arrow_left_2_copy),
 onPressed: () {
 close(context, null);
 },
 );
 }

 @override
 Widget buildResults(BuildContext context) {
 return _buildSearchResults(context);
 }

 @override
 Widget buildSuggestions(BuildContext context) {
 return _buildSearchResults(context);
 }

 Widget _buildSearchResults(BuildContext context) {
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';
 
 return FutureBuilder<List<UserModel>>(
 future: _searchUsers(query),
 builder: (context, snapshot) {
 if (snapshot.connectionState == ConnectionState.waiting) {
 return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
 }

 final users = snapshot.data ?? [];
 final filteredUsers = currentUserRole == 'owner'
 ? users.where((u) => u.role == 'player' && !u.hasStadium && u.uid != currentUserId).toList()
 : users.where((u) => u.uid != currentUserId).toList();

 if (filteredUsers.isEmpty) {
 return Center(
 child: Text(
 query.isEmpty
 ? (isArabic ? 'ابحث عن لاعبين لبدء المحادثة...' : 'Search for players to start a chat...')
 : (isArabic ? 'لم يتم العثور على لاعبين بهذا الاسم' : 'No players found'),
 style: const TextStyle(color: VSPColors.textSecondary),
 ),
 );
 }

 return ListView.builder(
 itemCount: filteredUsers.length,
 itemBuilder: (context, index) {
 final user = filteredUsers[index];
 final roleLabel = user.isOwnerRole
 ? (isArabic ? 'مالك ملعب' : 'Stadium Owner')
 : (isArabic ? 'لاعب' : 'Player');

 return ListTile(
 leading: CircleAvatar(
 backgroundColor: VSPColors.surfaceAlt,
 backgroundImage: (user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty)
 ? NetworkImage(user.profileImageUrl!)
 : null,
 child: (user.profileImageUrl == null || user.profileImageUrl!.isEmpty)
 ? const Icon(Iconsax.user_copy, color: VSPColors.accent)
 : null,
 ),
 title: Text(
 user.name ?? user.email,
 style: const TextStyle(color: VSPColors.textPrimary, fontWeight: FontWeight.bold),
 ),
 subtitle: Text(
 roleLabel,
 style: TextStyle(
 color: user.isOwnerRole ? VSPColors.accent : VSPColors.textSecondary,
 fontSize: 11,
 ),
 ),
 onTap: () {
 close(context, user);
 },
 );
 },
 );
 },
 );
 }

 Future<List<UserModel>> _searchUsers(String query) async {
 try {
 final supabase = Supabase.instance.client;
 var dbQuery = supabase.from('users').select().neq('id', currentUserId);

 if (currentUserRole == 'owner') {
 dbQuery = dbQuery.eq('role', 'player');
 }

 if (query.isNotEmpty) {
 dbQuery = dbQuery.ilike('name', '%$query%');
 }

 final response = await dbQuery.limit(50);
 return (response as List).map((data) => UserModel.fromFirestore(data)).toList();
 } catch (e) {
 debugPrint('Error searching users: ');
 return [];
 }
 }
}
