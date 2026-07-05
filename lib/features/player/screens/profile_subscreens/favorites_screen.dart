import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/stadium_provider.dart';
import '../../../../shared/widgets/stadium_card.dart';
import '../../../../shared/widgets/vsp_empty_state.dart';
import '../stadium_details_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Favorite Stadiums',
          style: Theme.of(context).textTheme.displayMedium,
        ),
      ),
      body: Consumer2<AuthProvider, StadiumProvider>(
        builder: (context, auth, stadiumProvider, child) {
          final favoriteIds = auth.userModel?.favoriteStadiums ?? [];
          
          if (favoriteIds.isEmpty) {
            return const VSPEmptyState(
              icon: LucideIcons.heart,
              title: 'No Favorites Yet',
              subtitle: 'Explore stadiums and heart your favorites to see them here.',
            );
          }

          // Filter all stadiums to show only favorites
          final favoriteStadiums = stadiumProvider.allStadiums
              .where((s) => favoriteIds.contains(s.id))
              .toList();

          if (favoriteStadiums.isEmpty) {
            // If they are in the list but not in the provider's current fetch
            // we could either fetch them or show empty. 
            // For now, let's assume allStadiums has what we need or show a message.
            return const VSPEmptyState(
              icon: LucideIcons.search,
              title: 'Stadiums Not Found',
              subtitle: 'Your favorite stadiums could not be loaded right now.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(VSPSpacing.md),
            itemCount: favoriteStadiums.length,
            itemBuilder: (context, index) {
              final stadium = favoriteStadiums[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: VSPSpacing.md),
                child: StadiumCard(
                  stadium: stadium,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StadiumDetailsScreen(stadium: stadium),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
