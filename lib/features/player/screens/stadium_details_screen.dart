import 'package:lucide_icons_flutter/lucide_icons.dart';
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
import '../../../core/providers/booking_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class StadiumDetailsScreen extends StatefulWidget {
  final Stadium stadium;

  const StadiumDetailsScreen({super.key, required this.stadium});

  @override
  State<StadiumDetailsScreen> createState() => _StadiumDetailsScreenState();
}

class _StadiumDetailsScreenState extends State<StadiumDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentImageIndex = 0;
  late final List<String> _displayImages;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _displayImages = widget.stadium.images.isNotEmpty
        ? widget.stadium.images
        : [widget.stadium.imageUrl];
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          // ── Hero Image Header ──────────────────────────────────────────────
          SizedBox(
            height: (MediaQuery.of(context).size.height * 0.35).clamp(250.0, 450.0),
            child: Stack(
              children: [
                Positioned.fill(
                  child: _displayImages.isNotEmpty && _displayImages.first.isNotEmpty
                      ? PageView.builder(
                          itemCount: _displayImages.length,
                          onPageChanged: (index) =>
                              setState(() => _currentImageIndex = index),
                          itemBuilder: (context, index) {
                            return CachedNetworkImage(
                              imageUrl: _displayImages[index],
                              fit: BoxFit.cover,
                              memCacheHeight: 800,
                              maxHeightDiskCache: 1200,
                              placeholder: (ctx, url) =>
                                  Container(color: VSPColors.surface),
                              errorWidget: (ctx, url, _) => _buildVspLogoBackground(),
                            );
                          },
                        )
                      : _buildVspLogoBackground(),
                ),
                // Gradient overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          VSPColors.background.withValues(alpha: 0),
                          VSPColors.background,
                        ],
                      ),
                    ),
                  ),
                ),
                // Top icons row
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(
                        top: 10, left: 16, right: 16, bottom: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildCircularIcon(
                          icon: LucideIcons.chevronLeft,
                          onTap: () => Navigator.pop(context),
                        ),
                        Row(
                          children: [
                            _buildCircularIcon(
                              icon: LucideIcons.share2,
                              onTap: () {
                                Share.share(
                                  l10n.shareStadiumText(
                                      stadium.name, stadium.location),
                                );
                              },
                            ),
                            const SizedBox(width: 16),
                            Consumer<AuthProvider>(
                              builder: (context, auth, _) {
                                final isFavorite = auth.userModel
                                        ?.favoriteStadiums
                                        .contains(stadium.id) ??
                                    false;
                                return _buildCircularIcon(
                                  icon: isFavorite
                                      ? LucideIcons.heart
                                      : LucideIcons.heart,
                                  color: isFavorite
                                      ? VSPColors.accent
                                      : VSPColors.textPrimary,
                                  onTap: () =>
                                      auth.toggleFavoriteStadium(stadium.id),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Slider dots
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _displayImages.length,
                      (index) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _buildDot(isActive: index == _currentImageIndex),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Custom Tab Bar ─────────────────────────────────────────────────
          Container(
            color: VSPColors.background,
            padding: const EdgeInsets.symmetric(
                horizontal: VSPSpacing.md, vertical: VSPSpacing.md),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: BorderRadius.circular(VSPRadius.xl),
              ),
              child: AnimatedBuilder(
                animation: _tabController,
                builder: (context, _) {
                  return Row(
                    children: [
                      _buildTabItem(0, l10n.information),
                      _buildTabItem(1, l10n.pitchConditions),
                      _buildTabItem(2, l10n.ratings),
                    ],
                  );
                },
              ),
            ),
          ),

          // ── Tab Content ────────────────────────────────────────────────────
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

      // ── FEATURE 2: Deposit-Transparent Bottom Bar ─────────────────────────
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(VSPSpacing.lg),
        decoration: BoxDecoration(
          color: VSPColors.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(VSPRadius.xl),
            topRight: Radius.circular(VSPRadius.xl),
          ),
          boxShadow: VSPShadow.subtle,
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Price column — shows deposit note when applicable
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.pricePerHour,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: VSPColors.textSecondary),
                  ),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${stadium.basePrice.toStringAsFixed(0)} ',
                          style: Theme.of(context).textTheme.displayLarge,
                        ),
                        TextSpan(
                          text: l10n.egCurrency,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  // Deposit / pay-at-pitch note
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: hasDeposit
                        ? Row(
                            key: const ValueKey('deposit'),
                            children: [
                              Icon(LucideIcons.lock,
                                  color: VSPColors.accent, size: 11),
                              const SizedBox(width: 4),
                              Text(
                                '${isArabic ? 'عربون: ' : 'Deposit: '}${stadium.depositAmount.toInt()} ${l10n.egCurrency}',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: VSPColors.accent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          )
                        : Row(
                            key: const ValueKey('cash'),
                            children: [
                              Icon(LucideIcons.banknote,
                                  color: VSPColors.textSecondary, size: 11),
                              const SizedBox(width: 4),
                              Text(
                                isArabic ? 'ادفع نقداً في الملعب' : 'Pay cash at stadium',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: VSPColors.textSecondary,
                                      fontSize: 10,
                                    ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
              const SizedBox(width: VSPSpacing.lg),
              Expanded(
                child: PrimaryButton(
                  text: l10n.bookNow,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BookingTypeScreen(stadium: stadium),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _buildTabItem(int index, String label) {
    final isSelected = _tabController.index == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _tabController.animateTo(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected ? VSPColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(VSPRadius.xl),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? VSPColors.background : VSPColors.textSecondary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircularIcon({
    required IconData icon,
    required VoidCallback onTap,
    Color color = VSPColors.textPrimary,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: VSPColors.background.withValues(alpha: 0.6),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildDot({required bool isActive}) {
    return Container(
      width: isActive ? 12 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive
            ? VSPColors.accent
            : VSPColors.textSecondary.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildVspLogoBackground() {
    return Container(
      color: VSPColors.surface,
      child: Center(
        child: Image.asset(
          'assets/images/logo.png',
          width: 80,
          height: 80,
          color: VSPColors.textPrimary.withValues(alpha: 0.06),
          colorBlendMode: BlendMode.modulate,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INFORMATION TAB
// ─────────────────────────────────────────────────────────────────────────────
class _InformationTab extends StatelessWidget {
  final Stadium stadium;

  const _InformationTab({required this.stadium});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(VSPSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── FEATURE 4: Stadium Name + Verified Badge ──────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        stadium.name,
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                    ),
                    if (stadium.isVerified) ...[
                      const SizedBox(width: 8),
                      _VerifiedBadge(),
                    ],
                  ],
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: VSPColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                      border: Border.all(
                        color: VSPColors.accent.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: VSPColors.accent.withValues(alpha: 0.1),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.star,
                          color: VSPColors.accent,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          stadium.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            LucideIcons.star,
                            color: i < stadium.rating.round() ? VSPColors.accent : VSPColors.surfaceAlt,
                            size: 10,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.reviews(stadium.reviewsCount),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: VSPColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: VSPSpacing.sm),

          // ── Address + Location Button ──────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  stadium.address.isNotEmpty ? stadium.address : l10n.na,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: VSPColors.textSecondary),
                ),
              ),
              const SizedBox(width: VSPSpacing.sm),
              GestureDetector(
                onTap: () async {
                  final query = Uri.encodeComponent(stadium.name);
                  final googleMapsUrl = Uri.parse(
                      'https://www.google.com/maps/search/?api=1&query=$query');
                  try {
                    await launchUrl(googleMapsUrl,
                        mode: LaunchMode.externalApplication);
                  } catch (e) {
                    debugPrint('Could not launch maps: $e');
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: VSPColors.accent,
                    borderRadius: BorderRadius.circular(VSPRadius.xl),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.mapPin,
                          color: VSPColors.background, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        stadium.location.isNotEmpty
                            ? stadium.location
                            : l10n.na,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(
                              color: VSPColors.background,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: VSPSpacing.md),

          // ── FEATURE 3: Pitch Specifications Card ──────────────────────────
          _PitchSpecsCard(stadium: stadium),

          const SizedBox(height: VSPSpacing.md),

          // ── FEATURE 1: Today's Real-Time Slots Preview ────────────────────
          _TodaysSlotsPreview(stadium: stadium),

          const SizedBox(height: VSPSpacing.lg),

          // ── About the Stadium ─────────────────────────────────────────────
          Text(
            l10n.informationStadium,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: VSPSpacing.sm),
          Text(
            stadium.description.isNotEmpty
                ? stadium.description
                : l10n.noDescription,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: VSPColors.textSecondary, height: 1.5),
          ),

          const SizedBox(height: VSPSpacing.lg),

          // ── FEATURE 5: Accessible Facilities Icon Grid ────────────────────
          Text(
            l10n.features,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: VSPSpacing.md),
          _FacilitiesGrid(stadium: stadium),

          const SizedBox(height: VSPSpacing.lg),

          // ── Paid Extras ───────────────────────────────────────────────────
          Text(
            l10n.featuresForMoney,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: VSPSpacing.md),
          if (stadium.hasBall)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: VSPSpacing.md, vertical: VSPSpacing.sm),
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(
                    color: VSPColors.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.trophy,
                      color: VSPColors.accent, size: 14),
                  const SizedBox(width: 8),
                  Text(
                    l10n.ballAvailable(
                        stadium.ballPrice.toStringAsFixed(0), l10n.egCurrency),
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(
                          color: VSPColors.accent,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: VSPSpacing.xxl),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FEATURE 4: Verified Badge Widget
// ─────────────────────────────────────────────────────────────────────────────
class _VerifiedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD4AF37), Color(0xFFFFDF7A), Color(0xFFAC7C11)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(VSPRadius.xl),
        border: Border.all(
          color: const Color(0xFFFFF0B3).withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(LucideIcons.badgeCheck, color: VSPColors.background, size: 12),
          SizedBox(width: 4),
          Text(
            'VERIFIED 🛡️',
            style: TextStyle(
              color: VSPColors.background,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FEATURE 3: Pitch Specs Card
// ─────────────────────────────────────────────────────────────────────────────
class _PitchSpecsCard extends StatelessWidget {
  final Stadium stadium;

  const _PitchSpecsCard({required this.stadium});

  String _getFloorType() {
    final f = stadium.features;
    if (f is Map) {
      return f['floorType']?.toString() ?? '';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final ppt = stadium.playersPerTeam;
    final matchLabel = ppt > 0 ? '$ppt vs $ppt' : '5 vs 5';
    final floorType = _getFloorType();

    // Map common floor types from database
    String displayFloorType = floorType;
    if (!isArabic) {
      if (floorType == 'نجيل صناعي') displayFloorType = 'Artificial Grass';
      if (floorType == 'نجيل طبيعي') displayFloorType = 'Natural Grass';
      if (floorType == 'بلاط') displayFloorType = 'Tile';
      if (floorType == 'ترتان') displayFloorType = 'Tartan';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: VSPSpacing.md, vertical: VSPSpacing.sm),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: VSPColors.divider),
      ),
      child: Row(
        children: [
          _buildSpecItem(
            context,
            icon: LucideIcons.expand,
            label: isArabic ? 'حجم الملعب' : 'Pitch Size',
            value: matchLabel,
          ),
          if (floorType.isNotEmpty) ...[
            Container(
                width: 1,
                height: 36,
                color: VSPColors.divider,
                margin:
                    const EdgeInsets.symmetric(horizontal: VSPSpacing.md)),
            Expanded(
              child: _buildSpecItem(
                context,
                icon: LucideIcons.leaf,
                label: isArabic ? 'نوع الأرضية' : 'Surface Type',
                value: displayFloorType,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpecItem(BuildContext context,
      {required IconData icon,
      required String label,
      required String value}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: VSPColors.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(VSPRadius.sm),
          ),
          child: Icon(icon, color: VSPColors.accent, size: 18),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: VSPColors.textSecondary, fontSize: 10),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: VSPColors.textPrimary,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FEATURE 1: Today's Real-Time Slots Preview
// ─────────────────────────────────────────────────────────────────────────────
class _TodaysSlotsPreview extends StatelessWidget {
  final Stadium stadium;

  const _TodaysSlotsPreview({required this.stadium});

  List<String> _generateAllSlots() {
    final f = stadium.features;
    String startStr = '02:00 PM';
    String endStr = '11:00 PM';
    if (f is Map && f['workingHours'] != null) {
      startStr = f['workingHours']['start'] ?? startStr;
      endStr = f['workingHours']['end'] ?? endStr;
    }

    int parse(String t) {
      if (t.isEmpty) return 0;
      try {
        final r = RegExp(r'(\d+)(?::(\d+))?\s*(AM|PM)?', caseSensitive: false);
        final m = r.firstMatch(t);
        if (m == null) return 0;
        int h = int.parse(m.group(1)!);
        int min = m.group(2) != null ? int.parse(m.group(2)!) : 0;
        final p = m.group(3)?.toUpperCase();
        if (p == 'PM' && h != 12) h += 12;
        if (p == 'AM' && h == 12) h = 0;
        return h * 60 + min;
      } catch (_) {
        return 0;
      }
    }

    String fmt(int total) {
      total = total % (24 * 60);
      final h = total ~/ 60;
      final m = total % 60;
      final p = h >= 12 ? 'PM' : 'AM';
      final dh = h > 12 ? h - 12 : (h == 0 ? 12 : h);
      return '${dh.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $p';
    }

    int s = parse(startStr);
    int e = parse(endStr);
    if (e < s) e += 24 * 60;
    final slots = <String>[];
    for (int t = s; t < e; t += 60) {
      slots.add(fmt(t));
    }
    return slots;
  }

  bool _isSlotBooked(String slot, List<Booking> bookings, DateTime date) {
    final r =
        RegExp(r'(\d+):(\d+)\s*(AM|PM)', caseSensitive: false);
    final m = r.firstMatch(slot);
    if (m == null) return false;
    int h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    final p = m.group(3)!.toUpperCase();
    if (p == 'PM' && h != 12) h += 12;
    if (p == 'AM' && h == 12) h = 0;
    final slotStart = DateTime(date.year, date.month, date.day, h, min);
    final slotEnd = slotStart.add(const Duration(hours: 1));
    for (final b in bookings) {
      if (slotStart.isBefore(b.endTime) && slotEnd.isAfter(b.startTime)) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final today = DateTime.now();
    return StreamBuilder<List<Booking>>(
      stream: Provider.of<BookingProvider>(context, listen: false)
          .getBookingsForStadium(stadium.id, today),
      builder: (context, snapshot) {
        final existingBookings = snapshot.data ?? [];
        final allSlots = _generateAllSlots();

        // Filter out past slots and booked slots, take next 3 available
        final now = DateTime.now();
        final available = allSlots.where((slot) {
          final r = RegExp(r'(\d+):(\d+)\s*(AM|PM)', caseSensitive: false);
          final m = r.firstMatch(slot);
          if (m == null) return false;
          int h = int.parse(m.group(1)!);
          final min = int.parse(m.group(2)!);
          final p = m.group(3)!.toUpperCase();
          if (p == 'PM' && h != 12) h += 12;
          if (p == 'AM' && h == 12) h = 0;
          final dt = DateTime(today.year, today.month, today.day, h, min);
          if (dt.isBefore(now)) return false;
          return !_isSlotBooked(slot, existingBookings, today);
        }).take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.clock, color: VSPColors.accent, size: 16),
                const SizedBox(width: 6),
                Text(
                  isArabic ? 'توفر الملاعب اليوم' : "Today's Availability",
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (available.isEmpty)
              // Fully booked badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: VSPSpacing.md, vertical: VSPSpacing.sm),
                decoration: BoxDecoration(
                  color: VSPColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(VSPRadius.xl),
                  border: Border.all(
                      color: VSPColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: VSPColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isArabic ? 'الملعب مكتمل اليوم — تحقق غداً 🔴' : 'Pitch is fully booked today — Check tomorrow 🔴',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: VSPColors.error),
                    ),
                  ],
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: available
                      .map((slot) => _SlotPill(slot: slot))
                      .toList(),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SlotPill extends StatelessWidget {
  final String slot;

  const _SlotPill({required this.slot});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: VSPColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(VSPRadius.xl),
        border: Border.all(color: VSPColors.accent, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.checkCircle,
              color: VSPColors.accent, size: 13),
          const SizedBox(width: 5),
          Text(
            slot,
            style: const TextStyle(
              color: VSPColors.accent,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FEATURE 5: Accessible Facilities Icon Grid
// ─────────────────────────────────────────────────────────────────────────────
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
    final hasBathroom = stadium.features is Map
        ? (stadium.features as Map)['bathOption'] == 'Yes'
        : false;
    final hasChangingRoom = _getBool('changingRoom');
    final seats = _getSeat();
    final hasSeats =
        seats.isNotEmpty && seats != '0' && seats != 'null';

    final facilities = [
      _FacilityItem(
          icon: LucideIcons.showerHead,
          label: isArabic ? 'حمامات' : 'Bathrooms',
          active: hasBathroom),
      _FacilityItem(
          icon: LucideIcons.car,
          label: isArabic ? 'جراج' : 'Garage',
          active: hasGarage),
      _FacilityItem(
          icon: LucideIcons.coffee,
          label: isArabic ? 'كافتيريا' : 'Cafeteria',
          active: hasCafeteria),
      _FacilityItem(
          icon: LucideIcons.shirt,
          label: isArabic ? 'غرف تغيير' : 'Changing Rooms',
          active: hasChangingRoom),
      _FacilityItem(
          icon: LucideIcons.sofa,
          label: isArabic ? 'مدرجات' : 'Spectator Seats',
          active: hasSeats,
          badge: hasSeats ? seats : null),
    ];

    return GridView.count(
      crossAxisCount: 4,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 0.85,
      children: facilities
          .map((f) => _FacilityTile(item: f))
          .toList(),
    );
  }
}

class _FacilityItem {
  final IconData icon;
  final String label;
  final bool active;
  final String? badge;

  const _FacilityItem({
    required this.icon,
    required this.label,
    required this.active,
    this.badge,
  });
}

class _FacilityTile extends StatelessWidget {
  final _FacilityItem item;

  const _FacilityTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final activeColor = VSPColors.accent;
    final inactiveColor =
        VSPColors.textSecondary.withValues(alpha: 0.35);
    final color = item.active ? activeColor : inactiveColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: item.active
            ? VSPColors.accent.withValues(alpha: 0.08)
            : VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(
          color: item.active
              ? VSPColors.accent.withValues(alpha: 0.4)
              : VSPColors.divider,
          width: item.active ? 1.5 : 1,
        ),
        boxShadow: item.active
            ? [
                BoxShadow(
                  color: VSPColors.accent.withValues(alpha: 0.12),
                  blurRadius: 8,
                )
              ]
            : [],
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
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: item.active
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ],
          ),
          if (item.badge != null)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: VSPColors.accent,
                  borderRadius: BorderRadius.circular(VSPRadius.xs),
                ),
                child: Text(
                  item.badge!,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PITCH CONDITIONS TAB
// ─────────────────────────────────────────────────────────────────────────────
class _PitchConditionsTab extends StatelessWidget {
  final Stadium stadium;

  const _PitchConditionsTab({required this.stadium});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasOwnerNotes = stadium.notes.trim().isNotEmpty;

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(VSPSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Owner Notes
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(VSPSpacing.md),
            decoration: BoxDecoration(
              color: VSPColors.surface,
              borderRadius: BorderRadius.circular(VSPRadius.lg),
              border: Border.all(
                  color: VSPColors.accent.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.ownerNotes,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: VSPColors.accent,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: VSPSpacing.sm),
                Text(
                  hasOwnerNotes ? stadium.notes : l10n.noOwnerNotes,
                  style:
                      Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: VSPSpacing.lg),

          // Standard Policies
          Container(
            padding: const EdgeInsets.all(VSPSpacing.md),
            decoration: BoxDecoration(
              color: VSPColors.surface,
              borderRadius: BorderRadius.circular(VSPRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPolicySection(
                    context, l10n.punctuality, l10n.punctualityPolicy),
                const SizedBox(height: VSPSpacing.md),
                _buildPolicySection(
                    context,
                    l10n.reservationDuration,
                    l10n.reservationDurationPolicy),
                const SizedBox(height: VSPSpacing.md),
                _buildPolicySection(
                    context,
                    l10n.cancellationPolicyTitle,
                    l10n.cancellationPolicy),
                const SizedBox(height: VSPSpacing.md),
                _buildPolicySection(
                    context, l10n.liability, l10n.liabilityPolicy),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicySection(
      BuildContext context, String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: VSPColors.accent,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          content,
          style:
              Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RATINGS TAB
// ─────────────────────────────────────────────────────────────────────────────
class _RatingsTab extends StatelessWidget {
  final Stadium stadium;

  const _RatingsTab({required this.stadium});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        // Summary Card
        Padding(
          padding: const EdgeInsets.all(VSPSpacing.md),
          child: Container(
            padding: const EdgeInsets.all(VSPSpacing.md),
            decoration: BoxDecoration(
              color: VSPColors.surface,
              borderRadius: BorderRadius.circular(VSPRadius.lg),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        stadium.rating.toStringAsFixed(1),
                        style: Theme.of(context)
                            .textTheme
                            .displayLarge
                            ?.copyWith(fontSize: 42),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < stadium.rating.round()
                                ? LucideIcons.star
                                : LucideIcons.star,
                            color: Colors.amber,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: VSPSpacing.xs),
                      Text(
                        l10n.reviews(stadium.reviewsCount),
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: VSPColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Reviews List المحدث بالكامل لـ سوبابيز
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: Supabase.instance.client
                .from('reviews')
                .stream(primaryKey: ['id'])
                .eq('stadium_id', stadium.id)
                .map((list) {
                  final sorted = List<Map<String, dynamic>>.from(list);
                  sorted.sort((a, b) {
                    final dateA = DateTime.parse(a['created_at'].toString());
                    final dateB = DateTime.parse(b['created_at'].toString());
                    return dateB.compareTo(dateA);
                  });
                  return sorted;
                }),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: VSPColors.accent));
              }

              final docs = snapshot.data ?? [];

              if (docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Text(
                      l10n.noReviews,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: VSPColors.textSecondary),
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(VSPSpacing.md),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final rating = (doc['rating'] as num?)?.toInt() ?? 0;
                  final text = doc['review_text'] as String? ?? '';
                  final createdAtStr = doc['created_at'] as String?;
                  final createdAt = createdAtStr != null ? DateTime.parse(createdAtStr) : null;

                  return _buildReviewItem(
                    context,
                    name: l10n.player,
                    imageUrl: '',
                    rating: rating,
                    timeAgo: createdAt != null
                        ? timeago.format(createdAt)
                        : l10n.recently,
                    comment: text,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReviewItem(
    BuildContext context, {
    required String name,
    required String imageUrl,
    required int rating,
    required String timeAgo,
    required String comment,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: VSPSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: VSPColors.surfaceAlt,
            backgroundImage:
                imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
            child: imageUrl.isEmpty
                ? Icon(LucideIcons.user,
                    color: VSPColors.textSecondary)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(name,
                        style:
                            Theme.of(context).textTheme.titleSmall),
                    Text(
                      timeAgo,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: VSPColors.textSecondary),
                    ),
                  ],
                ),
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(LucideIcons.star,
                        size: 12,
                        color: i < rating
                            ? Colors.amber
                            : VSPColors.surfaceAlt),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  comment,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: VSPColors.textSecondary,
                        height: 1.4,
                      ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: VSPSpacing.md),
                  child: Divider(color: VSPColors.divider),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}



