import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/stadium_provider.dart';
import '../../../../core/repositories/league/team_league_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../data/models.dart';
import '../../screens/booking_confirmation_screen.dart';
import '../create_team_sheet.dart';
import 'team_league_fixtures_view.dart';
import 'team_league_gathering_card.dart';
import 'team_league_match_dialog.dart';
import 'team_league_onboarding_card.dart';
import 'team_league_standings_view.dart';

class TeamLeagueTab extends StatefulWidget {
  final Team? userTeam;
  final VoidCallback onTeamCreated;

  const TeamLeagueTab({
    super.key,
    required this.userTeam,
    required this.onTeamCreated,
  });

  @override
  State<TeamLeagueTab> createState() => _TeamLeagueTabState();
}

class _TeamLeagueTabState extends State<TeamLeagueTab> {
  final TeamLeagueRepository _leagueRepo = TeamLeagueRepository();
  bool _isLoading = true;
  TeamLeagueData? _leagueData;
  int _selectedSubTab = 0; // 0 = المباريات, 1 = الترتيب

  @override
  void initState() {
    super.initState();
    _loadLeague();
  }

  @override
  void didUpdateWidget(covariant TeamLeagueTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userTeam?.id != widget.userTeam?.id) {
      _loadLeague();
    }
  }

  Future<void> _loadLeague() async {
    if (widget.userTeam == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (mounted) setState(() => _isLoading = true);
    try {
      final data = await _leagueRepo.getTeamActiveLeague(widget.userTeam!.id);
      if (mounted) {
        setState(() {
          _leagueData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showCreateLeagueDialog() {
    final nameController = TextEditingController(
      text: widget.userTeam != null ? 'دوري ${widget.userTeam!.name}' : '',
    );
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: EdgeInsets.only(
            top: 24,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: VSPColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Iconsax.cup_copy, color: VSPColors.accent, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'إنشاء دوري لفريقك',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'سيتم فتح الدوري ودعوة 3 فرق منافسة للمشاركة في 3 جولات.',
                style: TextStyle(color: VSPColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'اسم الدوري',
                  labelStyle: const TextStyle(color: VSPColors.textSecondary),
                  filled: true,
                  fillColor: VSPColors.surfaceAlt,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Fee clarification badge
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: VSPColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(VSPRadius.md),
                  border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Iconsax.info_circle_copy, color: VSPColors.accent, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'رسوم الاشتراك: 30 جنيه لكل فريق.',
                        style: TextStyle(
                          color: VSPColors.accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final name = nameController.text.trim();
                        if (name.isEmpty) return;

                        setSheetState(() => isSubmitting = true);
                        try {
                          await _leagueRepo.createTeamLeague(
                            teamId: widget.userTeam!.id,
                            leagueName: name,
                          );
                          VSPFeedback.triggerSuccess();
                          if (ctx.mounted) Navigator.pop(ctx);
                          await _loadLeague();
                        } catch (e) {
                          setSheetState(() => isSubmitting = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('خطأ: $e')),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: VSPColors.accent,
                  foregroundColor: VSPColors.background,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                  ),
                ),
                child: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Text(
                        'تأكيد وإنشاء الدوري (30 ج)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showJoinLeagueDialog() {
    final codeController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: VSPColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
          child: Padding(
            padding: const EdgeInsets.all(VSPSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'الانضمام لدوري',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'أدخل كود الدوري للانضمام والمنافسة مع الفرق',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: codeController,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'كود الدوري',
                    labelStyle: const TextStyle(color: VSPColors.textSecondary),
                    filled: true,
                    fillColor: VSPColors.surfaceAlt,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                const Text(
                  'رسوم الاشتراك: 30 جنيه لكل فريق',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: VSPColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: VSPColors.textSecondary,
                          side: const BorderSide(color: VSPColors.borderLight),
                        ),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final code = codeController.text.trim();
                                if (code.isEmpty) return;

                                setDialogState(() => isSubmitting = true);
                                try {
                                  await _leagueRepo.joinTeamLeague(
                                    championshipId: code,
                                    teamId: widget.userTeam!.id,
                                  );
                                  VSPFeedback.triggerSuccess();
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  await _loadLeague();
                                } catch (e) {
                                  setDialogState(() => isSubmitting = false);
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text('خطأ: $e')),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VSPColors.accent,
                          foregroundColor: VSPColors.background,
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : const Text('انضمام', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onBookMatch(TeamLeagueMatch match) {
    final stadiumProvider = Provider.of<StadiumProvider>(context, listen: false);
    final stadiums = stadiumProvider.allStadiums;

    if (stadiums.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد ملاعب متاحة حالياً للحجز')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: VSPColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
        ),
        padding: const EdgeInsets.all(VSPSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Iconsax.building_copy, color: VSPColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'اختر ملعب لمباراة: ${match.homeTeamName} vs ${match.awayTeamName}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                IconButton(
                  icon: const Icon(Iconsax.close_circle_copy, color: VSPColors.textSecondary),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(color: VSPColors.divider),
            Expanded(
              child: ListView.separated(
                itemCount: stadiums.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final stadium = stadiums[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: VSPColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                    ),
                    child: ListTile(
                      title: Text(
                        stadium.name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${stadium.governorate} • ${stadium.basePrice.toStringAsFixed(0)} ج/ساعة',
                        style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                      ),
                      trailing: const Icon(Iconsax.arrow_left_2_copy, color: VSPColors.accent, size: 18),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final bookingRes = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BookingConfirmationScreen(
                              stadium: stadium,
                              bookingType: 'Team',
                            ),
                          ),
                        );

                        if (bookingRes != null && bookingRes is Booking) {
                          await _leagueRepo.linkLeagueMatchBooking(
                            matchId: match.id,
                            bookingId: bookingRes.id,
                            scheduledTime: bookingRes.startTime,
                            stadiumName: stadium.name,
                          );
                          VSPFeedback.triggerSuccess();
                          await _loadLeague();
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onRecordScore(TeamLeagueMatch match) {
    showDialog(
      context: context,
      builder: (ctx) => TeamLeagueMatchDialog(
        match: match,
        onSubmit: (homeScore, awayScore, homePenalties, awayPenalties) async {
          await _leagueRepo.recordLeagueMatchResult(
            matchId: match.id,
            homeScore: homeScore,
            awayScore: awayScore,
            homePenalties: homePenalties,
            awayPenalties: awayPenalties,
          );
          VSPFeedback.triggerSuccess();
          await _loadLeague();
        },
      ),
    );
  }

  Future<void> _cancelLeague(String leagueId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        title: const Text('إلغاء الدوري', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('هل أنت متأكد من إلغاء هذا الدوري وحذفه؟', style: TextStyle(color: VSPColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: VSPColors.error),
            child: const Text('نعم، إلغاء', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _leagueRepo.cancelTeamLeague(leagueId);
        VSPFeedback.triggerSuccess();
        await _loadLeague();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. If player has no team
    if (widget.userTeam == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(VSPSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Iconsax.people_copy,
                size: 72,
                color: VSPColors.accent.withValues(alpha: 0.3),
              ),
              const SizedBox(height: VSPSpacing.md),
              const Text(
                'ليس لديك فريق حالياً',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'الدوري يتطلب وجود فريق للمشاركة والمنافسة على اللقب.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: VSPColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: VSPSpacing.xl),
              ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => const CreateTeamSheet(),
                  ).then((_) => widget.onTeamCreated());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: VSPColors.accent,
                  foregroundColor: VSPColors.background,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                ),
                child: const Text('إنشاء فريق جديد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ],
          ),
        ),
      );
    }

    // 2. Loading state
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: VSPColors.accent),
      );
    }

    final league = _leagueData;

    // 3. Not in any league -> Show onboarding card
    if (league == null) {
      return RefreshIndicator(
        onRefresh: _loadLeague,
        color: VSPColors.accent,
        backgroundColor: VSPColors.surface,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            TeamLeagueOnboardingCard(
              onCreateLeague: _showCreateLeagueDialog,
              onJoinLeague: _showJoinLeagueDialog,
            ),
          ],
        ),
      );
    }

    // 4. Gathering state (1-3 teams)
    if (league.status == 'open') {
      return RefreshIndicator(
        onRefresh: _loadLeague,
        color: VSPColors.accent,
        backgroundColor: VSPColors.surface,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            TeamLeagueGatheringCard(
              league: league,
              onRefresh: _loadLeague,
              onCancelLeague: () => _cancelLeague(league.id),
            ),
          ],
        ),
      );
    }

    // 5. Ongoing or Completed League (Fixtures + Standings)
    return RefreshIndicator(
      onRefresh: _loadLeague,
      color: VSPColors.accent,
      backgroundColor: VSPColors.surface,
      child: Column(
        children: [
          // Sub-pill switcher: [ المباريات (6) ] [ جدول الترتيب ]
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: VSPColors.surfaceAlt,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedSubTab = 0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _selectedSubTab == 0 ? VSPColors.accent : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'المباريات (${league.matches.length})',
                          style: TextStyle(
                            color: _selectedSubTab == 0 ? Colors.black : VSPColors.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedSubTab = 1),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _selectedSubTab == 1 ? VSPColors.accent : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'جدول الترتيب 🏆',
                          style: TextStyle(
                            color: _selectedSubTab == 1 ? Colors.black : VSPColors.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content view
          Expanded(
            child: _selectedSubTab == 0
                ? TeamLeagueFixturesView(
                    matches: league.matches,
                    userTeamId: widget.userTeam!.id,
                    onBookMatch: _onBookMatch,
                    onRecordScore: _onRecordScore,
                  )
                : TeamLeagueStandingsView(
                    league: league,
                    userTeamId: widget.userTeam!.id,
                  ),
          ),
        ],
      ),
    );
  }
}
