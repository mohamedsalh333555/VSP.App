import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/ui/components/vsp_stat_card.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/stadium_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../widgets/custom_date_range_picker.dart';
import '../../../data/models.dart';
import '../../../shared/widgets/vsp_fade_in_item.dart';
import '../../../shared/widgets/vsp_empty_state.dart';
import '../../../core/services/database_service.dart';
import '../../../features/player/screens/notifications_center_screen.dart';
import 'owner_bookings_screen.dart';
import 'owner_documentation_wizard.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  // --- State Variables ---
  String _selectedStadium = 'All Stadiums';
  DateTimeRange? _selectedDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  
  bool _isAllTime = false; 
  final bool _filterPendingOnly = false; 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isAuthenticated) {
        final uid = auth.firebaseUser!.uid;
        final stadiumProvider = Provider.of<StadiumProvider>(context, listen: false);
        stadiumProvider.listenToOwnerStadiums(uid);
        
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
        _selectedDateRange = null; 
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
    final auth = Provider.of<AuthProvider>(context);
    final l10n = AppLocalizations.of(context)!;
    
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
              _buildHeader(),
              const SizedBox(height: VSPSpacing.md),

              if (auth.userModel?.verificationStatus == 'rejected') ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(VSPSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.gavel, color: Colors.red, size: 28),
                      const SizedBox(width: VSPSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Verification Rejected ⚠️",
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              auth.userModel?.additionalData?['rejection_reason'] ?? 
                              auth.userModel?.additionalData?['last_warning'] ??
                              "Your documents were rejected during audit. Please click below to re-submit clear documents.",
                              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12, height: 1.4),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const OwnerDocumentationWizard()),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text("Re-upload Documents", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: VSPSpacing.md),
              ],

              if (auth.userModel?.verificationStatus == 'pending') ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(VSPSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.clock, color: Colors.orange, size: 28),
                      const SizedBox(width: VSPSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Under Review ⏳",
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              (Localizations.localeOf(context).languageCode == "ar" ? "جاري مراجعة حسابك ⏳\nيمكنك استكشاف لوحة التحكم براحتك، لكن يرجى العلم أن ملاعبك لن تظهر للاعبين ولن تستقبل حجوزات حتى يتم توثيق الأوراق من الإدارة." : "Account Under Review ⏳\nYou can explore the dashboard, but your stadiums are hidden from players and won't receive bookings until admin verification."),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: VSPColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: VSPSpacing.md),
              ],

              if (auth.userModel?.isBlocked == true) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(VSPSpacing.md),
                  decoration: BoxDecoration(
                    color: VSPColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    border: Border.all(color: VSPColors.error),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.shieldAlert, color: VSPColors.error, size: 28),
                      const SizedBox(width: VSPSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.blockedBannerTitle,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: VSPColors.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.blockedBannerSubtitle,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: VSPColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: VSPSpacing.md),
              ],

              _buildFunctionalFilters(),
              const SizedBox(height: VSPSpacing.md),

              if (auth.userModel?.isIdentityVerified == false && auth.userModel?.verificationStatus != 'pending')
                VSPFadeInItem(
                  index: 0,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const OwnerDocumentationWizard()),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: VSPSpacing.md),
                      padding: const EdgeInsets.all(VSPSpacing.md),
                      decoration: BoxDecoration(
                        color: VSPColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(VSPRadius.md),
                        border: Border.all(color: VSPColors.warning.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(LucideIcons.info, color: VSPColors.warning),
                          const SizedBox(width: VSPSpacing.sm),
                          Expanded(
                            child: Text(
                              l10n.identityPendingVerification,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.warning, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Icon(LucideIcons.chevronRight, size: 14, color: VSPColors.warning),
                        ],
                      ),
                    ),
                  ),
                ),

              _buildStatsGrid(),
              const SizedBox(height: VSPSpacing.xl),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.bookedTodayLabel,
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
                            l10n.liveBookingsForToday,
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
                            MaterialPageRoute(builder: (context) => const OwnerBookingsScreen()),
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.showMoreBtn,
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: VSPColors.accent),
                            ),
                            const SizedBox(width: 4),
                            Icon(LucideIcons.chevronDown, color: VSPColors.accent, size: 18),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
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
    final l10n = AppLocalizations.of(context)!;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${l10n.hiPrefix} ${(auth.userModel?.name ?? l10n.ownerGuestFallback).split(' ').first}',
              style: Theme.of(context).textTheme.displayMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.youHaveStadiums(stadiumsCount),
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
                    Icon(LucideIcons.bell, color: VSPColors.textPrimary, size: 24),
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
    final l10n = AppLocalizations.of(context)!;
    final String allStadiumsText = l10n.allStadiumsFilter;
    final List<String> stadiumNames = [allStadiumsText, ...stadiumProvider.stadiums.map((s) => s.name)];
    
    if (!stadiumNames.contains(_selectedStadium)) {
      _selectedStadium = allStadiumsText;
    }

    String dateDisplayText = _isAllTime 
                          ? l10n.allTimeFilter 
                          : '${DateFormat('MMM dd').format(_selectedDateRange!.start)} - ${DateFormat('MMM dd').format(_selectedDateRange!.end)}';

    return Row(
      children: [
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
                icon: Icon(LucideIcons.chevronDown, color: VSPColors.textSecondary, size: 18),
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
                         Icon(LucideIcons.chevronDown, color: VSPColors.textSecondary, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
                    LucideIcons.globe, 
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
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    
    final filteredBookings = bookingProvider.userBookings.where((booking) {
      final String allStadiumsKey = l10n.allStadiumsFilter;
      bool matchesStadium = true;
      if (_selectedStadium != allStadiumsKey && _selectedStadium != 'All Stadiums') {
        final stadium = stadiumProvider.stadiums.firstWhere(
          (s) => s.id == booking.stadiumId, 
          orElse: () => Stadium(id: '', name: 'Unknown', location: '', imageUrl: '', type: '', size: '', baths: 0, cafeteria: 0, playersPerTeam: 0, totalFieldCapacity: 0, pricePerHour: 0, area: '', ownerId: '')
        );
        matchesStadium = stadium.name == _selectedStadium;
      }
      
      bool matchesDate = _isAllTime || 
                         (booking.startTime.isAfter(_selectedDateRange!.start) && 
                          booking.startTime.isBefore(_selectedDateRange!.end.add(const Duration(days: 1))));
      
      return matchesStadium && matchesDate;
    }).toList();

    double cashRevenue = 0;
    double digitalRevenue = 0;
    int totalMinutes = 0;
    final now = DateTime.now();

    for (var b in filteredBookings) {
      if (b.paymentMethod == 'cash') {
        cashRevenue += b.totalPrice;
      } else {
        // card / wallet / online
        digitalRevenue += b.totalPrice;
      }
      if (b.endTime.isBefore(now)) {
        totalMinutes += b.endTime.difference(b.startTime).inMinutes;
      }
    }

    final double revenue = cashRevenue + digitalRevenue;
    final int bookingsCount = filteredBookings.where((b) => b.isCompleted && b.status != BookingStatus.cancelled && b.status != BookingStatus.pending).length;

    String revenueStr = revenue >= 1000 ? '${(revenue/1000).toStringAsFixed(1)}K' : revenue.toStringAsFixed(0);
    String cashStr    = cashRevenue >= 1000 ? '${(cashRevenue/1000).toStringAsFixed(1)}K' : cashRevenue.toStringAsFixed(0);
    String digitalStr = digitalRevenue >= 1000 ? '${(digitalRevenue/1000).toStringAsFixed(1)}K' : digitalRevenue.toStringAsFixed(0);
    String bookedStr = bookingsCount.toString();
    
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

    return Column(
      children: [
        VSPFadeInItem(
          index: 0,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(VSPSpacing.lg),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
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
                    Text(l10n.totalCollectedGross, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Text('$revenueStr ${l10n.egCurrency}', style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 34, color: Colors.white, letterSpacing: -1, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                  ),
                  child: Row(
                    children: [
                      _buildFinanceMetric(isArabic ? 'كاش' : 'Cash', '$cashStr ${l10n.egCurrency}', LucideIcons.banknote, Colors.green),
                      Container(width: 1, height: 30, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 16)),
                      _buildFinanceMetric(isArabic ? 'رقمي' : 'Digital', '$digitalStr ${l10n.egCurrency}', LucideIcons.creditCard, Colors.lightBlueAccent),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 20),

        VSPFadeInItem(
          index: 1,
          child: Row(
            children: [
              Expanded(
                child: VSPStatCard(
                  label: l10n.bookedHours,
                  value: timeStr,
                  icon: LucideIcons.clock,
                ),
              ),
              const SizedBox(width: VSPSpacing.md),
              Expanded(
                child: VSPStatCard(
                  label: l10n.activeBookingsLabel,
                  value: bookedStr,
                  icon: LucideIcons.ticket,
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
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
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

  Widget _buildBookedTodayList() {
    final bookingProvider = Provider.of<BookingProvider>(context);
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final stadiumProvider = Provider.of<StadiumProvider>(context);
    final l10n = AppLocalizations.of(context)!;

    final todayBookings = bookingProvider.userBookings.where((b) {
      final isToday = b.startTime.isAfter(todayStart) && b.startTime.isBefore(todayEnd);
      final String allStadiumsKey = l10n.allStadiumsFilter;
      bool matchesStadium = true;
      if (_selectedStadium != allStadiumsKey && _selectedStadium != 'All Stadiums') {
        final stadium = stadiumProvider.stadiums.firstWhere(
          (s) => s.id == b.stadiumId, 
          orElse: () => Stadium(id: '', name: 'Unknown', location: '', imageUrl: '', type: '', size: '', baths: 0, cafeteria: 0, playersPerTeam: 0, totalFieldCapacity: 0, pricePerHour: 0, area: '', ownerId: '')
        );
        matchesStadium = stadium.name == _selectedStadium;
      }
      return isToday && matchesStadium;
    }).toList();

    if (todayBookings.isEmpty) {
      return VSPEmptyState(
        icon: LucideIcons.calendar,
        title: l10n.noBookingsForTodayLabel,
        subtitle: l10n.liveBookingsForToday,
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
                                ? Icon(LucideIcons.user, color: VSPColors.textSecondary, size: 20)
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  booking.playerTeamName ?? l10n.individualPlayerLabel, 
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  booking.bookingType == BookingType.challenge 
                                      ? l10n.challengeMatch 
                                      : (booking.bookingType == BookingType.team ? l10n.teamMatchLabel : l10n.playerTypeLabel), 
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
                                  booking.endTime.isBefore(now) ? l10n.collectedSticker : l10n.pendingSticker,
                                  style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Icon(LucideIcons.moreVertical, color: VSPColors.textSecondary, size: 20),
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
        }),
      ],
    );
  }
}




