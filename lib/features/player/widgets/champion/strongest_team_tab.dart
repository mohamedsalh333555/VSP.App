import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/repositories/gamification_repository.dart';
import '../../../../core/repositories/team_repository.dart';
import '../../../../core/repositories/user_repository.dart';
import '../../../../core/services/paymob_service.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../data/models/team_gamification_models.dart';
import '../../../../data/models/team_models.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/vsp_error_state.dart';
import '../../screens/paymob_web_view_screen.dart';

/// Official VSP Strongest Team Championship Tab (Replaces legacy 1vs1 tab).
/// - 4 Teams per event, 5 players per team including 1 goalkeeper.
/// - 5 skill tests (Speed, Moving Ball Shooting, Penalties, First Touch, Final 1v1).
/// - XP Rewards: 1st=1400, 2nd=1100, 3rd=800, 4th=600 (independent from Ranking).
class StrongestTeamTab extends StatefulWidget {
  final String selectedLocation;
  final VoidCallback onRetry;

  const StrongestTeamTab({
    super.key,
    required this.selectedLocation,
    required this.onRetry,
  });

  @override
  State<StrongestTeamTab> createState() => _StrongestTeamTabState();
}

class _StrongestTeamTabState extends State<StrongestTeamTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _isLoading = true;
  String? _error;
  List<StrongestTeamEvent> _events = const [];
  List<Team> _myCaptainTeams = const [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant StrongestTeamTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedLocation != widget.selectedLocation) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final uid = auth.currentUser?.uid;
      final events = await GamificationRepository.instance.getStrongestTeamEvents(
        governorate: widget.selectedLocation,
      );
      List<Team> myTeams = const [];
      if (uid != null && uid.isNotEmpty) {
        final allMy = await TeamRepository().getTeamsForUser(uid);
        myTeams = allMy.where((t) => t.captainId == uid).toList();
      }
      if (!mounted) return;
      setState(() {
        _events = events;
        _myCaptainTeams = myTeams;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openRegistrationModal(BuildContext context, StrongestTeamEvent event, bool isArabic) async {
    if (_myCaptainTeams.isEmpty) {
      VSPFeedback.showWarning(
        context,
        isArabic ? 'يجب أن تكون كابتن فريق لتسجيل فريقك في البطولة.' : 'You must be a team captain to register.',
      );
      return;
    }
    Team selectedTeam = _myCaptainTeams.first;
    if (selectedTeam.memberUids.length < 5) {
      VSPFeedback.showWarning(
        context,
        isArabic ? 'يجب أن يضم الفريق 5 أعضاء على الأقل للمشاركة في بطولة أقوى فريق.' : 'Team needs at least 5 members to register.',
      );
      return;
    }

    final memberData = await UserRepository().getUsersByIds(selectedTeam.memberUids);
    if (!context.mounted) return;

    final Set<String> selectedIds = {};
    String? gkId;
    bool isSubmitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: VSPColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isValid = selectedIds.length == 5 && gkId != null && selectedIds.contains(gkId);
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).padding.bottom + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? 'تسجيل فريق ${selectedTeam.name}' : 'Register ${selectedTeam.name}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: VSPColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    border: Border.all(color: VSPColors.info.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    isArabic
                        ? 'اختر خمسة لاعبين من فريقك للمشاركة في البطولة، على أن يكون من بينهم حارس مرمى. توجد جائزة خاصة لأفضل حارس مرمى.'
                        : 'Select exactly 5 players from your team, including a goalkeeper. There is a special award for Best Goalkeeper.',
                    style: const TextStyle(color: VSPColors.info, fontSize: 12, height: 1.4),
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: memberData.length,
                    itemBuilder: (_, i) {
                      final u = memberData[i];
                      final isSelected = selectedIds.contains(u.uid);
                      final isGk = gkId == u.uid;
                      return CheckboxListTile(
                        value: isSelected,
                        activeColor: VSPColors.textPrimary,
                        checkColor: Colors.black,
                        title: Text(u.name ?? u.email, style: const TextStyle(color: Colors.white, fontSize: 13.5)),
                        subtitle: isSelected
                            ? GestureDetector(
                                onTap: () => setModalState(() => gkId = u.uid),
                                child: Text(
                                  isGk
                                      ? (isArabic ? '🧤 حارس المرمى المختار' : '🧤 Selected Goalkeeper')
                                      : (isArabic ? 'اضغط لتعيينه حارس مرمى' : 'Tap to set as Goalkeeper'),
                                  style: TextStyle(
                                    color: isGk ? VSPColors.warning : VSPColors.textSecondary,
                                    fontSize: 11.5,
                                    fontWeight: isGk ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              )
                            : null,
                        onChanged: (val) {
                          setModalState(() {
                            if (val == true) {
                              if (selectedIds.length < 5) {
                                selectedIds.add(u.uid);
                              }
                            } else {
                              selectedIds.remove(u.uid);
                              if (gkId == u.uid) gkId = null;
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  text: event.entryFeeEgp > 0
                      ? (isArabic ? 'تأكيد ودفع ${event.entryFeeEgp.toStringAsFixed(0)} ج.م' : 'Confirm & Pay ${event.entryFeeEgp.toStringAsFixed(0)} EGP')
                      : (isArabic ? 'تأكيد التسجيل مجاناً' : 'Confirm Free Registration'),
                  isLoading: isSubmitting,
                  onPressed: (!isValid || isSubmitting)
                      ? null
                      : () async {
                          final auth = Provider.of<AuthProvider>(context, listen: false);
                          final user = auth.userModel;
                          setModalState(() => isSubmitting = true);
                          try {
                            final res = await GamificationRepository.instance.joinStrongestTeamEvent(
                              eventId: event.id,
                              teamId: selectedTeam.id,
                              selectedPlayerIds: selectedIds.toList(),
                              goalkeeperUserId: gkId!,
                            );
                            if (res['success'] != true) {
                              throw Exception(res['error']?.toString() ?? 'Registration failed');
                            }
                            if (res['requires_payment'] == true) {
                              final orderRef = res['order_reference'].toString();
                              final amount = (res['amount'] as num).toDouble();
                              final checkoutUrl = await PaymobService.getCheckoutUrlFromServer(
                                amountInEgp: amount,
                                bookingId: orderRef,
                                userEmail: user?.email ?? '',
                                userName: user?.name ?? 'Captain',
                                userPhone: user?.phone ?? '',
                                isTournamentPayment: true,
                              );
                              if (checkoutUrl == null) {
                                throw Exception(isArabic ? 'تعذر إنشاء رابط الدفع.' : 'Failed to create checkout URL.');
                              }
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PaymobWebViewScreen(
                                    initialUrl: checkoutUrl,
                                    bookingId: orderRef,
                                    title: isArabic ? 'سداد بطولة أقوى فريق' : 'Strongest Team Checkout',
                                  ),
                                ),
                              );
                            } else {
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              VSPFeedback.showSuccess(
                                context,
                                isArabic ? 'تم تسجيل فريقك في بطولة أقوى فريق بنجاح!' : 'Team registered successfully!',
                              );
                            }
                            _loadData();
                          } catch (e) {
                            setModalState(() => isSubmitting = false);
                            if (context.mounted) {
                              VSPFeedback.showError(context, e.toString());
                            }
                          }
                        },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: VSPColors.info));
    }
    if (_error != null) {
      return VSPErrorState(
        customMessage: _error,
        onRetry: () {
          _loadData();
          widget.onRetry();
        },
      );
    }

    final activeEvent = _events.cast<StrongestTeamEvent?>().firstWhere(
          (e) => e!.status != 'completed' && e.status != 'cancelled',
          orElse: () => _events.isNotEmpty ? _events.first : null,
        );
    final pastEvents = _events.where((e) => e.id != activeEvent?.id && e.status == 'completed').toList();

    final isRegistered = activeEvent != null &&
        activeEvent.participants.any(
          (p) => p['registration_status'] == 'confirmed' && _myCaptainTeams.any((t) => t.id == p['team_id']),
        );
    final confirmedCount = activeEvent?.participants.where((p) => p['registration_status'] == 'confirmed').length ?? 0;
    final canRegister = activeEvent != null &&
        activeEvent.status == 'registration_open' &&
        !isRegistered &&
        confirmedCount < 4;

    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.fromLTRB(16, 4, 16, canRegister ? 150 : 90),
          physics: const BouncingScrollPhysics(),
          children: [
            _buildOfficialHeader(isArabic),
            const SizedBox(height: 14),
            if (activeEvent == null)
              _buildNoActiveCard(isArabic)
            else
              _buildActiveEventCard(context, activeEvent, confirmedCount, isRegistered, isArabic),
            if (pastEvents.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                isArabic ? 'النسخ السابقة لبطولة أقوى فريق' : 'Previous Strongest Team Editions',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 10),
              ...pastEvents.map((e) => _buildPastEventTile(e, isArabic)),
            ],
          ],
        ),
        if (canRegister)
          Positioned(
            left: 16,
            right: 16,
            bottom: 84, // cleanly above floating Bottom Nav
            child: PrimaryButton(
              text: activeEvent.entryFeeEgp > 0
                  ? (isArabic
                      ? 'سجّل فريقك الآن (${activeEvent.entryFeeEgp.toStringAsFixed(0)} ج.م للفريق)'
                      : 'Register Team (${activeEvent.entryFeeEgp.toStringAsFixed(0)} EGP/team)')
                  : (isArabic ? 'سجّل فريقك مجاناً' : 'Register Team Free'),
              onPressed: () => _openRegistrationModal(context, activeEvent, isArabic),
            ),
          ),
      ],
    );
  }

  Widget _buildOfficialHeader(bool isArabic) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            VSPColors.surface,
            VSPColors.surfaceAlt,
          ],
        ),
        borderRadius: BorderRadius.circular(VSPRadius.xl),
        border: Border.all(color: VSPColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Iconsax.crown_1_copy, color: VSPColors.info, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isArabic ? 'بطولة أقوى فريق — VSP الرسمية' : 'Strongest Team — Official VSP Event',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isArabic
                ? '4 فرق • 5 لاعبين لكل فريق (منهم حارس مرمى) • 5 اختبارات مهارية على أرض الواقع.\nالمكافآت: الأول 1,400 • الثاني 1,100 • الثالث 800 • الرابع 600 XP.'
                : '4 Teams • 5 Players/team (incl. GK) • 5 Live Skill Tests.\nXP Rewards: 1st 1,400 • 2nd 1,100 • 3rd 800 • 4th 600 XP.',
            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildNoActiveCard(bool isArabic) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.xl),
        border: Border.all(color: VSPColors.divider),
      ),
      child: Column(
        children: [
          const Icon(Iconsax.medal_star_copy, color: VSPColors.info, size: 42),
          const SizedBox(height: 10),
          Text(
            isArabic ? 'لا توجد بطولة أقوى فريق مفتوحة حالياً في هذه المحافظة' : 'No active Strongest Team event in this governorate',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            isArabic
                ? 'الاختبارات الخمسة: السرعة • التسديد والكرة متحركة • ركلات الجزاء • التحكم بالكرة • المواجهة النهائية 1 ضد 1.'
                : '5 Tests: Speed • Moving Ball Shooting • Penalties • First Touch Control • Final 1v1.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveEventCard(
    BuildContext context,
    StrongestTeamEvent event,
    int confirmedCount,
    bool isRegistered,
    bool isArabic,
  ) {
    final statusLabel = switch (event.status) {
      'registration_open' => isArabic ? 'التسجيل مفتوح' : 'Registration Open',
      'registration_closed' => isArabic ? 'التسجيل مغلق' : 'Registration Closed',
      'ongoing' => isArabic ? 'البطولة جارية' : 'Ongoing',
      'completed' => isArabic ? 'البطولة انتهت' : 'Completed',
      'cancelled' => isArabic ? 'ملغاة' : 'Cancelled',
      _ => event.status,
    };

    final sortedParts = [...event.participants]
      ..sort((a, b) => ((a['final_rank'] as num?) ?? 99).compareTo((b['final_rank'] as num?) ?? 99));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.xl),
        border: Border.all(color: VSPColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  isArabic ? event.titleAr : event.titleEn,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: VSPColors.info.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(VSPRadius.full),
                ),
                child: Text(statusLabel, style: const TextStyle(color: VSPColors.info, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${event.governorate} • ${event.venueName} • ${event.eventDate.toLocal().toString().substring(0, 16)}',
            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            isArabic
                ? 'الفرق المسجلة: $confirmedCount / 4  •  الرسوم: ${event.entryFeeEgp > 0 ? '${event.entryFeeEgp.toStringAsFixed(0)} ج.م للفريق' : 'مجانية'}'
                : 'Registered: $confirmedCount / 4  •  Fee: ${event.entryFeeEgp > 0 ? '${event.entryFeeEgp.toStringAsFixed(0)} EGP/team' : 'Free'}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
          ),
          if (isRegistered) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: VSPColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(VSPRadius.md),
              ),
              child: Text(
                isArabic ? '✅ فريقك مسجل ومؤكد في هذه البطولة' : '✅ Your team is confirmed in this event',
                style: const TextStyle(color: VSPColors.success, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
          if ((isArabic ? event.prizeDescriptionAr : event.prizeDescriptionEn)?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              (isArabic ? event.prizeDescriptionAr : event.prizeDescriptionEn)!,
              style: const TextStyle(color: VSPColors.warning, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
          if (sortedParts.isNotEmpty) ...[
            const Divider(color: VSPColors.divider, height: 24),
            Text(
              isArabic ? 'الفرق والترتيب' : 'Teams & Standings',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
            const SizedBox(height: 8),
            ...sortedParts.map((p) {
              final t = p['teams'] as Map<String, dynamic>?;
              final rank = p['final_rank'];
              final score = (p['total_weighted_score'] as num?)?.toStringAsFixed(1) ?? '0';
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Text(rank != null ? '#$rank' : '•', style: const TextStyle(color: VSPColors.info, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text((t?['name'] ?? 'Team').toString(), style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                    Text('$score pts', style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12)),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildPastEventTile(StrongestTeamEvent e, bool isArabic) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VSPColors.surfaceAlt,
        borderRadius: BorderRadius.circular(VSPRadius.md),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(isArabic ? e.titleAr : e.titleEn, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          Text(e.governorate, style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}
