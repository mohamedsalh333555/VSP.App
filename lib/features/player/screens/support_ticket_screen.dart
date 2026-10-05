import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/chat_repository.dart';
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

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _repo.sendSupportTicketMessage(ticketId: widget.ticketId, body: body);
      _controller.clear();
    } catch (_) {
      if (mounted) {
        final ar = Localizations.localeOf(context).languageCode == 'ar';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ar ? 'تعذر إرسال الرسالة.' : 'Could not send the message.')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _whatsappFallback() async {
    try {
      final settings = await AppSettingsRepository().getSettings();
      final phone = settings.whatsappNumber.isNotEmpty ? settings.whatsappNumber : settings.supportPhone;
      if (phone.isEmpty || !mounted) return;
      final ar = Localizations.localeOf(context).languageCode == 'ar';
      final ref = widget.ticketId.length >= 8 ? widget.ticketId.substring(0, 8) : widget.ticketId;
      final ticketId = widget.ticketId;
      try {
        await _repo.markSupportTicketWhatsAppEscalated(ticketId);
      } catch (_) {}
      if (!mounted) return;
      await VSPLauncherUtils.openWhatsApp(context, phone: phone, message: ar ? 'أحتاج تصعيد تذكرة دعم VSP رقم #$ref.' : 'I need to escalate VSP support ticket #$ref.');
    } catch (_) {}
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
        actions: [IconButton(tooltip: ar ? 'تصعيد عبر واتساب' : 'Escalate via WhatsApp', onPressed: _whatsappFallback, icon: const Icon(Iconsax.message_text_1_copy, color: VSPColors.accent))],
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: _repo.streamSupportTicket(widget.ticketId),
        builder: (context, ticketSnapshot) {
          final ticket = ticketSnapshot.data;
          final status = ticket?['status']?.toString().toLowerCase() ?? 'open';
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
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _repo.streamSupportTicketMessages(widget.ticketId),
                builder: (context, snapshot) {
                  final messages = snapshot.data ?? [];
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
                    itemCount: messages.length,
                    itemBuilder: (_, i) {
                      final m = messages[i];
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
                    IconButton(
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Iconsax.send_2_copy, color: VSPColors.accent),
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
