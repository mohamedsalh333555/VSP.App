import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../core/repositories/tournament_repository.dart';
import '../../../core/services/sharing_service.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/app_date_formatter.dart';
import '../../../core/utils/app_error_handler.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../data/models.dart';
import '../../../shared/widgets/primary_button.dart';
import '../widgets/tournament/tournament_bracket_preview_dialog.dart';
import '../widgets/tournament/tournament_manual_team_sheet.dart';
import '../widgets/tournament/tournament_overview_card.dart';
import '../widgets/tournament/tournament_prize_delivery_dialog.dart';
import '../widgets/tournament/tournament_team_card.dart';
import 'tournament_brackets_screen.dart';

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
                        text: _currentChampionship.entryFee > 0
                            ? (Localizations.localeOf(context).languageCode == 'ar' ? 'فهمت ذلك' : 'Understood')
                            : l10n.proceedAnyway,
                        height: 44,
                        color: VSPColors.warning,
                        textColor: Colors.black,
                        onPressed: () => Navigator.pop(ctx, _currentChampionship.entryFee <= 0),
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
        showTournamentBracketPreviewDialog(
          context,
          teams: teams,
          onStartDraw: () {
            showInteractiveDrawRoomDialog(
              context,
              teams: teams,
              onConfirmDraw: _executeStartTournament,
            );
          },
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        AppErrorHandler.showError(context, e);
      }
    }
  }

  Future<void> _executeStartTournament() async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final now = DateTime.now();

    if (now.isBefore(_currentChampionship.startDate)) {
      final formattedDate = AppDateFormatter.formatFullDate(_currentChampionship.startDate, isArabic ? 'ar' : 'en');
      VSPFeedback.showError(
        context,
        isArabic
            ? 'لا يمكن بدء البطولة أو إطلاق القرعة قبل الموعد المعلن للفرق ($formattedDate) لالتزام اللاعبين واستعدادهم.'
            : 'Tournament cannot be started before its official date ($formattedDate).',
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
        title: Text(
          _currentChampionship.name,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
        ),
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
        stream: TournamentRepository().streamChampionshipRaw(_currentChampionship.id),
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
                  TournamentOverviewCard(
                    championship: currentChamp,
                    onRecordPrizeDelivery: () {
                      showTournamentPrizeDeliveryDialog(
                        context,
                        championship: currentChamp,
                        onDelivered: () => setState(() {}),
                      );
                    },
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.lg, vertical: VSPSpacing.sm),
                    child: Row(
                      children: [
                        const Icon(Iconsax.people_copy, color: VSPColors.textSecondary, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          AppLocalizations.of(context)!.joinedTeamsLabel,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: VSPColors.textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const Spacer(),
                        if (currentChamp.status == 'open' && currentChamp.joinedTeams.length < currentChamp.maxTeams)
                          GestureDetector(
                            onTap: () {
                              showTournamentManualTeamSheet(
                                context,
                                championship: currentChamp,
                                onTeamAdded: (updated) => setState(() => _currentChampionship = updated),
                              );
                            },
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
                                  Text(
                                    AppLocalizations.of(context)!.addTeam,
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: VSPColors.accent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                  ),
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
                              return TournamentTeamCard(
                                team: team,
                                isPaid: isPaid,
                                onTogglePayment: () => _togglePaymentStatus(team.id),
                                onDelete: () {
                                  showDeleteTeamConfirmationDialog(
                                    context,
                                    team: team,
                                    championship: currentChamp,
                                    onTeamRemoved: (updated) => setState(() => _currentChampionship = updated),
                                  );
                                },
                              );
                            },
                          ),
                  ),

                  Container(
                    padding: EdgeInsets.fromLTRB(
                      VSPSpacing.md,
                      VSPSpacing.md,
                      VSPSpacing.md,
                      VSPSpacing.md + MediaQuery.of(context).padding.bottom,
                    ),
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
                                      ? 'بطل البطولة: ${currentChamp.championTeamName ?? ""}'
                                      : 'Champion: ${currentChamp.championTeamName ?? ""}',
                                  style: const TextStyle(
                                      color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 15),
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
}
