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
    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.chooseBookingType, style: Theme.of(context).textTheme.displaySmall),
        backgroundColor: VSPColors.background,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(icon: const Icon(LucideIcons.chevronLeft, color: VSPColors.textPrimary, size: 20), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildOptionCard(
                    id: 'Book a Pitch',
                    title: AppLocalizations.of(context)!.bookPitch,
                    subtitle: AppLocalizations.of(context)!.bookPitchSubtitle,
                    iconData: LucideIcons.calendarCheck,
                  ),
                  const SizedBox(height: VSPSpacing.md),
                  _buildOptionCard(
                    id: _hasTeam ? 'Find Players' : 'Create Team to Find Players',
                    title: _hasTeam ? AppLocalizations.of(context)!.findPlayers : (isArabic ? 'أنشئ فريقاً لتجد لاعبين' : 'Create Team to Find Players'),
                    subtitle: _hasTeam ? AppLocalizations.of(context)!.findPlayersSubtitle : (isArabic ? 'أنشئ فريقاً يضم 5 لاعبين على الأقل لتتمكن من اللعب العام.' : 'Create a team with 5+ players to unlock public matchmaking.'),
                    iconData: LucideIcons.users,
                    enabled: _hasTeam,
                  ),
                  const SizedBox(height: VSPSpacing.md),
                  _buildChallengeBookingOption(context),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(VSPSpacing.lg, VSPSpacing.lg, VSPSpacing.lg, MediaQuery.of(context).padding.bottom + 24),
            decoration: const BoxDecoration(
              color: VSPColors.surface,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(VSPRadius.xl), topRight: Radius.circular(VSPRadius.xl)),
            ),
            child: PrimaryButton(text: AppLocalizations.of(context)!.continueButton, onPressed: _selectedType == null ? null : _handleContinue),
          ),
        ],
      ),
    );
  }

  void _handleContinue() async {
    if (_selectedType == null) return;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    if (_selectedType == 'Create Team to Compete' || _selectedType == 'Team Incomplete' || _selectedType == 'Challenge Match') {
      if (!_hasTeam || _teamPlayersCount < 5) {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTeamScreen()));
        await _checkUserTeam();
        if (!_hasTeam || _teamPlayersCount < 5) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.teamIncompleteError), backgroundColor: VSPColors.warning));
          return;
        }
        _selectedType = 'Challenge Match';
      }
    }

    if (_selectedType == 'Fair Play Banned') {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isArabic ? 'نقاط اللعب النظيف لفريقك أقل من 40%. لا يمكن المشاركة في تحديات الترتيب.' : 'Your team Fair Play is below 40%. Cannot participate in ranked challenges.'), backgroundColor: const Color(0xFFB71C1C)));
      return;
    }

    if (_selectedType == 'Find Players' || _selectedType == 'Create Team to Find Players') {
      if (!_hasTeam) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: VSPColors.surface,
            title: Text(isArabic ? 'تكوين فريق أولاً' : 'Create Team First', style: const TextStyle(color: Colors.white)),
            content: Text(isArabic ? 'يجب أن تنشئ فريقك الخاص لتتمكن من إنشاء حجز وطلب انضمام لاعبين آخرين.' : 'You must create your own team to be able to create a booking and request other players to join.', style: const TextStyle(color: VSPColors.textSecondary)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isArabic ? 'إلغاء' : 'Cancel', style: const TextStyle(color: VSPColors.textSecondary))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: VSPColors.accent, foregroundColor: Colors.black),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTeamScreen()));
                },
                child: Text(isArabic ? 'إنشاء فريق الآن' : 'Create Team Now', style: const TextStyle(fontWeight: FontWeight.bold)),
              )
            ]
          )
        );
        return;
      }
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
      stadiumId: widget.stadium.id, stadiumName: widget.stadium.name, stadiumImageUrl: widget.stadium.imageUrl,
      ownerId: widget.stadium.ownerId, hostName: authProvider.userModel?.name, hostAvatarUrl: authProvider.userModel?.profileImageUrl,
      startTime: DateTime.now(), endTime: DateTime.now().add(const Duration(hours: 1)),
      bookingType: type, isPrivate: _selectedType != 'Find Players', rentBall: false, totalPrice: 0, needsDeposit: widget.stadium.needsDeposit,
    ));

    if (type == BookingType.challenge) {
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => ChallengeSelectTeamScreen(stadium: widget.stadium, bookingType: typeString)));
    } else {
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => BookingConfirmationScreen(stadium: widget.stadium, bookingType: typeString)));
    }
  }

  Future<bool> _showFindPlayersWarningDialog() async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final result = await showDialog<bool>(
      context: context, barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(color: const Color(0xFF0D0D0D), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFFF6B00))),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.alertTriangle, color: Color(0xFFFF6B00), size: 38),
                const SizedBox(height: 20),
                Text(isArabic ? 'تنبيه مهم قبل المتابعة' : 'Important Warning', style: const TextStyle(color: Color(0xFFFF6B00), fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Icon(LucideIcons.dollarSign, color: Color(0xFFFF6B00)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(isArabic ? 'المنصة لا تضمن دفع حصص اللاعبين الغائبين (No-Show). المسؤولية المالية الكاملة تقع على عاتق صاحب الحجز.' : 'The platform does not guarantee payment for absent players (No-Show). Full financial responsibility lies with the booking owner.', style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5))),
                  ],
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(isArabic ? 'رجوع' : 'Back', style: const TextStyle(color: Colors.white)))),
                    const SizedBox(width: 12),
                    Expanded(child: ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B00)), child: Text(isArabic ? 'موافق' : 'Accept', style: const TextStyle(color: Colors.white)))),
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

  Widget _buildOptionCard({required String id, required String title, required String subtitle, IconData? iconData, bool enabled = true}) {
    final isSelected = _selectedType == id;
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: InkWell(
        onTap: !enabled ? () {
          final isArabic = Localizations.localeOf(context).languageCode == 'ar';
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: VSPColors.surface,
              title: Text(isArabic ? 'تكوين فريق أولاً' : 'Create Team First', style: const TextStyle(color: Colors.white)),
              content: Text(isArabic ? 'يجب أن تنشئ فريقك الخاص لتتمكن من إنشاء حجز وطلب انضمام لاعبين آخرين.' : 'You must create your own team to be able to create a booking and request other players to join.', style: const TextStyle(color: VSPColors.textSecondary)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isArabic ? 'إلغاء' : 'Cancel', style: const TextStyle(color: VSPColors.textSecondary))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: VSPColors.accent, foregroundColor: Colors.black),
                  onPressed: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTeamScreen())); },
                  child: Text(isArabic ? 'إنشاء فريق الآن' : 'Create Team Now', style: const TextStyle(fontWeight: FontWeight.bold)),
                )
              ]
            )
          );
        } : () { setState(() { _selectedType = id; }); },
        child: Container(
          height: 125, margin: const EdgeInsets.only(bottom: VSPSpacing.md), padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: isSelected ? [VSPColors.accent.withOpacity(0.15), VSPColors.surface] : [VSPColors.surfaceAlt, VSPColors.surface], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(VSPRadius.lg),
            border: Border.all(color: isSelected ? VSPColors.accent : Colors.transparent, width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (iconData != null) Icon(iconData, color: VSPColors.accent, size: 28),
                      const SizedBox(width: 12),
                      Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: isSelected ? VSPColors.accent : VSPColors.textSecondary, width: 1.5)),
                    child: isSelected ? Center(child: Container(width: 12, height: 12, decoration: const BoxDecoration(color: VSPColors.accent, shape: BoxShape.circle))) : null,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChallengeBookingOption(BuildContext context) {
    if (_isLoadingTeam) return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    if (!_hasTeam) {
      return _buildOptionCard(
        id: 'Create Team to Compete', title: AppLocalizations.of(context)!.createTeamToCompete,
        subtitle: isArabic ? 'أنشئ فريقاً يضم 5 لاعبين على الأقل لتتمكن من اللعب التنافسي.' : 'Create a team with 5+ players to compete.',
        iconData: LucideIcons.lock,
      );
    }
    if (_teamPlayersCount < 5) {
      return _buildOptionCard(
        id: 'Team Incomplete', title: AppLocalizations.of(context)!.teamIncomplete,
        subtitle: isArabic ? 'الفريق غير مكتمل، تحتاج لـ 5 لاعبين على الأقل.' : 'Team is incomplete, need 5+ players.',
        iconData: LucideIcons.alertTriangle,
      );
    }
    if (_teamFairPlayScore < 40) {
      final bool isSelected = _selectedType == 'Fair Play Banned';
      return GestureDetector(
        onTap: () => setState(() => _selectedType = 'Fair Play Banned'),
        child: Container(
          width: double.infinity, padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: VSPColors.error.withOpacity(0.08), borderRadius: BorderRadius.circular(VSPRadius.lg), border: Border.all(color: isSelected ? VSPColors.error : VSPColors.error.withOpacity(0.4))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [Icon(LucideIcons.gavel, color: VSPColors.error), SizedBox(width: 10), Text('محظور من التحديات المصنّفة', style: TextStyle(color: VSPColors.error, fontWeight: FontWeight.bold))]),
              const SizedBox(height: 10),
              Text('نقاط اللعب النظيف لفريقك: $_teamFairPlayScore / 100', style: TextStyle(color: VSPColors.error.withOpacity(0.8))),
            ],
          ),
        ),
      );
    }
    return _buildOptionCard(
      id: 'Challenge Match', title: AppLocalizations.of(context)!.challengeMatch,
      subtitle: AppLocalizations.of(context)!.challengeMatchSubtitle, iconData: LucideIcons.trophy,
    );
  }
}
