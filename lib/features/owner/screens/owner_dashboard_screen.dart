import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/stadium_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../widgets/custom_date_range_picker.dart';
import '../../../data/models.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  // --- State Variables ---
  String _selectedStadium = 'All Stadium';
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  
  // Stats Values
  final double _rating = 4.8; 

  @override
  void initState() {
    super.initState();
    // Fetch live data for owner
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isAuthenticated) {
        final uid = auth.firebaseUser!.uid;
        Provider.of<StadiumProvider>(context, listen: false).listenToOwnerStadiums(uid);
        Provider.of<BookingProvider>(context, listen: false).loadOwnerBookings(uid);
      }
    });
  }
  





  Future<void> _pickDateRange() async {
    final picked = await showDialog<DateTimeRange>(
      context: context,
      builder: (context) => CustomDateRangePicker(initialDateRange: _selectedDateRange),
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
      setState(() {
        _selectedDateRange = picked;
      });
      // Stream will auto-update based on state change if parameters passed (not yet passed to stream, doing calculation in builder for simplicity)
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Pure Dark
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header & Notification
              _buildHeader(),
              const SizedBox(height: 20),

              // 2. Functional Filters
              _buildFunctionalFilters(),
              const SizedBox(height: 20),

              // 3. Stats Grid (Calculated)
              _buildStatsGrid(),
              const SizedBox(height: 32),

              // 4. Booked Today Section
              const Text(
                'Booked Today',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Agency FB',
                ),
              ),
              const SizedBox(height: 16),
              _buildBookedTodayList(),
              
              const SizedBox(height: 100), // Space for bottom nav
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final auth = Provider.of<AuthProvider>(context);
    final stadiumProvider = Provider.of<StadiumProvider>(context);
    final stadiumsCount = stadiumProvider.stadiums.length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hi ${auth.userModel?.name ?? "Owner"}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'Agency FB',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'You have $stadiumsCount ${stadiumsCount == 1 ? 'stadium' : 'stadiums'}',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              const Icon(Icons.notifications_outlined, color: Colors.white, size: 24),
              // Green Badge
              Positioned(
                top: 0,
                right: 2,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppTheme.neonGreen,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFunctionalFilters() {
    final stadiumProvider = Provider.of<StadiumProvider>(context);
    final List<String> stadiumNames = ['All Stadium', ...stadiumProvider.stadiums.map((s) => s.name)];
    
    // Ensure selected stadium still exists in the list (fallback to 'All Stadium')
    if (!stadiumNames.contains(_selectedStadium)) {
      _selectedStadium = 'All Stadium';
    }

    String formattedDate = '${DateFormat('MMM dd').format(_selectedDateRange.start)} - ${DateFormat('MMM dd').format(_selectedDateRange.end)}';

    return Row(
      children: [
        // Dropdown Filter (Stadiums)
        Expanded(
          child: Container(
            height: 44, // Fixed Reduced Height
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(8), // Standard 8.0 Radius
              border: Border.all(color: Colors.grey[800]!),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedStadium,
                dropdownColor: const Color(0xFF1E1E1E),
                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 16),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                isExpanded: true,
                items: stadiumNames.map((stadium) {
                  return DropdownMenuItem(
                    value: stadium,
                    child: Text(stadium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedStadium = val;
                    });
                  }
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Date Picker Trigger
        Expanded(
          child: InkWell(
            onTap: _pickDateRange,
            child: Container(
              height: 44, // Fixed Reduced Height
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(8), // Standard 8.0 Radius
                border: Border.all(color: Colors.grey[800]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text(formattedDate, style: const TextStyle(color: Colors.white, fontSize: 13)),
                   const Icon(Icons.calendar_today_outlined, color: Colors.white, size: 16),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    final bookingProvider = Provider.of<BookingProvider>(context);
    final stadiumProvider = Provider.of<StadiumProvider>(context);
    
    // Filter bookings based on selected stadium and date range
    final filteredBookings = bookingProvider.userBookings.where((booking) {
      bool matchesStadium = true;
      if (_selectedStadium != 'All Stadium') {
        // Try to match by name (since we use names in dropdown for now)
        final stadium = stadiumProvider.stadiums.firstWhere((s) => s.id == booking.stadiumId, orElse: () => Stadium(id: '', name: 'Unknown', location: '', imageUrl: '', type: '', size: '', baths: 0, cafeteria: 0, seatsCapacity: 0, pricePerHour: 0, area: '', ownerId: ''));
        matchesStadium = stadium.name == _selectedStadium;
      }
      
      bool matchesDate = booking.startTime.isAfter(_selectedDateRange.start) && 
                         booking.startTime.isBefore(_selectedDateRange.end.add(const Duration(days: 1)));
      
      return matchesStadium && matchesDate;
    }).toList();

    double revenue = 0;
    int totalHours = 0;
    int totalVisitors = 0;
    
    for (var b in filteredBookings) {
      revenue += b.totalPrice;
      totalHours += b.endTime.difference(b.startTime).inHours;
      // visitor count: for team bookings, could be many; for indiv, usually 1 or slot.
      // we'll assume 10 per hour for rough estimate if data missing
      totalVisitors += 12; 
    }

    final int bookingsCount = filteredBookings.length;
    final double commission = revenue * 0.05;

    // Format numeric values
    String revenueStr = revenue >= 1000 ? '${(revenue/1000).toStringAsFixed(1)}K' : revenue.toStringAsFixed(0); 
    String bookedStr = bookingsCount.toString();
    String timeStr = '${totalHours}h';
    String visitorsStr = totalVisitors >= 1000 ? '${(totalVisitors/1000).toStringAsFixed(1)}K' : totalVisitors.toString();
    String commissionStr = commission >= 1000 ? '${(commission/1000).toStringAsFixed(1)}K' : commission.toStringAsFixed(0);

    return Column(
      children: [
        // Revenue Card (Large Top)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(15), 
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                 decoration: BoxDecoration(
                  color: Colors.grey[900],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey[800]!),
                ),
                child: const Icon(Icons.monetization_on_outlined, color: Colors.white, size: 22),
              ),
               const SizedBox(width: 16),
               Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   const Text('Revenue (Cash at Stadium)', style: TextStyle(color: Colors.grey, fontSize: 11)),
                   Text('${revenueStr} EGP', style: const TextStyle(color: AppTheme.neonGreen, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Agency FB')),
                   const SizedBox(height: 4),
                   Text(
                     'App Commission Pending (5%): $commissionStr EGP',
                     style: const TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold),
                   ),
                 ],
               ),
               const Spacer(),
               // Details Button
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                 decoration: BoxDecoration(
                   color: Colors.grey[800],
                   borderRadius: BorderRadius.circular(20), 
                 ),
                 child: Row(
                   children: [
                     Text('Details', style: TextStyle(color: Colors.grey[300], fontSize: 10)),
                     const SizedBox(width: 4),
                     Icon(Icons.arrow_outward, color: Colors.grey[300], size: 10)
                   ],
                 ),
               )
            ],
          ),
        ),
        
        const SizedBox(height: 12),

        // 2x2 Grid
        Row(
          children: [
            Expanded(child: _buildStatCard('Booked', bookedStr, '22%', Icons.check_circle_outline)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard('Total Time Booked', timeStr, '10%', Icons.access_time)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildRateCard()),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard('Visitors', visitorsStr, '9%', Icons.remove_red_eye_outlined)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, String trend, IconData icon) {
    return Container(
      height: 110, // Fixed height for uniformity
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(15), // Standard 15.0 Radius
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row( // Icon Top-Left
            children: [
              Icon(icon, color: Colors.white, size: 20),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Text(title, style: TextStyle(color: Colors.grey[400], fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
               const SizedBox(height: 2),
               Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(value, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, fontFamily: 'Agency FB')),
                  Row(
                    children: [
                      const Icon(Icons.arrow_upward, color: AppTheme.neonGreen, size: 10),
                      Text(trend, style: const TextStyle(color: AppTheme.neonGreen, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRateCard() {
    return Container(
      height: 110,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(15), // Standard 15.0 Radius
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Icon(Icons.star_border, color: Colors.white, size: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rate', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
              const SizedBox(height: 4),
              Row(
                children: List.generate(5, (index) => Icon(Icons.star, color: index < _rating.floor() ? const Color(0xFFFFD700) : Colors.grey[700], size: 16)), // Gold
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBookedTodayList() {
    final bookingProvider = Provider.of<BookingProvider>(context);
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    // Filter for today's bookings
    final todayBookings = bookingProvider.userBookings.where((b) => 
      b.startTime.isAfter(todayStart) && b.startTime.isBefore(todayEnd)
    ).toList();

    if (todayBookings.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        alignment: Alignment.center,
        child: Text(
          'No bookings for today',
          style: TextStyle(color: Colors.grey[600], fontSize: 16),
        ),
      );
    }

    return Column(
      children: [
        ...todayBookings.map((booking) {
          final timeStr = DateFormat('h a').format(booking.startTime);
          // For now, assume we show the player's name if it's an individual booking
          // Since we might not have the full User object here, we'll use placeholder or get from booking if available
          // In a real app, you'd fetch the user profile or it's stored in booking.
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 50,
                  child: Text(timeStr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Agency FB', fontSize: 16)),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                           Color(0xFF2D5016),
                           Color(0xFF1E1E1E),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(15), 
                      border: Border.all(color: AppTheme.neonGreen.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppTheme.cardBackground,
                          backgroundImage: booking.playerTeamName != null ? null : const NetworkImage('https://images.unsplash.com/photo-1543351611-58f69d7c1781?w=150&h=150&fit=crop&q=80'),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(booking.playerTeamName ?? 'Individual Player', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                            Text(booking.bookingType == BookingType.challenge ? 'Challenge Match' : 'Normal Match', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                        const Spacer(),
                        const Icon(Icons.edit_outlined, color: AppTheme.neonGreen, size: 22),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}
