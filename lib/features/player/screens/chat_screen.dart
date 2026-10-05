import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/models/chat_model.dart';
import '../../../core/repositories/chat_repository.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/ui/vsp_ui.dart';
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

  const ChatScreen({
    super.key,
    required this.booking,
    this.conversationId,
    this.conversationTitle,
    this.otherUserId,
    this.isSupportChat = false,
  });

  const ChatScreen.conversation({
    super.key,
    required String conversationId,
    required String title,
    String? otherUserId,
  })  : booking = null,
        conversationId = conversationId,
        conversationTitle = title,
        otherUserId = otherUserId,
        isSupportChat = false;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Stream<List<ChatMessage>>? _messagesStream;
  String? _streamConversationId;
  bool _isSending = false;
  bool _canSend = false;
  bool _checkingPolicy = true;

  String get _conversationKey => widget.conversationId ?? widget.booking?.id ?? '';

  Future<void> _loadPolicy() async {
    if (_conversationKey.isEmpty) {
      if (mounted) setState(() { _checkingPolicy = false; _canSend = false; });
      return;
    }
    final allowed = await ChatRepository().canWriteConversation(_conversationKey);
    if (mounted) setState(() { _checkingPolicy = false; _canSend = allowed; });
  }

  Stream<List<ChatMessage>> _getMessagesStream(String currentUserId) {
    if (_messagesStream != null && _streamConversationId == _conversationKey) return _messagesStream!;
    _streamConversationId = _conversationKey;
    _messagesStream = ChatRepository().getChatMessages(_conversationKey, currentUserId: currentUserId);
    return _messagesStream!;
  }

  String? _reportTarget(String currentUserId) {
    if (widget.otherUserId != null && widget.otherUserId!.isNotEmpty) return widget.otherUserId;
    final b = widget.booking;
    if (b == null) return null;
    return <String>[b.ownerId, b.createdByUserId, ...b.joinedUserIds]
        .firstWhere((id) => id.isNotEmpty && id != currentUserId, orElse: () => '');
  }

  String _reportContextType() => widget.booking?.bookingType == BookingType.challenge ? 'challenge' : 'booking';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final id = context.read<AuthProvider>().currentUser?.id;
      if (id == null) return;
      await _loadPolicy();
      await ChatRepository().markMessagesAsRead(_conversationKey, id);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_isSending || !_canSend) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSending = true);
    try {
      final user = context.read<AuthProvider>().userModel;
      if (user == null) return;
      final message = ChatMessage(
        id: '',
        senderId: user.uid,
        senderName: user.name ?? 'VSP User',
        text: text,
        timestamp: DateTime.now(),
      );
      await ChatRepository().sendMessage(_conversationKey, message);
      _messageController.clear();
      AnalyticsService.logChatMessageSent(widget.booking?.bookingType.name ?? 'direct');
      await _loadPolicy();
    } catch (_) {
      if (mounted) {
        final ar = Localizations.localeOf(context).languageCode == 'ar';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ar ? 'تعذر إرسال الرسالة أو انتهت فترة الكتابة.' : 'Could not send the message or the chat is now read-only.')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final currentUserId = auth.currentUser?.id ?? '';
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final targetUserId = _reportTarget(currentUserId);

    return VSPScaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.surface,
        elevation: 0,
        leading: const VSPBackButton(),
        title: widget.booking != null
            ? ChatAppBarTitle(booking: widget.booking!, currentUserId: currentUserId)
            : Text(widget.conversationTitle ?? (ar ? 'المحادثة' : 'Conversation')),
        actions: [
          if (widget.booking != null)
            IconButton(
              icon: const Icon(Iconsax.call_calling_copy, color: VSPColors.accent, size: 20),
              tooltip: ar ? 'اتصال' : 'Call',
              onPressed: () => ChatCallUtils.makeCall(context, booking: widget.booking!, currentUserId: currentUserId),
            ),
          if (targetUserId != null && targetUserId.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Iconsax.more_copy, color: VSPColors.textPrimary),
              color: VSPColors.surface,
              onSelected: (value) {
                if (value == 'report') {
                  ChatDialogs.showReportDialog(
                    context,
                    currentUserId: currentUserId,
                    targetUserId: targetUserId,
                    contextId: widget.booking?.id ?? _conversationKey,
                    contextType: widget.booking == null ? 'booking' : _reportContextType(),
                    bookingId: widget.booking?.id,
                    conversationId: widget.conversationId,
                  );
                } else if (value == 'delete') {
                  ChatDialogs.showConfirmDeleteConversationDialog(
                    context,
                    currentUserId: currentUserId,
                    conversationId: _conversationKey,
                  );
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'report',
                  child: Row(children: [
                    const Icon(Iconsax.flag_copy, color: VSPColors.warning, size: 18),
                    const SizedBox(width: 8),
                    Text(ar ? 'إبلاغ عن المستخدم' : 'Report User', style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ]),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    const Icon(Iconsax.trash_copy, color: VSPColors.error, size: 18),
                    const SizedBox(width: 8),
                    Text(ar ? 'حذف المحادثة' : 'Delete Conversation', style: const TextStyle(color: VSPColors.error, fontSize: 13)),
                  ]),
                ),
              ],
            ),
        ],
      ),
      body: Column(children: [
        if (_checkingPolicy) const LinearProgressIndicator(minHeight: 2, color: VSPColors.accent),
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: _getMessagesStream(currentUserId),
            builder: (context, snapshot) {
              final messages = snapshot.data ?? [];
              return ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                itemCount: messages.length + 1,
                itemBuilder: (context, index) {
                  if (index == messages.length) {
                    return ChatSystemBanner(booking: widget.booking, currentUserId: currentUserId, isSpecialChat: false);
                  }
                  final message = messages[index];
                  return ChatMessageBubble(
                    message: message,
                    isMe: message.senderId == currentUserId,
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
          canSend: !_checkingPolicy && _canSend,
          messageController: _messageController,
          isSending: _isSending,
          onSendMessage: _sendMessage,
        ),
      ]),
    );
  }
}
