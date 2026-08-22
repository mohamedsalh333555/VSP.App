import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/material.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/vsp_back_button.dart';
import '../../../data/models.dart';
import '../widgets/booking_type_modal.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../core/constants/egypt_governorates.dart';
import '../../../core/utils/app_date_formatter.dart';
import '../../../core/services/logger_service.dart';

class StadiumDetailsScreen extends StatefulWidget {
  final Stadium stadium;
  const StadiumDetailsScreen({super.key, required this.stadium});
  @override
  State<StadiumDetailsScreen> createState() => _StadiumDetailsScreenState();
}

class _StadiumDetailsScreenState extends State<StadiumDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late PageController _pageController;
  int _currentImageIndex = 0;
  late final List<String> _displayImages;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _pageController = PageController();
    
    // Parse ALL genuine stadium images (primary imageUrl + images array + features['allImages'])
    final List<String> rawImages = [];
    if (widget.stadium.imageUrl.isNotEmpty) {
      rawImages.add(widget.stadium.imageUrl);
    }
    for (final img in widget.stadium.images) {
      if (img.isNotEmpty && !rawImages.contains(img)) {
        rawImages.add(img);
      }
    }
    final features = widget.stadium.features;
    if (features is Map && features['allImages'] is List) {
      for (final img in (features['allImages'] as List)) {
        final imgStr = img.toString().trim();
        if (imgStr.isNotEmpty && !rawImages.contains(imgStr)) {
          rawImages.add(imgStr);
        }
      }
    }

    _displayImages = rawImages;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _openFullScreenGallery(int initialIndex) {
    int activeIdx = initialIndex;
    final dialogPageController = PageController(initialPage: initialIndex);

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog.fullscreen(
            backgroundColor: Colors.black,
            child: Stack(
              children: [
                PageView.builder(
                  controller: dialogPageController,
                  itemCount: _displayImages.length,
                  onPageChanged: (idx) => setDialogState(() => activeIdx = idx),
                  itemBuilder: (ctx, i) {
                    return InteractiveViewer(
                      child: CachedNetworkImage(
                        imageUrl: _displayImages[i],
                        memCacheWidth: 1080,
                        memCacheHeight: 1080,
                        fit: BoxFit.contain,
                      ),
                    );
                  },
                ),
                Positioned(
                  top: 40,
                  right: 16,
                  child: IconButton(
                    icon: const Icon(Iconsax.close_circle_copy, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(dialogCtx),
                  ),
                ),
                Positioned(
                  bottom: 30,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${activeIdx + 1} / ${_displayImages.length}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final stadium = widget.stadium;
    final hasDeposit = stadium.depositAmount > 0.0;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: VSPColors.background,
      body: Column(
        children: [
          SizedBox(
            height: (MediaQuery.of(context).size.height * 0.35).clamp(250.0, 450.0),
            child: Stack(
              children: [
                // 1. Full Bleed Image Carousel with Touch Swipe
                Positioned.fill(
                  child: _displayImages.isNotEmpty && _displayImages.first.isNotEmpty
                      ? PageView.builder(
                          controller: _pageController,
                          itemCount: _displayImages.length,
                          onPageChanged: (index) => setState(() => _currentImageIndex = index),
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onTap: () => _openFullScreenGallery(index),
                              child: CachedNetworkImage(
                                imageUrl: _displayImages[index],
                                memCacheWidth: 800,
                                memCacheHeight: 600,
                                fit: BoxFit.cover,
                                placeholder: (ctx, url) => Container(color: VSPColors.surface),
                                errorWidget: (ctx, url, _) => _buildVspLogoBackground(),
                              ),
                            );
                          },
                        )
                      : _buildVspLogoBackground(),
                ),

                // 2. Subtle Gradient Overlay for Top & Bottom Controls Readability
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.6),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.6),
                          ],
                          stops: const [0.0, 0.4, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),

                // 3. Top Action Bar (Back, Share, Favorite)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const VSPBackButton(),
                        Row(
                          children: [
                            _buildCircularIcon(
                              icon: Iconsax.share_copy,
                              onTap: () => SharePlus.instance.share(ShareParams(text: l10n.shareStadiumText(stadium.name, stadium.location))),
                            ),
                            const SizedBox(width: 12),
                            Consumer<AuthProvider>(
                              builder: (context, auth, _) {
                                final isFav = auth.userModel?.favoriteStadiums.contains(stadium.id) ?? false;
                                return _buildCircularIcon(
                                  icon: isFav ? Iconsax.heart : Iconsax.heart_copy,
                                  color: VSPColors.accent,
                                  onTap: () => auth.toggleFavoriteStadium(stadium.id),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // 4. Instagram/Airbnb Style Bottom Dots Indicator
                if (_displayImages.length > 1)
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: () => _openFullScreenGallery(_currentImageIndex),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(_displayImages.length, (idx) {
                              final isSelected = _currentImageIndex == idx;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: isSelected ? 14 : 6,
                                height: 6,
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                decoration: BoxDecoration(
                                  color: isSelected ? VSPColors.accent : Colors.white.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            color: VSPColors.background,
            padding: const EdgeInsets.all(VSPSpacing.md),
            child: Container(
              height: 48,
              decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(VSPRadius.xl)),
              child: AnimatedBuilder(
                animation: _tabController,
                builder: (context, _) => Row(
                  children: [
                    _buildTabItem(0, l10n.information),
                    _buildTabItem(1, l10n.pitchConditions),
                    _buildTabItem(2, l10n.ratings),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _InformationTab(stadium: stadium),
                _PitchConditionsTab(stadium: stadium),
                _RatingsTab(stadium: stadium),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(VSPSpacing.lg, VSPSpacing.md, VSPSpacing.lg, VSPSpacing.lg),
        decoration: const BoxDecoration(
          color: VSPColors.surface,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(VSPRadius.xl), topRight: Radius.circular(VSPRadius.xl)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.pricePerHour, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary)),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(text: '${stadium.basePrice.toStringAsFixed(0)} ', style: Theme.of(context).textTheme.displayLarge),
                              TextSpan(text: isArabic ? 'ج.م' : 'EGP', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: hasDeposit
                            ? Row(
                                key: const ValueKey('deposit'),
                                children: [
                                  const Icon(Iconsax.lock_copy, color: VSPColors.accent, size: 11),
                                  const SizedBox(width: 4),
                                  Text('${isArabic ? 'عربون: ' : 'Deposit: '}${stadium.depositAmount.toInt()} ${isArabic ? 'ج.م' : 'EGP'}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.accent, fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              )
                            : Row(
                                key: const ValueKey('cash'),
                                children: [
                                  Text(isArabic ? 'ادفع نقداً في الملعب' : 'Pay cash at stadium', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary, fontSize: 10)),
                                ],
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(width: VSPSpacing.lg),
                  Expanded(
                    child: PrimaryButton(
                      text: isArabic ? 'احجز الآن' : 'Book Now',
                      onPressed: () => BookingTypeModal.show(context, stadium),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(int index, String label) {
    final isSelected = _tabController.index == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _tabController.animateTo(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: isSelected ? VSPColors.accent : Colors.transparent, borderRadius: BorderRadius.circular(VSPRadius.xl)),
          alignment: Alignment.center,
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: isSelected ? VSPColors.background : VSPColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ),
    );
  }

  Widget _buildCircularIcon({required IconData icon, required VoidCallback onTap, Color color = VSPColors.textPrimary}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: VSPColors.background.withValues(alpha: 0.6), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildVspLogoBackground() => Container(color: VSPColors.surface, child: Center(child: Image.asset('assets/images/logo.png', width: 80, height: 80, color: VSPColors.textPrimary.withValues(alpha: 0.06), colorBlendMode: BlendMode.modulate)));
}

class _InformationTab extends StatelessWidget {
  final Stadium stadium;
  const _InformationTab({required this.stadium});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final String displayName = stadium.name.trim().isNotEmpty
        ? (isArabic ? stadium.formattedName : stadium.name.trim())
        : (isArabic ? 'ملعب بدون اسم' : 'Unnamed Pitch');

    String rawDesc = stadium.description.isNotEmpty ? stadium.description : l10n.noDescription;
    if (!isArabic && rawDesc.isNotEmpty) {
      rawDesc = rawDesc
          .replaceAll('الالتزام بالمواعد', '• Punctuality')
          .replaceAll('الالتزام بالمواعيد', '• Punctuality')
          .replaceAll('الحفاظ على النظافة', '• Cleanliness')
          .replaceAll('ممنوع التدخين', '• No Smoking');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(VSPSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Stadium Name & Single Clean Rating Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  displayName,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              // Single Clean Rating Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: VSPColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(VSPRadius.md),
                  border: Border.all(color: VSPColors.divider.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Iconsax.star_copy, color: VSPColors.accent, size: 14),
                    const SizedBox(width: 5),
                    Text(
                      stadium.rating.toStringAsFixed(1),
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '(${stadium.reviewsCount})',
                      style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: VSPSpacing.md),
          // Location Badge: Guaranteed working maps launch (lat/lng or text query fallback)
          GestureDetector(
            onTap: () async {
              try {
                final String query = (stadium.lat != null && stadium.lng != null)
                    ? '${stadium.lat},${stadium.lng}'
                    : Uri.encodeComponent('${stadium.name} ${stadium.location} ${stadium.governorate ?? ''}'.trim());
                final googleMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
                await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
              } catch (e) {
                debugPrint('Error launching maps: $e');
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: BorderRadius.circular(VSPRadius.xl),
                border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Iconsax.location_copy, color: VSPColors.accent, size: 14),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      EgyptGovernorates.formatSmartLocation(
                        rawAddress: stadium.area.isNotEmpty
                            ? stadium.area
                            : (stadium.location.isNotEmpty ? stadium.location : stadium.address),
                        administrativeArea: stadium.governorate,
                      ),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: VSPColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: VSPSpacing.md),
          // Description Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(VSPSpacing.md),
            decoration: BoxDecoration(
              color: VSPColors.surface,
              borderRadius: BorderRadius.circular(VSPRadius.lg),
              border: Border.all(color: VSPColors.divider.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.informationStadium, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                Text(rawDesc, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.textSecondary, height: 1.6)),
              ],
            ),
          ),
          const SizedBox(height: VSPSpacing.md),
          // Features Section Header
          Text(l10n.features, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 10),
          _FacilitiesGrid(stadium: stadium),
          if (stadium.hasBall || stadium.ballPrice > 0) ...[
            const SizedBox(height: VSPSpacing.md),
            Text(l10n.featuresForMoney, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 10),
            SizedBox(
              width: 96,
              height: 72,
              child: _FacilityTile(
                item: _FacilityItem(
                  icon: Iconsax.activity_copy,
                  label: isArabic ? 'كرة (${stadium.ballPrice.toInt()} ج.م)' : 'Ball (${stadium.ballPrice.toInt()} EGP)',
                  active: true,
                ),
              ),
            ),
          ],
          const SizedBox(height: VSPSpacing.lg),
        ],
      ),
    );
  }
}

class _FacilitiesGrid extends StatelessWidget {
  final Stadium stadium;
  const _FacilitiesGrid({required this.stadium});

  bool _getBool(String key) {
    final f = stadium.features;
    if (f is Map) return f[key] == true;
    return false;
  }

  String _getSeat() {
    final f = stadium.features;
    if (f is Map) return f['seats']?.toString() ?? '';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final hasCafeteria = _getBool('cafeteria');
    final hasGarage = _getBool('garage');
    final hasBathroom = stadium.features is Map ? (stadium.features as Map)['bathOption'] == 'Yes' : false;
    final hasChangingRoom = _getBool('changingRoom');
    final seats = _getSeat();
    final hasSeats = seats.isNotEmpty && seats != '0' && seats != 'null';

    final allFacilities = [
      _FacilityItem(icon: Iconsax.drop, label: isArabic ? 'حمامات' : 'Bathrooms', active: hasBathroom),
      _FacilityItem(icon: Iconsax.car_copy, label: isArabic ? 'جراج' : 'Garage', active: hasGarage),
      _FacilityItem(icon: Iconsax.coffee_copy, label: isArabic ? 'كافتيريا' : 'Cafeteria', active: hasCafeteria),
      _FacilityItem(icon: Iconsax.shop_copy, label: isArabic ? 'غرف تغيير' : 'Changing Rooms', active: hasChangingRoom),
      _FacilityItem(icon: Iconsax.home_copy, label: isArabic ? 'مقاعد' : 'Seats', active: hasSeats),
    ];

    // Filter to only active features selected by the owner
    final activeFacilities = allFacilities.where((f) => f.active).toList();

    if (activeFacilities.isEmpty) {
      return Text(
        isArabic ? 'لا توجد مميزات مضافة لهذا الملعب' : 'No features listed for this pitch',
        style: TextStyle(color: VSPColors.textSecondary.withValues(alpha: 0.7), fontSize: 11),
      );
    }

    return SizedBox(
      height: 72,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: activeFacilities.map((f) => Container(
          width: 74,
          margin: const EdgeInsets.only(left: 8),
          child: _FacilityTile(item: f),
        )).toList(),
      ),
    );
  }
}

class _FacilityItem {
  final IconData icon;
  final String label;
  final bool active;
  const _FacilityItem({required this.icon, required this.label, required this.active});
}

class _FacilityTile extends StatelessWidget {
  final _FacilityItem item;
  const _FacilityTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.divider, width: 1),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, color: VSPColors.accent, size: 22),
            const SizedBox(height: 5),
            Text(
              item.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: VSPColors.accent,
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PitchConditionsTab extends StatelessWidget {
  final Stadium stadium;
  const _PitchConditionsTab({required this.stadium});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(VSPSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(VSPSpacing.md),
            decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(VSPRadius.lg)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPolicySection(context, l10n.punctuality, l10n.punctualityPolicy),
                const SizedBox(height: VSPSpacing.md),
                _buildPolicySection(context, l10n.reservationDuration, l10n.reservationDurationPolicy),
                const SizedBox(height: VSPSpacing.md),
                _buildPolicySection(context, l10n.cancellationPolicyTitle, l10n.cancellationPolicy),
                const SizedBox(height: VSPSpacing.md),
                _buildPolicySection(context, l10n.liability, l10n.liabilityPolicy),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicySection(BuildContext context, String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.accent, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(content, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5)),
      ],
    );
  }
}

class _RatingsTab extends StatelessWidget {
  final Stadium stadium;
  const _RatingsTab({required this.stadium});

  Future<void> _showAddReviewSheet(BuildContext context) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    if (!auth.isAuthenticated) {
      VSPFeedback.showError(context, isArabic ? 'يرجى تسجيل الدخول أولاً لإضافة تقييم' : 'Please login to leave a review');
      return;
    }

    int selectedRating = 5;
    final commentController = TextEditingController();
    bool isSubmitting = false;

    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  VSPSpacing.md,
                  VSPSpacing.md,
                  VSPSpacing.md,
                  VSPSpacing.md + MediaQuery.of(context).padding.bottom + 16,
                ),
                decoration: const BoxDecoration(
                  color: VSPColors.background,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: VSPColors.divider, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 16),
                    Text(
                      isArabic ? 'تقييم وإبداء رأيك في الملعب' : 'Rate & Review Stadium',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    // Star Picker
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final starIndex = index + 1;
                        final isSelected = starIndex <= selectedRating;
                        return IconButton(
                          icon: Icon(
                            isSelected ? Iconsax.star_1_copy : Iconsax.star_copy,
                            color: isSelected ? Colors.amber : VSPColors.textSecondary,
                            size: 36,
                          ),
                          onPressed: () {
                            setSheetState(() {
                              selectedRating = starIndex;
                            });
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: commentController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: isArabic ? 'اكتب انطباعك عن جودة الملعب والإضاءة والمعاملة...' : 'Write your feedback...',
                        hintStyle: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                        filled: true,
                        fillColor: VSPColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(VSPRadius.md),
                          borderSide: const BorderSide(color: VSPColors.divider),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      text: isArabic ? 'إرسال التقييم ⭐️' : 'Submit Review',
                      isLoading: isSubmitting,
                      onPressed: () async {
                        final comment = commentController.text.trim();
                        if (comment.isEmpty) {
                          VSPFeedback.showError(sheetCtx, isArabic ? 'يرجى كتابة تعليق' : 'Please enter a comment');
                          return;
                        }
                        setSheetState(() => isSubmitting = true);
                        try {
                          final userModel = auth.userModel;
                          final userId = userModel?.uid ?? auth.currentUser?.id;
                          if (userId == null || userId.isEmpty) {
                            VSPFeedback.showError(sheetCtx, isArabic ? 'يرجى تسجيل الدخول أولاً لإضافة تقييم' : 'Please log in to submit a review');
                            setSheetState(() => isSubmitting = false);
                            return;
                          }

                          final userName = userModel?.name ?? auth.currentUser?.email?.split('@').first ?? (isArabic ? 'لاعب VSP' : 'VSP Player');
                          final userAvatar = userModel?.profileImageUrl ?? '';

                          await Supabase.instance.client.from('reviews').insert({
                            'stadium_id': stadium.id,
                            'user_id': userId,
                            'user_name': userName,
                            'user_image_url': userAvatar,
                            'rating': selectedRating,
                            'review_text': comment,
                            'created_at': DateTime.now().toIso8601String(),
                          });

                          // Update average rating on stadium record safely
                          final allReviews = await Supabase.instance.client.from('reviews').select('rating').eq('stadium_id', stadium.id);
                          final count = (allReviews as List).length;
                          double sum = 0;
                          for (final r in allReviews) {
                            sum += (r['rating'] as num?)?.toDouble() ?? 0.0;
                          }
                          final newAvg = count > 0 ? (sum / count) : selectedRating.toDouble();

                          await Supabase.instance.client.from('stadiums').update({
                            'rating': newAvg,
                            'reviews_count': count,
                          }).eq('id', stadium.id);

                          if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                          if (context.mounted) {
                            VSPFeedback.showSuccess(context, isArabic ? 'شكراً لك! تم إرسال تقييمك بنجاح' : 'Review submitted successfully!');
                          }
                        } catch (e, stack) {
                          VSPLogger.e('❌ Error saving review to Supabase', e, stack);
                          setSheetState(() => isSubmitting = false);
                          if (sheetCtx.mounted) {
                            VSPFeedback.showError(sheetCtx, isArabic ? 'حدث خطأ أثناء حفظ التقييم' : 'Error saving review');
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client.from('reviews').stream(primaryKey: ['id']).eq('stadium_id', stadium.id).map((list) {
        final sorted = List<Map<String, dynamic>>.from(list);
        sorted.sort((a, b) => DateTime.parse(b['created_at'].toString()).compareTo(DateTime.parse(a['created_at'].toString())));
        return sorted;
      }),
      builder: (context, snapshot) {
        final docs = snapshot.data ?? [];
        final count = docs.length;
        
        double liveRating = 0.0;
        if (count > 0) {
          double sum = 0.0;
          for (final doc in docs) {
            sum += (doc['rating'] as num?)?.toDouble() ?? 0.0;
          }
          liveRating = sum / count;
        }

        Widget buildReviewHeader() {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: VSPSpacing.md),
                padding: const EdgeInsets.all(VSPSpacing.md),
                decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(VSPRadius.lg)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            count > 0 ? liveRating.toStringAsFixed(1) : '0.0',
                            style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 42),
                          ),
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                5,
                                (i) => Icon(
                                  i < liveRating.round() ? Iconsax.star_1_copy : Iconsax.star_copy,
                                  color: i < liveRating.round() ? Colors.amber : VSPColors.textSecondary,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: VSPSpacing.xs),
                          Text(
                            count > 0 ? l10n.reviews(count) : (isArabic ? 'ملعب جديد ✨' : 'New Stadium ✨'),
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              PrimaryButton(
                text: isArabic ? 'إضافة تقييمك ورأيك' : 'Add Your Review',
                height: 44,
                color: VSPColors.surfaceAlt,
                textColor: VSPColors.accent,
                onPressed: () => _showAddReviewSheet(context),
              ),
              const SizedBox(height: VSPSpacing.md),
            ],
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting && docs.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
        }

        if (docs.isEmpty) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.all(VSPSpacing.md),
            child: Column(
              children: [
                buildReviewHeader(),
                Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Text(
                    l10n.noReviews,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.all(VSPSpacing.md),
          itemCount: docs.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return buildReviewHeader();
            }

            final doc = docs[index - 1];
            final createdAtStr = doc['created_at'] as String?;
            final userName = doc['user_name']?.toString() ?? doc['userName']?.toString() ?? l10n.player;
            final userImage = doc['user_image_url']?.toString() ?? doc['userImageUrl']?.toString() ?? '';

            String formattedTime = l10n.recently;
            if (createdAtStr != null) {
              try {
                final dt = DateTime.parse(createdAtStr);
                final diff = DateTime.now().difference(dt);
                if (diff.inSeconds < 60) {
                  formattedTime = isArabic ? 'منذ لحظات' : 'Just now';
                } else if (diff.inMinutes < 60) {
                  formattedTime = isArabic ? 'منذ ${diff.inMinutes} دقيقة' : '${diff.inMinutes}m ago';
                } else if (diff.inHours < 24) {
                  formattedTime = isArabic ? 'منذ ${diff.inHours} ساعة' : '${diff.inHours}h ago';
                } else if (diff.inDays < 30) {
                  formattedTime = isArabic ? 'منذ ${diff.inDays} يوم' : '${diff.inDays}d ago';
                } else {
                  formattedTime = AppDateFormatter.formatDayMonth(dt, isArabic ? 'ar' : 'en');
                }
              } catch (e, stack) {
                VSPLogger.e('Error formatting review date', e, stack);
              }
            }

            return _buildReviewItem(
              context,
              name: userName,
              imageUrl: userImage,
              rating: (doc['rating'] as num?)?.toInt() ?? 0,
              timeAgo: formattedTime,
              comment: doc['review_text'] as String? ?? '',
            );
          },
        );
      },
    );
  }

  Widget _buildReviewItem(BuildContext context, {required String name, required String imageUrl, required int rating, required String timeAgo, required String comment}) {
    return Container(
      margin: const EdgeInsets.only(bottom: VSPSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 20, backgroundColor: VSPColors.surfaceAlt, backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null, child: imageUrl.isEmpty ? const Icon(Iconsax.user_copy, color: VSPColors.textSecondary) : null),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleSmall),
                    Text(timeAgo, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary)),
                  ],
                ),
                Row(children: List.generate(5, (i) => Icon(i < rating ? Iconsax.star_1_copy : Iconsax.star_copy, size: 14, color: i < rating ? Colors.amber : VSPColors.textSecondary))),
                const SizedBox(height: 8),
                Text(comment, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.textSecondary, height: 1.4)),
                const Padding(padding: EdgeInsets.symmetric(vertical: VSPSpacing.md), child: Divider(color: VSPColors.divider)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

