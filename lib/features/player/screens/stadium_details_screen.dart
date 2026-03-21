import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../data/models.dart';
import 'booking_type_screen.dart';

class StadiumDetailsScreen extends StatefulWidget {
  final Stadium stadium;

  const StadiumDetailsScreen({super.key, required this.stadium});

  @override
  State<StadiumDetailsScreen> createState() => _StadiumDetailsScreenState();
}

class _StadiumDetailsScreenState extends State<StadiumDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isFavorite = false;
  int _currentImageIndex = 0;
  late final List<String> _displayImages;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _isFavorite = widget.stadium.isFavorite;
    _displayImages = widget.stadium.images.isNotEmpty ? widget.stadium.images : [widget.stadium.imageUrl];
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VSPColors.background,
      body: Column(
        children: [
          // Header (Stack with Image and Slider Dots)
          SizedBox(
            height: (MediaQuery.of(context).size.height * 0.35).clamp(250.0, 450.0),
            child: Stack(
              children: [
                Positioned.fill(
                  child: _displayImages.isNotEmpty && _displayImages.first.isNotEmpty
                      ? PageView.builder(
                          itemCount: _displayImages.length,
                          onPageChanged: (index) {
                            setState(() {
                              _currentImageIndex = index;
                            });
                          },
                          itemBuilder: (context, index) {
                            return CachedNetworkImage(
                              imageUrl: _displayImages[index],
                              fit: BoxFit.cover,
                              memCacheHeight: 800,
                              maxHeightDiskCache: 1200,
                              placeholder: (context, url) => Container(
                                color: VSPColors.surface,
                              ),
                              errorWidget: (context, url, error) => _buildVspLogoBackground(),
                            );
                          },
                        )
                      : _buildVspLogoBackground(),
                ),
                // Gradient Overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          VSPColors.background,
                        ],
                      ),
                    ),
                  ),
                ),
                // Header Icons
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(VSPSpacing.md),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildCircularIcon(
                          icon: Icons.arrow_back_ios_new,
                          onTap: () => Navigator.pop(context),
                        ),
                        Row(
                          children: [
                            _buildCircularIcon(
                              icon: Icons.share_outlined,
                              onTap: () {
                                Share.share(
                                  'Check out ${widget.stadium.name} in ${widget.stadium.location} on VSP app!',
                                );
                              },
                            ),
                            const SizedBox(width: VSPSpacing.md),
                            _buildCircularIcon(
                              icon: _isFavorite ? Icons.favorite : Icons.favorite_border,
                              color: _isFavorite ? VSPColors.accent : VSPColors.textPrimary,
                              onTap: () {
                                setState(() => _isFavorite = !_isFavorite);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Slider Dots Indicator
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_displayImages.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: _buildDot(isActive: index == _currentImageIndex),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),

          Container(
            color: VSPColors.background,
            padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.md),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: BorderRadius.circular(VSPRadius.xl),
              ),
              child: AnimatedBuilder(
                animation: _tabController,
                builder: (context, child) {
                  return Row(
                    children: [
                      _buildTabItem(0, 'Information'),
                      _buildTabItem(1, 'Pitch Conditions'),
                      _buildTabItem(2, 'Ratings'),
                    ],
                  );
                },
              ),
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _InformationTab(stadium: widget.stadium),
                _PitchConditionsTab(stadium: widget.stadium),
                _RatingsTab(stadium: widget.stadium),
              ],
            ),
          ),
        ],
      ),
      // Booking Button & Price Fixed Bottom Bar
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
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Price per hour',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
                  ),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${widget.stadium.basePrice.toStringAsFixed(0)} ',
                          style: Theme.of(context).textTheme.displayLarge,
                        ),
                        TextSpan(
                          text: 'eg',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: VSPSpacing.lg),
              Expanded(
                child: PrimaryButton(
                  text: 'Book Now',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BookingTypeScreen(stadium: widget.stadium),
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
        color: isActive ? VSPColors.accent : VSPColors.textSecondary.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildVspLogoBackground() {
    return Container(
      color: VSPColors.surface,
      child: Center(
        child: Image.asset(
          'assets/images/logo.png', // VSP logo
          width: 80,
          height: 80,
          color: Colors.white.withValues(alpha: 0.06),
          colorBlendMode: BlendMode.modulate,
        ),
      ),
    );
  }
}

class _InformationTab extends StatelessWidget {
  final Stadium stadium;

  const _InformationTab({required this.stadium});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(VSPSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name and Stars
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  stadium.name,
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      ...List.generate(5, (index) => Icon(
                        index < stadium.rating.round() ? Icons.star : Icons.star_border, 
                        color: Colors.amber, 
                        size: 16
                      )),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${stadium.rating.toStringAsFixed(1)} (${stadium.reviewsCount} Reviews)',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: VSPSpacing.sm),
          
          // Address and Location Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  stadium.address.isNotEmpty ? stadium.address : 'N/A',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.textSecondary),
                ),
              ),
              const SizedBox(width: VSPSpacing.sm),
              GestureDetector(
                onTap: () async {
                   final query = Uri.encodeComponent(stadium.name);
                   final googleMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
                   try {
                     await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
                   } catch (e) {
                     debugPrint('Could not launch maps: $e');
                   }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: VSPColors.accent,
                    borderRadius: BorderRadius.circular(VSPRadius.xl),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_outlined, color: VSPColors.background, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        stadium.location.isNotEmpty ? stadium.location : 'N/A',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
          
          const SizedBox(height: VSPSpacing.lg),
          
          // Information Stadium
          Text(
            'Information Stadium',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: VSPSpacing.sm),
          Text(
            stadium.description.isNotEmpty 
              ? stadium.description 
              : 'No description provided.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.textSecondary, height: 1.5),
          ),
          
          const SizedBox(height: VSPSpacing.lg),
          
          // Features
          Text(
            'Features',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: VSPSpacing.md),
          Wrap(
            spacing: VSPSpacing.sm,
            runSpacing: VSPSpacing.sm,
            children: (Stadium.parseFeatures(stadium.features).isNotEmpty ? Stadium.parseFeatures(stadium.features) : []).map((feature) => Container(
              padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.sm),
              decoration: BoxDecoration(
                color: VSPColors.surfaceAlt,
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                borderRadius: BorderRadius.circular(VSPRadius.md),
              ),
              child: Text(
                feature,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            )).toList(),
          ),

          const SizedBox(height: VSPSpacing.lg),
          
          // Features For Money
          Text(
            'Features For Money',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: VSPSpacing.md),
          if (stadium.hasBall)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.sm),
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sports_soccer, color: VSPColors.accent, size: 14),
                  const SizedBox(width: 8),
                  Text(
                    'Ball Available: ${stadium.ballPrice.toStringAsFixed(0)} EGP',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.accent, fontWeight: FontWeight.bold),
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

class _PitchConditionsTab extends StatelessWidget {
  final Stadium stadium;

  const _PitchConditionsTab({required this.stadium});

  @override
  Widget build(BuildContext context) {
    final hasOwnerNotes = stadium.notes.trim().isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(VSPSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ Owner Notes Section (Priority Display)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(VSPSpacing.md),
            decoration: BoxDecoration(
              color: VSPColors.surface,
              borderRadius: BorderRadius.circular(VSPRadius.lg),
              border: Border.all(
                color: VSPColors.accent.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Owner Notes',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: VSPColors.accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: VSPSpacing.sm),
                Text(
                  hasOwnerNotes
                      ? stadium.notes
                      : 'No specific notes have been added by the stadium owner.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: VSPSpacing.lg),

          // Standard Policies Section
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
                  context,
                  'Punctuality:',
                  'Customers Must Arrive On Time For Their Reservation. Any Delay May Result In Forfeiting Part Of Their Playing Time Without Compensation.',
                ),
                const SizedBox(height: VSPSpacing.md),
                _buildPolicySection(
                  context,
                  'Reservation Duration:',
                  'The Playing Time Cannot Be Extended After The Booked Time Has Expired. If Additional Time Is Required, A New Reservation Must Be Made (Subject To Availability).',
                ),
                const SizedBox(height: VSPSpacing.md),
                _buildPolicySection(
                  context,
                  'Cancellation And Refund Policy:',
                  'No Refund Will Be Given If The Reservation Is Cancelled Less Than 24 Hours Before The Scheduled Time.\n\nIf The Cancellation Is Made More Than 24 Hours Before The Scheduled Time, A Full Refund Will Be Issued.',
                ),
                const SizedBox(height: VSPSpacing.md),
                _buildPolicySection(
                  context,
                  'Liability:',
                  'Stadium management is not responsible for lost, stolen, or damaged personal belongings. Players use the facilities at their own risk.',
                ),
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
          style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
        ),
      ],
    );
  }
}

class _RatingsTab extends StatelessWidget {
  final Stadium stadium;
  const _RatingsTab({required this.stadium});

   @override
  Widget build(BuildContext context) {
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
                // Big Score
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        stadium.rating.toStringAsFixed(1),
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 42),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) => Icon(
                          index < stadium.rating.round() ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 16,
                        )),
                      ),
                      const SizedBox(height: VSPSpacing.xs),
                      Text(
                        '${stadium.reviewsCount} Reviews',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Reviews List View
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('stadiums')
                .doc(stadium.id)
                .collection('reviews')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
              }
              
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Text(
                      'No reviews yet. Be the first to review!',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary),
                    ),
                  ),
                );
              }

              final reviews = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.all(VSPSpacing.md),
                itemCount: reviews.length,
                itemBuilder: (context, index) {
                  final reviewDoc = reviews[index].data() as Map<String, dynamic>;
                  final rating = (reviewDoc['rating'] as num?)?.toInt() ?? 0;
                  final text = reviewDoc['reviewText'] as String? ?? '';
                  final createdAt = reviewDoc['createdAt'] as Timestamp?;
                  
                  return _buildReviewItem(
                    context,
                    name: 'Player',
                    imageUrl: '',   
                    rating: rating,
                    timeAgo: createdAt != null ? timeago.format(createdAt.toDate()) : 'Recently',
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
            backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
            child: imageUrl.isEmpty ? const Icon(Icons.person, color: VSPColors.textSecondary) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      timeAgo,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
                    ),
                  ],
                ),
                Row(
                  children: List.generate(5, (index) => Icon(
                    Icons.star,
                    size: 12,
                    color: index < rating ? Colors.amber : VSPColors.surfaceAlt,
                  )),
                ),
                const SizedBox(height: 8),
                Text(
                  comment,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.textSecondary, height: 1.4),
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
