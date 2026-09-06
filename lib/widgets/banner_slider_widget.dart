import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';

import '../models/banner_model.dart';
import '../services/banner_service.dart';
import '../core/ui/tokens/vsp_tokens.dart';
import '../features/player/screens/player_home_screen.dart';

/// An interactive, auto-rotating promotional banner carousel linked directly to Supabase.
class BannerSliderWidget extends StatefulWidget {
  final String placement;
  final double height;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool autoPlay;
  final bool showIndicators;
  final void Function(AppBanner banner)? onBannerTap;

  const BannerSliderWidget({
    super.key,
    this.placement = 'home_slider',
    this.height = 155.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0),
    this.borderRadius = VSPRadius.lg,
    this.autoPlay = true,
    this.showIndicators = true,
    this.onBannerTap,
  });

  @override
  State<BannerSliderWidget> createState() => _BannerSliderWidgetState();
}

class _BannerSliderWidgetState extends State<BannerSliderWidget> {
  final PageController _pageController = PageController();
  final BannerService _bannerService = BannerService();

  int _currentIndex = 0;
  Timer? _timer;
  StreamSubscription<List<AppBanner>>? _streamSubscription;
  List<AppBanner> _banners = [];
  bool _isLoading = true;
  bool _isUserInteracting = false;

  @override
  void initState() {
    super.initState();
    _fetchBanners();
    _subscribeToStream();
  }

  Future<void> _fetchBanners() async {
    try {
      final banners = await _bannerService.getActiveBanners(placement: widget.placement);
      if (!mounted) return;
      setState(() {
        _banners = banners;
        _isLoading = false;
      });
      if (_banners.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _banners.isNotEmpty) {
            _bannerService.recordBannerImpression(_banners[_currentIndex].id);
            _scheduleNextSlide();
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _subscribeToStream() {
    _streamSubscription = _bannerService
        .getActiveBannersStream(placement: widget.placement)
        .listen((newBanners) {
      if (!mounted) return;
      setState(() {
        _banners = newBanners;
        _isLoading = false;
        if (_currentIndex >= _banners.length) {
          _currentIndex = 0;
        }
      });
      if (_banners.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _banners.isNotEmpty) {
            _bannerService.recordBannerImpression(_banners[_currentIndex].id);
            _scheduleNextSlide();
          }
        });
      }
    }, onError: (err) {
      debugPrint('[BannerSliderWidget] Stream error (using REST fallback): $err');
    });
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _scheduleNextSlide() {
    _timer?.cancel();
    if (!widget.autoPlay || _banners.length <= 1 || _isUserInteracting) return;

    final currentBanner = _banners.isNotEmpty && _currentIndex < _banners.length
        ? _banners[_currentIndex]
        : null;

    final seconds = (currentBanner?.durationSeconds ?? 5).clamp(3, 30);

    _timer = Timer(Duration(seconds: seconds), () {
      if (!mounted || !_pageController.hasClients || _isUserInteracting) return;

      final nextIndex = (_currentIndex + 1) % _banners.length;
      _pageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _onPageChanged(int index) {
    if (!mounted || _banners.isEmpty) return;
    setState(() {
      _currentIndex = index;
    });

    // Record impression for the visible banner
    if (index >= 0 && index < _banners.length) {
      _bannerService.recordBannerImpression(_banners[index].id);
    }

    _scheduleNextSlide();
  }

  Future<void> _handleBannerTap(AppBanner banner) async {
    HapticFeedback.lightImpact();
    // Record click count
    _bannerService.recordBannerClick(banner.id);

    // If custom callback provided
    if (widget.onBannerTap != null) {
      widget.onBannerTap!(banner);
      return;
    }

    final target = banner.targetUrl?.trim();
    if (target == null || target.isEmpty) return;

    // 1. External URL or WhatsApp link
    if (banner.isExternalUrl) {
      final uri = Uri.parse(
        target.startsWith('wa.me') ? 'https://$target' : target,
      );
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        debugPrint('[BannerSliderWidget] Error launching URL: $e');
      }
      return;
    }

    // 2. Internal Tab or Route Navigation
    final normalized = target.toLowerCase();

    // Tab shortcuts
    if (normalized == 'home' || normalized == '/home' || normalized == 'tab:0') {
      playerHomeScreenKey.currentState?.switchToTab(0);
      return;
    }
    if (normalized == 'matches' || normalized == '/matches' || normalized == 'team' || normalized == 'tab:1') {
      playerHomeScreenKey.currentState?.switchToTab(1);
      return;
    }
    if (normalized == 'tournaments' || normalized == '/tournaments' || normalized == 'championships' || normalized == 'tab:2') {
      playerHomeScreenKey.currentState?.switchToTab(2);
      return;
    }
    if (normalized == 'bookings' || normalized == '/bookings' || normalized == 'tab:3') {
      playerHomeScreenKey.currentState?.switchToTab(3);
      return;
    }
    if (normalized == 'profile' || normalized == '/profile' || normalized == 'tab:4') {
      playerHomeScreenKey.currentState?.switchToTab(4);
      return;
    }

    // GoRouter internal path
    if (target.startsWith('/')) {
      try {
        context.push(target);
      } catch (e) {
        debugPrint('[BannerSliderWidget] Router navigation failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Loading State
    if (_isLoading && _banners.isEmpty) {
      return _buildSkeletonLoader();
    }

    // 2. Empty State (No banners available for this placement)
    if (_banners.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: widget.padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Banner Slider
          SizedBox(
            height: widget.height,
                child: Listener(
                  onPointerDown: (_) {
                    _isUserInteracting = true;
                    _timer?.cancel();
                  },
                  onPointerUp: (_) {
                    _isUserInteracting = false;
                    _scheduleNextSlide();
                  },
                  onPointerCancel: (_) {
                    _isUserInteracting = false;
                    _scheduleNextSlide();
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _banners.length,
                      onPageChanged: _onPageChanged,
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, index) {
                        final banner = _banners[index];
                        return _buildBannerCard(banner);
                      },
                    ),
                  ),
                ),
              ),

              // Page Indicators
              if (widget.showIndicators && _banners.length > 1) ...[
                const SizedBox(height: 8),
                _buildDotsIndicator(),
              ],
            ],
          ),
        );
  }

  Widget _buildBannerCard(AppBanner banner) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleBannerTap(banner),
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Container(
          decoration: BoxDecoration(
            color: VSPColors.surface,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: VSPColors.divider,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Banner Image
              CachedNetworkImage(
                imageUrl: banner.imageUrl,
                memCacheWidth: 800,
                memCacheHeight: 450,
                fit: BoxFit.cover,
                placeholder: (context, url) => Shimmer.fromColors(
                  baseColor: VSPColors.surface,
                  highlightColor: VSPColors.surfaceAlt,
                  child: Container(color: VSPColors.surface),
                ),
                errorWidget: (context, url, error) => Container(
                  color: VSPColors.surfaceAlt,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.broken_image_rounded, color: VSPColors.textSecondary, size: 28),
                        if (banner.title.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            banner.title,
                            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                            maxLines: 1,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // Subtle Bottom Gradient & Title Overlay if title exists
              if (banner.title.trim().isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.85),
                          Colors.black.withValues(alpha: 0.3),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.7, 1.0],
                      ),
                    ),
                    child: Text(
                      banner.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: VSPColors.black80,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDotsIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_banners.length, (index) {
        final isActive = index == _currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          height: 4,
          width: isActive ? 20 : 6,
          decoration: BoxDecoration(
            color: isActive ? VSPColors.accent : Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(VSPRadius.full),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: VSPColors.accent.withValues(alpha: 0.5),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }

  Widget _buildSkeletonLoader() {
    return Container(
      margin: widget.padding,
      height: widget.height,
      child: Shimmer.fromColors(
        baseColor: VSPColors.surface,
        highlightColor: VSPColors.surfaceAlt,
        child: Container(
          decoration: BoxDecoration(
            color: VSPColors.surface,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(color: VSPColors.divider),
          ),
        ),
      ),
    );
  }
}
