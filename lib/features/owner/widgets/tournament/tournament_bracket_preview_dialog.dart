import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/primary_button.dart';

/// Shows the interactive visual bracket preview dialog.
void showTournamentBracketPreviewDialog(
  BuildContext context, {
  required List<Team> teams,
  required VoidCallback onStartDraw,
}) {
  final int totalTeams = teams.length;
  if (totalTeams < 2) return;

  int targetP2 = 1;
  while (targetP2 * 2 <= totalTeams) {
    targetP2 *= 2;
  }
  final int totalBracketRounds = (log(targetP2) / log(2)).round();
  final int numOpeningMatches = totalTeams - targetP2;
  final int numTeamsR0 = numOpeningMatches * 2;

  final List<List<Map<String, String>>> rounds = [];
  final previewTeams = List<Team>.from(teams);

  if (numOpeningMatches > 0) {
    final List<Map<String, String>> r0 = [];
    for (int m = 0; m < numOpeningMatches; m++) {
      final String homeName = previewTeams[m * 2].name;
      final String awayName = previewTeams[m * 2 + 1].name;
      r0.add({'home': homeName, 'away': awayName});
    }
    rounds.add(r0);
  }

  final List<Map<String, String>> r1 = [];
  final int matchCountR1 = targetP2 ~/ 2;
  for (int m = 0; m < matchCountR1; m++) {
    String homeName = '';
    String awayName = '';

    final int slotH = m * 2;
    if (slotH < numOpeningMatches) {
      homeName = 'فائز مـ ${slotH + 1} (R0)';
    } else {
      final int byeIndex = slotH - numOpeningMatches + numTeamsR0;
      if (byeIndex < totalTeams) {
        homeName = previewTeams[byeIndex].name;
      } else {
        homeName = 'BYE';
      }
    }

    final int slotA = m * 2 + 1;
    if (slotA < numOpeningMatches) {
      awayName = 'فائز مـ ${slotA + 1} (R0)';
    } else {
      final int byeIndex = slotA - numOpeningMatches + numTeamsR0;
      if (byeIndex < totalTeams) {
        awayName = previewTeams[byeIndex].name;
      } else {
        awayName = 'BYE';
      }
    }

    r1.add({'home': homeName, 'away': awayName});
  }
  rounds.add(r1);

  for (int r = 2; r <= totalBracketRounds; r++) {
    final List<Map<String, String>> rx = [];
    final int matchCount = targetP2 ~/ pow(2, r);
    for (int m = 0; m < matchCount; m++) {
      rx.add({
        'home': 'فائز مـ ${m * 2 + 1}',
        'away': 'فائز مـ ${m * 2 + 2}',
      });
    }
    rounds.add(rx);
  }

  showDialog(
    context: context,
    builder: (ctx) {
      final l10n = AppLocalizations.of(context)!;
      return AlertDialog(
        backgroundColor: VSPColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
        insetPadding: const EdgeInsets.all(16),
        title: Text(
          l10n.tournamentBrackets,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.65,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(VSPRadius.md),
            child: InteractiveViewer(
              transformationController: TransformationController(
                Matrix4.identity()..translate(0.0, 0.0),
              ),
              constrained: false,
              scaleEnabled: true,
              minScale: 0.5,
              maxScale: 2.0,
              child: Builder(
                builder: (context) {
                  final int maxOpeningMatches = rounds.first.length;
                  final double totalBracketHeight = (maxOpeningMatches * 84.0).clamp(450.0, 1600.0);

                  return Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...rounds.asMap().entries.map((entry) {
                          final int roundIdx = entry.key;
                          final List<Map<String, String>> roundMatches = entry.value;
                          final int matchCount = roundMatches.length;
                          final double slotHeight = totalBracketHeight / matchCount;

                          final Widget roundColumn = SizedBox(
                            width: 165,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  height: 32,
                                  alignment: Alignment.center,
                                  child: Text(
                                    roundIdx == 0 && numOpeningMatches > 0
                                        ? 'جولة تمهيدية'
                                        : (roundIdx == rounds.length - 1
                                            ? 'النهائي'
                                            : 'جولة ${numOpeningMatches > 0 ? roundIdx : roundIdx + 1}'),
                                    style: const TextStyle(
                                      color: VSPColors.accent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: totalBracketHeight,
                                  child: Column(
                                    children: roundMatches.map((m) {
                                      return SizedBox(
                                        height: slotHeight,
                                        child: Center(
                                          child: Container(
                                            width: 155,
                                            margin: const EdgeInsets.symmetric(horizontal: 4),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: VSPColors.surfaceAlt,
                                              borderRadius: BorderRadius.circular(VSPRadius.md),
                                              border: Border.all(color: VSPColors.divider, width: 1),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.3),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                )
                                              ],
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  m['home']!,
                                                  style: const TextStyle(
                                                      fontSize: 11.5,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const Divider(height: 8, color: Colors.white12),
                                                Text(
                                                  m['away']!,
                                                  style: const TextStyle(
                                                      fontSize: 11.5,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          );

                          return Row(
                            children: [
                              roundColumn,
                              SizedBox(
                                height: totalBracketHeight + 32,
                                child: const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 2),
                                    child: Icon(Iconsax.arrow_right_1_copy, color: VSPColors.accent, size: 16),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),

                        // Champion Card Column
                        SizedBox(
                          width: 155,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 32),
                              SizedBox(
                                height: totalBracketHeight,
                                child: Center(
                                  child: Container(
                                    width: 145,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: VSPColors.accent.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(VSPRadius.lg),
                                      border: Border.all(color: VSPColors.accent, width: 1.5),
                                      boxShadow: [
                                        BoxShadow(
                                          color: VSPColors.accent.withValues(alpha: 0.2),
                                          blurRadius: 10,
                                          spreadRadius: 1,
                                        )
                                      ],
                                    ),
                                    child: const Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Iconsax.cup_copy, color: VSPColors.accent, size: 36),
                                        SizedBox(height: 8),
                                        Text(
                                          'البطل',
                                          style: TextStyle(
                                              fontSize: 14, fontWeight: FontWeight.bold, color: VSPColors.accent),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'الفائز بالنهائي',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontSize: 10, color: Colors.white70),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.md),
        actions: [
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  text: l10n.cancel,
                  height: 44,
                  color: VSPColors.surfaceAlt,
                  textColor: VSPColors.textPrimary,
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                  text: l10n.generateDrawStart.split(' ').first,
                  height: 44,
                  onPressed: () {
                    Navigator.pop(ctx);
                    onStartDraw();
                  },
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}

/// Shows the interactive randomized live draw room modal dialog.
Future<void> showInteractiveDrawRoomDialog(
  BuildContext context, {
  required List<Team> teams,
  required VoidCallback onConfirmDraw,
}) async {
  final isAr = Localizations.localeOf(context).languageCode == 'ar';
  final shuffledTeams = List<Team>.from(teams)..shuffle(Random());

  final List<Map<String, String>> matchups = [];
  for (int i = 0; i < shuffledTeams.length; i += 2) {
    if (i + 1 < shuffledTeams.length) {
      matchups.add({
        'home': shuffledTeams[i].name,
        'away': shuffledTeams[i + 1].name,
      });
    } else {
      matchups.add({
        'home': shuffledTeams[i].name,
        'away': isAr ? 'BYE (تأهل تلقائي)' : 'BYE (Auto Qualify)',
      });
    }
  }

  int revealedCount = 0;
  bool isRevealing = false;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (ctx, setModalState) {
        return AlertDialog(
          backgroundColor: VSPColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.xl)),
          title: Row(
            children: [
              const Icon(Iconsax.cup_copy, color: VSPColors.accent, size: 24),
              const SizedBox(width: 10),
              Text(
                isAr ? 'غرفة سحب القرعة المباشر' : 'Live Draw Room',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            height: 340,
            child: Column(
              children: [
                Text(
                  isAr
                      ? 'سحب موجه ومؤمن عشوائياً بدون أي تدخل بشري لضمان النزاهة التامة'
                      : 'Fair automated live draw for all participating teams',
                  style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: matchups.length,
                    itemBuilder: (c, idx) {
                      final isRevealed = idx < revealedCount;
                      final m = matchups[idx];

                      return AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: isRevealed ? 1.0 : 0.2,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isRevealed ? VSPColors.accent.withValues(alpha: 0.12) : VSPColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(VSPRadius.md),
                            border: Border.all(
                              color: isRevealed ? VSPColors.accent : VSPColors.divider,
                              width: isRevealed ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  isRevealed ? m['home']! : (isAr ? 'قيد السحب...' : 'Pending draw...'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isRevealed ? Colors.white : VSPColors.textSecondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Text('VS',
                                    style: TextStyle(
                                        color: VSPColors.accent, fontWeight: FontWeight.w900, fontSize: 12)),
                              ),
                              Expanded(
                                child: Text(
                                  isRevealed ? m['away']! : (isAr ? 'قيد السحب...' : 'Pending draw...'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isRevealed ? Colors.white : VSPColors.textSecondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (!isRevealing && revealedCount < matchups.length)
              PrimaryButton(
                text: isAr ? 'بدء السحب الكاشف' : 'Start Live Reveal',
                height: 44,
                onPressed: () async {
                  setModalState(() => isRevealing = true);
                  for (int i = 0; i < matchups.length; i++) {
                    await Future.delayed(const Duration(milliseconds: 450));
                    HapticFeedback.mediumImpact();
                    setModalState(() {
                      revealedCount = i + 1;
                    });
                  }
                  setModalState(() => isRevealing = false);
                },
              )
            else if (revealedCount >= matchups.length)
              PrimaryButton(
                text: isAr ? 'اعتماد القرعة وبدء البطولة' : 'Confirm Draw & Start',
                height: 44,
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  onConfirmDraw();
                },
              ),
          ],
        );
      },
    ),
  );
}
