import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/team_repository.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/app_date_formatter.dart';
import '../../../data/models.dart';
import '../../../shared/widgets/vsp_back_button.dart';
import '../widgets/booking/booking_bottom_bar.dart';
import '../widgets/booking/booking_confirmation_handler.dart';
import '../widgets/booking/booking_date_selector.dart';
import '../widgets/booking/booking_financial_summary.dart';
import '../widgets/booking/booking_slot_calculator.dart';
import '../widgets/booking/booking_slot_models.dart';
import '../widgets/booking/booking_slot_stream_section.dart';

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

  DateTime get _operationalBaseDate =>
      AppDateFormatter.getOperationalDate(DateTime.now());

  bool get _isOpenJoin => BookingConfirmationHandler.isOpenJoin(widget.bookingType);

  double get _slotPrice => widget.stadium.basePrice / 2;
  double get _ballPrice => widget.stadium.ballPrice > 0 ? widget.stadium.ballPrice : 0;

  double get _totalPrice {
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
    _isPrivate = !_isOpenJoin;
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
    final maxPlayers =
        widget.stadium.totalFieldCapacity > 1 ? widget.stadium.totalFieldCapacity - 1 : 1;

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
                  BookingSlotStreamSection(
                    stadiumId: widget.stadium.id,
                    stadium: widget.stadium,
                    selectedDate: _selectedDate,
                    timeSlots: _timeSlots,
                    selectedTimeSlots: List.unmodifiable(_selectedTimeSlots),
                    onSlotTap: _onTimeSlotTap,
                    onRetry: () => setState(() {}),
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
