import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../owner/screens/tournament_brackets_screen.dart';
import 'championship_standings_table.dart';

/// تبويب جدول الترتيب ومباريات البطولة المجدولة
class ChampionshipMatchesTab extends StatelessWidget {
  final Championship championship;
  final Stream<List<TournamentMatch>> matchesStream;

  const ChampionshipMatchesTab({
    super.key,
    required this.championship,
    required this.matchesStream,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(VSPSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Live Standings Table (For League & Group Systems)
          ChampionshipStandingsSection(championship: championship),

          // Brackets Button
          PrimaryButton(
            text: isArabic ? 'عرض شجرة القرعة والمواجهات' : 'View Tournament Brackets',
            height: 48,
            color: VSPColors.accent,
            textColor: Colors.black,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TournamentBracketsScreen(
                    championship: championship,
                    isOwner: false,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: VSPSpacing.lg),

          // Live Match Fixtures Stream
          StreamBuilder<List<TournamentMatch>>(
            stream: matchesStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        VSPColors.surface,
                        VSPColors.accent.withValues(alpha: 0.04),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(VSPRadius.xl),
                    border: Border.all(
                      color: VSPColors.accent.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: VSPColors.accent.withValues(alpha: 0.1),
                          border: Border.all(
                            color: VSPColors.accent.withValues(alpha: 0.25),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Iconsax.calendar_1_copy,
                          color: VSPColors.accent,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        isArabic ? 'لم يتم إعداد المباريات بعد' : 'No Matches Scheduled Yet',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isArabic
                            ? 'سيتم الإعلان عن جدول المباريات بمجرد اكتمال التسجيل'
                            : 'Match schedule will be announced once registration is complete',
                        style: const TextStyle(
                          color: VSPColors.textSecondary,
                          fontSize: 12,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              final matches = snapshot.data!;

              String roundLabelAr(int roundIndex) {
                if (championship.type == 'GroupsAndKnockout' && roundIndex == 99) {
                  return 'دور المجموعات';
                }
                if (championship.type == 'League') {
                  return 'مباريات الدوري';
                }
                switch (roundIndex) {
                  case 0:
                    return 'المباراة النهائية';
                  case 1:
                    return 'نصف النهائي';
                  case 2:
                    return 'ربع النهائي';
                  case 3:
                    return 'دور الـ 16';
                  case 4:
                    return 'دور الـ 32';
                  case 5:
                    return 'دور الـ 64';
                  default:
                    return 'الجولة ${roundIndex + 1}';
                }
              }

              // Group matches by roundIndex (highest roundIndex = earliest round)
              final rounds = <int>{};
              for (final m in matches) {
                rounds.add(m.roundIndex);
              }
              final sortedRounds = rounds.toList()..sort((a, b) => b.compareTo(a));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic ? 'المباريات والمواجهات' : 'Match Fixtures',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                  const SizedBox(height: VSPSpacing.md),
                  ...sortedRounds.map((roundIdx) {
                    final roundMatches = matches.where((m) => m.roundIndex == roundIdx).toList()
                      ..sort((a, b) => a.matchIndex.compareTo(b.matchIndex));
                    final roundLabel = isArabic ? roundLabelAr(roundIdx) : roundMatches.first.roundLabel;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Round Header
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: VSPColors.accent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  roundLabel,
                                  style: const TextStyle(
                                    color: VSPColors.accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Divider(color: VSPColors.divider.withValues(alpha: 0.4), height: 1),
                              ),
                            ],
                          ),
                        ),
                        // Matches in this round
                        ...roundMatches.map((m) {
                          final homeName = m.homeTeamName ?? '';
                          final awayName = m.awayTeamName ?? '';
                          final matchNum = m.matchIndex + 1;

                          // Format scheduled time
                          String? scheduledLabel;
                          if (m.scheduledTime != null) {
                            final t = m.scheduledTime!;
                            scheduledLabel =
                                '${t.day}/${t.month} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: VSPSpacing.sm),
                            decoration: BoxDecoration(
                              color: VSPColors.surface,
                              borderRadius: BorderRadius.circular(VSPRadius.md),
                              border: Border.all(
                                color: m.isCompleted
                                    ? VSPColors.accent.withValues(alpha: 0.3)
                                    : VSPColors.divider.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Column(
                              children: [
                                // Match meta: match number + date
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: 6),
                                  decoration: const BoxDecoration(
                                    color: VSPColors.surfaceAlt,
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(VSPRadius.md),
                                      topRight: Radius.circular(VSPRadius.md),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        isArabic ? 'مباراة $matchNum' : 'Match $matchNum',
                                        style: const TextStyle(
                                          color: VSPColors.textSecondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (scheduledLabel != null)
                                        Row(
                                          children: [
                                            const Icon(Iconsax.calendar_1_copy,
                                                size: 11, color: VSPColors.textSecondary),
                                            const SizedBox(width: 4),
                                            Text(
                                              scheduledLabel,
                                              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                                            ),
                                          ],
                                        )
                                      else
                                        Text(
                                          isArabic ? 'لم يحدد التاريخ' : 'TBD',
                                          style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                                        ),
                                    ],
                                  ),
                                ),
                                // Teams + Score/VS
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: 12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          homeName.isNotEmpty ? homeName : (isArabic ? 'فريق 1' : 'Team 1'),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: m.isCompleted
                                              ? VSPColors.accent.withValues(alpha: 0.15)
                                              : VSPColors.background,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          m.isCompleted ? '${m.homeScore} - ${m.awayScore}' : 'VS',
                                          style: TextStyle(
                                            color: m.isCompleted ? VSPColors.accent : VSPColors.textSecondary,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          awayName.isNotEmpty ? awayName : (isArabic ? 'فريق 2' : 'Team 2'),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 4),
                      ],
                    );
                  }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
