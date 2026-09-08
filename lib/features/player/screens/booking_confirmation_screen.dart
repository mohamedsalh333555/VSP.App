import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/repositories/booking_repository.dart';
import '../../../core/repositories/team_repository.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/app_date_formatter.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../data/models.dart';
import '../../../shared/widgets/vsp_back_button.dart';
import '../widgets/booking/booking_bottom_bar.dart';
import '../widgets/booking/booking_date_selector.dart';
import '../widgets/booking/booking_financial_summary.dart';
import '../widgets/booking/booking_payment_method_sheet.dart';
import '../widgets/booking/booking_slot_card.dart';
import '../widgets/booking/booking_slot_models.dart';
import 'payment_gateway_screen.dart';

export '../widgets/booking/booking_slot_models.dart' show TimeSlotItem;

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
  bool _isSlotsInitialized = false;

  DateTime get _operationalBaseDate {
    return AppDateFormatter.getOperationalDate(DateTime.now());
  }

  bool get _isOpenJoin {
    final bType = widget.bookingType.toLowerCase().replaceAll(' ', '').replaceAll('_', '');
    return bType == 'openjoin' || bType == 'openjoinmatch';
  }

  bool get _isChallenge {
    final bType = widget.bookingType.toLowerCase().replaceAll(' ', '').replaceAll('_', '');
    return bType == 'challenge' || bType == 'challengematch';
  }

  bool get _isMatchup {
    final bType = widget.bookingType.toLowerCase().replaceAll(' ', '').replaceAll('_', '');
    return bType == 'matchup' || bType == 'matchups' || bType == 'matchupmatch';
  }

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
        final tappedIdx = _selectedTimeSlots.indexOf(slotKey);
        if (_selectedTimeSlots.length <= 1) {
          _selectedTimeSlots.clear();
        } else if (_selectedTimeSlots.length == 2) {
          _selectedTimeSlots.remove(slotKey);
        } else {
          if (tappedIdx == 0) {
            _selectedTimeSlots.removeAt(0);
          } else if (tappedIdx == _selectedTimeSlots.length - 1) {
            _selectedTimeSlots.removeLast();
          } else {
            _selectedTimeSlots.removeRange(tappedIdx, _selectedTimeSlots.length);
          }
        }
        return;
      }

      if (idxTapped == -1) return;

      if (_selectedTimeSlots.isEmpty) {
        _selectedTimeSlots.add(slotKey);
      } else if (_selectedTimeSlots.length == 1) {
        final first = _selectedTimeSlots.first;
        final idxFirst = _timeSlots.indexWhere((s) => s.key == first);
        if (idxFirst == -1) {
          _selectedTimeSlots.clear();
          _selectedTimeSlots.add(slotKey);
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
          _selectedTimeSlots.clear();
          _selectedTimeSlots.add(slotKey);
        } else {
          _selectedTimeSlots.clear();
          _selectedTimeSlots.addAll(tempRange);
        }
      } else {
        _selectedTimeSlots.clear();
        _selectedTimeSlots.add(slotKey);
      }
    });
  }

  Future<void> _handleBookingConfirmation() async {
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserModel = authProvider.userModel;
    if (currentUserModel == null) {
      setState(() => _isLoading = false);
      return;
    }

    final nav = Navigator.of(context);
    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);

    // Pre-Selection Double-Check: Verify slot is still 100% free right before opening payment
    try {
      List<Booking> currentBookings = [];
      try {
        currentBookings = await bookingProvider
            .getBookingsForStadium(widget.stadium.id, _selectedDate)
            .first
            .timeout(const Duration(seconds: 4));
      } catch (_) {
        final repo = SupabaseBookingRepository();
        currentBookings = await repo.fetchStadiumBookingsDirectly(widget.stadium.id, _selectedDate);
      }
      if (!mounted) return;
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
                ? 'عذراً، تم حجز وتأكيد هذه الساعة للتو بواسطة لاعب آخر. تم تحديث الجدول تلقائياً.'
                : 'Sorry, this slot was just booked by another player! Schedule updated automatically.',
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
    } else if (_isMatchup) {
      bType = BookingType.matchup;
    } else {
      bType = BookingType.personal;
    }

    final depositAmount = widget.stadium.depositAmount;
    final fieldCapacity = widget.stadium.totalFieldCapacity > 0
        ? widget.stadium.totalFieldCapacity
        : (widget.stadium.seatsCapacity > 0 ? widget.stadium.seatsCapacity * 2 : 10);

    final draft = BookingDraft(
      stadiumId: widget.stadium.id,
      stadiumName: widget.stadium.name,
      stadiumImageUrl: widget.stadium.imageUrl,
      ownerId: widget.stadium.ownerId,
      startTime: startTime,
      endTime: endTime,
      bookingType: bType,
      playerTeamId: (bType == BookingType.team || bType == BookingType.challenge) ? _userTeamId : null,
      playerTeamName: (bType == BookingType.team || bType == BookingType.challenge)
          ? _userTeamName
          : currentUserModel.name,
      opponentTeamId: widget.opponentTeam?.id,
      opponentTeamName: widget.opponentTeam?.name,
      totalPrice: _totalPrice,
      isPaid: false,
      isPrivate: _isPrivate,
      rentBall: _isBallRented,
      currentPlayers: (bType == BookingType.openJoin) ? _initialPlayersCount : _currentPlayers,
      playersPerTeam: widget.stadium.playersPerTeam,
      totalFieldCapacity: fieldCapacity,
      depositPaid: depositAmount,
      isDepositPaid: false,
      needsDeposit: widget.stadium.needsDeposit,
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
      final isAr = Localizations.localeOf(context).languageCode == 'ar';
      VSPFeedback.showError(
        context,
        isAr
            ? "حسابك مقيد من الحجز النقدي لعدم الحضور السابق. يرجى الدفع أونلاين 100٪."
            : "Cash bookings restricted due to missed attendance. Please pay 100% online.",
      );
      nav.push(MaterialPageRoute(
        builder: (_) => PaymentGatewayScreen(bookingDraft: draft, forceFullPayment: true),
      ));
      return;
    }

    if (!context.mounted) return;
    showBookingPaymentMethodSheet(
      context: context,
      draft: draft,
      totalPrice: _totalPrice,
      depositAmount: depositAmount,
      requiresDeposit: requiresDeposit,
      currentUserModel: currentUserModel,
      bookingProvider: bookingProvider,
      nav: nav,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isSlotSelected = _selectedTimeSlots.isNotEmpty;
    final hasBallOption = widget.stadium.hasBall || _ballPrice > 0;
    final deposit = widget.stadium.depositAmount;
    final maxPlayers = widget.stadium.totalFieldCapacity > 1 ? widget.stadium.totalFieldCapacity - 1 : 1;

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        leading: const VSPBackButton(),
        centerTitle: true,
        title: Text(l10n.bookNow, style: Theme.of(context).textTheme.displaySmall),
      ),
      body: Column(
        children: [
          BookingDateSelector(
            selectedDate: _selectedDate,
            operationalBaseDate: _operationalBaseDate,
            onDateChanged: (date) {
              setState(() {
                _selectedDate = date;
                _selectedTimeSlots.clear();
              });
            },
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.selectTime, style: Theme.of(context).textTheme.displaySmall),
                  StreamBuilder<List<Booking>>(
                    stream: Provider.of<BookingProvider>(context, listen: false)
                        .getBookingsForStadium(widget.stadium.id, _selectedDate),
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
                      if (snapshot.hasError && (!snapshot.hasData || snapshot.data!.isEmpty)) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(Icons.refresh, color: VSPColors.warning, size: 28),
                                const SizedBox(height: 8),
                                const Text(
                                  'تعذر التحديث اللحظي، اسحب للأسفل للتحديث',
                                  style: TextStyle(color: VSPColors.textSecondary, fontSize: 13),
                                ),
                                const SizedBox(height: 10),
                                TextButton.icon(
                                  onPressed: () => setState(() {}),
                                  icon: const Icon(Icons.refresh, color: VSPColors.accent, size: 16),
                                  label: const Text(
                                    'إعادة المحاولة',
                                    style: TextStyle(color: VSPColors.accent, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      final existingBookings = snapshot.data ?? [];
                      final now = DateTime.now();
                      final bool isToday = _selectedDate.year == now.year &&
                          _selectedDate.month == now.month &&
                          _selectedDate.day == now.day;

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
                          final isCurrentOngoing =
                              isToday && now.isAfter(slotDateTime) && now.isBefore(slotEndDateTime);
                          final isNextAvailable = isToday && slotItem.key == firstUpcomingSlotKey;

                          final isOvernightSlot = slotItem.startMinutes >= 1440;
                          final bool isFirstOvernightSlot =
                              isOvernightSlot && (index == 0 || _timeSlots[index - 1].startMinutes < 1440);
                          final String nextDayName = isOvernightSlot
                              ? DateFormat('EEEE', Localizations.localeOf(context).toString()).format(slotDateTime)
                              : '';

                          return BookingSlotCard(
                            slotItem: slotItem,
                            isBooked: isBooked,
                            isPast: isPast,
                            isSelected: isSelected,
                            isCurrentOngoing: isCurrentOngoing,
                            isNextAvailable: isNextAvailable,
                            isFirstOvernightSlot: isFirstOvernightSlot,
                            nextDayName: nextDayName,
                            onTap: () => _onTimeSlotTap(slotItem.key, existingBookings),
                          );
                        }),
                      );
                    },
                  ),
                  BookingFinancialSummary(
                    stadium: widget.stadium,
                    totalPrice: _totalPrice,
                  ),
                  const SizedBox(height: VSPSpacing.xl),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BookingBottomBar(
        isOpenJoin: _isOpenJoin,
        isPrivate: _isPrivate,
        onPrivateChanged: (val) => setState(() => _isPrivate = val),
        initialPlayersCount: _initialPlayersCount,
        maxPlayersCount: maxPlayers,
        onPlayersCountChanged: (count) => setState(() => _initialPlayersCount = count),
        hasBallOption: hasBallOption,
        isBallRented: _isBallRented,
        onBallRentedChanged: (val) => setState(() => _isBallRented = val),
        ballPrice: _ballPrice,
        totalPrice: _totalPrice,
        depositAmount: deposit,
        needsDeposit: widget.stadium.needsDeposit,
        isSlotSelected: isSlotSelected,
        isLoading: _isLoading,
        onConfirmPressed: _handleBookingConfirmation,
      ),
    );
  }
}
