import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models.dart';
import 'booking_success_screen.dart';

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
  bool _isPrivate = false;
  bool _isLoading = false;
  int _currentPlayers = 1;

  @override
  void initState() {
    super.initState();
    _generateDynamicTimeSlots();
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
      final time = timeStr.trim().toUpperCase();
      final isPm = time.contains('PM');
      final isAm = time.contains('AM');
      
      final cleanTime = time.replaceAll('PM', '').replaceAll('AM', '').trim();
      final parts = cleanTime.split(':');
      int hour = int.parse(parts[0]);
      int minute = parts.length > 1 ? int.parse(parts[1]) : 0;

      if (isPm && hour != 12) hour += 12;
      if (isAm && hour == 12) hour = 0;
      
      return hour * 60 + minute;
    } catch (e) {
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
      barrierColor: Colors.black.withValues(alpha: 0.8), // Dimmed background
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
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[800]!),
                  ),
                  child: Center(
                    child: Text(
                      dateText,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            }

            return Dialog(
              backgroundColor: const Color(0xFF1E1E1E), // Dark grey card
              insetPadding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header: Month Navigation
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, color: Colors.white70),
                          onPressed: () {
                            setModalState(() {
                              currentMonth = DateTime(currentMonth.year, currentMonth.month - 1);
                            });
                          },
                        ),
                        Text(
                          DateFormat('MMMM yyyy').format(currentMonth),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Agency FB',
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, color: Colors.white70),
                          onPressed: () {
                            setModalState(() {
                              currentMonth = DateTime(currentMonth.year, currentMonth.month + 1);
                            });
                          },
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Date Inputs (Visual only based on screenshot)
                    Row(
                      children: [
                        buildDateInput('Start', DateFormat('MMM d, yyyy').format(tempSelectedDate)),
                        const SizedBox(width: 8),
                         const Text('-', style: TextStyle(color: Colors.grey)),
                        const SizedBox(width: 8),
                        buildDateInput('End', DateFormat('MMM d, yyyy').format(tempSelectedDate.add(const Duration(days: 7)))),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Days of Week Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sat', 'Su']
                          .map((d) => Text(d, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)))
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
                                color: isSelected ? AppTheme.neonGreen : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$day',
                                style: TextStyle(
                                  color: isSelected ? Colors.black : Colors.white70,
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
                          child: SizedBox(
                            height: 50,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey[800]!),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Text('Cancel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _selectedDate = tempSelectedDate;
                                });
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.neonGreen,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
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
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Book Now',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'Agency FB',
          ),
        ),
      ),
      body: Column(
        children: [
          // sticky Header Section
          Container(
            color: AppTheme.darkBackground,
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date Selector Header with Calendar Icon
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GestureDetector(
                    onTap: _showCalendarModal,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            DateFormat('MMMM, yyyy').format(_selectedDate),
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.calendar_month, color: AppTheme.textPrimary, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Horizontal Date List
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Date',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
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
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppTheme.neonGreen : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? AppTheme.neonGreen : AppTheme.textSecondary.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${date.day}',
                                      style: TextStyle(
                                        color: isSelected ? AppTheme.darkBackground : AppTheme.textPrimary,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      DateFormat('E').format(date).toUpperCase(),
                                      style: TextStyle(
                                        color: isSelected ? AppTheme.darkBackground : AppTheme.textSecondary,
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Time',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Agency FB',
                    ),
                  ),
                  const SizedBox(height: 16),
                  
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

                          final slotDateTime = _getSlotDateTime(startTime);
                          final isPast = slotDateTime.isBefore(DateTime.now());

                          return GestureDetector(
                            onTap: (isBooked || isPast) ? null : () => _onTimeSlotTap(startTime, isBooked),
                            child: Container(
                              alignment: Alignment.center,
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                              decoration: BoxDecoration(
                                color: (isBooked || isPast)
                                    ? Colors.grey.withValues(alpha: 0.1) 
                                    : (isSelected ? const Color(0xFF1C3A00) : Colors.transparent),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: (isBooked || isPast)
                                      ? Colors.grey.withValues(alpha: 0.2)
                                      : (isSelected ? AppTheme.neonGreen : AppTheme.textSecondary.withValues(alpha: 0.3)),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    slotLabel,
                                    style: TextStyle(
                                      color: (isBooked || isPast)
                                          ? Colors.grey.withValues(alpha: 0.4) 
                                          : (isSelected ? AppTheme.neonGreen : AppTheme.textSecondary),
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      decoration: isBooked ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                  if (isBooked) ...[
                                    const SizedBox(width: 12),
                                    const Text(
                                      'BOOKED',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ] else if (isPast) ...[
                                    const SizedBox(width: 12),
                                    const Text(
                                      'EXPIRED',
                                      style: TextStyle(
                                        color: Colors.grey,
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

          // Bottom Fixed Section (Price & Confirmation)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFF1C1C1E), // Slightly lighter dark
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Private Toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Private',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                         fontFamily: 'Agency FB',
                      ),
                    ),
                    Switch(
                      value: _isPrivate,
                      onChanged: (val) => setState(() => _isPrivate = val),
                      activeColor: AppTheme.neonGreen,
                      activeTrackColor: AppTheme.neonGreen.withValues(alpha: 0.3),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Current Players Counter (ONLY for Public Matches)
                if (widget.bookingType.toLowerCase() == 'team') ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Players with You',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Agency FB',
                            ),
                          ),
                          Text(
                            'How many players are already in your group?',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
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
                                color: AppTheme.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          _buildCounterButton(Icons.add, () {
                            if (_currentPlayers < 22) setState(() => _currentPlayers++);
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
                            'Rent Ball (+${_ballPrice.toInt()} EGP)',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 18,
                               fontWeight: FontWeight.bold,
                               fontFamily: 'Agency FB',
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Pay Per Ball At This Pitch',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _isBallRented ? AppTheme.neonGreen : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isBallRented ? AppTheme.neonGreen : AppTheme.textSecondary,
                          ),
                        ),
                        child: _isBallRented
                            ? const Icon(Icons.check, size: 16, color: AppTheme.darkBackground)
                            : null,
                      ),
                    ],
                  ),
                ),
                
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Divider(color: Colors.grey, thickness: 0.5),
                ),

                // Total Price & Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Price',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                        ),
                        Text(
                          '${_totalPrice.toInt()} EGP',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Agency FB',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (_selectedTimeSlots.isEmpty || _isLoading) ? null : () async {
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
                          
                          final endTime = DateTime(
                            _selectedDate.year,
                            _selectedDate.month,
                            _selectedDate.day,
                            endMinute >= 60 ? endHour + (endMinute ~/ 60) : endHour,
                            endMinute % 60,
                          );
  
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
                            isPrivate: _isPrivate,
                            rentBall: _isBallRented,
                            totalPrice: _totalPrice,
                            currency: 'EGP',
                            currentPlayers: _currentPlayers,
                            maxPlayers: (widget.stadium.seatsCapacity > 0) ? widget.stadium.seatsCapacity : 10,
                          );
  
                          // DIRECT BOOKING (Cash-only)
                          setState(() => _isLoading = true);
                          try {
                            final authProvider = Provider.of<AuthProvider>(context, listen: false);
                            final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
                            final userId = authProvider.currentUser?.uid ?? 'demo_user';
                            
                            // Explicitly set payment to cash
                            final cashDraft = draft.copyWith(
                              paymentMethod: 'cash',
                              paymentTransactionId: 'CASH_${DateTime.now().millisecondsSinceEpoch}',
                            );
                            
                            final booking = await bookingProvider.createBooking(cashDraft, userId);
                            
                            if (mounted) {
                              setState(() => _isLoading = false);
                              if (booking != null) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => BookingSuccessScreen(booking: booking),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(bookingProvider.errorMessage ?? 'Failed to confirm booking')),
                                );
                              }
                            }
                          } catch (e) {
                            if (mounted) {
                              setState(() => _isLoading = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.neonGreen,
                          foregroundColor: AppTheme.darkBackground,
                          disabledBackgroundColor: Colors.grey[800],
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isLoading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : const Text(
                              'Confirm Booking',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
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
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: AppTheme.neonGreen, size: 20),
      ),
    );
  }
}
