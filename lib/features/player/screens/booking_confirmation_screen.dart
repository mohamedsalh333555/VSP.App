import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../data/models.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/team_repository.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/utils/app_date_formatter.dart';
import '../../../core/utils/vsp_feedback.dart';
import 'booking_success_screen.dart';
import 'payment_gateway_screen.dart';

class TimeSlotItem {
  final String startTime;
  final String endTime;
  final String key;
  final int startMinutes;

  TimeSlotItem({
    required this.startTime,
    required this.endTime,
    required this.key,
    required this.startMinutes,
  });
}

class BookingConfirmationScreen extends StatefulWidget {
  final Stadium stadium; 
  final DateTime? selectedDate;
  final String bookingType; // 'Personal', 'Team', 'Challenge'
  final Team? opponentTeam;

  const BookingConfirmationScreen({
    super.key,
    required this.stadium,
    this.selectedDate,
    this.bookingType = 'Personal',
    this.opponentTeam,
  });

  @override
  State<BookingConfirmationScreen> createState() => _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends State<BookingConfirmationScreen> {
  late DateTime _selectedDate;
  final List<String> _selectedTimeSlots = []; 
  bool _isBallRented = false;
  bool _isPrivate = true;
  bool _isLoading = false;
  final int _currentPlayers = 1;
  int _initialPlayersCount = 1;
  String? _userTeamId;
  String? _userTeamName;
  List<TimeSlotItem> _timeSlots = [];

  DateTime get _operationalBaseDate {
    final now = DateTime.now();
    final openMin = _parseTimeToMinutes(widget.stadium.openingTime);
    final closeMin = _parseTimeToMinutes(widget.stadium.closingTime);
    final openH = openMin ~/ 60;
    final closeH = closeMin ~/ 60;
    if (openH > closeH && now.hour < closeH) {
      final prev = now.subtract(const Duration(days: 1));
      return DateTime(prev.year, prev.month, prev.day);
    }
    return DateTime(now.year, now.month, now.day);
  }

  bool get _isOpenJoin {
    final bType = widget.bookingType.toLowerCase().replaceAll(' ', '').replaceAll('_', '');
    return bType == 'openjoin' || bType == 'openjoinmatch';
  }

  bool get _isChallenge {
    final bType = widget.bookingType.toLowerCase().replaceAll(' ', '').replaceAll('_', '');
    return bType == 'challenge' || bType == 'challengematch';
  }

  bool _isSlotsInitialized = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate ?? _operationalBaseDate;
    if (_isOpenJoin) {
      _isPrivate = false;
    } else {
      _isPrivate = true;
    }
    _fetchUserTeam();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isSlotsInitialized) {
      _isSlotsInitialized = true;
      _generateDynamicTimeSlots();
    }
  }

  Future<void> _fetchUserTeam() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.uid;
    if (userId != null) {
      final team = await TeamRepository().getUserTeam(userId);
      if (mounted) {
        setState(() {
          _userTeamId = team?.id;
          _userTeamName = team?.name; 
        });
      }
    }
  }
  
  double get _slotPrice => widget.stadium.basePrice / 2;
  double get _ballPrice => widget.stadium.ballPrice > 0 ? widget.stadium.ballPrice : 0;

  int _parseTimeToMinutes(String timeStr) {
    return AppDateFormatter.parseTimeToMinutes(timeStr);
  }

  String _formatMinutesToTime(int totalMinutes, bool isArabic) {
    return AppDateFormatter.formatMinutesToTime(totalMinutes, isArabic);
  }

  void _generateDynamicTimeSlots() {
    try {
      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
      final features = widget.stadium.features;
      String startStr = '';
      String endStr = ''; 

      if (features is Map && features['workingHours'] is Map) {
        startStr = features['workingHours']['start']?.toString() ?? '';
        endStr = features['workingHours']['end']?.toString() ?? '';
      }
      if (startStr.isEmpty) startStr = widget.stadium.openingTime;
      if (endStr.isEmpty) endStr = widget.stadium.closingTime;
      if (startStr.isEmpty) startStr = '04:00 PM';
      if (endStr.isEmpty) endStr = '03:00 AM';

      int startMinutes = _parseTimeToMinutes(startStr);
      int endMinutes = _parseTimeToMinutes(endStr);

      if (endMinutes <= startMinutes) {
        endMinutes += 24 * 60; 
      }

      int getCumulativeMinutes(String timeStr) {
        if (timeStr.trim().isEmpty) return -1;
        int min = _parseTimeToMinutes(timeStr);
        if (min < startMinutes) {
          min += 24 * 60; 
        }
        return min;
      }

      int? bStart;
      int? bEnd;
      if (features is Map && features['breakTime'] != null) {
        final s = features['breakTime']['start']?.toString() ?? '';
        final e = features['breakTime']['end']?.toString() ?? '';
        if (s.isNotEmpty && e.isNotEmpty) {
          bStart = getCumulativeMinutes(s);
          bEnd = getCumulativeMinutes(e);
        }
      }

      final List<TimeSlotItem> slots = [];
      for (int m = startMinutes; m < endMinutes; m += 30) {
        final slotStart = m;
        final slotEnd = m + 30;

        // Skip slot if it overlaps with stadium break shift
        if (bStart != null && bEnd != null && bStart != -1 && bEnd != -1) {
          if (slotStart < bEnd && slotEnd > bStart) {
            continue; 
          }
        }

        final startTimeFormatted = _formatMinutesToTime(slotStart % (24 * 60), isArabic);
        final endTimeFormatted = _formatMinutesToTime(slotEnd % (24 * 60), isArabic);
        final rawKey = _formatMinutesToTime(slotStart % (24 * 60), false);

        slots.add(TimeSlotItem(
          startTime: startTimeFormatted,
          endTime: endTimeFormatted,
          key: rawKey,
          startMinutes: slotStart,
        ));
      }

      setState(() {
        _timeSlots = slots;
      });
    } catch (e) {
      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
      setState(() {
        _timeSlots = List.generate(8, (i) {
          final m = (14 + i) * 60;
          return TimeSlotItem(
            startTime: _formatMinutesToTime(m, isArabic),
            endTime: _formatMinutesToTime(m + 30, isArabic),
            key: _formatMinutesToTime(m, false),
            startMinutes: m,
          );
        });
      });
    }
  }

  double get _totalPrice {
    double total = _selectedTimeSlots.length * _slotPrice;
    if (_isBallRented) {
      total += _ballPrice;
    }
    return total;
  }

  DateTime _getSlotDateTime(String slot) {
    int startMin = _parseTimeToMinutes(slot);
    String openStr = widget.stadium.openingTime;
    String closeStr = widget.stadium.closingTime;
    final features = widget.stadium.features;
    if ((openStr.isEmpty || closeStr.isEmpty) && features is Map && features['workingHours'] != null) {
      openStr = openStr.isNotEmpty ? openStr : (features['workingHours']['start'] ?? '');
      closeStr = closeStr.isNotEmpty ? closeStr : (features['workingHours']['end'] ?? '');
    }
    int openMin = _parseTimeToMinutes(openStr);
    int closeMin = _parseTimeToMinutes(closeStr);
    
    DateTime date = _selectedDate;
    final bool isOvernightShift = (closeMin <= openMin && openMin > 0);
    if (isOvernightShift && startMin < openMin) {
      date = date.add(const Duration(days: 1));
    } else if (!isOvernightShift && openMin > 12 * 60 && startMin < openMin) {
      date = date.add(const Duration(days: 1));
    }
    return DateTime(date.year, date.month, date.day, startMin ~/ 60, startMin % 60);
  }

  bool _isSlotBooked(String slotKey, List<Booking> existingBookings) {
    final slotStartTime = _getSlotDateTime(slotKey).toUtc();
    final slotEndTime = slotStartTime.add(const Duration(minutes: 30));
    for (var booking in existingBookings) {
      final bStart = booking.startTime.toUtc();
      final bEnd = booking.endTime.toUtc();
      if (slotStartTime.isBefore(bEnd) && slotEndTime.isAfter(bStart)) {
        return true;
      }
    }
    return false;
  }

  void _onTimeSlotTap(String slotKey, List<Booking> existingBookings) {
    setState(() {
      final isAlreadySelected = _selectedTimeSlots.contains(slotKey);
      final idxTapped = _timeSlots.indexWhere((s) => s.key == slotKey);

      if (isAlreadySelected) {
        if (_selectedTimeSlots.length <= 2) {
          _selectedTimeSlots.clear();
          return;
        }
      }

      if (idxTapped == -1) return;

      if (_selectedTimeSlots.isEmpty || isAlreadySelected) {
        _selectSlotWithAutoConsecutive(idxTapped, existingBookings);
      } else if (_selectedTimeSlots.length == 1) {
        final first = _selectedTimeSlots.first;
        final idxFirst = _timeSlots.indexWhere((s) => s.key == first);
        if (idxFirst == -1) {
          _selectSlotWithAutoConsecutive(idxTapped, existingBookings);
          return;
        }

        final startIdx = idxFirst < idxTapped ? idxFirst : idxTapped;
        final endIdx = idxFirst > idxTapped ? idxFirst : idxTapped;
        
        bool hasInvalidSlot = false;
        final List<String> tempRange = [];
        for (int i = startIdx; i <= endIdx; i++) {
          if (i > startIdx) {
            final prevSlot = _timeSlots[i - 1];
            final currSlot = _timeSlots[i];
            if (currSlot.startMinutes != prevSlot.startMinutes + 30) {
              hasInvalidSlot = true; // Break time gap detected!
              break;
            }
          }
          final checkItem = _timeSlots[i];
          final slotDateTime = _getSlotDateTime(checkItem.key);
          final isPast = slotDateTime.isBefore(DateTime.now());
          final isBooked = _isSlotBooked(checkItem.key, existingBookings);
          
          if (isPast || isBooked) {
            hasInvalidSlot = true;
            break;
          }
          tempRange.add(checkItem.key);
        }
        
        if (hasInvalidSlot) {
          _selectSlotWithAutoConsecutive(idxTapped, existingBookings);
        } else {
          _selectedTimeSlots.clear();
          _selectedTimeSlots.addAll(tempRange);
        }
      } else {
        _selectSlotWithAutoConsecutive(idxTapped, existingBookings);
      }
    });
  }

  void _selectSlotWithAutoConsecutive(int startIdx, List<Booking> existingBookings) {
    _selectedTimeSlots.clear();
    final startSlot = _timeSlots[startIdx];
    _selectedTimeSlots.add(startSlot.key);

    if (startIdx + 1 < _timeSlots.length) {
      final nextSlot = _timeSlots[startIdx + 1];
      if (nextSlot.startMinutes == startSlot.startMinutes + 30) {
        final nextDateTime = _getSlotDateTime(nextSlot.key);
        final isPast = nextDateTime.isBefore(DateTime.now());
        final isBooked = _isSlotBooked(nextSlot.key, existingBookings);
        if (!isPast && !isBooked) {
          _selectedTimeSlots.add(nextSlot.key);
        }
      }
    }
  }

  void _showCalendarModal() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierColor: VSPColors.background.withValues(alpha: 0.8),
      builder: (context) {
        DateTime tempSelectedDate = _selectedDate;
        DateTime currentMonth = DateTime(_selectedDate.year, _selectedDate.month);
        final DateTime todayMonth = DateTime(DateTime.now().year, DateTime.now().month);
        final DateTime maxMonth = DateTime(DateTime.now().year, DateTime.now().month + 3);

        return StatefulBuilder(
          builder: (context, setModalState) {
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
              backgroundColor: VSPColors.surface,
              insetPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.xl)),
              child: Padding(
                padding: const EdgeInsets.all(VSPSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(Iconsax.arrow_left_2_copy, color: currentMonth.isAfter(todayMonth) ? VSPColors.textSecondary : VSPColors.textSecondary.withValues(alpha: 0.25)),
                          onPressed: currentMonth.isAfter(todayMonth) ? () { setModalState(() { currentMonth = DateTime(currentMonth.year, currentMonth.month - 1); }); } : null,
                        ),
                        Text(DateFormat('MMMM yyyy', Localizations.localeOf(context).toString()).format(currentMonth), style: Theme.of(context).textTheme.titleLarge),
                        IconButton(
                          icon: Icon(Iconsax.arrow_right_1_copy, color: currentMonth.isBefore(maxMonth) ? VSPColors.textSecondary : VSPColors.textSecondary.withValues(alpha: 0.25)),
                          onPressed: currentMonth.isBefore(maxMonth) ? () { setModalState(() { currentMonth = DateTime(currentMonth.year, currentMonth.month + 1); }); } : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: VSPSpacing.md),
                    Row(
                      children: [
                        buildDateInput('Start', DateFormat('MMM d, yyyy', Localizations.localeOf(context).toString()).format(tempSelectedDate)),
                        const SizedBox(width: 8), const Text('-', style: TextStyle(color: VSPColors.textSecondary)), const SizedBox(width: 8),
                        buildDateInput('End', DateFormat('MMM d, yyyy', Localizations.localeOf(context).toString()).format(tempSelectedDate.add(const Duration(days: 7)))),
                      ],
                    ),
                    const SizedBox(height: 36),
                    SizedBox(
                      height: 240, 
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 8, crossAxisSpacing: 8),
                        itemCount: DateTime(currentMonth.year, currentMonth.month + 1, 0).day + (DateTime(currentMonth.year, currentMonth.month, 1).weekday - 1),
                        itemBuilder: (context, index) {
                          final firstWeekday = DateTime(currentMonth.year, currentMonth.month, 1).weekday;
                          final dayOffset = index - (firstWeekday - 1);
                          if (dayOffset < 0) return const SizedBox();
                          final day = dayOffset + 1;
                          final date = DateTime(currentMonth.year, currentMonth.month, day);
                          final isSelected = date.year == tempSelectedDate.year && date.month == tempSelectedDate.month && date.day == tempSelectedDate.day;
                          final isPastDate = date.isBefore(DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0));

                          return InkWell(
                            onTap: isPastDate ? null : () { setModalState(() { tempSelectedDate = date; }); },
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: isSelected ? VSPColors.accent : (isPastDate ? VSPColors.surfaceAlt : Colors.transparent), shape: BoxShape.circle),
                              child: Text('$day', style: TextStyle(color: isSelected ? VSPColors.background : (isPastDate ? VSPColors.textSecondary.withValues(alpha: 0.5) : VSPColors.textSecondary), fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(child: PrimaryButton(text: l10n.cancel, onPressed: () => Navigator.pop(context), color: VSPColors.surfaceAlt, textColor: VSPColors.textPrimary)),
                        const SizedBox(width: VSPSpacing.md),
                        Expanded(child: PrimaryButton(text: l10n.apply, onPressed: () { setState(() { _selectedDate = tempSelectedDate; }); Navigator.pop(context); })),
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
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            isArabic ? Iconsax.arrow_right_1_copy : Iconsax.arrow_left_2_copy,
            color: VSPColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(l10n.bookNow, style: Theme.of(context).textTheme.displaySmall),
      ),
      body: Column(
        children: [
          Container(
            color: VSPColors.background,
            padding: const EdgeInsets.only(bottom: VSPSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md),
                  child: GestureDetector(
                    onTap: _showCalendarModal,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.xs),
                      decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(VSPRadius.md), border: Border.all(color: VSPColors.divider)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(DateFormat('MMMM, yyyy', Localizations.localeOf(context).toString()).format(_selectedDate), style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(width: VSPSpacing.xs),
                          const Icon(Iconsax.calendar_1_copy, color: VSPColors.textPrimary, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: VSPSpacing.md),
                Padding(
                  padding: const EdgeInsets.only(left: VSPSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.selectDate, style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12)),
                      const SizedBox(height: VSPSpacing.sm),
                      SizedBox(
                        height: 70,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: 14, 
                          itemBuilder: (context, index) {
                            final date = _operationalBaseDate.add(Duration(days: index));
                            final isSelected = date.day == _selectedDate.day && date.month == _selectedDate.month;
                            return GestureDetector(
                              onTap: () { setState(() { _selectedDate = date; }); },
                              child: Container(
                                width: 60, margin: const EdgeInsets.only(right: VSPSpacing.sm),
                                decoration: BoxDecoration(color: isSelected ? VSPColors.accent : Colors.transparent, borderRadius: BorderRadius.circular(VSPRadius.md), border: Border.all(color: isSelected ? VSPColors.accent : VSPColors.divider)),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('${date.day}', style: TextStyle(color: isSelected ? VSPColors.background : VSPColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                                    Text(DateFormat('E', Localizations.localeOf(context).toString()).format(date).toUpperCase(), style: TextStyle(color: isSelected ? VSPColors.background : VSPColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
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
          
          // FIXED BODY: Holds the full, scrollable flow (Time slots + Options + Prices)
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.selectTime, style: Theme.of(context).textTheme.displaySmall),
                  StreamBuilder<List<Booking>>(
                    stream: Provider.of<BookingProvider>(context, listen: false).getBookingsForStadium(widget.stadium.id, _selectedDate),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Column(
                              children: [
                                CircularProgressIndicator(color: VSPColors.accent, strokeWidth: 2.5),
                                SizedBox(height: 12),
                                Text(
                                  'جاري قراءة وتحديث الساعات المتاحة...',
                                  style: TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      final existingBookings = snapshot.data ?? [];
                      final now = DateTime.now();
                      final bool isToday = _selectedDate.year == now.year && _selectedDate.month == now.month && _selectedDate.day == now.day;

                      String? firstUpcomingSlotKey;
                      if (isToday) {
                        for (final item in _timeSlots) {
                          final dt = _getSlotDateTime(item.key);
                          final booked = _isSlotBooked(item.key, existingBookings);
                          if (dt.isAfter(now) && !booked) {
                            firstUpcomingSlotKey = item.key;
                            break;
                          }
                        }
                      }

                      return Column(
                        children: List.generate(_timeSlots.length, (index) {
                          final slotItem = _timeSlots[index];
                          final isBooked = _isSlotBooked(slotItem.key, existingBookings);
                          final isSelected = _selectedTimeSlots.contains(slotItem.key);
                          final slotDateTime = _getSlotDateTime(slotItem.key);
                          final slotEndDateTime = slotDateTime.add(const Duration(minutes: 30));
                          final isPast = slotDateTime.isBefore(now);
                          final isCurrentOngoing = isToday && now.isAfter(slotDateTime) && now.isBefore(slotEndDateTime);
                          final isNextAvailable = isToday && slotItem.key == firstUpcomingSlotKey;

                          final isOvernightSlot = slotItem.startMinutes >= 1440;
                          final bool isFirstOvernightSlot = isOvernightSlot && (index == 0 || _timeSlots[index - 1].startMinutes < 1440);
                          final String nextDayName = isOvernightSlot
                              ? DateFormat('EEEE', Localizations.localeOf(context).toString()).format(slotDateTime)
                              : '';

                          final slotWidget = GestureDetector(
                            onTap: (isBooked || isPast) ? null : () => _onTimeSlotTap(slotItem.key, existingBookings),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              alignment: Alignment.center,
                              margin: const EdgeInsets.only(bottom: VSPSpacing.sm),
                              padding: const EdgeInsets.symmetric(vertical: VSPSpacing.md, horizontal: VSPSpacing.lg),
                              decoration: BoxDecoration(
                                color: isBooked 
                                    ? Colors.red.withValues(alpha: 0.08)
                                    : (isPast
                                        ? VSPColors.surface.withValues(alpha: 0.3)
                                        : (isSelected ? VSPColors.accent.withValues(alpha: 0.18) : Colors.transparent)),
                                borderRadius: BorderRadius.circular(VSPRadius.md),
                                border: Border.all(
                                  color: isBooked
                                      ? Colors.red.withValues(alpha: 0.3)
                                      : (isPast
                                          ? Colors.transparent
                                          : (isSelected ? VSPColors.accent : (isNextAvailable ? VSPColors.accent.withValues(alpha: 0.5) : VSPColors.divider))),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (isSelected) ...[const Icon(Iconsax.tick_circle_copy, size: 18, color: VSPColors.accent), const SizedBox(width: 8)],
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        slotItem.startTime,
                                        style: TextStyle(
                                          color: isBooked
                                              ? Colors.redAccent.withValues(alpha: 0.7)
                                              : (isPast
                                                  ? VSPColors.textSecondary.withValues(alpha: 0.4)
                                                  : (isSelected ? Colors.white : VSPColors.textPrimary)),
                                          fontSize: 15,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                          decoration: (isBooked || isPast) ? TextDecoration.lineThrough : TextDecoration.none,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        child: Text(
                                          '–',
                                          style: TextStyle(
                                            color: isBooked 
                                                ? Colors.redAccent.withValues(alpha: 0.7)
                                                : (isSelected ? VSPColors.accent : VSPColors.textSecondary),
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        slotItem.endTime,
                                        style: TextStyle(
                                          color: isBooked
                                              ? Colors.redAccent.withValues(alpha: 0.7)
                                              : (isPast
                                                  ? VSPColors.textSecondary.withValues(alpha: 0.4)
                                                  : (isSelected ? Colors.white : VSPColors.textPrimary)),
                                          fontSize: 15,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                          decoration: (isBooked || isPast) ? TextDecoration.lineThrough : TextDecoration.none,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (isBooked) ...[
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Iconsax.lock_copy, size: 12, color: Colors.redAccent),
                                          const SizedBox(width: 4),
                                          Text(
                                            isArabic ? '🔒 محجوز' : '🔒 Booked',
                                            style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ] else if (isCurrentOngoing) ...[
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.amber),
                                      ),
                                      child: Text(
                                        isArabic ? '⚡ الآن' : '⚡ NOW',
                                        style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ] else if (isNextAvailable) ...[
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: VSPColors.accent.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.5)),
                                      ),
                                      child: Text(
                                        isArabic ? '⚡ الأقرب' : '⚡ Next Available',
                                        style: const TextStyle(color: VSPColors.accent, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ] else if (isPast) ...[
                                    const SizedBox(width: 12),
                                    Text(
                                      isArabic ? 'منقضي' : 'Past',
                                      style: TextStyle(color: VSPColors.textSecondary.withValues(alpha: 0.4), fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );

                          if (isFirstOvernightSlot) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 16, bottom: 10, right: 4, left: 4),
                                  child: Text(
                                    isArabic ? 'بعد منتصف الليل ($nextDayName)' : 'After Midnight ($nextDayName)',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                slotWidget,
                              ],
                            );
                          }

                          return slotWidget;
                        }),
                      );
                    },
                  ),

                  // ── Financial & Debt Calculations Summary Panel ──
                  Builder(builder: (context) {
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    final isCashLocked = (authProvider.userModel?.noShowCount ?? 0) >= 2;
                    final deposit = widget.stadium.depositAmount;

                    if (isCashLocked) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: VSPColors.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(VSPRadius.md),
                              border: Border.all(color: VSPColors.accent.withValues(alpha: 0.4)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Iconsax.card_pos_copy, color: VSPColors.accent, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      isArabic ? "الدفع الإلكتروني المقترح 💳" : "Smart Online Payment 💳",
                                      style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  isArabic
                                      ? "الحجز النقدي مقيد مؤقتاً - ادفع أونلاين بالفيزا أو المحفظة لتأكيد مكانك فوراً واستعادة تقييمك 💳"
                                      : "Cash booking is temporarily restricted - Pay online via card or mobile wallet to confirm your spot immediately and restore your rating 💳",
                                  style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: VSPSpacing.md),
                        ],
                      );
                    }

                    if (deposit > 0 && widget.stadium.needsDeposit) {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(VSPRadius.md), border: Border.all(color: VSPColors.divider)),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(isArabic ? 'عربون الحجز المطلوبة' : 'Upfront Deposit Required', style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 13)),
                                Text('${deposit.toInt()} ${l10n.egCurrency}', style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(isArabic ? 'المتبقي عند الملعب' : 'Remaining at Pitch', style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12)),
                                Text('${(_totalPrice - deposit).clamp(0, double.infinity).toInt()} ${l10n.egCurrency}', style: const TextStyle(color: VSPColors.textPrimary, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }),

                  const SizedBox(height: VSPSpacing.xl),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomOverlay(context, l10n, isArabic),
    );
  }

  Widget _buildBottomOverlay(BuildContext context, AppLocalizations l10n, bool isArabic) {
    final hasBallOption = widget.stadium.hasBall || _ballPrice > 0;
    final deposit = widget.stadium.depositAmount;
    final isSlotSelected = _selectedTimeSlots.isNotEmpty;

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        bottomPadding > 0 ? bottomPadding + 14 : 20,
      ),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        border: const Border(top: BorderSide(color: VSPColors.divider, width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Row 1: Private Toggle (Only shown for OpenJoin gathering matches - FIRST) ──
          if (_isOpenJoin) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isArabic ? 'حجز خاص' : 'Private',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                Transform.scale(
                  scale: 0.85,
                  child: Switch(
                    value: _isPrivate,
                    activeColor: Colors.black,
                    activeTrackColor: VSPColors.accent,
                    inactiveThumbColor: Colors.grey,
                    inactiveTrackColor: VSPColors.surfaceAlt,
                    trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                    onChanged: (val) {
                      setState(() => _isPrivate = val);
                      VSPFeedback.showInfo(
                        context,
                        _isPrivate
                            ? (isArabic ? 'حجز خاص: تقتصر المباراة على فريقك فقط.' : 'Private Booking: Exclusive for your team only.')
                            : (isArabic ? 'حجز عام: ستظهر مباراتك في الخريطة ليتمكن باقي اللاعبين من الانضمام!' : 'Public Booking: Visible on map for players to join!'),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // ── Row 2: Available Players With You Counter (Only shown for OpenJoin gathering matches - SECOND) ──
          if (_isOpenJoin) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'عدد اللاعبين المتوفرين معك' : 'Players With You',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isArabic ? 'حدد عدد أصحابك القادمين معك لتكملة سعة الملعب' : 'Specify how many friends you bring with you',
                      style: const TextStyle(
                        color: VSPColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    color: VSPColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    border: Border.all(color: VSPColors.borderLight),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Iconsax.minus_copy, size: 16, color: Colors.white),
                        onPressed: _initialPlayersCount > 1 
                            ? () {
                                HapticFeedback.selectionClick();
                                setState(() => _initialPlayersCount--);
                              } 
                            : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          '$_initialPlayersCount',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Iconsax.add_copy, size: 16, color: Colors.white),
                        onPressed: _initialPlayersCount < widget.stadium.totalFieldCapacity 
                            ? () {
                                HapticFeedback.selectionClick();
                                setState(() => _initialPlayersCount++);
                              } 
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // ── Option Card: Rent Ball Add-on ──
          if (hasBallOption) ...[
            GestureDetector(
              onTap: () => setState(() => _isBallRented = !_isBallRented),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _isBallRented
                      ? VSPColors.accent.withValues(alpha: 0.12)
                      : VSPColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(VSPRadius.lg),
                  border: Border.all(
                    color: _isBallRented ? VSPColors.accent : VSPColors.divider,
                    width: _isBallRented ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isArabic
                                ? 'إيجار كرة / ${_ballPrice.toInt()} ج.م'
                                : 'Ball / ${_ballPrice.toInt()}eg',
                            style: TextStyle(
                              color: _isBallRented ? Colors.white : VSPColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isArabic
                                ? 'دفع رسوم إيجار الكرة في هذا الملعب'
                                : 'Pay Per Ball At This Pitch',
                            style: const TextStyle(
                              color: VSPColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isBallRented ? VSPColors.accent : Colors.transparent,
                        border: Border.all(
                          color: _isBallRented ? VSPColors.accent : Colors.grey.shade600,
                          width: 1.5,
                        ),
                      ),
                      child: _isBallRented
                          ? const Icon(Icons.check, size: 16, color: Colors.black)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // ── Row 3: Price & Spacious Booking Confirmation Button ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isArabic ? 'السعر الإجمالي' : 'Total Price',
                    style: const TextStyle(
                      color: VSPColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '${_totalPrice.toInt()} ${isArabic ? "ج.م" : "eg"}',
                        style: TextStyle(
                          color: isSlotSelected ? VSPColors.accent : Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (deposit > 0 && widget.stadium.needsDeposit) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: VSPColors.warning.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isArabic ? 'عربون ${deposit.toInt()}' : 'Dep ${deposit.toInt()}',
                            style: const TextStyle(color: VSPColors.warning, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSlotSelected ? VSPColors.accent : VSPColors.surfaceAlt,
                      foregroundColor: isSlotSelected ? Colors.black : Colors.grey.shade500,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(VSPRadius.lg),
                      ),
                    ),
                    onPressed: (!isSlotSelected || _isLoading) ? null : () async {
                      setState(() => _isLoading = true);
                      final authProvider = Provider.of<AuthProvider>(context, listen: false);
                      final currentUserModel = authProvider.userModel;
                      if (currentUserModel == null) { setState(() => _isLoading = false); return; }

                      final nav = Navigator.of(context);
                      final bookingProvider = Provider.of<BookingProvider>(context, listen: false);

                      // 🛡️ Pre-Selection Double-Check: Verify slot is still 100% free right before opening payment
                      try {
                        final currentBookings = await bookingProvider.getBookingsForStadium(widget.stadium.id, _selectedDate).first;
                        final sortedCheck = List<String>.from(_selectedTimeSlots)
                          ..sort((a, b) => _getSlotDateTime(a).compareTo(_getSlotDateTime(b)));
                        final isConflict = _isSlotBooked(sortedCheck.first, currentBookings);
                        if (isConflict) {
                          HapticFeedback.vibrate();
                          setState(() {
                            _selectedTimeSlots.clear();
                            _isLoading = false;
                          });
                          if (context.mounted) {
                            final isAr = Localizations.localeOf(context).languageCode == 'ar';
                            VSPFeedback.showError(
                              context, 
                              isAr 
                                ? '⚠️ عذراً، تم حجز وتأكيد هذه الساعة للتو بواسطة لاعب آخر! تم تحديث الجدول تلقائياً.' 
                                : '⚠️ Sorry, this slot was just booked by another player! Schedule updated automatically.'
                            );
                          }
                          return;
                        }
                      } catch (e, stack) {
                        VSPLogger.e('Error checking slot availability before booking', e, stack);
                      }

                      HapticFeedback.mediumImpact();

                      final sortedSlots = List<String>.from(_selectedTimeSlots)
                        ..sort((a, b) => _getSlotDateTime(a).compareTo(_getSlotDateTime(b)));
                      final firstSlot = sortedSlots.first;
                      final startTime = _getSlotDateTime(firstSlot);
                      final endTime = startTime.add(Duration(minutes: _selectedTimeSlots.length * 30));

                      BookingType bType;
                      if (_isOpenJoin) {
                        bType = BookingType.openJoin;
                      } else if (_isChallenge) {
                        bType = BookingType.challenge;
                      } else {
                        bType = BookingType.personal;
                      }

                      final depositAmount = widget.stadium.depositAmount;
                      final fieldCapacity = widget.stadium.totalFieldCapacity > 0 ? widget.stadium.totalFieldCapacity : (widget.stadium.seatsCapacity > 0 ? widget.stadium.seatsCapacity * 2 : 10);

                      final draft = BookingDraft(
                        stadiumId: widget.stadium.id, stadiumName: widget.stadium.name, stadiumImageUrl: widget.stadium.imageUrl,
                        ownerId: widget.stadium.ownerId, startTime: startTime, endTime: endTime, bookingType: bType,
                        playerTeamId: (bType == BookingType.team || bType == BookingType.challenge) ? _userTeamId : null,
                        playerTeamName: (bType == BookingType.team || bType == BookingType.challenge) ? _userTeamName : currentUserModel.name,
                        opponentTeamId: widget.opponentTeam?.id, opponentTeamName: widget.opponentTeam?.name,
                        totalPrice: _totalPrice, isPaid: false, isPrivate: _isPrivate, rentBall: _isBallRented,
                        currentPlayers: (bType == BookingType.openJoin) ? _initialPlayersCount : _currentPlayers, playersPerTeam: widget.stadium.playersPerTeam, totalFieldCapacity: fieldCapacity,
                        depositPaid: depositAmount, isDepositPaid: false, needsDeposit: widget.stadium.needsDeposit,
                        instapay: widget.stadium.features is Map ? widget.stadium.features['instapay'] : null,
                        vodafoneCash: widget.stadium.features is Map ? widget.stadium.features['vodafoneCash'] : null,
                        binanceId: widget.stadium.features is Map ? widget.stadium.features['binanceId'] : null,
                      );

                      setState(() => _isLoading = false);

                      final bool requiresDeposit = widget.stadium.needsDeposit && depositAmount > 0;

                      if (!context.mounted) return;
                      final isCashLocked = (currentUserModel.noShowCount) >= 2;
                      if (isCashLocked && !requiresDeposit) {
                        HapticFeedback.vibrate();
                        VSPFeedback.showError(context, isArabic ? "حسابك مقيد من الحجز النقدي لعدم الحضور السابق. يرجى الدفع أونلاين 100٪." : "Cash bookings restricted due to missed attendance. Please pay 100% online.");
                        nav.push(MaterialPageRoute(builder: (_) => PaymentGatewayScreen(bookingDraft: draft, forceFullPayment: true)));
                        return;
                      }

                      if (!context.mounted) return;
                      showModalBottomSheet(
                        context: context,
                        useSafeArea: true,
                        isScrollControlled: true,
                        backgroundColor: VSPColors.surface,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                        builder: (ctx) {
                          bool isCashSubmitting = false;
                          return StatefulBuilder(
                            builder: (sheetContext, setSheetState) {
                              return SafeArea(
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    20,
                                    20,
                                    20,
                                    MediaQuery.of(ctx).padding.bottom > 0 ? 8 : 20,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 4,
                                        decoration: BoxDecoration(color: VSPColors.divider, borderRadius: BorderRadius.circular(2)),
                                      ),
                                      const SizedBox(height: 14),
                                      Text(
                                        isArabic ? 'اختر طريقة الدفع' : 'Select Payment Option',
                                        style: const TextStyle(color: VSPColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 16),

                                      // -------------------------------------------------------------
                                      // حالة 1: الملعب يشترط عربوناً -> (دفع كامل أونلاين vs دفع العربون)
                                      // -------------------------------------------------------------
                                      if (requiresDeposit) ...[
                                        // خيار 1: دفع كامل المبلغ أونلاين
                                        ListTile(
                                          leading: const Icon(Iconsax.card_copy, color: VSPColors.accent),
                                          title: Text(
                                            isArabic ? 'دفع كامل المبلغ أونلاين 💳' : 'Pay Full Amount Online 💳',
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                          ),
                                          subtitle: Text(
                                            isArabic
                                                ? 'سداد ${_totalPrice.toInt()} ج.م كاملاً بالفيزا/المحفظة (المتبقي بالملعب: 0 ج.م)'
                                                : 'Pay full ${_totalPrice.toInt()} EGP online (Remaining at pitch: 0 EGP)',
                                            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                                          ),
                                          onTap: () {
                                            HapticFeedback.lightImpact();
                                            Navigator.pop(ctx);
                                            final fullDraft = draft.copyWith(
                                              needsDeposit: false,
                                              depositPaid: 0.0,
                                            );
                                            nav.push(MaterialPageRoute(
                                              builder: (_) => PaymentGatewayScreen(
                                                bookingDraft: fullDraft,
                                                forceFullPayment: true,
                                              ),
                                            ));
                                          },
                                        ),
                                        const Divider(color: VSPColors.divider),
                                        // خيار 2: دفع العربون فقط أونلاين
                                        ListTile(
                                          leading: const Icon(Iconsax.lock_copy, color: Colors.amber),
                                          title: Text(
                                            isArabic ? 'دفع العربون فقط أونلاين 🔒' : 'Pay Deposit Only Online 🔒',
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                          ),
                                          subtitle: Text(
                                            isArabic
                                                ? 'سداد ${depositAmount.toInt()} ج.م عربون لتأكيد الحجز + سداد المتبقي (${(_totalPrice - depositAmount).toInt()} ج.م) كاش بالملعب'
                                                : 'Pay ${depositAmount.toInt()} EGP deposit now + pay remaining (${(_totalPrice - depositAmount).toInt()} EGP) in cash',
                                            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                                          ),
                                          onTap: () {
                                            HapticFeedback.lightImpact();
                                            Navigator.pop(ctx);
                                            final depositDraft = draft.copyWith(
                                              needsDeposit: true,
                                              depositPaid: depositAmount,
                                            );
                                            nav.push(MaterialPageRoute(
                                              builder: (_) => PaymentGatewayScreen(
                                                bookingDraft: depositDraft,
                                              ),
                                            ));
                                          },
                                        ),
                                      ]

                                      // -------------------------------------------------------------
                                      // حالة 2: الملعب لا يشترط عربوناً -> (دفع كامل أونلاين vs دفع كاش)
                                      // -------------------------------------------------------------
                                      else ...[
                                        // خيار 1: دفع إلكتروني
                                        ListTile(
                                          leading: const Icon(Iconsax.card_copy, color: VSPColors.accent),
                                          title: Text(
                                            isArabic ? 'دفع إلكتروني كامل 💳' : 'Full Online Payment 💳',
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                          ),
                                          subtitle: Text(
                                            isArabic ? 'سداد بالفيزا / فودافون كاش / إنستاباي' : 'Pay via Visa / Vodafone Cash / InstaPay',
                                            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                                          ),
                                          onTap: isCashSubmitting ? null : () {
                                            HapticFeedback.lightImpact();
                                            Navigator.pop(ctx);
                                            nav.push(MaterialPageRoute(
                                              builder: (_) => PaymentGatewayScreen(
                                                bookingDraft: draft,
                                                forceFullPayment: true,
                                              ),
                                            ));
                                          },
                                        ),
                                        const Divider(color: VSPColors.divider),
                                        // خيار 2: دفع نقدي
                                        ListTile(
                                          leading: isCashSubmitting
                                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: VSPColors.accent))
                                              : const Icon(Iconsax.money_3_copy, color: VSPColors.warning),
                                          title: Text(
                                            isArabic ? 'دفع نقدي بالكامل في الملعب 💵' : 'Pay Full Cash at Pitch 💵',
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                          ),
                                          subtitle: Text(
                                            isArabic ? 'سداد المبلغ كاملاً للمسؤول عند الحضور' : 'Pay total amount in cash upon arrival',
                                            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                                          ),
                                          onTap: isCashSubmitting ? null : () async {
                                            HapticFeedback.mediumImpact();
                                            setSheetState(() => isCashSubmitting = true);
                                            try {
                                              final cashDraft = draft.copyWith(
                                                paymentMethod: 'cash',
                                                isPaid: false,
                                                depositPaid: 0.0,
                                                isDepositPaid: false,
                                              );
                                              final booking = await bookingProvider.createBooking(cashDraft, currentUserModel.uid);
                                              if (booking != null && sheetContext.mounted) {
                                                HapticFeedback.lightImpact();
                                                Navigator.pop(ctx);
                                                nav.pushReplacement(MaterialPageRoute(builder: (_) => BookingSuccessScreen(booking: booking)));
                                              } else if (bookingProvider.errorMessage != null && sheetContext.mounted) {
                                                HapticFeedback.vibrate();
                                                setSheetState(() => isCashSubmitting = false);
                                                VSPFeedback.showError(sheetContext, bookingProvider.errorMessage!);
                                              }
                                            } catch (e) {
                                              HapticFeedback.vibrate();
                                              if (sheetContext.mounted) {
                                                setSheetState(() => isCashSubmitting = false);
                                                VSPFeedback.showError(sheetContext, e.toString().replaceAll('Exception: ', ''));
                                              }
                                            }
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : Text(
                            isSlotSelected
                                ? (isArabic ? 'تأكيد الحجز' : 'Booking Confirmation')
                                : (isArabic ? 'اختر الوقت أولاً' : 'Select Time'),
                            style: TextStyle(
                              color: isSlotSelected ? Colors.black : Colors.grey.shade400,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
