import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../data/models.dart';
import 'booking_confirmation_screen.dart';
import 'challenge_select_team_screen.dart';

class BookingTypeScreen extends StatefulWidget {
  final Stadium stadium;

  const BookingTypeScreen({
    super.key,
    required this.stadium,
  });

  @override
  State<BookingTypeScreen> createState() => _BookingTypeScreenState();
}

class _BookingTypeScreenState extends State<BookingTypeScreen> {
  String? _selectedType;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: const Text(
          'Choose What Suits You',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            fontFamily: 'Agency FB',
          ),
        ),
        backgroundColor: AppTheme.darkBackground,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildBookingOption(
                    context,
                    id: 'Personal',
                    title: 'Personal Booking',
                    subtitle: 'Book the pitch for yourself and your friends.',
                    imageUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=800&q=80',
                  ),
                  const SizedBox(height: 24),
                  _buildBookingOption(
                    context,
                    id: 'Team',
                    title: 'Your Team',
                    subtitle: 'Manage and play as a registered team.',
                    imageUrl: 'https://upload.wikimedia.org/wikipedia/en/thumb/5/56/Newcastle_United_Logo.svg/1200px-Newcastle_United_Logo.svg.png',
                  ),
                  const SizedBox(height: 24),
                  _buildBookingOption(
                    context,
                    id: 'Challenge',
                    title: 'Challenge',
                    subtitle: 'Challenge another team for a competitive match.',
                    imageUrl: 'https://images.unsplash.com/photo-1529900748604-07564a03e7a6?w=800&q=80',
                  ),
                ],
              ),
            ),
          ),
          // Continue Button
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFF1C1C1E),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _selectedType == null ? null : _handleContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.neonGreen,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.grey[800],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleContinue() {
    if (_selectedType == 'Challenge') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChallengeSelectTeamScreen(
            stadium: widget.stadium,
            bookingType: _selectedType!,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookingConfirmationScreen(
            stadium: widget.stadium,
            bookingType: _selectedType!,
          ),
        ),
      );
    }
  }

  Widget _buildBookingOption(
    BuildContext context, {
    required String id,
    required String title,
    required String subtitle,
    required String imageUrl,
  }) {
    final bool isSelected = _selectedType == id;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = id;
        });
      },
      child: Container(
        width: double.infinity,
        height: 180,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.neonGreen : AppTheme.neonGreen.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned.fill(
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: isSelected ? 0.4 : 0.6),
                    BlendMode.darken,
                  ),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFF1E1E1E)),
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.9),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Agency FB',
                          ),
                        ),
                        if (isSelected)
                          const CircleAvatar(
                            radius: 12,
                            backgroundColor: AppTheme.neonGreen,
                            child: Icon(Icons.check, size: 16, color: Colors.black),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
