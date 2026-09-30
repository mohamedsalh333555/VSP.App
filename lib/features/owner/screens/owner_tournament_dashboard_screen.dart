import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/tournament_repository.dart';
import '../../../core/services/sharing_service.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/app_date_formatter.dart';
import '../../../core/utils/app_error_handler.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../data/models.dart';
import '../widgets/tournament/tournament_bracket_preview_dialog.dart';
import '../widgets/tournament/tournament_dashboard_bottom_bar.dart';
import '../../../shared/widgets/vsp_back_button.dart';
import '../widgets/tournament/tournament_dashboard_dialogs.dart';
import '../widgets/tournament/tournament_manual_team_sheet.dart';
import '../widgets/tournament/tournament_overview_card.dart';
import '../widgets/tournament/tournament_prize_delivery_dialog.dart';
import '../widgets/tournament/tournament_team_card.dart';
import 'create_tournament_wizard.dart';

class OwnerTournamentDashboardScreen extends StatefulWidget {
  final Championship championship;

  const OwnerTournamentDashboardScreen({super.key, required this.championship});

  @override
  State<OwnerTournamentDashboardScreen> createState() => _OwnerTournamentDashboardScreenState();
}

class _OwnerTournamentDashboardScreenState extends State<OwnerTournamentDashboardScreen> {
  late Championship _currentChampionship;
  bool _isLoading = false;
  List<Team> _teams = [];
  List<String> _lastJoinedTeams = [];
  StreamSubscription? _champSubscription;

  @override
  void initState() {
    super.initState();
    _currentChampionship = widget.championship;
    _lastJoinedTeams = List.from(widget.championship.joinedTeams);
    _subscribeToChampionship();
    _fetchTeams(widget.championship.joinedTeams);
  }

  void _subscribeToChampionship() {
    _champSubscription = TournamentRepository()
        .streamChampionshipRaw(_currentChampionship.id)
        .listen((data) {
      if (!mounted || data.isEmpty) return;
      final updated = Championship.fromFirestore(data.first, _currentChampionship.id);
      setState(() => _currentChampionship = updated);

      if (!listEquals(updated.joinedTeams, _lastJoinedTeams)) {
        _lastJoinedTeams = List.from(updated.joinedTeams);
        _fetchTeams(updated.joinedTeams);
      }
    });
  }

  Future<void> _fetchTeams(List<String> ids) async {
    if (ids.isEmpty) {
      if (mounted) setState(() => _teams = []);
      return;
    }
    try {
      final teams = await TournamentRepository().getTeamsByIds(ids);
      if (mounted) setState(() => _teams = teams);
    } catch (e) {
      debugPrint('Error fetching teams in dashboard: $e');
    }
  }

  @override
  void dispose() {
    _champSubscription?.cancel();
    super.dispose();
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
        final proceed = await TournamentDashboardDialogs.showUnpaidTeamsWarning(
          context,
          unpaidNames: unpaidNames,
          entryFee: _currentChampionship.entryFee,
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
    final teamCount = _currentChampionship.joinedTeams.length;

    if (teamCount < _currentChampionship.maxTeams) {
      final shouldForceStart = await TournamentDashboardDialogs.showForceStartConfirmation(
        context,
        teamCount: teamCount,
        maxTeams: _currentChampionship.maxTeams,
      );

      if (shouldForceStart != true) return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    try {
      await TournamentRepository().startChampionship(_currentChampionship.id);

      if (mounted) {
        VSPFeedback.showSuccess(
          context,
          isAr
              ? 'تم إغلاق التسجيل وتوليد القرعة بنجاح! راجع جدول المباريات ثم اضغط بدء المنافسة.'
              : 'Registration locked and draw generated successfully!',
        );
      }
    } catch (e) {
      if (mounted) {
        VSPFeedback.showError(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleActivateCompetition() async {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
        title: Row(
          children: [
            const Icon(Iconsax.play_circle_copy, color: VSPColors.accent, size: 22),
            const SizedBox(width: 8),
            Text(
              isAr ? 'بدء المنافسة رسميًا' : 'Kickoff Competition',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          isAr
              ? 'ستبدأ البطولة رسميًا الآن ولن يمكن تعديل الفرق أو القوائم بعد هذه الخطوة. هل تريد المتابعة؟'
              : 'The tournament will officially begin now and rosters will be locked. Do you want to proceed?',
          style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isAr ? 'إلغاء' : 'Cancel', style: const TextStyle(color: VSPColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: VSPColors.accent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.sm)),
            ),
            child: Text(isAr ? 'تأكيد الانطلاق' : 'Confirm Kickoff', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await TournamentRepository().activateCompetition(_currentChampionship.id);
      if (mounted) {
        VSPFeedback.showSuccess(
          context,
          isAr ? 'انطلقت البطولة رسميًا! بالتوفيق لجميع الفرق.' : 'Tournament competition is now ongoing!',
        );
      }
    } catch (e) {
      if (mounted) {
        VSPFeedback.showError(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEditTournament() async {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    setState(() => _isLoading = true);
    final actions = await TournamentRepository().getChampionshipActions(_currentChampionship.id);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (actions['can_edit'] != true && actions['can_edit_basic_info'] != true) {
      VSPFeedback.showError(
        context,
        isAr ? 'لا يمكن تعديل هذه البطولة في حالتها الحالية.' : 'Tournament cannot be edited in its current state.',
      );
      return;
    }

    CreateTournamentWizard.open(
      context,
      tournament: _currentChampionship,
    );
  }

  Future<void> _handleCancelTournament() async {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    setState(() => _isLoading = true);
    final actions = await TournamentRepository().getChampionshipActions(_currentChampionship.id);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (actions['can_cancel'] != true) {
      final reason = actions['reason']?.toString() ?? '';
      String msg;
      if (reason == 'fixtures_generated' || reason == 'competition_in_progress') {
        msg = isAr
            ? 'لا يمكن إلغاء البطولة بعد إنشاء جدول المباريات أو انطلاقها.'
            : 'Cannot cancel tournament after fixtures are generated or competition started.';
      } else if (reason == 'already_cancelled') {
        msg = isAr ? 'البطولة ملغاة بالفعل.' : 'Tournament is already cancelled.';
      } else if (reason == 'competition_completed') {
        msg = isAr ? 'البطولة مكتملة بالفعل.' : 'Tournament is already completed.';
      } else {
        msg = isAr ? 'لا يمكن إلغاء البطولة في حالتها الحالية.' : 'Cannot cancel tournament in current state.';
      }
      VSPFeedback.showError(context, msg);
      return;
    }

    final confirmed = await TournamentDashboardDialogs.showCancelTournamentConfirmation(
      context,
      tournamentName: _currentChampionship.name,
      teamsCount: actions['teams_count'] is int ? actions['teams_count'] as int : _currentChampionship.joinedTeams.length,
      paidTeamsCount: actions['payments_count'] is int ? actions['payments_count'] as int : _currentChampionship.paidTeams.length,
      isTeamLeague: _currentChampionship.templateType == 'team_league',
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await TournamentRepository().cancelChampionship(_currentChampionship.id);
      if (mounted) {
        VSPFeedback.showSuccess(
          context,
          isAr ? 'تم إلغاء البطولة بنجاح.' : 'Tournament cancelled successfully.',
        );
        setState(() {
          _currentChampionship = _currentChampionship.copyWith(status: 'cancelled');
        });
      }
    } catch (e) {
      if (mounted) {
        VSPFeedback.showError(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDeleteTournament() async {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    setState(() => _isLoading = true);
    final actions = await TournamentRepository().getChampionshipActions(_currentChampionship.id);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (actions['can_delete'] != true) {
      final msg = isAr
          ? 'لا يمكن حذف البطولة لوجود فرق مسجلة أو مباريات. يمكنك استخدام خيار "إلغاء البطولة" بدلاً من ذلك.'
          : 'Cannot delete tournament with registered teams or matches. Use "Cancel Tournament" instead.';
      VSPFeedback.showError(context, msg);
      return;
    }

    final confirmed = await TournamentDashboardDialogs.showDeleteTournamentConfirmation(
      context,
      tournamentName: _currentChampionship.name,
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final ok = await TournamentRepository().deleteChampionship(_currentChampionship.id);
      if (ok && mounted) {
        VSPFeedback.showSuccess(
          context,
          isAr ? 'تم حذف البطولة نهائياً.' : 'Tournament permanently deleted.',
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        VSPFeedback.showError(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final uid = auth.currentUser?.id ?? auth.userModel?.uid;
    final isAdmin = auth.userModel?.role == 'admin' ||
        auth.userModel?.role == 'co_founder' ||
        auth.userModel?.role == 'super_admin';
    final isOwnerOrAdmin = (uid != null && uid == _currentChampionship.ownerId) || isAdmin;

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const VSPBackButton(),
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
          if (isOwnerOrAdmin)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: VSPColors.textPrimary),
              color: VSPColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
              onSelected: (action) {
                if (action == 'edit') _handleEditTournament();
                if (action == 'cancel') _handleCancelTournament();
                if (action == 'delete') _handleDeleteTournament();
              },
              itemBuilder: (ctx) {
                final isAr = Localizations.localeOf(ctx).languageCode == 'ar';
                final status = _currentChampionship.status.toLowerCase();
                final isCancelled = status == 'cancelled';
                final isCompleted = status == 'completed' || status == 'finished';

                return [
                  if (!isCompleted && !isCancelled)
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          const Icon(Iconsax.edit_2_copy, color: VSPColors.accent, size: 18),
                          const SizedBox(width: 8),
                          Text(isAr ? 'تعديل البطولة' : 'Edit Tournament', style: const TextStyle(color: VSPColors.textPrimary)),
                        ],
                      ),
                    ),
                  if (!isCancelled && !isCompleted)
                    PopupMenuItem(
                      value: 'cancel',
                      child: Row(
                        children: [
                          const Icon(Iconsax.close_circle_copy, color: VSPColors.warning, size: 18),
                          const SizedBox(width: 8),
                          Text(isAr ? 'إلغاء البطولة' : 'Cancel Tournament', style: const TextStyle(color: VSPColors.warning)),
                        ],
                      ),
                    ),
                  if (status == 'open' && _currentChampionship.joinedTeams.isEmpty)
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Iconsax.trash_copy, color: VSPColors.error, size: 18),
                          const SizedBox(width: 8),
                          Text(isAr ? 'حذف البطولة' : 'Delete Tournament', style: const TextStyle(color: VSPColors.error)),
                        ],
                      ),
                    ),
                ];
              },
            ),
        ],
      ),
      body: Column(
        children: [
          TournamentOverviewCard(
            championship: _currentChampionship,
            onRecordPrizeDelivery: () {
              showTournamentPrizeDeliveryDialog(
                context,
                championship: _currentChampionship,
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
                if (_currentChampionship.status == 'open' && _currentChampionship.joinedTeams.length < _currentChampionship.maxTeams)
                  GestureDetector(
                    onTap: () {
                      showTournamentManualTeamSheet(
                        context,
                        championship: _currentChampionship,
                        onTeamAdded: (updated) {
                          setState(() {
                            _currentChampionship = updated;
                            if (!listEquals(updated.joinedTeams, _lastJoinedTeams)) {
                              _lastJoinedTeams = List.from(updated.joinedTeams);
                              _fetchTeams(updated.joinedTeams);
                            }
                          });
                        },
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
            child: _teams.isEmpty
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
                    itemCount: _teams.length,
                    itemBuilder: (context, index) {
                      final team = _teams[index];
                      final isPaid = _currentChampionship.paidTeams.contains(team.id);
                      return TournamentTeamCard(
                        team: team,
                        isPaid: isPaid,
                        onDelete: () {
                          showDeleteTeamConfirmationDialog(
                            context,
                            team: team,
                            championship: _currentChampionship,
                            onTeamRemoved: (updated) {
                              setState(() {
                                _currentChampionship = updated;
                                if (!listEquals(updated.joinedTeams, _lastJoinedTeams)) {
                                  _lastJoinedTeams = List.from(updated.joinedTeams);
                                  _fetchTeams(updated.joinedTeams);
                                }
                              });
                            },
                          );
                        },
                      );
                    },
                  ),
          ),

          TournamentDashboardBottomBar(
            championship: _currentChampionship,
            isLoading: _isLoading,
            onStartTournament: _handleStartTournament,
            onActivateCompetition: _handleActivateCompetition,
          ),
        ],
      ),
    );
  }
}
