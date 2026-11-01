import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/material.dart';
import '../../../../core/ui/vsp_ui.dart';
import 'package:provider/provider.dart';
import '../../../../core/repositories/stadium_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../shared/widgets/stadium_card.dart';
import '../../../../shared/widgets/vsp_back_button.dart';
import '../../../../shared/widgets/vsp_empty_state.dart';
import '../../../../shared/widgets/vsp_error_state.dart';
import '../../../../data/models.dart';
import '../stadium_details_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  String? _favoriteIdsKey;
  List<String> _favoriteIds = [];
  Future<List<Stadium>>? _favoriteStadiumsFuture;

  void _bindFavorites(List<String> ids) {
    final key = ids.join('|');
    if (_favoriteIdsKey == key) return;
    _favoriteIdsKey = key;
    _favoriteIds = List<String>.from(ids);
    _favoriteStadiumsFuture = ids.isEmpty
        ? null
        : StadiumRepository().getStadiumsByIds(_favoriteIds);
  }

  void _retryFavorites() {
    setState(() {
      _favoriteStadiumsFuture = StadiumRepository().getStadiumsByIds(_favoriteIds);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return VSPScaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: const VSPBackButton(),
        title: Text(
          isAr ? 'الملاعب المفضلة' : 'Favorite Stadiums',
          style: Theme.of(context).textTheme.displayMedium,
        ),
      ),
      body: SafeArea(top: false, bottom: true, child: Consumer<AuthProvider>(
        builder: (context, auth, child) {
          final favoriteIds = auth.userModel?.favoriteStadiums ?? [];
          
          _bindFavorites(favoriteIds);
          if (favoriteIds.isEmpty) {
            return VSPEmptyState(
              icon: Iconsax.heart_copy,
              title: isAr ? 'لا توجد ملاعب مفضلة بعد' : 'No Favorites Yet',
              subtitle: isAr ? 'تصفح الملاعب واضغط على رمز القلب لإضافتها إلى مفضلتك هنا.' : 'Explore stadiums and heart your favorites to see them here.',
            );
          }

          return FutureBuilder<List<Stadium>>(
            future: _favoriteStadiumsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return VSPStateView(
                  state: VSPUiState.loading,
                  title: isAr ? 'جاري تحميل المفضلة' : 'Loading favorites',
                );
              }

              if (snapshot.hasError) {
                return VSPErrorState(
                  customMessage: isAr
                      ? 'تعذر تحميل الملاعب المفضلة. تحقق من الاتصال ثم أعد المحاولة.'
                      : 'Could not load favorite stadiums. Check your connection and try again.',
                  retryButtonText: isAr ? 'إعادة المحاولة' : 'Retry',
                  onRetry: _retryFavorites,
                );
              }

              final favoriteStadiums = snapshot.data ?? [];

              if (favoriteStadiums.isEmpty) {
                return VSPEmptyState(
                  icon: Iconsax.search_normal_copy,
                  title: isAr ? 'تعذر تحميل الملاعب المفضلة' : 'Stadiums Not Found',
                  subtitle: isAr ? 'لم نتمكن من العثور على بيانات الملاعب المفضلة حالياً.' : 'Your favorite stadiums could not be loaded.',
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
          );
        },
      )),
    );
  }
}
