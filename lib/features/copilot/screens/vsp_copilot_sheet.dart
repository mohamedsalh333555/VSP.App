import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/models/copilot_message.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/stadium_repository.dart';
import '../../../core/services/vsp_copilot_service.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/gemini_ai_icon.dart';
import '../../player/screens/booking_confirmation_screen.dart';

/// Simple chat sheet for VSP Copilot POC with single read-only search tool.
class VspCopilotSheet extends StatefulWidget {
  final VspCopilotService copilotService;
  final bool isArabic;

  const VspCopilotSheet({
    super.key,
    this.copilotService = const VspCopilotService(),
    this.isArabic = true,
  });

  static Future<void> show(BuildContext context, {bool isArabic = true}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VspCopilotSheet(isArabic: isArabic),
    );
  }

  @override
  State<VspCopilotSheet> createState() => _VspCopilotSheetState();
}

class _VspCopilotSheetState extends State<VspCopilotSheet> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<CopilotMessage> _messages = [];
  bool _isLoading = false;

  static const String _singleQuickPromptAr = 'دور لي على ملاعب فاضية النهاردة';
  static const String _singleQuickPromptEn = 'Find available pitches today';

  Future<void> _handleBookStadium(CopilotStadiumSummary summary) async {
    Navigator.of(context).pop();

    try {
      final repo = StadiumRepository();
      final stadium = await repo.getStadiumById(summary.id);
      if (stadium != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BookingConfirmationScreen(
              stadium: stadium,
              selectedDate: DateTime.now(),
              initialSelectedSlots: const ['08:00 PM - 09:00 PM'],
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[VspCopilotSheet] _handleBookStadium error: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _messages.add(
      CopilotMessage.assistant(
        widget.isArabic
            ? 'أهلاً يا كابتن! أنا كابتن VSP. أقدر أساعدك تبحث وتستكشف أفضل الملاعب المتاحة بالمنطقة والسعر.'
            : 'Welcome Captain! I am VSP Copilot. I can help you search and explore pitches by area and price.',
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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

  Future<void> _handleSendMessage([String? overrideText]) async {
    final text = (overrideText ?? _controller.text).trim();
    if (text.isEmpty || _isLoading) return;

    _controller.clear();
    setState(() {
      _messages.add(CopilotMessage.user(text));
      _isLoading = true;
    });
    _scrollToBottom();

    final auth = Provider.of<AuthProvider?>(context, listen: false);
    final userGov = auth?.userModel?.governorate ?? 'أسوان';

    final response = await widget.copilotService.sendMessage(
      message: text,
      governorate: userGov,
    );

    if (mounted) {
      setState(() {
        _messages.add(response);
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final auth = Provider.of<AuthProvider?>(context, listen: false);
    final userGov = auth?.userModel?.governorate;
    final quickPrompt = widget.isArabic
        ? (userGov != null ? 'دور لي على ملاعب فاضية في $userGov' : _singleQuickPromptAr)
        : _singleQuickPromptEn;

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
        border: Border.all(color: VSPColors.borderLight, width: 1),
      ),
      child: Column(
        children: [
          _buildHeader(),
          const Divider(color: Colors.white12, height: 1),
          Expanded(child: _buildMessagesList()),
          if (!_isLoading) _buildQuickPrompt(quickPrompt),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const GeminiAIIcon(size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isArabic ? 'كابتن VSP الذكي' : 'VSP Copilot',
                  style: const TextStyle(
                    color: VSPColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.isArabic ? 'بحث واستكشاف الملاعب' : 'Pitch Search & Discovery',
                  style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Iconsax.close_circle_copy, color: Colors.white70, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length && _isLoading) {
          return _buildLoadingBubble();
        }
        final msg = _messages[index];
        return _buildMessageItem(msg);
      },
    );
  }

  Widget _buildMessageItem(CopilotMessage msg) {
    final isUser = msg.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
            decoration: BoxDecoration(
              color: isUser ? VSPColors.accent : VSPColors.surfaceAlt,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(isUser ? 14 : 2),
                bottomRight: Radius.circular(isUser ? 2 : 14),
              ),
              border: Border.all(
                color: isUser ? Colors.transparent : VSPColors.borderLight,
              ),
            ),
            child: Text(
              msg.text,
              style: TextStyle(
                color: isUser ? Colors.black : VSPColors.textPrimary,
                fontSize: 13.5,
                height: 1.4,
                fontWeight: isUser ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          if (msg.hasStadiums) ...[
            const SizedBox(height: 10),
            _buildStadiumsList(msg.stadiumResults),
          ],
        ],
      ),
    );
  }

  Widget _buildStadiumsList(List<CopilotStadiumSummary> stadiums) {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: stadiums.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final s = stadiums[i];
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(VSPRadius.md),
              onTap: () => _handleBookStadium(s),
              child: Container(
                width: 200,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: VSPColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(VSPRadius.md),
                  border: Border.all(color: VSPColors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.name,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (s.rating > 0) ...[
                          const Icon(Iconsax.star_copy, color: VSPColors.warning, size: 13),
                          const SizedBox(width: 2),
                          Text(
                            s.rating.toStringAsFixed(1),
                            style: const TextStyle(color: VSPColors.warning, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      s.governorate.isNotEmpty ? s.governorate : (widget.isArabic ? 'مصر' : 'Egypt'),
                      style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${s.pricePerHour.toInt()} ${widget.isArabic ? "ج.م/ساعة" : "EGP/hr"}',
                          style: const TextStyle(color: VSPColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Icon(widget.isArabic ? Iconsax.arrow_left_2_copy : Iconsax.arrow_right_3_copy, size: 10, color: Colors.white54),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingBubble() {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: VSPColors.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: VSPColors.borderLight),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: VSPColors.accent),
            ),
            SizedBox(width: 10),
            Text(
              'كابتن VSP يبحث الآن...',
              style: TextStyle(color: VSPColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickPrompt(String prompt) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Align(
        alignment: Alignment.centerRight,
        child: ActionChip(
          backgroundColor: VSPColors.accent.withValues(alpha: 0.12),
          side: BorderSide(color: VSPColors.accent.withValues(alpha: 0.25)),
          avatar: const Icon(Iconsax.search_normal_copy, size: 13, color: VSPColors.accent),
          label: Text(
            prompt,
            style: const TextStyle(color: VSPColors.accent, fontSize: 11, fontWeight: FontWeight.w600),
          ),
          onPressed: () => _handleSendMessage(prompt),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: VSPColors.surface,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: widget.isArabic ? 'اكتب طلبك للبحث عن ملاعب...' : 'Search pitches...',
                hintStyle: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
                filled: true,
                fillColor: VSPColors.inputFill,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(VSPRadius.input),
                  borderSide: const BorderSide(color: VSPColors.borderLight, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(VSPRadius.input),
                  borderSide: const BorderSide(color: VSPColors.borderLight, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(VSPRadius.input),
                  borderSide: const BorderSide(color: VSPColors.accent, width: 1.2),
                ),
              ),
              onSubmitted: (_) => _handleSendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _isLoading ? null : () => _handleSendMessage(),
            icon: const Icon(Iconsax.send_2_copy, color: VSPColors.accent),
          ),
        ],
      ),
    );
  }
}
