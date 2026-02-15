import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shimmer_image.dart';
import '../../../data/models.dart';

class TournamentDetailsScreen extends StatelessWidget {
  final Championship championship;

  const TournamentDetailsScreen({
    super.key,
    required this.championship,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Champion',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border, color: Colors.red),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card with Hero
            Hero(
              tag: 'championship_card_${championship.id}',
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppTheme.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(
                    children: [
                      // Background Image
                      Positioned.fill(
                        child: ShimmerImage(
                          imageUrl: 'https://images.unsplash.com/photo-1522778119026-d647f0596c20?w=1200&q=80',
                          fit: BoxFit.cover,
                          errorWidget: const Icon(Icons.sports_soccer, color: AppTheme.textSecondary),
                        ),
                      ),
                      // Content
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Logo
                            Container(
                              width: 60,
                              height: 60,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                              ),
                              child: ShimmerImage(
                                imageUrl: championship.logoUrl,
                                width: 60,
                                height: 60,
                                borderRadius: 30,
                                errorWidget: const Icon(Icons.emoji_events_outlined, color: AppTheme.textSecondary),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    championship.name,
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    championship.type,
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Matches Button
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppTheme.neonGreen,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Matches',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Stats Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatItem('Date', '${championship.startDate} - ${championship.endDate}'),
                  _buildStatItem('Entry Fee', '${championship.entryFee.toStringAsFixed(0)} eg'),
                  _buildStatItem('Grand Prize', '${championship.grandPrize.toStringAsFixed(0)} eg'),
                ],
              ),
            ),
             const SizedBox(height: 16),
             // Teams Joined (Visual indicator)
             Row(
                children: [
                   ...championship.teamLogos.take(5).map((logo) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                         child: ShimmerImage(
                             imageUrl: logo,
                             width: 24,
                             height: 24,
                             borderRadius: 12,
                           ),
                   )),
                    const SizedBox(width: 8),
                   Text(
                     'Teams Joined: ${championship.teamsJoined} / ${championship.maxTeams}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                   )
                ]
             ),

            const SizedBox(height: 24),

            // Timeline Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       // Dates (Left)
                       Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: const [
                           Text('Aug 6-7', style: TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
                           SizedBox(height: 24),
                           Text('Aug 9-10', style: TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
                           SizedBox(height: 24),
                           Text('Aug 12-13', style: TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
                           SizedBox(height: 24),
                           Text('Aug 15-16', style: TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
                         ],
                       ),
                       // Visual Line (Center)
                       Container(
                         height: 150,
                         width: 2,
                         color: Colors.grey,
                         child: Stack(
                           alignment: Alignment.center,
                           children: [
                             Positioned(top: 0, child: _buildTimelineDot()),
                             Positioned(top: 40, child: _buildTimelineDot()),
                             Positioned(top: 80, child: _buildTimelineDot()),
                             Positioned(bottom: 10, child: _buildTimelineDot()),
                           ],
                         ),
                       ),
                        // Rounds (Right)
                       Expanded(
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: const [
                             Padding(padding: EdgeInsets.only(left: 12), child: Text('First Round...', style: TextStyle(color: AppTheme.textSecondary))),
                             SizedBox(height: 24),
                             Padding(padding: EdgeInsets.only(left: 12), child: Text('Second Round', style: TextStyle(color: AppTheme.textSecondary))),
                             SizedBox(height: 24),
                             Padding(padding: EdgeInsets.only(left: 12), child: Text('Third Round', style: TextStyle(color: AppTheme.textSecondary))),
                             SizedBox(height: 24),
                             Padding(padding: EdgeInsets.only(left: 12), child: Text('Four Round', style: TextStyle(color: AppTheme.textSecondary))),
                           ],
                         ),
                       ),
                       // Expand Button
                       Container(
                         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                         decoration: BoxDecoration(
                           color: Colors.grey[800],
                           borderRadius: BorderRadius.circular(8),
                         ),
                         child: const Text('Expand', style: TextStyle(color: Colors.white, fontSize: 10)),
                       ),
                     ],
                   ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // About Section
            const Text(
              'About The Tournament',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Welcome To The ACO Sal Football League!\nThis Tournament Is Organized By The ACO Public Stadium For Football Fans.\nThe Final Edition Will Be Held From August 6 To September 30, 2025.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 24),

            // Rules Section
            const Text(
              'Match Rules And Regulations',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildBulletPoint('Each Match Lasts 20 Minutes (Two Halves, Each Half Lasting 10 Minutes).'),
            _buildBulletPoint('Teams Must Arrive 15 Minutes Before The Start Of The Match.'),
            _buildBulletPoint('A Team That Is More Than 10 Minutes Late Will Be Considered Forfeited.'),
            _buildBulletPoint('The Tournament Is A League System, And The Top Teams Advance To The Knockout Stage.'),
            _buildBulletPoint('A Maximum Of 3 Substitutions Are Permitted Per Match.'),
            _buildBulletPoint('Any Unsportsmanlike Conduct Will Result In Immediate Disqualification.'),

            const SizedBox(height: 24),

            // Instructions Section
            const Text(
              'Important Instructions For Players',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildBulletPoint('Each Player Must Wear Designated Sports Shoes (Kochi)—Barefoot Play Is Not Permitted.'),
            _buildBulletPoint('Players Must Bring Their Own Sports Clothing And Equipment.'),
            _buildBulletPoint('Please Keep The Field Clean And Follow The Organizers\' Instructions.'),
            _buildBulletPoint('Respect The Referees, Organizers, And Other Participants.'),
            _buildBulletPoint('Any Team That Causes Disruption Or Trouble May Be Banned From Future Tournaments.'),

            const SizedBox(height: 40),
            
            // Bottom Action Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.neonGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Matches',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineDot() {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '•',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
