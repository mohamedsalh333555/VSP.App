import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/ui/components/vsp_card.dart';
import '../../../core/utils/app_error_handler.dart';
import '../../../core/services/database_service.dart';
import '../../../core/repositories/tournament_repository.dart';
import '../../../core/repositories/team_repository.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../data/models.dart';
import 'tournament_brackets_screen.dart'; // 🟢 IMPORT
import 'package:supabase_flutter/supabase_flutter.dart';

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

  // 🟢 Fetch teams first and show bracket preview popup
  Future<void> _handleStartTournament() async {
    if (_currentChampionship.joinedTeams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.noTeamsFound('')), backgroundColor: VSPColors.error),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final teams = await TournamentRepository().getTeamsByIds(_currentChampionship.joinedTeams);
      setState(() => _isLoading = false);
      if (!mounted) return;

      // Audit payments
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

  // 🟢 Show the Bracket Tree popup
  void _showBracketPreviewDialog(BuildContext context, List<Team> teams) {
    int totalTeams = teams.length;
    if (totalTeams < 2) return;

    // 1. Calculate power-of-2 details matching generateFixtures in TournamentRepository
    int targetP2 = 1;
    while (targetP2 * 2 <= totalTeams) {
      targetP2 *= 2;
    }
    int totalBracketRounds = (log(targetP2) / log(2)).round();
    int numOpeningMatches = totalTeams - targetP2;
    int numTeamsR0 = numOpeningMatches * 2;

    // Build the visual rounds list: each element is a list of matches (each match is a Map containing 'home' and 'away')
    List<List<Map<String, String>>> rounds = [];

    // Let's create an ordered copy of teams to pair sequentially (no need to shuffle for visual preview)
    final previewTeams = List<Team>.from(teams);

    // 2. Generate Opening Round (R0) if any
    if (numOpeningMatches > 0) {
      List<Map<String, String>> r0 = [];
      for (int m = 0; m < numOpeningMatches; m++) {
        String homeName = previewTeams[m * 2].name;
        String awayName = previewTeams[m * 2 + 1].name;
        r0.add({'home': homeName, 'away': awayName});
      }
      rounds.add(r0);
    }

    // 3. Generate main bracket rounds (R1...Final)
    // Round 1 (Power of 2 round)
    List<Map<String, String>> r1 = [];
    int matchCountR1 = targetP2 ~/ 2;
    for (int m = 0; m < matchCountR1; m++) {
      String homeName = '';
      String awayName = '';

      // Home Slot
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

      // Away Slot
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

    // Subsequent Rounds (Round 2 to Final)
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
            height: 350,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ...rounds.asMap().entries.map((entry) {
                    int roundIdx = entry.key;
                    List<Map<String, String>> roundMatches = entry.value;
                    
                    Widget roundColumn = SizedBox(
                      width: 160,
                      height: 350,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Text(
                              roundIdx == 0 && numOpeningMatches > 0
                                  ? 'جولة تمهيدية'
                                  : (roundIdx == rounds.length - 1 ? 'النهائي' : 'جولة ${numOpeningMatches > 0 ? roundIdx : roundIdx + 1}'),
                              style: const TextStyle(
                                color: VSPColors.accent,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: roundMatches.map((m) {
                                  return Container(
                                    width: 160,
                                    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: VSPColors.surfaceAlt,
                                      borderRadius: BorderRadius.circular(VSPRadius.md),
                                      border: Border.all(color: VSPColors.divider),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(m['home']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        const Divider(height: 10, color: Colors.white10),
                                        Text(m['away']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );

                    return Row(
                      children: [
                        roundColumn,
                        Icon(LucideIcons.chevronRight, color: VSPColors.accent, size: 14),
                      ],
                    );
                  }),

                  // Column for Trophy
                  SizedBox(
                    width: 150,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 140,
                          margin: const EdgeInsets.all(8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: VSPColors.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(VSPRadius.lg),
                            border: Border.all(color: VSPColors.accent, width: 1.5),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.trophy, color: VSPColors.accent, size: 32),
                              SizedBox(height: 8),
                              Text(
                                '🏆 البطل',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: VSPColors.accent),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'الفائز بالنهائي',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 10, color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                      _executeStartTournament();
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

  // 🟢 Run the actual start tournament and generate matches execution
  Future<void> _executeStartTournament() async {
    final teamCount = _currentChampionship.joinedTeams.length;

    // If teams are less than maxTeams, show force start confirmation
    if (teamCount < _currentChampionship.maxTeams) {
      final shouldForceStart = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: VSPColors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
          title: Text(AppLocalizations.of(context)!.forceStartTournament, style: Theme.of(context).textTheme.titleLarge),
          content: Text(
            AppLocalizations.of(context)!.forceStartWarning(teamCount, _currentChampionship.maxTeams),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.md),
          actions: [
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    text: AppLocalizations.of(context)!.cancel,
                    height: 44,
                    color: VSPColors.surfaceAlt,
                    textColor: VSPColors.textPrimary,
                    onPressed: () => Navigator.pop(ctx, false),
                  ),
                ),
                const SizedBox(width: VSPSpacing.md),
                Expanded(
                  child: PrimaryButton(
                    text: AppLocalizations.of(context)!.forceStart,
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
      // Run Algorithm
      await TournamentRepository().generateFixtures(_currentChampionship.id);
      
      // Update Local State
      setState(() {
        _currentChampionship = _currentChampionship.copyWith(status: 'ongoing');
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.drawGeneratedSuccess), backgroundColor: VSPColors.accent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: VSPColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showWinnerSelectionDialog(List<Team> teams) {
    String? selectedTeamId;
    String? selectedTeamName;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: VSPColors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
          title: Text(AppLocalizations.of(context)!.selectTournamentWinner, style: Theme.of(context).textTheme.titleLarge),
          content: teams.isEmpty 
            ? Text(AppLocalizations.of(context)!.noTeamsFound(''), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary))
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: teams.length,
                  itemBuilder: (context, index) {
                    final team = teams[index];
                    return RadioListTile<String>(
                      value: team.id,
                      groupValue: selectedTeamId,
                      activeColor: VSPColors.accent,
                      title: Text(team.name, style: Theme.of(context).textTheme.bodyMedium),
                      onChanged: (val) {
                        setModalState(() {
                          selectedTeamId = val;
                          selectedTeamName = team.name;
                        });
                      },
                    );
                  },
                ),
              ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.md),
          actions: [
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    text: AppLocalizations.of(context)!.cancel,
                    height: 48,
                    color: VSPColors.surfaceAlt,
                    textColor: VSPColors.textPrimary,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: VSPSpacing.md),
                Expanded(
                  child: PrimaryButton(
                    text: AppLocalizations.of(context)!.confirmSelections,
                    height: 48,
                    onPressed: selectedTeamId == null ? null : () {
                      Navigator.pop(context);
                      _crownChampion(selectedTeamId!, selectedTeamName!);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _crownChampion(String teamId, String teamName) async {
    setState(() => _isLoading = true);
    try {
      await TournamentRepository().crownChampion(_currentChampionship.id, teamId, teamName);
      setState(() {
         _currentChampionship = _currentChampionship.copyWith(status: 'completed');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddTeamManuallyDialog() {
    final nameCtrl = TextEditingController();
    final playerInputCtrl = TextEditingController();
    
    // قائمة الألوان الأساسية
    final List<Map<String, dynamic>> quickColors = [
      {'name': 'أبيض', 'value': '#FFFFFF', 'color': Colors.white},
      {'name': 'أحمر', 'value': '#EF4444', 'color': Colors.red},
      {'name': 'أزرق', 'value': '#3B82F6', 'color': Colors.blue},
      {'name': 'أخضر', 'value': '#22C55E', 'color': Colors.green},
      {'name': 'أصفر', 'value': '#F59E0B', 'color': Colors.amber},
      {'name': 'أسود', 'value': '#18181B', 'color': Colors.black},
    ];

    String selectedPrimaryColor = '#FFFFFF';
    List<String> offlinePlayerNames = []; // كشف أسماء لاعبي الفريق

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
        title: Text(AppLocalizations.of(context)!.addTeamManually, style: Theme.of(context).textTheme.titleLarge),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              final totalPlayers = offlinePlayerNames.length;
              final bool isValidRoster = totalPlayers >= 5 && totalPlayers <= 12;

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.manualRegistrationSub,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.textSecondary),
                    ),
                    const SizedBox(height: VSPSpacing.md),
                    
                    // 1. اسم الفريق
                    _buildInputLabel('اسم الفريق:'),
                    TextField(
                      controller: nameCtrl,
                      style: Theme.of(context).textTheme.bodyMedium,
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)!.teamName,
                        hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary),
                        filled: true,
                        fillColor: VSPColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(VSPRadius.md),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. لون قميص الفريق
                    _buildInputLabel('لون قميص الفريق الأساسي:'),
                    SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: quickColors.length,
                        itemBuilder: (context, index) {
                          final item = quickColors[index];
                          final isSelected = selectedPrimaryColor == item['value'];
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedPrimaryColor = item['value'];
                              });
                            },
                            child: Container(
                              width: 34,
                              height: 34,
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
                                  ? Icon(Icons.check, color: item['color'] == Colors.white ? Colors.black : Colors.white, size: 14) 
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 3. إدخال أسماء اللاعبين
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'كشف أسماء اللاعبين (من 5 إلى 12):',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          '$totalPlayers / 12',
                          style: TextStyle(
                            color: isValidRoster ? VSPColors.accent : Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: playerInputCtrl,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'اكتب اسم اللاعب واضغط إضافة...',
                              hintStyle: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                              filled: true,
                              fillColor: VSPColors.background,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(VSPRadius.md),
                                  borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
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
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                          ),
                          child: const Icon(Icons.add, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // عرض قائمة اللاعبين المضافين على شكل بطاقات صغيرة (Chips) قابلة للحذف
                    if (offlinePlayerNames.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: VSPColors.background.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(VSPRadius.md),
                        ),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: offlinePlayerNames.map((name) {
                            return Chip(
                              backgroundColor: VSPColors.surfaceAlt,
                              label: Text(name, style: const TextStyle(color: Colors.white, fontSize: 11)),
                              deleteIcon: const Icon(Icons.close, size: 12, color: Colors.redAccent),
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
                        '⚠️ يجب إضافة ${5 - totalPlayers} لاعبين إضافيين على الأقل لتفعيل خيار الحفظ.',
                        style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              );
            }
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.md),
        actions: [
          StatefulBuilder(
            builder: (context, setButtonState) {
              final bool canSave = nameCtrl.text.trim().isNotEmpty && offlinePlayerNames.length >= 5;
              
              return Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      text: AppLocalizations.of(context)!.cancel,
                      height: 44,
                      color: VSPColors.surfaceAlt,
                      textColor: VSPColors.textPrimary,
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                  const SizedBox(width: VSPSpacing.md),
                  Expanded(
                    child: PrimaryButton(
                      text: AppLocalizations.of(context)!.addMember.split(' ').first,
                      height: 44,
                      onPressed: !canSave ? null : () async {
                        final teamName = nameCtrl.text.trim();
                        Navigator.pop(ctx);
                        
                        setState(() => _isLoading = true);
                        try {
                          final auth = Provider.of<AuthProvider>(context, listen: false);
                          final currentUserId = auth.currentUser?.uid ?? auth.currentUser?.id ?? '';

                          // 1. إنشاء الفريق في جدول teams
                          final teamId = await TeamRepository().createTeam({
                            'name': teamName,
                            'captainName': AppLocalizations.of(context)!.manualRegistration,
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
                            // 2. تسجيل انضمام الفريق في جدول البطولة الرئيسي
                            await TournamentRepository().joinChampionship(
                              _currentChampionship.id,
                              teamId,
                              skipMemberCheck: true,
                            );

                            // 3. أتمتة حفظ كشف أسماء اللاعبين المضافين في جدول championship_rosters الخاص بالبطولة
                            await Supabase.instance.client.from('championship_rosters').insert({
                              'championship_id': _currentChampionship.id,
                              'team_id': teamId,
                              'player_ids': [], // لا يوجد معرفات مستخدمين أونلاين
                              'guest_names': offlinePlayerNames, // حفظ كشف الأسماء هنا!
                            });

                            // تحديث الواجهة فوراً
                            setState(() {
                              _currentChampionship = _currentChampionship.copyWith(
                                joinedTeams: [..._currentChampionship.joinedTeams, teamId],
                              );
                            });

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(AppLocalizations.of(context)!.teamCreatedSuccess),
                                  backgroundColor: VSPColors.success,
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: VSPColors.error),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _isLoading = false);
                        }
                      },
                    ),
                  ),
                ],
              );
            }
          ),
        ],
      ),
    );
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

  // â”€â”€ Toggle Paid Status â”€â”€
  Future<void> _togglePaymentStatus(String teamId) async {
    final isPaid = _currentChampionship.paidTeams.contains(teamId);
    try {
      await TournamentRepository().toggleTeamPayment(
        championshipId: _currentChampionship.id,
        teamId: teamId,
        isPaid: !isPaid, // Toggle
      );
      // Update local state
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: VSPColors.error),
        );
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
          icon: Icon(LucideIcons.chevronLeft, color: VSPColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_currentChampionship.name, style: Theme.of(context).textTheme.displayLarge),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Team>>(
        future: TournamentRepository().getTeamsByIds(_currentChampionship.joinedTeams),
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
                        _buildInfoItem(AppLocalizations.of(context)!.statusLabel, _currentChampionship.status.toUpperCase(), 
                          color: _currentChampionship.status == 'completed' ? VSPColors.error : VSPColors.accent),
                        _buildInfoItem(AppLocalizations.of(context)!.categoryLabel, _currentChampionship.type),
                      ],
                    ),
                    const Divider(color: VSPColors.divider, height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildInfoItem(AppLocalizations.of(context)!.datesLabel, '${DateFormat('MMM d').format(_currentChampionship.startDate)} - ${DateFormat('MMM d').format(_currentChampionship.endDate)}'),
                        _buildInfoItem(AppLocalizations.of(context)!.teamsLabel, '${_currentChampionship.joinedTeams.length} / ${_currentChampionship.maxTeams}'),
                      ],
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.lg, vertical: VSPSpacing.sm),
                child: Row(
                  children: [
                    Icon(LucideIcons.users, color: VSPColors.textSecondary, size: 18),
                    const SizedBox(width: 8),
                    Text(AppLocalizations.of(context)!.joinedTeamsLabel, style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: VSPColors.textSecondary, 
                      fontWeight: FontWeight.bold
                    )),
                    const Spacer(),
                    if (_currentChampionship.status == 'open' && _currentChampionship.joinedTeams.length < _currentChampionship.maxTeams)
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
                              Icon(LucideIcons.userPlus, color: VSPColors.accent, size: 14),
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
                child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: teams.length,
                        itemBuilder: (context, index) {
                          final team = teams[index];
                          final isPaid = _currentChampionship.paidTeams.contains(team.id);
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(VSPSpacing.sm),
                            decoration: BoxDecoration(
                              color: VSPColors.surface,
                              borderRadius: BorderRadius.circular(VSPRadius.md),
                              border: Border.all(color: VSPColors.divider),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundImage: team.captainImageUrl.isNotEmpty
                                      ? NetworkImage(team.captainImageUrl)
                                      : null,
                                  backgroundColor: VSPColors.surfaceAlt,
                                  child: team.captainImageUrl.isEmpty
                                      ? Icon(LucideIcons.users, color: VSPColors.textSecondary, size: 20)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(team.name, style: Theme.of(context).textTheme.titleSmall),
                                      Text(team.captainName, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary)),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          // Entry Fee Payment Badge
                                          GestureDetector(
                                            onTap: () => _togglePaymentStatus(team.id),
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 250),
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                                                    isPaid ? LucideIcons.checkCircle : LucideIcons.clock,
                                                    size: 14,
                                                    color: isPaid ? VSPColors.success : VSPColors.warning,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    isPaid ? AppLocalizations.of(context)!.paid : AppLocalizations.of(context)!.pending,
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
                                          if (_currentChampionship.status == 'open') ...[
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: const Icon(LucideIcons.trash2, color: VSPColors.error, size: 18),
                                              onPressed: () async {
                                                final confirm = await showDialog<bool>(
                                                  context: context,
                                                  builder: (ctx) => AlertDialog(
                                                    backgroundColor: VSPColors.surface,
                                                    title: const Text('إلغاء انضمام الفريق', style: TextStyle(color: Colors.white)),
                                                    content: Text('هل أنت متأكد من إلغاء انضمام فريق ${team.name} للبطولة؟'),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () => Navigator.pop(ctx, false),
                                                        child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
                                                      ),
                                                      TextButton(
                                                        onPressed: () => Navigator.pop(ctx, true),
                                                        child: const Text('تأكيد الحذف', style: TextStyle(color: VSPColors.error, fontWeight: FontWeight.bold)),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                                if (confirm == true) {
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
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(content: Text('تم إلغاء انضمام الفريق بنجاح.'), backgroundColor: VSPColors.success),
                                                        );
                                                      }
                                                    }
                                                  } catch (e) {
                                                    if (mounted) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(content: Text('Error: $e'), backgroundColor: VSPColors.error),
                                                      );
                                                    }
                                                  } finally {
                                                    if (mounted) setState(() => _isLoading = false);
                                                  }
                                                }
                                              },
                                            ),
                                          ],
                                        ],
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

              Container(
                padding: EdgeInsets.fromLTRB(VSPSpacing.md, VSPSpacing.md, VSPSpacing.md, VSPSpacing.md + MediaQuery.of(context).padding.bottom),
                decoration: BoxDecoration(
                  color: VSPColors.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_currentChampionship.status == 'open')
                      PrimaryButton(
                        text: AppLocalizations.of(context)!.generateDrawStart,
                        isLoading: _isLoading,
                        onPressed: _handleStartTournament,
                      ),
                    
                    if (_currentChampionship.status != 'open')
                      PrimaryButton(
                        text: AppLocalizations.of(context)!.viewBrackets.toUpperCase(),
                        color: VSPColors.accent.withValues(alpha: 0.1),
                        textColor: VSPColors.accent,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TournamentBracketsScreen(
                                championship: _currentChampionship,
                                isOwner: true, 
                              ),
                            ),
                          );
                        },
                      ),
                      
                    if (_currentChampionship.status == 'ongoing') ...[
                      const SizedBox(height: 12),
                      PrimaryButton(
                        text: AppLocalizations.of(context)!.manualCrownChampion,
                        color: VSPColors.surfaceAlt,
                        textColor: VSPColors.textSecondary,
                        onPressed: () => _showWinnerSelectionDialog(teams),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color ?? VSPColors.textPrimary, fontWeight: FontWeight.bold)),
      ],
    );
  }
}


