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
import 'owner_booked_screen.dart';

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
  // Removed hardcoded _rating = 4.8

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
          padding: EdgeInsets.fromLTRB(VSPSpacing.md, VSPSpacing.md, VSPSpacing.md, MediaQuery.of(context).padding.bottom + 110),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Booked Today',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: VSPColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Live bookings for today',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: VSPColors.textSecondary,
                                  fontSize: 10,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: VSPSpacing.md),
              _buildBookedTodayList(),
              
              const SizedBox(height: VSPSpacing.lg),
              // Show More Button
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const OwnerBookedScreen()),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Show more',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: VSPColors.accent),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down, color: VSPColors.accent, size: 18),
                    ],
                  ),
                ),
              ),
              
              // Removed fixed SizedBox as we use padding instead.
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

    String dateDisplayText = _selectedDateRange.start.day == DateTime.now().subtract(const Duration(days: 30)).day && 
                          _selectedDateRange.end.day == DateTime.now().day 
                          ? 'Last 30 days' 
                          : '${DateFormat('MMM dd').format(_selectedDateRange.start)} - ${DateFormat('MMM dd').format(_selectedDateRange.end)}';

    return Row(
      children: [
        // Dropdown Filter (Stadiums)
        Expanded(
          child: Container(
            height: 44, 
            padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md),
            decoration: BoxDecoration(
              color: VSPColors.surface,
              borderRadius: BorderRadius.circular(VSPRadius.md), 
              border: Border.all(color: VSPColors.divider, width: 0.5),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedStadium,
                dropdownColor: VSPColors.surface,
                icon: const Icon(Icons.keyboard_arrow_down, color: VSPColors.textSecondary, size: 18),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textPrimary, fontSize: 13),
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
            borderRadius: BorderRadius.circular(VSPRadius.md),
            child: Container(
              height: 44, 
              padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md),
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(color: VSPColors.divider, width: 0.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text(dateDisplayText, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textPrimary, fontSize: 13)),
                   const Icon(Icons.keyboard_arrow_down, color: VSPColors.textSecondary, size: 18),
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
    int totalMinutes = 0;
    
    for (var b in filteredBookings) {
      revenue += b.totalPrice;
      totalMinutes += b.endTime.difference(b.startTime).inMinutes;
    }

    final int bookingsCount = filteredBookings.length;
    final double commission = revenue * 0.05;

    // Format numeric values
    String revenueStr = revenue >= 1000 ? '${(revenue/1000).toStringAsFixed(1)}K' : revenue.toStringAsFixed(0); 
    String bookedStr = bookingsCount.toString();
    
    // Minute-accurate time formatting
    String timeStr;
    if (totalMinutes == 0) {
      timeStr = '0m';
    } else {
      final h = totalMinutes ~/ 60;
      final m = totalMinutes % 60;
      if (h > 0 && m > 0) {
        timeStr = '${h}h ${m}m';
      } else if (h > 0) {
        timeStr = '${h}h';
      } else {
        timeStr = '${m}m';
      }
    }
    
    String visitorsStr = 'N/A'; // Neutral fallback for unknown visitors metric
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
                    border: Border.all(color: VSPColors.divider, width: 0.5),
                  ),
                  child: const Icon(Icons.monetization_on_outlined, color: VSPColors.accent, size: 24),
                ),
               const SizedBox(width: 16),
               Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text('Total Revenue', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary)),
                   const SizedBox(height: 2),
                   Text('${revenueStr} EGP', style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28, color: VSPColors.textPrimary)),
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
                     const Icon(Icons.arrow_forward_ios, color: VSPColors.textSecondary, size: 8)
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
                  // Intentionally removed trend percentages as they are not calculated from real history yet.
                ),
              ),
              const SizedBox(width: VSPSpacing.md),
              Expanded(
                child: VSPStatCard(
                  label: 'Total Time',
                  value: timeStr,
                  icon: Icons.access_time_outlined,
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
                  // Intentionally neutralized to N/A until real turnstile analytics exist. Do not invent formulas.
                  value: visitorsStr,
                  icon: Icons.groups_outlined,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRateCard() {
    return const VSPStatCard(
      label: 'Rate',
      // Intentionally neutralized to N/A until real rating API is implemented. Do not reintroduce fake numbers.
      value: 'N/A', 
      icon: Icons.star_outline,
    );
  }

  Widget _buildBookedTodayList() {
    final bookingProvider = Provider.of<BookingProvider>(context);
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final stadiumProvider = Provider.of<StadiumProvider>(context);

    // Filter for today's bookings + Stadium Filter
    final todayBookings = bookingProvider.userBookings.where((b) {
      final isToday = b.startTime.isAfter(todayStart) && b.startTime.isBefore(todayEnd);
      
      bool matchesStadium = true;
      if (_selectedStadium != 'All Stadium') {
        final stadium = stadiumProvider.stadiums.firstWhere(
          (s) => s.id == b.stadiumId, 
          orElse: () => Stadium(id: '', name: 'Unknown', location: '', imageUrl: '', type: '', size: '', baths: 0, cafeteria: 0, seatsCapacity: 0, pricePerHour: 0, area: '', ownerId: '')
        );
        matchesStadium = stadium.name == _selectedStadium;
      }
      
      return isToday && matchesStadium;
    }).toList();

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
              margin: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    child: Text(
                      timeStr, 
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold, 
                        fontSize: 16, 
                        color: VSPColors.textPrimary.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                             VSPColors.cardGreen,
                             VSPColors.cardDarkGreen,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(VSPRadius.lg), 
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: VSPColors.surfaceAlt,
                              border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3), width: 1),
                            ),
                            child: const Icon(Icons.person_outline, color: VSPColors.textSecondary, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  booking.playerTeamName ?? 'Individual Player', 
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  booking.bookingType == BookingType.challenge 
                                      ? 'Challenge Match' 
                                      : (booking.bookingType == BookingType.team ? 'Team Match' : 'Player'), 
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.more_vert, color: Colors.white54, size: 20),
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
