import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/providers/auth_provider.dart' as app_auth;
import '../../../core/repositories/team_repository.dart';
import '../../../data/models.dart';
import '../../../core/widgets/skeleton_loader.dart';
import 'booking_confirmation_screen.dart';
import 'challenge_select_team_screen.dart';
import 'profile_subscreens/my_team_screen.dart';

class BookingTypeScreen extends StatefulWidget {
  final Stadium stadium;

  const BookingTypeScreen({super.key, required this.stadium});

  @override
  State<BookingTypeScreen> createState() => _BookingTypeScreenState();
}

class _BookingTypeScreenState extends State<BookingTypeScreen> {
  String? _selectedType;
  bool _isLoadingTeam = true;
  bool _hasTeam = false;
  int _teamPlayersCount = 0;
  int _teamFairPlayScore = 100;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
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
      final team = await TeamRepository().getUserTeam(uid);
      if (!context.mounted) return;
      setState(() {
        _hasTeam = team != null;
        _teamPlayersCount = team?.currentPlayers ?? 0;
        _teamFairPlayScore = team?.fairPlayScore ?? 100;
        _isLoadingTeam = false;
      });
    } else {
      if (context.mounted) setState(() => _isLoadingTeam = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    
    // Determine bottom button text dynamically
    String continueText = AppLocalizations.of(context)!.continueButton;
    if (_selectedType == 'Create Team to Find Players' || _selectedType == 'Create Team to Compete') {
      continueText = AppLocalizations.of(context)!.createTeamButton;
    } else if (_selectedType == 'Team Incomplete') {
      continueText = AppLocalizations.of(context)!.completeTeamButton;
    }

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.chooseBookingType, style: Theme.of(context).textTheme.displaySmall),
        backgroundColor: VSPColors.background,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            isArabic ? LucideIcons.chevronRight : LucideIcons.chevronLeft, 
            color: VSPColors.textPrimary, 
            size: 20
          ), 
          onPressed: () => Navigator.pop(context)
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.sm),
              child: Column(
                children: [
                  _buildOptionCard(
                    id: 'Book a Pitch',
                    title: AppLocalizations.of(context)!.bookPitch,
                    subtitle: AppLocalizations.of(context)!.bookPitchSubtitle,
                    iconData: LucideIcons.calendarCheck,
                  ),
                  _buildOptionCard(
                    id: _hasTeam ? 'Find Players' : 'Create Team to Find Players',
                    title: _hasTeam 
                        ? AppLocalizations.of(context)!.findPlayers 
                        : AppLocalizations.of(context)!.createTeamFirstTitle,
                    subtitle: _hasTeam 
                        ? AppLocalizations.of(context)!.findPlayersSubtitle 
                        : AppLocalizations.of(context)!.createTeamFirstContent,
                    iconData: LucideIcons.users,
                  ),
                  _buildChallengeBookingOption(context),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              VSPSpacing.md, 
              VSPSpacing.md, 
              VSPSpacing.md, 
              MediaQuery.of(context).padding.bottom + VSPSpacing.md
            ),
            decoration: const BoxDecoration(
              color: VSPColors.surface,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(VSPRadius.xl), 
                topRight: Radius.circular(VSPRadius.xl)
              ),
            ),
            child: PrimaryButton(
              text: continueText, 
              onPressed: (_selectedType == null || _isNavigating) ? null : _handleContinue
            ),
          ),
        ],
      ),
    );
  }

  void _handleContinue() async {
    if (_selectedType == null || _isNavigating) return;
    
    setState(() {
      _isNavigating = true;
    });

    try {
      if (_selectedType == 'Create Team to Compete' || 
          _selectedType == 'Team Incomplete' || 
          _selectedType == 'Create Team to Find Players') {
        
        if (!_hasTeam || _teamPlayersCount < 5) {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTeamScreen()));
          await _checkUserTeam();
          
          if (!_hasTeam || _teamPlayersCount < 5) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!.teamIncompleteError), 
                backgroundColor: VSPColors.warning
              )
            );
            return;
          }
          
          // Re-evaluate selected type after successfully setting up the team
          if (_selectedType == 'Create Team to Find Players') {
            _selectedType = 'Find Players';
          } else {
            _selectedType = 'Challenge Match';
          }
        }
      }

      if (_selectedType == 'Find Players') {
        final confirmed = await _showFindPlayersWarningDialog();
        if (!confirmed || !mounted) return;
      }

      BookingType type = BookingType.personal;
      String typeString = 'Personal';

      if (_selectedType == 'Find Players') {
        type = BookingType.team;
        typeString = 'Team';
      } else if (_selectedType == 'Challenge Match') {
        type = BookingType.challenge;
        typeString = 'Challenge';
      }

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
        startTime: DateTime.now(), 
        endTime: DateTime.now().add(const Duration(hours: 1)),
        bookingType: type, 
        isPrivate: _selectedType != 'Find Players', 
        rentBall: false, 
        totalPrice: 0, 
        needsDeposit: widget.stadium.needsDeposit,
      ));

      if (type == BookingType.challenge) {
        if (!mounted) return;
        Navigator.push(
          context, 
          MaterialPageRoute(
            builder: (_) => ChallengeSelectTeamScreen(stadium: widget.stadium, bookingType: typeString)
          )
        );
      } else {
        if (!mounted) return;
        Navigator.push(
          context, 
          MaterialPageRoute(
            builder: (_) => BookingConfirmationScreen(stadium: widget.stadium, bookingType: typeString)
          )
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isNavigating = false;
        });
      }
    }
  }

  Future<bool> _showFindPlayersWarningDialog() async {
    final result = await showDialog<bool>(
      context: context, 
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: VSPColors.surface, 
            borderRadius: BorderRadius.circular(VSPRadius.lg), 
            border: Border.all(color: VSPColors.warning, width: 1.5)
          ),
          child: Padding(
            padding: const EdgeInsets.all(VSPSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.alertTriangle, color: VSPColors.warning, size: 38),
                const SizedBox(height: VSPSpacing.md),
                Text(
                  AppLocalizations.of(context)!.findPlayersWarningTitle, 
                  style: const TextStyle(color: VSPColors.warning, fontSize: 20, fontWeight: FontWeight.bold), 
                  textAlign: TextAlign.center
                ),
                const SizedBox(height: VSPSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(LucideIcons.dollarSign, color: VSPColors.warning),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.findPlayersWarningContent, 
                        style: const TextStyle(color: VSPColors.textPrimary, fontSize: 13, height: 1.5)
                      )
                    ),
                  ],
                ),
                const SizedBox(height: VSPSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: VSPColors.textPrimary,
                          side: const BorderSide(color: VSPColors.divider),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(false), 
                        child: Text(AppLocalizations.of(context)!.backButton)
                      )
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VSPColors.warning,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(true), 
                        child: Text(AppLocalizations.of(context)!.accept)
                      )
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return result ?? false;
  }

  Widget _buildOptionCard({
    required String id, 
    required String title, 
    required String subtitle, 
    IconData? iconData, 
    bool enabled = true,
    bool isError = false,
  }) {
    final isSelected = _selectedType == id;
    final accentColor = isError ? VSPColors.error : VSPColors.accent;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: VSPSpacing.md),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.6,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isSelected 
                  ? [accentColor.withValues(alpha: 0.15), VSPColors.surface] 
                  : [VSPColors.surfaceAlt, VSPColors.surface], 
              begin: Alignment.topLeft, 
              end: Alignment.bottomRight
            ),
            borderRadius: BorderRadius.circular(VSPRadius.lg),
            border: Border.all(color: isSelected ? accentColor : Colors.transparent, width: 1.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(VSPRadius.lg),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (!enabled) {
                    if (id == 'Fair Play Banned') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(AppLocalizations.of(context)!.fairPlayBannedError), 
                          backgroundColor: VSPColors.error
                        )
                      );
                    }
                    return;
                  }
                  setState(() { _selectedType = id; });
                },
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                if (iconData != null) Icon(iconData, color: accentColor, size: 28),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    title, 
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 24, height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle, 
                              border: Border.all(
                                color: isSelected ? accentColor : VSPColors.textSecondary, 
                                width: 1.5
                              )
                            ),
                            child: isSelected 
                                ? Center(
                                    child: Container(
                                      width: 12, height: 12, 
                                      decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle)
                                    )
                                  ) 
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        subtitle, 
                        style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChallengeBookingOption(BuildContext context) {
    if (_isLoadingTeam) {
      return Padding(
        padding: const EdgeInsets.only(bottom: VSPSpacing.md),
        child: VSPSkeleton(
          width: double.infinity,
          height: 110,
          borderRadius: VSPRadius.lg,
        ),
      );
    }
    
    if (!_hasTeam) {
      return _buildOptionCard(
        id: 'Create Team to Compete', 
        title: AppLocalizations.of(context)!.createTeamToCompete,
        subtitle: AppLocalizations.of(context)!.createTeamSubtitle,
        iconData: LucideIcons.lock,
      );
    }
    
    if (_teamPlayersCount < 5) {
      return _buildOptionCard(
        id: 'Team Incomplete', 
        title: AppLocalizations.of(context)!.teamIncomplete,
        subtitle: AppLocalizations.of(context)!.teamIncompleteSubtitle,
        iconData: LucideIcons.alertTriangle,
      );
    }
    
    if (_teamFairPlayScore < 40) {
      return _buildOptionCard(
        id: 'Fair Play Banned',
        title: AppLocalizations.of(context)!.fairPlayBannedTitle,
        subtitle: AppLocalizations.of(context)!.fairPlayBannedSubtitle(_teamFairPlayScore),
        iconData: LucideIcons.gavel,
        enabled: false,
        isError: true,
      );
    }
    
    return _buildOptionCard(
      id: 'Challenge Match', 
      title: AppLocalizations.of(context)!.challengeMatch,
      subtitle: AppLocalizations.of(context)!.challengeMatchSubtitle, 
      iconData: LucideIcons.trophy,
    );
  }
}

