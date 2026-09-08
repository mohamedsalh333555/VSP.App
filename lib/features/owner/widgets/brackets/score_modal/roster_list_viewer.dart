import 'package:flutter/material.dart';
import '../../../../../core/ui/tokens/vsp_tokens.dart';

class RosterListViewer extends StatelessWidget {
  final String homeTeamName;
  final List<String> homeRoster;
  final String awayTeamName;
  final List<String> awayRoster;
  final bool isLoading;

  const RosterListViewer({
    super.key,
    required this.homeTeamName,
    required this.homeRoster,
    required this.awayTeamName,
    required this.awayRoster,
    this.isLoading = false,
  });

  Widget _buildRosterListColumn(String teamName, List<String> roster) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          teamName,
          style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(8)),
          child: roster.isEmpty
              ? const Text(
                  'لا يوجد لاعبون مسجلون',
                  style: TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: roster.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final name = entry.value;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '${idx + 1}. $name',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isArabic ? ' كشف أسماء اللاعبين المشاركين بالبطولة:' : ' Championship Team Rosters:',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 12),
        if (isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: VSPColors.accent),
            ),
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildRosterListColumn(homeTeamName, homeRoster)),
              const SizedBox(width: 12),
              Expanded(child: _buildRosterListColumn(awayTeamName, awayRoster)),
            ],
          ),
      ],
    );
  }
}
