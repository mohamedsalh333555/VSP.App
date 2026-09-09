import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/copilot_message.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';

/// Chat bubble rendering user and assistant messages, actions, and pitch recommendation cards.
class CopilotChatBubble extends StatelessWidget {
  final CopilotMessage message;
  final bool isArabic;
  final ValueChanged<CopilotStadiumSummary>? onBookStadium;

  const CopilotChatBubble({
    super.key,
    required this.message,
    this.isArabic = true,
    this.onBookStadium,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
            decoration: BoxDecoration(
              color: isUser ? VSPColors.accent : const Color(0xFF1C2B22),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isUser ? 16 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 16),
              ),
              border: Border.all(
                color: isUser ? Colors.transparent : VSPColors.accent.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.text,
                  style: TextStyle(
                    color: isUser ? Colors.black : VSPColors.textPrimary,
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: isUser ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                if (!isUser) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: message.text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isArabic ? 'تم نسخ الرد' : 'Response copied'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy_rounded, size: 12, color: Colors.white54),
                          SizedBox(width: 4),
                          Text('نسخ', style: TextStyle(color: Colors.white54, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (message.hasStadiums) ...[
            const SizedBox(height: 12),
            _buildStadiumsCarousel(context, message.stadiumResults),
          ],
        ],
      ),
    );
  }

  Widget _buildStadiumsCarousel(BuildContext context, List<CopilotStadiumSummary> stadiums) {
    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: stadiums.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final s = stadiums[i];
          return Container(
            width: 230,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF142019),
              borderRadius: BorderRadius.circular(VSPRadius.md),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (s.rating > 0) ...[
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                      const SizedBox(width: 2),
                      Text(
                        s.rating.toStringAsFixed(1),
                        style: const TextStyle(color: Colors.amber, fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ],
                ),
                Text(
                  s.governorate.isNotEmpty ? s.governorate : (isArabic ? 'مصر' : 'Egypt'),
                  style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${s.pricePerHour.toInt()} ${isArabic ? "ج.م/ساعة" : "EGP/hr"}',
                        style: const TextStyle(
                          color: VSPColors.accent,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (onBookStadium != null)
                      ElevatedButton(
                        onPressed: () => onBookStadium!(s),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VSPColors.accent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: const Size(54, 26),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: Text(
                          isArabic ? 'احجز' : 'Book',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Loading indicator bubble shown while waiting for LLM response
class CopilotLoadingBubble extends StatelessWidget {
  const CopilotLoadingBubble({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1C2B22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: VSPColors.accent.withValues(alpha: 0.15)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: VSPColors.accent),
            ),
            SizedBox(width: 12),
            Text(
              'كابتن VSP يفكر ويبحث...',
              style: TextStyle(color: VSPColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
