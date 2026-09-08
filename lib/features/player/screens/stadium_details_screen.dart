import 'package:flutter/material.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../core/repositories/stadium_repository.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../data/models.dart';
import '../widgets/stadium_details/stadium_bottom_booking_bar.dart';
import '../widgets/stadium_details/stadium_image_carousel.dart';
import '../widgets/stadium_details/stadium_information_tab.dart';
import '../widgets/stadium_details/stadium_pitch_conditions_tab.dart';
import '../widgets/stadium_details/stadium_ratings_tab.dart';

/// Screen displaying complete details for a stadium including image carousel, facilities, conditions, and reviews.
class StadiumDetailsScreen extends StatefulWidget {
  final Stadium stadium;
  const StadiumDetailsScreen({super.key, required this.stadium});

  @override
  State<StadiumDetailsScreen> createState() => _StadiumDetailsScreenState();
}

class _StadiumDetailsScreenState extends State<StadiumDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final List<String> _displayImages;
  late final Stream<List<Map<String, dynamic>>> _stadiumStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _stadiumStream = StadiumRepository().streamStadiumRaw(widget.stadium.id);

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
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _stadiumStream,
      builder: (context, snapshot) {
        Stadium stadium = widget.stadium;
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          try {
            stadium = Stadium.fromFirestore(snapshot.data!.first, widget.stadium.id);
          } catch (_) {}
        }

        return Scaffold(
          backgroundColor: VSPColors.background,
          body: Column(
            children: [
              StadiumImageCarousel(
                stadium: stadium,
                displayImages: _displayImages,
              ),
              Container(
                color: VSPColors.background,
                padding: const EdgeInsets.all(VSPSpacing.md),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: VSPColors.surface,
                    borderRadius: BorderRadius.circular(VSPRadius.xl),
                  ),
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
                    StadiumInformationTab(stadium: stadium),
                    StadiumPitchConditionsTab(stadium: stadium),
                    StadiumRatingsTab(stadium: stadium),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: StadiumBottomBookingBar(stadium: stadium),
        );
      },
    );
  }
}
