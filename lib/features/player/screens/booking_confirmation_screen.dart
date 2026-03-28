import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import 'booking_success_screen.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../data/models.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/providers/auth_provider.dart';

import '../../../core/services/database_service.dart';

import 'payment_gateway_screen.dart';

class BookingConfirmationScreen extends StatefulWidget {
  final Stadium stadium; // Assuming we need stadium info later
  final String bookingType; // 'Personal', 'Team', 'Challenge'
  final Team? opponentTeam;

  const BookingConfirmationScreen({
    super.key,
    required this.stadium,
    this.bookingType = 'Personal',
    this.opponentTeam,
  });

  @override
  State<BookingConfirmationScreen> createState() => _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends State<BookingConfirmationScreen> {
  DateTime _selectedDate = DateTime.now();
  final List<String> _selectedTimeSlots = []; // Storing slot IDs or start times
  bool _isBallRented = false;
  bool _isPrivate = true;
  bool _isLoading = false;
  int _currentPlayers = 1;
  String? _userTeamId;

  @override
  void initState() {
    super.initState();
    if (widget.bookingType == 'Team') {
      _isPrivate = false;
    } else {
      _isPrivate = true;
    }
    _generateDynamicTimeSlots();
    _fetchUserTeam();
  }

  String? _userTeamName; // Fixed: track team name separately from user name

  Future<void> _fetchUserTeam() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.uid;
    if (userId != null) {
      final team = await DatabaseService().getUserTeam(userId);
      if (mounted) {
        setState(() {
          _userTeamId = team?.id;
          _userTeamName = team?.name; // Fix: use actual team name not user's display name
        });
      }
    }
  }
  
  // Pricing Constants
  // Pricing will be derived from stadium
  double get _slotPrice => widget.stadium.basePrice / 2;
  double get _ballPrice => widget.stadium.ballPrice > 0 ? widget.stadium.ballPrice : 0;

  // Dynamic Time Slots
  List<String> _timeSlots = [];

  void _generateDynamicTimeSlots() {
    try {
      final features = widget.stadium.features;
      String startStr = '02:00 PM';
      String endStr = '11:00 PM';

      if (features is Map) {
        if (features['workingHours'] != null) {
          startStr = features['workingHours']['start'] ?? startStr;
          endStr = features['workingHours']['end'] ?? endStr;
        }
      }

      int startMinutes = _parseTimeToMinutes(startStr);
      int endMinutes = _parseTimeToMinutes(endStr);

      // Handle overnight operating hours (e.g., 2 PM to 2 AM)
      if (endMinutes < startMinutes) {
        endMinutes += 24 * 60;
      }

      // Check for break time
      int? breakStart;
      int? breakEnd;
      if (features is Map && features['breakTime'] != null) {
        breakStart = _parseTimeToMinutes(features['breakTime']['start'] ?? '');
        breakEnd = _parseTimeToMinutes(features['breakTime']['end'] ?? '');
      }

      final List<String> slots = [];
      for (int m = startMinutes; m <= endMinutes; m += 30) {
        // Check if this slot overlaps with break time
        if (breakStart != null && breakEnd != null) {
          // Check if m (start of slot) or m+30 (end of slot) is within break
          // If break is during the slot, we skip it
          if ((m >= breakStart && m < breakEnd) || (m + 30 > breakStart && m + 30 <= breakEnd)) {
            continue;
          }
        }

        slots.add(_formatMinutesToTime(m % (24 * 60)));
      }

      setState(() {
        _timeSlots = slots;
      });
    } catch (e) {
      debugPrint('Error generating time slots: $e');
      // Fallback
      setState(() {
        _timeSlots = ['02:00 PM', '03:00 PM', '04:00 PM', '05:00 PM', '06:00 PM', '07:00 PM', '08:00 PM', '09:00 PM', '10:00 PM', '11:00 PM'];
      });
    }
  }

  int _parseTimeToMinutes(String timeStr) {
    if (timeStr.isEmpty) return 0;
    try {
      final RegExp timeRegex = RegExp(r'(\d+)(?::(\d+))?\s*(AM|PM)?', caseSensitive: false);
      final match = timeRegex.firstMatch(timeStr);
      
      if (match == null) return 0;
      
      int hour = int.parse(match.group(1)!);
      int minute = match.group(2) != null ? int.parse(match.group(2)!) : 0;
      String? period = match.group(3)?.toUpperCase();
      
      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      
      return hour * 60 + minute;
    } catch (e) {
      debugPrint('Error parsing time: $e');
      return 0;
    }
  }

  String _formatMinutesToTime(int totalMinutes) {
    int hour = totalMinutes ~/ 60;
    int minute = totalMinutes % 60;
    final period = hour >= 12 ? 'PM' : 'AM';
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  double get _totalPrice {
    double total = _selectedTimeSlots.length * _slotPrice;
    if (_isBallRented) {
      total += _ballPrice;
    }
    return total;
  }

  void _onTimeSlotTap(String slot, bool isBooked) {
    if (isBooked) return;
    setState(() {
      if (_selectedTimeSlots.contains(slot)) {
        _selectedTimeSlots.remove(slot);
      } else {
        _selectedTimeSlots.add(slot);
      }
    });
  }

  DateTime _getSlotDateTime(String slot) {
    final startMin = _parseTimeToMinutes(slot);
    return DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, startMin ~/ 60, startMin % 60);
  }

  bool _isSlotBooked(String slot, List<Booking> existingBookings) {
    final slotStartTime = _getSlotDateTime(slot);
    final slotEndTime = slotStartTime.add(const Duration(hours: 1));

    for (var booking in existingBookings) {
      // Overlap logic: (StartA < EndB) && (EndA > StartB)
      if (slotStartTime.isBefore(booking.endTime) && slotEndTime.isAfter(booking.startTime)) {
        return true;
      }
    }
    return false;
  }

  void _showCalendarModal() {
    showDialog(
      context: context,
      barrierColor: VSPColors.background.withValues(alpha: 0.8), // Dimmed background
      builder: (context) {
        DateTime tempSelectedDate = _selectedDate; // Local state for modal
        DateTime currentMonth = DateTime(_selectedDate.year, _selectedDate.month); // For page navigation

        return StatefulBuilder(
          builder: (context, setModalState) {
            // Helper to build range inputs
            Widget buildDateInput(String label, String dateText) {
              return Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    border: Border.all(color: VSPColors.divider),
                  ),
                  child: Center(
                    child: Text(
                      dateText,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: VSPColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ),
              );
            }

            return Dialog(
              backgroundColor: VSPColors.surface, // Dark grey card
              insetPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.xl)),
              child: Padding(
                padding: const EdgeInsets.all(VSPSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header: Month Navigation
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, color: VSPColors.textSecondary),
                          onPressed: () {
                            setModalState(() {
                              currentMonth = DateTime(currentMonth.year, currentMonth.month - 1);
                            });
                          },
                        ),
                        Text(
                          DateFormat('MMMM yyyy').format(currentMonth),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, color: VSPColors.textSecondary),
                          onPressed: () {
                            setModalState(() {
                              currentMonth = DateTime(currentMonth.year, currentMonth.month + 1);
                            });
                          },
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: VSPSpacing.md),
                    
                    // Date Inputs (Visual only based on screenshot)
                    Row(
                      children: [
                        buildDateInput('Start', DateFormat('MMM d, yyyy').format(tempSelectedDate)),
                        const SizedBox(width: 8),
                         const Text('-', style: TextStyle(color: VSPColors.textSecondary)),
                        const SizedBox(width: 8),
                        buildDateInput('End', DateFormat('MMM d, yyyy').format(tempSelectedDate.add(const Duration(days: 7)))),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Days of Week Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: const ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sat', 'Su']
                          .map((d) => Text(d, style: TextStyle(color: VSPColors.textSecondary, fontWeight: FontWeight.bold)))
                          .toList(),
                    ),
                    
                    const SizedBox(height: 12),

                    // Calendar Grid
                    SizedBox(
                      height: 240, 
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        // Calculate days in month roughly + offset for alignment
                        itemCount: DateTime(currentMonth.year, currentMonth.month + 1, 0).day + 
                                   (DateTime(currentMonth.year, currentMonth.month, 1).weekday - 1),
                        itemBuilder: (context, index) {
                          // Offset logic
                          final firstWeekday = DateTime(currentMonth.year, currentMonth.month, 1).weekday;
                          final dayOffset = index - (firstWeekday - 1);
                          
                          if (dayOffset < 0) return const SizedBox();

                          final day = dayOffset + 1;
                          final date = DateTime(currentMonth.year, currentMonth.month, day);
                          final isSelected = date.year == tempSelectedDate.year &&
                                             date.month == tempSelectedDate.month &&
                                             date.day == tempSelectedDate.day;

                          return InkWell(
                            onTap: () {
                              setModalState(() {
                                tempSelectedDate = date;
                              });
                            },
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected ? VSPColors.accent : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$day',
                                style: TextStyle(
                                  color: isSelected ? VSPColors.background : VSPColors.textSecondary,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Footer Buttons
                    Row(
                      children: [
                        Expanded(
                          child: PrimaryButton(
                            text: AppLocalizations.of(context)!.cancel,
                            onPressed: () => Navigator.pop(context),
                            color: VSPColors.surfaceAlt,
                            textColor: VSPColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: VSPSpacing.md),
                        Expanded(
                          child: PrimaryButton(
                            text: AppLocalizations.of(context)!.apply,
                            onPressed: () {
                              setState(() {
                                _selectedDate = tempSelectedDate;
                              });
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: VSPColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          AppLocalizations.of(context)!.bookNow,
          style: Theme.of(context).textTheme.displaySmall,
        ),
      ),
      body: Column(
        children: [
          // sticky Header Section
          Container(
            color: VSPColors.background,
            padding: const EdgeInsets.only(bottom: VSPSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date Selector Header with Calendar Icon
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md),
                  child: GestureDetector(
                    onTap: _showCalendarModal,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.xs),
                      decoration: BoxDecoration(
                        color: VSPColors.surface,
                        borderRadius: BorderRadius.circular(VSPRadius.md),
                        border: Border.all(color: VSPColors.divider),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            DateFormat('MMMM, yyyy').format(_selectedDate),
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: VSPSpacing.xs),
                          const Icon(Icons.calendar_month, color: VSPColors.textPrimary, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: VSPSpacing.md),
                
                // Horizontal Date List
                Padding(
                  padding: const EdgeInsets.only(left: VSPSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.selectDate,
                        style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: VSPSpacing.sm),
                      SizedBox(
                        height: 70,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: 14, // Next 2 weeks
                          itemBuilder: (context, index) {
                            final date = DateTime.now().add(Duration(days: index));
                            final isSelected = date.day == _selectedDate.day && date.month == _selectedDate.month;
                            
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedDate = date;
                                });
                              },
                              child: Container(
                                width: 60,
                                margin: const EdgeInsets.only(right: VSPSpacing.sm),
                                decoration: BoxDecoration(
                                  color: isSelected ? VSPColors.accent : Colors.transparent,
                                  borderRadius: BorderRadius.circular(VSPRadius.md),
                                  border: Border.all(
                                    color: isSelected ? VSPColors.accent : VSPColors.divider,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${date.day}',
                                      style: TextStyle(
                                        color: isSelected ? VSPColors.background : VSPColors.textPrimary,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      DateFormat('E').format(date).toUpperCase(),
                                      style: TextStyle(
                                        color: isSelected ? VSPColors.background : VSPColors.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Scrollable Time Slots
          Expanded(
            child: SingleChildScrollView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.selectTime,
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: VSPSpacing.md),
                  
                  StreamBuilder<List<Booking>>(
                    stream: Provider.of<BookingProvider>(context, listen: false)
                        .getBookingsForStadium(widget.stadium.id, _selectedDate),
                    builder: (context, snapshot) {
                      final existingBookings = snapshot.data ?? [];
                      
                      return Column(
                        children: List.generate(_timeSlots.isEmpty ? 0 : _timeSlots.length - 1, (index) {
                          final startTime = _timeSlots[index];
                          final endTime = _timeSlots[index + 1];
                          final slotLabel = '$startTime  -  $endTime';
                          
                          final isBooked = _isSlotBooked(startTime, existingBookings);
                          final isSelected = _selectedTimeSlots.contains(startTime);

                          // BETA READY: Prevent past bookings for today's date
                          final slotDateTime = _getSlotDateTime(startTime);
                          final isPast = _selectedDate.year == DateTime.now().year && 
                                         _selectedDate.month == DateTime.now().month && 
                                         _selectedDate.day == DateTime.now().day && 
                                         slotDateTime.isBefore(DateTime.now());

                          return GestureDetector(
                            onTap: (isBooked || isPast) ? null : () => _onTimeSlotTap(startTime, isBooked),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              alignment: Alignment.center,
                              margin: const EdgeInsets.only(bottom: VSPSpacing.sm),
                              padding: const EdgeInsets.symmetric(vertical: VSPSpacing.md, horizontal: VSPSpacing.lg),
                              decoration: BoxDecoration(
                                color: (isBooked || isPast)
                                    ? VSPColors.surface.withValues(alpha: 0.3)
                                    : (isSelected ? VSPColors.accent.withValues(alpha: 0.1) : Colors.transparent),
                                borderRadius: BorderRadius.circular(VSPRadius.md),
                                border: Border.all(
                                  color: (isBooked || isPast)
                                      ? Colors.transparent
                                      : (isSelected ? VSPColors.accent : VSPColors.divider),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (isSelected) ...[
                                    const Icon(Icons.check_circle, size: 16, color: VSPColors.accent),
                                    const SizedBox(width: 8),
                                  ],
                                  Text(
                                    slotLabel,
                                    style: TextStyle(
                                      color: (isBooked || isPast)
                                          ? VSPColors.textSecondary.withValues(alpha: 0.3)
                                          : (isSelected ? VSPColors.accent : VSPColors.textPrimary),
                                      fontSize: 16,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      decoration: (isBooked || isPast) ? TextDecoration.lineThrough : TextDecoration.none,
                                    ),
                                  ),
                                    if (isBooked) ...[
                                      const SizedBox(width: 12),
                                      Text(
                                        AppLocalizations.of(context)!.bookedStatus,
                                        style: const TextStyle(
                                          color: VSPColors.error,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ] else if (isPast) ...[
                                      const SizedBox(width: 12),
                                      Text(
                                        AppLocalizations.of(context)!.expiredStatus,
                                        style: TextStyle(
                                          color: VSPColors.textSecondary.withValues(alpha: 0.5),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                ],
                              ),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          Container(
            padding: EdgeInsets.fromLTRB(VSPSpacing.lg, VSPSpacing.lg, VSPSpacing.lg, MediaQuery.of(context).padding.bottom + VSPSpacing.lg),
            decoration: BoxDecoration(
              color: VSPColors.surfaceAlt,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(VSPRadius.xl),
                topRight: Radius.circular(VSPRadius.xl),
              ),
              boxShadow: VSPShadow.subtle,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Private Toggle (Hidden for Team Bookings to force Public)
                if (widget.bookingType != 'Team') ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.privateLabel,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Switch(
                        value: _isPrivate,
                        onChanged: (val) => setState(() => _isPrivate = val),
                        activeColor: VSPColors.accent,
                        activeTrackColor: VSPColors.accent.withValues(alpha: 0.3),
                      ),
                    ],
                  ),
                  const SizedBox(height: VSPSpacing.sm),
                ],

                // Current Players Counter (ONLY for Public Matches)
                if (widget.bookingType == 'Team') ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.currentPlayersWithYou,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            AppLocalizations.of(context)!.playersInGroupSubtitle,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          _buildCounterButton(Icons.remove, () {
                            if (_currentPlayers > 1) setState(() => _currentPlayers--);
                          }),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              '$_currentPlayers',
                              style: const TextStyle(
                                color: VSPColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          _buildCounterButton(Icons.add, () {
                            final int maxAllowed = (widget.stadium.seatsCapacity > 0) ? widget.stadium.seatsCapacity : 10;
                            if (_currentPlayers < maxAllowed) setState(() => _currentPlayers++);
                          }),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
                
                // Rent Ball Toggle
                GestureDetector(
                  onTap: () => setState(() => _isBallRented = !_isBallRented),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.rentBallLabel(_ballPrice.toInt(), AppLocalizations.of(context)!.egCurrency),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: VSPSpacing.xs),
                          Text(
                            AppLocalizations.of(context)!.payPerBallSubtitle,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
                          ),
                        ],
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _isBallRented ? VSPColors.accent : Colors.transparent,
                          borderRadius: BorderRadius.circular(VSPRadius.sm),
                          border: Border.all(
                            color: _isBallRented ? VSPColors.accent : VSPColors.textSecondary.withValues(alpha: 0.4),
                          ),
                        ),
                        child: _isBallRented
                            ? const Icon(Icons.check, size: 16, color: VSPColors.background)
                            : null,
                      ),
                    ],
                  ),
                ),
                
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: VSPSpacing.lg),
                  child: Divider(color: VSPColors.divider, thickness: 1),
                ),

                // Total Price & Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.totalPriceLabel,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
                        ),
                        Text(
                          AppLocalizations.of(context)!.priceEgp(_totalPrice.toInt()),
                          style: Theme.of(context).textTheme.displayLarge,
                        ),
                      ],
                    ),
                    const SizedBox(width: VSPSpacing.md),
                    Expanded(
                      child: PrimaryButton(
                        text: AppLocalizations.of(context)!.confirmSelections,
                        isLoading: _isLoading,
                        onPressed: (_selectedTimeSlots.isEmpty || _isLoading) ? null : () async {
                          final authProvider = Provider.of<AuthProvider>(context, listen: false);
                          final currentUserModel = authProvider.userModel;
  
                          // Build start and end times from selected slots
                          final sortedSlots = List<String>.from(_selectedTimeSlots)..sort();
                          final firstSlot = sortedSlots.first;
                          final lastSlot = sortedSlots.last;
                          
                          // Parse times
                          int parseHour(String time) {
                            final parts = time.split(':');
                            int hour = int.parse(parts[0]);
                            if (time.toLowerCase().contains('pm') && hour != 12) hour += 12;
                            return hour;
                          }
                          int parseMinute(String time) {
                            final parts = time.split(':');
                            return int.parse(parts[1].replaceAll(RegExp(r'[^0-9]'), '').substring(0, 2));
                          }
                          
                          final startHour = parseHour(firstSlot);
                          final startMinute = parseMinute(firstSlot);
                          final endHour = parseHour(lastSlot);
                          final endMinute = parseMinute(lastSlot) + 30;
                          
                          final startTime = DateTime(
                            _selectedDate.year,
                            _selectedDate.month,
                            _selectedDate.day,
                            startHour,
                            startMinute,
                          );
                          
                          // Handle duration based on number of 30-minute slots selected
                          final int totalSlotCount = _selectedTimeSlots.length;
                          final endTime = startTime.add(Duration(minutes: totalSlotCount * 30));
  
                          // Convert string bookingType to enum
                          BookingType bookingTypeEnum;
                          switch (widget.bookingType.toLowerCase()) {
                            case 'team':
                              bookingTypeEnum = BookingType.team;
                              break;
                            case 'challenge':
                              bookingTypeEnum = BookingType.challenge;
                              break;
                            default:
                              bookingTypeEnum = BookingType.personal;
                          }
  
                          // stadium.seatsCapacity actually stores "Players per Team"
                          final int trueMaxPlayers = (widget.stadium.seatsCapacity > 0) 
                              ? widget.stadium.seatsCapacity 
                              : 5; // Default to 5v5 (5 per side)
  
                          // Force it to false if the booking type is 'Team'
                          final bool isActuallyPrivate = widget.bookingType.toLowerCase() == 'team' ? false : _isPrivate;
  
                          // Create BookingDraft
                          final draft = BookingDraft(
                            stadiumId: widget.stadium.id,
                            stadiumName: widget.stadium.name,
                            stadiumImageUrl: widget.stadium.imageUrl,
                            ownerId: widget.stadium.ownerId,
                            startTime: startTime,
                            endTime: endTime,
                            bookingType: bookingTypeEnum,
                            opponentTeamId: widget.opponentTeam?.id,
                            opponentTeamName: widget.opponentTeam?.name,
                            playerTeamId: _userTeamId,
                            playerTeamName: _userTeamName, // Fix: use team name, not user display name
                            hostName: currentUserModel?.name,
                            hostAvatarUrl: currentUserModel?.profileImageUrl,
                            isPrivate: isActuallyPrivate,
                            rentBall: _isBallRented,
                            totalPrice: _totalPrice,
                            currency: 'EGP',
                            currentPlayers: _currentPlayers,
                            maxPlayers: trueMaxPlayers,
                          );
  
                          // Navigate to Payment Gateway
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PaymentGatewayScreen(bookingDraft: draft),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: VSPColors.surface,
          borderRadius: BorderRadius.circular(VSPRadius.md),
          border: Border.all(color: VSPColors.divider),
        ),
        child: Icon(icon, color: VSPColors.textPrimary, size: 20),
      ),
    );
  }
}
