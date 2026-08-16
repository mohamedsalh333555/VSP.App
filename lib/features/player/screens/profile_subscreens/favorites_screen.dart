import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../shared/widgets/stadium_card.dart';
import '../../../../shared/widgets/vsp_empty_state.dart';
import '../../../../data/models.dart';
import '../stadium_details_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(isAr ? Iconsax.arrow_right_1_copy : Iconsax.arrow_left_2_copy, color: VSPColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isAr ? 'الملاعب المفضلة' : 'Favorite Stadiums',
          style: Theme.of(context).textTheme.displayMedium,
        ),
      ),
      body: Consumer<AuthProvider>(
        builder: (context, auth, child) {
          final favoriteIds = auth.userModel?.favoriteStadiums ?? [];
          
          if (favoriteIds.isEmpty) {
            return VSPEmptyState(
              icon: Iconsax.heart_copy,
              title: isAr ? 'لا توجد ملاعب مفضلة بعد' : 'No Favorites Yet',
              subtitle: isAr ? 'تصفح الملاعب واضغط على رمز القلب لإضافتها إلى مفضلتك هنا.' : 'Explore stadiums and heart your favorites to see them here.',
            );
          }

          return FutureBuilder<List<Map<String, dynamic>>>(
            future: Supabase.instance.client
                .from('stadiums')
                .select()
                .inFilter('id', favoriteIds)
                .then((res) => List<Map<String, dynamic>>.from(res)),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
              }
              
              final data = snapshot.data ?? [];
              
              if (data.isEmpty) {
                return VSPEmptyState(
                  icon: Iconsax.search_normal_copy,
                  title: isAr ? 'تعذر تحميل الملاعب المفضلة' : 'Stadiums Not Found',
                  subtitle: isAr ? 'لم نتمكن من العثور على بيانات الملاعب المفضلة حالياً.' : 'Your favorite stadiums could not be loaded.',
                );
              }

              final favoriteStadiums = data.map((d) => Stadium.fromFirestore(d, d['id'].toString())).toList();

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
          );
        },
      ),
    );
  }
}
