import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/ui/components/vsp_card.dart';
import '../../../core/ui/components/vsp_stat_card.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/stadium_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../widgets/custom_date_range_picker.dart';
import '../../../data/models.dart';
import '../../../shared/widgets/vsp_fade_in_item.dart';

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
      // Stream will auto-update based on state change if parameters passed
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VSPColors.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header & Notification
              _buildHeader(),
              const SizedBox(height: VSPSpacing.md),

              // 2. Functional Filters
              _buildFunctionalFilters(),
              const SizedBox(height: VSPSpacing.md),

              // 3. Stats Grid (Calculated)
              _buildStatsGrid(),
              const SizedBox(height: VSPSpacing.xl),

              // 4. Booked Today Section
              Text(
                'Booked Today',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: VSPSpacing.md),
              _buildBookedTodayList(),
              
              const SizedBox(height: VSPSpacing.xxl * 2), // Space for bottom nav
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
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'You have $stadiumsCount ${stadiumsCount == 1 ? 'stadium' : 'stadiums'}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(VSPSpacing.sm),
          decoration: BoxDecoration(
            color: VSPColors.surface,
            borderRadius: BorderRadius.circular(VSPRadius.md),
          ),
          child: Stack(
            children: [
              const Icon(Icons.notifications_outlined, color: VSPColors.textPrimary, size: 24),
              // Green Badge
              Positioned(
                top: 0,
                right: 2,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: VSPColors.accent,
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
            height: 48, 
            padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md),
            decoration: BoxDecoration(
              color: VSPColors.surface,
              borderRadius: BorderRadius.circular(VSPRadius.md), 
              border: Border.all(color: VSPColors.divider),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedStadium,
                dropdownColor: VSPColors.surface,
                icon: const Icon(Icons.keyboard_arrow_down, color: VSPColors.textSecondary, size: 16),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textPrimary),
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
              height: 48, 
              padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md),
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(color: VSPColors.divider),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text(formattedDate, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textPrimary)),
                   const Icon(Icons.calendar_today_outlined, color: VSPColors.textPrimary, size: 16),
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
        final stadium = stadiumProvider.stadiums.firstWhere(
          (s) => s.id == booking.stadiumId, 
          orElse: () => Stadium(id: '', name: 'Unknown', location: '', imageUrl: '', type: '', size: '', baths: 0, cafeteria: 0, seatsCapacity: 0, pricePerHour: 0, area: '', ownerId: '')
        );
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
        VSPFadeInItem(
          index: 0,
          child: VSPCard(
            width: double.infinity,
            padding: const EdgeInsets.all(VSPSpacing.md),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(VSPSpacing.sm),
                   decoration: BoxDecoration(
                    color: VSPColors.background,
                    shape: BoxShape.circle,
                    border: Border.all(color: VSPColors.divider),
                  ),
                  child: const Icon(Icons.monetization_on_outlined, color: VSPColors.accent, size: 22),
                ),
               const SizedBox(width: 16),
               Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text('Revenue (Cash at Stadium)', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary)),
                   Text('${revenueStr} EGP', style: Theme.of(context).textTheme.displayMedium?.copyWith(color: VSPColors.accent)),
                   const SizedBox(height: 4),
                   Text(
                     'Commission Pending (5%): $commissionStr EGP',
                     style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.warning, fontWeight: FontWeight.bold),
                   ),
                 ],
               ),
               const Spacer(),
               // Details Button
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                 decoration: BoxDecoration(
                   color: VSPColors.surfaceAlt,
                   borderRadius: BorderRadius.circular(20), 
                 ),
                 child: Row(
                   children: [
                     Text('Details', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary, fontSize: 10)),
                     const SizedBox(width: 4),
                     const Icon(Icons.arrow_outward, color: VSPColors.textSecondary, size: 10)
                   ],
                 ),
               )
            ],
          ),
        ),
        ),
        
        const SizedBox(height: 12),

        // 2x2 Grid
        VSPFadeInItem(
          index: 1,
          child: Row(
            children: [
              Expanded(
                child: VSPStatCard(
                  label: 'Booked',
                  value: bookedStr,
                  icon: Icons.check_circle_outline,
                  trend: '22%',
                ),
              ),
              const SizedBox(width: VSPSpacing.md),
              Expanded(
                child: VSPStatCard(
                  label: 'Total Time',
                  value: timeStr,
                  icon: Icons.access_time,
                  trend: '10%',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: VSPSpacing.md),
        VSPFadeInItem(
          index: 2,
          child: Row(
            children: [
              Expanded(child: _buildRateCard()),
              const SizedBox(width: VSPSpacing.md),
              Expanded(
                child: VSPStatCard(
                  label: 'Visitors',
                  value: visitorsStr,
                  icon: Icons.remove_red_eye_outlined,
                  trend: '9%',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRateCard() {
    return VSPCard(
      height: 110,
      padding: const EdgeInsets.all(VSPSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Icon(Icons.star_border, color: VSPColors.textSecondary, size: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rate', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary)),
              const SizedBox(height: 4),
              Row(
                children: List.generate(5, (index) => Icon(Icons.star, color: index < _rating.floor() ? VSPColors.warning : VSPColors.divider, size: 16)), 
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
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: VSPColors.textSecondary),
        ),
      );
    }

    return Column(
      children: [
        ...todayBookings.asMap().entries.map((entry) {
          final index = entry.key;
          final booking = entry.value;
          final timeStr = DateFormat('h a').format(booking.startTime);
          
          return VSPFadeInItem(
            index: index + 3,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 50,
                    child: Text(timeStr, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 16, color: VSPColors.textPrimary)),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                             VSPColors.accent.withValues(alpha: 0.1),
                             VSPColors.surface,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(VSPRadius.md), 
                        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: VSPColors.background,
                            backgroundImage: booking.playerTeamName != null ? null : const NetworkImage('https://images.unsplash.com/photo-1543351611-58f69d7c1781?w=150&h=150&fit=crop&q=80'),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(booking.playerTeamName ?? 'Individual Player', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: VSPColors.textPrimary)),
                              Text(booking.bookingType == BookingType.challenge ? 'Challenge Match' : 'Normal Match', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: VSPColors.textSecondary)),
                            ],
                          ),
                          const Spacer(),
                          const Icon(Icons.edit_outlined, color: VSPColors.accent, size: 22),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }
}
