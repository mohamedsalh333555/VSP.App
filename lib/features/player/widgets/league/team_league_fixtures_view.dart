import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import '../../../../core/repositories/league/team_league_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

class TeamLeagueFixturesView extends StatelessWidget {
  final List<TeamLeagueMatch> matches;
  final String userTeamId;
  final Function(TeamLeagueMatch match) onBookMatch;
  final Function(TeamLeagueMatch match) onRecordScore;

  const TeamLeagueFixturesView({
    super.key,
    required this.matches,
    required this.userTeamId,
    required this.onBookMatch,
    required this.onRecordScore,
  });

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(VSPSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Iconsax.calendar_copy, size: 60, color: VSPColors.textSecondary.withValues(alpha: 0.3)),
              const SizedBox(height: 12),
              const Text(
                'سيتم توليد جدول المباريات فور اكتمال الـ 4 فرق',
                textAlign: TextAlign.center,
                style: TextStyle(color: VSPColors.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    // Group matches by week / stage
    final regularMatches = matches.where((m) => m.stage == 'league').toList();
    final playoffMatches = matches.where((m) => m.stage == 'playoff').toList();

    final Map<int, List<TeamLeagueMatch>> weekMap = {};
    for (final m in regularMatches) {
      weekMap.putIfAbsent(m.weekNumber, () => []).add(m);
    }

    final sortedWeeks = weekMap.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        if (playoffMatches.isNotEmpty) ...[
          _buildStageHeader('🔥 المباراة الفاصلة لتحديد بطل الدوري'),
          ...playoffMatches.map((m) => _buildMatchCard(context, m, isPlayoff: true)),
          const SizedBox(height: VSPSpacing.lg),
        ],

        ...sortedWeeks.map((week) {
          final weekMatches = weekMap[week] ?? [];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStageHeader('📅 الجولة $week - الأسبوع $week'),
              ...weekMatches.map((m) => _buildMatchCard(context, m)),
              const SizedBox(height: VSPSpacing.md),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildStageHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: VSPColors.accent,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildMatchCard(BuildContext context, TeamLeagueMatch match, {bool isPlayoff = false}) {
    final isUserMatch = match.homeTeamId == userTeamId || match.awayTeamId == userTeamId;
    final isCompleted = match.isCompleted;
    final hasBooking = match.bookingId != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(
          color: isPlayoff
              ? Colors.amber
              : isUserMatch
                  ? VSPColors.accent.withValues(alpha: 0.5)
                  : VSPColors.borderLight,
          width: isUserMatch || isPlayoff ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(VSPSpacing.md),
        child: Column(
          children: [
            // Status bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (isCompleted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: VSPColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'انتهت',
                      style: TextStyle(color: VSPColors.accent, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  )
                else if (hasBooking)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Iconsax.tick_circle_copy, size: 12, color: Colors.green),
                        SizedBox(width: 4),
                        Text(
                          'تم الحجز',
                          style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: VSPColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'في انتظار حجز الملعب',
                      style: TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                    ),
                  ),

                if (isUserMatch)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: VSPColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'مباراة فريقك ⭐',
                      style: TextStyle(color: VSPColors.accent, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Teams & Score
            Row(
              children: [
                // Home Team
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        match.homeTeamName,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: match.homeTeamId == userTeamId ? VSPColors.accent : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (isCompleted && match.winnerId == match.homeTeamId)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Icon(Iconsax.medal_star_copy, color: Colors.amber, size: 16),
                        ),
                    ],
                  ),
                ),

                // Score or VS
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: isCompleted
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: VSPColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            '${match.homeScore ?? 0} - ${match.awayScore ?? 0}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: VSPColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'VS',
                            style: TextStyle(
                              color: VSPColors.accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                ),

                // Away Team
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        match.awayTeamName,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: match.awayTeamId == userTeamId ? VSPColors.accent : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (isCompleted && match.winnerId == match.awayTeamId)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Icon(Iconsax.medal_star_copy, color: Colors.amber, size: 16),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            // Booking Details if scheduled
            if (hasBooking) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: VSPColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Iconsax.location_copy, size: 14, color: VSPColors.accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        match.stadiumName ?? 'الملعب المحدد',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (match.scheduledTime != null) ...[
                      const Icon(Iconsax.clock_copy, size: 14, color: VSPColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('d MMMM - h:mm a', 'ar').format(match.scheduledTime!),
                        style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Action Buttons
            if (!isCompleted) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (!hasBooking && isUserMatch)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => onBookMatch(match),
                        icon: const Icon(Iconsax.calendar_add_copy, size: 16),
                        label: const Text(
                          'حجز موعد المباراة',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VSPColors.accent,
                          foregroundColor: VSPColors.background,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  if (!hasBooking && isUserMatch) const SizedBox(width: 8),

                  // Record score button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => onRecordScore(match),
                      icon: const Icon(Iconsax.edit_2_copy, size: 14),
                      label: const Text(
                        'تسجيل النتيجة',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: VSPColors.accent,
                        side: const BorderSide(color: VSPColors.accent),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
