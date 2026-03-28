import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/ui/components/vsp_card.dart';
import '../../../core/services/database_service.dart';
import '../../../core/repositories/tournament_repository.dart';
import '../../../data/models.dart';
import 'tournament_brackets_screen.dart'; // 🟢 IMPORT

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

  // 🟢 UPDATED: Generate Fixtures Logic (with Force Start option)
  Future<void> _handleStartTournament() async {
    final teamCount = _currentChampionship.joinedTeams.length;

    // If teams are less than maxTeams, show force start confirmation
    if (teamCount < _currentChampionship.maxTeams) {
      final shouldForceStart = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: VSPColors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
          title: Text('Force Start Tournament?', style: Theme.of(context).textTheme.titleLarge),
          content: Text(
            'Tournament is not full ($teamCount / ${_currentChampionship.maxTeams} teams). '
            'Are you sure you want to force start?\n\n'
            'Make sure you have 4, 8, 16, or 32 teams for the brackets to work correctly.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.md),
          actions: [
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    text: 'Cancel',
                    height: 44,
                    color: VSPColors.surfaceAlt,
                    textColor: VSPColors.textPrimary,
                    onPressed: () => Navigator.pop(ctx, false),
                  ),
                ),
                const SizedBox(width: VSPSpacing.md),
                Expanded(
                  child: PrimaryButton(
                    text: 'Force Start',
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
          const SnackBar(content: Text('Draw Generated & Tournament Started!'), backgroundColor: VSPColors.accent),
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
          title: Text('Select Tournament Winner', style: Theme.of(context).textTheme.titleLarge),
          content: teams.isEmpty 
            ? Text('No teams joined yet.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary))
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
                    text: 'Cancel',
                    height: 48,
                    color: VSPColors.surfaceAlt,
                    textColor: VSPColors.textPrimary,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: VSPSpacing.md),
                Expanded(
                  child: PrimaryButton(
                    text: 'Confirm',
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
        title: Text('Add Team Manually', style: Theme.of(context).textTheme.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Register a team that signed up via phone or in-person.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.textSecondary),
            ),
            const SizedBox(height: VSPSpacing.md),
            TextField(
              controller: nameCtrl,
              style: Theme.of(context).textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Team name',
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary),
                filled: true,
                fillColor: VSPColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(VSPRadius.md),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.md),
        actions: [
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  text: 'Cancel',
                  height: 44,
                  color: VSPColors.surfaceAlt,
                  textColor: VSPColors.textPrimary,
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
              const SizedBox(width: VSPSpacing.md),
              Expanded(
                child: PrimaryButton(
                  text: 'Add',
                  height: 44,
                  onPressed: () async {
                    final teamName = nameCtrl.text.trim();
                    if (teamName.isEmpty) return;
                    Navigator.pop(ctx);
                    
                    setState(() => _isLoading = true);
                    try {
                      // Create a placeholder team doc in Firestore
                      final teamId = await DatabaseService().createTeam({
                        'name': teamName,
                        'captainId': 'manual_entry',
                        'captainName': 'Manual Registration',
                        'captainImage': '',
                        'sport': _currentChampionship.sportType,
                        'members': [],
                        'memberNames': [],
                        'memberImages': [],
                        'createdAt': DateTime.now().toIso8601String(),
                      });
                      
                      if (teamId != null) {
                        // Join the team to the championship
                        await TournamentRepository().joinChampionship(
                          _currentChampionship.id,
                          teamId,
                          skipMemberCheck: true,
                        );
                        // Refresh state
                        setState(() {
                          _currentChampionship = _currentChampionship.copyWith(
                            joinedTeams: [..._currentChampionship.joinedTeams, teamId],
                          );
                        });
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Team "$teamName" added!'),
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
          icon: const Icon(Icons.arrow_back_ios, color: VSPColors.textPrimary),
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
                        _buildInfoItem('STATUS', _currentChampionship.status.toUpperCase(), 
                          color: _currentChampionship.status == 'completed' ? VSPColors.error : VSPColors.accent),
                        _buildInfoItem('CATEGORY', _currentChampionship.type),
                      ],
                    ),
                    const Divider(color: VSPColors.divider, height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildInfoItem('DATES', '${DateFormat('MMM d').format(_currentChampionship.startDate)} - ${DateFormat('MMM d').format(_currentChampionship.endDate)}'),
                        _buildInfoItem('TEAMS', '${_currentChampionship.joinedTeams.length} / ${_currentChampionship.maxTeams}'),
                      ],
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.lg, vertical: VSPSpacing.sm),
                child: Row(
                  children: [
                    const Icon(Icons.groups, color: VSPColors.textSecondary, size: 18),
                    const SizedBox(width: 8),
                    Text('Joined Teams', style: Theme.of(context).textTheme.labelLarge?.copyWith(
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
                              const Icon(Icons.person_add_alt_1, color: VSPColors.accent, size: 14),
                              const SizedBox(width: 4),
                              Text('Add Team', style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
                                  backgroundImage: NetworkImage(team.captainImageUrl),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(team.name, style: Theme.of(context).textTheme.titleSmall),
                                      Text(team.captainName, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary)),
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
                        text: 'GENERATE DRAW & START',
                        isLoading: _isLoading,
                        onPressed: _handleStartTournament,
                      ),
                    
                    if (_currentChampionship.status != 'open')
                      PrimaryButton(
                        text: 'VIEW BRACKETS',
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
                        text: 'MANUAL CROWN CHAMPION',
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
