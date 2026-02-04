import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shimmer_image.dart';
import '../../../data/models.dart';
import '../screens/booking_confirmation_screen.dart';
import 'create_team_sheet.dart';

class BookingTeamSelectionSheet extends StatefulWidget {
  final Stadium stadium;
  const BookingTeamSelectionSheet({super.key, required this.stadium});

  @override
  State<BookingTeamSelectionSheet> createState() => _BookingTeamSelectionSheetState();
}

class _BookingTeamSelectionSheetState extends State<BookingTeamSelectionSheet> {
  // Mock State
  bool _hasTeam = true; 
  String _selectedOption = 'Challenge'; // Default to Challenge as per screenshot

  // Restoring the missing variable
  final List<Map<String, dynamic>> _myTeams = [
    {
      'name': 'New Castle United',
      'image': 'https://upload.wikimedia.org/wikipedia/en/thumb/5/56/Newcastle_United_Logo.svg/1200px-Newcastle_United_Logo.svg.png', // Real Logo
      'members': 12,
    },
  ];

  void _showCreateTeamSheet() {
    Navigator.pop(context); // Close current sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CreateTeamSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_myTeams.isEmpty) {
      _hasTeam = false;
      if (_selectedOption == 'Team') _selectedOption = 'Personal';
    }

    return Container(
      padding: const EdgeInsets.only(top: 24, left: 16, right: 16, bottom: 24),
      decoration: const BoxDecoration(
        color: AppTheme.darkBackground,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Moved from Container to Column
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle Bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Title
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose What Suits You',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Agency FB', 
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose What Suits You To Finish Your Booking Easily',
                style: TextStyle(
                  color: AppTheme.textSecondary.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // --- Options List ---
          
          if (!_hasTeam)
            // No Team State - Top Card: Create Button
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.textSecondary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.groups_outlined, color: AppTheme.neonGreen),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Create A New Team',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Create A New Team Now To Confirm Your Booking.',
                          style: TextStyle(
                            color: AppTheme.textSecondary.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _showCreateTeamSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.neonGreen,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            'Create',
                            style: TextStyle(
                              color: AppTheme.darkBackground,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.refresh, size: 14, color: AppTheme.darkBackground), 
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Option 1: Personal Booking
          _buildOptionCard(
            id: 'Personal',
            title: 'Personal Booking',
            subtitle: 'Booking The Pitch For Yourself Only',
            iconUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100',
            isAvatar: true,
          ),

          // Option 2: Your Team (Only if has team)
          if (_hasTeam)
            _buildOptionCard(
              id: 'Team',
              title: _myTeams.isNotEmpty ? 'Your Team (${_myTeams[0]['name']})' : 'Your Team',
              subtitle: 'For You & Your Team — Public With A Link Or Private For Friends',
              iconUrl: _myTeams.isNotEmpty ? _myTeams[0]['image'] : '',
              isAvatar: true, 
            ),

          // Option 3: Challenge
          _buildOptionCard(
            id: 'Challenge',
            title: 'Challenge',
            subtitle: _hasTeam ? 'Challenge Another Team' : "You Don't Have A Team.",
            iconData: Icons.bolt,
          ),

          const SizedBox(height: 24),

          // Continue Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close modal
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookingConfirmationScreen(
                      stadium: widget.stadium,
                      bookingType: _selectedOption,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.neonGreen,
                foregroundColor: AppTheme.darkBackground,
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
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required String id,
    required String title,
    required String subtitle,
    String? iconUrl,
    IconData? iconData,
    bool isAvatar = false,
  }) {
    final isSelected = _selectedOption == id;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedOption = id;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.neonGreen.withOpacity(0.05) : AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.neonGreen : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Icon / Avatar
            if (iconUrl != null && iconUrl.isNotEmpty) // Added check
              ShimmerImage(
                imageUrl: iconUrl,
                width: 48,
                height: 48,
                borderRadius: 24,
              )
            else if (iconData != null)
               Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, color: AppTheme.neonGreen),
              ),
            
            const SizedBox(width: 16),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppTheme.textSecondary.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Radio Button
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppTheme.neonGreen : AppTheme.textSecondary,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: AppTheme.neonGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
