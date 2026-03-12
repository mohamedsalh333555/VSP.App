import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/shimmer_image.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../../core/providers/booking_provider.dart';
import '../../../../core/services/database_service.dart';
import '../../../data/models.dart';
import 'booking_confirmation_screen.dart';

class ChallengeSelectTeamScreen extends StatefulWidget {
  final Stadium stadium;
  final String bookingType;

  const ChallengeSelectTeamScreen({
    super.key,
    required this.stadium,
    required this.bookingType,
  });

  @override
  State<ChallengeSelectTeamScreen> createState() => _ChallengeSelectTeamScreenState();
}

class _ChallengeSelectTeamScreenState extends State<ChallengeSelectTeamScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Team? _selectedTeam;
  Timer? _debounce;
  bool _isSearching = false;
  List<Team> _searchedTeams = [];
  Map<String, int>? _h2hStats;
  bool _isLoadingH2H = false;

  // Mock History Teams (Should eventually come from Firestore too)
  final List<Team> _historyTeams = Team.getMockTeams().take(3).toList();
  
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    setState(() {
      _searchQuery = query;
    });

    if (query.isEmpty) {
      setState(() {
        _searchedTeams = [];
        _isSearching = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _isSearching = true);
      
      final String? myTeamId = context.read<BookingProvider>().currentDraft?.playerTeamId;
      final results = await DatabaseService().searchOpponentTeams(query);
      
      if (mounted) {
        setState(() {
          // Filter out the player's own team
          _searchedTeams = results.where((team) => team.id != myTeamId).toList();
          _isSearching = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: VSPColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'Select Opponent Team',
          style: Theme.of(context).textTheme.displaySmall,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Choose Opponent",
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Search for a team to challenge or pick from teams you've played against.",
                    style: TextStyle(
                      color: VSPColors.textSecondary.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Search Field
                  Container(
                    decoration: BoxDecoration(
                      color: VSPColors.surface,
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                      border: Border.all(color: VSPColors.divider),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: Theme.of(context).textTheme.bodyLarge,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: "Search by Team Name or Captain's Phone",
                        hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary),
                        prefixIcon: const Icon(Icons.search, color: VSPColors.accent),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: 14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Search Results or History
                  if (_searchQuery.isNotEmpty) ...[
                    Text(
                      'Search Results',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    if (_isSearching)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: CircularProgressIndicator(color: VSPColors.accent),
                        ),
                      )
                    else if (_searchedTeams.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              Icon(Icons.search_off, color: VSPColors.textSecondary.withOpacity(0.3), size: 48),
                              const SizedBox(height: 16),
                              Text(
                                "No teams found matching '$_searchQuery'",
                                style: TextStyle(color: VSPColors.textSecondary.withOpacity(0.5)),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._searchedTeams.map((team) => _buildTeamCard(team)),
                  ] else ...[
                    Text(
                      'Teams You Played Against',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    if (_historyTeams.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        decoration: BoxDecoration(
                          color: VSPColors.surface,
                          borderRadius: BorderRadius.circular(VSPRadius.lg),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.history, color: VSPColors.textSecondary.withOpacity(0.3), size: 48),
                            const SizedBox(height: 16),
                            Text(
                              "You don't have previous opponents yet.\nStart by searching for a team.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: VSPColors.textSecondary.withOpacity(0.5), fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._historyTeams.map((team) => _buildTeamCard(team)),
                  ],
                ],
              ),
            ),
          ),

          // Continue Button
          Container(
            padding: const EdgeInsets.all(VSPSpacing.lg),
            decoration: BoxDecoration(
              color: VSPColors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(VSPRadius.xl),
                topRight: Radius.circular(VSPRadius.xl),
              ),
              boxShadow: VSPShadow.subtle,
            ),
            child: SafeArea(
              child: PrimaryButton(
                text: 'Continue',
                onPressed: _selectedTeam == null
                    ? null
                    : () {
                        // Save opponent to draft
                        context.read<BookingProvider>().updateDraft(
                          opponentTeamId: _selectedTeam!.id,
                          opponentTeamName: _selectedTeam!.name,
                        );

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BookingConfirmationScreen(
                              stadium: widget.stadium,
                              bookingType: widget.bookingType,
                              opponentTeam: _selectedTeam,
                            ),
                          ),
                        );
                      },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamCard(Team team) {
    final bool isSelected = _selectedTeam?.id == team.id;

    return GestureDetector(
      onTap: () async {
        if (isSelected) return;
        
        setState(() {
          _selectedTeam = team;
          _isLoadingH2H = true;
          _h2hStats = null;
        });

        final String? myTeamId = context.read<BookingProvider>().currentDraft?.playerTeamId;
        if (myTeamId != null) {
          final stats = await DatabaseService().getHeadToHeadStats(myTeamId, team.id);
          if (mounted) {
            setState(() {
              _h2hStats = stats;
              _isLoadingH2H = false;
            });
          }
        } else {
          if (mounted) setState(() => _isLoadingH2H = false);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(VSPSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? VSPColors.accent.withOpacity(0.05) : VSPColors.surface,
          borderRadius: BorderRadius.circular(VSPRadius.lg),
          border: Border.all(
            color: isSelected ? VSPColors.accent : VSPColors.divider,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                ShimmerImage(
                  imageUrl: team.captainImageUrl,
                  width: 50,
                  height: 50,
                  borderRadius: VSPRadius.full,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        team.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Matches played: ${team.matchesPlayed}",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle, color: VSPColors.accent)
                else
                  Icon(Icons.circle_outlined, color: VSPColors.textSecondary.withOpacity(0.3)),
              ],
            ),
            if (isSelected) ...[
              const Divider(color: Colors.white10, height: 32),
              if (_isLoadingH2H)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: VSPColors.accent),
                    ),
                  ),
                )
              else if (_h2hStats != null && _h2hStats!['totalMatches']! > 0)
                _buildH2HContent()
              else if (_h2hStats != null)
                const Text(
                  "First time playing against them. Set the tone!",
                  style: TextStyle(color: VSPColors.textSecondary, fontSize: 12, fontStyle: FontStyle.italic),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildH2HContent() {
    final wins = _h2hStats!['teamAWins']!;
    final opposingWins = _h2hStats!['teamBWins']!;
    final draws = _h2hStats!['draws']!;
    
    String hypeMessage = "The series is tied! Break the deadlock!";
    if (wins > opposingWins) {
      hypeMessage = "You dominate them. Keep the streak alive!";
    } else if (wins < opposingWins) {
      hypeMessage = "Time for revenge! They have the upper hand.";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "HEAD-TO-HEAD HISTORY",
          style: TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildH2HStatItem("YOUR WINS", wins, VSPColors.accent),
            _buildH2HStatItem("DRAWS", draws, Colors.white60),
            _buildH2HStatItem("THEIR WINS", opposingWins, VSPColors.error),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: VSPColors.accent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(VSPRadius.sm),
          ),
          child: Text(
            hypeMessage,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: VSPColors.accent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildH2HStatItem(String label, int value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: VSPColors.textSecondary.withOpacity(0.6),
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
