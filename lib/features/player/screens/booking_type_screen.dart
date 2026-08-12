import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/material.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/providers/auth_provider.dart' as app_auth;
import '../../../core/repositories/team_repository.dart';
import '../../../data/models.dart';
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
  bool _hasTeam = false;
  int _teamPlayersCount = 0;
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
      });
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
            isArabic ? Iconsax.arrow_right_3_copy : Iconsax.arrow_left_2_copy, 
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
                    title: isArabic ? 'حجز ملعب عادي ⚽' : 'Standard Pitch Booking',
                    subtitle: isArabic ? 'حجز مباشر وسريع للملعب لوقتك الخاص بدون إضافة لاعبين' : 'Direct pitch booking for your group without extra player matching',
                    iconData: Iconsax.calendar_1_copy,
                  ),
                  _buildOptionCard(
                    id: 'Open Join Match',
                    title: isArabic ? 'حجز انضمام وتجميع 👥' : 'Open Gathering Match',
                    subtitle: isArabic ? 'حجز مباراة تجميعية وتحديد عدد لاعبيك والسماح للاعبين بالانضمام' : 'Create an open match, specify your available players, and let others join',
                    iconData: Iconsax.people_copy,
                  ),
                  _buildOptionCard(
                    id: 'Challenge Match',
                    title: isArabic ? 'مباراة تحدي فرق 🏆' : 'Team Challenge Match',
                    subtitle: isArabic ? 'مباراة تحدي بين فريقك وفريق آخر واحتساب نقاط تصنيف الـ ELO' : 'Competitive match between two teams to earn ELO rank points',
                    iconData: Iconsax.cup_copy,
                  ),
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
      if (_selectedType == 'Challenge Match') {
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
        }
      }

      BookingType type = BookingType.personal;
      String typeString = 'Personal';

      if (_selectedType == 'Open Join Match') {
        type = BookingType.openJoin;
        typeString = 'OpenJoin';
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
        isPrivate: type != BookingType.openJoin, 
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
}

