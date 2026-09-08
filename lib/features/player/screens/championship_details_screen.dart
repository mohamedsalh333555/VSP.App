import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../core/constants/egypt_governorates.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/team_repository.dart';
import '../../../core/repositories/tournament_repository.dart';
import '../../../core/services/sharing_service.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/app_date_formatter.dart';
import '../../../data/models.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/vsp_back_button.dart';
import '../../owner/screens/tournament_brackets_screen.dart';
import '../widgets/championship_details/championship_details_header.dart';
import '../widgets/championship_details/championship_matches_tab.dart';
import '../widgets/championship_details/championship_rules_tab.dart';
import '../widgets/championship_details/championship_squad_builder_sheet.dart';
import '../widgets/championship_details/championship_top_scorers_tab.dart';
import 'championship_checkout_screen.dart';
import 'manage_tournament_roster_screen.dart';

class ChampionshipDetailsScreen extends StatefulWidget {
  final Championship championship;

  const ChampionshipDetailsScreen({super.key, required this.championship});

  @override
  State<ChampionshipDetailsScreen> createState() => _ChampionshipDetailsScreenState();
}

class _ChampionshipDetailsScreenState extends State<ChampionshipDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isJoining = false;
  Team? _myTeam;
  late final Stream<Championship?> _singleChampionshipStream;
  late final Stream<List<TournamentMatch>> _matchesStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _singleChampionshipStream = TournamentRepository().getSingleChampionshipStream(widget.championship.id);
    _matchesStream = TournamentRepository().getTournamentMatches(widget.championship.id);
    _checkUserTeamState();
  }

  Future<void> _checkUserTeamState() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.currentUser != null) {
        final team = await TeamRepository().getUserTeam(auth.currentUser!.uid);
        if (team != null && mounted) {
          setState(() {
            _myTeam = team;
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking user team state in championship: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleJoin([Championship? liveChamp]) async {
    final activeChamp = liveChamp ?? widget.championship;
    if (_isJoining) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);

    if (!auth.isAuthenticated || auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.loginToJoinError)),
      );
      return;
    }

    setState(() => _isJoining = true);

    try {
      final team = await TeamRepository().getUserTeam(auth.currentUser!.uid);

      if (team != null && team.captainId != auth.currentUser!.uid) {
        if (mounted) {
          final isArabic = Localizations.localeOf(context).languageCode == 'ar';
          _showErrorDialog(isArabic
              ? 'عذراً! قائد الفريق (الكابتن) فقط هو من يحق له تسجيل الفريق في البطولة '
              : 'Only team captain is authorized to register team in tournaments ');
        }
        return;
      }

      if (team == null || team.memberUids.length < 5) {
        if (mounted) {
          await showIncompleteSquadBridgeSheet(
            context: context,
            team: team,
            championship: activeChamp,
          );
        }
        return;
      }

      if (activeChamp.joinedTeams.contains(team.id)) {
        if (mounted) {
          _showErrorDialog(AppLocalizations.of(context)!.alreadyJoinedError);
        }
        return;
      }

      // INTER-GOVERNORATE ATTENDANCE CONFIRMATION: Verify commitment if championship is hosted in another governorate
      if (!mounted) return;
      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
      final champGovRaw = activeChamp.governorate.trim();
      final playerGovRaw = auth.governorate.trim();

      final champGovStd = EgyptGovernorates.resolveGoogleName(champGovRaw) ?? champGovRaw;
      final playerGovStd = EgyptGovernorates.resolveGoogleName(playerGovRaw) ?? playerGovRaw;

      if (champGovStd.isNotEmpty &&
          playerGovStd.isNotEmpty &&
          champGovStd.toLowerCase() != playerGovStd.toLowerCase()) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: VSPColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(VSPRadius.xl),
              side: const BorderSide(color: VSPColors.divider),
            ),
            title: Row(
              children: [
                const Icon(Iconsax.location_copy, color: VSPColors.accent, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isArabic ? 'تأكيد موقع البطولة' : 'Confirm Tournament Location',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                  ),
                ),
              ],
            ),
            content: Text(
              isArabic
                  ? 'هذه البطولة تُقام في ملاعب محافظة [$champGovRaw]. هل أنت وفريقك مستعدون للالتزام بالحضور وخوض المباريات في الموعد والمكان المحدد؟'
                  : 'This tournament is hosted in [$champGovRaw]. Are you and your team committed to attending and playing on-site as scheduled?',
              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, height: 1.5),
            ),
            actionsPadding: const EdgeInsets.all(16),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(isArabic ? 'إلغاء' : 'Cancel', style: const TextStyle(color: VSPColors.textSecondary)),
              ),
              PrimaryButton(
                text: isArabic ? 'نعم، ملتزمون بالحضور' : 'Yes, We Will Attend',
                height: 44,
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ],
          ),
        );

        if (confirmed != true) {
          return;
        }
      }

      if (!mounted) return;
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => ChampionshipCheckoutScreen(
            championship: activeChamp,
            team: team,
          ),
        ),
      );

      if (!mounted) return;
      if (result == true) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VSPColors.surface,
        title: Text(
          AppLocalizations.of(context)!.errorLabel,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: VSPColors.error),
        ),
        content: Text(message, style: Theme.of(context).textTheme.bodyMedium),
        actionsPadding: const EdgeInsets.all(VSPSpacing.md),
        actions: [
          PrimaryButton(
            text: AppLocalizations.of(context)!.ok,
            height: 48,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return StreamBuilder<Championship?>(
      stream: _singleChampionshipStream,
      initialData: widget.championship,
      builder: (context, snapshot) {
        final championship = snapshot.data ?? widget.championship;
        final isTeamRegistered = _myTeam != null && championship.joinedTeams.contains(_myTeam!.id);
        final isFull = championship.isFull || championship.joinedTeams.length >= championship.maxTeams;

        final DateTime effectiveStartDate = (championship.status == 'ongoing' ||
                DateTime.now().isAfter(championship.startDate))
            ? DateTime.now()
            : championship.startDate;
        final startDateDisplay = AppDateFormatter.formatDayMonth(effectiveStartDate, isArabic ? 'ar' : 'en');

        return Scaffold(
          backgroundColor: VSPColors.background,
          appBar: AppBar(
            backgroundColor: VSPColors.surface,
            elevation: 0,
            centerTitle: true,
            title: Text(
              isArabic ? 'تفاصيل البطولة' : 'Championship Details',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            leading: const VSPBackButton(),
            actions: [
              IconButton(
                icon: const Icon(Iconsax.share_copy, color: VSPColors.accent, size: 20),
                onPressed: () {
                  SharingService.shareChampionshipObject(
                    context: context,
                    championship: championship,
                  );
                },
              ),
            ],
          ),
          body: Column(
            children: [
              if (isTeamRegistered && _myTeam != null) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(VSPSpacing.md, VSPSpacing.xs, VSPSpacing.md, 0),
                  padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: 10),
                  decoration: BoxDecoration(
                    color: VSPColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    border: Border.all(color: VSPColors.accent.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Iconsax.verify_copy, color: VSPColors.accent, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isArabic
                              ? 'فريقك [${_myTeam!.name}] مسجّل رسمياً في هذه البطولة '
                              : 'Your team [${_myTeam!.name}] is registered in this tournament ',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 1. Header Card
              ChampionshipDetailsHeader(
                championship: championship,
                isFull: isFull,
                startDateDisplay: startDateDisplay,
              ),

              // 2. Pill Segmented Switcher
              Container(
                margin: const EdgeInsets.symmetric(horizontal: VSPSpacing.md),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: VSPColors.surface,
                  borderRadius: BorderRadius.circular(VSPRadius.full),
                  border: Border.all(color: VSPColors.divider, width: 0.5),
                ),
                child: AnimatedBuilder(
                  animation: _tabController,
                  builder: (context, _) {
                    final currentIndex = _tabController.index;
                    return Row(
                      children: [
                        _buildPillTabItem(
                          index: 0,
                          currentIndex: currentIndex,
                          title: isArabic ? 'المباريات' : 'Matches',
                          icon: Iconsax.calendar_1_copy,
                        ),
                        _buildPillTabItem(
                          index: 1,
                          currentIndex: currentIndex,
                          title: isArabic ? 'الهدافين' : 'Scorers',
                          icon: Iconsax.award_copy,
                        ),
                        _buildPillTabItem(
                          index: 2,
                          currentIndex: currentIndex,
                          title: isArabic ? 'القواعد' : 'Rules',
                          icon: Iconsax.document_text_copy,
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),

              // 3. Tab Body Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // TAB 1: Matches & Standings
                    ChampionshipMatchesTab(
                      championship: championship,
                      matchesStream: _matchesStream,
                    ),

                    // TAB 2: Top Scorers
                    ChampionshipTopScorersTab(championshipId: championship.id),

                    // TAB 3: Rules & Details
                    ChampionshipRulesTab(championship: championship),
                  ],
                ),
              ),

              // 4. Floating Action / Bottom Button Area
              Container(
                padding: EdgeInsets.fromLTRB(
                  VSPSpacing.md,
                  VSPSpacing.sm,
                  VSPSpacing.md,
                  MediaQuery.of(context).padding.bottom + VSPSpacing.md,
                ),
                decoration: const BoxDecoration(
                  color: VSPColors.surface,
                  border: Border(top: BorderSide(color: VSPColors.divider, width: 0.5)),
                ),
                child: (isTeamRegistered && _myTeam != null)
                    ? PrimaryButton(
                        text: isArabic ? 'فريقك مسجّل بالبطولة | إدارة التشكيلة ' : 'Team Registered | Manage Roster ',
                        color: VSPColors.accent,
                        textColor: Colors.black,
                        onPressed: () async {
                          final updated = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ManageTournamentRosterScreen(
                                championship: championship,
                                team: _myTeam!,
                              ),
                            ),
                          );
                          if (updated == true && mounted) {
                            setState(() {});
                          }
                        },
                      )
                    : (isFull || championship.status == 'ongoing' || championship.status == 'completed')
                        ? PrimaryButton(
                            text: isFull && championship.status != 'ongoing' && championship.status != 'completed'
                                ? (isArabic ? 'مكتمل العدد (مشاهدة القرعة والجدول)' : 'Fully Booked (View Brackets)')
                                : AppLocalizations.of(context)!.viewBrackets,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TournamentBracketsScreen(
                                    championship: championship,
                                    isOwner: false,
                                  ),
                                ),
                              );
                            },
                          )
                        : PrimaryButton(
                            text: isArabic ? 'انضمام للبطولة الآن ' : AppLocalizations.of(context)!.join,
                            isLoading: _isJoining,
                            onPressed: _isJoining ? null : () => _handleJoin(championship),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPillTabItem({
    required int index,
    required int currentIndex,
    required String title,
    required IconData icon,
  }) {
    final isSelected = currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          _tabController.animateTo(index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? VSPColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(VSPRadius.full),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.black : VSPColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? Colors.black : VSPColors.textSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
