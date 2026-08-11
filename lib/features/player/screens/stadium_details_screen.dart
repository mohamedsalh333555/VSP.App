import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/material.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:provider/provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../data/models.dart';
import 'booking_type_screen.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/vsp_feedback.dart';

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
    
    // Parse ONLY genuine stadium images uploaded for this specific stadium
    final List<String> rawImages = [];
    if (widget.stadium.imageUrl.isNotEmpty) {
      rawImages.add(widget.stadium.imageUrl);
    }
    for (final img in widget.stadium.images) {
      if (img.isNotEmpty && !rawImages.contains(img)) {
        rawImages.add(img);
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
                                fit: BoxFit.cover,
                                placeholder: (ctx, url) => Container(color: VSPColors.surface),
                                errorWidget: (ctx, url, _) => _buildVspLogoBackground(),
                              ),
                            );
                          },
                        )
                      : _buildVspLogoBackground(),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [VSPColors.background.withValues(alpha: 0), VSPColors.background],
                        ),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildCircularIcon(
                          icon: Localizations.localeOf(context).languageCode == 'ar'
                              ? Iconsax.arrow_right_3_copy
                              : Iconsax.arrow_left_2_copy,
                          onTap: () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            }
                          },
                        ),
                        Row(
                          children: [
                            _buildCircularIcon(
                              icon: Iconsax.share_copy,
                              onTap: () => SharePlus.instance.share(ShareParams(text: l10n.shareStadiumText(stadium.name, stadium.location))),
                            ),
                            const SizedBox(width: 16),
                            Consumer<AuthProvider>(
                              builder: (context, auth, _) {
                                final isFav = auth.userModel?.favoriteStadiums.contains(stadium.id) ?? false;
                                return _buildCircularIcon(
                                  icon: Iconsax.heart_copy,
                                  color: isFav ? VSPColors.accent : VSPColors.textPrimary,
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
                // Left / Right Quick Navigation Arrows for non-swipers
                if (_displayImages.length > 1) ...[
                  Positioned(
                    left: 12,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: IgnorePointer(
                        ignoring: _currentImageIndex == 0,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: _currentImageIndex > 0 ? 1.0 : 0.0,
                          child: _buildCircularIcon(
                            icon: isArabic ? Iconsax.arrow_right_3_copy : Iconsax.arrow_left_2_copy,
                            onTap: () {
                              if (_currentImageIndex > 0) {
                                _pageController.previousPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: IgnorePointer(
                        ignoring: _currentImageIndex == _displayImages.length - 1,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: _currentImageIndex < _displayImages.length - 1 ? 1.0 : 0.0,
                          child: _buildCircularIcon(
                            icon: isArabic ? Iconsax.arrow_left_2_copy : Iconsax.arrow_right_3_copy,
                            onTap: () {
                              if (_currentImageIndex < _displayImages.length - 1) {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                Positioned(
                  bottom: 16, left: 0, right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_displayImages.length, (index) => Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: _buildDot(isActive: index == _currentImageIndex))),
                  ),
                ),
                // Photo Counter Pill Badge (e.g. 1/4 📷) - Clickable to open full screen gallery
                if (_displayImages.length > 1)
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: GestureDetector(
                      onTap: () => _openFullScreenGallery(_currentImageIndex),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(VSPRadius.md),
                          border: Border.all(color: Colors.white24, width: 0.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Iconsax.image_copy, color: Colors.white, size: 12),
                            const SizedBox(width: 5),
                            Text(
                              '${_currentImageIndex + 1}/${_displayImages.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
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
              // 🔥 Loss Aversion Urgency Banner (تجنب الخسارة)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(VSPRadius.md),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    const Icon(Iconsax.flash_1_copy, color: Colors.amber, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isArabic
                            ? '80% من مواعيد اليوم محجوزة! احجز موعدك الآن قبل انشغال الملعب'
                            : '80% of today\'s slots are booked! Lock in your pitch before it\'s taken',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.pricePerHour, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary)),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(text: '${stadium.basePrice.toStringAsFixed(0)} ', style: Theme.of(context).textTheme.displayLarge),
                            TextSpan(text: isArabic ? 'ج.م' : 'EGP', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
                          ],
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
                                  const Icon(Iconsax.card_copy, color: VSPColors.textSecondary, size: 11),
                                  const SizedBox(width: 4),
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
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookingTypeScreen(stadium: stadium))),
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

  Widget _buildDot({required bool isActive}) => Container(width: isActive ? 12 : 8, height: 8, decoration: BoxDecoration(color: isActive ? VSPColors.accent : VSPColors.textSecondary.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(4)));

  Widget _buildVspLogoBackground() => Container(color: VSPColors.surface, child: Center(child: Image.asset('assets/images/logo.png', width: 80, height: 80, color: VSPColors.textPrimary.withValues(alpha: 0.06), colorBlendMode: BlendMode.modulate)));
}

class _InformationTab extends StatelessWidget {
  final Stadium stadium;
  const _InformationTab({required this.stadium});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final String displayName = (stadium.name.trim().isEmpty || stadium.name.trim() == 'Mo')
        ? (isArabic ? 'الملعب الرئيسي' : 'Main Pitch')
        : stadium.name;

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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(color: VSPColors.divider.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Iconsax.location_copy, color: VSPColors.accent, size: 14),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      stadium.location.isNotEmpty ? stadium.location : (stadium.address.isNotEmpty ? stadium.address : l10n.na),
                      style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Iconsax.export_3_copy, color: VSPColors.textSecondary, size: 12),
                ],
              ),
            ),
          ),
          const SizedBox(height: VSPSpacing.lg),
          Text(l10n.informationStadium, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: VSPSpacing.sm),
          Text(rawDesc, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.textSecondary, height: 1.5)),
          const SizedBox(height: VSPSpacing.lg),
          Text(l10n.features, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: VSPSpacing.md),
          _FacilitiesGrid(stadium: stadium),
          const SizedBox(height: VSPSpacing.lg),
          Text(l10n.featuresForMoney, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: VSPSpacing.md),
          if (stadium.hasBall || stadium.ballPrice > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.sm),
              decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(VSPRadius.md), border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3))),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Iconsax.cup_copy, color: VSPColors.accent, size: 14),
                  const SizedBox(width: 8),
                  Text(l10n.ballAvailable(stadium.ballPrice.toStringAsFixed(0), l10n.egCurrency), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.accent, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          const SizedBox(height: VSPSpacing.xxl),
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

    final facilities = [
      _FacilityItem(icon: Iconsax.drop, label: isArabic ? 'حمامات' : 'Bathrooms', active: hasBathroom),
      _FacilityItem(icon: Iconsax.car_copy, label: isArabic ? 'جراج' : 'Garage', active: hasGarage),
      _FacilityItem(icon: Iconsax.coffee_copy, label: isArabic ? 'كافتيريا' : 'Cafeteria', active: hasCafeteria),
      _FacilityItem(icon: Iconsax.tag_copy, label: isArabic ? 'غرف تغيير' : 'Changing Rooms', active: hasChangingRoom),
      _FacilityItem(icon: Iconsax.home_copy, label: isArabic ? 'مدرجات' : 'Seats', active: hasSeats, badge: hasSeats ? seats : null),
    ];

    return GridView.count(
      crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 8, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 0.85,
      children: facilities.map((f) => _FacilityTile(item: f)).toList(),
    );
  }
}

class _FacilityItem {
  final IconData icon;
  final String label;
  final bool active;
  final String? badge;
  const _FacilityItem({required this.icon, required this.label, required this.active, this.badge});
}

class _FacilityTile extends StatelessWidget {
  final _FacilityItem item;
  const _FacilityTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = item.active ? VSPColors.accent : VSPColors.textSecondary.withValues(alpha: 0.35);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: item.active ? VSPColors.accent.withValues(alpha: 0.08) : VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: item.active ? VSPColors.accent.withValues(alpha: 0.4) : VSPColors.divider, width: item.active ? 1.5 : 1),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, color: color, size: 26),
              const SizedBox(height: 6),
              Text(
                item.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: item.active ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
          if (item.badge != null)
            Positioned(top: 6, right: 6, child: Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2), decoration: BoxDecoration(color: VSPColors.accent, borderRadius: BorderRadius.circular(VSPRadius.xs)), child: Text(item.badge!, style: const TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.bold)))),
        ],
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
    final hasOwnerNotes = stadium.notes.trim().isNotEmpty;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(VSPSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity, padding: const EdgeInsets.all(VSPSpacing.md),
            decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(VSPRadius.lg), border: Border.all(color: VSPColors.accent.withValues(alpha: 0.4))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.ownerNotes, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.accent, fontWeight: FontWeight.bold)),
                const SizedBox(height: VSPSpacing.sm),
                Text(hasOwnerNotes ? stadium.notes : l10n.noOwnerNotes, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5)),
              ],
            ),
          ),
          const SizedBox(height: VSPSpacing.lg),
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
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(VSPSpacing.md),
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
                        return IconButton(
                          icon: Icon(
                            Iconsax.star_copy,
                            color: starIndex <= selectedRating ? Colors.amber : VSPColors.surfaceAlt,
                            size: 32,
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
                          debugPrint('❌ Error saving review: $e\n$stack');
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(VSPSpacing.md),
          child: Container(
            padding: const EdgeInsets.all(VSPSpacing.md),
            decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(VSPRadius.lg)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(stadium.rating.toStringAsFixed(1), style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 42)),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) => const Icon(Iconsax.star_copy, color: Colors.amber, size: 16))),
                      const SizedBox(height: VSPSpacing.xs),
                      Text(l10n.reviews(stadium.reviewsCount), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md),
          child: PrimaryButton(
            text: isArabic ? 'إضافة تقييمك ورأيك' : 'Add Your Review',
            height: 44,
            color: VSPColors.surfaceAlt,
            textColor: VSPColors.accent,
            onPressed: () => _showAddReviewSheet(context),
          ),
        ),
        const SizedBox(height: VSPSpacing.sm),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: Supabase.instance.client.from('reviews').stream(primaryKey: ['id']).eq('stadium_id', stadium.id).map((list) {
                  final sorted = List<Map<String, dynamic>>.from(list);
                  sorted.sort((a, b) => DateTime.parse(b['created_at'].toString()).compareTo(DateTime.parse(a['created_at'].toString())));
                  return sorted;
                }),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
              final docs = snapshot.data ?? [];
              if (docs.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(40.0), child: Text(l10n.noReviews, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary))));
              return ListView.builder(
                padding: const EdgeInsets.all(VSPSpacing.md),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final createdAtStr = doc['created_at'] as String?;
                  final userName = doc['user_name']?.toString() ?? doc['userName']?.toString() ?? l10n.player;
                  final userImage = doc['user_image_url']?.toString() ?? doc['userImageUrl']?.toString() ?? '';

                  return _buildReviewItem(
                    context,
                    name: userName,
                    imageUrl: userImage,
                    rating: (doc['rating'] as num?)?.toInt() ?? 0,
                    timeAgo: createdAtStr != null 
                        ? timeago.format(DateTime.parse(createdAtStr), locale: Localizations.localeOf(context).languageCode) 
                        : l10n.recently,
                    comment: doc['review_text'] as String? ?? '',
                  );
                },
              );
            },
          ),
        ),
      ],
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
                Row(children: List.generate(5, (i) => Icon(Iconsax.star_copy, size: 12, color: i < rating ? Colors.amber : VSPColors.surfaceAlt))),
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

