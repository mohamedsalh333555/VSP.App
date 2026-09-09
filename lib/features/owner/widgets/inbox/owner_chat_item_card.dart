import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/components/vsp_card.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

/// Card widget representing a single conversation row in the Owner Inbox.
class OwnerChatItemCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String timeStr;
  final String? avatar;
  final bool hasUnread;
  final int unreadCount;
  final VoidCallback onTap;

  const OwnerChatItemCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.timeStr,
    required this.avatar,
    required this.hasUnread,
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: VSPSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        child: VSPCard(
          padding: const EdgeInsets.all(16),
          border: hasUnread ? Border.all(color: VSPColors.accent, width: 1.5) : null,
          color: hasUnread ? VSPColors.accent.withValues(alpha: 0.05) : VSPColors.surface,
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: VSPColors.surfaceAlt,
                backgroundImage: avatar != null ? NetworkImage(avatar!) : null,
                child: avatar == null
                    ? const Icon(Iconsax.user_copy, color: VSPColors.accent)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeStr,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: VSPColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: VSPColors.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasUnread) ...[
                const SizedBox(width: 12),
                CircleAvatar(
                  radius: 10,
                  backgroundColor: VSPColors.accent,
                  child: Text(
                    unreadCount > 0 ? '$unreadCount' : '',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
