import 'package:flutter/material.dart';

import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../shared/widgets/primary_button.dart';
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
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: VSPColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Champion',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border, color: VSPColors.error),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
        padding: const EdgeInsets.all(VSPSpacing.md),
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
                    color: VSPColors.surface,
                    borderRadius: BorderRadius.circular(VSPRadius.lg),
                  ),
                  child: Stack(
                    children: [
                      // Background Image
                      Positioned.fill(
                        child: ShimmerImage(
                          imageUrl: '', // BETA READY: Removed fake background
                          fit: BoxFit.cover,
                          errorWidget: const Icon(Icons.sports_soccer, color: VSPColors.textSecondary),
                        ),
                      ),
                      // Content
                      Padding(
                        padding: const EdgeInsets.all(VSPSpacing.md),
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
                                errorWidget: const Icon(Icons.emoji_events_outlined, color: VSPColors.textSecondary),
                              ),
                            ),
                            const SizedBox(width: VSPSpacing.md),
                            // Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    championship.name,
                                    style: Theme.of(context).textTheme.titleLarge,
                                  ),
                                  Text(
                                    championship.type,
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            // Matches Button
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.xs),
                              decoration: BoxDecoration(
                                color: VSPColors.accent,
                                borderRadius: BorderRadius.circular(VSPRadius.md),
                              ),
                              child: Text(
                                'Matches',
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                      color: VSPColors.background,
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
            const SizedBox(height: VSPSpacing.md),

            // Stats Bar
            Container(
              padding: const EdgeInsets.all(VSPSpacing.md),
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: BorderRadius.circular(VSPRadius.lg),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatItem(context, 'Date', '${championship.startDate} - ${championship.endDate}'),
                  _buildStatItem(context, 'Entry Fee', '${championship.entryFee.toStringAsFixed(0)} eg'),
                  _buildStatItem(context, 'Grand Prize', '${championship.grandPrize.toStringAsFixed(0)} eg'),
                ],
              ),
            ),
             const SizedBox(height: VSPSpacing.md),
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
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
                   )
                ]
             ),

            const SizedBox(height: VSPSpacing.lg),

            // Timeline Section
            Container(
              padding: const EdgeInsets.all(VSPSpacing.md),
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: BorderRadius.circular(VSPRadius.lg),
              ),
              child: Column(
                children: [
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       // Dates (Left)
                       Column(
                           children: [
                             Text('Aug 6-7', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textPrimary)),
                             const SizedBox(height: 24),
                             Text('Aug 9-10', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textPrimary)),
                             const SizedBox(height: 24),
                             Text('Aug 12-13', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textPrimary)),
                             const SizedBox(height: 24),
                             Text('Aug 15-16', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textPrimary)),
                           ],
                         ),
                         // Visual Line (Center)
                         Container(
                           height: 150,
                           width: 2,
                           color: VSPColors.divider.withValues(alpha: 0.1),
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
                             children: [
                               Padding(padding: const EdgeInsets.only(left: 12), child: Text('First Round...', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary))),
                               const SizedBox(height: 24),
                               Padding(padding: const EdgeInsets.only(left: 12), child: Text('Second Round', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary))),
                               const SizedBox(height: 24),
                               Padding(padding: const EdgeInsets.only(left: 12), child: Text('Third Round', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary))),
                               const SizedBox(height: 24),
                               Padding(padding: const EdgeInsets.only(left: 12), child: Text('Four Round', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary))),
                             ],
                           ),
                         ),
                       // Expand Button
                       Container(
                         padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.sm, vertical: VSPSpacing.xs),
                         decoration: BoxDecoration(
                           color: VSPColors.surfaceAlt,
                           borderRadius: BorderRadius.circular(VSPRadius.sm),
                         ),
                         child: Text('Expand', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10)),
                       ),
                     ],
                   ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // About Section
            Text(
              'About The Tournament',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: VSPSpacing.sm),
            Text(
              'Welcome To The ACO Sal Football League!\nThis Tournament Is Organized By The ACO Public Stadium For Football Fans.\nThe Final Edition Will Be Held From August 6 To September 30, 2025.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: VSPColors.textSecondary,
                    height: 1.5,
                  ),
            ),

            const SizedBox(height: 24),

            // Rules Section
            Text(
              'Match Rules And Regulations',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: VSPSpacing.md),
            _buildBulletPoint(context, 'Each Match Lasts 20 Minutes (Two Halves, Each Half Lasting 10 Minutes).'),
            _buildBulletPoint(context, 'Teams Must Arrive 15 Minutes Before The Start Of The Match.'),
            _buildBulletPoint(context, 'A Team That Is More Than 10 Minutes Late Will Be Considered Forfeited.'),
            _buildBulletPoint(context, 'The Tournament Is A League System, And The Top Teams Advance To The Knockout Stage.'),
            _buildBulletPoint(context, 'A Maximum Of 3 Substitutions Are Permitted Per Match.'),
            _buildBulletPoint(context, 'Any Unsportsmanlike Conduct Will Result In Immediate Disqualification.'),

            const SizedBox(height: 24),

            // Instructions Section
            Text(
              'Important Instructions For Players',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: VSPSpacing.md),
            _buildBulletPoint(context, 'Each Player Must Wear Designated Sports Shoes (Kochi)â€”Barefoot Play Is Not Permitted.'),
            _buildBulletPoint(context, 'Players Must Bring Their Own Sports Clothing And Equipment.'),
            _buildBulletPoint(context, 'Please Keep The Field Clean And Follow The Organizers\' Instructions.'),
            _buildBulletPoint(context, 'Respect The Referees, Organizers, And Other Participants.'),
            _buildBulletPoint(context, 'Any Team That Causes Disruption Or Trouble May Be Banned From Future Tournaments.'),

            const SizedBox(height: 40),
            
            // Bottom Action Button
            PrimaryButton(
              text: 'Matches',
              onPressed: () {},
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildTimelineDot() {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: VSPColors.textPrimary,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildBulletPoint(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'â€¢',
            style: TextStyle(
              color: VSPColors.textPrimary,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: VSPColors.textPrimary,
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

