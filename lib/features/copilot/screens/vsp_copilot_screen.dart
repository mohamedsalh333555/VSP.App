import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/models/copilot_message.dart';
import '../../../core/providers/stadium_provider.dart';
import '../../../core/repositories/stadium_repository.dart';
import '../../../core/services/vsp_copilot_service.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../data/models.dart';
import '../../player/screens/booking_confirmation_screen.dart';
import '../../player/screens/champion_screen.dart';
import '../../player/screens/player_home_screen.dart';
import '../widgets/copilot_chat_bubble.dart';
import '../widgets/copilot_conversations_drawer.dart';
import '../widgets/copilot_starter_prompts.dart';

/// Full-screen LLM Chatbot experience for VSP Copilot (matching ChatGPT/Gemini apps).
class VspCopilotScreen extends StatefulWidget {
  final VspCopilotService copilotService;
  final bool? isArabic;

  const VspCopilotScreen({
    super.key,
    this.copilotService = const VspCopilotService(),
    this.isArabic,
  });

  @override
  State<VspCopilotScreen> createState() => _VspCopilotScreenState();
}

class _VspCopilotScreenState extends State<VspCopilotScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<CopilotConversation> _conversations = [];
  List<CopilotMessage> _messages = [];
  String? _activeConversationId;
  bool _isLoadingConversations = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoadingConversations = true);
    final convs = await widget.copilotService.fetchConversations();
    if (mounted) {
      setState(() {
        _conversations = convs;
        _isLoadingConversations = false;
      });
    }
  }

  Future<void> _handleSelectConversation(CopilotConversation conv) async {
    setState(() {
      _activeConversationId = conv.id;
      _isSending = true;
    });
    final msgs = await widget.copilotService.fetchMessages(conv.id);
    if (mounted) {
      setState(() {
        _messages = msgs;
        _isSending = false;
      });
      _scrollToBottom();
    }
  }

  void _handleStartNewChat() {
    setState(() {
      _activeConversationId = null;
      _messages = [];
    });
  }

  Future<void> _handleDeleteConversation(String convId) async {
    final success = await widget.copilotService.deleteConversation(convId);
    if (success && mounted) {
      if (_activeConversationId == convId) {
        _handleStartNewChat();
      }
      _loadConversations();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSendMessage([String? promptText]) async {
    final text = (promptText ?? _controller.text).trim();
    if (text.isEmpty || _isSending) return;

    _controller.clear();
    HapticFeedback.lightImpact();

    setState(() {
      _messages.add(CopilotMessage.user(text, conversationId: _activeConversationId));
      _isSending = true;
    });
    _scrollToBottom();

    final response = await widget.copilotService.sendMessage(
      text,
      conversationId: _activeConversationId,
    );

    if (mounted) {
      setState(() {
        _activeConversationId = response.conversationId ?? _activeConversationId;
        _messages.add(response);
        _isSending = false;
      });
      _scrollToBottom();
      _loadConversations();
    }
  }

  Future<void> _handleBookStadium(CopilotStadiumSummary summary) async {
    final stadiumProvider = Provider.of<StadiumProvider>(context, listen: false);
    Stadium? targetStadium = stadiumProvider.stadiums.cast<Stadium?>().firstWhere(
      (s) => s?.id == summary.id,
      orElse: () => null,
    );

    if (targetStadium == null) {
      try {
        final repo = StadiumRepository();
        targetStadium = await repo.getStadiumById(summary.id);
      } catch (e) {
        debugPrint('[VspCopilotScreen] getStadiumById error: $e');
      }
    }

    if (!mounted) return;

    if (targetStadium != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BookingConfirmationScreen(
            stadium: targetStadium!,
            selectedDate: DateTime.now(),
            initialSelectedSlots: const ['08:00 PM - 09:00 PM'],
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر تحميل بيانات ملعب ${summary.name} حالياً، يرجى المحاولة لاحقاً'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _handleExecuteAction(CopilotAction action) {
    HapticFeedback.mediumImpact();
    final actionType = action.actionType.toUpperCase();
    final route = action.route.toLowerCase();

    if (actionType == 'PROFILE_UPDATED') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  action.label.isNotEmpty ? action.label : 'تم تحديث بياناتك بنجاح!',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF00E676),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    if (route.contains('team') || route.contains('my-team')) {
      context.pop();
      playerHomeScreenKey.currentState?.switchToTab(1);
    } else if (route.contains('1v1') || route.contains('tournament') || route.contains('championship')) {
      context.pop();
      playerHomeScreenKey.currentState?.switchToTab(2);
      if (route.contains('1v1')) {
        championScreenKey.currentState?.switchToTab(1);
      }
    } else if (route.contains('booking') || route.contains('match')) {
      context.pop();
      playerHomeScreenKey.currentState?.switchToTab(3);
    } else if (route.contains('profile') || route.contains('setting')) {
      context.pop();
      playerHomeScreenKey.currentState?.switchToTab(4);
    } else {
      try {
        context.push(action.route);
      } catch (e) {
        debugPrint('[VspCopilotScreen] Navigate error: $e');
      }
    }
  }

  void _handleSelectTournament(CopilotTournamentSummary t) {
    HapticFeedback.lightImpact();
    if (t.type == '1v1') {
      context.pop();
      playerHomeScreenKey.currentState?.switchToTab(2);
      championScreenKey.currentState?.switchToTab(1);
    } else {
      context.push('/championship/${t.id}');
    }
  }

  void _handleJoinMatch(CopilotOpenMatchSummary m) {
    HapticFeedback.lightImpact();
    context.push('/match/${m.id}');
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = widget.isArabic ?? (Localizations.maybeLocaleOf(context)?.languageCode != 'en');
    final hasMessages = _messages.isNotEmpty;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: VSPColors.surface,
      drawer: CopilotConversationsDrawer(
        conversations: _conversations,
        activeConversationId: _activeConversationId,
        isLoading: _isLoadingConversations,
        onNewChat: _handleStartNewChat,
        onSelectConversation: _handleSelectConversation,
        onDeleteConversation: _handleDeleteConversation,
      ),
      appBar: _buildAppBar(context, isArabic),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: hasMessages
                  ? _buildMessagesList(isArabic)
                  : CopilotStarterPrompts(
                      onSelectPrompt: _handleSendMessage,
                      isArabic: isArabic,
                    ),
            ),
            _buildInputBar(isArabic),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isArabic) {
    return AppBar(
      backgroundColor: VSPColors.surface,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Iconsax.textalign_justifycenter_copy, color: VSPColors.accent, size: 22),
        tooltip: isArabic ? 'سجل المحادثات' : 'Chat History',
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Iconsax.flash_copy, color: VSPColors.accent, size: 18),
          const SizedBox(width: 8),
          Text(
            isArabic ? 'كابتن VSP الذكي' : 'VSP Copilot',
            style: const TextStyle(
              color: VSPColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Color(0xFF00E676),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.add_circle_outline_rounded, color: VSPColors.accent, size: 22),
          tooltip: isArabic ? 'محادثة جديدة' : 'New Chat',
          onPressed: _handleStartNewChat,
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
          onPressed: () => context.pop(),
        ),
      ],
    );
  }

  Widget _buildMessagesList(bool isArabic) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length + (_isSending ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length && _isSending) {
          return const CopilotLoadingBubble();
        }
        final msg = _messages[index];
        return CopilotChatBubble(
          message: msg,
          isArabic: isArabic,
          onBookStadium: _handleBookStadium,
          onExecuteAction: _handleExecuteAction,
          onSelectTournament: _handleSelectTournament,
          onJoinMatch: _handleJoinMatch,
        );
      },
    );
  }

  Widget _buildInputBar(bool isArabic) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF142019),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: isArabic ? 'اسأل كابتن VSP عن أي ملعب...' : 'Ask VSP Copilot...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF1C2B22),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(VSPRadius.lg),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _handleSendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _isSending ? null : () => _handleSendMessage(),
            style: IconButton.styleFrom(
              backgroundColor: VSPColors.accent,
              foregroundColor: Colors.black,
            ),
            icon: const Icon(Icons.send_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}
