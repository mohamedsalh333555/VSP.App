// ignore_for_file: prefer_initializing_formals

import 'package:flutter/material.dart';
import '../../../core/ui/vsp_ui.dart';
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
  final Booking? booking;
  final String? conversationId;
  final String? conversationTitle;
  final String? otherUserId;
  final bool isSupportChat;
  static String? activeBookingId;

  const ChatScreen({super.key, required Booking booking})
      : booking = booking,
        conversationId = null,
        conversationTitle = null,
        otherUserId = null,
        isSupportChat = false;

  const ChatScreen.conversation({
    super.key,
    required String conversationId,
    required String title,
    String? otherUserId,
    bool isSupportChat = false,
  })  : booking = null,
        conversationId = conversationId,
        conversationTitle = title,
        otherUserId = otherUserId,
        isSupportChat = isSupportChat;

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
    final id = widget.conversationId ?? widget.booking!.id;
    _messagesStream = ChatRepository().getChatMessages(id, currentUserId: currentUserId);
    return _messagesStream!;
  }

  @override
  void initState() {
    super.initState();
    ChatScreen.activeBookingId = widget.conversationId ?? widget.booking?.id;
    // Mark messages as read when entering the screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.currentUser != null) {
        ChatRepository().markMessagesAsRead(widget.conversationId ?? widget.booking!.id, auth.currentUser!.uid);
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
      await ChatRepository().sendMessage(widget.conversationId ?? widget.booking!.id, message);
      AnalyticsService.logChatMessageSent(widget.booking?.bookingType.name ?? 'direct');

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

    return VSPScaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.surface,
        elevation: 0,
        title: widget.booking != null
            ? ChatAppBarTitle(booking: widget.booking!, currentUserId: currentUserId)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.conversationTitle ?? (isArabic ? 'المحادثة' : 'Conversation'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    widget.isSupportChat
                        ? (isArabic ? 'محادثة الدعم الفني' : 'Support Conversation')
                        : (isArabic ? 'محادثة مباشرة' : 'Direct Conversation'),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
                  ),
                ],
              ),
        leading: const VSPBackButton(),
        actions: [
          if (widget.booking != null)
            IconButton(
              icon: const Icon(Iconsax.call_calling_copy, color: VSPColors.accent, size: 20),
              tooltip: isArabic ? 'اتصال بالمالك' : 'Call Owner',
              onPressed: () => ChatCallUtils.makeCall(
                context,
                booking: widget.booking!,
                currentUserId: currentUserId,
              ),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Iconsax.more_copy, color: VSPColors.textPrimary),
            color: VSPColors.surface,
            onSelected: (value) {
              if (value == 'report') {
                ChatDialogs.showReportDialog(
                  context,
                  currentUserId: currentUserId,
                  bookingId: widget.conversationId ?? widget.booking!.id,
                );
              } else if (value == 'delete') {
                if (widget.booking != null) {
                  ChatDialogs.showConfirmDeleteDialog(
                    context,
                    currentUserId: currentUserId,
                    booking: widget.booking!,
                  );
                } else {
                  ChatDialogs.showConfirmDeleteConversationDialog(
                    context,
                    currentUserId: currentUserId,
                    conversationId: widget.conversationId!,
                  );
                }
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    const Icon(Iconsax.flag_copy, color: VSPColors.warning, size: 18),
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
                    const Icon(Iconsax.trash_copy, color: VSPColors.error, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      isArabic ? 'حذف المحادثة' : 'Delete Conversation',
                      style: const TextStyle(color: VSPColors.error, fontSize: 13),
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
                        isSpecialChat: widget.booking == null || widget.isSupportChat,
                      );
                    }
                    final message = messages[index];
                    final isMe = message.senderId == currentUserId;

                    return ChatMessageBubble(
                      message: message,
                      isMe: isMe,
                      booking: widget.booking,
                      isHost: widget.booking != null && message.senderId == widget.booking!.createdByUserId,
                    );
                  },
                );
              },
            ),
          ),
          ChatInputBar(
            booking: widget.booking,
            isSpecialChat: widget.booking == null || widget.isSupportChat,
            messageController: _messageController,
            isSending: _isSending,
            onSendMessage: _sendMessage,
          ),
        ],
      ),
    );
  }
}
