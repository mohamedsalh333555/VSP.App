import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/primary_button.dart';
import 'bracket_preview_canvas.dart';
import 'draw_room_matchup_tile.dart';
import 'tournament_bracket_builder.dart';

export 'tournament_bracket_builder.dart' show TournamentBracketBuilder;

/// Shows the interactive visual bracket preview dialog.
void showTournamentBracketPreviewDialog(
  BuildContext context, {
  required List<Team> teams,
  required VoidCallback onStartDraw,
}) {
  final rounds = TournamentBracketBuilder.buildRounds(teams);
  if (rounds.isEmpty) return;

  final int numOpeningMatches = (() {
    int p = 1;
    while (p * 2 <= teams.length) {
      p *= 2;
    }
    return teams.length - p;
  })();

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
              child: BracketPreviewCanvas(
                rounds: rounds,
                numOpeningMatches: numOpeningMatches,
              ),
            ),
          ),
        ),
        actionsPadding:
            const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.md),
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
      matchups.add({'home': shuffledTeams[i].name, 'away': shuffledTeams[i + 1].name});
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.xl)),
          title: Row(
            children: [
              const Icon(Iconsax.cup_copy, color: VSPColors.accent, size: 24),
              const SizedBox(width: 10),
              Text(
                isAr ? 'غرفة سحب القرعة المباشر' : 'Live Draw Room',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
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
                  style:
                      const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: matchups.length,
                    itemBuilder: (c, idx) => DrawRoomMatchupTile(
                      matchup: matchups[idx],
                      isRevealed: idx < revealedCount,
                      isArabic: isAr,
                    ),
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
                    setModalState(() => revealedCount = i + 1);
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
