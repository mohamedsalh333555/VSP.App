import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models.dart';
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
  bool _isPrivate = false;
  
  // Pricing Constants
  static const double _slotPrice = 60.0; // 60 EGP per 30 mins
  static const double _ballPrice = 20.0;

  // Mock Time Slots (30 min intervals)
  final List<String> _timeSlots = [
    '06:00 Pm', '06:30 Pm', '07:00 Pm', '07:30 Pm',
    '08:00 Pm', '08:30 Pm', '09:00 Pm', '09:30 Pm',
    '10:00 Pm', '10:30 Pm'
  ];

  double get _totalPrice {
    double total = _selectedTimeSlots.length * _slotPrice;
    if (_isBallRented) {
      total += _ballPrice;
    }
    return total;
  }

  void _onTimeSlotTap(String slot) {
    setState(() {
      if (_selectedTimeSlots.contains(slot)) {
        _selectedTimeSlots.remove(slot);
      } else {
        _selectedTimeSlots.add(slot);
      }
    });
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
                  
                  ...List.generate(_timeSlots.length - 1, (index) {
                    final startTime = _timeSlots[index];
                    final endTime = _timeSlots[index + 1];
                    final slotLabel = '$startTime   <   $endTime'; // Visual match: 06:30 Pm < 06:00 Pm (Arabic/RTL style usually puts start on right? Or just graphical arrow)
                                                                    // Image shows: 06:30 Pm < 06:00 Pm. Wait, standard english is 6:00 - 6:30.
                                                                    // The image 1 shows "06:30 Pm < 06:00 Pm" which is odd. It represents the interval.
                                                                    // I will follow the image format literally: End < Start or Start < End?
                                                                    // Image: "06:30 Pm < 06:00 Pm". This implies End Time < Start Time visually? That's confusing. 
                                                                    // Or maybe it's RTL UI? "Start < End"? 06:00 < 06:30?
                                                                    // If RTL: 06:00 > 06:30. 
                                                                    // Let's assume the text is "End Time  <  Start Time" or just stick to "Start - End".
                                                                    // I'll stick to image literal: "06:30 Pm < 06:00 Pm". 
                    
                    final isSelected = _selectedTimeSlots.contains(startTime); // Using startTime as Key

                    return GestureDetector(
                      onTap: () => _onTimeSlotTap(startTime),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF1C3A00) : Colors.transparent, // Dark Green bg for selected
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppTheme.neonGreen : AppTheme.textSecondary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              slotLabel, // I'll refine this string construction
                              style: TextStyle(
                                color: isSelected ? AppTheme.neonGreen : AppTheme.textSecondary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
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
                            'Rent Ball / +${_ballPrice.toInt()} EGP',
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
                    ElevatedButton(
                      onPressed: _selectedTimeSlots.isEmpty ? null : () {
                        // Build start and end times from selected slots
                        final sortedSlots = List<String>.from(_selectedTimeSlots)..sort();
                        final firstSlot = sortedSlots.first;
                        final lastSlot = sortedSlots.last;
                        
                        // Parse times (simplified - assumes PM times)
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
                        final endMinute = parseMinute(lastSlot) + 30; // Add 30 mins for slot duration
                        
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
                          endMinute >= 60 ? endHour + 1 : endHour,
                          endMinute >= 60 ? endMinute - 60 : endMinute,
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
                          ownerId: '', // Would come from stadium data
                          startTime: startTime,
                          endTime: endTime,
                          bookingType: bookingTypeEnum,
                          opponentTeamId: widget.opponentTeam?.id,
                          opponentTeamName: widget.opponentTeam?.name,
                          isPrivate: _isPrivate,
                          rentBall: _isBallRented,
                          totalPrice: _totalPrice,
                          currency: 'EGP',
                        );

                        // Navigate to PaymentGatewayScreen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PaymentGatewayScreen(
                              bookingDraft: draft,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.neonGreen,
                        foregroundColor: AppTheme.darkBackground,
                        disabledBackgroundColor: Colors.grey[800],
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text(
                        'Booking Confirmation',
                        style: TextStyle(fontWeight: FontWeight.bold),
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
}
