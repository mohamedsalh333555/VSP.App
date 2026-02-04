import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models.dart';
import 'player_home_screen.dart'; // To access ChampionshipCard if needed or we build the specific uniform card here

class ChampionshipDetailsScreen extends StatelessWidget {
  final Championship championship;

  const ChampionshipDetailsScreen({super.key, required this.championship});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: Stack(
        children: [
          // 1. Header Image
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 280, // Taller header to allow overlap
            child: ShaderMask(
              shaderCallback: (rect) {
                return const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black, Colors.transparent],
                ).createShader(Rect.fromLTRB(0, 0, rect.width, rect.height));
              },
              blendMode: BlendMode.dstIn,
              child: Image.network(
                'https://images.unsplash.com/photo-1577223625816-7546f13df25d?w=800&fit=crop', // Real stadium photo
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[900]),
              ),
            ),
          ),
          
          // Back & Favorite Buttons
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInteractiveCircleIcon(
                  context, 
                  Icons.arrow_back, 
                  () => Navigator.of(context).pop(),
                ),
                StatefulBuilder(
                  builder: (context, setState) {
                    bool isFav = false; // Local state for demo, ideally passed from parent or provider
                    return _buildInteractiveCircleIcon(
                      context, 
                       isFav ? Icons.favorite : Icons.favorite_border,
                      () {
                         setState(() => isFav = !isFav); // Toggle local state
                      },
                      color: isFav ? Colors.red : Colors.white,
                    );
                  }
                ),
              ],
            ),
          ),

          // Main Content
          SingleChildScrollView(
            padding: const EdgeInsets.only(top: 220), // Start below header
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 2. Overlapping Unified Championship Card - Width Fixed to Infinity
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Hero(
                    tag: 'champion_card_${championship.id}',
                    child: SizedBox(
                      width: double.infinity, // Force full width
                      child: ChampionshipCard(championship: championship), 
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 3. Tournament Timeline (Rounds)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Row(
                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                           children: [
                             Text(
                               'Schedule',
                               style: TextStyle(
                                 color: AppTheme.textPrimary.withOpacity(0.9), 
                                 fontWeight: FontWeight.bold,
                                 fontSize: 16
                               )
                             ),
                             Container(
                               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                               decoration: BoxDecoration(
                                 color: Colors.white.withOpacity(0.05),
                                 borderRadius: BorderRadius.circular(8),
                               ),
                               child: const Text('Expand', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                             )
                           ],
                         ),
                         const SizedBox(height: 16),
                         // Vertical timeline
                         _buildTimelineStep('Aug 6-7', 'First Round', true, true),
                         _buildTimelineStep('Aug 9-10', 'Second Round', true, true),
                         _buildTimelineStep('Aug 12-13', 'Third Round', true, true),
                         _buildTimelineStep('Aug 15-16', 'Four Round', false, false),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // 4. Content Sections
                _buildSection(
                  'About The Tournament',
                  'Welcome To The ACD Sal Football League!\nThis Tournament Is Organized By The ACD Public Stadium For Football Fans.\nThe Final Edition Will Be Held From August 6 To September 30, 2025.',
                ),
                _buildSection(
                  'Match Rules And Regulations',
                  'Each Match Lasts 20 Minutes (Two Halves, Each Half Lasting 10 Minutes).\nTeams Must Arrive 15 Minutes Before The Start Of The Match.\nA Team That Is More Than 10 Minutes Late Will Be Considered Forfeited.\nThe Tournament Is A League System, And The Top Teams Advance To The Knockout Stage.\nA Maximum Of 3 Substitutions Are Permitted Per Match.\nAny Unsportsmanlike Conduct Will Result In Immediate Disqualification.',
                ),
                _buildSection(
                  'Important Instructions For Players',
                  'Each Player Must Wear Designated Sports Shoes (Kochi)—Barefoot Play Is Not Permitted.\nPlayers Must Bring Their Own Sports Clothing And Equipment.\nPlease Keep The Field Clean And Follow The Organizers\' Instructions.\nRespect The Referees, Organizers, And Other Participants.\nAny Team That Causes Disruption Or Trouble May Be Banned From Future Tournaments.',
                ),

                const SizedBox(height: 100), // Space for Join Button
              ],
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.neonGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
            ),
            child: const Text(
              'Join',
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Agency FB', // Condensed look
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              color: AppTheme.textSecondary.withOpacity(0.7),
              fontSize: 14,
              height: 1.6,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep(String date, String title, bool isActive, bool hasNext) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: isActive ? Colors.white : Colors.grey.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                ),
                if (hasNext)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date,
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                            color: Colors.grey, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: TextStyle(
                          color: isActive ? Colors.white.withOpacity(0.7) : Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveCircleIcon(BuildContext context, IconData icon, VoidCallback onTap, {Color color = Colors.white}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: color, size: 20),
        onPressed: onTap,
      ),
    );
  }
}
