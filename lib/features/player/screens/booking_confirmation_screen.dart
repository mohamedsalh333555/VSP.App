import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../data/models.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/team_repository.dart';
import '../../../core/repositories/booking_repository.dart';
import '../../../core/repositories/user_repository.dart';
import 'booking_success_screen.dart';
import 'payment_gateway_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class BookingConfirmationScreen extends StatefulWidget {
  final Stadium stadium; 
  final String bookingType; 
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
  final List<String> _selectedTimeSlots = []; 
  bool _isBallRented = false;
  bool _isPrivate = true;
  bool _isLoading = false;
  int _currentPlayers = 1;
  String? _userTeamId;
  String? _userTeamName;
  String? _ownerPhone;
  bool _isLoadingPhone = true;
  List<String> _timeSlots = [];

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
    _fetchOwnerPhone();
  }

  Future<void> _fetchOwnerPhone() async {
    try {
      final features = widget.stadium.features;
      if (features is Map && features['stadiumPhone'] != null && features['stadiumPhone'].toString().trim().isNotEmpty) {
        if (mounted) {
          setState(() {
            _ownerPhone = features['stadiumPhone'].toString().trim();
            _isLoadingPhone = false;
          });
        }
        return;
      }

      final ownerId = widget.stadium.ownerId;
      if (ownerId.isNotEmpty) {
        final userData = await UserRepository().getUserData(ownerId);
        if (userData != null && mounted) {
          setState(() {
            _ownerPhone = userData['phone']?.toString();
            _isLoadingPhone = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Error fetching owner phone in confirmation: $e');
    }
    if (mounted) {
      setState(() => _isLoadingPhone = false);
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

  void _generateDynamicTimeSlots() {
    try {
      final features = widget.stadium.features;
      String startStr = '03:00 PM'; 
      String endStr = '03:00 AM';   

      if (features is Map && features['workingHours'] != null) {
        startStr = features['workingHours']['start'] ?? startStr;
        endStr = features['workingHours']['end'] ?? endStr;
      }

      int startMinutes = _parseTimeToMinutes(startStr);
      int endMinutes = _parseTimeToMinutes(endStr);

      if (endMinutes < startMinutes) {
        endMinutes += 24 * 60; 
      }

      int getCumulativeMinutes(String timeStr) {
        int min = _parseTimeToMinutes(timeStr);
        if (min < startMinutes) {
          min += 24 * 60; 
        }
        return min;
      }

      int? bStart;
      int? bEnd;
      if (features is Map && features['breakTime'] != null) {
        bStart = getCumulativeMinutes(features['breakTime']['start'] ?? '');
        bEnd = getCumulativeMinutes(features['breakTime']['end'] ?? '');
      }

      final List<String> slots = [];
      for (int m = startMinutes; m <= endMinutes; m += 30) {
        if (bStart != null && bEnd != null) {
          if ((m >= bStart && m < bEnd) || (m + 30 > bStart && m + 30 <= bEnd)) {
            continue; 
          }
        }
        slots.add(_formatMinutesToTime(m % (24 * 60)));
      }

      setState(() {
        _timeSlots = slots;
      });
    } catch (e) {
      setState(() {
        _timeSlots = ['02:00 PM', '03:00 PM', '04:00 PM', '05:00 PM', '06:00 PM', '07:00 PM', '08:00 PM', '09:00 PM', '10:00 PM', '11:00 PM'];
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
    int openMin = _parseTimeToMinutes(widget.stadium.openingTime);
    DateTime date = _selectedDate;
    if (openMin > 12 * 60 && startMin < openMin) {
      date = date.add(const Duration(days: 1));
    }
    return DateTime(date.year, date.month, date.day, startMin ~/ 60, startMin % 60);
  }

  bool _isSlotBooked(String slot, List<Booking> existingBookings) {
    final slotStartTime = _getSlotDateTime(slot);
    final slotEndTime = slotStartTime.add(const Duration(hours: 1));
    for (var booking in existingBookings) {
      if (slotStartTime.isBefore(booking.endTime) && slotEndTime.isAfter(booking.startTime)) {
        return true;
      }
    }
    return false;
  }

  void _onTimeSlotTap(String slot, List<Booking> existingBookings) {
    setState(() {
      if (_selectedTimeSlots.isEmpty) {
        _selectedTimeSlots.add(slot);
      } else if (_selectedTimeSlots.length == 1) {
        final first = _selectedTimeSlots.first;
        if (first == slot) {
          _selectedTimeSlots.clear();
        } else {
          final idxFirst = _timeSlots.indexOf(first);
          final idxTapped = _timeSlots.indexOf(slot);
          
          final startIdx = idxFirst < idxTapped ? idxFirst : idxTapped;
          final endIdx = idxFirst > idxTapped ? idxFirst : idxTapped;
          
          bool hasInvalidSlot = false;
          final List<String> tempRange = [];
          for (int i = startIdx; i <= endIdx; i++) {
            final checkSlot = _timeSlots[i];
            final slotDateTime = _getSlotDateTime(checkSlot);
            final isPast = slotDateTime.isBefore(DateTime.now());
            final isBooked = _isSlotBooked(checkSlot, existingBookings);
            
            if (isPast || isBooked) {
              hasInvalidSlot = true;
              break;
            }
            tempRange.add(checkSlot);
          }
          
          if (hasInvalidSlot) {
            _selectedTimeSlots.clear();
            _selectedTimeSlots.add(slot);
          } else {
            _selectedTimeSlots.clear();
            _selectedTimeSlots.addAll(tempRange);
          }
        }
      } else {
        _selectedTimeSlots.clear();
        _selectedTimeSlots.add(slot);
      }
    });
  }

  void _showCalendarModal() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierColor: VSPColors.background.withOpacity(0.8),
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
                          icon: Icon(LucideIcons.chevronLeft, color: currentMonth.isAfter(todayMonth) ? VSPColors.textSecondary : VSPColors.textSecondary.withOpacity(0.25)),
                          onPressed: currentMonth.isAfter(todayMonth) ? () { setModalState(() { currentMonth = DateTime(currentMonth.year, currentMonth.month - 1); }); } : null,
                        ),
                        Text(DateFormat('MMMM yyyy', Localizations.localeOf(context).toString()).format(currentMonth), style: Theme.of(context).textTheme.titleLarge),
                        IconButton(
                          icon: Icon(LucideIcons.chevronRight, color: currentMonth.isBefore(maxMonth) ? VSPColors.textSecondary : VSPColors.textSecondary.withOpacity(0.25)),
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
                              child: Text('$day', style: TextStyle(color: isSelected ? VSPColors.background : (isPastDate ? VSPColors.textSecondary.withOpacity(0.5) : VSPColors.textSecondary), fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
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
        leading: IconButton(icon: const Icon(LucideIcons.chevronLeft, color: VSPColors.textPrimary, size: 20), onPressed: () => Navigator.pop(context)),
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
                          const Icon(LucideIcons.calendar, color: VSPColors.textPrimary, size: 18),
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
                            final date = DateTime.now().add(Duration(days: index));
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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.selectTime, style: Theme.of(context).textTheme.displaySmall),
                  const SizedBox(height: VSPSpacing.md),
                  StreamBuilder<List<Booking>>(
                    stream: Provider.of<BookingProvider>(context, listen: false).getBookingsForStadium(widget.stadium.id, _selectedDate),
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
                          
                          if (isPast) return const SizedBox.shrink();

                          return GestureDetector(
                            onTap: (isBooked || isPast) ? null : () => _onTimeSlotTap(startTime, existingBookings),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              alignment: Alignment.center,
                              margin: const EdgeInsets.only(bottom: VSPSpacing.sm),
                              padding: const EdgeInsets.symmetric(vertical: VSPSpacing.md, horizontal: VSPSpacing.lg),
                              decoration: BoxDecoration(
                                color: (isBooked || isPast) ? VSPColors.surface.withOpacity(0.3) : (isSelected ? VSPColors.accentSoft : Colors.transparent),
                                borderRadius: BorderRadius.circular(VSPRadius.md),
                                border: Border.all(color: (isBooked || isPast) ? Colors.transparent : (isSelected ? VSPColors.accent : VSPColors.divider), width: isSelected ? 2 : 1),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (isSelected) ...[const Icon(LucideIcons.checkCircle, size: 16, color: VSPColors.accent), const SizedBox(width: 8)],
                                  Text(
                                    slotLabel,
                                    style: TextStyle(
                                      color: (isBooked || isPast) ? VSPColors.textSecondary.withOpacity(0.3) : (isSelected ? VSPColors.accent : VSPColors.textPrimary),
                                      fontSize: 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      decoration: (isBooked || isPast) ? TextDecoration.lineThrough : TextDecoration.none,
                                    ),
                                  ),
                                  if (isBooked) ...[const SizedBox(width: 12), Text(l10n.bookedStatus, style: const TextStyle(color: VSPColors.error, fontSize: 12, fontWeight: FontWeight.bold))] 
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
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(VSPSpacing.lg, VSPSpacing.lg, VSPSpacing.lg, MediaQuery.of(context).padding.bottom + VSPSpacing.lg),
        decoration: BoxDecoration(
          color: VSPColors.surfaceAlt,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(VSPRadius.xl), topRight: Radius.circular(VSPRadius.xl)),
          boxShadow: VSPShadow.subtle,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.bookingType != 'Team') ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.privateLabel, style: Theme.of(context).textTheme.titleLarge),
                  Switch(value: _isPrivate, onChanged: (val) => setState(() => _isPrivate = val), activeColor: VSPColors.accent, activeTrackColor: VSPColors.accentSoft),
                ],
              ),
              const SizedBox(height: VSPSpacing.sm),
            ],
            if (widget.bookingType == 'Team') ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.currentPlayersWithYou, style: Theme.of(context).textTheme.titleMedium),
                      Text(l10n.playersInGroupSubtitle, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary)),
                    ],
                  ),
                  Row(
                    children: [
                      _buildCounterButton(LucideIcons.minus, () { if (_currentPlayers > 1) setState(() => _currentPlayers--); }),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('$_currentPlayers', style: const TextStyle(color: VSPColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold))),
                      _buildCounterButton(LucideIcons.plus, () { final int maxAllowed = (widget.stadium.seatsCapacity > 0) ? widget.stadium.seatsCapacity : 10; if (_currentPlayers < maxAllowed) setState(() => _currentPlayers++); }),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
            GestureDetector(
              onTap: () => setState(() => _isBallRented = !_isBallRented),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.rentBallLabel(_ballPrice.toInt(), l10n.egCurrency), style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: VSPSpacing.xs),
                      Text(l10n.payPerBallSubtitle, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary)),
                    ],
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 24, height: 24,
                    decoration: BoxDecoration(color: _isBallRented ? VSPColors.accent : Colors.transparent, borderRadius: BorderRadius.circular(VSPRadius.sm), border: Border.all(color: _isBallRented ? VSPColors.accent : VSPColors.borderMedium)),
                    child: _isBallRented ? const Icon(LucideIcons.check, size: 16, color: VSPColors.background) : null,
                  ),
                ],
              ),
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: VSPSpacing.lg), child: Divider(color: VSPColors.divider, thickness: 1)),
            Builder(builder: (context) {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              final isCashLocked = (authProvider.userModel?.noShowCount ?? 0) >= 2;
              final deposit = widget.stadium.depositAmount;

              if (isCashLocked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPriceRow(l10n.totalPriceLabel, '${_totalPrice.toInt()} ${l10n.egCurrency}', highlight: true),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: VSPColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(VSPRadius.md), border: Border.all(color: VSPColors.error.withOpacity(0.5))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(LucideIcons.alertTriangle, color: VSPColors.error, size: 18),
                              const SizedBox(width: 8),
                              Text(isArabic ? "تقييد الحساب" : "Account Restricted", style: const TextStyle(color: VSPColors.error, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(isArabic ? "تم تقييد حسابك مؤقتاً من الحجوزات النقدية بسبب تكرار عدم الحضور. للحجز، يجب دفع 100٪ من قيمة الحجز عبر الإنترنت باستخدام المحافظ الرقمية." : "Your account is temporarily restricted from Cash bookings due to multiple missed bookings. To book, you must pay 100% of the booking amount online via digital wallets.", style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11, height: 1.4)),
                        ],
                      ),
                    ),
                    const SizedBox(height: VSPSpacing.lg),
                  ],
                );
              }

              if (deposit > 0 && widget.stadium.needsDeposit) {
                return Column(
                  children: [
                    _buildPriceRow(l10n.totalPriceLabel, '${_totalPrice.toInt()} ${l10n.egCurrency}', highlight: false),
                    const SizedBox(height: 8),
                    _buildPriceRow(isArabic ? 'عربون الحجز' : 'Upfront Deposit', '${deposit.toInt()} ${l10n.egCurrency}', icon: LucideIcons.lock, highlight: false, color: VSPColors.accent),
                    const SizedBox(height: 8),
                    _buildPriceRow(isArabic ? 'المتبقي عند الملعب' : 'Remaining (At Pitch)', '${(_totalPrice - deposit).clamp(0, double.infinity).toInt()} ${l10n.egCurrency}', icon: LucideIcons.banknote, highlight: false, color: VSPColors.textSecondary),
                    const SizedBox(height: VSPSpacing.lg),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.totalPriceLabel, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary)),
                  Text(l10n.priceEgp(_totalPrice.toInt()), style: Theme.of(context).textTheme.displayLarge),
                  const SizedBox(height: VSPSpacing.lg),
                ],
              );
            }),
            if (!_isLoadingPhone && _ownerPhone != null && _ownerPhone!.isNotEmpty) ...[
              _buildContactPitchButton(context, _ownerPhone!),
              const SizedBox(height: 12),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(
                  child: PrimaryButton(
                    text: l10n.confirmSelections,
                    isLoading: _isLoading,
                    onPressed: (_selectedTimeSlots.isEmpty || _isLoading) ? null : () async {
                       setState(() => _isLoading = true);
                       final authProvider = Provider.of<AuthProvider>(context, listen: false);
                       final currentUserModel = authProvider.userModel;
                       if (currentUserModel == null) { setState(() => _isLoading = false); return; }
                       
                       final sortedSlots = List<String>.from(_selectedTimeSlots)..sort();
                       final firstSlot = sortedSlots.first;
                       int startMin = _parseTimeToMinutes(firstSlot);
                       int openMin = _parseTimeToMinutes(widget.stadium.openingTime);
                       DateTime date = _selectedDate;
                       if (openMin > 12 * 60 && startMin < openMin) { date = date.add(const Duration(days: 1)); }
                       final startTime = DateTime(date.year, date.month, date.day, startMin ~/ 60, startMin % 60);
                       final endTime = startTime.add(Duration(minutes: _selectedTimeSlots.length * 30));

                       BookingType bType;
                       switch (widget.bookingType.toLowerCase()) {
                         case 'team': bType = BookingType.team; break;
                         case 'challenge': bType = BookingType.challenge; break;
                         default: bType = BookingType.personal;
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
                         currentPlayers: _currentPlayers, totalFieldCapacity: fieldCapacity,
                         depositPaid: widget.stadium.needsDeposit ? depositAmount : 0.0,
                         isDepositPaid: false, needsDeposit: widget.stadium.needsDeposit,
                       );

                       final needsDeposit = widget.stadium.needsDeposit;
                       final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
                       final unpaidBookings = await SupabaseBookingRepository().getUnpaidBookingsForUser(currentUserModel.uid);
                       final now = DateTime.now();
                       final activeUnpaidBookings = unpaidBookings.where((b) { return b.status != BookingStatus.cancelled && b.status != BookingStatus.completed && b.endTime.isAfter(now) && !b.isPaid && b.paymentMethod == 'cash'; }).toList();
                       final bool hasActiveUnpaid = activeUnpaidBookings.isNotEmpty;

                       if (!needsDeposit && !hasActiveUnpaid) {
                         final cashDraft = draft.copyWith(isPaid: false, isDepositPaid: false, depositPaid: 0.0, paymentStatus: 'unpaid', paymentMethod: 'cash', paymentTransactionId: '_');
                         final booking = await bookingProvider.createBooking(cashDraft, currentUserModel.uid);
                         if (mounted) {
                           setState(() => _isLoading = false);
                           if (booking != null) {
                             Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => BookingSuccessScreen(booking: booking)));
                           } else {
                             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(bookingProvider.errorMessage ?? 'Failed to create booking')));
                           }
                         }
                       } else {
                         final forceFullPayment = !needsDeposit && hasActiveUnpaid;
                         final amountToPay = needsDeposit ? depositAmount : _totalPrice;
                         if (amountToPay <= 0) { final zeroDraft = draft.copyWith(isPaid: true, paymentStatus: 'paid', paymentMethod: 'free', paymentTransactionId: 'FREE'); final booking = await bookingProvider.createBooking(zeroDraft, currentUserModel.uid); if (mounted) { setState(() => _isLoading = false); if (booking != null) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => BookingSuccessScreen(booking: booking))); } return; }
                         await Navigator.push(context, MaterialPageRoute(builder: (context) => PaymentGatewayScreen(bookingDraft: draft, forceFullPayment: forceFullPayment)));
                         if (mounted) { setState(() => _isLoading = false); }
                       }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactPitchButton(BuildContext context, String phone) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(VSPRadius.lg), border: Border.all(color: VSPColors.accent.withOpacity(0.3))),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
            final path = cleanPhone.startsWith('0') && cleanPhone.length == 11 ? '+2$cleanPhone' : (cleanPhone.startsWith('2') ? '+$cleanPhone' : cleanPhone);
            final Uri launchUri = Uri(scheme: 'tel', path: path);
            try { if (await canLaunchUrl(launchUri)) { await launchUrl(launchUri, mode: LaunchMode.externalApplication); } } catch (e) {}
          },
          borderRadius: BorderRadius.circular(VSPRadius.lg),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.phoneCall, color: VSPColors.accent, size: 18),
                const SizedBox(width: 8),
                Text(isArabic ? 'اتصل بالملعب للاستفسار المباشر' : 'Call Stadium directly to inquire', style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCounterButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: VSPColors.divider)),
        child: Icon(icon, color: VSPColors.textPrimary, size: 16),
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool highlight = false, IconData? icon, Color? color}) {
    final effectiveColor = color ?? (highlight ? VSPColors.accent : VSPColors.textPrimary);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (icon != null) ...[Icon(icon, color: effectiveColor, size: 14), const SizedBox(width: 6)],
            Text(label, style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13)),
          ],
        ),
        Text(value, style: TextStyle(color: effectiveColor, fontSize: highlight ? 18 : 14, fontWeight: highlight ? FontWeight.bold : FontWeight.w600)),
      ],
    );
  }
}
