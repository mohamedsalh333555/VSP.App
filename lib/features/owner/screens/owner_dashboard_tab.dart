import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../../core/theme/app_theme.dart';
import '../../../core/services/database_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../data/models.dart';
import '../../../shared/widgets/stadium_card.dart';

class OwnerDashboardTab extends StatefulWidget {
  const OwnerDashboardTab({super.key});

  @override
  State<OwnerDashboardTab> createState() => _OwnerDashboardTabState();
}

class _OwnerDashboardTabState extends State<OwnerDashboardTab> {
  final DatabaseService _databaseService = DatabaseService();
  bool _showRevenue = true;

  @override
  void initState() {
    super.initState();
    // Load bookings for the current owner
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final uid = auth.firebaseUser?.uid;
      if (uid != null) {
        Provider.of<BookingProvider>(context, listen: false).loadOwnerBookings(uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final uid = auth.firebaseUser?.uid;

    if (uid == null) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.neonGreen));
    }

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Financial Overview',
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontFamily: 'Agency FB', fontSize: 24),
        ),
        actions: [
          IconButton(
            icon: Icon(_showRevenue ? Icons.visibility : Icons.visibility_off, color: Colors.white70),
            onPressed: () => setState(() => _showRevenue = !_showRevenue),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 💰 FINANCIAL STATS SECTION
            FutureBuilder<List<dynamic>>(
              future: Future.wait([
                _databaseService.calculateOwnerRevenue(uid),
                _databaseService.calculateBookedHours(uid),
              ]),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(color: AppTheme.neonGreen),
                  ));
                }

                final revenue = snapshot.data?[0] as double? ?? 0.0;
                final hours = snapshot.data?[1] as int? ?? 0;

                return Row(
                  children: [
                    Expanded(
                      child: _buildFinancialCard(
                        'Total Revenue',
                        _showRevenue ? '${revenue.toStringAsFixed(0)} EGP' : '**** EGP',
                        Icons.payments_outlined,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _buildFinancialCard(
                        'Booked Hours',
                        '$hours hrs',
                        Icons.timer_outlined,
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 32),

            // 🏟️ MY STADIUMS STATUS SECTION
            const Text(
              'My Stadiums Status',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Agency FB',
              ),
            ),
            const SizedBox(height: 16),

            StreamBuilder<List<Stadium>>(
              stream: _databaseService.getOwnerStadiums(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.neonGreen));
                }

                final stadiums = snapshot.data ?? [];

                if (stadiums.isEmpty) {
                  return _buildEmptyState();
                }

                return Column(
                  children: stadiums.map((stadium) => _buildStatusStadiumCard(stadium)).toList(),
                );
              },
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.neonGreen.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.neonGreen.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.neonGreen, size: 28),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'Agency FB',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusStadiumCard(Stadium stadium) {
    final bool isVerified = stadium.isVerified;
    final bookingProvider = Provider.of<BookingProvider>(context);

    final now = DateTime.now();

    // ✅ Filter upcoming bookings for this specific stadium
    final upcomingBookings = bookingProvider.userBookings
        .where((b) =>
            b.stadiumId == stadium.id &&
            b.startTime.isAfter(now) &&
            b.status != BookingStatus.cancelled)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStadiumHeader(stadium, isVerified),

          // ✅ Upcoming Bookings Section
          if (upcomingBookings.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Icon(Icons.event_note_outlined, color: Colors.white70, size: 16),
                      SizedBox(width: 8),
                      Text(
                        "Upcoming Bookings",
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...upcomingBookings.take(3).map((booking) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.03)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  booking.playerTeamName ?? "Individual Player",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (booking.bookingType == BookingType.challenge)
                                  const Text(
                                    "Challenge Match",
                                    style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.neonGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${booking.startTime.hour}:${booking.startTime.minute.toString().padLeft(2, '0')} - ${booking.endTime.hour}:${booking.endTime.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                color: AppTheme.neonGreen,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  if (upcomingBookings.length > 3)
                    Center(
                      child: Text(
                        "+ ${upcomingBookings.length - 3} more bookings",
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStadiumHeader(Stadium stadium, bool isVerified) {
    return Column(
      children: [
        Stack(
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              child: Image.network(
                stadium.imageUrl,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 140,
                  color: Colors.grey[900],
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
            // Status Badge
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isVerified ? AppTheme.neonGreen : Colors.orange,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: (isVerified ? AppTheme.neonGreen : Colors.orange).withOpacity(0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      isVerified ? Icons.check_circle : Icons.watch_later,
                      color: Colors.black,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isVerified ? 'Published' : 'Under Review',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stadium.name,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    stadium.location,
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                  ),
                ],
              ),
              Text(
                '${stadium.pricePerHour} EGP/hr',
                style: const TextStyle(color: AppTheme.neonGreen, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.stadium_outlined, color: Colors.grey[600], size: 64),
            ),
            const SizedBox(height: 24),
            const Text(
              'Welcome! Start Earning',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first stadium from the menu to start taking bookings and tracking your revenue.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
