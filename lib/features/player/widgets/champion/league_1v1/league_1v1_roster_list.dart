import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../../core/ui/tokens/vsp_tokens.dart';

/// List of players currently registered and confirmed in the 1v1 tournament roster.
class League1v1RosterList extends StatelessWidget {
  final int registeredCount;
  final List<Map<String, dynamic>> players;
  final String? currentUserId;
  final bool isArabic;

  const League1v1RosterList({
    super.key,
    required this.registeredCount,
    required this.players,
    required this.currentUserId,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Roster Table Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArabic ? 'جدول المسجلين بالبطولة' : 'Registered Roster',
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: VSPColors.surface,
                  borderRadius: BorderRadius.circular(VSPRadius.full),
                  border: Border.all(color: VSPColors.divider, width: 0.5),
                ),
                child: Text(
                  '$registeredCount ${isArabic ? "لاعبين" : "players"}',
                  style: const TextStyle(color: VSPColors.accent, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Registered Players List or Empty placeholder
        if (players.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                isArabic
                    ? 'كن أول من يسجل ويسدد للاشتراك في هذه البطولة!'
                    : 'Be the first to register and join this tournament!',
                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: players.length,
            itemBuilder: (ctx, idx) {
              final p = players[idx];
              final pName = p['player_name'] ?? 'لاعب';
              final pAvatar = p['avatar_url'] as String? ?? '';
              final isMe = currentUserId != null && p['user_id'] == currentUserId;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe ? const Color(0xFF1B2A16) : VSPColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isMe ? VSPColors.accent : VSPColors.divider.withValues(alpha: 0.3),
                    width: isMe ? 1.5 : 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        '#${idx + 1}',
                        style: TextStyle(
                          color: isMe ? VSPColors.accent : VSPColors.textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: VSPColors.surfaceAlt,
                        border: Border.all(color: isMe ? VSPColors.accent : VSPColors.divider, width: 1),
                      ),
                      child: ClipOval(
                        child: pAvatar.isNotEmpty
                            ? CachedNetworkImage(imageUrl: pAvatar, fit: BoxFit.cover)
                            : Center(
                                child: Text(
                                  pName.isNotEmpty ? pName[0].toUpperCase() : 'P',
                                  style: TextStyle(
                                    color: isMe ? VSPColors.accent : Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        pName + (isMe ? (isArabic ? ' (أنت)' : ' (You)') : ''),
                        style: TextStyle(
                          color: isMe ? VSPColors.accent : Colors.white,
                          fontWeight: isMe ? FontWeight.w900 : FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF142E18),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.3), width: 0.5),
                      ),
                      child: Text(
                        isArabic ? 'مسجل ومسدد' : 'Paid & Confirmed',
                        style: const TextStyle(
                          color: Color(0xFF86EFAC),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
