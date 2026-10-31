import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/stadium_provider.dart';
import '../../../../core/repositories/league/team_league_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../data/models.dart';
import '../../screens/booking_confirmation_screen.dart';
import '../../screens/payment_gateway_screen.dart';
import '../../screens/tournament_registration_success_screen.dart';
import '../create_team_sheet.dart';
import 'team_league_fixtures_view.dart';
import 'team_league_gathering_card.dart';
import 'team_league_match_dialog.dart';
import 'team_league_onboarding_card.dart';
import 'team_league_standings_view.dart';

class TeamLeagueTab extends StatefulWidget {
  final Team? userTeam;
  final VoidCallback onTeamCreated;
  final bool isLoadingUserTeam;
  final bool hasUserTeamLoadError;
  final VoidCallback onRetryUserTeam;

  const TeamLeagueTab({
    super.key,
    required this.userTeam,
    required this.onTeamCreated,
    required this.isLoadingUserTeam,
    required this.hasUserTeamLoadError,
    required this.onRetryUserTeam,
  });

  @override
  State<TeamLeagueTab> createState() => _TeamLeagueTabState();
}

class _TeamLeagueTabState extends State<TeamLeagueTab> {
  final TeamLeagueRepository _leagueRepo = TeamLeagueRepository();
  bool _isLoading = true;
  bool _hasLeagueLoadError = false;
  bool _hasPaymentStatusError = false;
  int _leagueLoadGeneration = 0;
  TeamLeagueData? _leagueData;
  String _leaguePaymentStatus = 'not_created';
  double _configuredFee = 30.0;
  int _selectedSubTab = 0; // 0 = جدول المباريات, 1 = تفاصيل الدوري

  @override
  void initState() {
    super.initState();
    _loadLeague();
  }

  @override
  void didUpdateWidget(covariant TeamLeagueTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userTeam?.id != widget.userTeam?.id) {
      _loadLeague();
    }
  }

  Future<void> _loadLeague() async {
    final teamId = widget.userTeam?.id;
    final generation = ++_leagueLoadGeneration;
    if (teamId == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _leagueData = null;
          _hasLeagueLoadError = false;
          _hasPaymentStatusError = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasLeagueLoadError = false;
        _hasPaymentStatusError = false;
      });
    }
    try {
      final data = await _leagueRepo.getTeamActiveLeagueStrict(teamId);
      if (!mounted || generation != _leagueLoadGeneration || widget.userTeam?.id != teamId) return;
      final fee = await _leagueRepo.getTeamLeagueEntryFeeStrict();
      if (!mounted || generation != _leagueLoadGeneration || widget.userTeam?.id != teamId) return;
      var paymentStatus = 'not_created';
      var paymentStatusError = false;
      if (data != null) {
        try {
          final payment = await _leagueRepo.getTeamLeaguePaymentStatus(
            championshipId: data.id,
            teamId: teamId,
          );
          paymentStatus = payment['status']?.toString() ?? 'not_created';
        } catch (e) {
          // Unknown payment state must never be treated as unpaid/eligible to pay.
          debugPrint('Error loading team league payment status: $e');
          paymentStatusError = true;
        }
      }
      if (mounted && generation == _leagueLoadGeneration && widget.userTeam?.id == teamId) {
        setState(() {
          _leagueData = data;
          _leaguePaymentStatus = paymentStatus;
          _configuredFee = fee;
          _hasPaymentStatusError = paymentStatusError;
          _hasLeagueLoadError = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading team league: $e');
      if (mounted && generation == _leagueLoadGeneration && widget.userTeam?.id == teamId) {
        setState(() {
          _leagueData = null;
          _hasLeagueLoadError = true;
          _hasPaymentStatusError = false;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _payCurrentLeague() async {
    final league = _leagueData;
    final team = widget.userTeam;
    if (league == null || team == null) return;
    try {
      final payment = await _leagueRepo.joinTeamLeague(
        championshipId: league.id,
        teamId: team.id,
      );
      if (payment['prepaid_by_creator'] == true || payment['already_paid'] == true) {
        VSPFeedback.triggerSuccess();
        if (!mounted || widget.userTeam?.id != team.id) return;
        await _loadLeague();
        if (mounted && widget.userTeam?.id == team.id) {
          final isArabic = Localizations.localeOf(context).languageCode == 'ar';
          final message = payment['already_paid'] == true
              ? (isArabic ? 'رسوم مشاركة فريقك مدفوعة بالفعل.' : 'Your team participation fee is already paid.')
              : (isArabic ? 'رسوم مشاركة الفريق: مدفوعة' : 'Team participation fee is paid.');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
        return;
      }
      final reference = payment['payment_reference']?.toString();
      final amount = (payment['amount'] as num?)?.toDouble() ?? _configuredFee;
      if (reference == null || reference.isEmpty) throw Exception('تعذر إنشاء عملية الدفع');
      if (!mounted || widget.userTeam?.id != team.id) return;
      await _openLeaguePayment(paymentReference: reference, amount: amount, team: team);
    } catch (e) {
      debugPrint('Error starting team league payment: $e');
      if (mounted && widget.userTeam?.id == team.id) {
        final isArabic = Localizations.localeOf(context).languageCode == 'ar';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArabic ? 'تعذر بدء عملية الدفع. حاول مرة أخرى.' : 'Could not start payment. Please try again.'),
            backgroundColor: VSPColors.error,
          ),
        );
      }
    }
  }

  Future<void> _openLeaguePayment({required String paymentReference, required double amount, required Team team}) async {
    final now = DateTime.now();
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentGatewayScreen(
          isTournamentPayment: true,
          forceFullPayment: true,
          bookingDraft: BookingDraft(
            stadiumId: 'league_fee',
            stadiumName: Localizations.localeOf(context).languageCode == 'ar'
                ? 'دوري: رسوم مشاركة الفرق'
                : 'League: team entry fees',
            ownerId: '',
            startTime: now,
            endTime: now.add(const Duration(hours: 1)),
            bookingType: BookingType.team,
            playerTeamId: team.id,
            playerTeamName: team.name,
            isPrivate: true,
            rentBall: false,
            totalPrice: amount,
            currency: 'EGP',
            needsDeposit: false,
          ),
          existingBookingId: paymentReference,
        ),
      ),
    );
    if (mounted && widget.userTeam?.id == team.id) {
      if (result == true) {
        VSPFeedback.triggerSuccess();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TournamentRegistrationSuccessScreen(
              tournamentType: 'team_league',
              tournamentId: _leagueData?.id ?? '',
              orderReference: paymentReference,
              teamId: team.id,
              teamName: team.name,
              initialTournamentName: _leagueData?.name ?? (Localizations.localeOf(context).languageCode == 'ar' ? 'دوري الفرق' : 'Team league'),
            ),
          ),
        );
      }
      await _loadLeague();
    }
  }

  // Section 3, 4, 5: Create League Multi-Step Flow
  void _showCreateLeagueDialog() {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final nameController = TextEditingController(
      text: widget.userTeam != null
          ? (isArabic ? 'دوري ${widget.userTeam!.name}' : '${widget.userTeam!.name} League')
          : '',
    );
    int selectedMaxTeams = 4;
    int selectedIntervalDays = 7;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: EdgeInsets.only(
            top: 24,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: VSPColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(Iconsax.cup_copy, color: VSPColors.accent, size: 24),
                    SizedBox(width: 8),
                    Text(
                      isArabic ? 'إنشاء دوري' : 'Create League',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 1. League Name
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: isArabic ? 'اسم الدوري' : 'League name',
                    hintText: isArabic ? 'اكتب اسم الدوري' : 'Enter league name',
                    hintStyle: const TextStyle(color: VSPColors.textSecondary),
                    labelStyle: const TextStyle(color: VSPColors.textSecondary),
                    filled: true,
                    fillColor: VSPColors.surfaceAlt,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Number of Teams (4 to 8 Stepper / Selector)
                Text(
                  isArabic ? 'عدد الفرق المشاركة:' : 'Number of participating teams:',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [4, 5, 6, 7, 8].map((n) {
                    final isSel = selectedMaxTeams == n;
                    return InkWell(
                      onTap: () => setSheetState(() => selectedMaxTeams = n),
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                      child: Container(
                        width: 50,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSel ? VSPColors.accent : VSPColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(VSPRadius.md),
                          border: Border.all(color: isSel ? VSPColors.accent : VSPColors.divider),
                        ),
                        child: Text(
                          '$n',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSel ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // 3. League System Uneditable Card (Single Round Robin)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: VSPColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    border: Border.all(color: VSPColors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Iconsax.lock_copy, color: VSPColors.accent, size: 16),
                          SizedBox(width: 6),
                          Text(
                            isArabic ? 'نظام الدوري: دوري — دور واحد' : 'League format: Single round-robin',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        isArabic ? 'كل فريق يواجه كل فريق مرة واحدة (دوري خاص بدون ذهاب وإياب).' : 'Each team plays every other team once (single round-robin).',
                        style: TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 4. Match Scheduling Interval
                Text(
                  isArabic ? 'الفترة بين المباريات:' : 'Interval between matches:',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                const SizedBox(height: 4),
                Text(
                  isArabic ? 'VSP يحدد يوم المباراة حسب الفترة التي تختارها، والفرق تحدد الملعب والساعة.' : 'VSP sets match days from your chosen interval; teams choose the venue and kickoff time.',
                  style: TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [3, 5, 7, 10, 14].map((d) {
                    final isSel = selectedIntervalDays == d;
                    return InkWell(
                      onTap: () => setSheetState(() => selectedIntervalDays = d),
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSel ? VSPColors.accent : VSPColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(VSPRadius.md),
                          border: Border.all(color: isSel ? VSPColors.accent : VSPColors.divider),
                        ),
                        child: Text(
                          isArabic ? 'كل $d أيام' : 'Every $d days',
                          style: TextStyle(
                            color: isSel ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Next Button -> Shows Payment Options Sheet
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(isArabic ? 'يرجى كتابة اسم الدوري' : 'Enter a league name to continue.')),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    _showPaymentOptionsSheet(
                      leagueName: name,
                      maxTeams: selectedMaxTeams,
                      intervalDays: selectedIntervalDays,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VSPColors.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                  ),
                  child: Text(isArabic ? 'متابعة إلى خيارات الدفع' : 'Continue to payment options', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(nameController.dispose);
  }

  // Section 4: Payment Options Bottom Sheet
  void _showPaymentOptionsSheet({
    required String leagueName,
    required int maxTeams,
    required int intervalDays,
  }) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    String selectedPayOption = 'my_team'; // 'my_team', 'all', 'custom'
    int customPaidCount = 2;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (pCtx) => StatefulBuilder(
        builder: (context, setPSheetState) {
          final feePerTeam = _configuredFee;
          final totalForTeam = feePerTeam;
          final totalForAll = maxTeams * feePerTeam;
          final totalForCustom = customPaidCount * feePerTeam;

          return Container(
            padding: EdgeInsets.only(
              top: 24,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: VSPColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isArabic ? 'طريقة دفع رسوم الدوري' : 'League fee payment method',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isArabic
                        ? 'رسوم مشاركة الفريق: ${feePerTeam.toStringAsFixed(0)} جنيه للفريق الواحد'
                        : 'Team entry fee: ${feePerTeam.toStringAsFixed(0)} EGP per team',
                    style: TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 16),

                  // OPTION A: Pay for your team only
                  _buildPaymentOptionCard(
                    title: isArabic ? 'ادفع لفريقك' : 'Pay for your team',
                    subtitle: isArabic
                        ? '${feePerTeam.toStringAsFixed(0)} جنيه — رسوم مشاركة فريقك'
                        : '${feePerTeam.toStringAsFixed(0)} EGP — your team entry fee',
                    costText: '${totalForTeam.toStringAsFixed(0)} ${isArabic ? 'جنيه' : 'EGP'}',
                    isSelected: selectedPayOption == 'my_team',
                    onTap: () => setPSheetState(() => selectedPayOption = 'my_team'),
                  ),
                  const SizedBox(height: 10),

                  // OPTION B: Pay for the whole league
                  _buildPaymentOptionCard(
                    title: isArabic ? 'ادفع للدوري كله' : 'Pay for the entire league',
                    subtitle: isArabic
                        ? 'ادفع رسوم جميع الفرق ($maxTeams فرق × ${feePerTeam.toStringAsFixed(0)} جنيه)'
                        : 'Pay for all teams ($maxTeams × ${feePerTeam.toStringAsFixed(0)} EGP)',
                    costText: '${totalForAll.toStringAsFixed(0)} ${isArabic ? 'جنيه' : 'EGP'}',
                    isSelected: selectedPayOption == 'all',
                    onTap: () => setPSheetState(() => selectedPayOption = 'all'),
                  ),
                  const SizedBox(height: 10),

                  // OPTION C: Pay for a custom number of teams
                  _buildPaymentOptionCard(
                    title: isArabic ? 'ادفع لعدد محدد من الفرق' : 'Pay for a selected number of teams',
                    subtitle: isArabic
                        ? '$customPaidCount فرق × ${feePerTeam.toStringAsFixed(0)} جنيه = ${totalForCustom.toStringAsFixed(0)} جنيه'
                        : '$customPaidCount teams × ${feePerTeam.toStringAsFixed(0)} EGP = ${totalForCustom.toStringAsFixed(0)} EGP',
                    costText: '${totalForCustom.toStringAsFixed(0)} ${isArabic ? 'جنيه' : 'EGP'}',
                    isSelected: selectedPayOption == 'custom',
                    onTap: () => setPSheetState(() => selectedPayOption = 'custom'),
                  ),

                  // Custom Count Stepper if Option C selected
                  if (selectedPayOption == 'custom') ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: VSPColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(VSPRadius.md),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(isArabic ? 'عدد الفرق التي ستدفع عنها:' : 'Number of teams to pay for:', style: const TextStyle(color: Colors.white, fontSize: 13)),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Iconsax.minus_cirlce_copy, color: VSPColors.accent),
                                onPressed: customPaidCount > 1
                                    ? () => setPSheetState(() => customPaidCount--)
                                    : null,
                              ),
                              Text('$customPaidCount', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              IconButton(
                                icon: const Icon(Iconsax.add_circle_copy, color: VSPColors.accent),
                                onPressed: customPaidCount < maxTeams
                                    ? () => setPSheetState(() => customPaidCount++)
                                    : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Submit Payment and Create League
                  ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            setPSheetState(() => isSubmitting = true);
                            try {
                              final result = await _leagueRepo.createTeamLeague(
                                teamId: widget.userTeam!.id,
                                leagueName: leagueName,
                                maxTeams: maxTeams,
                                intervalDays: intervalDays,
                                payOption: selectedPayOption,
                                customPaidCount: customPaidCount,
                              );
                              final ref = result['payment_reference']?.toString();
                              final amount = (result['amount'] as num?)?.toDouble() ?? 30.0;
                              if (pCtx.mounted) Navigator.pop(pCtx);
                              if (ref != null && ref.isNotEmpty) {
                                await _openLeaguePayment(paymentReference: ref, amount: amount, team: widget.userTeam!);
                              } else {
                                await _loadLeague();
                              }
                            } catch (e, stackTrace) {
                              debugPrint('Team league creation/payment setup failed: $e\n$stackTrace');
                              if (pCtx.mounted) {
                                setPSheetState(() => isSubmitting = false);
                                ScaffoldMessenger.of(pCtx).showSnackBar(SnackBar(
                                  content: Text(isArabic
                                      ? 'تعذر إنشاء الدوري وتجهيز الدفع. حاول مرة أخرى.'
                                      : 'Could not create the league or prepare payment. Please retry.'),
                                ));
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VSPColors.accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                    ),
                    child: isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : Text(
                            selectedPayOption == 'my_team'
                                ? (isArabic ? 'ادفع ${totalForTeam.toStringAsFixed(0)} جنيه' : 'Pay ${totalForTeam.toStringAsFixed(0)} EGP')
                                : selectedPayOption == 'all'
                                    ? (isArabic ? 'ادفع ${totalForAll.toStringAsFixed(0)} جنيه' : 'Pay ${totalForAll.toStringAsFixed(0)} EGP')
                                    : (isArabic ? 'ادفع ${totalForCustom.toStringAsFixed(0)} جنيه' : 'Pay ${totalForCustom.toStringAsFixed(0)} EGP'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaymentOptionCard({
    required String title,
    required String subtitle,
    required String costText,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(VSPRadius.md),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? VSPColors.accent.withValues(alpha: 0.15) : VSPColors.surfaceAlt,
          borderRadius: BorderRadius.circular(VSPRadius.md),
          border: Border.all(
            color: isSelected ? VSPColors.accent : VSPColors.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Iconsax.tick_circle_copy : Iconsax.record_copy,
              color: isSelected ? VSPColors.accent : VSPColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11.5)),
                ],
              ),
            ),
            Text(costText, style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  void _showJoinLeagueDialog() {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final codeController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: VSPColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.82,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(VSPSpacing.lg),
                child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isArabic ? 'الانضمام لدوري عبر دعوة / كود' : 'Join a league by invite code',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                ),
                const SizedBox(height: 8),
                Text(
                  isArabic ? 'الدوري خاص، أدخل كود الدوري للانضمام' : 'This league is private. Enter its code to join.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: codeController,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: isArabic ? 'كود أو معرف الدوري' : 'League code or ID',
                    labelStyle: const TextStyle(color: VSPColors.textSecondary),
                    filled: true,
                    fillColor: VSPColors.surfaceAlt,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                  ),
                ),

                const SizedBox(height: 12),
                Text(
                  isArabic
                      ? 'رسوم مشاركة الفريق: ${_configuredFee.toStringAsFixed(0)} جنيه للفريق الواحد'
                      : 'Team entry fee: ${_configuredFee.toStringAsFixed(0)} EGP per team',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: VSPColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: VSPColors.textSecondary,
                          side: const BorderSide(color: VSPColors.borderLight),
                        ),
                        child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final code = codeController.text.trim();
                                if (code.isEmpty) return;

                                final messenger = ScaffoldMessenger.of(context);
                                setDialogState(() => isSubmitting = true);
                                try {
                                  final result = await _leagueRepo.joinTeamLeague(
                                    championshipId: code,
                                    teamId: widget.userTeam!.id,
                                  );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (result['prepaid_by_creator'] == true) {
                                    VSPFeedback.triggerSuccess();
                                    await _loadLeague();
                                    messenger.showSnackBar(
                                      SnackBar(content: Text(isArabic ? 'رسوم مشاركة الفريق: مدفوعة' : 'Team entry fee has already been paid.')),
                                    );
                                    return;
                                  }
                                  final paymentReference = result['payment_reference']?.toString();
                                  final amount = (result['amount'] as num?)?.toDouble() ?? _configuredFee;
                                  if (paymentReference != null && paymentReference.isNotEmpty) {
                                    await _openLeaguePayment(paymentReference: paymentReference, amount: amount, team: widget.userTeam!);
                                  } else {
                                    await _loadLeague();
                                  }
                                } catch (e, stackTrace) {
                                  debugPrint('Joining team league failed: $e\n$stackTrace');
                                  if (ctx.mounted) {
                                    setDialogState(() => isSubmitting = false);
                                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                      content: Text(isArabic
                                          ? 'تعذر الانضمام للدوري. تحقق من الكود وحاول مرة أخرى.'
                                          : 'Could not join the league. Check the code and try again.'),
                                    ));
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VSPColors.accent,
                          foregroundColor: VSPColors.background,
                        ),
                        child: isSubmitting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                            : Text(isArabic ? 'انضمام' : 'Join', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
                ),
              ),
            ),
          ),
        ),
      ),
    ).whenComplete(codeController.dispose);
  }

  void _onBookMatch(TeamLeagueMatch match) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final stadiumProvider = Provider.of<StadiumProvider>(context, listen: false);
    final stadiums = stadiumProvider.allStadiums;

    if (stadiums.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isArabic ? 'لا توجد ملاعب متاحة حالياً للحجز' : 'No stadiums are currently available for booking.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: VSPColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
        ),
        padding: EdgeInsets.fromLTRB(VSPSpacing.md, VSPSpacing.md, VSPSpacing.md, VSPSpacing.md + MediaQuery.of(ctx).padding.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Iconsax.building_copy, color: VSPColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isArabic
                        ? 'اختر ملعب لمباراة: ${match.homeTeamName} × ${match.awayTeamName}'
                        : 'Choose a stadium for: ${match.homeTeamName} vs ${match.awayTeamName}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                IconButton(
                  icon: const Icon(Iconsax.close_circle_copy, color: VSPColors.textSecondary),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(color: VSPColors.divider),
            Expanded(
              child: ListView.separated(
                itemCount: stadiums.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final stadium = stadiums[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: VSPColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                    ),
                    child: ListTile(
                      title: Text(
                        stadium.name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        isArabic
                            ? '${stadium.governorate} • ${stadium.basePrice.toStringAsFixed(0)} ج.م/ساعة'
                            : '${stadium.governorate} • ${stadium.basePrice.toStringAsFixed(0)} EGP/hour',
                        style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                      ),
                      trailing: const Icon(Iconsax.arrow_left_2_copy, color: VSPColors.accent, size: 18),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final bookingRes = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BookingConfirmationScreen(
                              stadium: stadium,
                              bookingType: 'Team',
                            ),
                          ),
                        );

                        if (bookingRes != null && bookingRes is Booking) {
                          await _leagueRepo.linkLeagueMatchBooking(
                            matchId: match.id,
                            bookingId: bookingRes.id,
                            scheduledTime: bookingRes.startTime,
                            stadiumName: stadium.name,
                          );
                          VSPFeedback.triggerSuccess();
                          await _loadLeague();
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Section 10: Non-numerical Result Submission
  void _onRecordScore(TeamLeagueMatch match) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TeamLeagueMatchResultSheet(
        match: match,
        userTeamId: widget.userTeam!.id,
        onSubmitResult: (result) async {
          await _leagueRepo.submitMatchResult(
            matchId: match.id,
            teamId: widget.userTeam!.id,
            result: result,
          );
          VSPFeedback.triggerSuccess();
          await _loadLeague();
        },
      ),
    );
  }

  // Section 17: Creator Dispute Resolution
  void _onResolveDispute(TeamLeagueMatch match) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TeamLeagueDisputeResolutionSheet(
        match: match,
        onResolveDispute: (resolution) async {
          await _leagueRepo.resolveDispute(
            matchId: match.id,
            resolution: resolution,
          );
          VSPFeedback.triggerSuccess();
          await _loadLeague();
        },
      ),
    );
  }

  Future<void> _cancelLeague(String leagueId) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        backgroundColor: VSPColors.surface,
        title: Text(isArabic ? 'إلغاء الدوري' : 'Cancel league', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          isArabic
              ? 'هل أنت متأكد من إلغاء هذا الدوري؟ ستتم مراجعة المبالغ المؤهلة للاسترداد وفق سياسة الاسترداد. المصاريف الإدارية غير قابلة للاسترداد.'
              : 'Are you sure you want to cancel this league? Only amounts eligible under the refund policy will be reviewed for refund. Administrative fees are non-refundable.',
          style: const TextStyle(color: VSPColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isArabic ? 'تراجع' : 'Go back')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: VSPColors.error),
            child: Text(isArabic ? 'نعم، إلغاء' : 'Yes, cancel', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _leagueRepo.cancelTeamLeague(leagueId);
        VSPFeedback.triggerSuccess();
        await _loadLeague();
      } catch (e, stackTrace) {
        debugPrint('Team league cancellation failed: $e\\n$stackTrace');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isArabic
                ? 'تعذر إلغاء الدوري. حاول مرة أخرى.'
                : 'Could not cancel the league. Please try again.'),
          ));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    // A failed or unfinished membership query is not equivalent to no team.
    if (widget.isLoadingUserTeam) {
      return const Center(
        child: CircularProgressIndicator(color: VSPColors.accent),
      );
    }
    if (widget.hasUserTeamLoadError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(VSPSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isArabic ? 'تعذر تحميل بيانات فريقك' : 'Could not load your team',
                textAlign: TextAlign.center,
                style: const TextStyle(color: VSPColors.textSecondary),
              ),
              const SizedBox(height: VSPSpacing.md),
              TextButton(
                onPressed: widget.onRetryUserTeam,
                child: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // 1. If player has no team
    if (widget.userTeam == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(VSPSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Iconsax.people_copy, size: 72, color: VSPColors.accent.withValues(alpha: 0.3)),
              const SizedBox(height: VSPSpacing.md),
              Text(isArabic ? 'ليس لديك فريق حالياً' : 'You are not in a team yet', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 6),
              Text(
                isArabic
                    ? 'الدوري يتطلب وجود فريق للمشاركة والمنافسة على اللقب.'
                    : 'You need a team to join a league and compete for the title.',
                textAlign: TextAlign.center,
                style: TextStyle(color: VSPColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: VSPSpacing.xl),
              ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => const CreateTeamSheet(),
                  ).then((_) => widget.onTeamCreated());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: VSPColors.accent,
                  foregroundColor: VSPColors.background,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                ),
                child: Text(isArabic ? 'إنشاء فريق جديد' : 'Create a team', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ],
          ),
        ),
      );
    }

    // 2. Loading state
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
    }

    if (_hasLeagueLoadError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(VSPSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isArabic ? 'تعذر تحميل بيانات الدوري' : 'Could not load league data',
                textAlign: TextAlign.center,
                style: const TextStyle(color: VSPColors.textSecondary),
              ),
              const SizedBox(height: VSPSpacing.md),
              TextButton(
                onPressed: _loadLeague,
                child: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final league = _leagueData;

    // 3. Not in any league -> Show onboarding card
    if (league == null) {
      return RefreshIndicator(
        onRefresh: _loadLeague,
        color: VSPColors.accent,
        backgroundColor: VSPColors.surface,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            TeamLeagueOnboardingCard(
              entryFee: _configuredFee,
              onCreateLeague: _showCreateLeagueDialog,
              onJoinLeague: _showJoinLeagueDialog,
            ),
          ],
        ),
      );
    }

    // 4. Gathering state (1 to N-1 teams)
    if (league.status == 'open') {
      return RefreshIndicator(
        onRefresh: _loadLeague,
        color: VSPColors.accent,
        backgroundColor: VSPColors.surface,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (_hasPaymentStatusError)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        isArabic
                            ? 'تعذر التحقق من حالة رسوم الفريق. أعد المحاولة قبل الدفع.'
                            : 'Could not verify the team fee status. Retry before paying.',
                        style: const TextStyle(color: VSPColors.warning, fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: _loadLeague,
                      child: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
                    ),
                  ],
                ),
              ),
            TeamLeagueGatheringCard(
              league: league,
              entryFee: _hasPaymentStatusError ? null : _configuredFee,
              onRefresh: _loadLeague,
              onCancelLeague: () => _cancelLeague(league.id),
              onPayFee: (_hasPaymentStatusError || _leaguePaymentStatus == 'paid')
                  ? null
                  : _payCurrentLeague,
            ),
          ],
        ),
      );
    }

    // 5. Ongoing or Completed League (Section 7: Exactly 2 tabs: [ جدول المباريات ] [ تفاصيل الدوري ])
    return RefreshIndicator(
      onRefresh: _loadLeague,
      color: VSPColors.accent,
      backgroundColor: VSPColors.surface,
      child: Column(
        children: [
          // Sub-pill switcher: Exactly two tabs (Section 7)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: VSPColors.surfaceAlt,
                borderRadius: BorderRadius.circular(21),
                border: Border.all(color: VSPColors.divider, width: 0.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedSubTab = 0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _selectedSubTab == 0 ? VSPColors.accent : Colors.transparent,
                          borderRadius: BorderRadius.circular(21),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          isArabic ? 'جدول المباريات' : 'Fixtures',
                          style: TextStyle(
                            color: _selectedSubTab == 0 ? Colors.black : VSPColors.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedSubTab = 1),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _selectedSubTab == 1 ? VSPColors.accent : Colors.transparent,
                          borderRadius: BorderRadius.circular(21),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          isArabic ? 'تفاصيل الدوري' : 'League details',
                          style: TextStyle(
                            color: _selectedSubTab == 1 ? Colors.black : VSPColors.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content view
          Expanded(
            child: _selectedSubTab == 0
                ? TeamLeagueFixturesView(
                    matches: league.matches,
                    userTeamId: widget.userTeam!.id,
                    isCreator: league.isCreator,
                    onBookMatch: _onBookMatch,
                    onRecordScore: _onRecordScore,
                    onResolveDispute: _onResolveDispute,
                  )
                : TeamLeagueDetailsView(
                    league: league,
                    userTeamId: widget.userTeam!.id,
                  ),
          ),
        ],
      ),
    );
  }
}
