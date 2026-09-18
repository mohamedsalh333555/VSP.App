import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../core/models/copilot_message.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';

/// Sidebar Drawer displaying previous chat sessions for VSP Copilot.
class CopilotConversationsDrawer extends StatelessWidget {
  final List<CopilotConversation> conversations;
  final String? activeConversationId;
  final bool isLoading;
  final VoidCallback onNewChat;
  final ValueChanged<CopilotConversation> onSelectConversation;
  final ValueChanged<String> onDeleteConversation;

  const CopilotConversationsDrawer({
    super.key,
    required this.conversations,
    required this.activeConversationId,
    required this.isLoading,
    required this.onNewChat,
    required this.onSelectConversation,
    required this.onDeleteConversation,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: VSPColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            _buildDrawerHeader(context),
            const Divider(color: Colors.white12, height: 1),
            _buildNewChatButton(context),
            const Divider(color: Colors.white12, height: 1),
            Expanded(child: _buildConversationsList(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Icon(Iconsax.messages_2_copy, color: VSPColors.textPrimary, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'سجل المحادثات',
                  style: TextStyle(
                    color: VSPColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'جلسات VSP Copilot السابقة',
                  style: TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewChatButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop();
          onNewChat();
        },
        borderRadius: BorderRadius.circular(VSPRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(VSPRadius.md),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Iconsax.add_copy, color: VSPColors.textPrimary, size: 20),
              SizedBox(width: 8),
              Text(
                'محادثة جديدة',
                style: TextStyle(
                  color: VSPColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConversationsList(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: VSPColors.accent),
      );
    }

    if (conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.message_text_copy, size: 36, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 10),
            const Text(
              'لا توجد محادثات سابقة بعد',
              style: TextStyle(color: VSPColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      itemCount: conversations.length,
      itemBuilder: (context, index) {
        final conv = conversations[index];
        final isActive = conv.id == activeConversationId;

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Material(
            color: isActive
                ? VSPColors.accent.withValues(alpha: 0.14)
                : const Color(0xFF142019),
            borderRadius: BorderRadius.circular(VSPRadius.md),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(VSPRadius.md),
                side: BorderSide(
                  color: isActive
                      ? VSPColors.accent.withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.04),
                ),
              ),
              dense: true,
              leading: Icon(
                Iconsax.message_copy,
                size: 16,
                color: isActive ? VSPColors.accent : Colors.white54,
              ),
              title: Text(
                conv.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isActive ? Colors.white : VSPColors.textPrimary,
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Iconsax.trash_copy, size: 16, color: Colors.white38),
                onPressed: () => onDeleteConversation(conv.id),
              ),
              onTap: () {
                Navigator.of(context).pop();
                onSelectConversation(conv);
              },
            ),
          ),
        );
      },
    );
  }
}
