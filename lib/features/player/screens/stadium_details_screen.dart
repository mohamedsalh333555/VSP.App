import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _isFavorite = widget.stadium.isFavorite;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: Column(
        children: [
          // Header (Stack with Image and Slider Dots)
          SizedBox(
            height: 250,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.network(
                    widget.stadium.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[800],
                      child: const Center(child: Icon(Icons.stadium, size: 50, color: Colors.white)),
                    ),
                  ),
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
                          AppTheme.darkBackground.withValues(alpha: 0.9),
                        ],
                      ),
                    ),
                  ),
                ),
                // Header Icons
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildCircularIcon(
                          icon: Icons.arrow_back,
                          onTap: () => Navigator.pop(context),
                        ),
                        Row(
                          children: [
                            _buildCircularIcon(
                              icon: Icons.share,
                              onTap: () {},
                            ),
                            const SizedBox(width: 12),
                            _buildCircularIcon(
                              icon: _isFavorite ? Icons.favorite : Icons.favorite_border,
                              color: _isFavorite ? Colors.red : AppTheme.textPrimary,
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
                    children: [
                      _buildDot(isActive: true),
                      const SizedBox(width: 8),
                      _buildDot(isActive: false),
                      const SizedBox(width: 8),
                      _buildDot(isActive: false),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Custom Pill Tab Bar
          Container(
            color: AppTheme.darkBackground,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(30),
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
                const _RatingsTab(),
              ],
            ),
          ),
        ],
      ),
      // Booking Button & Price Fixed Bottom Bar
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.darkBackground,
          border: Border(top: BorderSide(color: Colors.grey[900]!)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Price per hour',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${widget.stadium.pricePerHour.toStringAsFixed(0)} ',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Agency FB',
                          ),
                        ),
                        const TextSpan(
                          text: 'eg',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 24),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BookingTypeScreen(stadium: widget.stadium),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.neonGreen,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15), // Detailed radius as requested
                    ),
                  ),
                  child: const Text(
                    'Book Now',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.neonGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.black : AppTheme.textSecondary,
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
    Color color = AppTheme.textPrimary,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
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
        color: isActive ? AppTheme.neonGreen : Colors.grey.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      ...List.generate(5, (index) => const Icon(Icons.star, color: Colors.amber, size: 16)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '4.5 (52 Reviews)',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Address and Location Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  stadium.address.isNotEmpty ? stadium.address : 'Av. De Concha Espina, 1, Chamartín, 28036 Madrid',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
// Add to imports at top: import 'package:url_launcher/url_launcher.dart';

              GestureDetector(
                onTap: () async {
                   final query = Uri.encodeComponent(stadium.name); // e.g. "Santiago Bernabéu Stadium"
                   final googleMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
                   // Try launching directly
                   try {
                     await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
                   } catch (e) {
                     debugPrint('Could not launch maps: $e');
                   }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.neonGreen,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_outlined, color: Colors.black, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        stadium.location.isNotEmpty ? stadium.location : 'Madrid',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Information Stadium
          const Text(
            'Information Stadium',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Agency FB',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            stadium.description.isNotEmpty 
              ? stadium.description 
              : 'The Santiago Bernabéu Stadium Is A Modern, Multi-Use Stadium Featuring A Retractable Roof, A Contemporary Facade, A Retractable Pitch, And Significant Improvements In Safety, Comfort, And Accessibility. It Also Includes Multifunctional Spaces Such As Restaurants, Museums, And Commercial Areas, As Well As A 360-Degree Giant Screen, With A Focus On Sustainability.',
            style: const TextStyle(color: AppTheme.textSecondary, height: 1.5, fontSize: 13),
          ),
          
          const SizedBox(height: 24),
          
          // Features
          const Text(
            'Features',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Agency FB', 
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (stadium.features.isNotEmpty ? stadium.features : ['Baths', '11 VS 11', 'Cafeteria', 'Jerash', 'Seats']).map((feature) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                feature,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            )).toList(),
          ),

          const SizedBox(height: 24),
          
          // Features For Money
          const Text(
            'Features For Money',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Agency FB',
            ),
          ),
          const SizedBox(height: 12),
          if (stadium.hasBall)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Ball',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ),

          const SizedBox(height: 32),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPolicySection(
              'Punctuality:',
              'Customers Must Arrive On Time For Their Reservation. Any Delay May Result In Forfeiting Part Of Their Playing Time Without Compensation.',
            ),
            const SizedBox(height: 16),
            _buildPolicySection(
              'Reservation Duration:',
              'The Playing Time Cannot Be Extended After The Booked Time Has Expired. If Additional Time Is Required, A New Reservation Must Be Made (Subject To Availability).',
            ),
            const SizedBox(height: 16),
            _buildPolicySection(
              'Cancellation And Refund Policy:',
              'No Refund Will Be Given If The Reservation Is Cancelled Less Than 24 Hours Before The Scheduled Time.\n\nIf The Cancellation Is Made More Than 24 Hours Before The Scheduled Time, A Full Refund Will Be Issued.',
            ),
            const SizedBox(height: 16),
             _buildPolicySection(
              'Liability:',
              'Stadium management is not responsible for lost, stolen, or damaged personal belongings. Players use the facilities at their own risk.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicySection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.neonGreen, // Updated to Neon Green
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          content,
          style: const TextStyle(
            color: Colors.white, // Updated to White
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _RatingsTab extends StatelessWidget {
  const _RatingsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              // Bars Column
              Expanded(
                child: Column(
                  children: [
                    _buildRatingBar(5, 0.8),
                    _buildRatingBar(4, 0.6),
                    _buildRatingBar(3, 0.4),
                    _buildRatingBar(2, 0.1),
                    _buildRatingBar(1, 0.05),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Big Score
              const Column(
                children: [
                  Text(
                    '4.5', // Updated Rating to 4.5
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Agency FB',
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber, size: 12),
                      Icon(Icons.star, color: Colors.amber, size: 12),
                      Icon(Icons.star, color: Colors.amber, size: 12),
                      Icon(Icons.star, color: Colors.amber, size: 12),
                      Icon(Icons.star_half, color: Colors.amber, size: 12),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    '52 Reviews',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),

        // Review 1
        _buildReviewItem(
          name: 'Courtney Henry',
          imageUrl: 'https://randomuser.me/api/portraits/women/32.jpg', // Changed to women to match name usually
          rating: 5,
          timeAgo: '2 Mins Ago',
          comment: 'Consequat Velit Qui Adipisicing Sunt Do Rependerit Ad Laborum Tempor Ullamco Exercitation. Ullamco Tempor Adipisicing Et Voluptate Duis Sit Esse Aliqua',
        ),

        // Review 2
        _buildReviewItem(
          name: 'Jane Cooper',
          imageUrl: 'https://randomuser.me/api/portraits/women/44.jpg',
          rating: 4,
          timeAgo: '2 Mins Ago',
          comment: 'Great stadium with excellent facilities!',
        ),
      ],
    );
  }

  Widget _buildRatingBar(int star, double pct) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 12,
            child: Text('$star', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ),
          const Icon(Icons.star, size: 10, color: Colors.amber),
          const SizedBox(width: 8),
          Expanded(
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.grey[800],
              color: AppTheme.neonGreen,
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewItem({
    required String name,
    required String imageUrl,
    required int rating,
    required String timeAgo,
    required String comment,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: NetworkImage(imageUrl),
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
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      timeAgo,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: List.generate(5, (index) => Icon(
                    Icons.star,
                    size: 12,
                    color: index < rating ? Colors.amber : Colors.grey,
                  )),
                ),
                const SizedBox(height: 8),
                Text(
                  comment,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
