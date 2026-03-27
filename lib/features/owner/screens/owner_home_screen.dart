// Legacy / inactive screen - kept for reference
// Replaced by OwnerMainScreen & OwnerDashboardScreen
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/providers/stadium_provider.dart';
import '../../../data/models.dart';
import 'owner_profile_screen.dart';
import 'owner_booked_screen.dart';
import 'owner_cup_screen.dart';

class OwnerHomeScreen extends StatefulWidget {
  const OwnerHomeScreen({super.key});

  @override
  State<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends State<OwnerHomeScreen> {
  int _selectedIndex = 0;
  String? _selectedStadiumFilter; // null = All

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final uid = authProvider.userModel?.uid;
      if (uid != null) {
        context.read<BookingProvider>().loadOwnerBookings(uid);
        context.read<StadiumProvider>().listenToOwnerStadiums(uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VSPColors.background,
      body: Stack(
        children: [
          _buildBody(),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomNavBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        return const OwnerCupScreen();
      case 2:
        return const OwnerBookedScreen();
      case 3:
        return const OwnerProfileScreen();
      default:
        return _buildHomeContent();
    }
  }

  // ── Derived stats helpers ──────────────────────────────

  List<Booking> _getFilteredBookings(List<Booking> bookings) {
    if (_selectedStadiumFilter == null) return bookings;
    return bookings.where((b) => b.stadiumId == _selectedStadiumFilter).toList();
  }

  List<Booking> _getTodayBookings(List<Booking> bookings) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    return _getFilteredBookings(bookings)
        .where((b) =>
            b.startTime.isAfter(todayStart) &&
            b.startTime.isBefore(todayEnd) &&
            b.status == BookingStatus.confirmed)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  double _calcRevenue(List<Booking> bookings) {
    return _getFilteredBookings(bookings)
        .where((b) => b.status == BookingStatus.confirmed || b.status == BookingStatus.completed)
        .fold(0.0, (sum, b) => sum + b.totalPrice);
  }

  int _calcBookedCount(List<Booking> bookings) {
    return _getFilteredBookings(bookings)
        .where((b) => b.status == BookingStatus.confirmed || b.status == BookingStatus.completed)
        .length;
  }

  int _calcTotalHours(List<Booking> bookings) {
    return _getFilteredBookings(bookings)
        .where((b) => b.status == BookingStatus.confirmed || b.status == BookingStatus.completed)
        .fold(0, (sum, b) => sum + b.endTime.difference(b.startTime).inHours);
  }

  // ── Home Content ─────────────────────────────────────

  Widget _buildHomeContent() {
    final auth = context.watch<AuthProvider>();
    final booking = context.watch<BookingProvider>();
    final stadium = context.watch<StadiumProvider>();

    final ownerName = auth.userModel?.name ?? 'Owner';
    final allBookings = booking.userBookings;
    final stadiums = stadium.stadiums;
    final todayBookings = _getTodayBookings(allBookings);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        VSPSpacing.md,
        MediaQuery.of(context).padding.top + 16,
        VSPSpacing.md,
        MediaQuery.of(context).padding.bottom + 110,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(ownerName, stadiums.length),
          const SizedBox(height: VSPSpacing.md),
          _buildFilters(stadiums),
          const SizedBox(height: VSPSpacing.md),
          _buildStatsGrid(allBookings, stadiums.length, todayBookings.length),
          const SizedBox(height: VSPSpacing.lg),
          _buildSectionHeader('Booked Today', count: todayBookings.length),
          const SizedBox(height: VSPSpacing.sm),
          if (booking.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: VSPColors.accent),
              ),
            )
          else if (todayBookings.isEmpty)
            _buildEmptyCard('No bookings today.\nEnjoy your free day! ☕')
          else
            ...todayBookings.map((b) => _buildBookingCard(b)),
          const SizedBox(height: VSPSpacing.lg),
          _buildManualBookingButton(stadiums),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────

  Widget _buildHeader(String ownerName, int stadiumCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hi, $ownerName 👋',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 4),
            Text(
              stadiumCount == 0
                  ? 'No stadiums yet'
                  : 'You have $stadiumCount stadium${stadiumCount > 1 ? 's' : ''}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: VSPColors.textSecondary.withValues(alpha: 0.85),
                  ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: VSPColors.surfaceAlt,
            borderRadius: BorderRadius.circular(VSPRadius.md),
            border: Border.all(color: VSPColors.divider),
          ),
          child: const Icon(
            Icons.notifications_none,
            color: VSPColors.accent,
            size: 26,
          ),
        ),
      ],
    );
  }

  // ── Filters ─────────────────────────────────────────

  Widget _buildFilters(List<Stadium> stadiums) {
    return Row(
      children: [
        Expanded(
          child: _buildDropdown(stadiums),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: BoxDecoration(
              color: VSPColors.surface,
              borderRadius: BorderRadius.circular(VSPRadius.md),
              border: Border.all(color: VSPColors.divider),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 15, color: VSPColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  DateFormat('d MMM yyyy').format(DateTime.now()),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: VSPColors.textPrimary,
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(List<Stadium> stadiums) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(
          color: _selectedStadiumFilter != null ? VSPColors.accent : VSPColors.divider,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _selectedStadiumFilter,
          dropdownColor: VSPColors.surfaceAlt,
          iconEnabledColor: VSPColors.textPrimary,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: VSPColors.textPrimary),
          isExpanded: true,
          hint: Text(
            'All Stadiums',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: VSPColors.textPrimary),
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All Stadiums'),
            ),
            ...stadiums.map((s) => DropdownMenuItem<String?>(
                  value: s.id,
                  child: Text(
                    s.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                )),
          ],
          onChanged: (val) => setState(() => _selectedStadiumFilter = val),
        ),
      ),
    );
  }

  // ── Stats Grid ──────────────────────────────────────

  Widget _buildStatsGrid(List<Booking> bookings, int stadiumCount, int todayCount) {
    final revenue = _calcRevenue(bookings);
    final bookedCount = _calcBookedCount(bookings);
    final totalHours = _calcTotalHours(bookings);
    final revenueStr = revenue >= 1000
        ? '${(revenue / 1000).toStringAsFixed(1)}K'
        : revenue.toStringAsFixed(0);

    return Column(
      children: [
        // Revenue Card (Full Width)
        Container(
          padding: const EdgeInsets.all(VSPSpacing.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                VSPColors.accent.withValues(alpha: 0.15),
                VSPColors.surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            color: VSPColors.surface,
            borderRadius: BorderRadius.circular(VSPRadius.lg),
            border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: VSPColors.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.attach_money,
                    color: VSPColors.accent, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Revenue',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: VSPColors.textSecondary)),
                    Text(
                      '$revenueStr EGP',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: VSPColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: VSPColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Actual', // Changed from misleading 'Live' label
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: VSPColors.accent, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _buildStatCard(
              'Total Booked',
              bookedCount.toString(),
              Icons.check_circle_outline,
              VSPColors.success,
            )),
            const SizedBox(width: 12),
            Expanded(
                child: _buildStatCard(
              'Total Hours',
              '${totalHours}h',
              Icons.access_time,
              VSPColors.accent,
            )),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _buildStatCard(
              'Stadiums',
              stadiumCount.toString(),
              Icons.stadium_outlined,
              const Color(0xFF818CF8), // Indigo
            )),
            const SizedBox(width: 12),
            Expanded(
                child: _buildStatCard(
              'Today',
              todayCount.toString(),
              Icons.today_outlined,
              VSPColors.warning,
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(VSPSpacing.md),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: VSPColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accentColor, size: 20),
          const SizedBox(height: 10),
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: VSPColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: VSPColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  // ── Section Header ─────────────────────────────────

  Widget _buildSectionHeader(String title, {int? count}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.displaySmall,
        ),
        if (count != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: VSPColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(VSPRadius.full),
            ),
            child: Text(
              '$count bookings',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: VSPColors.accent,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
      ],
    );
  }

  // ── Booking Card ────────────────────────────────────

  Widget _buildBookingCard(Booking booking) {
    final timeStr = DateFormat('h:mm a').format(booking.startTime);
    final endStr = DateFormat('h:mm a').format(booking.endTime);
    final typeColor = _typeColor(booking.bookingType);
    final typeLabel = _typeLabel(booking.bookingType);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            VSPColors.surface,
            typeColor.withValues(alpha: 0.06),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: typeColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          // Time pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(VSPRadius.sm),
            ),
            child: Column(
              children: [
                Text(
                  timeStr,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: typeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                ),
                Container(
                  width: 1,
                  height: 12,
                  color: typeColor.withValues(alpha: 0.4),
                  margin: const EdgeInsets.symmetric(vertical: 3),
                ),
                Text(
                  endStr,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: VSPColors.textSecondary,
                        fontSize: 10,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.playerTeamName ?? booking.stadiumName,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: VSPColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.stadium_outlined,
                        size: 12, color: VSPColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        booking.stadiumName,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: VSPColors.textSecondary,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Right side: type tag + price
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(VSPRadius.full),
                ),
                child: Text(
                  typeLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: typeColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${booking.totalPrice.toStringAsFixed(0)} EGP',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: VSPColors.accent,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _typeColor(BookingType type) {
    switch (type) {
      case BookingType.challenge:
        return VSPColors.error;
      case BookingType.team:
        return const Color(0xFF818CF8);
      case BookingType.personal:
        return VSPColors.accent;
    }
  }

  String _typeLabel(BookingType type) {
    switch (type) {
      case BookingType.challenge:
        return 'Challenge';
      case BookingType.team:
        return 'Team';
      case BookingType.personal:
        return 'Personal';
    }
  }

  // ── Empty State ─────────────────────────────────────

  Widget _buildEmptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(VSPSpacing.xl),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: VSPColors.divider),
      ),
      child: Column(
        children: [
          Icon(Icons.calendar_today_outlined,
              color: VSPColors.textSecondary.withValues(alpha: 0.5), size: 40),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: VSPColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  // ── Manual Booking Button ────────────────────────

  Widget _buildManualBookingButton(List<Stadium> stadiums) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: stadiums.isEmpty
            ? null
            : () => _showManualBookingModal(stadiums),
        icon: const Icon(Icons.add_circle_outline, size: 20),
        label: const Text('Add Manual Booking'),
        style: OutlinedButton.styleFrom(
          foregroundColor: VSPColors.accent,
          side: const BorderSide(color: VSPColors.accent),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VSPRadius.md),
          ),
        ),
      ),
    );
  }

  // ── Manual Booking Modal ─────────────────────────

  void _showManualBookingModal(List<Stadium> stadiums) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ManualBookingSheet(stadiums: stadiums),
    ).then((created) {
      if (created == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Booking created successfully!'),
            backgroundColor: VSPColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(VSPRadius.sm)),
          ),
        );
      }
    });
  }

  // ── Bottom Nav ──────────────────────────────────────

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: VSPColors.background.withValues(alpha: 0.97),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(VSPRadius.xl),
          topRight: Radius.circular(VSPRadius.xl),
        ),
        boxShadow: VSPShadow.subtle,
        border: const Border(
          top: BorderSide(color: VSPColors.divider, width: 0.8),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home_filled, 'Home', 0),
              _buildNavItem(Icons.emoji_events_outlined, 'Tournaments', 1),
              _buildNavItem(Icons.calendar_today_outlined, 'Booked', 2),
              _buildNavItem(Icons.person_outline, 'Profile', 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? VSPColors.accent.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(VSPRadius.md),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? VSPColors.accent : VSPColors.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isSelected
                        ? VSPColors.accent
                        : VSPColors.textSecondary,
                    fontSize: 10,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
//  MANUAL BOOKING MODAL SHEET
// ══════════════════════════════════════════════════════

class _ManualBookingSheet extends StatefulWidget {
  final List<Stadium> stadiums;

  const _ManualBookingSheet({required this.stadiums});

  @override
  State<_ManualBookingSheet> createState() => _ManualBookingSheetState();
}

class _ManualBookingSheetState extends State<_ManualBookingSheet> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  Stadium? _selectedStadium;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay _endTime = TimeOfDay(
    hour: (TimeOfDay.now().hour + 1) % 24,
    minute: TimeOfDay.now().minute,
  );
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.stadiums.isNotEmpty) {
      _selectedStadium = widget.stadiums.first;
    }
  }

  @override
  void dispose() {
    _customerNameCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  DateTime _toDateTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: VSPColors.accent,
            onPrimary: Colors.black,
            surface: VSPColors.surfaceAlt,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: VSPColors.accent,
            onPrimary: Colors.black,
            surface: VSPColors.surfaceAlt,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStadium == null) return;

    final start = _toDateTime(_selectedDate, _startTime);
    final end = _toDateTime(_selectedDate, _endTime);

    if (!end.isAfter(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End time must be after start time'),
          backgroundColor: VSPColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final bookingProvider = context.read<BookingProvider>();
      final userId = authProvider.userModel!.uid;

      final draft = BookingDraft(
        stadiumId: _selectedStadium!.id,
        stadiumName: _selectedStadium!.name,
        stadiumImageUrl: _selectedStadium!.imageUrl,
        ownerId: _selectedStadium!.ownerId,
        startTime: start,
        endTime: end,
        bookingType: BookingType.personal,
        playerTeamName: _customerNameCtrl.text.trim(),
        isPrivate: true,
        rentBall: false,
        totalPrice: double.tryParse(_priceCtrl.text) ?? 0.0,
        paymentMethod: 'cash',
        currentPlayers: 1,
        maxPlayers: 10,
      );

      final booking = await bookingProvider.createBooking(draft, userId);

      setState(() => _isSubmitting = false);

      if (mounted) {
        Navigator.of(context).pop(booking != null);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: VSPColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + bottomPad),
      decoration: const BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: VSPColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: VSPColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(VSPRadius.sm),
                ),
                child: const Icon(Icons.add_circle_outline,
                    color: VSPColors.accent, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                'Manual Booking',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: VSPColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Form(
            key: _formKey,
            child: Column(
              children: [
                // Stadium Picker
                _buildLabel('Stadium'),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: VSPColors.inputFill,
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    border: Border.all(color: VSPColors.divider),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Stadium>(
                      value: _selectedStadium,
                      isExpanded: true,
                      dropdownColor: VSPColors.surfaceAlt,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: VSPColors.textPrimary,
                          ),
                      items: widget.stadiums
                          .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s.name,
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedStadium = val),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Customer Name
                _buildLabel('Customer Name'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _customerNameCtrl,
                  style: const TextStyle(color: VSPColors.textPrimary),
                  decoration: _inputDecoration('e.g. Ahmed Mohamed'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                // Date Row
                _buildLabel('Date'),
                const SizedBox(height: 6),
                _buildTappableField(
                  icon: Icons.calendar_month_outlined,
                  text: DateFormat('EEE, d MMM yyyy').format(_selectedDate),
                  onTap: _pickDate,
                ),
                const SizedBox(height: 16),

                // Time Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Start Time'),
                          const SizedBox(height: 6),
                          _buildTappableField(
                            icon: Icons.schedule,
                            text: _startTime.format(context),
                            onTap: () => _pickTime(true),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('End Time'),
                          const SizedBox(height: 6),
                          _buildTappableField(
                            icon: Icons.schedule_outlined,
                            text: _endTime.format(context),
                            onTap: () => _pickTime(false),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Price
                _buildLabel('Price (EGP)'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _priceCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: VSPColors.textPrimary),
                  decoration: _inputDecoration('e.g. 150'),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (double.tryParse(v) == null) return 'Invalid number';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Submit
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    text: 'Confirm Booking',
                    isLoading: _isSubmitting,
                    onPressed: _isSubmitting ? null : _submit,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: VSPColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
    );
  }

  Widget _buildTappableField(
      {required IconData icon,
      required String text,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: VSPColors.inputFill,
          borderRadius: BorderRadius.circular(VSPRadius.md),
          border: Border.all(color: VSPColors.divider),
        ),
        child: Row(
          children: [
            Icon(icon, color: VSPColors.accent, size: 16),
            const SizedBox(width: 10),
            Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: VSPColors.textPrimary,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: VSPColors.textSecondary.withValues(alpha: 0.5)),
      filled: true,
      fillColor: VSPColors.inputFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VSPRadius.md),
        borderSide: const BorderSide(color: VSPColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VSPRadius.md),
        borderSide: const BorderSide(color: VSPColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VSPRadius.md),
        borderSide: const BorderSide(color: VSPColors.accent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    );
  }
}
