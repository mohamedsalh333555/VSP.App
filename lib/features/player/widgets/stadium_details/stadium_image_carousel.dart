import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/vsp_back_button.dart';

/// Top image carousel header with full-bleed touch swipe, dots indicator, and full-screen gallery.
class StadiumImageCarousel extends StatefulWidget {
  final Stadium stadium;
  final List<String> displayImages;

  const StadiumImageCarousel({
    super.key,
    required this.stadium,
    required this.displayImages,
  });

  @override
  State<StadiumImageCarousel> createState() => _StadiumImageCarouselState();
}

class _StadiumImageCarouselState extends State<StadiumImageCarousel> {
  late final PageController _pageController;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
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
                  itemCount: widget.displayImages.length,
                  onPageChanged: (idx) => setDialogState(() => activeIdx = idx),
                  itemBuilder: (ctx, i) {
                    return InteractiveViewer(
                      child: CachedNetworkImage(
                        imageUrl: widget.displayImages[i],
                        memCacheWidth: 1080,
                        memCacheHeight: 1080,
                        fit: BoxFit.contain,
                      ),
                    );
                  },
                ),
                PositionedDirectional(
                  top: 0,
                  end: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: IconButton(
                        icon: const Icon(Iconsax.close_circle_copy, color: Colors.white, size: 28),
                        onPressed: () => Navigator.pop(dialogCtx),
                      ),
                    ),
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
                        '${activeIdx + 1} / ${widget.displayImages.length}',
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
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildVspLogoBackground() => Container(
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SizedBox(
      height: (MediaQuery.of(context).size.height * 0.35).clamp(250.0, 450.0),
      child: Stack(
        children: [
          // 1. Full Bleed Image Carousel with Touch Swipe
          Positioned.fill(
            child: widget.displayImages.isNotEmpty && widget.displayImages.first.isNotEmpty
                ? PageView.builder(
                    controller: _pageController,
                    itemCount: widget.displayImages.length,
                    onPageChanged: (index) => setState(() => _currentImageIndex = index),
                    itemBuilder: (context, index) {
                      final imageWidget = CachedNetworkImage(
                        imageUrl: widget.displayImages[index],
                        memCacheWidth: 800,
                        memCacheHeight: 600,
                        fit: BoxFit.cover,
                        placeholder: (ctx, url) => Container(color: VSPColors.surface),
                        errorWidget: (ctx, url, _) => _buildVspLogoBackground(),
                      );

                      return GestureDetector(
                        onTap: () => _openFullScreenGallery(index),
                        child: index == 0
                            ? Hero(
                                tag: 'stadium-hero-${widget.stadium.id}',
                                child: imageWidget,
                              )
                            : imageWidget,
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
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    VSPBackButton(
                      size: 40,
                      backgroundColor: VSPColors.background.withValues(alpha: 0.6),
                    ),
                    Row(
                      children: [
                        _buildCircularIcon(
                          icon: Iconsax.share_copy,
                          onTap: () => SharePlus.instance.share(
                            ShareParams(text: l10n.shareStadiumText(widget.stadium.name, widget.stadium.location)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Consumer<AuthProvider>(
                          builder: (context, auth, _) {
                            final isFav = auth.userModel?.favoriteStadiums.contains(widget.stadium.id) ?? false;
                            return _buildCircularIcon(
                              icon: isFav ? Iconsax.heart : Iconsax.heart_copy,
                              color: VSPColors.accent,
                              onTap: () => auth.toggleFavoriteStadium(widget.stadium.id),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. Bottom Dots Indicator
          if (widget.displayImages.length > 1)
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
                      children: List.generate(widget.displayImages.length, (idx) {
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
    );
  }
}
