import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/tournament_repository.dart';
import '../../../core/repositories/user_repository.dart';
import '../../../core/services/paymob_service.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/roster_parser_utils.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../data/models.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/vsp_back_button.dart';
import '../widgets/championship_checkout/checkout_championship_header.dart';
import '../widgets/championship_checkout/checkout_financial_card.dart';
import '../widgets/championship_checkout/checkout_guest_players_section.dart';
import '../widgets/championship_checkout/checkout_squad_requirement_card.dart';
import '../widgets/championship_checkout/checkout_team_members_list.dart';
import 'payment_gateway_screen.dart';

class ChampionshipCheckoutScreen extends StatefulWidget {
  final Championship championship;
  final Team team;

  const ChampionshipCheckoutScreen({
    super.key,
    required this.championship,
    required this.team,
  });

  @override
  State<ChampionshipCheckoutScreen> createState() => _ChampionshipCheckoutScreenState();
}

class _ChampionshipCheckoutScreenState extends State<ChampionshipCheckoutScreen> {
  final List<String> _selectedPlayerIds = [];
  final List<String> _offlineGuestNames = [];
  final TextEditingController _guestController = TextEditingController();

  List<Map<String, dynamic>> _teamMembers = [];
  bool _isLoadingMembers = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadTeamMembers();
  }

  @override
  void dispose() {
    _guestController.dispose();
    super.dispose();
  }

  Future<void> _loadTeamMembers() async {
    try {
      final response = await UserRepository().getUserSummariesByIds(widget.team.memberUids);
      _teamMembers = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading team members: $e');
    }

    for (final uid in widget.team.memberUids) {
      if (!_teamMembers.any((m) => m['id'] == uid)) {
        _teamMembers.add({
          'id': uid,
          'name': uid == widget.team.captainName ? widget.team.captainName : 'لاعب ${_teamMembers.length + 1}',
          'profile_image_url': '',
        });
      }
    }

    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.currentUser?.uid;

    if (currentUserId != null && widget.team.memberUids.contains(currentUserId)) {
      if (!_selectedPlayerIds.contains(currentUserId)) {
        _selectedPlayerIds.add(currentUserId);
      }
    } else if (widget.team.memberUids.isNotEmpty) {
      _selectedPlayerIds.add(widget.team.memberUids.first);
    }

    if (mounted) {
      setState(() => _isLoadingMembers = false);
    }
  }

  void _addGuestPlayer() {
    final name = _guestController.text.trim();
    if (name.isEmpty) return;
    if (_offlineGuestNames.contains(name)) return;

    final maxPlayers = widget.championship.maxPlayersPerTeam;
    if (_selectedPlayerIds.length + _offlineGuestNames.length >= maxPlayers) {
      VSPFeedback.showError(context, 'تجاوزت الحد الأقصى للاعبين ($maxPlayers لاعبين)!');
      return;
    }

    setState(() {
      _offlineGuestNames.add(name);
      _guestController.clear();
    });
  }

  Future<void> _pasteFromWhatsApp() async {
    final parsedNames = await RosterParserUtils.showImportSquadDialog(context);
    if (parsedNames.isEmpty) {
      if (mounted) VSPFeedback.showError(context, 'لم يتم العثور على أسماء واضحة في النص الملصوق.');
      return;
    }

    final maxPlayers = widget.championship.maxPlayersPerTeam;
    int addedCount = 0;

    setState(() {
      for (final name in parsedNames) {
        if (_selectedPlayerIds.length + _offlineGuestNames.length >= maxPlayers) break;
        if (!_offlineGuestNames.contains(name)) {
          _offlineGuestNames.add(name);
          addedCount++;
        }
      }
    });

    if (addedCount > 0 && mounted) {
      HapticFeedback.mediumImpact();
      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
      VSPFeedback.showSuccess(
        context,
        isArabic
            ? 'تمت إضافة $addedCount لاعبين من نص التشكيلة بنجاح! '
            : 'Successfully added $addedCount players from WhatsApp text! ',
      );
    }
  }

  Future<void> _handleConfirmAndPay() async {
    if (_isSubmitting) return;

    final minPlayers = widget.championship.minPlayersPerTeam;
    final maxPlayers = widget.championship.maxPlayersPerTeam;
    final totalCount = _selectedPlayerIds.length + _offlineGuestNames.length;

    if (totalCount < minPlayers) {
      VSPFeedback.showError(context, 'يرجى اختيار $minPlayers لاعبين على الأقل للتشكيلة.');
      return;
    }
    if (totalCount > maxPlayers) {
      VSPFeedback.showError(context, 'التشكيلة تجاوزت الحد الأقصى ($maxPlayers لاعبين).');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // فحص تكرار اللاعبين في فرق أخرى بالبطولة
      final duplicatePlayers = await TournamentRepository().checkDuplicatePlayersInChampionship(
        championshipId: widget.championship.id,
        currentTeamId: widget.team.id,
        playerIds: _selectedPlayerIds,
        guestNames: _offlineGuestNames,
      );

      if (duplicatePlayers.isNotEmpty) {
        if (mounted) {
          final isArabic = Localizations.localeOf(context).languageCode == 'ar';
          final dupNamesStr = duplicatePlayers.join('، ');
          VSPFeedback.showError(
            context,
            isArabic
                ? 'عذراً! اللاعبون التالي أسماؤهم مسجلون بالفعل في فرق أخرى داخل هذه البطولة: ($dupNamesStr). يرجى تعديل التشكيلة أولاً.'
                : 'The following players are already registered in other teams for this tournament: ($dupNamesStr). Please adjust your roster.',
          );
        }
        return;
      }

      final entryFee = widget.championship.entryFee;

      if (entryFee > 0) {
        final draft = BookingDraft(
          stadiumId: '00000000-0000-0000-0000-000000000000',
          stadiumName: 'بطولة: ${widget.championship.name}',
          stadiumImageUrl: widget.championship.logoUrl,
          ownerId: widget.championship.ownerId,
          startTime: widget.championship.startDate,
          endTime: widget.championship.endDate,
          bookingType: BookingType.team,
          playerTeamId: widget.team.id,
          playerTeamName: widget.team.name,
          totalPrice: entryFee,
          isPaid: false,
          isPrivate: false,
          rentBall: false,
          currentPlayers: totalCount,
          totalFieldCapacity: maxPlayers,
          depositPaid: entryFee,
          isDepositPaid: false,
          needsDeposit: true,
        );

        if (mounted) {
          final paymentResult = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentGatewayScreen(
                bookingDraft: draft,
                forceFullPayment: true,
                isTournamentPayment: true,
              ),
            ),
          );

          if (paymentResult == true && mounted) {
            await _executeJoinChampionship();
          }
          return;
        }
      }

      await _executeJoinChampionship();
    } catch (e) {
      if (mounted) {
        VSPFeedback.showError(context, 'حدث خطأ أثناء الاشتراك: $e');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _executeJoinChampionship() async {
    final entryFee = widget.championship.entryFee;
    // DUP-FIX: استخدام الدالة المركزية لحساب المبلغ الإجمالي مع العمولة
    final totalCheckoutPrice = PaymobService.calculateTotalAmount(entryFee);

    final success = await TournamentRepository().joinChampionship(
      widget.championship.id,
      widget.team.id,
      selectedPlayerIds: _selectedPlayerIds,
      offlineGuestNames: _offlineGuestNames,
      isPaid: true,
      totalPaidAmount: totalCheckoutPrice,
    );

    if (success && mounted) {
      VSPFeedback.showSuccess(context, 'تم الاشتراك في البطولة بنجاح! ');
      Navigator.pop(context, true);
    } else if (mounted) {
      VSPFeedback.showError(context, 'فشل الانضمام للبطولة، يرجى المحاولة مرة أخرى.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final captainId = auth.currentUser?.uid ?? widget.team.captainName;

    final minPlayers = widget.championship.minPlayersPerTeam;
    final maxPlayers = widget.championship.maxPlayersPerTeam;
    final totalCount = _selectedPlayerIds.length + _offlineGuestNames.length;
    final isSelectionValid = totalCount >= minPlayers && totalCount <= maxPlayers;

    final entryFee = widget.championship.entryFee;
    final serviceFee = PaymobService.calculateServiceFee(entryFee);
    final totalCheckoutPrice = PaymobService.calculateTotalAmount(entryFee);

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        leading: const VSPBackButton(),
        centerTitle: true,
        title: Text(
          'التسجيل في البطولة',
          style: Theme.of(context).textTheme.displaySmall,
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(VSPSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Championship Summary Header Card
            CheckoutChampionshipHeader(
              championship: widget.championship,
              team: widget.team,
            ),
            const SizedBox(height: VSPSpacing.lg),

            // 2. Squad Selection Requirement Header
            CheckoutSquadRequirementCard(
              totalCount: totalCount,
              minPlayers: minPlayers,
              maxPlayers: maxPlayers,
              isSelectionValid: isSelectionValid,
            ),
            const SizedBox(height: VSPSpacing.md),

            // 3. Team Roster Selection List
            CheckoutTeamMembersList(
              teamMembers: _teamMembers,
              selectedPlayerIds: _selectedPlayerIds,
              isLoading: _isLoadingMembers,
              captainId: captainId,
              onTogglePlayer: (memberId) {
                setState(() {
                  if (_selectedPlayerIds.contains(memberId)) {
                    _selectedPlayerIds.remove(memberId);
                  } else {
                    _selectedPlayerIds.add(memberId);
                  }
                });
              },
            ),
            const SizedBox(height: VSPSpacing.lg),

            // 4. Add Guest Players Section
            CheckoutGuestPlayersSection(
              guestController: _guestController,
              offlineGuestNames: _offlineGuestNames,
              minPlayers: minPlayers,
              totalCount: totalCount,
              onAddGuest: _addGuestPlayer,
              onPasteFromWhatsApp: _pasteFromWhatsApp,
              onRemoveGuest: (name) => setState(() => _offlineGuestNames.remove(name)),
            ),
            const SizedBox(height: VSPSpacing.xl),

            // 5. Financial Breakdown Card
            CheckoutFinancialCard(
              entryFee: entryFee,
              serviceFee: serviceFee,
              totalCheckoutPrice: totalCheckoutPrice,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),

      // Sticky Bottom Navigation Action Bar
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          VSPSpacing.lg,
          VSPSpacing.sm,
          VSPSpacing.lg,
          MediaQuery.of(context).padding.bottom + VSPSpacing.sm,
        ),
        decoration: const BoxDecoration(
          color: VSPColors.surface,
          border: Border(top: BorderSide(color: VSPColors.divider, width: 0.5)),
        ),
        child: PrimaryButton(
          text: entryFee > 0
              ? (isArabic ? 'الانتقال للدفع الآمن' : 'Proceed to Secure Payment')
              : (isArabic ? 'تأكيد الاشتراك في البطولة' : 'Confirm Registration'),
          isLoading: _isSubmitting,
          onPressed: isSelectionValid ? _handleConfirmAndPay : null,
        ),
      ),
    );
  }
}
