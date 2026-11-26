import 'package:flutter/material.dart';
import '../../../core/ui/vsp_ui.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/repositories/gamification_repository.dart';
import '../../../core/repositories/team_repository.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/app_date_formatter.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../data/models.dart';
import '../../../data/models/team_gamification_models.dart';
import '../../../shared/widgets/vsp_back_button.dart';
import '../widgets/booking/booking_bottom_bar.dart';
import '../widgets/booking/booking_confirmation_handler.dart';
import '../widgets/booking/booking_date_selector.dart';
import '../widgets/booking/booking_financial_summary.dart';
import '../widgets/booking/booking_slot_calculator.dart';
import '../widgets/booking/booking_slot_models.dart';
import '../widgets/booking/booking_slot_stream_section.dart';
import 'booking_success_screen.dart';

export '../widgets/booking/booking_slot_models.dart' show TimeSlotItem;

class BookingConfirmationScreen extends StatefulWidget {
  final Stadium stadium;
  final DateTime? selectedDate;
  final String bookingType; // 'Personal', 'Team', 'Challenge'
  final Team? opponentTeam;
  final List<String>? initialSelectedSlots;

  const BookingConfirmationScreen({
    super.key,
    required this.stadium,
    this.selectedDate,
    this.bookingType = 'Personal',
    this.opponentTeam,
    this.initialSelectedSlots,
  });

  @override
  State<BookingConfirmationScreen> createState() =>
      _BookingConfirmationScreenState();
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
  MonthlyFreeHourAward? _eligibleFreeHourAward;
  bool _useFreeHourAward = false;
  List<TimeSlotItem> _timeSlots = [];
  bool _isSlotsInitialized = false;

  DateTime get _operationalBaseDate =>
      AppDateFormatter.getOperationalDate(DateTime.now());

  bool get _isOpenJoin =>
      BookingConfirmationHandler.isOpenJoin(widget.bookingType);
  bool get _isChallenge =>
      BookingConfirmationHandler.isChallenge(widget.bookingType);

  double get _slotPrice => widget.stadium.basePrice / 2;
  double get _ballPrice =>
      widget.stadium.ballPrice > 0 ? widget.stadium.ballPrice : 0;

  double get _totalPrice {
    if (_useFreeHourAward && _selectedTimeSlots.length == 2) return 0.0;
    double total = _selectedTimeSlots.length * _slotPrice;
    if (_isBallRented) total += _ballPrice;
    return total;
  }

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate ?? _operationalBaseDate;
    if (widget.initialSelectedSlots != null) {
      _selectedTimeSlots.addAll(widget.initialSelectedSlots!);
    }
    _isPrivate = true;
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
      final teams = await TeamRepository().getUserTeams(userId);
      final primaryTeam = teams.isNotEmpty ? teams.first : null;
      MonthlyFreeHourAward? matchingAward;
      if (!_isOpenJoin && !_isChallenge) {
        final stadiumGov = (widget.stadium.governorate ?? '')
            .trim()
            .toLowerCase();
        for (final t in teams.where((t) => t.captainId == userId)) {
          final profile = await GamificationRepository.instance
              .getTeamGamificationProfile(t.id);
          if (profile == null) continue;
          for (final award in profile.freeHourAwards) {
            if (award.status == 'issued' &&
                award.governorate.trim().toLowerCase() == stadiumGov) {
              matchingAward = award;
              break;
            }
          }
          if (matchingAward != null) break;
        }
      }
      if (mounted) {
        setState(() {
          _userTeamId = primaryTeam?.id;
          _userTeamName = primaryTeam?.name;
          _eligibleFreeHourAward = matchingAward;
        });
      }
    }
  }

  void _generateDynamicTimeSlots() {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    setState(() {
      _timeSlots = BookingSlotCalculator.generateDynamicTimeSlots(
        stadium: widget.stadium,
        isArabic: isArabic,
      );
    });
  }

  void _onTimeSlotTap(String slotKey, List<Booking> existingBookings) {
    setState(() {
      final updated = BookingSlotCalculator.calculateNewSelectedSlots(
        slotKey: slotKey,
        currentSelectedSlots: _selectedTimeSlots,
        timeSlots: _timeSlots,
        stadium: widget.stadium,
        selectedDate: _selectedDate,
        existingBookings: existingBookings,
      );
      _selectedTimeSlots.clear();
      _selectedTimeSlots.addAll(updated);
    });
  }

  Future<void> _handleBookingConfirmation() async {
    if (_useFreeHourAward && _eligibleFreeHourAward != null) {
      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
      if (_selectedTimeSlots.length != 2) {
        VSPFeedback.showInfo(
          context,
          isArabic
              ? 'جائزة الساعة المجانية تغطي ساعة واحدة بالضبط (فترتين متتاليتين).'
              : 'Free hour award covers exactly 1 hour (2 consecutive slots).',
        );
        return;
      }
      setState(() => _isLoading = true);
      try {
        final sortedSlots = List<String>.from(_selectedTimeSlots)
          ..sort(
            (a, b) =>
                BookingSlotCalculator.getSlotDateTime(
                  slotKey: a,
                  stadium: widget.stadium,
                  selectedDate: _selectedDate,
                ).compareTo(
                  BookingSlotCalculator.getSlotDateTime(
                    slotKey: b,
                    stadium: widget.stadium,
                    selectedDate: _selectedDate,
                  ),
                ),
          );
        final startTime = BookingSlotCalculator.getSlotDateTime(
          slotKey: sortedSlots.first,
          stadium: widget.stadium,
          selectedDate: _selectedDate,
        );
        final endTime = startTime.add(const Duration(hours: 1));
        final bookingProvider = Provider.of<BookingProvider>(
          context,
          listen: false,
        );
        final res = await GamificationRepository.instance
            .bookStadiumWithMonthlyAward(
              awardId: _eligibleFreeHourAward!.id,
              stadiumId: widget.stadium.id,
              startTime: startTime,
              endTime: endTime,
            );
        if (!mounted) return;
        if (res['success'] == true && res['booking_id'] != null) {
          final booking = await bookingProvider.getBookingById(
            res['booking_id'].toString(),
          );
          if (!mounted) return;
          setState(() => _isLoading = false);
          if (booking != null) {
            VSPFeedback.showSuccess(
              context,
              isArabic
                  ? 'تم حجز الساعة المجانية بنجاح!'
                  : 'Free hour booked successfully!',
            );
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => BookingSuccessScreen(booking: booking),
              ),
            );
            return;
          }
        }
        setState(() => _isLoading = false);
        VSPFeedback.showError(
          context,
          res['error']?.toString() ??
              (isArabic
                  ? 'تعذر استبدال الساعة المجانية.'
                  : 'Failed to redeem free hour.'),
        );
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          VSPFeedback.showError(context, e.toString());
        }
      }
      return;
    }

    await BookingConfirmationHandler.run(
      context: context,
      stadium: widget.stadium,
      bookingType: widget.bookingType,
      opponentTeam: widget.opponentTeam,
      selectedTimeSlots: List.unmodifiable(_selectedTimeSlots),
      selectedDate: _selectedDate,
      timeSlots: _timeSlots,
      isBallRented: _isBallRented,
      isPrivate: _isPrivate,
      totalPrice: _totalPrice,
      initialPlayersCount: _initialPlayersCount,
      currentPlayers: _currentPlayers,
      userTeamId: _userTeamId,
      userTeamName: _userTeamName,
      onLoadingChanged: (loading) => setState(() => _isLoading = loading),
      onSlotsCleared: () => setState(() => _selectedTimeSlots.clear()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isSlotSelected = _selectedTimeSlots.isNotEmpty;
    final hasBallOption = widget.stadium.hasBall || _ballPrice > 0;
    final deposit = widget.stadium.depositAmount;
    final maxPlayers = widget.stadium.totalFieldCapacity > 1
        ? widget.stadium.totalFieldCapacity - 1
        : 1;

    return VSPScaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        leading: const VSPBackButton(),
        centerTitle: true,
        title: Text(
          l10n.bookNow,
          style: Theme.of(context).textTheme.displaySmall,
        ),
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, VSPSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.selectTime,
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  BookingSlotStreamSection(
                    stadiumId: widget.stadium.id,
                    stadium: widget.stadium,
                    selectedDate: _selectedDate,
                    timeSlots: _timeSlots,
                    selectedTimeSlots: List.unmodifiable(_selectedTimeSlots),
                    onSlotTap: _onTimeSlotTap,
                    onRetry: () => setState(() {}),
                  ),
                  if (_eligibleFreeHourAward != null &&
                      !_isOpenJoin &&
                      !_isChallenge) ...[
                    const SizedBox(height: VSPSpacing.md),
                    Builder(
                      builder: (context) {
                        final isArabic =
                            Localizations.localeOf(context).languageCode ==
                            'ar';
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _useFreeHourAward
                                ? VSPColors.accent.withValues(alpha: 0.14)
                                : VSPColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(VSPRadius.md),
                            border: Border.all(
                              color: _useFreeHourAward
                                  ? VSPColors.accent
                                  : VSPColors.divider,
                            ),
                          ),
                          child: SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            activeTrackColor: VSPColors.accent,
                            secondary: const Icon(
                              Iconsax.gift_copy,
                              color: VSPColors.accent,
                            ),
                            title: Text(
                              isArabic
                                  ? 'استخدام جائزة الساعة المجانية (بطل ${_eligibleFreeHourAward!.monthKey})'
                                  : 'Redeem Monthly Champion Free Hour (${_eligibleFreeHourAward!.monthKey})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              isArabic
                                  ? 'ساعة مجانية 100% مدفوعة من VSP (اختر ساعة واحدة = فترتين).'
                                  : '100% VSP-funded 1 hour (select exactly 2 slots).',
                              style: const TextStyle(
                                color: VSPColors.textSecondary,
                                fontSize: 11.5,
                              ),
                            ),
                            value: _useFreeHourAward,
                            onChanged: (val) =>
                                setState(() => _useFreeHourAward = val),
                          ),
                        );
                      },
                    ),
                  ],
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
        isPrivate: _isOpenJoin ? true : _isPrivate,
        onPrivateChanged: (_) {},
        initialPlayersCount: _initialPlayersCount,
        maxPlayersCount: maxPlayers,
        onPlayersCountChanged: (count) =>
            setState(() => _initialPlayersCount = count),
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
