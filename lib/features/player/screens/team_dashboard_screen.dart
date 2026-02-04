import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models.dart';
import '../widgets/your_team_modal.dart';
import 'player_home_screen.dart'; // To access MatchCard

class TeamDashboardScreen extends StatelessWidget {
  const TeamDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock data for the dashboard
    final myTeam = Team(
      id: 'my_team',
      name: 'Your Team',
      captainName: 'Mohamed Salah',
      captainImageUrl: 'https://images.unsplash.com/photo-1543351611-58f69d7c1781?w=150&h=150&fit=crop&q=80',
      date: 'Aug 6th / pm7 to pm9',
      stadium: 'Sal Acd',
      pricePerPerson: 100,
      currentPlayers: 3,
      maxPlayers: 12,
      playerImages: [
        'https://images.unsplash.com/photo-1552674605-db6ffd4facb5?w=150&h=150&fit=crop&q=80',
        'https://images.unsplash.com/photo-1551958219-acbc608c6377?w=150&h=150&fit=crop&q=80',
        'https://images.unsplash.com/photo-1575361204480-aadea25e6e68?w=150&h=150&fit=crop&q=80',
        'https://images.unsplash.com/photo-1504450758481-7338eba7524a?w=150&h=150&fit=crop&q=80',
        'https://images.unsplash.com/photo-1516567727245-ad8c68f3ec93?w=150&h=150&fit=crop&q=80',
      ],
    );

    final otherTeams = [
      Team(
        id: '2',
        name: 'Real Madrid',
        captainName: 'Saleh Ahmed',
        captainImageUrl: 'https://images.unsplash.com/photo-1517466787929-bc90951d0974?w=150&h=150&fit=crop&q=80',
        date: 'Aug 6th / pm7 to pm9',
        stadium: 'Sal Acd',
        pricePerPerson: 100,
        currentPlayers: 3,
        maxPlayers: 12,
        playerImages: [
          'https://images.unsplash.com/photo-1552667466-07770ae110d0?w=150&h=150&fit=crop&q=80',
          'https://images.unsplash.com/photo-1511886929837-354d827aae26?w=150&h=150&fit=crop&q=80',
          'https://images.unsplash.com/photo-1516567727245-ad8c68f3ec93?w=150&h=150&fit=crop&q=80',
        ],
      ),
      Team(
        id: '3',
        name: 'Aswan FC',
        captainName: 'Mohamed Ahmed',
        captainImageUrl: 'https://images.unsplash.com/photo-1516567727245-ad8c68f3ec93?w=150&h=150&fit=crop&q=80',
        date: 'Aug 6th / pm7 to pm9',
        stadium: 'Sal Acd',
        pricePerPerson: 100,
        currentPlayers: 3,
        maxPlayers: 12,
        playerImages: [
          'https://images.unsplash.com/photo-1504450758481-7338eba7524a?w=150&h=150&fit=crop&q=80',
          'https://images.unsplash.com/photo-1543326727-cf6c39e8f84c?w=150&h=150&fit=crop&q=80',
        ],
      ),
    ];

    final allTeams = [myTeam, ...otherTeams];

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        elevation: 0,
        centerTitle: true,
        // Back button removed
        automaticallyImplyLeading: false,
        title: const Text(
          'Matches',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: allTeams.length,
        itemBuilder: (context, index) {
          final team = allTeams[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: GestureDetector(
              onTap: index == 0 ? () {
                showDialog(
                  context: context,
                  builder: (context) => const YourTeamModal(),
                );
              } : null,
              child: MatchCard(
                team: team,
                index: index,
              ),
            ),
          );
        },
      ),
    );
  }
}
