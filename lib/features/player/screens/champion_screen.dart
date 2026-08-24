import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/egypt_governorates.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../data/models.dart';
import '../../../core/repositories/league_repository.dart';
import '../../../core/repositories/team_repository.dart';
import '../../../core/repositories/tournament_repository.dart';
import 'championship_details_screen.dart';
import 'player_home_screen.dart'; // For ChampionshipCard
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/vsp_fade_in_item.dart';

final GlobalKey<ChampionScreenState> championScreenKey = GlobalKey<ChampionScreenState>();

class ChampionScreen extends StatefulWidget {
 const ChampionScreen({super.key});

 @override
 State<ChampionScreen> createState() => ChampionScreenState();
}

class ChampionScreenState extends State<ChampionScreen>
 with SingleTickerProviderStateMixin {
 late TabController _tabController;
 int _selectedTabIndex = 0;
 String? _selectedRankingType;


 // Filter states
 String _selectedLocation = 'Cairo'; 
 String _selectedSport = 'Football'; 
 bool _isLocationInitialized = false;

 @override
 void initState() {
 super.initState();
 _tabController = TabController(length: 2, vsync: this);
 _tabController.addListener(() {
 setState(() {
 _selectedTabIndex = _tabController.index;
 });
 });
 }

 @override
 void didChangeDependencies() {
 super.didChangeDependencies();
 if (!_isLocationInitialized) {
 final auth = Provider.of<AuthProvider>(context);
 final rawGov = auth.userModel?.governorate ?? auth.governorate;
 final resolvedGov = EgyptGovernorates.resolveGoogleName(rawGov);
 if (resolvedGov != null && EgyptGovernorates.allGovernorates.contains(resolvedGov)) {
 _selectedLocation = resolvedGov;
 } else {
 final matchedGov = EgyptGovernorates.allGovernorates.firstWhere(
 (g) => g.toLowerCase() == rawGov.toLowerCase(),
 orElse: () => 'Cairo',
 );
 _selectedLocation = matchedGov;
 }
 _isLocationInitialized = true;
 }
 }
 
 void switchToTab(int index) {
 if (_tabController.length > index) {
 _tabController.animateTo(index);
 }
 }

 @override
 void dispose() {
 _tabController.dispose();
 super.dispose();
 }

 @override
 Widget build(BuildContext context) {
 return Scaffold(
 backgroundColor: VSPColors.background,
 appBar: AppBar(
 backgroundColor: VSPColors.background,
 elevation: 0,
 centerTitle: true,
 automaticallyImplyLeading: false, // Maintain no back button
 title: Text(
 AppLocalizations.of(context)!.champion,
 style: Theme.of(context).textTheme.displayMedium,
 ),
 ),
 body: SafeArea(
 top: true,
 bottom: false,
 child: Column(
 children: [
 Container(
 margin: const EdgeInsets.symmetric(horizontal: 16),
 height: 48,
 padding: const EdgeInsets.all(3),
 decoration: BoxDecoration(
 color: VSPColors.surface,
 borderRadius: BorderRadius.circular(VSPRadius.full),
 border: Border.all(color: VSPColors.divider, width: 0.5),
 ),
 child: Stack(
 children: [
 // Animated background pill
 AnimatedAlign(
 duration: const Duration(milliseconds: 220),
 curve: Curves.easeInOut,
 alignment: Directionality.of(context) == TextDirection.rtl 
 ? (_selectedTabIndex == 0 ? Alignment.centerRight : Alignment.centerLeft) 
 : (_selectedTabIndex == 0 ? Alignment.centerLeft : Alignment.centerRight),
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
 Expanded(
 child: GestureDetector(
 onTap: () => _tabController.animateTo(0),
 behavior: HitTestBehavior.opaque,
 child: Center(
 child: Text(
 AppLocalizations.of(context)!.ranking,
 style: Theme.of(context).textTheme.bodyLarge?.copyWith(
 color: _selectedTabIndex == 0
 ? Colors.black // Pure black on accent green background
 : Colors.white, // Pure white for better contrast on dark
 fontWeight: _selectedTabIndex == 0 ? FontWeight.w900 : FontWeight.bold,
 fontSize: 14,
 ),
 ),
 ),
 ),
 ),
 Expanded(
 child: GestureDetector(
 onTap: () => _tabController.animateTo(1),
 behavior: HitTestBehavior.opaque,
 child: Center(
 child: Text(
 AppLocalizations.of(context)!.championships,
 style: Theme.of(context).textTheme.bodyLarge?.copyWith(
 color: _selectedTabIndex == 1
 ? Colors.black // Pure black on accent green background
 : Colors.white, // Pure white for better contrast on dark
 fontWeight: _selectedTabIndex == 1 ? FontWeight.w900 : FontWeight.bold,
 fontSize: 14,
 ),
 ),
 ),
 ),
 ),
 ],
 ),
 ],
 ),
 ),

 const SizedBox(height: VSPSpacing.md),

 // Filters Row - Symmetrical Dropdowns
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 16),
 child: Row(
 children: [
 // Dropdown 1: Governorates
 Expanded(
 child: _buildFunctionalDropdown(
 value: _selectedLocation,
 items: EgyptGovernorates.allGovernorates,
 onChanged: (val) => setState(() => _selectedLocation = val!),
 ),
 ),
 const SizedBox(width: 8), 
 // Dropdown 2: Team Sports
 Expanded(
 child: _buildFunctionalDropdown(
 value: _selectedSport,
 items: VSPConstants.sports,
 onChanged: (val) => setState(() => _selectedSport = val!),
 ),
 ),
 const SizedBox(width: 8),
 // Dropdown 3: Ranking Type
 Expanded(
 child: _buildFunctionalDropdown(
 value: _selectedRankingType ?? AppLocalizations.of(context)!.teams,
 items: [AppLocalizations.of(context)!.teams, AppLocalizations.of(context)!.oneVsOnePlayers],
 onChanged: (val) => setState(() => _selectedRankingType = val!),
 ),
 ),
 ],
 ),
 ),

 const SizedBox(height: VSPSpacing.lg),

 // Tab Views
 Expanded(
 child: TabBarView(
 controller: _tabController,
 children: [
 _buildRankingTab(),
 _buildChampionshipsTab(),
 ],
 ),
 ),
 ],
 ),
 ),
 );
 }

 String _translateItem(String item) {
 final isArabic = AppLocalizations.of(context)!.localeName == 'ar';
 if (!isArabic) return item;
 if (EgyptGovernorates.sportsTranslations.containsKey(item)) {
 return EgyptGovernorates.getLocalizedSport(item, true);
 }
 return EgyptGovernorates.getLocalizedName(item, true);
 }

 Widget _buildFunctionalDropdown({
 required String value,
 required List<String> items,
 required ValueChanged<String?> onChanged,
 }) {
 // Ensure value is in items, otherwise fallback to first
 final effectiveValue = items.contains(value) ? value : items.first;

 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 10),
 height: 44,
 decoration: BoxDecoration(
 color: VSPColors.surface,
 borderRadius: BorderRadius.circular(VSPRadius.lg),
 border: Border.all(color: VSPColors.divider, width: 0.5),
 ),
 child: DropdownButtonHideUnderline(
 child: DropdownButton<String>(
 value: effectiveValue,
 icon: const Icon(Iconsax.arrow_down_1_copy, color: VSPColors.accent, size: 16),
 dropdownColor: VSPColors.surface,
 isExpanded: true,
 style: Theme.of(context).textTheme.bodyMedium?.copyWith(
 fontWeight: FontWeight.w500,
 fontSize: 10, // Small text for 3-column layout
 ),
 onChanged: onChanged,
 selectedItemBuilder: (BuildContext context) {
 return items.map<Widget>((String item) {
 return Container(
 alignment: AlignmentDirectional.centerStart,
 child: FittedBox(
 fit: BoxFit.scaleDown,
 child: Text(
 _translateItem(item),
 style: Theme.of(context).textTheme.bodyMedium?.copyWith(
 fontWeight: FontWeight.w500,
 fontSize: 10,
 ),
 ),
 ),
 );
 }).toList();
 },
 items: items.map<DropdownMenuItem<String>>((String item) {
 return DropdownMenuItem<String>(
 value: item,
 child: Text(
 _translateItem(item),
 overflow: TextOverflow.ellipsis,
 style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white, fontSize: 13),
 ),
 );
 }).toList(),
 ),
 ),
 );
 }

 Widget _buildRankingTab() {
 return Column(
 children: [
 // Conditional Rendering based on Dropdown selection
 Expanded(
 child: (_selectedRankingType == AppLocalizations.of(context)!.oneVsOnePlayers) 
 ? _build1v1PlayersRanking() 
 : _buildTeamsRankingStream(),
 ),
 ],
 );
 }

 Widget _build1v1PlayersRanking() {
 return StreamBuilder<List<VSP1v1Player>>(
 stream: LeagueRepository().get1v1Standings(),
 builder: (context, snapshot) {
 if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
 final players = snapshot.data ?? [];
 if (players.isEmpty) return Center(child: Text(AppLocalizations.of(context)!.noOneVsOneRanked, style: const TextStyle(color: VSPColors.textSecondary)));

 return ListView.builder(
 padding: VSPScrollPadding.forList(context, hasFloatingNavBar: true, top: 8),
 physics: const BouncingScrollPhysics(),
 itemCount: players.length,
 itemBuilder: (context, index) {
 final player = players[index];
 final isFirst = player.rank == 1;
 
 return Container(
 margin: const EdgeInsets.only(bottom: 8),
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 decoration: BoxDecoration(
 color: VSPColors.surface,
 borderRadius: BorderRadius.circular(VSPRadius.md),
 border: Border(left: BorderSide(color: isFirst ? VSPColors.accent : Colors.transparent, width: 4)),
 ),
 child: Row(
 children: [
 SizedBox(
 width: 30,
 child: Text('${player.rank}', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: isFirst ? VSPColors.accent : VSPColors.textSecondary, fontWeight: FontWeight.w900)),
 ),
 Icon(player.trend == 'up' ? Iconsax.arrow_up_1_copy : (player.trend == 'down' ? Iconsax.arrow_down_1_copy : Iconsax.minus_cirlce_copy), color: player.trend == 'up' ? VSPColors.accent : (player.trend == 'down' ? Colors.red : VSPColors.textSecondary), size: 20),
 const SizedBox(width: 12),
 CircleAvatar(
 radius: 18, 
 backgroundColor: VSPColors.surfaceAlt, 
 backgroundImage: player.avatarUrl.isNotEmpty ? NetworkImage(player.avatarUrl) : null,
 child: player.avatarUrl.isEmpty ? const Icon(Iconsax.user_copy, size: 20, color: VSPColors.accent) : null,
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(player.name.toUpperCase(), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
 Text(AppLocalizations.of(context)!.skillPointsLabel(player.skillPoints, player.goals), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary, fontSize: 10)),
 ],
 ),
 ),
 Text('${player.totalPoints}', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: VSPColors.textPrimary, fontWeight: FontWeight.w900)),
 const SizedBox(width: 4),
 Text(AppLocalizations.of(context)!.pts, style: const TextStyle(color: VSPColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
 ],
 ),
 );
 },
 );
 },
 );
 }

 Widget _buildTeamsRankingStream() {
 return StreamBuilder<List<Team>>(
 stream: TeamRepository().getTeams(),
 builder: (context, snapshot) {
 if (snapshot.connectionState == ConnectionState.waiting) {
 return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
 }

 final List<Team> allTeams = snapshot.data ?? [];

 final teams = allTeams.where((team) {
 final matchesLocation = _selectedLocation == 'All' ||
 team.governorate.toLowerCase() == _selectedLocation.toLowerCase() ||
 EgyptGovernorates.resolveGoogleName(team.governorate) == _selectedLocation ||
 (EgyptGovernorates.resolveGoogleName(team.governorate) != null &&
 EgyptGovernorates.resolveGoogleName(team.governorate) == EgyptGovernorates.resolveGoogleName(_selectedLocation));

 final matchesSport = team.sportType.toLowerCase() == _selectedSport.toLowerCase();

 return matchesLocation && matchesSport;
 }).toList();

 if (teams.isEmpty) {
 return Center(
 child: Padding(
 padding: const EdgeInsets.all(24.0),
 child: Text(
 AppLocalizations.of(context)!.noTeamsInLoc(_translateItem(_selectedLocation)), 
 textAlign: TextAlign.center,
 style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.textSecondary),
 ),
 ),
 );
 }

 // Sort by points desc
 teams.sort((a, b) => b.points.compareTo(a.points)); 

 final totalTeams = teams.length;
 final top3 = teams.take(3).toList();
 final rest = teams.skip(3).toList();
 
 if (teams.length < 3) {
 return ListView.builder(
 padding: EdgeInsets.fromLTRB(16, VSPSpacing.md, 16, MediaQuery.of(context).padding.bottom + 24),
 physics: const BouncingScrollPhysics(),
 itemCount: teams.length,
 itemBuilder: (ctx, i) => VSPFadeInItem(
 index: i,
 child: Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: _buildRankListItem(teams[i], i + 1, totalTeams: totalTeams),
 ),
 ),
 );
 }

 return SingleChildScrollView(
 keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
 padding: VSPScrollPadding.forList(context, hasFloatingNavBar: true, top: 12),
 physics: const BouncingScrollPhysics(),
 child: Column(
 children: [
 // Premium Podium
 SizedBox(
 height: 290,
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.end,
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 // Rank 2 - Left (Silver)
 Expanded(
 child: VSPFadeInItem(
 index: 1,
 child: _buildTopRankItem(
 rank: 2,
 name: top3[1].name,
 logo: top3[1].logoUrl.isNotEmpty ? top3[1].logoUrl : top3[1].captainImageUrl,
 points: top3[1].points,
 badgeIcon: '',
 borderColor: const Color(0xFFC0C0C0),
 bgColor: VSPColors.surface,
 ),
 ),
 ),
 const SizedBox(width: 10),
 // Rank 1 - Center (Gold)
 Expanded(
 child: VSPFadeInItem(
 index: 0,
 child: _buildTopRankItem(
 rank: 1,
 name: top3[0].name,
 logo: top3[0].logoUrl.isNotEmpty ? top3[0].logoUrl : top3[0].captainImageUrl,
 points: top3[0].points,
 badgeIcon: '',
 borderColor: VSPColors.accent,
 bgColor: const Color(0xFF1E2614),
 isCenter: true,
 ),
 ),
 ),
 const SizedBox(width: 10),
 // Rank 3 - Right (Bronze)
 Expanded(
 child: VSPFadeInItem(
 index: 2,
 child: _buildTopRankItem(
 rank: 3,
 name: top3[2].name,
 logo: top3[2].logoUrl.isNotEmpty ? top3[2].logoUrl : top3[2].captainImageUrl,
 points: top3[2].points,
 badgeIcon: '',
 borderColor: const Color(0xFFCD7F32),
 bgColor: VSPColors.surface,
 ),
 ),
 ),
 ],
 ),
 ),

 const SizedBox(height: 28),

 // Expanded Ranking List (#4, #5...)
 ...List.generate(rest.length, (index) {
 final team = rest[index];
 final rank = index + 4;
 return VSPFadeInItem(
 index: index + 3,
 child: Padding(
 padding: const EdgeInsets.only(bottom: 10),
 child: _buildRankListItem(team, rank, totalTeams: totalTeams),
 ),
 );
 }),

 const SizedBox(height: 20),
 ],
 ),
 );
 },
 );
 }

 Widget _buildTopRankItem({
 required int rank,
 required String name,
 required String logo,
 required int points,
 required String badgeIcon,
 required Color borderColor,
 required Color bgColor,
 bool isCenter = false,
 }) {
 final height = isCenter ? 260.0 : 210.0;
 final initialLetter = name.trim().isNotEmpty ? name.trim().split(' ').last.substring(0, 1).toUpperCase() : 'V';

 return Container(
 height: height,
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
 decoration: BoxDecoration(
 color: bgColor,
 borderRadius: BorderRadius.circular(VSPRadius.lg),
 border: Border.all(color: borderColor.withValues(alpha: isCenter ? 0.9 : 0.4), width: isCenter ? 2 : 1),
 boxShadow: isCenter
 ? [
 BoxShadow(
 color: VSPColors.accent.withValues(alpha: 0.25),
 blurRadius: 16,
 spreadRadius: 1,
 offset: const Offset(0, 4),
 )
 ]
 : [],
 ),
 child: Column(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 // Top Crown / Medal Icon
 Text(badgeIcon, style: TextStyle(fontSize: isCenter ? 26 : 20)),

 // Team Logo / Initial Avatar
 Container(
 width: isCenter ? 62 : 48,
 height: isCenter ? 62 : 48,
 decoration: BoxDecoration(
 shape: BoxShape.circle,
 color: VSPColors.surfaceAlt,
 border: Border.all(color: borderColor, width: 2),
 ),
 child: ClipOval(
 child: logo.isNotEmpty
 ? CachedNetworkImage(
 imageUrl: logo,
 fit: BoxFit.cover,
 errorWidget: (_, __, ___) => _buildInitialBadge(initialLetter, borderColor),
 )
 : _buildInitialBadge(initialLetter, borderColor),
 ),
 ),

 // Team Name
 Padding(
 padding: const EdgeInsets.symmetric(horizontal: 2),
 child: Text(
 name,
 textAlign: TextAlign.center,
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 style: Theme.of(context).textTheme.titleSmall?.copyWith(
 color: Colors.white,
 fontWeight: FontWeight.bold,
 fontSize: isCenter ? 13 : 11,
 ),
 ),
 ),

 // Points Badge
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
 decoration: BoxDecoration(
 color: borderColor.withValues(alpha: 0.15),
 borderRadius: BorderRadius.circular(VSPRadius.sm),
 ),
 child: Text(
 '$points ${AppLocalizations.of(context)!.pts}',
 style: TextStyle(
 color: isCenter ? VSPColors.accent : Colors.white70,
 fontSize: 10,
 fontWeight: FontWeight.bold,
 ),
 ),
 ),

 // Rank Pill Badge at Bottom
 Container(
 width: isCenter ? 36 : 28,
 height: isCenter ? 36 : 28,
 decoration: BoxDecoration(
 color: isCenter ? VSPColors.accent : VSPColors.surfaceAlt,
 shape: BoxShape.circle,
 ),
 alignment: Alignment.center,
 child: Text(
 '$rank',
 style: TextStyle(
 color: isCenter ? Colors.black : Colors.white,
 fontWeight: FontWeight.w900,
 fontSize: isCenter ? 18 : 13,
 ),
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildInitialBadge(String letter, Color accentColor) {
 return Container(
 color: VSPColors.surfaceAlt,
 alignment: Alignment.center,
 child: Text(
 letter,
 style: TextStyle(
 color: accentColor,
 fontWeight: FontWeight.w900,
 fontSize: 18,
 ),
 ),
 );
 }

 Widget _buildRankListItem(Team team, int rank, {bool isMyTeam = false, int totalTeams = 10}) {
 final initialLetter = team.name.trim().isNotEmpty ? team.name.trim().split(' ').last.substring(0, 1).toUpperCase() : 'T';

 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
 decoration: BoxDecoration(
 color: VSPColors.surface,
 borderRadius: BorderRadius.circular(VSPRadius.lg),
 border: isMyTeam ? Border.all(color: VSPColors.accent.withValues(alpha: 0.6)) : Border.all(color: VSPColors.divider.withValues(alpha: 0.3)),
 ),
 child: Row(
 children: [
 // Rank Number
 SizedBox(
 width: 28,
 child: Text(
 '#$rank',
 style: Theme.of(context).textTheme.titleMedium?.copyWith(
 color: rank <= 3 ? VSPColors.accent : VSPColors.textSecondary,
 fontWeight: FontWeight.w900,
 fontSize: 13,
 ),
 ),
 ),

 // Team Logo / Initial Avatar
 Container(
 width: 38,
 height: 38,
 decoration: BoxDecoration(
 shape: BoxShape.circle,
 color: VSPColors.surfaceAlt,
 border: Border.all(color: VSPColors.divider, width: 1),
 ),
 child: ClipOval(
 child: team.logoUrl.isNotEmpty
 ? CachedNetworkImage(
 imageUrl: team.logoUrl,
 fit: BoxFit.cover,
 errorWidget: (_, __, ___) => _buildInitialBadge(initialLetter, VSPColors.accent),
 )
 : _buildInitialBadge(initialLetter, VSPColors.accent),
 ),
 ),
 const SizedBox(width: 12),

 // Team Name & Match Stats
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 team.name,
 style: Theme.of(context).textTheme.bodyMedium?.copyWith(
 fontWeight: FontWeight.bold,
 color: Colors.white,
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 const SizedBox(height: 2),
 Text(
 AppLocalizations.of(context)!.teamStats(team.matchesPlayed, team.wins, team.draws, team.losses),
 style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
 ),
 ],
 ),
 ),
 // Points Column
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: VSPColors.surfaceAlt,
 borderRadius: BorderRadius.circular(VSPRadius.md),
 border: Border.all(color: VSPColors.divider.withValues(alpha: 0.4)),
 ),
 child: Text(
 AppLocalizations.of(context)!.pointsCount(team.points),
 style: const TextStyle(
 color: VSPColors.accent,
 fontWeight: FontWeight.w900,
 fontSize: 12,
 ),
 ),
 ),
 ],
 ),
 );
 }



 Widget _buildChampionshipsTab() {
 return StreamBuilder<List<Championship>>(
 stream: TournamentRepository().getChampionshipsStream(
 governorate: _selectedLocation,
 sportType: _selectedSport,
 ),
 builder: (context, snapshot) {
 if (snapshot.connectionState == ConnectionState.waiting) {
 return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
 }

 final championships = snapshot.data ?? [];

 if (championships.isEmpty) {
 return Center(
 child: Column(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 Icon(Iconsax.cup_copy, color: Colors.white.withValues(alpha: 0.1), size: 64),
 const SizedBox(height: 16),
 Text(
 AppLocalizations.of(context)!.noChampionshipsInLoc(_selectedLocation),
 style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary),
 ),
 ],
 ),
 );
 }

 return ListView.builder(
 padding: VSPScrollPadding.forList(context, hasFloatingNavBar: true, horizontal: 0, top: 16),
 physics: const BouncingScrollPhysics(),
 itemCount: championships.length,
 itemBuilder: (context, index) {
 final championship = championships[index];
 return VSPFadeInItem(
 index: index,
 child: Padding(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
 child: GestureDetector(
 onTap: () {
 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (context) => ChampionshipDetailsScreen(championship: championship),
 ),
 );
 },
 child: ChampionshipCard(championship: championship),
 ),
 ),
 );
 },
 );
 },
 );
 }
}


