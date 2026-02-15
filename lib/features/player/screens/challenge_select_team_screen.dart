import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shimmer_image.dart';
import '../../../../core/providers/booking_provider.dart';
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

  // Mock History Teams
  final List<Team> _historyTeams = Team.getMockTeams().take(3).toList();
  
  // Results filtered by search
  List<Team> get _searchResults {
    if (_searchQuery.isEmpty) return [];
    return Team.getMockTeams().where((team) => 
      team.name.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Select Opponent Team',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'Agency FB',
          ),
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
                  const Text(
                    "Choose Opponent",
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Agency FB',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Search for a team to challenge or pick from teams you've played against.",
                    style: TextStyle(
                      color: AppTheme.textSecondary.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Search Field
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.2)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search by team name',
                        hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                        prefixIcon: const Icon(Icons.search, color: AppTheme.neonGreen),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Search Results or History
                  if (_searchQuery.isNotEmpty) ...[
                    const Text(
                      'Search Results',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Agency FB',
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_searchResults.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              Icon(Icons.search_off, color: AppTheme.textSecondary.withValues(alpha: 0.3), size: 48),
                              const SizedBox(height: 16),
                              Text(
                                "No teams found matching '$_searchQuery'",
                                style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._searchResults.map((team) => _buildTeamCard(team)),
                  ] else ...[
                    const Text(
                      'Teams You Played Against',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Agency FB',
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_historyTeams.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.history, color: AppTheme.textSecondary.withValues(alpha: 0.3), size: 48),
                            const SizedBox(height: 16),
                            Text(
                              "You don't have previous opponents yet.\nStart by searching for a team.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.5), fontSize: 13),
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
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.neonGreen,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.grey[800],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
      onTap: () {
        setState(() {
          _selectedTeam = team;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.neonGreen.withValues(alpha: 0.1) : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.neonGreen : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            ShimmerImage(
              imageUrl: team.captainImageUrl,
              width: 50,
              height: 50,
              borderRadius: 25,
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
                    "Matches played: ${team.currentPlayers}", // Using currentPlayers as mock for matches played
                    style: TextStyle(
                      color: AppTheme.textSecondary.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppTheme.neonGreen)
            else
              Icon(Icons.circle_outlined, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }
}
