import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_theme.dart';
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
  // Removed global state for Type since we are removing that filter

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
      stream: DatabaseService().getTeams(), // Fetches streams
      builder: (context, snapshot) {
        
        // Demo Mode Logic
        if (AppConfig.demoMode) {
           var teams = Team.getMockTeams();
           teams.sort((a, b) => b.points.compareTo(a.points));
           
           // Copy-paste the rest of rendering logic
            // Split Top 3 and Rest
            final top3 = teams.take(3).toList();
            final rest = teams.skip(3).toList();
            
            if (teams.length < 3) {
                 return ListView.builder(
                   itemCount: teams.length,
                   itemBuilder: (ctx, i) => _buildRankListItem(i + 1, teams[i].name, teams[i].captainImageUrl, false, i + 1, teams[i].points),
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
                       child: _buildRankListItem(rank, team.name, team.captainImageUrl, false, rank, team.points),
                     );
                  }),

                  const SizedBox(height: 100),
                ],
              ),
            );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.neonGreen));
        }

        // Sort by points desc
        var teams = snapshot.data!;
        teams.sort((a, b) => b.points.compareTo(a.points)); 

        if (teams.isEmpty) return const Center(child: Text("No rankings yet", style: TextStyle(color: Colors.grey)));

        // Split Top 3 and Rest
        final top3 = teams.take(3).toList();
        final rest = teams.skip(3).toList();
        
        // Ensure we have enough data for podium logic (Safe checks)
        // If less than 3, we just show what we have in list or simplified podium
        // Simplified: if < 3, just list. Else Podium.
        if (teams.length < 3) {
             return ListView.builder(
               itemCount: teams.length,
               itemBuilder: (ctx, i) => _buildRankListItem(i + 1, teams[i].name, teams[i].captainImageUrl, false, i + 1, teams[i].points),
             );
        }

        // Mapping Podium: Center=Rank 1 (index 0), Left=Rank 2 (index 1), Right=Rank 3 (index 2)
        // Adjust indices for visual order: Left(1), Center(0), Right(2)
        
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
                   child: _buildRankListItem(rank, team.name, team.captainImageUrl, false, rank, team.points),
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

  Widget _buildRankListItem(int rank, String name, String logo, bool isMyTeam, int currentRank, int points) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(15), // 15px
        border: isMyTeam ? Border.all(color: AppTheme.neonGreen.withValues(alpha: 0.5)) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            padding: const EdgeInsets.all(3),
            child: ClipOval(
              child: ShimmerImage(
                imageUrl: logo,
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
                  name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Agency FB',
                  ),
                ),
                // Real Faces Stack
                SizedBox(
                  width: 80,
                  height: 20,
                  child: Stack(
                    children: List.generate(4, (index) => Positioned(
                         left: index * 14.0, 
                         child: Container(
                           width: 20,
                           height: 20,
                           decoration: BoxDecoration(
                             border: Border.all(color: AppTheme.cardBackground, width: 1.5),
                             shape: BoxShape.circle,
                           ),
                           child: ClipRRect(
                             borderRadius: BorderRadius.circular(10),
                             child: CachedNetworkImage(
                               imageUrl: 'https://randomuser.me/api/portraits/men/${index + rank * 5}.jpg',
                               fit: BoxFit.cover,
                               placeholder: (context, url) => Container(color: Colors.grey[800]),
                               errorWidget: (context, url, error) => Container(color: Colors.grey[600]), 
                             ),
                           ),
                         )
                       ),)
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
                    '$points pts',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
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
    final championships = Championship.getMockChampionships();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: championships.length,
      itemBuilder: (context, index) {
        final championship = championships[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Margin fix: 16 horz, 8 vert
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
  }
}
