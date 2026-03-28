import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../data/models.dart';
import '../../../core/repositories/stadium_repository.dart';
import '../../../core/repositories/match_repository.dart';
import '../../../core/services/sharing_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/providers/stadium_provider.dart';
import '../../../shared/widgets/vsp_bottom_nav_bar.dart';
import '../../../shared/widgets/vsp_fade_in_item.dart';
import '../../../core/widgets/promo_slider.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../shared/widgets/public_match_card.dart';
import '../../../core/ui/components/vsp_section_title.dart';
import '../../../core/constants/egypt_governorates.dart';
import '../../../core/repositories/tournament_repository.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../shared/widgets/stadium_card.dart';
import 'stadium_details_screen.dart';
import 'team_dashboard_screen.dart';
import 'booked_screen.dart';
import 'champion_screen.dart';
import 'profile_screen.dart';
import 'championship_details_screen.dart';
import '../widgets/filter_bottom_sheet.dart';
import 'global_search_screen.dart';

// المفتاح العالمي للتحكم في تبويبات صفحة البطل
final GlobalKey<ChampionScreenState> championScreenKey = GlobalKey<ChampionScreenState>();

class PlayerHomeScreen extends StatefulWidget {
  const PlayerHomeScreen({super.key});

  @override
  State<PlayerHomeScreen> createState() => _PlayerHomeScreenState();
}

class _PlayerHomeScreenState extends State<PlayerHomeScreen> {
  int _selectedIndex = 0;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Set system status bar style to match the dark theme
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light, // White icons
      statusBarBrightness: Brightness.dark, // iOS specific
    ));

    return Scaffold(
      extendBody: true,
      backgroundColor: VSPColors.background,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _HomeContent(
            searchController: _searchController,
            onNavigate: (index, {arguments}) {
              setState(() {
                _selectedIndex = index;
                if (index == 2 && arguments != null && arguments['initialTab'] != null) {
                   championScreenKey.currentState?.switchToTab(arguments['initialTab']);
                }
              });
            },
          ),
          const TeamDashboardScreen(),
          ChampionScreen(key: championScreenKey),
          const BookedScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: VspBottomNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: (index) => setState(() => _selectedIndex = index),
        items: [
          VspNavItem(activeIcon: Icons.home_rounded, inactiveIcon: Icons.home_outlined, label: AppLocalizations.of(context)!.homeNav),
          VspNavItem(activeIcon: Icons.groups_rounded, inactiveIcon: Icons.groups_outlined, label: AppLocalizations.of(context)!.matchesNav),
          VspNavItem(activeIcon: Icons.emoji_events_rounded, inactiveIcon: Icons.emoji_events_outlined, label: AppLocalizations.of(context)!.championNav),
          VspNavItem(activeIcon: Icons.bookmark_rounded, inactiveIcon: Icons.bookmark_outline_rounded, label: AppLocalizations.of(context)!.bookedNav),
          VspNavItem(activeIcon: Icons.person_rounded, inactiveIcon: Icons.person_outline_rounded, label: AppLocalizations.of(context)!.profileNav),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// مكونات الصفحة الرئيسية
// -----------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onSeeAll;

  const _SectionHeader({required this.title, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          VSPSectionTitle(title),
          TextButton(
            onPressed: onSeeAll,
            child: Text(AppLocalizations.of(context)!.seeAll, style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class ChampionshipCard extends StatelessWidget {
  final Championship championship;
  final double? width;
  final EdgeInsetsGeometry? margin;

  const ChampionshipCard({super.key, required this.championship, this.width, this.margin});

  @override
  Widget build(BuildContext context) {
    final int remainingTeams = (championship.maxTeams - championship.joinedTeams.length).clamp(0, championship.maxTeams);

    return Container(
      width: width ?? 320,
      padding: const EdgeInsets.all(16),
      margin: margin ?? EdgeInsets.zero,
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.xl),
        border: Border.all(
          color: VSPColors.divider,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTypeBadge(AppLocalizations.of(context)!.tournament),
              _buildStatusBadge(
                championship.status == 'open' 
                    ? AppLocalizations.of(context)!.open.toUpperCase() 
                    : AppLocalizations.of(context)!.full.toUpperCase(), 
                championship.status == 'open' ? Colors.green : VSPColors.accent
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3), width: 2)),
                child: ClipOval(
                  child: championship.logoUrl.isNotEmpty
                      ? CachedNetworkImage(imageUrl: championship.logoUrl, fit: BoxFit.cover, errorWidget: (_, __, ___) => const Icon(Icons.emoji_events, color: VSPColors.accent))
                      : const Icon(Icons.emoji_events, color: VSPColors.accent, size: 28),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(championship.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 0.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(championship.type, style: const TextStyle(color: VSPColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.ios_share, color: VSPColors.textSecondary, size: 20), 
                onPressed: () => SharingService.shareChampionship(id: championship.id, name: championship.name, date: DateFormat('MMM d').format(championship.startDate))
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCompactInfo(Icons.calendar_month, DateFormat('MMM d').format(championship.startDate)),
                _buildDivider(),
                _buildCompactInfo(Icons.emoji_events_outlined, "${championship.grandPrize.toInt()} ${AppLocalizations.of(context)!.egCurrency}"),
                _buildDivider(),
                _buildCompactInfo(Icons.payments_outlined, "${championship.entryFee.toInt()} ${AppLocalizations.of(context)!.egCurrency}"),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        "$remainingTeams",
                        style: const TextStyle(
                          color: VSPColors.accent,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        AppLocalizations.of(context)!.spotsLeft,
                        style: const TextStyle(
                          color: VSPColors.textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  Text(AppLocalizations.of(context)!.teamsJoined(championship.joinedTeams.length, championship.maxTeams), style: TextStyle(color: VSPColors.textSecondary.withValues(alpha: 0.6), fontSize: 10, fontWeight: FontWeight.w500)),
                ],
              ),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChampionshipDetailsScreen(championship: championship))),
                child: Container(
                  height: 44.0, padding: const EdgeInsets.symmetric(horizontal: 32),
                  decoration: BoxDecoration(color: VSPColors.accent, borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text(AppLocalizations.of(context)!.joinMatch, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.0))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBadge(String text) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: VSPColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3))), child: Text(text, style: const TextStyle(color: VSPColors.accent, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.0)));

  Widget _buildStatusBadge(String text, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.4))), child: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 6), Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold))]));

  Widget _buildCompactInfo(IconData icon, String label) => Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: VSPColors.accent, size: 14), const SizedBox(width: 6), Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))]);

  Widget _buildDivider() => Container(width: 1, height: 14, color: Colors.white10);
}

class _HomeContent extends StatelessWidget {
  final TextEditingController searchController;
  final Function(int, {Map<String, dynamic>? arguments}) onNavigate;

  const _HomeContent({required this.searchController, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final stadiumProvider = Provider.of<StadiumProvider>(context);

    return Column(
      children: [
        _buildTopBar(context, auth),
        Expanded(
          child: SingleChildScrollView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              children: [
                const SizedBox(height: 16),
                _buildPromos(),
                const SizedBox(height: 24),
                _buildStadiumsList(context, stadiumProvider),
                const SizedBox(height: 32),
                _buildMatchesList(context),
                const SizedBox(height: 32),
                _buildChampionshipsList(context, auth),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context, AuthProvider auth) {
    return SafeArea(
      top: true,
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 10, left: 16, right: 16, bottom: 16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 25, backgroundColor: VSPColors.surface, 
                  backgroundImage: auth.userModel?.profileImageUrl != null ? NetworkImage(auth.userModel!.profileImageUrl!) : null, 
                  child: auth.userModel?.profileImageUrl == null ? const Icon(Icons.person, color: VSPColors.textSecondary) : null
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${AppLocalizations.of(context)!.hi} ${auth.userModel?.name?.split(' ').first ?? AppLocalizations.of(context)!.playerDefaultName}', style: Theme.of(context).textTheme.titleLarge),
                      GestureDetector(
                        onTap: () => _handleLocationPicker(context, auth),
                        child: Row(children: [const Icon(Icons.location_on, color: VSPColors.accent, size: 14), const SizedBox(width: 4), Text(auth.userModel?.governorate ?? AppLocalizations.of(context)!.selectLocation, style: const TextStyle(color: VSPColors.textSecondary, fontWeight: FontWeight.bold, decoration: TextDecoration.underline))]),
                      ),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.notifications_none, color: Colors.white), onPressed: () {}),
              ],
            ),
            const SizedBox(height: 16),
            _buildSearchBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GlobalSearchScreen())),
            child: Container(
              height: 50,
              padding: const EdgeInsets.only(left: 6, right: 16),
              decoration: BoxDecoration(
                color: VSPColors.surfaceAlt,
                borderRadius: BorderRadius.circular(VSPRadius.full),
                border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3), width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: VSPColors.background.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.search, color: VSPColors.accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      enabled: false,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      textAlignVertical: TextAlignVertical.center,
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)!.searchStadiums,
                        hintStyle: const TextStyle(color: VSPColors.textSecondary, fontSize: 14),
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        InkWell(
          onTap: () async {
            final result = await showModalBottomSheet<Map<String, dynamic>>(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (context) => Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                child: const FilterBottomSheet(),
              ),
            );
            if (result != null && context.mounted) {
              context.read<StadiumProvider>().applyFilters(result);
            }
          },
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: VSPColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.tune, color: VSPColors.accent),
          ),
        ),
      ],
    );
  }

  Widget _buildPromos() => StreamBuilder<List<Promotion>>(stream: StadiumRepository().getPromotionsStream(), builder: (context, snapshot) => snapshot.hasData ? PromoSlider(promotions: snapshot.data!) : const SizedBox.shrink());

  Widget _buildStadiumsList(BuildContext context, StadiumProvider provider) {
    if (provider.stadiums.isEmpty && !provider.isLoading) {
      final cityName = context.read<AuthProvider>().userModel?.governorate ?? 'your area';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          children: [
            Text(
              '${AppLocalizations.of(context)!.noStadiumsFoundIn} $cityName',
              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => provider.fetchStadiums(isRefresh: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: VSPColors.surfaceAlt,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.xl)),
              ),
              child: Text(AppLocalizations.of(context)!.refresh, style: const TextStyle(color: VSPColors.accent)),
            )
          ],
        ),
      );
    }

    return Column(
      children: [
        _SectionHeader(title: AppLocalizations.of(context)!.nearbyStadiums, onSeeAll: () {}),
        const SizedBox(height: 16),
        SizedBox(
          height: 210,
          child: provider.isLoading && provider.stadiums.isEmpty
              ? ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: 3, itemBuilder: (_, __) => const CardSkeleton())
              : ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: provider.stadiums.length, itemBuilder: (context, i) => Container(width: 300, margin: const EdgeInsets.only(right: 12), child: StadiumCard(stadium: provider.stadiums[i], onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StadiumDetailsScreen(stadium: provider.stadiums[i])))))),
        ),
      ],
    );
  }

  Widget _buildMatchesList(BuildContext context) {
    return StreamBuilder<List<Booking>>(
      stream: MatchRepository().getPublicMatches(), 
      builder: (context, snapshot) {
        final matches = snapshot.data ?? [];
        return Column(
          children: [
            _SectionHeader(title: AppLocalizations.of(context)!.joinMatches, onSeeAll: () => onNavigate(1)),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: matches.isEmpty && snapshot.connectionState == ConnectionState.waiting
                  ? ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: 3, itemBuilder: (_, __) => const CardSkeleton())
                  : ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: matches.length, itemBuilder: (context, i) => Align(alignment: Alignment.topCenter, child: Container(width: 320, margin: const EdgeInsets.only(right: 12), child: PublicMatchCard(booking: matches[i])))),
            ),
          ],
        );
      }
    );
  }

  Widget _buildChampionshipsList(BuildContext context, AuthProvider auth) {
    return StreamBuilder<List<Championship>>(
      stream: TournamentRepository().getChampionshipsStream(governorate: auth.userModel?.governorate), 
      builder: (context, snapshot) {
        final championships = snapshot.data ?? [];
        return Column(
          children: [
            _SectionHeader(title: AppLocalizations.of(context)!.joinChampionships, onSeeAll: () => onNavigate(2, arguments: {'initialTab': 1})),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: championships.isEmpty && snapshot.connectionState == ConnectionState.waiting
                  ? ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: 3, itemBuilder: (_, __) => const CardSkeleton())
                  : ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: championships.length, itemBuilder: (context, i) => Align(alignment: Alignment.topCenter, child: Container(width: 320, margin: const EdgeInsets.only(right: 12), child: ChampionshipCard(championship: championships[i])))),
            ),
          ],
        );
      }
    );
  }

  void _handleLocationPicker(BuildContext context, AuthProvider auth) {
    showModalBottomSheet(context: context, backgroundColor: VSPColors.surface, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (context) {
      final governorates = EgyptGovernorates.allGovernorates;
      return Container(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(AppLocalizations.of(context)!.selectLocation, style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 16), Expanded(child: ListView.builder(itemCount: governorates.length, itemBuilder: (context, index) { final gov = governorates[index]; final isSelected = auth.userModel?.governorate == gov; return ListTile(leading: Icon(Icons.location_city, color: isSelected ? VSPColors.accent : VSPColors.textSecondary), title: Text(gov, style: TextStyle(color: isSelected ? VSPColors.accent : Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)), trailing: isSelected ? const Icon(Icons.check, color: VSPColors.accent) : null, onTap: () { auth.updateProfile({'governorate': gov}); context.read<StadiumProvider>().applyGovernorateFilter(gov); Navigator.pop(context); }); }))]));
    });
  }
}
