import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/copilot_message.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';

/// Chat bubble rendering user and assistant messages, actions, and pitch recommendation cards.
class CopilotChatBubble extends StatelessWidget {
  final CopilotMessage message;
  final bool isArabic;
  final ValueChanged<CopilotStadiumSummary>? onBookStadium;
  final ValueChanged<CopilotAction>? onExecuteAction;
  final ValueChanged<CopilotTournamentSummary>? onSelectTournament;
  final ValueChanged<CopilotOpenMatchSummary>? onJoinMatch;

  const CopilotChatBubble({
    super.key,
    required this.message,
    this.isArabic = true,
    this.onBookStadium,
    this.onExecuteAction,
    this.onSelectTournament,
    this.onJoinMatch,
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
          if (message.hasAction) ...[
            const SizedBox(height: 8),
            _buildActionCard(context, message.action!),
          ],
          if (message.hasStadiums) ...[
            const SizedBox(height: 12),
            _buildStadiumsCarousel(context, message.stadiumResults),
          ],
          if (message.hasTournaments) ...[
            const SizedBox(height: 12),
            _buildTournamentsCarousel(context, message.tournamentResults),
          ],
          if (message.hasOpenMatches) ...[
            const SizedBox(height: 12),
            _buildOpenMatchesCarousel(context, message.openMatchResults),
          ],
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, CopilotAction action) {
    final isProfileUpdated = action.actionType == 'PROFILE_UPDATED';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onExecuteAction != null ? () => onExecuteAction!(action) : null,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isProfileUpdated
                  ? const [Color(0xFF143B22), Color(0xFF0D2516)]
                  : const [Color(0xFF1B3828), Color(0xFF14241B)],
            ),
            borderRadius: BorderRadius.circular(VSPRadius.md),
            border: Border.all(
              color: isProfileUpdated ? const Color(0xFF00E676) : VSPColors.accent,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: (isProfileUpdated ? const Color(0xFF00E676) : VSPColors.accent).withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isProfileUpdated ? Icons.check_circle_rounded : Icons.rocket_launch_rounded,
                color: isProfileUpdated ? const Color(0xFF00E676) : VSPColors.accent,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                action.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: isProfileUpdated ? const Color(0xFF00E676) : VSPColors.accent,
                size: 12,
              ),
            ],
          ),
        ),
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
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(VSPRadius.md),
              onTap: onBookStadium != null ? () => onBookStadium!(s) : null,
              child: Container(
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
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTournamentsCarousel(BuildContext context, List<CopilotTournamentSummary> tournaments) {
    return SizedBox(
      height: 125,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tournaments.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final t = tournaments[i];
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(VSPRadius.md),
              onTap: onSelectTournament != null ? () => onSelectTournament!(t) : null,
              child: Container(
                width: 240,
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
                        const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            t.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${isArabic ? "جائزة:" : "Prize:"} ${t.grandPrize.toInt()} ${isArabic ? "ج.م" : "EGP"}',
                      style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            t.entryFee > 0 ? '${isArabic ? "اشتراك:" : "Fee:"} ${t.entryFee.toInt()} ج.م' : (isArabic ? 'مجاني' : 'Free'),
                            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (onSelectTournament != null)
                          ElevatedButton(
                            onPressed: () => onSelectTournament!(t),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: VSPColors.accent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: const Size(54, 26),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            child: Text(
                              isArabic ? 'عرض' : 'View',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
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

  Widget _buildOpenMatchesCarousel(BuildContext context, List<CopilotOpenMatchSummary> matches) {
    return SizedBox(
      height: 125,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: matches.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final m = matches[i];
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(VSPRadius.md),
              onTap: onJoinMatch != null ? () => onJoinMatch!(m) : null,
              child: Container(
                width: 240,
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
                        const Icon(Icons.sports_soccer_rounded, color: VSPColors.accent, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            m.stadiumName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isArabic ? 'ناقص ${m.missingPlayers} لاعبين' : '${m.missingPlayers} spots left',
                        style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            m.notes.isNotEmpty ? m.notes : (isArabic ? 'تقسيمة خماسي' : 'Open Match'),
                            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 10),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (onJoinMatch != null)
                          ElevatedButton(
                            onPressed: () => onJoinMatch!(m),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: VSPColors.accent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: const Size(54, 26),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            child: Text(
                              isArabic ? 'انضم' : 'Join',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
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
