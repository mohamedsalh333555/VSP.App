import 'package:flutter/material.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/repositories/tournament_repository.dart';
import '../../../data/models.dart';

class TournamentBracketsScreen extends StatelessWidget {
  final Championship championship;
  final bool isOwner;

  const TournamentBracketsScreen({
    super.key,
    required this.championship,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: VSPColors.textPrimary),
        title: Text(
          'Tournament Brackets',
          style: Theme.of(context).textTheme.displaySmall,
        ),
      ),
      body: StreamBuilder<List<TournamentMatch>>(
        stream: TournamentRepository().getTournamentMatches(championship.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
          }

          final matches = snapshot.data ?? [];

          if (matches.isEmpty) {
            return Center(
              child: Text(
                'Brackets not generated yet.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary),
              ),
            );
          }

          // Group by Round
          final rounds = <int, List<TournamentMatch>>{};
          for (var match in matches) {
            rounds.putIfAbsent(match.roundIndex, () => []).add(match);
          }
          
          // Sort rounds (High index = Early rounds, Low index = Final)
          final sortedRoundIndices = rounds.keys.toList()..sort((a, b) => b.compareTo(a));

          return SingleChildScrollView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: sortedRoundIndices.map((roundIndex) {
                return _buildRoundColumn(context, roundIndex, rounds[roundIndex]!);
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRoundColumn(BuildContext context, int roundIndex, List<TournamentMatch> matches) {
    matches.sort((a, b) => a.matchIndex.compareTo(b.matchIndex));
    
    String roundName = 'Round of ${matches.length * 2}';
    if (roundIndex == 0) {
      roundName = 'Final';
    } else if (roundIndex == 1) {
      roundName = 'Semi Final';
    } else if (roundIndex == 2) {
      roundName = 'Quarter Final';
    }

    return Container(
      width: 300,
      margin: const EdgeInsets.symmetric(horizontal: VSPSpacing.xs),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: VSPSpacing.md),
            child: Text(
              roundName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: VSPColors.accent,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: matches.length,
              separatorBuilder: (_, __) => const SizedBox(height: 20), // Spacing between matches
              itemBuilder: (context, index) {
                return _MatchNode(
                  match: matches[index],
                  isOwner: isOwner,
                  onTap: isOwner ? () => _showScoreDialog(context, matches[index]) : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showScoreDialog(BuildContext context, TournamentMatch match) {
    // Prevent editing if not fully populated
    if (match.homeTeamId == null || match.awayTeamId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Waiting for previous round winners...')),
      );
      return;
    }

    final homeController = TextEditingController(text: match.homeScore?.toString());
    final awayController = TextEditingController(text: match.awayScore?.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VSPColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
        title: Text('Update Score', style: Theme.of(context).textTheme.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildScoreInput(context, match.homeTeamName ?? 'Home', homeController),
            const SizedBox(height: VSPSpacing.md),
            _buildScoreInput(context, match.awayTeamName ?? 'Away', awayController),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: VSPColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              final h = int.tryParse(homeController.text) ?? 0;
              final a = int.tryParse(awayController.text) ?? 0;
              
              if (h == a) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Draws not allowed in knockout!')),
                );
                return;
              }

              String winnerId = h > a ? match.homeTeamId! : match.awayTeamId!;
              String winnerName = h > a ? match.homeTeamName! : match.awayTeamName!;

              Navigator.pop(context);
              
              await TournamentRepository().updateTournamentMatchScore(
                matchId: match.id,
                homeScore: h,
                awayScore: a,
                winnerId: winnerId,
                winnerName: winnerName,
              );
            },
            child: Text('Save', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: VSPColors.accent)),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreInput(BuildContext context, String label, TextEditingController controller) {
    return Row(
      children: [
        Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyLarge)),
        SizedBox(
          width: 60,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              filled: true,
              fillColor: VSPColors.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(VSPRadius.sm)),
              contentPadding: const EdgeInsets.all(8),
            ),
          ),
        ),
      ],
    );
  }
}

class _MatchNode extends StatelessWidget {
  final TournamentMatch match;
  final bool isOwner;
  final VoidCallback? onTap;

  const _MatchNode({required this.match, required this.isOwner, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: VSPColors.surface,
          borderRadius: BorderRadius.circular(VSPRadius.md),
          border: Border.all(
            color: match.winnerId != null ? VSPColors.accent : VSPColors.divider,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            _buildTeamRow(context, match.homeTeamName, match.homeScore, 
                isWinner: match.winnerId != null && match.winnerId == match.homeTeamId),
            const Divider(height: 1, color: VSPColors.divider),
            _buildTeamRow(context, match.awayTeamName, match.awayScore, 
                isWinner: match.winnerId != null && match.winnerId == match.awayTeamId),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamRow(BuildContext context, String? name, int? score, {bool isWinner = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isWinner ? VSPColors.accent.withValues(alpha: 0.1) : null,
        borderRadius: BorderRadius.circular(VSPRadius.md), // Slight rounding for the inner row
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name ?? 'TBD',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: name == null
                      ? VSPColors.textSecondary.withValues(alpha: 0.5)
                      : (isWinner ? VSPColors.accent : VSPColors.textPrimary),
                  fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
                ),
          ),
          if (score != null)
            Text(
              score.toString(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: isWinner ? VSPColors.accent : VSPColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
        ],
      ),
    );
  }
}
