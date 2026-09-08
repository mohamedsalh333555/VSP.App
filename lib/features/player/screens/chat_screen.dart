import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/models/chat_model.dart';
import '../../../core/repositories/chat_repository.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/services/analytics_service.dart';
import '../../../shared/widgets/vsp_back_button.dart';
import '../../../data/models.dart';
import '../widgets/chat/chat_message_bubble.dart';
import '../widgets/chat/chat_input_bar.dart';
import '../widgets/chat/chat_app_bar_title.dart';
import '../widgets/chat/chat_system_banner.dart';
import '../widgets/chat/chat_dialogs.dart';
import '../widgets/chat/chat_call_utils.dart';

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
  Stream<List<ChatMessage>>? _messagesStream;
  String? _lastUserId;
  bool _isSending = false;

  Stream<List<ChatMessage>> _getMessagesStream(String currentUserId) {
    if (_messagesStream != null && _lastUserId == currentUserId) {
      return _messagesStream!;
    }
    _lastUserId = currentUserId;
    _messagesStream = ChatRepository().getChatMessages(widget.booking.id, currentUserId: currentUserId);
    return _messagesStream!;
  }

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

  @override
  void dispose() {
    ChatScreen.activeBookingId = null;
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

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

      if (mounted && _scrollController.hasClients) {
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
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final currentUserId = auth.currentUser?.uid ?? '';
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.surface,
        elevation: 0,
        title: ChatAppBarTitle(
          booking: widget.booking,
          currentUserId: currentUserId,
        ),
        leading: const VSPBackButton(),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.call_calling_copy, color: VSPColors.accent, size: 20),
            tooltip: isArabic ? 'اتصال بالمالك' : 'Call Owner',
            onPressed: () => ChatCallUtils.makeCall(
              context,
              booking: widget.booking,
              currentUserId: currentUserId,
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: VSPColors.textPrimary),
            color: VSPColors.surface,
            onSelected: (value) {
              if (value == 'report') {
                ChatDialogs.showReportDialog(
                  context,
                  currentUserId: currentUserId,
                  bookingId: widget.booking.id,
                );
              } else if (value == 'delete') {
                ChatDialogs.showConfirmDeleteDialog(
                  context,
                  currentUserId: currentUserId,
                  booking: widget.booking,
                );
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    const Icon(Icons.flag_outlined, color: Colors.orangeAccent, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      isArabic ? 'إبلاغ عن المحادثة' : 'Report Chat',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      isArabic ? 'حذف المحادثة' : 'Delete Conversation',
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _getMessagesStream(currentUserId),
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
                      return ChatSystemBanner(
                        booking: widget.booking,
                        currentUserId: currentUserId,
                      );
                    }
                    final message = messages[index];
                    final isMe = message.senderId == currentUserId;

                    return ChatMessageBubble(
                      message: message,
                      isMe: isMe,
                      booking: widget.booking,
                    );
                  },
                );
              },
            ),
          ),
          ChatInputBar(
            booking: widget.booking,
            messageController: _messageController,
            isSending: _isSending,
            onSendMessage: _sendMessage,
          ),
        ],
      ),
    );
  }
}
