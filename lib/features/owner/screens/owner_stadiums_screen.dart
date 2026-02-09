import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models.dart';
import '../../../core/providers/stadium_provider.dart';
import 'add_stadium_screen.dart';
import 'document_upload_screen.dart';

class OwnerStadiumsScreen extends StatefulWidget {
  final bool isDevMode;
  
  const OwnerStadiumsScreen({
    super.key,
    this.isDevMode = false,
  });

  @override
  State<OwnerStadiumsScreen> createState() => _OwnerStadiumsScreenState();
}

class _OwnerStadiumsScreenState extends State<OwnerStadiumsScreen> {
  
  @override
  void initState() {
    super.initState();
    // Fetch stadiums when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<StadiumProvider>(context, listen: false).listenToStadiums();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        elevation: 0,
        automaticallyImplyLeading: false, // Hide back button if it's main tab
        title: Consumer<StadiumProvider>(
          builder: (context, provider, _) {
            return provider.stadiums.isNotEmpty
                ? const Text(
                    'Stadiums',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Agency FB',
                    ),
                  )
                : const SizedBox.shrink();
          },
        ),
        centerTitle: true,
      ),
      body: Consumer<StadiumProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null) {
            return Center(
              child: Text(
                'Error: ${provider.errorMessage}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (provider.stadiums.isEmpty) {
            return _buildEmptyState();
          }

          return _buildStadiumsList(provider.stadiums);
        },
      ),
      bottomNavigationBar: _buildBottomButtons(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 3D Stadium Illustration
            Image.asset(
              'assets/images/empty_stadium.png',
              width: 280,
              height: 280,
              errorBuilder: (context, error, stackTrace) {
                // Fallback if image not found
                return Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    color: AppTheme.cardBackground,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.stadium_outlined,
                    size: 120,
                    color: AppTheme.textSecondary,
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
            const Text(
              'All your stadiums will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'Agency FB',
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Add your stadium now',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStadiumsList(List<Stadium> stadiums) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: stadiums.length,
      itemBuilder: (context, index) {
        final stadium = stadiums[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildStadiumCard(stadium),
        );
      },
    );
  }

  Widget _buildStadiumCard(Stadium stadium) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        image: DecorationImage(
          image: NetworkImage(stadium.imageUrl.isNotEmpty 
              ? stadium.imageUrl 
              : 'https://images.unsplash.com/photo-1556056504-5c7696c4c28d?w=800&h=600&fit=crop&q=80'),
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
          // Top Left: Location Badge
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.location_on,
                    color: AppTheme.neonGreen,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    stadium.location,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Top Right: Edit Icon
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.edit_outlined,
                color: AppTheme.neonGreen,
                size: 18,
              ),
            ),
          ),

          // Bottom Info Bar with Blur
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                color: Colors.black.withValues(alpha: 0.7),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          stadium.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Seats ${stadium.seatsCapacity} person',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildFeatureIcon(Icons.bathroom),
                      const SizedBox(width: 12),
                      _buildFeatureIcon(Icons.male),
                      const SizedBox(width: 12),
                      _buildFeatureIcon(Icons.favorite_border),
                      const Spacer(),
                      Text(
                        stadium.location.split(',').first, // Just city
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.neonGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Price ${stadium.pricePerHour.toStringAsFixed(0)} eg',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureIcon(IconData icon) {
    return Icon(
      icon,
      color: AppTheme.textSecondary,
      size: 18,
    );
  }

  Widget _buildBottomButtons() {
    return Consumer<StadiumProvider>(
      builder: (context, provider, _) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.darkBackground,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Add Stadium Button (Always visible)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddStadiumScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D5016), // Dark Green
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Add stadium',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                
                // Complete Info Button (Only when stadiums exist)
                if (provider.stadiums.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DocumentUploadScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.neonGreen,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Complete your info',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
