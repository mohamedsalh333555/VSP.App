import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/team_repository.dart';
import '../../../core/repositories/tournament_repository.dart';
import '../../../core/services/sharing_service.dart';
import '../../../core/utils/app_date_formatter.dart';
import '../../../shared/widgets/vsp_countdown_timer.dart';
import '../../../data/models.dart';
import '../../../core/services/location_service.dart';
import '../../../core/constants/egypt_governorates.dart';
import '../../owner/screens/tournament_brackets_screen.dart';
import 'championship_checkout_screen.dart';

class ChampionshipDetailsScreen extends StatefulWidget {
  final Championship championship;

  const ChampionshipDetailsScreen({super.key, required this.championship});

  @override
  State<ChampionshipDetailsScreen> createState() => _ChampionshipDetailsScreenState();
}

class _ChampionshipDetailsScreenState extends State<ChampionshipDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isJoining = false;
  int _statsSubIndex = 0; // 0: Top Scorers, 1: Clean Sheets

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }



  Future<void> _handleJoin() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.loginToJoinError)));
      return;
    }

    setState(() => _isJoining = true);

    try {
      final userPhone = auth.userModel?.phone ?? '';
      final team = await TeamRepository().getTeamByCaptainPhone(userPhone);

      if (team == null) {
        if (mounted) {
          _showErrorDialog(AppLocalizations.of(context)!.captainRequiredError);
        }
        return;
      }

      if (widget.championship.joinedTeams.contains(team.id)) {
        if (mounted) {
           _showErrorDialog(AppLocalizations.of(context)!.alreadyJoinedError);
        }
        return;
      }

      // 🛡️ GPS GEOFENCING GUARD: Verify physical GPS location when joining a tournament in a different governorate
      if (!mounted) return;
      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
      final champGovRaw = widget.championship.governorate.trim();
      final playerGovRaw = auth.governorate.trim();

      final champGovStd = EgyptGovernorates.resolveGoogleName(champGovRaw) ?? champGovRaw;
      final playerGovStd = EgyptGovernorates.resolveGoogleName(playerGovRaw) ?? playerGovRaw;

      if (champGovStd.isNotEmpty && champGovStd.toLowerCase() != playerGovStd.toLowerCase()) {
        final (position, gpsGov) = await LocationService().getThrottledLocation(force: true);

        if (gpsGov == 'mock_location_detected') {
          if (mounted) {
            _showErrorDialog(isArabic 
                ? 'تنبيه أمني: تم اكتشاف استخدام موقع وهمي (Mock Location). لا يمكن الانضمام للبطولة.' 
                : 'Security Alert: Mock location detected. Cannot join tournament.');
          }
          return;
        }

        final resolvedGpsGov = (gpsGov != null && gpsGov.isNotEmpty)
            ? (EgyptGovernorates.resolveGoogleName(gpsGov) ?? gpsGov)
            : null;

        if (resolvedGpsGov == null || resolvedGpsGov.toLowerCase() != champGovStd.toLowerCase()) {
          if (mounted) {
            _showErrorDialog(isArabic 
                ? 'عذراً! هذه البطولة مقامة في محافظة [$champGovRaw]. يتطلب النظام التحقق التلقائي من تواجدك الفعلي في نفس المحافظة عبر إذن الموقع (GPS) للانضمام.' 
                : 'Sorry! This tournament is hosted in [$champGovRaw]. System requires active GPS verification confirming your presence in that governorate to join.');
          }
          return;
        }
      }

      if (!mounted) return;
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => ChampionshipCheckoutScreen(
            championship: widget.championship,
            team: team,
          ),
        ),
      );

      if (result == true && mounted) {
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
        title: Text(AppLocalizations.of(context)!.errorLabel, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: VSPColors.error)),
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
    final championship = widget.championship;
    final isFull = championship.isFull || championship.joinedTeams.length >= championship.maxTeams;

    final DateTime effectiveStartDate = (championship.status == 'ongoing' || DateTime.now().isAfter(championship.startDate)) 
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
        leading: IconButton(
          icon: Icon(
            isArabic ? Iconsax.arrow_right_3_copy : Iconsax.arrow_left_2_copy,
            color: VSPColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
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
          // 🏆 1. Modern Glassmorphic Header Card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(VSPSpacing.md),
            padding: const EdgeInsets.all(VSPSpacing.md),
            decoration: BoxDecoration(
              color: VSPColors.surface,
              borderRadius: BorderRadius.circular(VSPRadius.xl),
              border: Border.all(color: VSPColors.divider, width: 0.5),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: VSPColors.accent, width: 1.5),
                      ),
                      child: ClipOval(
                        child: championship.logoUrl.isNotEmpty
                            ? Image.network(championship.logoUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Iconsax.cup_copy, color: VSPColors.accent))
                            : const Icon(Iconsax.cup_copy, color: VSPColors.accent, size: 24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            championship.name,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Iconsax.location_copy, color: VSPColors.textSecondary, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                championship.governorate.isNotEmpty ? championship.governorate : (isArabic ? 'مصر' : 'Egypt'),
                                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isFull || championship.status != 'open')
                            ? VSPColors.error.withValues(alpha: 0.15)
                            : VSPColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(VSPRadius.sm),
                      ),
                      child: Text(
                        isFull
                            ? (isArabic ? 'مكتمل العدد' : 'Full')
                            : (championship.status == 'open' ? (isArabic ? 'مفتوح للتسجيل' : 'Open') : championship.status.toUpperCase()),
                        style: TextStyle(
                          color: (isFull || championship.status != 'open') ? VSPColors.error : VSPColors.success,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                if (championship.status == 'open' && !isFull && championship.startDate.isAfter(DateTime.now())) ...[
                  const SizedBox(height: 12),
                  VSPCountdownTimer(targetDate: championship.startDate),
                ],
                const SizedBox(height: 16),
                // 📊 Stats Grid
                Row(
                  children: [
                    _buildStatCard(
                      icon: Iconsax.cup_copy,
                      iconColor: VSPColors.accent,
                      label: isArabic ? 'الجائزة الكبرى' : 'Grand Prize',
                      value: '${championship.grandPrize.toInt()} ${isArabic ? "ج.م" : "EGP"}',
                    ),
                    const SizedBox(width: 8),
                    _buildStatCard(
                      icon: Iconsax.card_copy,
                      iconColor: VSPColors.accent,
                      label: isArabic ? 'رسوم الاشتراك' : 'Entry Fee',
                      value: '${championship.entryFee.toInt()} ${isArabic ? "ج.م" : "EGP"}',
                    ),
                    const SizedBox(width: 8),
                    _buildStatCard(
                      icon: Iconsax.calendar_1_copy,
                      iconColor: VSPColors.accent,
                      label: isArabic ? 'الموعد' : 'Date',
                      value: startDateDisplay,
                    ),
                    const SizedBox(width: 8),
                    _buildStatCard(
                      icon: Iconsax.people_copy,
                      iconColor: VSPColors.accent,
                      label: isArabic ? 'الفرق' : 'Teams',
                      value: '${championship.joinedTeams.length}/${championship.maxTeams}',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 📑 2. VSP Design System Pill Segmented Switcher
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
                      title: isArabic ? 'الجدول والقرعة' : 'Brackets',
                      icon: Iconsax.calendar_1_copy,
                    ),
                    _buildPillTabItem(
                      index: 1,
                      currentIndex: currentIndex,
                      title: isArabic ? 'الهدافين' : 'Scorers',
                      icon: Iconsax.cup_copy,
                    ),
                    _buildPillTabItem(
                      index: 2,
                      currentIndex: currentIndex,
                      title: isArabic ? 'التفاصيل والقواعد' : 'Rules',
                      icon: Iconsax.document_text_copy,
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // 📄 3. Tab Body Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 📅 TAB 1: Timeline & Brackets
                _buildTimelineAndBracketsTab(isArabic),

                // ⚽ TAB 2: Top Scorers Leaderboard
                _buildTopScorersTab(isArabic),

                // 📜 TAB 3: Rules & Details
                _buildRulesAndInfoTab(isArabic),
              ],
            ),
          ),

          // 🔘 4. Floating Action / Bottom Button Area
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
            child: (isFull || championship.status == 'ongoing' || championship.status == 'completed')
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
                    text: isArabic ? 'انضمام للبطولة الآن ⚽' : AppLocalizations.of(context)!.join,
                    isLoading: _isJoining,
                    onPressed: _handleJoin,
                  ),
          ),
        ],
      ),
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

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        decoration: BoxDecoration(
          color: VSPColors.background,
          borderRadius: BorderRadius.circular(VSPRadius.md),
          border: Border.all(color: VSPColors.divider, width: 0.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 16),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 9),
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStandingsSection(bool isArabic) {
    final isGroupOrLeague = widget.championship.type == 'League' || widget.championship.type == 'GroupsAndKnockout';
    if (!isGroupOrLeague) return const SizedBox.shrink();

    final isGroups = widget.championship.type == 'GroupsAndKnockout';
    final numGroups = widget.championship.numberOfGroups;
    final groupNames = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Iconsax.award_copy, color: VSPColors.accent, size: 20),
            const SizedBox(width: 8),
            Text(
              isArabic ? 'جدول الترتيب الحي' : 'Live Standings Table',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (isGroups) ...[
          for (int g = 0; g < numGroups; g++) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 6),
              child: Text(
                isArabic ? 'المجموعة ${groupNames[g]}' : 'Group ${groupNames[g]}',
                style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            _buildStandingsTableWidget(context, widget.championship.id, groupName: groupNames[g]),
            const SizedBox(height: 12),
          ],
        ] else ...[
          _buildStandingsTableWidget(context, widget.championship.id),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildStandingsTableWidget(BuildContext context, String championshipId, {String? groupName}) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: TournamentRepository().getChampionshipStandings(championshipId, groupName: groupName),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: VSPColors.accent)));
        }

        final rows = snapshot.data ?? [];
        if (rows.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(12)),
            child: Center(
              child: Text(
                isArabic ? 'لا توجد مباريات مسجلة بعد' : 'No recorded matches yet',
                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
              ),
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: VSPColors.surface,
            borderRadius: BorderRadius.circular(VSPRadius.md),
            border: Border.all(color: VSPColors.divider),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 14,
              headingRowHeight: 40,
              dataRowMaxHeight: 44,
              columns: [
                DataColumn(label: Text(isArabic ? '#' : '#', style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold))),
                DataColumn(label: Text(isArabic ? 'الفريق' : 'Team', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                DataColumn(label: Text(isArabic ? 'لعب' : 'P', style: const TextStyle(color: Colors.white70))),
                DataColumn(label: Text(isArabic ? 'فاز' : 'W', style: const TextStyle(color: Colors.white70))),
                DataColumn(label: Text(isArabic ? 'تعادل' : 'D', style: const TextStyle(color: Colors.white70))),
                DataColumn(label: Text(isArabic ? 'خسر' : 'L', style: const TextStyle(color: Colors.white70))),
                DataColumn(label: Text(isArabic ? 'له' : 'GF', style: const TextStyle(color: Colors.white70))),
                DataColumn(label: Text(isArabic ? 'عليه' : 'GA', style: const TextStyle(color: Colors.white70))),
                DataColumn(label: Text(isArabic ? '+/-' : 'GD', style: const TextStyle(color: Colors.white70))),
                DataColumn(label: Text(isArabic ? 'النقاط' : 'PTS', style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold))),
              ],
              rows: rows.asMap().entries.map((entry) {
                final rank = entry.key + 1;
                final r = entry.value;

                return DataRow(
                  cells: [
                    DataCell(Text('$rank', style: TextStyle(color: rank <= 2 ? VSPColors.accent : Colors.white, fontWeight: FontWeight.bold))),
                    DataCell(Text(r['team_name']?.toString() ?? 'Team', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    DataCell(Text('${r['played'] ?? 0}', style: const TextStyle(color: Colors.white70))),
                    DataCell(Text('${r['won'] ?? 0}', style: const TextStyle(color: Colors.green))),
                    DataCell(Text('${r['drawn'] ?? 0}', style: const TextStyle(color: Colors.orange))),
                    DataCell(Text('${r['lost'] ?? 0}', style: const TextStyle(color: Colors.red))),
                    DataCell(Text('${r['goals_for'] ?? 0}', style: const TextStyle(color: Colors.white70))),
                    DataCell(Text('${r['goals_against'] ?? 0}', style: const TextStyle(color: Colors.white70))),
                    DataCell(Text('${r['goal_difference'] ?? 0}', style: const TextStyle(color: Colors.white70))),
                    DataCell(Text('${r['points'] ?? 0}', style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 14))),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimelineAndBracketsTab(bool isArabic) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(VSPSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🏆 Live Standings Table (For League & Group Systems)
          _buildStandingsSection(isArabic),

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
                    championship: widget.championship,
                    isOwner: false,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: VSPSpacing.lg),

          // Live Match Fixtures Stream
          StreamBuilder<List<TournamentMatch>>(
            stream: TournamentRepository().getTournamentMatches(widget.championship.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(VSPSpacing.xl),
                  decoration: BoxDecoration(
                    color: VSPColors.surface,
                    borderRadius: BorderRadius.circular(VSPRadius.lg),
                    border: Border.all(color: VSPColors.divider, width: 0.5),
                  ),
                  child: Column(
                    children: [
                      const Icon(Iconsax.calendar_1_copy, color: VSPColors.textSecondary, size: 36),
                      const SizedBox(height: 12),
                      Text(
                        isArabic ? 'لم يتم إعداد المباريات بعد' : 'No matches scheduled yet',
                        style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              final matches = snapshot.data!;

              // Helper: Arabic round label
              String roundLabelAr(int roundIndex) {
                switch (roundIndex) {
                  case 0: return 'المباراة النهائية';
                  case 1: return 'نصف النهائي';
                  case 2: return 'ربع النهائي';
                  case 3: return 'دور الـ 16';
                  case 4: return 'دور الـ 32';
                  case 5: return 'دور الـ 64';
                  default: return 'الجولة ${roundIndex + 1}';
                }
              }

              // Group matches by roundIndex (highest roundIndex = earliest round)
              final rounds = <int>{};
              for (final m in matches) { rounds.add(m.roundIndex); }
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
                            scheduledLabel = '${t.day}/${t.month}  ${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';
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
                                  decoration: BoxDecoration(
                                    color: VSPColors.surfaceAlt,
                                    borderRadius: const BorderRadius.only(
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
                                            const Icon(Iconsax.calendar_1_copy, size: 11, color: VSPColors.textSecondary),
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
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
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
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
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

  Widget _buildTopScorersTab(bool isArabic) {
    return Column(
      children: [
        // Sub-switcher for Scorers vs Clean Sheets
        Container(
          margin: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: 4),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: VSPColors.surface,
            borderRadius: BorderRadius.circular(VSPRadius.md),
            border: Border.all(color: VSPColors.divider, width: 0.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _statsSubIndex = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _statsSubIndex == 0 ? VSPColors.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(VSPRadius.sm),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Iconsax.cup_copy, size: 14, color: _statsSubIndex == 0 ? Colors.black : VSPColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          isArabic ? 'ترتيب الهدافين' : 'Top Scorers',
                          style: TextStyle(
                            color: _statsSubIndex == 0 ? Colors.black : VSPColors.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _statsSubIndex = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _statsSubIndex == 1 ? VSPColors.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(VSPRadius.sm),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Iconsax.security_safe_copy, size: 14, color: _statsSubIndex == 1 ? Colors.black : VSPColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          isArabic ? 'أقوى دفاع (كلين شيت)' : 'Clean Sheets',
                          style: TextStyle(
                            color: _statsSubIndex == 1 ? Colors.black : VSPColors.textSecondary,
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
        ),

        Expanded(
          child: _statsSubIndex == 0
              ? _buildScorersList(isArabic)
              : _buildCleanSheetsList(isArabic),
        ),
      ],
    );
  }

  Widget _buildScorersList(bool isArabic) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: TournamentRepository().getTopScorersForChampionship(widget.championship.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
        }

        final scorers = snapshot.data ?? [];
        if (scorers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Iconsax.award_copy, color: VSPColors.textSecondary, size: 40),
                const SizedBox(height: 12),
                Text(
                  isArabic ? 'لم يتم تسجيل أهداف بعد في هذه البطولة' : 'No goals recorded yet in this tournament',
                  style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(VSPSpacing.md),
          itemCount: scorers.length,
          itemBuilder: (context, index) {
            final item = scorers[index];
            final bool isOwnGoalCategory = item['isOwnGoalCategory'] == true || item['name'] == 'أهداف عكسية';
            final rank = index + 1;
            final String name = item['name'] ?? '';
            final String team = item['team'] ?? '';
            final int goals = item['goals'] as int? ?? 0;

            Color rankColor = VSPColors.surfaceAlt;
            String rankEmoji = '#$rank';
            if (!isOwnGoalCategory) {
              if (rank == 1) {
                rankColor = VSPColors.accent;
                rankEmoji = '🥇';
              } else if (rank == 2) {
                rankColor = VSPColors.accent.withValues(alpha: 0.7);
                rankEmoji = '🥈';
              } else if (rank == 3) {
                rankColor = VSPColors.accent.withValues(alpha: 0.5);
                rankEmoji = '🥉';
              }
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(color: VSPColors.divider, width: 0.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isOwnGoalCategory ? VSPColors.error.withValues(alpha: 0.15) : rankColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: isOwnGoalCategory
                          ? const Icon(Iconsax.repeat_copy, color: VSPColors.error, size: 18)
                          : Text(
                              rankEmoji,
                              style: TextStyle(
                                color: rank <= 3 ? rankColor : VSPColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: rank <= 3 ? 16 : 12,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isOwnGoalCategory ? (isArabic ? 'أهداف عكسية' : 'Own Goals') : name,
                          style: TextStyle(
                            color: isOwnGoalCategory ? Colors.white70 : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (team.isNotEmpty && team != 'فريق غير محدد') ...[
                          const SizedBox(height: 2),
                          Text(
                            team,
                            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOwnGoalCategory ? VSPColors.error.withValues(alpha: 0.15) : VSPColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(VSPRadius.sm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(isOwnGoalCategory ? Iconsax.repeat_copy : Iconsax.cup_copy, color: isOwnGoalCategory ? VSPColors.error : VSPColors.accent, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          '$goals ${isArabic ? "أهداف" : "goals"}',
                          style: TextStyle(color: isOwnGoalCategory ? VSPColors.error : VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCleanSheetsList(bool isArabic) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: TournamentRepository().getCleanSheetsForChampionship(widget.championship.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
        }

        final cleanSheets = snapshot.data ?? [];
        if (cleanSheets.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Iconsax.security_safe_copy, color: VSPColors.textSecondary, size: 40),
                const SizedBox(height: 12),
                Text(
                  isArabic ? 'لم يتم تسجيل مباريات بشباك نظيفة بعد' : 'No clean sheets recorded yet',
                  style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(VSPSpacing.md),
          itemCount: cleanSheets.length,
          itemBuilder: (context, index) {
            final item = cleanSheets[index];
            final rank = index + 1;
            final String team = item['team'] ?? '';
            final int count = item['clean_sheets'] as int? ?? 0;

            Color rankColor = VSPColors.surfaceAlt;
            String rankEmoji = '#$rank';
            if (rank == 1) {
              rankColor = VSPColors.accent;
              rankEmoji = '🥇';
            } else if (rank == 2) {
              rankColor = VSPColors.accent.withValues(alpha: 0.7);
              rankEmoji = '🥈';
            } else if (rank == 3) {
              rankColor = VSPColors.accent.withValues(alpha: 0.5);
              rankEmoji = '🥉';
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(color: VSPColors.divider, width: 0.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: rankColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        rankEmoji,
                        style: TextStyle(
                          color: rank <= 3 ? rankColor : VSPColors.textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: rank <= 3 ? 16 : 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      team,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: VSPColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(VSPRadius.sm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Iconsax.security_safe_copy, color: VSPColors.accent, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          '$count ${isArabic ? "مباراة نظيفة" : "clean sheets"}',
                          style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRulesAndInfoTab(bool isArabic) {
    final championship = widget.championship;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(VSPSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoSection(
            isArabic ? 'وصف عن البطولة' : 'About Tournament',
            championship.rules.isNotEmpty
                ? championship.rules
                : (isArabic ? 'بطولة رسمية تنافسية لفرق كرة القدم بمدينة ${championship.governorate.isNotEmpty ? championship.governorate : "مصر"}.' : 'Official competitive football tournament.'),
          ),
          const SizedBox(height: 16),
          _buildInfoSection(
            isArabic ? 'قوانين المباريات' : 'Match Rules',
            isArabic
                ? '• مدة المباراة: ${championship.matchDuration} دقيقة.\n'
                  '• عدد اللاعبين الأساسيين لكل فريق: ${championship.minPlayersPerTeam} لاعبين.\n'
                  '• الحد الأقصى للاعبين في التشكيلة: ${championship.maxPlayersPerTeam} لاعبين.\n'
                  '• احتساب النقاط: ${championship.winningPoints} نقاط للفوز، ${championship.drawPoints} نقطة للتعادل، ${championship.lossPoints} للهزيمة.'
                : '• Match Duration: ${championship.matchDuration} mins.\n'
                  '• Min Players: ${championship.minPlayersPerTeam}.\n'
                  '• Max Players: ${championship.maxPlayersPerTeam}.\n'
                  '• Points: ${championship.winningPoints} Win / ${championship.drawPoints} Draw / ${championship.lossPoints} Loss.',
          ),
          const SizedBox(height: 16),
          _buildInfoSection(
            isArabic ? 'تعليمات وإرشادات مهمة' : 'Important Instructions',
            isArabic
                ? '• يرجى التواجد بالملعب قبل موعد المباراة بـ 15 دقيقة على الأقل.\n'
                  '• يجب التزام جميع الفرق بالزي الرياضي الموحد.\n'
                  '• أي بطاقة حمراء تؤدي لإيقاف اللاعب المباراة التالية.'
                : '• Please arrive 15 minutes prior to kickoff.\n'
                  '• Unified sports gear is required.\n'
                  '• Red card suspends player for next match.',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(VSPSpacing.md),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12, height: 1.6),
          ),
        ],
      ),
    );
  }

}
