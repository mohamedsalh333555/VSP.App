import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/widgets/shimmer_image.dart';
import '../../../data/models.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/database_service.dart';
import 'championship_details_screen.dart';
import 'player_home_screen.dart'; // For ChampionshipCard

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
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false, // Maintain no back button
        title: const Text(
          'Champion',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            fontFamily: 'Agency FB',
          ),
        ),
      ),
      body: Column(
        children: [
          // Capsule Tab Bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            height: 50,
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(25), // Pill Shape
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _tabController.animateTo(0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _selectedTabIndex == 0
                            ? AppTheme.neonGreen
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Ranking',
                        style: TextStyle(
                          color: _selectedTabIndex == 0
                              ? Colors.black
                              : AppTheme.textSecondary,
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
                    child: Container(
                      decoration: BoxDecoration(
                        color: _selectedTabIndex == 1
                            ? AppTheme.neonGreen
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Championships', // Reverted Label
                        style: TextStyle(
                          color: _selectedTabIndex == 1
                              ? Colors.black
                              : AppTheme.textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          const SizedBox(height: 16),

          const SizedBox(height: 16),

          // Filters Row - Symmetrical Dropdowns
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Dropdown 1: Governorates
                Expanded(
                  child: _buildFunctionalDropdown(
                    value: _selectedLocation,
                    items: const [
                      'Cairo', 'Alexandria', 'Giza', 'Dakahlia', 'Red Sea', 
                      'Luxor', 'Aswan', 'Gharbia', 'Port Said', 'Suez', 
                      'Ismailia', 'Minya', 'Assiut'
                    ],
                    onChanged: (val) => setState(() => _selectedLocation = val!),
                  ),
                ),
                const SizedBox(width: 8), 
                // Dropdown 2: Team Sports
                Expanded(
                  child: _buildFunctionalDropdown(
                    value: _selectedSport,
                    items: const ['Football', 'Basketball', 'Volleyball', 'Handball', 'Padel'],
                    onChanged: (val) => setState(() => _selectedSport = val!),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

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
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.neonGreen.withValues(alpha: 0.5)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: effectiveValue,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.neonGreen, size: 20),
          dropdownColor: const Color(0xFF1E1E1E),
          isExpanded: true,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            fontFamily: 'Inter',
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
    return StreamBuilder<List<Team>>(
      stream: DatabaseService().getTeams(governorate: _selectedLocation),
      builder: (context, snapshot) {
        List<Team> teams = [];
        
        if (AppConfig.demoMode) {
          teams = Team.getMockTeams()
              .where((t) => t.governorate == _selectedLocation)
              .toList();
        } else {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.neonGreen));
          }
          teams = snapshot.data ?? [];
        }

        if (teams.isEmpty) {
          return Center(
            child: Text(
              "No teams in $_selectedLocation yet", 
              style: const TextStyle(color: Colors.grey)
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
            padding: const EdgeInsets.all(16),
            itemCount: teams.length,
            itemBuilder: (ctx, i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildRankListItem(teams[i], i + 1, totalTeams: totalTeams),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
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
                       child: _buildTopRankItem(
                         rank: 2,
                         name: top3[1].name, 
                         logo: top3[1].captainImageUrl,
                         points: top3[1].points,
                         isCenter: false,
                         color: AppTheme.cardBackground,
                       ),
                     ),
                     
                     const SizedBox(width: 8),

                     // Rank 1 - Center
                     Expanded(
                       flex: 1, 
                       child: _buildTopRankItem(
                         rank: 1,
                         name: top3[0].name,
                         logo: top3[0].captainImageUrl, 
                         points: top3[0].points,
                         isCenter: true,
                         color: AppTheme.neonGreen,
                       ),
                     ),

                     const SizedBox(width: 8),

                     // Rank 3 - Right
                     Expanded(
                       flex: 1, 
                       child: _buildTopRankItem(
                         rank: 3,
                         name: top3[2].name, 
                         logo: top3[2].captainImageUrl,
                         points: top3[2].points,
                         isCenter: false,
                         color: AppTheme.cardBackground,
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
                 return Padding(
                   padding: const EdgeInsets.only(bottom: 12),
                   child: _buildRankListItem(team, rank, totalTeams: totalTeams),
                 );
              }),

              const SizedBox(height: 100),
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
    final textColor = isCenter ? Colors.black : Colors.white;

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(15), // 15px
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
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w500,
              fontSize: 13,
              fontFamily: 'Agency FB', 
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
                           imageUrl: 'https://randomuser.me/api/portraits/men/${index + 20 + rank}.jpg',
                           fit: BoxFit.cover,
                           placeholder: (context, url) => Container(color: Colors.grey[800]),
                           errorWidget: (context, url, error) => Container(color: Colors.grey[600]), 
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
                  style: TextStyle(
                    color: textColor,
                    fontSize: 48,
                    fontWeight: FontWeight.w900, // Condensed Bold
                    fontFamily: 'Agency FB',
                    height: 1.0,
                  ),
                ),
             ] else ...[
                 const SizedBox(height: 8), 
                 Row(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                     Icon(
                       rank == 3 ? Icons.arrow_drop_down : Icons.arrow_drop_up,
                       color: rank == 3 ? Colors.red : AppTheme.neonGreen,
                       size: 16,
                     ),
                     Text(
                       '$rank',
                       style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
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
    if (rank <= 3) statusColor = Colors.green.withOpacity(0.08); // Promotion zone
    if (rank >= totalTeams - 2 && totalTeams > 5) statusColor = Colors.red.withOpacity(0.08); // Relegation zone

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: statusColor ?? AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(15),
        border: isMyTeam ? Border.all(color: AppTheme.neonGreen.withOpacity(0.5)) : null,
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
                color: rank <= 3 ? Colors.green : Colors.red,
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
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Agency FB',
                  ),
                ),
                Text(
                  'MP: ${team.matchesPlayed} | W: ${team.wins} | D: ${team.draws} | L: ${team.losses}',
                  style: TextStyle(
                    color: AppTheme.textSecondary.withValues(alpha: 0.7),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          
          // Small Trend Arrow
          Icon(
             rank % 2 == 0 ? Icons.arrow_drop_down : Icons.arrow_drop_up, 
             color: rank % 2 == 0 ? Colors.red : AppTheme.neonGreen, 
             size: 16
          ),
          const SizedBox(width: 4),
          Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                   Text(
                    '$rank', // Pos
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Agency FB',
                    ),
                  ),
                  Text(
                    '${team.points} pts',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 10,
                    ),
                  ),
              ],
          ),
        ],
      ),
    );
  }



  Widget _buildChampionshipsTab() {
    return StreamBuilder<List<Championship>>(
      stream: DatabaseService().getChampionshipsStream(
        governorate: _selectedLocation,
        sportType: _selectedSport,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.neonGreen));
        }

        final championships = snapshot.data ?? [];

        if (championships.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_events_outlined, color: Colors.white.withOpacity(0.1), size: 64),
                const SizedBox(height: 16),
                Text(
                  "No championships in $_selectedLocation yet",
                  style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 16),
          itemCount: championships.length,
          itemBuilder: (context, index) {
            final championship = championships[index];
            return Padding(
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
            );
          },
        );
      },
    );
  }
}
