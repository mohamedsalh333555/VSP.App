import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/ui/components/vsp_card.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/user_repository.dart';
import '../../../core/models/user_model.dart';
import '../../../data/models.dart';
import '../../player/screens/chat_screen.dart';
import '../../../shared/widgets/vsp_empty_state.dart';
import '../../../shared/widgets/vsp_fade_in_item.dart';

class OwnerInboxScreen extends StatefulWidget {
  const OwnerInboxScreen({super.key});

  @override
  State<OwnerInboxScreen> createState() => _OwnerInboxScreenState();
}

class _OwnerInboxScreenState extends State<OwnerInboxScreen> {
  final ChatRepository _chatRepository = ChatRepository();

  Future<void> _openSupportChat(BuildContext context, String ownerId) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: VSPColors.accent)),
    );

    try {
      final chatData = await _chatRepository.getOrCreateSupportChat(ownerId, isArabic);
      final chatId = chatData['id'].toString();
      final booking = Booking.fromFirestore(chatData, chatId);

      if (context.mounted) {
        // Close loading dialog
        Navigator.pop(context);
        // Open ChatScreen
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ChatScreen(booking: booking)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(isArabic ? 'حدث خطأ أثناء الاتصال بالدعم.' : 'Error connecting to support.')),
        );
      }
    }
  }

  Future<void> _startNewChat(BuildContext context, String currentUserId) async {
    final selectedUser = await showSearch<UserModel?>(
      context: context,
      delegate: UserSearchDelegate(currentUserId: currentUserId),
    );

    if (selectedUser == null || !context.mounted) return;

    // Show loading dialog
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
      if (context.mounted) {
        Navigator.pop(context);
        final isArabic = Localizations.localeOf(context).languageCode == 'ar';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isArabic ? 'حدث خطأ أثناء فتح المحادثة.' : 'Error opening chat.')),
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
          style: Theme.of(context).textTheme.displayLarge,
        ),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.headset, color: VSPColors.accent),
            onPressed: () => _openSupportChat(context, ownerId),
            tooltip: isArabic ? 'الاتصال بالدعم' : 'Contact Support',
          ),
          IconButton(
            icon: Icon(LucideIcons.messageSquarePlus, color: VSPColors.accent),
            onPressed: () => _startNewChat(context, ownerId),
            tooltip: isArabic ? 'محادثة جديدة' : 'New Chat',
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _chatRepository.streamBookingsChats(),
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
            
            // The ownerId is involved if they are owner of the stadium, creator of the booking, or in joined_user_ids
            final isParticipant = b.ownerId == ownerId || 
                                  b.createdByUserId == ownerId || 
                                  b.joinedUserIds.contains(ownerId);
            if (!isParticipant) return false;

            final unreadMap = item['unread_counts'] as Map<String, dynamic>;
            final unreadCount = unreadMap[ownerId] as int? ?? 0;
            final isRecent = b.endTime.add(const Duration(hours: 24)).isAfter(now);
            
            // For general support/user chats, they never expire and have stadiumId == 'support_chat' or starting with 'chat_'
            final isGeneralChat = b.stadiumId == 'support_chat' || b.stadiumId == 'chat_thread' || b.id.startsWith('support_chat_') || b.id.startsWith('chat_');
            
            return isGeneralChat || (b.notes != null && (isRecent || unreadCount > 0));
          }).toList();

          if (bookings.isEmpty) {
            return VSPEmptyState(
              icon: LucideIcons.messageSquare,
              title: isArabic ? 'لا توجد محادثات نشطة' : 'No active chats',
              subtitle: isArabic 
                  ? 'ستظهر هنا المحادثات الواردة من اللاعبين بخصوص الحجوزات.' 
                  : 'Chats from players regarding bookings will appear here.',
              buttonText: isArabic ? 'تواصل مع الدعم الفني' : 'Contact Support',
              onButtonPressed: () => _openSupportChat(context, ownerId),
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

              final isSpecialChat = booking.stadiumId == 'support_chat' || 
                                   booking.stadiumId == 'chat_thread' || 
                                   booking.id.startsWith('support_chat_') || 
                                   booking.id.startsWith('chat_');

              if (isSpecialChat) {
                final otherUserId = booking.joinedUserIds.firstWhere(
                  (uid) => uid != ownerId,
                  orElse: () => 'vsp_support_admin',
                );

                if (otherUserId == 'vsp_support_admin') {
                  return VSPFadeInItem(
                    index: index,
                    child: _buildChatRow(
                      context: context,
                      title: isArabic ? 'الدعم الفني VSP' : 'VSP Support',
                      subtitle: booking.lastMessage ?? (isArabic ? 'مرحباً بك في الدعم الفني' : 'Welcome to Support'),
                      timeStr: booking.updatedAt != null ? _formatTime(booking.updatedAt!) : _formatTime(booking.startTime),
                      avatar: null,
                      booking: booking,
                      hasUnread: hasUnread,
                      unreadCount: unreadCount,
                    ),
                  );
                }

                return FutureBuilder<Map<String, dynamic>?>(
                  future: UserRepository().getUserData(otherUserId),
                  builder: (context, userSnap) {
                    final name = userSnap.data?['name'] ?? (isArabic ? 'مستخدم VSP' : 'VSP User');
                    final avatarUrl = userSnap.data?['profile_image_url'] ?? '';
                    return VSPFadeInItem(
                      index: index,
                      child: _buildChatRow(
                        context: context,
                        title: name,
                        subtitle: booking.lastMessage ?? (isArabic ? 'محادثة مباشرة' : 'Direct conversation'),
                        timeStr: booking.updatedAt != null ? _formatTime(booking.updatedAt!) : _formatTime(booking.startTime),
                        avatar: avatarUrl.isNotEmpty ? avatarUrl : null,
                        booking: booking,
                        hasUnread: hasUnread,
                        unreadCount: unreadCount,
                      ),
                    );
                  },
                );
              }

              // Standard booking chat
              return VSPFadeInItem(
                index: index,
                child: _buildChatRow(
                  context: context,
                  title: booking.hostName ?? (isArabic ? 'لاعب' : 'Player'),
                  subtitle: booking.stadiumName,
                  timeStr: _formatTime(booking.startTime),
                  avatar: (booking.hostAvatarUrl != null && booking.hostAvatarUrl!.isNotEmpty) ? booking.hostAvatarUrl : null,
                  booking: booking,
                  hasUnread: hasUnread,
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
    required String title,
    required String subtitle,
    required String timeStr,
    required String? avatar,
    required Booking booking,
    required bool hasUnread,
    required int unreadCount,
  }) {
    return Padding(
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
          color: hasUnread ? VSPColors.accent.withValues(alpha: 0.05) : VSPColors.surface,
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: VSPColors.surfaceAlt,
                backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                child: avatar == null
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
                          title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
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
  UserSearchDelegate({required this.currentUserId});

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
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    final isArabic = query.isNotEmpty && RegExp(r'[\u0600-\u06FF]').hasMatch(query);
    
    return FutureBuilder<List<UserModel>>(
      future: _searchUsers(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
        }

        final users = snapshot.data ?? [];
        if (users.isEmpty) {
          return Center(
            child: Text(
              query.isEmpty
                  ? (isArabic ? 'ابحث بالاسم لبدء المحادثة...' : 'Search by name to start a chat...')
                  : (isArabic ? 'لم يتم العثور على نتائج' : 'No users found'),
              style: const TextStyle(color: VSPColors.textSecondary),
            ),
          );
        }

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: (user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty)
                    ? NetworkImage(user.profileImageUrl!)
                    : null,
                child: (user.profileImageUrl == null || user.profileImageUrl!.isEmpty)
                    ? const Icon(Icons.person, color: VSPColors.accent)
                    : null,
              ),
              title: Text(user.name ?? user.email, style: const TextStyle(color: VSPColors.textPrimary)),
              subtitle: Text(user.role, style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11)),
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
      
      if (query.isNotEmpty) {
        dbQuery = dbQuery.ilike('name', '%$query%');
      }

      final response = await dbQuery.limit(20);
      return (response as List).map((data) => UserModel.fromFirestore(data)).toList();
    } catch (e) {
      debugPrint('Error searching users: $e');
      return [];
    }
  }
}
