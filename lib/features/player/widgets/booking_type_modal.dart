import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/providers/auth_provider.dart' as app_auth;
import '../../../core/providers/booking_provider.dart';
import '../../../core/repositories/team_repository.dart';
import '../../../data/models.dart';
import '../screens/booking_confirmation_screen.dart';
import '../screens/challenge_select_team_screen.dart';
import '../screens/profile_subscreens/my_team_screen.dart';

/// Modal Bottom Sheet لاختيار نوع الحجز بدون أي إيموجي (No Emojis)
class BookingTypeModal extends StatefulWidget {
  final Stadium stadium;

  const BookingTypeModal({super.key, required this.stadium});

  static Future<void> show(BuildContext context, Stadium stadium) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BookingTypeModal(stadium: stadium),
    );
  }

  @override
  State<BookingTypeModal> createState() => _BookingTypeModalState();
}

class _BookingTypeModalState extends State<BookingTypeModal> {
  bool _isLoading = false;

  Future<void> _handleOptionSelect(String typeId) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<app_auth.AuthProvider>();
      final bookingProvider = context.read<BookingProvider>();
      final uid = authProvider.currentUser?.uid;

      if (typeId == 'Challenge Match') {
        if (uid != null) {
          final team = await TeamRepository().getUserTeam(uid);
          if (team == null || team.currentPlayers < 5) {
            if (!mounted) return;
            Navigator.pop(context);
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTeamScreen()));
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!.teamIncompleteError),
                backgroundColor: VSPColors.warning,
              ),
            );
            return;
          }
        }
      }

      BookingType type = BookingType.personal;
      String typeString = 'Personal';

      if (typeId == 'Open Join Match') {
        type = BookingType.openJoin;
        typeString = 'OpenJoin';
      } else if (typeId == 'Challenge Match') {
        type = BookingType.challenge;
        typeString = 'Challenge';
      }

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

      if (!mounted) return;
      Navigator.pop(context); // Close Bottom Sheet

      if (type == BookingType.challenge) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChallengeSelectTeamScreen(stadium: widget.stadium, bookingType: typeString),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BookingConfirmationScreen(stadium: widget.stadium, bookingType: typeString),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      padding: EdgeInsets.fromLTRB(
        VSPSpacing.md,
        VSPSpacing.md,
        VSPSpacing.md,
        MediaQuery.of(context).padding.bottom + VSPSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: VSPColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Title & Close Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context)!.chooseBookingType,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Iconsax.close_circle_copy, color: VSPColors.textSecondary, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(color: VSPColors.divider, height: 24),
          // Option 1: Standard Pitch Booking
          _buildOptionCard(
            context,
            id: 'Book a Pitch',
            title: isArabic ? 'حجز ملعب عادي' : 'Standard Pitch Booking',
            subtitle: isArabic
                ? 'حجز مباشر وسريع للملعب لوقتك الخاص بدون إضافة لاعبين'
                : 'Direct pitch booking for your group without extra player matching',
            iconData: Iconsax.calendar_1_copy,
          ),
          const SizedBox(height: 12),
          // Option 2: Open Gathering Match
          _buildOptionCard(
            context,
            id: 'Open Join Match',
            title: isArabic ? 'حجز انضمام وتجميع' : 'Open Gathering Match',
            subtitle: isArabic
                ? 'حجز مباراة تجميعية وتحديد عدد لاعبيك والسماح للاعبين بالانضمام'
                : 'Create an open match, specify your available players, and let others join',
            iconData: Iconsax.people_copy,
          ),
          const SizedBox(height: 12),
          // Option 3: Team Challenge Match
          _buildOptionCard(
            context,
            id: 'Challenge Match',
            title: isArabic ? 'مباراة تحدي فرق' : 'Team Challenge Match',
            subtitle: isArabic
                ? 'مباراة تحدي بين فريقك وفريق آخر واحتساب نقاط تصنيف ELO'
                : 'Competitive match between two teams to earn ELO rank points',
            iconData: Iconsax.cup_copy,
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required String id,
    required String title,
    required String subtitle,
    required IconData iconData,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: VSPColors.surfaceAlt,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: VSPColors.divider, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _handleOptionSelect(id),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: VSPColors.accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(iconData, color: VSPColors.accent, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: VSPColors.textSecondary,
                            fontSize: 11.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Iconsax.arrow_left_2_copy,
                    color: VSPColors.textSecondary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
