import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/providers/auth_provider.dart' as app_auth;
import '../../../core/services/database_service.dart';
import '../../../data/models.dart';
import 'booking_confirmation_screen.dart';
import 'challenge_select_team_screen.dart';
import 'profile_subscreens/my_team_screen.dart';

class BookingTypeScreen extends StatefulWidget {
  final Stadium stadium;

  const BookingTypeScreen({
    super.key,
    required this.stadium,
  });

  @override
  State<BookingTypeScreen> createState() => _BookingTypeScreenState();
}

class _BookingTypeScreenState extends State<BookingTypeScreen> {
  String? _selectedType;
  bool _isLoadingTeam = true;
  bool _hasTeam = false;
  int _teamPlayersCount = 0;

  @override
  void initState() {
    super.initState();
    // Use Future.microtask to access Provider safely during init
    Future.microtask(() {
      if (mounted && context.mounted) {
        context.read<BookingProvider>().clearDraft();
      }
    });
    _checkUserTeam();
  }

  Future<void> _checkUserTeam() async {
    final auth = Provider.of<app_auth.AuthProvider>(context, listen: false);
    final uid = auth.currentUser?.uid;
    
    if (uid != null) {
      final team = await DatabaseService().getUserTeam(uid);
      if (!context.mounted) return;
      setState(() {
        _hasTeam = team != null;
        _teamPlayersCount = team?.currentPlayers ?? 0;
        _isLoadingTeam = false;
      });
    } else {
      if (context.mounted) setState(() => _isLoadingTeam = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.chooseBookingType,
          style: Theme.of(context).textTheme.displaySmall,
        ),
        backgroundColor: VSPColors.background,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, matchTextDirection: true, color: VSPColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildBookingOption(
                    context,
                    id: 'Book a Pitch',
                    title: AppLocalizations.of(context)!.bookPitch,
                    subtitle: AppLocalizations.of(context)!.bookPitchSubtitle,
                    imageUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=800&q=80',
                  ),
                  const SizedBox(height: VSPSpacing.md),
                  _buildBookingOption(
                    context,
                    id: 'Find Players',
                    title: AppLocalizations.of(context)!.findPlayers,
                    subtitle: AppLocalizations.of(context)!.findPlayersSubtitle,
                    imageUrl: 'https://images.unsplash.com/photo-1522778119026-d647f0596c20?w=800&q=80',
                  ),
                  const SizedBox(height: VSPSpacing.md),
                  _buildChallengeBookingOption(context),
                ],
              ),
            ),
          ),
          // Continue Button
          Container(
            padding: EdgeInsets.fromLTRB(VSPSpacing.lg, VSPSpacing.lg, VSPSpacing.lg, MediaQuery.of(context).padding.bottom + 24),
            decoration: const BoxDecoration(
              color: VSPColors.surface,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(VSPRadius.xl),
                topRight: Radius.circular(VSPRadius.xl),
              ),
            ),
            child: PrimaryButton(
              text: AppLocalizations.of(context)!.continueButton,
              onPressed: _selectedType == null ? null : _handleContinue,
            ),
          ),
        ],
      ),
    );
  }

  void _handleContinue() async {
    if (_selectedType == null) return;

    // GUIDED FLOW: If they want to challenge but team is invalid, help them fix it
    if (_selectedType == 'Create Team to Compete' || _selectedType == 'Team Incomplete' || _selectedType == 'Challenge Match') {
      if (!_hasTeam || _teamPlayersCount < 5) {
        // Navigation into team screen to fix it
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MyTeamScreen()),
        );
        
        // Re-check after return
        await _checkUserTeam();
        
        // If still invalid, stop here (they probably didn't finish)
        if (!_hasTeam || _teamPlayersCount < 5) {
          if (!mounted) return;
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.teamIncompleteError),
              backgroundColor: VSPColors.warning,
            ),
          );
          return;
        }
        
        // If NOW valid, update selection to Challenge and continue automatically!
        _selectedType = 'Challenge Match';
      }
    }

    // Map selection ID to correct BookingType
    // ... continues with the rest of the method below ...

    // Map selection ID to correct BookingType
    BookingType type = BookingType.personal;
    String typeString = 'Personal';

    if (_selectedType == 'Find Players') {
      type = BookingType.team;
      typeString = 'Team';
    } else if (_selectedType == 'Challenge Match') {
      type = BookingType.challenge;
      typeString = 'Challenge';
    }


    // CRITICAL FIX: Use setDraft (not updateDraft) to create a new draft skeleton
    // with all required stadium/owner fields. updateDraft() is a no-op when draft is null.
    if (!mounted) return;
    final bookingProvider = context.read<BookingProvider>();
    final authProvider = context.read<app_auth.AuthProvider>();
    bookingProvider.setDraft(BookingDraft(
      stadiumId: widget.stadium.id,
      stadiumName: widget.stadium.name,
      stadiumImageUrl: widget.stadium.imageUrl,
      ownerId: widget.stadium.ownerId,
      hostName: authProvider.userModel?.name,
      hostAvatarUrl: authProvider.userModel?.profileImageUrl,
      startTime: DateTime.now(), // placeholder - overwritten in BookingConfirmationScreen
      endTime: DateTime.now().add(const Duration(hours: 1)), // placeholder
      bookingType: type,
      isPrivate: _selectedType != 'Find Players', // public only for team/find-players
      rentBall: false, // user sets this in confirmation
      totalPrice: 0, // computed in confirmation
    ));

    if (type == BookingType.challenge) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChallengeSelectTeamScreen(
            stadium: widget.stadium,
            bookingType: typeString,
          ),
        ),
      );
    } else {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookingConfirmationScreen(
            stadium: widget.stadium,
            bookingType: typeString,
          ),
        ),
      );
    }
  }

  Widget _buildBookingOption(
    BuildContext context, {
    required String id,
    required String title,
    required String subtitle,
    required String imageUrl,
    IconData? icon,
  }) {
    final bool isSelected = _selectedType == id;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = id;
        });
      },
      child: Container(
        width: double.infinity,
        height: 180,
        decoration: BoxDecoration(
          color: VSPColors.surface,
          borderRadius: BorderRadius.circular(VSPRadius.lg),
          border: Border.all(
            color: isSelected ? VSPColors.accent : VSPColors.accent.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1.5,
          ),
        ),
        child: ClipRRect(
        borderRadius: BorderRadius.circular(VSPRadius.lg),
          child: Stack(
            children: [
              Positioned.fill(
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    VSPColors.background.withValues(alpha: isSelected ? 0.4 : 0.6),
                    BlendMode.darken,
                  ),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(color: VSPColors.surface),
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        VSPColors.background.withValues(alpha: 0.9),
                        VSPColors.background.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            if (icon != null) ...[
                              Icon(icon, color: VSPColors.accent, size: 24),
                              const SizedBox(width: VSPSpacing.sm),
                            ],
                            Text(
                              title,
                              style: Theme.of(context).textTheme.displaySmall,
                            ),
                          ],
                        ),
                        if (isSelected)
                          const CircleAvatar(
                            radius: 12,
                            backgroundColor: VSPColors.accent,
                            child: Icon(Icons.check, size: 16, color: VSPColors.background),
                          ),
                      ],
                    ),
                    const SizedBox(height: VSPSpacing.xs),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textPrimary.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildChallengeBookingOption(BuildContext context) {
    if (_isLoadingTeam) {
      return const Center(child: CircularProgressIndicator(color: VSPColors.accent, strokeWidth: 2.5));
    }

    if (!_hasTeam) {
      return _buildBookingOption(
        context,
        id: 'Create Team to Compete',
        title: AppLocalizations.of(context)!.createTeamToCompete,
        subtitle: 'Create a team with at least 5 players to unlock Ranked Challenges.',
        imageUrl: 'https://images.unsplash.com/photo-1526232761682-d26e03ac148e?w=800&q=80',
        icon: Icons.lock_outline,
      );
    }
    
    if (_teamPlayersCount < 5) {
      final missing = 5 - _teamPlayersCount;
      return _buildBookingOption(
        context,
        id: 'Team Incomplete',
        title: AppLocalizations.of(context)!.teamIncomplete,
        subtitle: 'Missing $missing more player${missing > 1 ? 's' : ''} to unlock Ranked Challenges.',
        imageUrl: 'https://images.unsplash.com/photo-1526232761682-d26e03ac148e?w=800&q=80',
        icon: Icons.warning_amber_rounded,
      );
    }

    return _buildBookingOption(
        context,
        id: 'Challenge Match',
        title: AppLocalizations.of(context)!.challengeMatch,
        subtitle: AppLocalizations.of(context)!.challengeMatchSubtitle,
        imageUrl: 'https://images.unsplash.com/photo-1529900748604-07564a03e7a6?w=800&q=80',
        icon: Icons.emoji_events_outlined,
    );
  }
}

