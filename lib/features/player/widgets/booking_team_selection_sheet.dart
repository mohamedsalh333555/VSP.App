import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/database_service.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/widgets/shimmer_image.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../data/models.dart';
import '../screens/challenge_select_team_screen.dart';
import '../screens/booking_confirmation_screen.dart';
import 'create_team_sheet.dart';

class BookingTeamSelectionSheet extends StatefulWidget {
  final Stadium stadium;
  const BookingTeamSelectionSheet({super.key, required this.stadium});

  @override
  State<BookingTeamSelectionSheet> createState() => _BookingTeamSelectionSheetState();
}

class _BookingTeamSelectionSheetState extends State<BookingTeamSelectionSheet> {
  // BETA READY: Real State Logic
  Team? _myTeam;
  bool _isLoading = true;
  String _selectedOption = 'Personal';

  @override
  void initState() {
    super.initState();
    _fetchTeam();
  }

  Future<void> _fetchTeam() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final phone = auth.userModel?.phone;
    if (phone != null) {
      final team = await DatabaseService().getTeamByCaptainPhone(phone);
      if (mounted) {
        setState(() {
          _myTeam = team;
          _isLoading = false;
          // Default to Challenge if team exists, otherwise Personal
          _selectedOption = (_myTeam != null) ? 'Challenge' : 'Personal';
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showCreateTeamSheet() async {
    final bool? created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CreateTeamSheet(),
    );

    if (created == true) {
      _fetchTeam(); // BETA READY: Refresh immediately to show the new team!
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 300,
        decoration: const BoxDecoration(
          color: VSPColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
        ),
        child: const Center(child: CircularProgressIndicator(color: VSPColors.accent)),
      );
    }

    final hasTeam = _myTeam != null;

    return Container(
      padding: const EdgeInsets.only(top: VSPSpacing.lg, left: VSPSpacing.md, right: VSPSpacing.md, bottom: VSPSpacing.lg),
      decoration: const BoxDecoration(
        color: VSPColors.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(VSPRadius.xl),
          topRight: Radius.circular(VSPRadius.xl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle Bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: VSPColors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: VSPSpacing.lg),

          // Title
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose What Suits You',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: VSPSpacing.sm),
              Text(
                'Choose What Suits You To Finish Your Booking Easily',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: VSPColors.textSecondary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // --- Options List ---
          
          if (!hasTeam)
            // No Team State - Top Card: Create Button
            Container(
              margin: const EdgeInsets.only(bottom: VSPSpacing.md),
              padding: const EdgeInsets.all(VSPSpacing.md),
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: BorderRadius.circular(VSPRadius.lg),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: VSPColors.surfaceAlt,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.groups_outlined, color: VSPColors.accent),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create A New Team',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: VSPSpacing.xs),
                        Text(
                          'Create A New Team Now To Confirm Your Booking.',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: VSPColors.textSecondary,
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
                        color: VSPColors.accent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            'Create',
                            style: TextStyle(
                              color: VSPColors.background,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.refresh, size: 14, color: VSPColors.background), 
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
            iconData: Icons.person_outline, // Replaced fake Unsplash image with neutral icon
            isAvatar: true,
          ),

          // Option 2: Your Team (Only if has team)
          if (hasTeam)
            _buildOptionCard(
              id: 'Team',
              title: 'Your Team (${_myTeam!.name})',
              subtitle: 'For You & Your Team — Public With A Link Or Private For Friends',
              iconUrl: _myTeam!.captainImageUrl,
              isAvatar: true, 
            ),

          // Option 3: Challenge
          _buildOptionCard(
            id: 'Challenge',
            title: 'Challenge',
            subtitle: hasTeam ? 'Challenge Another Team' : "You Don't Have A Team.",
            iconData: Icons.bolt,
            enabled: hasTeam,
          ),

          const SizedBox(height: VSPSpacing.lg),

          // Continue Button
          PrimaryButton(
            text: 'Continue',
            onPressed: () {
              Navigator.pop(context); // Close modal
              
              if (_selectedOption == 'Challenge') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChallengeSelectTeamScreen(
                      stadium: widget.stadium,
                      bookingType: _selectedOption,
                    ),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookingConfirmationScreen(
                      stadium: widget.stadium,
                      bookingType: _selectedOption,
                    ),
                  ),
                );
              }
            },
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
    bool enabled = true,
  }) {
    final isSelected = _selectedOption == id;

    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: InkWell(
        onTap: !enabled ? () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please create a team first to use this option.')),
          );
        } : () {
          setState(() {
            _selectedOption = id;
          });
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: VSPSpacing.md),
          padding: const EdgeInsets.all(VSPSpacing.md),
          decoration: BoxDecoration(
            color: isSelected ? VSPColors.accent.withValues(alpha: 0.05) : VSPColors.surface,
            borderRadius: BorderRadius.circular(VSPRadius.lg),
            border: Border.all(
              color: isSelected ? VSPColors.accent : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Icon / Avatar
              if (iconUrl != null && iconUrl.isNotEmpty)
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
                  decoration: const BoxDecoration(
                    color: VSPColors.surfaceAlt,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(iconData, color: VSPColors.accent),
                ),
              
              const SizedBox(width: 16),
  
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: VSPSpacing.xs),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: VSPColors.textSecondary,
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
                    color: isSelected ? VSPColors.accent : VSPColors.textSecondary,
                    width: 1.5,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: VSPColors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
