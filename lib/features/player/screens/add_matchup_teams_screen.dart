import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/auth_provider.dart' as app_auth;
import '../../../core/providers/booking_provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../core/widgets/shimmer_image.dart';
import '../../../data/models.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/vsp_back_button.dart';
import '../widgets/sixth_team_fee_dialog.dart';
import 'booking_confirmation_screen.dart';

class AddMatchupTeamsScreen extends StatefulWidget {
  final Stadium stadium;
  final Team hostTeam;

  const AddMatchupTeamsScreen({
    super.key,
    required this.stadium,
    required this.hostTeam,
  });

  @override
  State<AddMatchupTeamsScreen> createState() => _AddMatchupTeamsScreenState();
}

class _AddMatchupTeamsScreenState extends State<AddMatchupTeamsScreen> {
  final TextEditingController _codeController = TextEditingController();
  final List<Team> _addedTeams = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Host team is always Team #1
    _addedTeams.add(widget.hostTeam);
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  String get _dynamicTitle {
    final count = _addedTeams.length;
    if (count <= 1) return 'أضف الفرق للمواجهة';
    if (count == 2) return 'مواجهة ثنائية (فريقين)';
    return 'الفايز مستمر ($count/5 فرق)';
  }

  String get _dynamicSubtitle {
    final count = _addedTeams.length;
    if (count <= 1) return 'أدخل كود الفريق المنافس لبدء مواجهة ثنائية.';
    if (count == 2) return 'يمكنك التأكيد الآن أو إضافة حتى 5 فرق بنظام "الفايز مستمر".';
    return 'نظام الفايز مستمر: الفريق الفائز يستمر في الملعب ويتصدر الترتيب.';
  }

  Future<void> _lookupAndAddTeam() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    if (code.length < 4) {
      VSPFeedback.showError(context, 'يرجى إدخال كود صحيح من 6 خانات');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      // 1. Lookup team by active invite code
      final response = await supabase
          .from('teams')
          .select('*, team_members(count)')
          .eq('active_invite_code', code)
          .maybeSingle();

      if (response == null) {
        if (!mounted) return;
        VSPFeedback.showError(context, 'الكود غير صحيح أو لم يعد صالحاً');
        return;
      }

      // Check code expiration
      final expiresAtStr = response['invite_code_expires_at'];
      if (expiresAtStr != null) {
        final expiresAt = DateTime.parse(expiresAtStr);
        if (expiresAt.isBefore(DateTime.now().toUtc())) {
          if (!mounted) return;
          VSPFeedback.showError(context, 'انتهت صلاحية هذا الكود. اطلب كوداً جديداً من كابتن الفريق.');
          return;
        }
      }

      final team = Team.fromMap(response);

      // 2. Check if team is already in the list
      if (_addedTeams.any((t) => t.id == team.id)) {
        if (!mounted) return;
        VSPFeedback.showWarning(context, 'فريق ${team.name} مضاف بالفعل في المواجهة');
        return;
      }

      // 3. Verify minimum 5 members for official matchup
      final membersCount = (response['team_members'] as List?)?.isNotEmpty == true
          ? (response['team_members'][0]['count'] as int? ?? 0)
          : team.memberUids.length;

      if (membersCount < 5) {
        if (!mounted) return;
        VSPFeedback.showError(context, 'فريق ${team.name} غير مكتمل ($membersCount/5 أعضاء مسجلين)');
        return;
      }

      // 4. Check 6th team tier rule
      if (_addedTeams.length >= 5) {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (_) => SixthTeamFeeDialog(
            onProceedToPay: () {
              setState(() {
                _addedTeams.add(team);
                _codeController.clear();
              });
              VSPFeedback.showSuccess(context, 'تمت إضافة فريق ${team.name} بنجاح!');
            },
            onCancel: () {},
          ),
        );
        return;
      }

      setState(() {
        _addedTeams.add(team);
        _codeController.clear();
      });

      if (!mounted) return;
      VSPFeedback.showSuccess(context, 'تمت إضافة فريق ${team.name} بنجاح! ');
    } catch (e) {
      debugPrint('Error looking up team: $e');
      if (mounted) {
        VSPFeedback.showError(context, 'حدث خطأ أثناء فحص الكود: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _proceedToConfirmation() {
    if (_addedTeams.length < 2) {
      VSPFeedback.showWarning(context, 'يجب إضافة فريق منافس واحد على الأقل للمواجهة');
      return;
    }

    final authProvider = context.read<app_auth.AuthProvider>();
    final bookingProvider = context.read<BookingProvider>();

    final opponent = _addedTeams.length > 1 ? _addedTeams[1] : null;

    bookingProvider.setDraft(BookingDraft(
      stadiumId: widget.stadium.id,
      stadiumName: widget.stadium.name,
      stadiumImageUrl: widget.stadium.imageUrl,
      ownerId: widget.stadium.ownerId,
      hostName: authProvider.userModel?.name,
      hostAvatarUrl: authProvider.userModel?.profileImageUrl,
      startTime: DateTime.now(),
      endTime: DateTime.now().add(const Duration(hours: 1)),
      bookingType: BookingType.matchup,
      playerTeamId: widget.hostTeam.id,
      playerTeamName: widget.hostTeam.name,
      playerTeamLogoUrl: widget.hostTeam.logoUrl,
      opponentTeamId: opponent?.id,
      opponentTeamName: opponent?.name,
      opponentTeamLogoUrl: opponent?.logoUrl,
      isPrivate: true,
      rentBall: false,
      totalPrice: 0,
      needsDeposit: widget.stadium.needsDeposit,
    ));

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingConfirmationScreen(
          stadium: widget.stadium,
          bookingType: 'Matchup',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        leading: const VSPBackButton(),
        title: Text(
          isArabic ? 'إعداد المواجهة' : 'Matchup Setup',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(VSPSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Dynamic Mode Header Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(VSPSpacing.md),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          VSPColors.accent.withValues(alpha: 0.15),
                          VSPColors.surface,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(VSPRadius.lg),
                      border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: VSPColors.accent.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Iconsax.cup_copy, color: VSPColors.accent, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _dynamicTitle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _dynamicSubtitle,
                          style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, height: 1.4),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: VSPSpacing.xl),

                  // 2. Code Input Box
                  Text(
                    isArabic ? 'إضافة فريق عبر كود المواجهة' : 'Add Team via Matchup Code',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: VSPSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _codeController,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(6),
                            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                          ],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                          ),
                          decoration: InputDecoration(
                            hintText: 'ABCD12',
                            hintStyle: TextStyle(
                              color: VSPColors.textSecondary.withValues(alpha: 0.5),
                              letterSpacing: 4,
                            ),
                            filled: true,
                            fillColor: VSPColors.surface,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(VSPRadius.md),
                              borderSide: const BorderSide(color: VSPColors.borderLight),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(VSPRadius.md),
                              borderSide: const BorderSide(color: VSPColors.accent, width: 1.5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _lookupAndAddTeam,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: VSPColors.accent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                )
                              : Text(
                                  isArabic ? 'إضافة' : 'Add',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: VSPSpacing.xl),

                  // 3. Teams List
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isArabic ? 'الفرق المشاركة (${_addedTeams.length})' : 'Participating Teams (${_addedTeams.length})',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      if (_addedTeams.length >= 2)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: VSPColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: VSPColors.success),
                          ),
                          child: Text(
                            isArabic ? 'جاهز للتأكيد ✓' : 'Ready ✓',
                            style: const TextStyle(color: VSPColors.success, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: VSPSpacing.sm),

                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _addedTeams.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final team = _addedTeams[index];
                      final isHost = index == 0;

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: VSPColors.surface,
                          borderRadius: BorderRadius.circular(VSPRadius.md),
                          border: Border.all(
                            color: isHost ? VSPColors.accent.withValues(alpha: 0.4) : VSPColors.borderLight,
                          ),
                        ),
                        child: Row(
                          children: [
                            ShimmerImage(
                              imageUrl: team.logoUrl,
                              width: 44,
                              height: 44,
                              borderRadius: 22,
                              errorWidget: CircleAvatar(
                                radius: 22,
                                backgroundColor: VSPColors.surfaceAlt,
                                child: Text(
                                  team.name.isNotEmpty ? team.name[0] : 'T',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        team.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      if (isHost) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: VSPColors.accent.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            isArabic ? 'المستضيف' : 'Host',
                                            style: const TextStyle(
                                              color: VSPColors.accent,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${team.governorate} • ${team.points} نقطة',
                                    style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            if (!isHost)
                              IconButton(
                                icon: const Icon(Iconsax.trash_copy, color: VSPColors.error, size: 20),
                                onPressed: () {
                                  setState(() {
                                    _addedTeams.removeAt(index);
                                  });
                                },
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Bottom Bar
          Container(
            padding: EdgeInsets.fromLTRB(
              VSPSpacing.md,
              VSPSpacing.md,
              VSPSpacing.md,
              MediaQuery.of(context).padding.bottom + VSPSpacing.md,
            ),
            decoration: const BoxDecoration(
              color: VSPColors.surface,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(VSPRadius.xl),
                topRight: Radius.circular(VSPRadius.xl),
              ),
            ),
            child: PrimaryButton(
              text: isArabic ? 'تأكيد المواجهة والمتابعة للحجز' : 'Confirm Matchup & Proceed',
              onPressed: _addedTeams.length >= 2 ? _proceedToConfirmation : null,
            ),
          ),
        ],
      ),
    );
  }
}
