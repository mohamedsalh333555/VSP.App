import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import '../../../core/ui/vsp_ui.dart';
import 'package:flutter/services.dart';
import 'package:vsp_application/core/utils/vsp_feedback.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart' as app_auth;
import '../../../core/repositories/team_repository.dart';
import '../../../core/repositories/match_repository.dart';
import '../../../data/models.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/services/sharing_service.dart';
import '../../../core/services/support_service.dart';
import '../../../shared/widgets/team_card_hero.dart';
import '../../../core/repositories/league/team_league_repository.dart';
import '../widgets/league/team_league_tab.dart';
import '../widgets/collective_match_invite_sheet.dart';
import 'player_home_screen.dart';

class TeamDashboardScreen extends StatefulWidget {
  const TeamDashboardScreen({super.key});

  @override
  State<TeamDashboardScreen> createState() => _TeamDashboardScreenState();
}

class _TeamDashboardScreenState extends State<TeamDashboardScreen> {
  Team? _userTeam;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _collectiveCodeController = TextEditingController();
  bool _resolvingCollectiveInvite = false;
  int _selectedMainTab = 0; // 0 = تجميع افتراضياً، 1 = دوري

  @override
  void initState() {
    super.initState();
    _fetchUserTeam();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _collectiveCodeController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserTeam() async {
    final auth = Provider.of<app_auth.AuthProvider>(context, listen: false);
    if (auth.isAuthenticated) {
      final team = await TeamRepository().getUserTeam(auth.currentUser!.uid);
      if (mounted) {
        setState(() => _userTeam = team);
        if (team != null) {
          final activeLeague = await TeamLeagueRepository().getTeamActiveLeague(team.id);
          if (mounted && activeLeague != null && (activeLeague.status == 'ongoing' || activeLeague.status == 'open')) {
            setState(() => _selectedMainTab = 1);
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return VSPScaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          AppLocalizations.of(context)!.matchesTitle,
          style: Theme.of(context).textTheme.displayMedium,
        ),
        actions: [
          if (_userTeam != null)
            IconButton(
              icon: const Icon(Iconsax.share_copy, color: VSPColors.accent),
              onPressed: () => _showTeamCard(context, _userTeam!),
            ),
          IconButton(
            icon: const Icon(Iconsax.headphones_copy, color: VSPColors.textSecondary),
            onPressed: () => SupportService().openSupport(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            // Pill Switcher: [ تجميع ] [ دوري ] مطابقة 100% لشاشة الأبطال بدون إيموجي
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              height: 48,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: BorderRadius.circular(VSPRadius.full),
                border: Border.all(color: VSPColors.divider, width: 0.5),
              ),
              child: Stack(
                children: [
                  // Animated background pill for 2 tabs
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    alignment: Directionality.of(context) == TextDirection.rtl
                        ? (_selectedMainTab == 0
                            ? Alignment.centerRight
                            : Alignment.centerLeft)
                        : (_selectedMainTab == 0
                            ? Alignment.centerLeft
                            : Alignment.centerRight),
                    child: FractionallySizedBox(
                      widthFactor: 0.5,
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: VSPColors.accent,
                          borderRadius: BorderRadius.circular(VSPRadius.full),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      // Tab 0: تجميع
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedMainTab = 0);
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Center(
                            child: Builder(
                              builder: (context) {
                                final isArabic = Localizations.localeOf(context).languageCode == 'ar';
                                final label = isArabic ? 'تجميع' : 'Gathering';
                                return Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: _selectedMainTab == 0 ? Colors.black : Colors.white,
                                        fontWeight: _selectedMainTab == 0 ? FontWeight.w900 : FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      // Tab 1: دوري
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedMainTab = 1);
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Center(
                            child: Builder(
                              builder: (context) {
                                final isArabic = Localizations.localeOf(context).languageCode == 'ar';
                                final label = isArabic ? 'دوري' : 'League';
                                return Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: _selectedMainTab == 1 ? Colors.black : Colors.white,
                                        fontWeight: _selectedMainTab == 1 ? FontWeight.w900 : FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: IndexedStack(
                index: _selectedMainTab,
                children: [
                  _buildGatheringTab(),
                  TeamLeagueTab(
                    userTeam: _userTeam,
                    onTeamCreated: _fetchUserTeam,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGatheringTab() {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return ListView(
      padding: VSPScrollPadding.forList(context, hasFloatingNavBar: true, top: VSPSpacing.lg),
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: VSPSpacing.lg),
          padding: const EdgeInsets.all(VSPSpacing.lg),
          decoration: BoxDecoration(
            color: VSPColors.surface,
            borderRadius: BorderRadius.circular(VSPRadius.xl),
            border: Border.all(color: VSPColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: VSPColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(VSPRadius.lg),
                    ),
                    child: const Icon(Iconsax.people_copy, color: VSPColors.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isArabic ? 'التجميعية الخاصة' : 'Private Collective Match',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                isArabic
                    ? 'التجميعية لا تظهر بشكل عام. افتح دعوة وصلتك من خلال الرابط أو استخدم كود الدعوة لعرض تفاصيل المباراة والانضمام.'
                    : 'Collective matches are private. Open a received invitation by link or use its invite code to view the match and join.',
                style: const TextStyle(color: VSPColors.textSecondary, height: 1.5, fontSize: 12),
              ),
              const SizedBox(height: 18),
              Text(
                isArabic ? 'كود الدعوة' : 'Invite code',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _collectiveCodeController,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                maxLength: 10,
                onSubmitted: (_) => _openCollectiveByCode(),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: isArabic ? 'مثال: 37D4B48CD9' : 'e.g. 37D4B48CD9',
                  prefixIcon: const Icon(Iconsax.key_copy, color: VSPColors.textSecondary),
                  filled: true,
                  fillColor: VSPColors.surfaceAlt,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(VSPRadius.md), borderSide: const BorderSide(color: VSPColors.divider)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(VSPRadius.md), borderSide: const BorderSide(color: VSPColors.divider)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _resolvingCollectiveInvite ? null : _openCollectiveByCode,
                  icon: _resolvingCollectiveInvite
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Iconsax.search_normal_1_copy, size: 18),
                  label: Text(isArabic ? 'فتح التجميعية' : 'Open collective match'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VSPColors.accent,
                    foregroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.button)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openCollectiveByCode() async {
    final code = _collectiveCodeController.text.trim().toUpperCase();
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    if (code.isEmpty) {
      VSPFeedback.showInfo(context, isArabic ? 'اكتب كود الدعوة أولاً.' : 'Enter the invite code first.');
      return;
    }
    if (_resolvingCollectiveInvite) return;
    setState(() => _resolvingCollectiveInvite = true);
    try {
      final data = await MatchRepository().getPrivateCollectiveInviteByCode(code);
      if (!mounted) return;
      if (data == null) {
        VSPFeedback.showError(context, isArabic ? 'كود الدعوة غير صحيح أو لم يعد متاحًا.' : 'The invite code is invalid or no longer available.');
        return;
      }
      await CollectiveMatchInviteSheet.showInviteData(context, data);
    } catch (e) {
      if (mounted) VSPFeedback.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _resolvingCollectiveInvite = false);
    }
  }
  void _showTeamCard(BuildContext context, Team team) {
    VSPFeedback.triggerSuccess();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TeamCardHero(team: team),
            const SizedBox(height: VSPSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Iconsax.close_circle_copy),
                  label: Text(AppLocalizations.of(context)!.close),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VSPColors.surfaceAlt,
                    foregroundColor: VSPColors.textPrimary,
                  ),
                ),
                const SizedBox(width: VSPSpacing.md),
                ElevatedButton.icon(
                  onPressed: () {
                    SharingService().shareText(
                      AppLocalizations.of(context)!.shareTeamText(team.name, team.rankTitle),
                    );
                  },
                  icon: const Icon(Iconsax.share_copy),
                  label: Text(AppLocalizations.of(context)!.shareLink),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VSPColors.accent,
                    foregroundColor: VSPColors.background,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
