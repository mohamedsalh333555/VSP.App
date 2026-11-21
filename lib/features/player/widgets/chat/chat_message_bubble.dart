import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/chat_model.dart';
import '../../../../core/repositories/chat_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';

class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final Booking? booking;
  final bool isHost;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.booking,
    this.isHost = false,
  });

  void _showEditDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      useSafeArea: true,
      barrierDismissible: false,
      builder: (_) => _MessageEditDialog(message: message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final host = isHost || (booking != null && message.senderId == booking!.createdByUserId);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Semantics(
      customSemanticsActions: isMe
          ? <CustomSemanticsAction, VoidCallback>{
              CustomSemanticsAction(
                label: isArabic ? 'تعديل الرسالة' : 'Edit message',
              ): () => _showEditDialog(context),
            }
          : const <CustomSemanticsAction, VoidCallback>{},
      child: GestureDetector(
        onLongPress: isMe ? () => _showEditDialog(context) : null,
        child: Align(
        alignment: isMe ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isMe ? VSPColors.accent : VSPColors.surface,
            borderRadius: BorderRadiusDirectional.only(
              topStart: const Radius.circular(16),
              topEnd: const Radius.circular(16),
              bottomStart: Radius.circular(isMe ? 16 : 4),
              bottomEnd: Radius.circular(isMe ? 4 : 16),
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
                    Flexible(
                      child: Text(
                        message.senderName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                        color: VSPColors.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ),
                    if (host) ...[
                      const SizedBox(width: 4),
                      Text(
                        isArabic ? '[المُضيف ]' : '[HOST ]',
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.isEdited) ...[
                    Text(
                      isArabic ? '(مُعدلة) ' : '(edited) ',
                      style: TextStyle(
                        color: (isMe ? VSPColors.background : VSPColors.textSecondary).withValues(alpha: 0.65),
                        fontSize: 9,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  Text(
                    DateFormat.jm(Localizations.localeOf(context).toString()).format(message.timestamp),
                    style: TextStyle(
                      color: (isMe ? VSPColors.background : VSPColors.textSecondary).withValues(alpha: 0.6),
                      fontSize: 10,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      message.isRead ? Iconsax.tick_circle_copy : Iconsax.tick_circle_copy,
                      size: 14,
                      color: message.isRead ? Colors.blueAccent : VSPColors.background.withValues(alpha: 0.65),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _MessageEditDialog extends StatefulWidget {
  final ChatMessage message;
  const _MessageEditDialog({required this.message});
  @override
  State<_MessageEditDialog> createState() => _MessageEditDialogState();
}

class _MessageEditDialogState extends State<_MessageEditDialog> {
  late final TextEditingController _controller;
  bool _saving = false;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.message.text);
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  Future<void> _save() async {
    if (_saving) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (text == widget.message.text) { Navigator.pop(context); return; }
    setState(() { _saving = true; _failed = false; });
    try {
      await ChatRepository().editMessage(widget.message.id, text);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        scrollable: true,
        backgroundColor: VSPColors.surface,
        title: Text(isArabic ? 'تعديل الرسالة' : 'Edit message'),
        content: TextField(
          controller: _controller,
          enabled: !_saving,
          minLines: 3, maxLines: 6,
          style: const TextStyle(color: VSPColors.textPrimary),
          decoration: InputDecoration(
            hintText: isArabic ? 'اكتب الرسالة الجديدة...' : 'Enter the new message...',
            errorMaxLines: 3,
            errorText: _failed ? (isArabic ? 'تعذر حفظ الرسالة. حاول مرة أخرى.' : 'Could not save the message. Try again.') : null,
          ),
        ),
        actions: [
          TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: Text(isArabic ? 'إلغاء' : 'Cancel')),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, _) => TextButton(
              onPressed: _saving || value.text.trim().isEmpty ? null : _save,
              child: Text(_saving ? (isArabic ? 'جارٍ الحفظ...' : 'Saving...') : (isArabic ? 'حفظ التعديل' : 'Save')),
            ),
          ),
        ],
      ),
    );
  }
}
