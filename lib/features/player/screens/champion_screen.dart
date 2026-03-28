import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/egypt_governorates.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../../core/widgets/shimmer_image.dart';
import '../../../data/models.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/database_service.dart';
import '../../../core/repositories/tournament_repository.dart';
import 'championship_details_screen.dart';
import 'player_home_screen.dart'; // For ChampionshipCard
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/vsp_fade_in_item.dart';
import 'official_league_standings_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
    });

    // Default to user's governorate
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userGov = Provider.of<AuthProvider>(context, listen: false).governorate;
      if (userGov.isNotEmpty) {
        setState(() => _selectedLocation = userGov);
      }
    });
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
            height: 50,
            decoration: BoxDecoration(
              color: VSPColors.surface,
              borderRadius: BorderRadius.circular(VSPRadius.full), // Pill Shape
            ),
            child: Stack(
              children: [
                // Animated background pill
                AnimatedAlign(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  alignment: _selectedTabIndex == 0 ? Alignment.centerLeft : Alignment.centerRight,
                  child: FractionallySizedBox(
                    widthFactor: 0.5,
                    child: Container(
                      height: 44,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: VSPColors.accent,
                        borderRadius: BorderRadius.circular(VSPRadius.full),
                        boxShadow: [
                          BoxShadow(
                            color: VSPColors.accent.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
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
                                  ? Colors.black
                                  : VSPColors.textSecondary,
                              fontWeight: FontWeight.bold,
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
                                  ? Colors.black
                                  : VSPColors.textSecondary,
                              fontWeight: FontWeight.bold,
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

  Widget _buildFunctionalDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    // Ensure value is in items, otherwise fallback to first
    final effectiveValue = items.contains(value) ? value : items.first;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: 40,
      decoration: BoxDecoration(
        color: VSPColors.surfaceAlt,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.5)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: effectiveValue,
          icon: const Icon(Icons.keyboard_arrow_down, color: VSPColors.accent, size: 20),
          dropdownColor: VSPColors.surfaceAlt,
          isExpanded: true,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
          onChanged: onChanged,
          items: items.map<DropdownMenuItem<String>>((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
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
      stream: DatabaseService().get1v1Standings(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
        final players = snapshot.data ?? [];
        if (players.isEmpty) return Center(child: Text(AppLocalizations.of(context)!.noOneVsOneRanked, style: const TextStyle(color: VSPColors.textSecondary)));

        return ListView.builder(
          padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 110),
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
                  Icon(player.trend == 'up' ? Icons.arrow_drop_up : (player.trend == 'down' ? Icons.arrow_drop_down : Icons.remove), color: player.trend == 'up' ? VSPColors.accent : (player.trend == 'down' ? Colors.red : VSPColors.textSecondary), size: 20),
                  const SizedBox(width: 12),
                  CircleAvatar(
                    radius: 18, 
                    backgroundColor: VSPColors.surfaceAlt, 
                    backgroundImage: player.avatarUrl.isNotEmpty ? NetworkImage(player.avatarUrl) : null,
                    child: player.avatarUrl.isEmpty ? const Icon(Icons.person, size: 20, color: VSPColors.accent) : null,
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
      stream: DatabaseService().getTeams(governorate: _selectedLocation),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
        }

        final List<Team> teams = snapshot.data ?? [];

        if (teams.isEmpty) {
          return Center(
          child: Text(
            AppLocalizations.of(context)!.noTeamsInLoc(_selectedLocation), 
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.textSecondary),
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

        return SingleChildScrollView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
          padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).padding.bottom + 110),
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // 🟢 NEW: VSP OFFICIAL 1v1 BANNER
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const OfficialLeagueStandingsScreen()),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(VSPSpacing.lg),
                  margin: const EdgeInsets.only(bottom: VSPSpacing.xl), // Spacing before regular podium
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [VSPColors.accent.withValues(alpha: 0.15), VSPColors.surface],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(VSPRadius.lg),
                    border: Border.all(color: VSPColors.accent.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: VSPColors.accent.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.flash_on, color: VSPColors.accent, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.vspOfficialLeague,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppLocalizations.of(context)!.watchHighlights,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: VSPColors.accent, size: 16),
                    ],
                  ),
                ),
              ),

              // Podium
              SizedBox(
                height: 280, 
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                     // Rank 2 - Left
                     Expanded(
                       flex: 1,
                       child: VSPFadeInItem(
                         index: 1,
                         child: _buildTopRankItem(
                           rank: 2,
                           name: top3[1].name, 
                           logo: top3[1].captainImageUrl,
                           points: top3[1].points,
                           isCenter: false,
                           color: VSPColors.surface,
                         ),
                       ),
                     ),
                     
                     const SizedBox(width: 8),

                     // Rank 1 - Center
                     Expanded(
                       flex: 1, 
                       child: VSPFadeInItem(
                         index: 0,
                         child: _buildTopRankItem(
                           rank: 1,
                           name: top3[0].name,
                           logo: top3[0].captainImageUrl, 
                           points: top3[0].points,
                           isCenter: true,
                           color: VSPColors.accent,
                         ),
                       ),
                     ),

                     const SizedBox(width: 8),

                     // Rank 3 - Right
                     Expanded(
                       flex: 1, 
                       child: VSPFadeInItem(
                         index: 2,
                         child: _buildTopRankItem(
                           rank: 3,
                           name: top3[2].name, 
                           logo: top3[2].captainImageUrl,
                           points: top3[2].points,
                           isCenter: false,
                           color: VSPColors.surface,
                         ),
                       ),
                     ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Expanded Ranking List
              ...List.generate(rest.length, (index) {
                 final team = rest[index];
                 final rank = index + 4;
                 return VSPFadeInItem(
                   index: index + 3,
                   child: Padding(
                     padding: const EdgeInsets.only(bottom: 12),
                     child: _buildRankListItem(team, rank, totalTeams: totalTeams),
                   ),
                 );
              }),

              const SizedBox(height: 20),
            ],
          ),
        );
      }
    );
  }

  Widget _buildTopRankItem({
    required int rank,
    required String name,
    required String logo,
    required int points, 
    required bool isCenter,
    required Color color,
  }) {
    // Widened/Taller Rank 1 Logic
    // Height adjustments to fix overflow: 
    // Center was 220, Keep it. Rank 2/3 was 165, reduce slightly or keep but adjust internal padding.
    // Let's optimize heights to be sure.
    final height = isCenter ? 230.0 : 170.0; 
    final textColor = isCenter ? VSPColors.background : VSPColors.textPrimary;

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(VSPRadius.lg), 
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Logo (Circular)
          Container(
            width: isCenter ? 65 : 45,
            height: isCenter ? 65 : 45,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            padding: const EdgeInsets.all(4),
            child: ClipOval(
              child: ShimmerImage(
                imageUrl: logo,
                width: isCenter ? 57 : 37,
                height: isCenter ? 57 : 37,
                fit: BoxFit.contain,
              ),
            ),
          ),
          SizedBox(height: isCenter ? 8 : 4), // Dynamic Spacing
          
          // Name
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
           
           // Dynamic Spacing
           SizedBox(height: isCenter ? 6 : 4),
           
           // Real Avatars Stack (No generic icons)
            SizedBox(
              width: 60,
              height: 24, 
              child: Stack(
                alignment: Alignment.center,
                children: List.generate(3, (index) => Positioned(
                     left: index * 12.0, 
                     child: Container(
                       width: 24,
                       height: 24,
                       decoration: BoxDecoration(
                         border: Border.all(color: color, width: 1.5),
                         shape: BoxShape.circle,
                       ),
                       child: ClipRRect(
                         borderRadius: BorderRadius.circular(12),
                         child: CachedNetworkImage(
                           imageUrl: '', // Removed fake randomuser.me avatars
                           fit: BoxFit.cover,
                            placeholder: (context, url) => Container(color: VSPColors.surfaceAlt),
                            errorWidget: (context, url, error) => const Icon(Icons.person, color: VSPColors.textSecondary, size: 16), 
                         ),
                       ),
                     )
                   ),)
              ),
            ),
            
             // Rank Number
             if (isCenter) ...[
                const Spacer(),
                Text(
                  '$rank',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: textColor,
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
             ] else ...[
                 const SizedBox(height: 8), 
                 Row(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                     Icon(
                       Icons.remove, // Neutral fallback for nonexistent trend data
                        color: VSPColors.textSecondary,
                       size: 16,
                     ),
                     Text(
                       '$rank',
                       style: Theme.of(context).textTheme.titleLarge?.copyWith(
                         color: textColor,
                         fontWeight: FontWeight.bold,
                       ),
                     )
                   ],
                 )
             ]
        ],
      ),
    );
  }

  Widget _buildRankListItem(Team team, int rank, {bool isMyTeam = false, int totalTeams = 10}) {
    // Promotion/Relegation status color code
    Color? statusColor;
    if (rank <= 3) statusColor = VSPColors.accent.withValues(alpha: 0.08); // Promotion zone
    if (rank >= totalTeams - 2 && totalTeams > 5) statusColor = VSPColors.error.withValues(alpha: 0.08); // Relegation zone

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: statusColor ?? VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: isMyTeam ? Border.all(color: VSPColors.accent.withValues(alpha: 0.5)) : null,
      ),
      child: Row(
        children: [
          // Visual Indicator Line for Promotion/Relegation
          if (statusColor != null)
            Container(
              width: 3,
              height: 25,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: rank <= 3 ? VSPColors.accent : VSPColors.error,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            padding: const EdgeInsets.all(3),
            child: ClipOval(
              child: ShimmerImage(
                imageUrl: team.captainImageUrl,
                width: 34,
                height: 34,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  team.name,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  AppLocalizations.of(context)!.teamStats(team.matchesPlayed, team.wins, team.draws, team.losses),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: VSPColors.textSecondary.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          
          // Small Trend Arrow
          const Icon(
             Icons.remove, // Neutral fallback for nonexistent trend data
             color: VSPColors.textSecondary, 
             size: 16
          ),
          const SizedBox(width: 4),
          Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                   Text(
                    '$rank', // Pos
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    AppLocalizations.of(context)!.pointsCount(team.points),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
                  ),
              ],
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
                Icon(Icons.emoji_events_outlined, color: Colors.white.withValues(alpha: 0.1), size: 64),
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
          padding: EdgeInsets.fromLTRB(0, 16, 0, MediaQuery.of(context).padding.bottom + 110),
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
