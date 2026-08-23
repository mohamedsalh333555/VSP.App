import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/ui/components/vsp_card.dart';
import '../../../core/utils/app_error_handler.dart';
import '../../../core/repositories/tournament_repository.dart';
import '../../../core/repositories/team_repository.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../data/models.dart';
import 'tournament_brackets_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/sharing_service.dart';
import '../../../core/utils/app_date_formatter.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../shared/widgets/custom_text_field.dart';

class OwnerTournamentDashboardScreen extends StatefulWidget {
  final Championship championship;

  const OwnerTournamentDashboardScreen({super.key, required this.championship});

  @override
  State<OwnerTournamentDashboardScreen> createState() => _OwnerTournamentDashboardScreenState();
}

class _OwnerTournamentDashboardScreenState extends State<OwnerTournamentDashboardScreen> {
  late Championship _currentChampionship;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentChampionship = widget.championship;
  }

  Future<void> _handleStartTournament() async {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    if (_currentChampionship.joinedTeams.isEmpty) {
      VSPFeedback.showError(
        context,
        isAr ? 'لا توجد فرق مشاركة بعد! أضف فريقاً يدوياً أو انتظر انضمام الفرق.' : 'No teams joined yet!',
      );
      return;
    }

    if (_currentChampionship.joinedTeams.length < 2) {
      VSPFeedback.showError(
        context,
        isAr ? 'يجب وجود فريقين على الأقل لبدء البطولة والقرعة!' : 'At least 2 teams required to start!',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final teams = await TournamentRepository().getTeamsByIds(_currentChampionship.joinedTeams);
      setState(() => _isLoading = false);
      if (!mounted) return;

      final unpaidTeams = teams.where((t) => !_currentChampionship.paidTeams.contains(t.id)).toList();
      if (unpaidTeams.isNotEmpty) {
        final unpaidNames = unpaidTeams.map((t) => t.name).join(', ');
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) {
            final l10n = AppLocalizations.of(context)!;
            return AlertDialog(
              backgroundColor: VSPColors.surface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
              title: Text(l10n.warning, style: const TextStyle(color: VSPColors.warning, fontWeight: FontWeight.bold)),
              content: Text(
                l10n.unpaidTeamsWarning(unpaidNames),
                style: const TextStyle(color: VSPColors.textSecondary),
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
                        onPressed: () => Navigator.pop(ctx, false),
                      ),
                    ),
                    const SizedBox(width: VSPSpacing.md),
                    Expanded(
                      child: PrimaryButton(
                        text: l10n.proceedAnyway,
                        height: 44,
                        color: VSPColors.warning,
                        textColor: Colors.black,
                        onPressed: () => Navigator.pop(ctx, true),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
        if (proceed != true) return;
      }

      if (mounted) {
        _showBracketPreviewDialog(context, teams);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        AppErrorHandler.showError(context, e);
      }
    }
  }

  void _showBracketPreviewDialog(BuildContext context, List<Team> teams) {
    int totalTeams = teams.length;
    if (totalTeams < 2) return;

    int targetP2 = 1;
    while (targetP2 * 2 <= totalTeams) {
      targetP2 *= 2;
    }
    int totalBracketRounds = (log(targetP2) / log(2)).round();
    int numOpeningMatches = totalTeams - targetP2;
    int numTeamsR0 = numOpeningMatches * 2;

    List<List<Map<String, String>>> rounds = [];
    final previewTeams = List<Team>.from(teams);

    if (numOpeningMatches > 0) {
      List<Map<String, String>> r0 = [];
      for (int m = 0; m < numOpeningMatches; m++) {
        String homeName = previewTeams[m * 2].name;
        String awayName = previewTeams[m * 2 + 1].name;
        r0.add({'home': homeName, 'away': awayName});
      }
      rounds.add(r0);
    }

    List<Map<String, String>> r1 = [];
    int matchCountR1 = targetP2 ~/ 2;
    for (int m = 0; m < matchCountR1; m++) {
      String homeName = '';
      String awayName = '';

      int slotH = m * 2;
      if (slotH < numOpeningMatches) {
        homeName = 'فائز مـ ${slotH + 1} (R0)';
      } else {
        int byeIndex = slotH - numOpeningMatches + numTeamsR0;
        if (byeIndex < totalTeams) {
          homeName = previewTeams[byeIndex].name;
        } else {
          homeName = 'BYE';
        }
      }

      int slotA = m * 2 + 1;
      if (slotA < numOpeningMatches) {
        awayName = 'فائز مـ ${slotA + 1} (R0)';
      } else {
        int byeIndex = slotA - numOpeningMatches + numTeamsR0;
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
      List<Map<String, String>> rx = [];
      int matchCount = targetP2 ~/ pow(2, r);
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
                            int roundIdx = entry.key;
                            List<Map<String, String>> roundMatches = entry.value;
                            int matchCount = roundMatches.length;
                            double slotHeight = totalBracketHeight / matchCount;

                            Widget roundColumn = SizedBox(
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
                                          : (roundIdx == rounds.length - 1 ? 'النهائي' : 'جولة ${numOpeningMatches > 0 ? roundIdx : roundIdx + 1}'),
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
                                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const Divider(height: 8, color: Colors.white12),
                                                  Text(
                                                    m['away']!,
                                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
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
                                            '🏆 البطل',
                                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: VSPColors.accent),
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
                      _showInteractiveDrawRoom(context, teams);
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

  Future<void> _showInteractiveDrawRoom(BuildContext context, List<Team> teams) async {
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
                  isAr ? 'غرفة سحب القرعة المباشر 🎲' : 'Live Draw Room 🎲',
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
                        ? 'سحب موجه ومؤمن عشوائياً بدون أي تدخل بشري لضمان النزاهة التامة 🏆'
                        : 'Fair automated live draw for all participating teams 🏆',
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
                                    isRevealed ? m['home']! : '❓ (مستخفي)',
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
                                  child: Text('VS', style: TextStyle(color: VSPColors.accent, fontWeight: FontWeight.w900, fontSize: 12)),
                                ),
                                Expanded(
                                  child: Text(
                                    isRevealed ? m['away']! : '❓ (مستخفي)',
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
                  text: isAr ? 'بدء السحب الكاشف 🎲' : 'Start Live Reveal 🎲',
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
                  text: isAr ? 'اعتماد القرعة وبدء البطولة 🚀' : 'Confirm Draw & Start 🚀',
                  height: 44,
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    _executeStartTournament();
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _executeStartTournament() async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final now = DateTime.now();

    if (now.isBefore(_currentChampionship.startDate)) {
      final formattedDate = AppDateFormatter.formatFullDate(_currentChampionship.startDate, isArabic ? 'ar' : 'en');
      VSPFeedback.showError(
        context,
        isArabic
          ? '🛑 لا يمكن بدء البطولة أو إطلاق القرعة قبل الموعد المعلن للفرق ($formattedDate) لالتزام اللاعبين واستعدادهم.'
          : '🛑 Tournament cannot be started before its official date ($formattedDate).',
      );
      return;
    }

    final teamCount = _currentChampionship.joinedTeams.length;

    if (teamCount < _currentChampionship.maxTeams) {
      final shouldForceStart = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: VSPColors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
          title: Text(AppLocalizations.of(ctx)!.forceStartTournament, style: Theme.of(ctx).textTheme.titleLarge),
          content: Text(
            AppLocalizations.of(ctx)!.forceStartWarning(teamCount, _currentChampionship.maxTeams),
            style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.md),
          actions: [
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    text: AppLocalizations.of(ctx)!.cancel,
                    height: 44,
                    color: VSPColors.surfaceAlt,
                    textColor: VSPColors.textPrimary,
                    onPressed: () => Navigator.pop(ctx, false),
                  ),
                ),
                const SizedBox(width: VSPSpacing.md),
                Expanded(
                  child: PrimaryButton(
                    text: AppLocalizations.of(ctx)!.forceStart,
                    height: 44,
                    color: VSPColors.warning,
                    textColor: Colors.black,
                    onPressed: () => Navigator.pop(ctx, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

      if (shouldForceStart != true) return;
    }

    setState(() => _isLoading = true);
    try {
      if (_currentChampionship.type == 'League') {
        await TournamentRepository().generateLeagueFixtures(_currentChampionship.id);
      } else if (_currentChampionship.type == 'GroupsAndKnockout') {
        await TournamentRepository().generateGroupsFixtures(_currentChampionship.id);
      } else {
        await TournamentRepository().generateFixtures(_currentChampionship.id);
      }
      
      setState(() {
        _currentChampionship = _currentChampionship.copyWith(status: 'ongoing');
      });
      if (mounted) {
        VSPFeedback.showSuccess(context, AppLocalizations.of(context)!.drawGeneratedSuccess);
      }
    } catch (e) {
      if (mounted) {
        VSPFeedback.showError(context, 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 🛡️ نافذة تأكيد حذف الفريق من البطولة
  Future<void> _showDeleteTeamConfirmationDialog(Team team) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
        title: Row(
          children: [
            const Icon(Iconsax.warning_2_copy, color: VSPColors.error, size: 22),
            const SizedBox(width: 8),
            Text(
              isArabic ? 'إلغاء انضمام الفريق؟' : 'Remove Team?',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          isArabic
              ? 'هل أنت متأكد من إلغاء انضمام فريق "${team.name}" من هذه البطولة؟'
              : 'Are you sure you want to remove team "${team.name}" from this tournament?',
          style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              isArabic ? 'إلغاء' : 'Cancel',
              style: const TextStyle(color: VSPColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: VSPColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.sm)),
            ),
            child: Text(
              isArabic ? 'تأكيد الحذف' : 'Confirm Remove',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      try {
        final success = await TournamentRepository().leaveChampionship(_currentChampionship.id, team.id);
        if (success) {
          setState(() {
            final updatedList = List<String>.from(_currentChampionship.joinedTeams)..remove(team.id);
            final updatedPaid = List<String>.from(_currentChampionship.paidTeams)..remove(team.id);
            _currentChampionship = _currentChampionship.copyWith(
              joinedTeams: updatedList,
              paidTeams: updatedPaid,
            );
          });
          if (mounted) {
            VSPFeedback.showSuccess(context, isArabic ? 'تم إلغاء انضمام الفريق بنجاح.' : 'Team removed successfully.');
          }
        }
      } catch (e) {
        if (mounted) {
          VSPFeedback.showError(context, e.toString().replaceAll('Exception:', ''));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showAddTeamManuallyDialog() {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final nameCtrl = TextEditingController();
    final playerInputCtrl = TextEditingController();

    final List<Map<String, dynamic>> quickColors = [
      {'name': 'أبيض', 'value': '#FFFFFF', 'color': Colors.white},
      {'name': 'أحمر', 'value': '#EF4444', 'color': Colors.red},
      {'name': 'أزرق', 'value': '#3B82F6', 'color': Colors.blue},
      {'name': 'أخضر', 'value': '#22C55E', 'color': Colors.green},
      {'name': 'أصفر', 'value': '#F59E0B', 'color': Colors.amber},
      {'name': 'أسود', 'value': '#18181B', 'color': Colors.black},
    ];

    String selectedPrimaryColor = '#FFFFFF';
    List<String> offlinePlayerNames = [];
    bool isPaidOnCreation = true; // 🟢 Default for manual additions: Paid!

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.88,
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(sheetContext).padding.bottom + MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          decoration: const BoxDecoration(
            color: VSPColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
          ),
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
              final teamName = nameCtrl.text.trim();
              final isNameValid = teamName.isNotEmpty;
              final totalPlayers = offlinePlayerNames.length;
              final bool isValidRoster = totalPlayers >= 5 && totalPlayers <= 12;
              final bool canSubmit = isNameValid && isValidRoster;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: VSPColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isArabic ? 'إضافة فريق يدويًا' : 'Add Team Manually',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      IconButton(
                        icon: const Icon(Iconsax.close_circle_copy, color: VSPColors.textSecondary),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                  Text(
                    isArabic ? 'تسجيل وتنسيق فريق خارجي يدويًا في قائمة البطولة' : 'Manually add and register an external team to the tournament',
                    style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 16),

                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. اسم الفريق مع رسالة التنبيه البصرية
                          _buildInputLabel(isArabic ? 'اسم الفريق:' : 'Team Name:'),
                          CustomTextField(
                            controller: nameCtrl,
                            hintText: isArabic ? 'اكتب اسم فريق' : 'Enter team name',
                            onChanged: (_) => setDialogState(() {}),
                          ),
                          if (!isNameValid) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Iconsax.warning_2_copy, color: Colors.orange, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  isArabic ? '⚠️ يرجى كتابة اسم الفريق لتفعيل التنسيق' : '⚠️ Please enter team name',
                                  style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),

                          // 2. حالة سداد رسوم الاشتراك
                          _buildInputLabel(isArabic ? 'حالة سداد رسوم الاشتراك:' : 'Payment Status:'),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setDialogState(() => isPaidOnCreation = true),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isPaidOnCreation ? VSPColors.accent : VSPColors.surfaceAlt,
                                      borderRadius: BorderRadius.circular(VSPRadius.md),
                                      border: Border.all(color: isPaidOnCreation ? VSPColors.accent : VSPColors.divider),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.check_circle, color: isPaidOnCreation ? Colors.black : VSPColors.accent, size: 16),
                                        const SizedBox(width: 6),
                                        Text(
                                          isArabic ? 'تم الدفع 🟢' : 'Paid 🟢',
                                          style: TextStyle(
                                            color: isPaidOnCreation ? Colors.black : Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setDialogState(() => isPaidOnCreation = false),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: !isPaidOnCreation ? VSPColors.warning.withValues(alpha: 0.2) : VSPColors.surfaceAlt,
                                      borderRadius: BorderRadius.circular(VSPRadius.md),
                                      border: Border.all(color: !isPaidOnCreation ? VSPColors.warning : VSPColors.divider),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.access_time_filled, color: !isPaidOnCreation ? VSPColors.warning : VSPColors.textSecondary, size: 16),
                                        const SizedBox(width: 6),
                                        Text(
                                          isArabic ? 'معلق / غير مدفوع 🕒' : 'Pending 🕒',
                                          style: TextStyle(
                                            color: !isPaidOnCreation ? VSPColors.warning : Colors.white70,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 2. لون قميص الفريق
                          _buildInputLabel(isArabic ? 'لون قميص الفريق:' : 'Shirt Color:'),
                          SizedBox(
                            height: 40,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: quickColors.length,
                              itemBuilder: (context, index) {
                                final item = quickColors[index];
                                final isSelected = selectedPrimaryColor == item['value'];
                                return GestureDetector(
                                  onTap: () => setDialogState(() => selectedPrimaryColor = item['value']),
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color: item['color'],
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected ? VSPColors.accent : VSPColors.divider,
                                        width: isSelected ? 3.0 : 1.0,
                                      ),
                                    ),
                                    child: isSelected
                                        ? Icon(Iconsax.tick_circle_copy, color: item['color'] == Colors.white ? Colors.black : Colors.white, size: 16)
                                        : null,
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 20),

                          // 3. كشف أسماء اللاعبين
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isArabic ? 'كشف أسماء اللاعبين (من 5 إلى 12):' : 'Roster (5 to 12 players):',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Directionality(
                                textDirection: TextDirection.ltr,
                                child: Text(
                                  '$totalPlayers / 12',
                                  style: TextStyle(
                                    color: isValidRoster ? VSPColors.accent : Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          Row(
                            children: [
                              Expanded(
                                child: CustomTextField(
                                  controller: playerInputCtrl,
                                  hintText: isArabic ? 'اكتب اسم اللاعب واضغط إضافة...' : 'Enter player name...',
                                  onChanged: (_) => setDialogState(() {}),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: () {
                                    final pName = playerInputCtrl.text.trim();
                                    if (pName.isEmpty) return;
                                    if (offlinePlayerNames.contains(pName)) return;
                                    if (offlinePlayerNames.length >= 12) return;

                                    setDialogState(() {
                                      offlinePlayerNames.add(pName);
                                      playerInputCtrl.clear();
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: VSPColors.accent,
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                                  ),
                                  child: const Icon(Icons.add, size: 22),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          if (offlinePlayerNames.isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: VSPColors.background,
                                borderRadius: BorderRadius.circular(VSPRadius.md),
                                border: Border.all(color: VSPColors.divider),
                              ),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: offlinePlayerNames.map((name) {
                                  return Chip(
                                    backgroundColor: VSPColors.surfaceAlt,
                                    label: Text(name, style: const TextStyle(color: Colors.white, fontSize: 12)),
                                    deleteIcon: const Icon(Icons.close, size: 14, color: Colors.redAccent),
                                    onDeleted: () {
                                      setDialogState(() {
                                        offlinePlayerNames.remove(name);
                                      });
                                    },
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(VSPRadius.sm),
                                      side: const BorderSide(color: VSPColors.divider),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),

                          if (totalPlayers < 5) ...[
                            const SizedBox(height: 8),
                            Text(
                              isArabic
                                  ? '⚠️ يجب إضافة ${5 - totalPlayers} لاعبين إضافيين لتشغيل كشف الفريق'
                                  : '⚠️ Add ${5 - totalPlayers} more players',
                              style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 💡 أزرار التحكم التفاعلية التي توضح سبب الرفض فوراً
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: VSPColors.surfaceAlt,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                            ),
                            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: PrimaryButton(
                            text: isArabic ? 'تأكيد إضافة الفريق 🏆' : 'Confirm Add Team 🏆',
                            color: canSubmit ? VSPColors.accent : VSPColors.surfaceAlt,
                            textColor: canSubmit ? Colors.black : VSPColors.textSecondary,
                            onPressed: () async {
                              if (!isNameValid) {
                                VSPFeedback.showError(sheetContext, isArabic ? 'يرجى كتابة اسم الفريق أولاً ✏️' : 'Please enter team name first ✏️');
                                return;
                              }
                              if (!isValidRoster) {
                                VSPFeedback.showError(sheetContext, isArabic ? 'يرجى إضافة 5 لاعبين على الأقل لكشف الفريق 👥' : 'Please add at least 5 players 👥');
                                return;
                              }

                              final teamNameVal = nameCtrl.text.trim();
                              final parentContext = context;
                              Navigator.pop(sheetContext);

                              setState(() => _isLoading = true);
                              try {
                                final auth = Provider.of<AuthProvider>(parentContext, listen: false);
                                final currentUserId = auth.currentUser?.uid ?? auth.currentUser?.id ?? '';

                                final teamId = await TeamRepository().createTeam({
                                  'name': teamNameVal,
                                  'captainName': isArabic ? 'تسجيل يدوي' : 'Manual Registration',
                                  'captainImageUrl': '',
                                  'logoUrl': '',
                                  'sportType': _currentChampionship.sportType,
                                  'governorate': _currentChampionship.governorate,
                                  'memberUids': [currentUserId.isNotEmpty ? currentUserId : '8d3d7d65-a167-4138-b36c-85bbdead1b7a'],
                                  'date': 'Upcoming',
                                  'primary_color': selectedPrimaryColor,
                                  'secondary_color': '#000000',
                                });

                                if (teamId != null) {
                                  await TournamentRepository().joinChampionship(
                                    _currentChampionship.id,
                                    teamId,
                                    skipMemberCheck: true,
                                    isPaid: isPaidOnCreation,
                                  );

                                  await Supabase.instance.client.from('championship_rosters').insert({
                                    'championship_id': _currentChampionship.id,
                                    'team_id': teamId,
                                    'player_ids': [],
                                    'guest_names': offlinePlayerNames,
                                  });

                                  setState(() {
                                    _currentChampionship = _currentChampionship.copyWith(
                                      joinedTeams: [..._currentChampionship.joinedTeams, teamId],
                                    );
                                  });

                                  if (parentContext.mounted) {
                                    VSPFeedback.showSuccess(
                                      parentContext,
                                      isArabic ? 'تم إضافة الفريق للبطولة بنجاح! 🏆' : 'Team added to tournament successfully!',
                                    );
                                  }
                                }
                              } catch (e) {
                                if (parentContext.mounted) {
                                  VSPFeedback.showError(parentContext, e.toString());
                                }
                              } finally {
                                if (mounted) setState(() => _isLoading = false);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    ).whenComplete(() {
      nameCtrl.dispose();
      playerInputCtrl.dispose();
    });
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Text(
        label,
        style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _togglePaymentStatus(String teamId) async {
    final isPaid = _currentChampionship.paidTeams.contains(teamId);
    try {
      await TournamentRepository().toggleTeamPayment(
        championshipId: _currentChampionship.id,
        teamId: teamId,
        isPaid: !isPaid,
      );
      setState(() {
        final updatedList = List<String>.from(_currentChampionship.paidTeams);
        if (isPaid) {
          updatedList.remove(teamId);
        } else {
          updatedList.add(teamId);
        }
        _currentChampionship = _currentChampionship.copyWith(paidTeams: updatedList);
      });
    } catch (e) {
      if (mounted) {
        VSPFeedback.showError(context, 'Error: $e');
      }
    }
  }

  Widget _buildTeamListItem(Team team, bool isPaid, BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: VSPColors.divider),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundImage: team.captainImageUrl.isNotEmpty
                ? NetworkImage(team.captainImageUrl)
                : null,
            backgroundColor: VSPColors.surfaceAlt,
            child: team.captainImageUrl.isEmpty
                ? const Icon(Iconsax.people_copy, color: VSPColors.textSecondary, size: 20)
                : null,
          ),
          const SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  team.name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  team.captainName,
                  style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),

          GestureDetector(
            onTap: () => _togglePaymentStatus(team.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isPaid
                    ? VSPColors.success.withValues(alpha: 0.15)
                    : VSPColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(VSPRadius.full),
                border: Border.all(
                  color: isPaid
                      ? VSPColors.success.withValues(alpha: 0.5)
                      : VSPColors.warning.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPaid ? Iconsax.tick_circle_copy : Iconsax.clock_copy,
                    size: 14,
                    color: isPaid ? VSPColors.success : VSPColors.warning,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isPaid ? (isArabic ? 'تم الدفع' : 'Paid') : (isArabic ? 'معلق' : 'Pending'),
                    style: TextStyle(
                      color: isPaid ? VSPColors.success : VSPColors.warning,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          IconButton(
            icon: const Icon(Iconsax.trash_copy, color: VSPColors.error, size: 20),
            onPressed: () => _showDeleteTeamConfirmationDialog(team),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Localizations.localeOf(context).languageCode == 'ar'
                ? Iconsax.arrow_right_1_copy
                : Iconsax.arrow_left_2_copy,
            color: VSPColors.textPrimary,
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
        title: Text(_currentChampionship.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Iconsax.share_copy, color: VSPColors.accent),
            onPressed: () {
              final isArabic = Localizations.localeOf(context).languageCode == 'ar';
              final String startDateStr = AppDateFormatter.formatDayMonth(
                _currentChampionship.startDate,
                isArabic ? 'ar' : 'en',
              );
              final String endDateStr = AppDateFormatter.formatDayMonth(
                _currentChampionship.endDate,
                isArabic ? 'ar' : 'en',
              );

              SharingService.shareChampionship(
                id: _currentChampionship.id,
                name: _currentChampionship.name,
                startDateStr: startDateStr,
                endDateStr: endDateStr,
                grandPrize: _currentChampionship.grandPrize,
                entryFee: _currentChampionship.entryFee,
                joinedTeamsCount: _currentChampionship.joinedTeams.length,
                maxTeams: _currentChampionship.maxTeams,
                sportType: _currentChampionship.sportType,
                governorate: _currentChampionship.governorate,
                isArabic: isArabic,
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Supabase.instance.client
            .from('championships')
            .stream(primaryKey: ['id'])
            .eq('id', _currentChampionship.id),
        builder: (context, champSnapshot) {
          if (champSnapshot.hasData && champSnapshot.data!.isNotEmpty) {
            _currentChampionship = Championship.fromFirestore(champSnapshot.data!.first, _currentChampionship.id);
          }
          final currentChamp = _currentChampionship;

          return FutureBuilder<List<Team>>(
            future: TournamentRepository().getTeamsByIds(currentChamp.joinedTeams),
            builder: (context, snapshot) {
              final teams = snapshot.data ?? [];
              
              return Column(
                children: [
                  VSPCard(
                    margin: const EdgeInsets.all(VSPSpacing.md),
                    padding: const EdgeInsets.all(VSPSpacing.md),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildInfoItem(
                              AppLocalizations.of(context)!.statusLabel, 
                              currentChamp.status.toUpperCase(), 
                              color: currentChamp.status == 'completed' ? VSPColors.error : VSPColors.accent,
                            ),
                            _buildInfoItem(AppLocalizations.of(context)!.categoryLabel, currentChamp.type),
                          ],
                        ),
                        const Divider(color: VSPColors.divider, height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildInfoItem(
                              AppLocalizations.of(context)!.datesLabel, 
                              '${DateFormat('MMM d').format(currentChamp.startDate)} - ${DateFormat('MMM d').format(currentChamp.endDate)}',
                            ),
                            _buildInfoItem(
                              AppLocalizations.of(context)!.teamsLabel, 
                              '${currentChamp.joinedTeams.length} / ${currentChamp.maxTeams}',
                              isLtr: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.lg, vertical: VSPSpacing.sm),
                    child: Row(
                      children: [
                        const Icon(Iconsax.people_copy, color: VSPColors.textSecondary, size: 18),
                        const SizedBox(width: 8),
                        Text(AppLocalizations.of(context)!.joinedTeamsLabel, style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: VSPColors.textSecondary, 
                          fontWeight: FontWeight.bold
                        )),
                        const Spacer(),
                        if (currentChamp.status == 'open' && currentChamp.joinedTeams.length < currentChamp.maxTeams)
                          GestureDetector(
                            onTap: () => _showAddTeamManuallyDialog(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: VSPColors.accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(VSPRadius.full),
                                border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Iconsax.user_add_copy, color: VSPColors.accent, size: 14),
                                  const SizedBox(width: 4),
                                  Text(AppLocalizations.of(context)!.addTeam, style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: VSPColors.accent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  )),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: teams.isEmpty
                        ? Center(
                            child: Text(
                              Localizations.localeOf(context).languageCode == 'ar'
                                  ? 'لا توجد فرق مشاركة حتى الآن'
                                  : 'No teams joined yet',
                              style: const TextStyle(color: VSPColors.textSecondary),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: teams.length,
                            itemBuilder: (context, index) {
                              final team = teams[index];
                              final isPaid = currentChamp.paidTeams.contains(team.id);
                              return _buildTeamListItem(team, isPaid, context);
                            },
                          ),
                  ),

                  Container(
                    padding: EdgeInsets.fromLTRB(VSPSpacing.md, VSPSpacing.md, VSPSpacing.md, VSPSpacing.md + MediaQuery.of(context).padding.bottom),
                    decoration: const BoxDecoration(
                      color: VSPColors.surface,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (currentChamp.status == 'open')
                          PrimaryButton(
                            text: AppLocalizations.of(context)!.generateDrawStart,
                            isLoading: _isLoading,
                            onPressed: _handleStartTournament,
                          ),
                        
                        if (currentChamp.status != 'open')
                          PrimaryButton(
                            text: AppLocalizations.of(context)!.viewBrackets.toUpperCase(),
                            color: VSPColors.accent.withValues(alpha: 0.1),
                            textColor: VSPColors.accent,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TournamentBracketsScreen(
                                    championship: currentChamp,
                                    isOwner: true, 
                                  ),
                                ),
                              );
                            },
                          ),
                          
                        if (currentChamp.status == 'completed' || currentChamp.championTeamName != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: VSPColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(VSPRadius.md),
                              border: Border.all(color: VSPColors.accent, width: 1.5),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Iconsax.cup_copy, color: VSPColors.accent, size: 24),
                                const SizedBox(width: 10),
                                Text(
                                  Localizations.localeOf(context).languageCode == 'ar'
                                      ? '🏆 بطل البطولة: ${currentChamp.championTeamName ?? ""}'
                                      : '🏆 Champion: ${currentChamp.championTeamName ?? ""}',
                                  style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, {Color? color, bool isLtr = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        const SizedBox(height: 4),
        isLtr
            ? Directionality(
                textDirection: TextDirection.ltr,
                child: Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color ?? VSPColors.textPrimary, fontWeight: FontWeight.bold)),
              )
            : Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color ?? VSPColors.textPrimary, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
