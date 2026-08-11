import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/models/chat_model.dart';
import '../../../core/repositories/chat_repository.dart';
import '../../../core/repositories/user_repository.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/services/analytics_service.dart';
import '../../../data/models.dart';

class ChatScreen extends StatefulWidget {
  final Booking booking;
  static String? activeBookingId;

  const ChatScreen({super.key, required this.booking});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    ChatScreen.activeBookingId = widget.booking.id;
    // Mark messages as read when entering the screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.currentUser != null) {
        ChatRepository().markMessagesAsRead(widget.booking.id, auth.currentUser!.uid);
      }
    });
  }

  bool _isSending = false;
  void _sendMessage() async {
    if (_isSending) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final user = auth.userModel;
      if (user == null) return;

      final message = ChatMessage(
        id: '',
        senderId: user.uid,
        senderName: user.name ?? 'Guest',
        text: text,
        timestamp: DateTime.now(),
      );

      _messageController.clear();
      await ChatRepository().sendMessage(widget.booking.id, message);
      AnalyticsService.logChatMessageSent(widget.booking.bookingType.name);

      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      // Log errors if necessary
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  void dispose() {
    ChatScreen.activeBookingId = null;
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final currentUserId = auth.currentUser?.uid;

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.surface,
        elevation: 0,
        title: Builder(
          builder: (context) {
            final isArabic = Localizations.localeOf(context).languageCode == 'ar';
            final isSpecialChat = widget.booking.stadiumId == 'support_chat' || 
                                 widget.booking.stadiumId == 'chat_thread' || 
                                 widget.booking.notes == 'chat_thread' || 
                                 widget.booking.notes == 'support_chat' || 
                                 widget.booking.id.startsWith('support_chat_') || 
                                 widget.booking.id.startsWith('chat_');

            if (!isSpecialChat) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.booking.stadiumName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${widget.booking.playerTeamName ?? "Public Match"} Chat',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
                  ),
                ],
              );
            }

            final otherUserId = widget.booking.joinedUserIds.firstWhere(
              (uid) => uid != currentUserId,
              orElse: () => 'vsp_support_admin',
            );

            if (otherUserId == 'vsp_support_admin') {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic ? 'الدعم الفني VSP' : 'VSP Support',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    isArabic ? 'محادثة الدعم الفني' : 'Support Conversation',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
                  ),
                ],
              );
            }

            return FutureBuilder<Map<String, dynamic>?>(
              future: UserRepository().getUserData(otherUserId),
              builder: (context, snap) {
                final name = snap.data?['name'] ?? (isArabic ? 'مستخدم VSP' : 'VSP User');
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      isArabic ? 'محادثة مباشرة' : 'Direct Conversation',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
                    ),
                  ],
                );
              },
            );
          },
        ),
        leading: IconButton(
          icon: Icon(
            Localizations.localeOf(context).languageCode == 'ar'
                ? Iconsax.arrow_right_3_copy
                : Iconsax.arrow_left_2_copy,
            color: VSPColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: ChatRepository().getChatMessages(widget.booking.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
                }

                final messages = snapshot.data ?? [];

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  itemCount: messages.length + 1,
                  itemBuilder: (context, index) {
                    if (index == messages.length) {
                      return _buildSystemMessage(context);
                    }
                    final message = messages[index];
                    final isMe = message.senderId == currentUserId;

                    return _ChatBubble(
                      message: message,
                      isMe: isMe,
                      booking: widget.booking,
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final now = DateTime.now();
    
    final isSpecialChat = widget.booking.stadiumId == 'support_chat' || 
                         widget.booking.stadiumId == 'chat_thread' || 
                         widget.booking.notes == 'chat_thread' || 
                         widget.booking.notes == 'support_chat' || 
                         widget.booking.id.startsWith('support_chat_') || 
                         widget.booking.id.startsWith('chat_');

    final bool isExpired = !isSpecialChat && widget.booking.endTime.isBefore(now);
    final bool isCancelled = !isSpecialChat && widget.booking.status == BookingStatus.cancelled;

    if (isExpired || isCancelled) {
      return Container(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
        decoration: const BoxDecoration(
          color: VSPColors.surface,
          border: Border(top: BorderSide(color: VSPColors.divider, width: 0.5)),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Iconsax.lock_copy, color: VSPColors.textSecondary, size: 18),
              const SizedBox(width: 8),
              Text(
                isCancelled 
                  ? (isArabic ? 'هذه المحادثة مغلقة لإلغاء الحجز.' : 'This chat is closed due to cancellation.')
                  : (isArabic ? 'المحادثة مغلقة لانتهاء وقت الحجز.' : 'This chat is closed as the booking time expired.'),
                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
      decoration: const BoxDecoration(
        color: VSPColors.surface,
        border: Border(top: BorderSide(color: VSPColors.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: VSPColors.surfaceAlt,
                borderRadius: BorderRadius.circular(VSPRadius.full),
                border: Border.all(color: VSPColors.accent.withValues(alpha: 0.4), width: 1),
              ),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: VSPColors.textPrimary, fontSize: 14),
                textAlign: isArabic ? TextAlign.right : TextAlign.left,
                decoration: InputDecoration(
                  hintText: isArabic ? 'اكتب رسالتك هنا...' : 'Type a message...',
                  hintStyle: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: VSPColors.accent,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Transform.rotate(
                  angle: isArabic ? 3.14159 : 0,
                  child: const Icon(Iconsax.send_1_copy, color: Colors.black, size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemMessage(BuildContext context) {
    final isSpecialChat = widget.booking.stadiumId == 'support_chat' || 
                         widget.booking.stadiumId == 'chat_thread' || 
                         widget.booking.notes == 'chat_thread' || 
                         widget.booking.notes == 'support_chat' || 
                         widget.booking.id.startsWith('support_chat_') || 
                         widget.booking.id.startsWith('chat_');

    if (isSpecialChat) {
      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
      final otherUserId = widget.booking.joinedUserIds.firstWhere(
        (uid) => uid != Provider.of<AuthProvider>(context, listen: false).currentUser?.uid,
        orElse: () => 'vsp_support_admin',
      );
      final text = otherUserId == 'vsp_support_admin'
          ? (isArabic
              ? '👋 مرحباً بك في الدعم الفني لـ VSP. كيف يمكننا مساعدتك اليوم؟'
              : '👋 Welcome to VSP Support. How can we help you today?')
          : (isArabic
              ? '🔒 هذه محادثة مباشرة آمنة ومشفرة.'
              : '🔒 This is a secure and encrypted direct chat.');

      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: VSPColors.surface.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(VSPRadius.lg),
          ),
          child: Text(
            text,
            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final text = lang.isArabic
        ? '🏆 تم تأكيد الحجز! الساحة بانتظاركم... من جاهز للتحدي؟ ⚽'
        : '🏆 Booking Confirmed! The pitch is waiting... Who is ready? ⚽';

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(VSPRadius.lg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(VSPRadius.lg),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: VSPColors.surface.withValues(alpha: 0.4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Iconsax.cup_copy, color: VSPColors.warning, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      text,
                      style: const TextStyle(
                        color: VSPColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final Booking booking;

  const _ChatBubble({
    required this.message,
    required this.isMe,
    required this.booking,
  });

  @override
  Widget build(BuildContext context) {
    final isHost = message.senderId == booking.createdByUserId;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? VSPColors.accent : VSPColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          boxShadow: isHost
              ? [
                  BoxShadow(
                    color: VSPColors.accent.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMe)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.senderName,
                    style: const TextStyle(
                      color: VSPColors.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isHost) ...[
                    const SizedBox(width: 4),
                    Text(
                      isArabic ? '[المُضيف 👑]' : '[HOST 👑]',
                      style: const TextStyle(
                        color: VSPColors.warning,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            if (!isMe) const SizedBox(height: 2),
            Text(
              message.text,
              style: TextStyle(
                color: isMe ? VSPColors.background : VSPColors.textPrimary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('hh:mm a').format(message.timestamp),
              style: TextStyle(
                color: (isMe ? VSPColors.background : VSPColors.textSecondary).withValues(alpha: 0.6),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
