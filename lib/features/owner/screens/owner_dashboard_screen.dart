import 'package:vsp_application/l10n/app_localizations.dart';
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
import '../../../core/services/database_service.dart';
import '../../../features/player/screens/notifications_center_screen.dart';
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
  
  bool _filterPendingOnly = false; // ✅ Added debt filter state
  
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
        final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
        bookingProvider.loadOwnerBookings(uid);
        
        // ── Auto-Reconciliation Pivot ──
        bookingProvider.autoReconcilePastBookings(uid);
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
        child: SingleChildScrollView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
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
              
              // Show More Button — only visible when > 3 bookings
              Builder(
                builder: (context) {
                  final bookingProvider = Provider.of<BookingProvider>(context);
                  final now = DateTime.now();
                  final todayStart = DateTime(now.year, now.month, now.day);
                  final todayEnd = todayStart.add(const Duration(days: 1));
                  final todayCount = bookingProvider.userBookings.where((b) {
                    return b.startTime.isAfter(todayStart) && b.startTime.isBefore(todayEnd);
                  }).length;

                  if (todayCount <= 3) return const SizedBox.shrink();

                  return Padding(
                    padding: const EdgeInsets.only(top: VSPSpacing.lg),
                    child: Center(
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
                  );
                },
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
              'Hi ${(auth.userModel?.name ?? "Owner").split(' ').first}',
              style: Theme.of(context).textTheme.displayMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'You have $stadiumsCount ${stadiumsCount == 1 ? 'stadium' : 'stadiums'}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary),
            ),
          ],
        ),
        Material(
          color: VSPColors.surface,
          borderRadius: BorderRadius.circular(VSPRadius.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(VSPRadius.md),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationsCenterScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(VSPSpacing.sm),
            child: StreamBuilder<int>(
              stream: DatabaseService().getUnreadNotificationCount(auth.firebaseUser?.uid ?? ''),
              builder: (context, snap) {
                final count = snap.data ?? 0;
                return Stack(
                  children: [
                    const Icon(Icons.notifications_outlined, color: VSPColors.textPrimary, size: 24),
                    if (count > 0)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: VSPColors.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
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
      
      bool matchesDebtFilter = !_filterPendingOnly || !booking.isPaid; // ✅ Debt filter filter logic
      
      return matchesStadium && matchesDate && matchesDebtFilter;
    }).toList();

    double revenue = 0; // Collected
    double debts = 0;   // Pending
    int totalMinutes = 0;
    final now = DateTime.now();
    
    for (var b in filteredBookings) {
      if (b.endTime.isBefore(now)) {
        revenue += b.totalPrice;
      } else {
        debts += b.totalPrice;
      }
      totalMinutes += b.endTime.difference(b.startTime).inMinutes;
    }

    final int bookingsCount = filteredBookings.length;
    final double commission = revenue * 0.05;
    double netRevenue = revenue - commission;

    // Format numeric values
    String revenueStr = revenue >= 1000 ? '${(revenue/1000).toStringAsFixed(1)}K' : revenue.toStringAsFixed(0); 
    String netStr = netRevenue >= 1000 ? '${(netRevenue/1000).toStringAsFixed(1)}K' : netRevenue.toStringAsFixed(0); 
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
    
    String debtStr = debts >= 1000 ? '${(debts/1000).toStringAsFixed(1)}K' : debts.toStringAsFixed(0);
    String commissionStr = commission >= 1000 ? '${(commission/1000).toStringAsFixed(1)}K' : commission.toStringAsFixed(0);

    return Column(
      children: [
        // 1. Revenue Card (Premium Design)
        VSPFadeInItem(
          index: 0,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(VSPSpacing.lg),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [VSPColors.accent, VSPColors.accent.withValues(alpha: 0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(VSPRadius.lg),
              boxShadow: [
                BoxShadow(color: VSPColors.accent.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Collected Revenue', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.black, fontWeight: FontWeight.bold)),
                    const Icon(Icons.account_balance_wallet_outlined, color: Colors.black, size: 24),
                  ],
                ),
                const SizedBox(height: 8),
                Text('${revenueStr} EGP', style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 34, color: Colors.black, letterSpacing: -1)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildMiniBadge('Net: ${netStr} EGP', Colors.black.withValues(alpha: 0.1)),
                    const SizedBox(width: 8),
                    _buildMiniBadge('Fees: ${commissionStr}', Colors.black.withValues(alpha: 0.1)),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 20),

        // 2. Main Stats Row
        VSPFadeInItem(
          index: 1,
          child: Row(
            children: [
              Expanded(
                child: VSPStatCard(
                  label: 'Hours Booked',
                  value: timeStr,
                  icon: Icons.history_toggle_off_rounded,
                ),
              ),
              const SizedBox(width: VSPSpacing.md),
              Expanded(
                child: VSPStatCard(
                  label: 'Active Bookings',
                  value: bookedStr,
                  icon: Icons.confirmation_number_outlined,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: VSPSpacing.md),
        
        // 3. Debt Row
        VSPFadeInItem(
          index: 2,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(VSPRadius.md),
              onTap: () {
                setState(() => _filterPendingOnly = !_filterPendingOnly);
              },
              child: Container(
                padding: const EdgeInsets.all(VSPSpacing.md),
                decoration: BoxDecoration(
                  color: _filterPendingOnly ? VSPColors.error.withValues(alpha: 0.1) : VSPColors.surface,
                  borderRadius: BorderRadius.circular(VSPRadius.md),
                  border: Border.all(color: _filterPendingOnly ? VSPColors.error.withValues(alpha: 0.5) : VSPColors.divider, width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: VSPColors.error.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.money_off_rounded, color: VSPColors.error, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pending Revenue', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary)),
                          Text('${debtStr} EGP', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: VSPColors.error, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (_filterPendingOnly)
                       const Text('FILTERING...', style: TextStyle(color: VSPColors.error, fontSize: 10, fontWeight: FontWeight.bold)),
                    Icon(Icons.chevron_right, color: VSPColors.textSecondary.withValues(alpha: 0.5)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(VSPRadius.sm)),
      child: Text(text, style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildRateCard() {
    return const SizedBox.shrink(); // Integrated into grid or removed for layout logic via StatCard replacements above
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
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: booking.endTime.isBefore(now) ? VSPColors.success.withValues(alpha: 0.2) : VSPColors.warning.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  booking.endTime.isBefore(now) ? 'COLLECTED' : 'PENDING',
                                  style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Icon(Icons.more_vert, color: VSPColors.textSecondary, size: 20),
                            ],
                          ),
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
