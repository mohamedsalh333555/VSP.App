import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../data/models.dart';
import '../../../shared/widgets/vsp_native_ad.dart';
import '../../../core/repositories/stadium_repository.dart';
import '../../../core/repositories/app_settings_repository.dart';
import '../../../core/repositories/match_repository.dart';
import '../../../core/services/sharing_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/stadium_provider.dart';
import '../../../shared/widgets/vsp_bottom_nav_bar.dart';
import '../../../core/widgets/promo_slider.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../shared/widgets/public_match_card.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/ui/components/vsp_section_title.dart';
import '../../../core/constants/egypt_governorates.dart';
import '../../../core/repositories/tournament_repository.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../shared/widgets/stadium_card.dart';
import 'stadium_details_screen.dart';
import 'team_dashboard_screen.dart';
import 'bookings_screen.dart';
import 'champion_screen.dart';
import 'profile_screen.dart';
import 'championship_details_screen.dart';
import '../widgets/filter_bottom_sheet.dart';
import 'global_search_screen.dart';
import 'notifications_center_screen.dart';

// المفتاح العالمي للتحكم في تبويبات صفحة البطل
final GlobalKey<ChampionScreenState> championScreenKey = GlobalKey<ChampionScreenState>();

class PlayerHomeScreen extends StatefulWidget {
  const PlayerHomeScreen({super.key});

  @override
  State<PlayerHomeScreen> createState() => _PlayerHomeScreenState();
}

class _PlayerHomeScreenState extends State<PlayerHomeScreen> {
  int _selectedIndex = 0;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  void _fetchInitialData() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final stadiumProvider = Provider.of<StadiumProvider>(context, listen: false);
      
      if (auth.isAuthenticated && !auth.isOwner) {
        String? gov = auth.userModel?.governorate;
        
        // إذا لم يكن لديه محافظة مسجلة، نقوم بمحاولة جلبها فوراً بالـ GPS أولاً في الخلفية
        if (gov == null || gov.isEmpty) {
          VSPFeedback.showSuccess(context, 'جاري تحديد موقعك الجغرافي تلقائياً... 📍');
          final success = await auth.updateUserLocation();
          
          if (success) {
            final resolvedGov = auth.userModel?.governorate ?? 'Cairo';
            stadiumProvider.applyGovernorateFilter(resolvedGov);
          } else {
            // إذا فشل الـ GPS أو رفض المستخدم الإذن، نفتح له نافذة الاختيار اليدوي كخيار بديل
            if (mounted) {
              VSPFeedback.showError(context, 'تعذر تحديد الموقع الجغرافي. يرجى الاختيار يدوياً.');
              _showLocationPickerHelper(context, auth);
            }
          }
        } else {
          stadiumProvider.applyGovernorateFilter(gov);
          
          // Silent GPS check on startup for travelers
          try {
            final gpsGov = await auth.determineGPSGovernorate();
            if (gpsGov != null && gpsGov != gov) {
              if (mounted) {
                _showGovernorateChangeAlert(context, auth, gpsGov, stadiumProvider);
              }
            }
          } catch (e) {
            debugPrint('Silent startup GPS check failed: $e');
          }
        }
      } else {
        stadiumProvider.fetchStadiums(isRefresh: true);
      }
    });
  }

  void _showGovernorateChangeAlert(BuildContext context, AuthProvider auth, String newGov, StadiumProvider stadiumProvider) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final isArabic = Localizations.localeOf(context).languageCode == 'ar';
        final title = isArabic ? 'تغيير المحافظة تلقائياً 📍' : 'Change Location 📍';
        final content = isArabic 
            ? 'مرحباً بك في $newGov! 📍 لاحظنا أنك انتقلت. هل تود تحديث موقعك لتظهر لك الملاعب والفرق في مكانك الجديد؟'
            : 'Welcome to $newGov! 📍 We noticed you moved. Would you like to update your location to see nearby stadiums and teams?';
        final yesBtn = isArabic ? 'تحديث الموقع' : 'Update Location';
        final noBtn = isArabic ? 'لا، شكراً' : 'No, thanks';

        return AlertDialog(
          backgroundColor: VSPColors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
          title: Row(
            children: [
              Icon(LucideIcons.mapPin, color: VSPColors.accent, size: 28),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Text(
            content,
            style: const TextStyle(color: VSPColors.textSecondary, height: 1.5, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                noBtn,
                style: TextStyle(color: VSPColors.textSecondary.withValues(alpha: 0.8), fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await auth.updateProfile({'governorate': newGov});
                stadiumProvider.applyGovernorateFilter(newGov);
                if (context.mounted) {
                  VSPFeedback.showSuccess(context, isArabic ? 'تم تحديث موقعك إلى $newGov! ⚡' : 'Location updated to $newGov! ⚡');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: VSPColors.accent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.sm)),
              ),
              child: Text(yesBtn, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Set system status bar style to match the dark theme
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light, // White icons
      statusBarBrightness: Brightness.dark, // iOS specific
    ));

    return Scaffold(
      extendBody: true,
      backgroundColor: VSPColors.background,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _HomeContent(
            searchController: _searchController,
            onNavigate: (index, {arguments}) {
              setState(() {
                _selectedIndex = index;
                if (index == 2 && arguments != null && arguments['initialTab'] != null) {
                   championScreenKey.currentState?.switchToTab(arguments['initialTab']);
                }
              });
            },
          ),
          const TeamDashboardScreen(),
          ChampionScreen(key: championScreenKey),
          const BookingsScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: VspBottomNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: (index) => setState(() => _selectedIndex = index),
        items: [
          VspNavItem(activeIcon: LucideIcons.home, inactiveIcon: LucideIcons.home, label: AppLocalizations.of(context)!.homeNav),
          VspNavItem(activeIcon: LucideIcons.users, inactiveIcon: LucideIcons.users, label: AppLocalizations.of(context)!.matchesNav),
          VspNavItem(activeIcon: LucideIcons.trophy, inactiveIcon: LucideIcons.trophy, label: AppLocalizations.of(context)!.championNav),
          VspNavItem(activeIcon: LucideIcons.bookmark, inactiveIcon: LucideIcons.bookmark, label: AppLocalizations.of(context)!.bookedNav),
          VspNavItem(activeIcon: LucideIcons.user, inactiveIcon: LucideIcons.user, label: AppLocalizations.of(context)!.profileNav),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// مكونات الصفحة الرئيسية
// -----------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onSeeAll;

  const _SectionHeader({required this.title, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          VSPSectionTitle(title),
          TextButton(
            onPressed: onSeeAll,
            child: Text(AppLocalizations.of(context)!.seeAll, style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class ChampionshipCard extends StatelessWidget {
  final Championship championship;
  final double? width;
  final EdgeInsetsGeometry? margin;

  const ChampionshipCard({super.key, required this.championship, this.width, this.margin});

  @override
  Widget build(BuildContext context) {
    final int remainingTeams = (championship.maxTeams - championship.joinedTeams.length).clamp(0, championship.maxTeams);

    return Container(
      width: width ?? (MediaQuery.sizeOf(context).width - 32).clamp(250.0, 320.0),
      padding: const EdgeInsets.all(16),
      margin: margin ?? EdgeInsets.zero,
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.xl),
        border: Border.all(
          color: VSPColors.divider,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTypeBadge(AppLocalizations.of(context)!.tournament),
              _buildStatusBadge(
                championship.status == 'open' 
                    ? AppLocalizations.of(context)!.open.toUpperCase() 
                    : AppLocalizations.of(context)!.full.toUpperCase(), 
                championship.status == 'open' ? Colors.green : VSPColors.accent
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3), width: 2)),
                child: ClipOval(
                  child: championship.logoUrl.isNotEmpty
                      ? CachedNetworkImage(imageUrl: championship.logoUrl, fit: BoxFit.cover, errorWidget: (_, __, ___) => Icon(LucideIcons.trophy, color: VSPColors.accent))
                      : Icon(LucideIcons.trophy, color: VSPColors.accent, size: 28),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(championship.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 0.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(championship.type, style: const TextStyle(color: VSPColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(LucideIcons.share2, color: VSPColors.textSecondary, size: 20), 
                onPressed: () => SharingService.shareChampionship(id: championship.id, name: championship.name, date: DateFormat('MMM d').format(championship.startDate))
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCompactInfo(LucideIcons.calendar, DateFormat('MMM d').format(championship.startDate)),
                _buildDivider(),
                _buildCompactInfo(LucideIcons.trophy, "${championship.grandPrize.toInt()} ${AppLocalizations.of(context)!.egCurrency}"),
                _buildDivider(),
                _buildCompactInfo(LucideIcons.banknote, "${championship.entryFee.toInt()} ${AppLocalizations.of(context)!.egCurrency}"),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          "$remainingTeams",
                          style: const TextStyle(
                            color: VSPColors.accent,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          AppLocalizations.of(context)!.spotsLeft,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: VSPColors.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      AppLocalizations.of(context)!.teamsJoined(championship.joinedTeams.length, championship.maxTeams),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: VSPColors.textSecondary.withValues(alpha: 0.6),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChampionshipDetailsScreen(championship: championship))),
                child: Container(
                  height: 44.0, 
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: VSPColors.accent, borderRadius: BorderRadius.circular(12)),
                  child: Center(
                    child: Text(
                      AppLocalizations.of(context)!.join,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBadge(String text) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: VSPColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3))), child: Text(text, style: const TextStyle(color: VSPColors.accent, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.0)));

  Widget _buildStatusBadge(String text, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.4))), child: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 6), Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold))]));

  Widget _buildCompactInfo(IconData icon, String label) => Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: VSPColors.accent, size: 14), const SizedBox(width: 6), Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))]);

  Widget _buildDivider() => Container(width: 1, height: 14, color: Colors.white10);
}

class _HomeContent extends StatelessWidget {
  final TextEditingController searchController;
  final Function(int, {Map<String, dynamic>? arguments}) onNavigate;

  const _HomeContent({required this.searchController, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final stadiumProvider = Provider.of<StadiumProvider>(context);

    return Column(
      children: [
        _buildTopBar(context, auth),
        Expanded(
          child: RefreshIndicator(
            color: VSPColors.accent,
            backgroundColor: VSPColors.surface,
            onRefresh: () async {
              context.read<StadiumProvider>().fetchStadiums(isRefresh: true);
              await Future.delayed(const Duration(milliseconds: 800));
            },
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.only(bottom: 120),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  _buildPromos(),
                  const SizedBox(height: 24),
                  _buildStadiumsList(context, stadiumProvider),
                  const SizedBox(height: 32),
                  _buildMatchesList(context),
                  const SizedBox(height: 32),
                  _buildChampionshipsList(context, auth),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context, AuthProvider auth) {
    return SafeArea(
      top: true,
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
        child: Column(
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onNavigate(4); // Switches the bottom navigation index directly to the Profile Tab (index 4)
                  },
                  child: CircleAvatar(
                    radius: 25, backgroundColor: VSPColors.surface, 
                    backgroundImage: auth.userModel?.profileImageUrl != null ? NetworkImage(auth.userModel!.profileImageUrl!) : null, 
                    child: auth.userModel?.profileImageUrl == null ? const Icon(LucideIcons.user, color: VSPColors.textSecondary) : null
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${AppLocalizations.of(context)!.hi} ${auth.userModel?.name?.split(' ').first ?? AppLocalizations.of(context)!.playerDefaultName}', style: Theme.of(context).textTheme.titleLarge),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: VSPColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              auth.userModel?.position ?? "ST",
                              style: const TextStyle(
                                color: VSPColors.accent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.bell, color: Colors.white),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationsCenterScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSearchBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    const double barHeight = 52.0;
    final borderRadius = BorderRadius.circular(VSPRadius.lg);

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GlobalSearchScreen())),
            child: Container(
              height: barHeight,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: borderRadius,
                border: Border.all(color: VSPColors.divider, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.search, color: VSPColors.accent, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.searchStadiums,
                      style: const TextStyle(color: VSPColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: borderRadius,
            onTap: () async {
              final result = await showModalBottomSheet<Map<String, dynamic>>(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (context) => Padding(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                  child: const FilterBottomSheet(),
                ),
              );
              if (result != null && context.mounted) {
                context.read<StadiumProvider>().applyFilters(result);
              }
            },
            child: Container(
              width: barHeight,
              height: barHeight,
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: borderRadius,
                border: Border.all(color: VSPColors.divider, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(LucideIcons.sliders, color: VSPColors.accent, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPromos() => StreamBuilder<List<Promotion>>(stream: StadiumRepository().getPromotionsStream(), builder: (context, snapshot) => snapshot.hasData ? PromoSlider(promotions: snapshot.data!) : const SizedBox.shrink());

  Widget _buildStadiumsList(BuildContext context, StadiumProvider provider) {
    if (provider.stadiums.isEmpty && !provider.isLoading) {
      final rawCityName = context.read<AuthProvider>().userModel?.governorate ?? 'منطقتك';
      final isAr = AppLocalizations.of(context)!.localeName == 'ar';
      final String cityName;
      if (isAr && rawCityName != 'منطقتك') {
        final Map<String, String> translations = {
          'Cairo': 'القاهرة',
          'Giza': 'الجيزة',
          'Alexandria': 'الإسكندرية',
          'Aswan': 'أسوان',
          'Luxor': 'الأقصر',
          'Red Sea': 'البحر الأحمر',
          'Dakahlia': 'الدقهلية',
          'Sharqia': 'الشرقية',
          'Gharbia': 'الغربية',
          'Monufia': 'المنوفية',
          'Beheira': 'البحيرة',
          'Suez': 'السويس',
          'Port Said': 'بورسعيد',
          'Ismailia': 'الإسماعيلية',
          'Damietta': 'دمياط',
          'Faiyum': 'الفيوم',
          'Beni Suef': 'بني سويف',
          'Minya': 'المنيا',
          'Asyut': 'أسيوط',
          'Sohag': 'سوهاج',
          'Qena': 'قنا',
          'South Sinai': 'جنوب سيناء',
          'North Sinai': 'شمال سيناء',
          'Matrouh': 'مطروح',
          'New Valley': 'الوادي الجديد',
        };
        cityName = translations[rawCityName] ?? rawCityName;
      } else {
        cityName = rawCityName;
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: VSPColors.surface,
          borderRadius: BorderRadius.circular(VSPRadius.xl),
          border: Border.all(color: VSPColors.divider),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: 0.3,
              child: Icon(LucideIcons.mapPin, color: VSPColors.accent, size: 64),
            ),
            const SizedBox(height: 16),
            Text(
              isAr ? 'لم نصل إلى $cityName بعد! 📍' : 'We haven\'t reached $cityName yet! 📍',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isAr ? 'ولكننا نتوسع بسرعة في جميع المحافظات.' : 'But we are expanding rapidly to all governorates.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: VSPColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              text: isAr ? 'اقترح ملعباً في منطقتك 🏟️' : 'Suggest a stadium in your area 🏟️',
              onPressed: () async {
                final message = isAr 
                    ? 'مرحباً VSP، أنا من محافظة $cityName وأريد اقتراح إضافة ملاعب في منطقتي!'
                    : 'Hello VSP, I am from $cityName and I want to suggest adding stadiums in my area!';
                final encoded = Uri.encodeComponent(message);
                final settings = await AppSettingsRepository().getSettings();
                final rawPhone = settings.whatsappNumber.isEmpty ? '201100229462' : settings.whatsappNumber;
                final phone = rawPhone.replaceAll('+', '').replaceAll(' ', '');
                final whatsappUrl = Uri.parse('https://wa.me/$phone?text=$encoded');
                try {
                  if (await canLaunchUrl(whatsappUrl)) {
                    await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
                  }
                } catch (e) {
                  debugPrint('Error launching WhatsApp support: $e');
                }
              },
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (provider.isGeographicFallback) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: VSPColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.info, color: VSPColors.accent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.geographicFallbackBanner,
                    style: const TextStyle(
                      color: VSPColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        _SectionHeader(title: AppLocalizations.of(context)!.nearbyStadiums, onSeeAll: () {}),
        const SizedBox(height: 16),
        SizedBox(
          height: 240,
          child: provider.isLoading && provider.stadiums.isEmpty
              ? ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: 3, itemBuilder: (_, __) => const CardSkeleton())
              : ListView.builder(
                  scrollDirection: Axis.horizontal, 
                  padding: const EdgeInsets.symmetric(horizontal: 16), 
                  itemCount: provider.stadiums.length + (provider.stadiums.length ~/ 3), 
                  itemBuilder: (context, index) {
                    final isAd = (index + 1) % 4 == 0;
                    if (isAd) {
                      return Container(
                        width: 300, 
                        margin: const EdgeInsets.only(right: 12), 
                        child: const VSPNativeAd(),
                      );
                    }
                    
                    final adOffset = (index + 1) ~/ 4;
                    final stadiumIndex = index - adOffset;
                    
                    if (stadiumIndex >= provider.stadiums.length) {
                      return const SizedBox.shrink();
                    }
                    
                    final stadium = provider.stadiums[stadiumIndex];
                    return Container(
                      width: 300, 
                      margin: const EdgeInsets.only(right: 12), 
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
                ),
        ),
      ],
    );
  }

  Widget _buildMatchesList(BuildContext context) {
    return StreamBuilder<List<Booking>>(
      stream: MatchRepository().getPublicMatches(), 
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('❌ Matches Stream Error: ${snapshot.error}');
          return const SizedBox.shrink(); // Hide silently or show error
        }

        final matches = snapshot.data ?? [];
        
        // Hide entire section if no matches to match premium UX
        if (matches.isEmpty && snapshot.connectionState != ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        return Column(
          children: [
            _SectionHeader(title: AppLocalizations.of(context)!.joinMatches, onSeeAll: () => onNavigate(1)),
            const SizedBox(height: 16),
            SizedBox(
              height: 240,
              child: matches.isEmpty && snapshot.connectionState == ConnectionState.waiting
                  ? ListView.builder(
                      scrollDirection: Axis.horizontal, 
                      padding: const EdgeInsets.symmetric(horizontal: 16), 
                      itemCount: 3, 
                      itemBuilder: (_, __) => const CardSkeleton(),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal, 
                      padding: const EdgeInsets.symmetric(horizontal: 16), 
                      itemCount: matches.length, 
                      itemBuilder: (context, i) => Align(
                        alignment: Alignment.topCenter, 
                        child: Container(
                          width: 320, 
                          margin: const EdgeInsets.only(right: 12), 
                          child: PublicMatchCard(booking: matches[i]),
                        ),
                      ),
                    ),
            ),
          ],
        );
      }
    );
  }

  Widget _buildChampionshipsList(BuildContext context, AuthProvider auth) {
    return StreamBuilder<List<Championship>>(
      stream: TournamentRepository().getChampionshipsStream(governorate: auth.userModel?.governorate), 
      builder: (context, snapshot) {
        final championships = snapshot.data ?? [];
        return Column(
          children: [
            _SectionHeader(title: AppLocalizations.of(context)!.joinChampionships, onSeeAll: () => onNavigate(2, arguments: {'initialTab': 1})),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: championships.isEmpty && snapshot.connectionState == ConnectionState.waiting
                  ? ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: 3, itemBuilder: (_, __) => const CardSkeleton())
                  : ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: championships.length, itemBuilder: (context, i) => Align(alignment: Alignment.topCenter, child: Container(width: 320, margin: const EdgeInsets.only(right: 12), child: ChampionshipCard(championship: championships[i])))),
            ),
          ],
        );
      }
    );
  }

}

void _showLocationPickerHelper(BuildContext context, AuthProvider auth) {
  showModalBottomSheet(
    context: context, 
    backgroundColor: VSPColors.surface, 
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20))
    ), 
    builder: (context) {
      final governorates = EgyptGovernorates.allGovernorates;
      return Container(
        padding: const EdgeInsets.all(16), 
        child: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [
            Text(
              AppLocalizations.of(context)!.selectLocation, 
              style: Theme.of(context).textTheme.titleLarge
            ), 
            const SizedBox(height: 16), 
            Expanded(
              child: ListView.builder(
                itemCount: governorates.length, 
                itemBuilder: (context, index) { 
                  final gov = governorates[index]; 
                  final isSelected = auth.userModel?.governorate == gov; 
                  return ListTile(
                    leading: Icon(
                      LucideIcons.building, 
                      color: isSelected ? VSPColors.accent : VSPColors.textSecondary
                    ), 
                    title: Text(
                      gov, 
                      style: TextStyle(
                        color: isSelected ? VSPColors.accent : Colors.white, 
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                      )
                    ), 
                    trailing: isSelected ? Icon(LucideIcons.check, color: VSPColors.accent) : null, 
                    onTap: () { 
                      auth.updateProfile({'governorate': gov}); 
                      context.read<StadiumProvider>().applyGovernorateFilter(gov); 
                      Navigator.pop(context); 
                    }
                  ); 
                }
              )
            )
          ]
        )
      );
    }
  );
}





