import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/chat_repository.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/repositories/app_settings_repository.dart';
import '../../../core/ui/vsp_ui.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/vsp_launcher_utils.dart';
import '../../../shared/widgets/vsp_back_button.dart';

class SupportTicketScreen extends StatefulWidget {
  final String ticketId;
  final String title;
  const SupportTicketScreen({super.key, required this.ticketId, required this.title});
  @override
  State<SupportTicketScreen> createState() => _SupportTicketScreenState();
}

class _SupportTicketScreenState extends State<SupportTicketScreen> {
  final _repo = ChatRepository();
  final _controller = TextEditingController();
  bool _sending = false;
  bool _escalating = false;
  int _accountGeneration = 0;
  String? _streamUserId;
  late Stream<Map<String, dynamic>?> _ticketStream;
  late Stream<List<Map<String, dynamic>>> _messagesStream;

  void _bindStreams(String userId) {
    _streamUserId = userId;
    _ticketStream = userId.isEmpty
        ? const Stream<Map<String, dynamic>?>.empty()
        : _repo.streamSupportTicket(widget.ticketId);
    _messagesStream = userId.isEmpty
        ? const Stream<List<Map<String, dynamic>>>.empty()
        : _repo.streamSupportTicketMessages(widget.ticketId);
  }

  @override
  void initState() {
    super.initState();
    _bindStreams(context.read<AuthProvider>().currentUser?.id ?? '');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final activeUserId = context.watch<AuthProvider>().currentUser?.id ?? '';
    if (activeUserId == _streamUserId) return;
    _accountGeneration++;
    _bindStreams(activeUserId);
    _controller.clear();
    _sending = false;
    _escalating = false;
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending ||
        _streamUserId == null ||
        _streamUserId!.isEmpty ||
        context.read<AuthProvider>().currentUser?.id != _streamUserId) {
      return;
    }
    final sendingUserId = _streamUserId!;
    final requestGeneration = _accountGeneration;
    setState(() => _sending = true);
    try {
      await _repo.sendSupportTicketMessage(ticketId: widget.ticketId, body: body);
      if (mounted &&
          requestGeneration == _accountGeneration &&
          context.read<AuthProvider>().currentUser?.id == sendingUserId) {
        _controller.clear();
      }
    } catch (e) {
      if (mounted &&
          requestGeneration == _accountGeneration &&
          context.read<AuthProvider>().currentUser?.id == sendingUserId) {
        VSPLogger.w('Support ticket message send failed: $e');
        final ar = Localizations.localeOf(context).languageCode == 'ar';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ar ? 'تعذر إرسال الرسالة. حاول مرة أخرى.' : 'Could not send the message. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted && requestGeneration == _accountGeneration) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _whatsappFallback() async {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final requestGeneration = _accountGeneration;
    final requestingUserId = _streamUserId;
    bool requestStillBelongsToActiveAccount() =>
        mounted &&
        requestGeneration == _accountGeneration &&
        requestingUserId != null &&
        requestingUserId.isNotEmpty &&
        context.read<AuthProvider>().currentUser?.id == requestingUserId;
    if (!requestStillBelongsToActiveAccount() || _escalating) return;
    setState(() => _escalating = true);
    try {
      final settings = await AppSettingsRepository().getSettings();
      if (!requestStillBelongsToActiveAccount()) return;
      final phone = settings.whatsappNumber.isNotEmpty
          ? settings.whatsappNumber
          : settings.supportPhone;
      if (phone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ar
                  ? 'وسيلة التواصل عبر واتساب غير متاحة حالياً.'
                  : 'WhatsApp support is not available right now.',
            ),
          ),
        );
        return;
      }
      final ref = widget.ticketId.length >= 8
          ? widget.ticketId.substring(0, 8)
          : widget.ticketId;
      try {
        await _repo.markSupportTicketWhatsAppEscalated(widget.ticketId);
      } catch (_) {
        // Escalation tracking is secondary; opening the configured support
        // channel remains available even if this metadata update fails.
      }
      if (!requestStillBelongsToActiveAccount()) return;
      await VSPLauncherUtils.openWhatsApp(
        context,
        phone: phone,
        message: ar
            ? 'أحتاج تصعيد تذكرة دعم VSP رقم #$ref.'
            : 'I need to escalate VSP support ticket #$ref.',
      );
    } catch (_) {
      if (requestStillBelongsToActiveAccount()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ar
                  ? 'تعذر فتح واتساب حالياً. حاول مرة أخرى.'
                  : 'Could not open WhatsApp right now. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted && requestGeneration == _accountGeneration) {
        setState(() => _escalating = false);
      }
    }
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<AuthProvider>().currentUser?.id ?? '';
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return VSPScaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background, elevation: 0,
        leading: const VSPBackButton(), title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: ar ? 'تصعيد عبر واتساب' : 'Escalate via WhatsApp',
            onPressed: _escalating ? null : _whatsappFallback,
            icon: _escalating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Iconsax.message_text_1_copy, color: VSPColors.accent),
          ),
        ],
      ),
      body: userId.isEmpty
          ? Center(
              child: Text(
                ar
                    ? 'سجّل الدخول لعرض تذكرة الدعم.'
                    : 'Sign in to view this support ticket.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: VSPColors.textSecondary),
              ),
            )
          : StreamBuilder<Map<String, dynamic>?>(
        key: ValueKey(_streamUserId),
        stream: _ticketStream,
        builder: (context, ticketSnapshot) {
          if (ticketSnapshot.connectionState == ConnectionState.waiting &&
              ticketSnapshot.data == null) {
            return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
          }
          if (ticketSnapshot.hasError && !ticketSnapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(VSPSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ar ? 'تعذر تحميل بيانات التذكرة.' : 'Could not load ticket details.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: VSPColors.textSecondary),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _bindStreams(userId);
                      }),
                      child: Text(ar ? 'إعادة المحاولة' : 'Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          final ticket = ticketSnapshot.data;
          if (ticket == null) {
            return Center(
              child: Text(
                ar ? 'التذكرة غير متاحة.' : 'This ticket is unavailable.',
                style: const TextStyle(color: VSPColors.textSecondary),
              ),
            );
          }
          final status = ticket['status']?.toString().toLowerCase() ?? 'open';
          final canReply = status != 'closed' && status != 'resolved';
          String statusLabel() {
            switch (status) {
              case 'in_progress':
                return ar ? 'قيد المتابعة' : 'In progress';
              case 'waiting_user':
                return ar ? 'في انتظار ردك' : 'Waiting for you';
              case 'resolved':
                return ar ? 'تم الحل' : 'Resolved';
              case 'closed':
                return ar ? 'مغلقة' : 'Closed';
              default:
                return ar ? 'مفتوحة' : 'Open';
            }
          }

          return Column(children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(VSPSpacing.md, VSPSpacing.sm, VSPSpacing.md, VSPSpacing.xs),
              padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.sm),
              decoration: BoxDecoration(
                color: canReply ? VSPColors.surface : VSPColors.surfaceAlt,
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(color: canReply ? VSPColors.divider : VSPColors.warning.withValues(alpha: 0.45)),
              ),
              child: Row(
                children: [
                  const Icon(Iconsax.info_circle_copy, color: VSPColors.accent, size: 18),
                  const SizedBox(width: VSPSpacing.sm),
                  Expanded(
                    child: Text(
                      '${ar ? 'حالة التذكرة' : 'Ticket status'}: ${statusLabel()}',
                      style: const TextStyle(color: VSPColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12.5),
                    ),
                  ),
                  Text(
                    widget.ticketId.length >= 8 ? '#${widget.ticketId.substring(0, 8)}' : '#${widget.ticketId}',
                    style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (ticketSnapshot.hasError)
              _SupportStreamWarning(
                isArabic: ar,
                onRetry: () => setState(() {
                  _bindStreams(userId);
                }),
              ),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                key: ValueKey('$_streamUserId-messages'),
                stream: _messagesStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      (snapshot.data == null || snapshot.data!.isEmpty)) {
                    return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
                  }
                  if (snapshot.hasError && !snapshot.hasData) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(VSPSpacing.lg),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              ar ? 'تعذر تحميل الرسائل.' : 'Could not load messages.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: VSPColors.textSecondary),
                            ),
                            TextButton(
                              onPressed: () => setState(() {
                                _bindStreams(userId);
                              }),
                              child: Text(ar ? 'إعادة المحاولة' : 'Retry'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final messages = snapshot.data ?? [];
                  if (snapshot.hasError && messages.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(VSPSpacing.lg),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              ar ? 'تعذر تحديث الرسائل.' : 'Could not load messages.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: VSPColors.textSecondary),
                            ),
                            TextButton(
                              onPressed: () => setState(() {
                                _bindStreams(userId);
                              }),
                              child: Text(ar ? 'إعادة المحاولة' : 'Retry'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  if (messages.isEmpty) {
                    return Center(
                      child: Text(
                        ar ? 'اكتب تفاصيل المشكلة لفريق الدعم.' : 'Describe the issue to support.',
                        style: const TextStyle(color: VSPColors.textSecondary),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(VSPSpacing.md),
                    itemCount: messages.length + (snapshot.hasError ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (snapshot.hasError && i == 0) {
                        return _SupportStreamWarning(
                          isArabic: ar,
                          onRetry: () => setState(() {
                  _bindStreams(userId);
                }),
                        );
                      }
                      final messageIndex = i - (snapshot.hasError ? 1 : 0);
                      final m = messages[messageIndex];
                      final me = m['sender_id']?.toString() == userId;
                      return Align(
                        alignment: me ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: VSPSpacing.sm),
                          padding: const EdgeInsets.all(VSPSpacing.md),
                          constraints: const BoxConstraints(maxWidth: 320),
                          decoration: BoxDecoration(
                            color: me ? VSPColors.accent : VSPColors.surface,
                            borderRadius: BorderRadius.circular(VSPRadius.card),
                          ),
                          child: Text(
                            m['body']?.toString() ?? '',
                            style: TextStyle(color: me ? Colors.black : Colors.white),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            if (canReply)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(VSPSpacing.md),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        enabled: !_sending,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: ar ? 'اكتب رسالتك للدعم...' : 'Write to support...',
                          prefixIcon: const Icon(Iconsax.message_text_1_copy),
                        ),
                      ),
                    ),
                    const SizedBox(width: VSPSpacing.sm),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _controller,
                      builder: (context, value, _) => IconButton(
                        tooltip: ar ? 'إرسال الرسالة' : 'Send message',
                        onPressed: _sending || value.text.trim().isEmpty
                            ? null
                            : _send,
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        icon: _sending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(
                                Iconsax.send_2_copy,
                                color: VSPColors.accent,
                              ),
                      ),
                    ),
                  ]),
                ),
              )
            else
              SafeArea(
                top: false,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(VSPSpacing.md),
                  decoration: const BoxDecoration(
                    color: VSPColors.surface,
                    border: Border(top: BorderSide(color: VSPColors.divider, width: 0.5)),
                  ),
                  child: Text(
                    ar
                        ? 'تم إغلاق التذكرة. يمكنك الاحتفاظ بالرسائل السابقة كمراجع.'
                        : 'This ticket is closed. Previous messages remain available.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: VSPColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                ),
              ),
          ]);
        },
      ),
    );
  }
}


class _SupportStreamWarning extends StatelessWidget {
  final bool isArabic;
  final VoidCallback onRetry;

  const _SupportStreamWarning({
    required this.isArabic,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(
        horizontal: VSPSpacing.md,
        vertical: VSPSpacing.xs,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: VSPSpacing.md,
        vertical: VSPSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: VSPColors.surfaceAlt,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Iconsax.warning_2_copy, color: VSPColors.warning, size: 17),
          const SizedBox(width: VSPSpacing.sm),
          Expanded(
            child: Text(
              isArabic
                  ? 'تعذر تحديث المحادثة. ما تم تحميله ما زال محفوظًا.'
                  : 'Could not refresh this conversation. Loaded messages are still available.',
              style: const TextStyle(
                color: VSPColors.textSecondary,
                fontSize: 11.5,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
          ),
        ],
      ),
    );
  }
}
