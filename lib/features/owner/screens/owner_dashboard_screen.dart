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
  DateTimeRange? _selectedDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  
  bool _isAllTime = false; // ✅ Added All-Time toggle
  
  bool _filterPendingOnly = false; // ✅ Added debt filter state
  
  // Stats Values
  // Removed hardcoded _rating = 4.8

  @override
  void initState() {
    super.initState();
    // Fetch live data for owner
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isAuthenticated) {
        final uid = auth.firebaseUser!.uid;
        final stadiumProvider = Provider.of<StadiumProvider>(context, listen: false);
        stadiumProvider.listenToOwnerStadiums(uid);
        
        // Wait briefly for stadium data to populate
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        
        final stadiums = stadiumProvider.stadiums
            .where((s) => s.ownerId == uid)
            .map((s) => s.id)
            .toList();

        final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
        bookingProvider.loadOwnerBookings(
          uid, 
          stadiumIds: stadiums.isNotEmpty ? stadiums : null
        );
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
        _isAllTime = false;
      });
    }
  }

  void _toggleAllTime() {
    setState(() {
      _isAllTime = !_isAllTime;
      if (_isAllTime) {
        _selectedDateRange = null; // Signal all time
      } else {
        _selectedDateRange = DateTimeRange(
          start: DateTime.now().subtract(const Duration(days: 30)),
          end: DateTime.now(),
        );
      }
    });
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
                        AppLocalizations.of(context)!.bookedTodayLabel,
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
                            AppLocalizations.of(context)!.liveBookingsForToday,
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
                              AppLocalizations.of(context)!.showMoreBtn,
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
              '${AppLocalizations.of(context)!.hiPrefix} ${(auth.userModel?.name ?? AppLocalizations.of(context)!.ownerGuestFallback).split(' ').first}',
              style: Theme.of(context).textTheme.displayMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context)!.youHaveStadiums(stadiumsCount),
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
    final String allStadiumsText = AppLocalizations.of(context)!.allStadiumsFilter;
    final List<String> stadiumNames = [allStadiumsText, ...stadiumProvider.stadiums.map((s) => s.name)];
    
    // Ensure selected stadium still exists in the list (fallback to 'All Stadium')
    if (!stadiumNames.contains(_selectedStadium)) {
      _selectedStadium = allStadiumsText;
    }

    String dateDisplayText = _isAllTime 
                          ? AppLocalizations.of(context)!.allTimeFilter 
                          : '${DateFormat('MMM dd').format(_selectedDateRange!.start)} - ${DateFormat('MMM dd').format(_selectedDateRange!.end)}';

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
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _pickDateRange,
                  borderRadius: BorderRadius.circular(VSPRadius.md),
                  child: Container(
                    height: 44, 
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: VSPColors.surface,
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                      border: Border.all(color: VSPColors.divider, width: 0.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                         Expanded(child: Text(dateDisplayText, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textPrimary, fontSize: 11), overflow: TextOverflow.ellipsis)),
                         const Icon(Icons.keyboard_arrow_down, color: VSPColors.textSecondary, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // All-time toggle button
              InkWell(
                onTap: _toggleAllTime,
                borderRadius: BorderRadius.circular(VSPRadius.md),
                child: Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: _isAllTime ? VSPColors.accent.withValues(alpha: 0.15) : VSPColors.surface,
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    border: Border.all(color: _isAllTime ? VSPColors.accent : VSPColors.divider, width: 0.5),
                  ),
                  child: Icon(
                    Icons.public, 
                    color: _isAllTime ? VSPColors.accent : VSPColors.textSecondary, 
                    size: 20
                  ),
                ),
              ),
            ],
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
      final String allStadiumsKey = AppLocalizations.of(context)!.allStadiumsFilter;
      bool matchesStadium = true;
      if (_selectedStadium != allStadiumsKey && _selectedStadium != 'All Stadium') {
        final stadium = stadiumProvider.stadiums.firstWhere(
          (s) => s.id == booking.stadiumId, 
          orElse: () => Stadium(id: '', name: 'Unknown', location: '', imageUrl: '', type: '', size: '', baths: 0, cafeteria: 0, seatsCapacity: 0, pricePerHour: 0, area: '', ownerId: '')
        );
        matchesStadium = stadium.name == _selectedStadium;
      }
      
      bool matchesDate = _isAllTime || 
                         (booking.startTime.isAfter(_selectedDateRange!.start) && 
                          booking.startTime.isBefore(_selectedDateRange!.end.add(const Duration(days: 1))));
      
      bool matchesDebtFilter = !_filterPendingOnly || !booking.isPaid;
      
      return matchesStadium && matchesDate && matchesDebtFilter;
    }).toList();

    double revenue = 0; // Collected
    double pendingRevenue = 0;   // Future/Pending
    int totalMinutes = 0;
    final now = DateTime.now();
    
    for (var b in filteredBookings) {
      if (b.endTime.isBefore(now)) {
        revenue += b.totalPrice;
        totalMinutes += b.endTime.difference(b.startTime).inMinutes;
      } else {
        pendingRevenue += b.totalPrice;
      }
    }

    final int bookingsCount = filteredBookings.length;
    final double commission = revenue * 0.05;
    double netRevenue = revenue - commission;

    // Format numeric values
    String revenueStr = revenue >= 1000 ? '${(revenue/1000).toStringAsFixed(1)}K' : revenue.toStringAsFixed(0); 
    String pendingStr = pendingRevenue >= 1000 ? '${(pendingRevenue/1000).toStringAsFixed(1)}K' : pendingRevenue.toStringAsFixed(0);
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
                colors: [VSPColors.accent, VSPColors.cardDarkGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(VSPRadius.lg),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(AppLocalizations.of(context)!.totalCollectedGross, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                    _buildMiniBadge(AppLocalizations.of(context)!.platformCutApplied, Colors.white.withValues(alpha: 0.15)),
                  ],
                ),
                const SizedBox(height: 8),
                Text('${revenueStr} EGP', style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 34, color: Colors.white, letterSpacing: -1, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                  ),
                  child: Row(
                    children: [
                      _buildFinanceMetric(AppLocalizations.of(context)!.netProfit, '${netStr} ${AppLocalizations.of(context)!.egCurrency}', Icons.trending_up, Colors.green),
                      Container(width: 1, height: 30, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 16)),
                      _buildFinanceMetric(AppLocalizations.of(context)!.pendingRev, '${pendingStr} ${AppLocalizations.of(context)!.egCurrency}', Icons.timer_outlined, VSPColors.warning),
                    ],
                  ),
                ),
                if (commission > 0)
                 Padding(
                   padding: const EdgeInsets.only(top: 8.0, left: 4),
                   child: Text(AppLocalizations.of(context)!.includesPlatformFee(commissionStr), style: const TextStyle(color: Colors.white60, fontSize: 10)),
                 ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),

        // 🔥 Platform Debt Highlight (From UserModel)
        Consumer<AuthProvider>(
          builder: (context, auth, _) {
            final debt = auth.userModel?.commissionDebt ?? 0.0;
            if (debt <= 0) return const SizedBox.shrink();
            
            return VSPFadeInItem(
              index: 0,
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: VSPColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(VSPRadius.md),
                  border: Border.all(color: VSPColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_rounded, color: VSPColors.error, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppLocalizations.of(context)!.platformCommission, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.error, fontWeight: FontWeight.bold)),
                          Text(AppLocalizations.of(context)!.debtCollectionNotice(debt.toStringAsFixed(0)), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.textSecondary)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: VSPColors.error.withValues(alpha: 0.5)),
                  ],
                ),
              ),
            );
          },
        ),
        
        const SizedBox(height: 20),

        // 2. Main Stats Row
        VSPFadeInItem(
          index: 1,
          child: Row(
            children: [
              Expanded(
                child: VSPStatCard(
                  label: AppLocalizations.of(context)!.hoursBookedLabel,
                  value: timeStr,
                  icon: Icons.history_toggle_off_rounded,
                ),
              ),
              const SizedBox(width: VSPSpacing.md),
              Expanded(
                child: VSPStatCard(
                  label: AppLocalizations.of(context)!.activeBookingsLabel,
                  value: bookedStr,
                  icon: Icons.confirmation_number_outlined,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(VSPRadius.sm)),
      child: Text(text, style: TextStyle(color: text.contains('VSP') || text.contains('%') || text.contains('منصة') ? Colors.white : Colors.black, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildFinanceMetric(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(color: Colors.white60, fontSize: 9, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
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
      
      final String allStadiumsKey = AppLocalizations.of(context)!.allStadiumsFilter;
      bool matchesStadium = true;
      if (_selectedStadium != allStadiumsKey && _selectedStadium != 'All Stadium') {
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
          AppLocalizations.of(context)!.noBookingsForTodayLabel,
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
                              image: (booking.hostAvatarUrl != null && booking.hostAvatarUrl!.isNotEmpty)
                                  ? DecorationImage(
                                      image: NetworkImage(booking.hostAvatarUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: (booking.hostAvatarUrl == null || booking.hostAvatarUrl!.isEmpty)
                                ? const Icon(Icons.person_outline, color: VSPColors.textSecondary, size: 20)
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  booking.playerTeamName ?? AppLocalizations.of(context)!.individualPlayerLabel, 
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  booking.bookingType == BookingType.challenge 
                                      ? AppLocalizations.of(context)!.challengeMatch 
                                      : (booking.bookingType == BookingType.team ? AppLocalizations.of(context)!.teamMatchLabel : AppLocalizations.of(context)!.playerTypeLabel), 
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
                                  booking.endTime.isBefore(now) ? AppLocalizations.of(context)!.collectedSticker : AppLocalizations.of(context)!.pendingSticker,
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
