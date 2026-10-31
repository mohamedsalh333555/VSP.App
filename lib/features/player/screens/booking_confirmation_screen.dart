import 'package:flutter/material.dart';
import '../../../core/ui/vsp_ui.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/team_repository.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/app_date_formatter.dart';
import '../../../core/utils/vsp_feedback.dart';
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
  bool _isLoadingUserTeam = true;
  bool _hasUserTeamLoadError = false;
  String? _activeUserTeamScope;
  bool _hasObservedUserTeamScope = false;
  int _userTeamRequestGeneration = 0;
  final int _currentPlayers = 1;
  int _initialPlayersCount = 1;
  String? _userTeamId;
  String? _userTeamName;
  List<TimeSlotItem> _timeSlots = [];
  bool _isSlotsInitialized = false;

  DateTime get _operationalBaseDate =>
      AppDateFormatter.getOperationalDate(DateTime.now());

  bool get _isOpenJoin => BookingConfirmationHandler.isOpenJoin(widget.bookingType);
  bool get _requiresTeamContext => widget.bookingType.toLowerCase().contains('team') ||
      BookingConfirmationHandler.isChallenge(widget.bookingType);

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

  Future<void> _fetchUserTeam() {
    final userId = context.read<AuthProvider>().currentUser?.id;
    return _fetchUserTeamFor(userId);
  }

  Future<void> _fetchUserTeamFor(String? userId) async {
    if (userId != null && context.read<AuthProvider>().currentUser?.id != userId) return;
    final generation = ++_userTeamRequestGeneration;
    if (userId == null) {
      if (mounted) {
        setState(() {
          _isLoadingUserTeam = false;
          _userTeamId = null;
          _userTeamName = null;
          _hasUserTeamLoadError = false;
        });
      }
      return;
    }

    if (mounted && !_isLoadingUserTeam) {
      setState(() {
        _isLoadingUserTeam = true;
        _hasUserTeamLoadError = false;
      });
    }
    try {
      final team = await TeamRepository().getUserTeamStrict(userId);
      if (mounted &&
          generation == _userTeamRequestGeneration &&
          context.read<AuthProvider>().currentUser?.id == userId) {
        setState(() {
          _userTeamId = team?.id;
          _userTeamName = team?.name;
          _isLoadingUserTeam = false;
          _hasUserTeamLoadError = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading booking team context: $e');
      if (mounted &&
          generation == _userTeamRequestGeneration &&
          context.read<AuthProvider>().currentUser?.id == userId) {
        setState(() {
          _userTeamId = null;
          _userTeamName = null;
          _isLoadingUserTeam = false;
          _hasUserTeamLoadError = true;
        });
      }
    }
  }

  Future<void> _handleBookingConfirmation() async {
    if (_requiresTeamContext && _isLoadingUserTeam) {
      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
      VSPFeedback.showInfo(
        context,
        isArabic ? 'جارٍ التحقق من بيانات فريقك. حاول بعد لحظات.' : 'Your team is still being verified. Try again in a moment.',
      );
      return;
    }
    if (_requiresTeamContext && _userTeamId == null) {
      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
      if (_hasUserTeamLoadError) {
        VSPFeedback.showError(
          context,
          isArabic ? 'تعذر التحقق من بيانات فريقك. أعد المحاولة الآن.' : 'Could not verify your team. Retrying now.',
        );
        await _fetchUserTeam();
      } else {
        VSPFeedback.showError(
          context,
          isArabic ? 'يجب أن تنضم إلى فريق قبل إنشاء هذا الحجز.' : 'Join a team before creating this booking.',
        );
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
    final maxPlayers =
        widget.stadium.totalFieldCapacity > 1 ? widget.stadium.totalFieldCapacity - 1 : 1;

    return VSPScaffold(
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, VSPSpacing.xl),
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
        isPrivate: _isOpenJoin ? true : _isPrivate,
        onPrivateChanged: (_) {},
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
        isLoading: _isLoading || (_requiresTeamContext && _isLoadingUserTeam),
        onConfirmPressed: _handleBookingConfirmation,
      ),
    );
  }
}
