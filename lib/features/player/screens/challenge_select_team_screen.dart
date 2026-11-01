import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/ui/vsp_ui.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

import '../../../core/providers/auth_provider.dart' as app_auth;
import '../../../core/providers/booking_provider.dart';
import '../../../core/repositories/team_repository.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../core/utils/vsp_launcher_utils.dart';
import '../../../data/models.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/vsp_back_button.dart';
import '../services/challenge_team_service.dart';
import '../widgets/challenge/challenge_team_card.dart';
import 'booking_confirmation_screen.dart';
import '../widgets/create_team_sheet.dart';

/// الشاشة الرسمية لحجز مباريات التحدي (Challenge Match)
/// المسار المعتمد الوحيد: إدخال كود التحدي -> التحقق من السيرفر -> ظهور بطاقة الخصم -> المتابعة للحجز
class ChallengeSelectTeamScreen extends StatefulWidget {
  final Stadium stadium;
  final String bookingType;

  const ChallengeSelectTeamScreen({
    super.key,
    required this.stadium,
    required this.bookingType,
  });

  @override
  State<ChallengeSelectTeamScreen> createState() => _ChallengeSelectTeamScreenState();
}

class _ChallengeSelectTeamScreenState extends State<ChallengeSelectTeamScreen> {
  final TextEditingController _challengeCodeController = TextEditingController();
  Team? _selectedTeam;
  Team? _userTeam;
  String? _appliedChallengeCode;
  bool _isLookingUpCode = false;
  bool _isGeneratingCode = false;
  Map<String, int>? _h2hStats;
  bool _isLoadingH2H = false;
  bool _hasH2HError = false;
  bool _isLoadingUserTeam = true;
  bool _hasUserTeamLoadError = false;
  bool _isContinuing = false;
  String? _activeUserId;
  bool _hasObservedUserId = false;
  int _teamRequestGeneration = 0;
  final Map<String, bool> _championStatusMap = {};

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = context.watch<app_auth.AuthProvider>().currentUser?.id;
    if (!_hasObservedUserId || userId != _activeUserId) {
      _hasObservedUserId = true;
      _activeUserId = userId;
      final generation = ++_teamRequestGeneration;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || generation != _teamRequestGeneration) return;
        _loadUserTeam(expectedUserId: userId, requestGeneration: generation);
      });
    }
  }

  @override
  void dispose() {
    _challengeCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadUserTeam({
    String? expectedUserId,
    int? requestGeneration,
  }) async {
    final generation = requestGeneration ?? ++_teamRequestGeneration;
    final uid = expectedUserId ?? context.read<app_auth.AuthProvider>().currentUser?.id;
    if (mounted) {
      setState(() {
        _isLoadingUserTeam = true;
        _hasUserTeamLoadError = false;
      });
    }
    if (uid == null) {
      if (mounted && generation == _teamRequestGeneration) {
        setState(() {
          _userTeam = null;
          _isLoadingUserTeam = false;
          _hasUserTeamLoadError = true;
        });
      }
      return;
    }
    try {
      final team = await TeamRepository().getUserTeamStrict(uid);
      if (!mounted ||
          generation != _teamRequestGeneration ||
          context.read<app_auth.AuthProvider>().currentUser?.id != uid) {
        return;
      }
      setState(() {
        _userTeam = team;
        _isLoadingUserTeam = false;
        _hasUserTeamLoadError = false;
      });
    } catch (e) {
      debugPrint('Failed to verify challenge captain team: $e');
      if (!mounted ||
          generation != _teamRequestGeneration ||
          context.read<app_auth.AuthProvider>().currentUser?.id != uid) {
        return;
      }
      setState(() {
        _userTeam = null;
        _isLoadingUserTeam = false;
        _hasUserTeamLoadError = true;
      });
    }
  }

  Future<void> _openCreateTeam() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateTeamSheet(),
    );
    if (!mounted || created != true) return;
    await _loadUserTeam();
  }

  Future<void> _continueWithChallenge() async {
    if (_isContinuing || _selectedTeam == null || _appliedChallengeCode == null) return;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final auth = context.read<app_auth.AuthProvider>();
    final uid = auth.currentUser?.id;
    if (uid == null) {
      VSPFeedback.showError(
        context,
        isArabic ? 'انتهت الجلسة. سجّل الدخول مرة أخرى.' : 'Your session expired. Please sign in again.',
      );
      return;
    }

    setState(() => _isContinuing = true);
    try {
      final team = await TeamRepository().getUserTeamStrict(uid);
      if (!mounted) return;
      if (context.read<app_auth.AuthProvider>().currentUser?.id != uid) return;
      if (team == null) {
        VSPFeedback.showError(
          context,
          isArabic
              ? 'يجب أن تكون عضواً في فريق قبل تأكيد مباراة التحدي.'
              : 'You must belong to a team before confirming a challenge match.',
        );
        return;
      }
      if (!ChallengeTeamService.isFairPlayEligible(team) ||
          !ChallengeTeamService.isFairPlayEligible(_selectedTeam)) {
        VSPFeedback.showError(context, AppLocalizations.of(context)!.fairPlayBannedError);
        return;
      }

      context.read<BookingProvider>().updateDraft(
        opponentTeamId: _selectedTeam!.id,
        opponentTeamName: _selectedTeam!.name,
        playerTeamId: team.id,
        playerTeamName: team.name,
        challengeCode: _appliedChallengeCode,
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BookingConfirmationScreen(
            stadium: widget.stadium,
            bookingType: widget.bookingType,
            opponentTeam: _selectedTeam,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Failed to verify team before challenge booking: $e');
      if (mounted) {
        VSPFeedback.showError(
          context,
          isArabic
              ? 'تعذر التحقق من فريقك. أعد المحاولة قبل متابعة الحجز.'
              : 'Could not verify your team. Retry before continuing.',
        );
      }
    } finally {
      if (mounted) setState(() => _isContinuing = false);
    }
  }

  Future<void> _check1v1ChampionForTeam(String teamId) async {
    if (_championStatusMap.containsKey(teamId)) return;
    try {
      final hasChamp = await TeamRepository().has1v1Champion(teamId);
      if (mounted) {
        setState(() {
          _championStatusMap[teamId] = hasChamp;
        });
      }
    } catch (e) {
      debugPrint('Error checking 1v1 champion for team $teamId: $e');
    }
  }

  Future<void> _handleLookupCode() async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final code = _challengeCodeController.text.trim();
    if (code.isEmpty) {
      VSPFeedback.showInfo(
        context,
        Localizations.localeOf(context).languageCode == 'ar'
            ? 'يرجى إدخال كود التحدي أولاً يا كابتن'
            : 'Please enter a challenge code first',
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLookingUpCode = true);

    try {
      final res = await TeamRepository().lookupChallengeCode(code);
      if (!mounted) return;

      if (res['success'] == true && res['opponent_team_id'] != null) {
        final oppId = res['opponent_team_id'].toString();
        final oppTeam = await TeamRepository().getTeam(oppId);
        if (!mounted) return;

        if (oppTeam != null) {
          final validatedCode = (res['code']?.toString() ?? code).toUpperCase();
          setState(() {
            _selectedTeam = oppTeam;
            _appliedChallengeCode = validatedCode;
            _isLookingUpCode = false;
            _isLoadingH2H = true;
            _h2hStats = null;
            _hasH2HError = false;
          });

          // Fetch head-to-head stats if user has a team
          if (_userTeam != null) {
            final stats = await TeamRepository().getHeadToHeadStats(_userTeam!.id, oppTeam.id);
            if (mounted) {
              setState(() {
                _h2hStats = stats;
                _isLoadingH2H = false;
                _hasH2HError = stats == null;
              });
            }
          } else {
            if (mounted) setState(() {
              _isLoadingH2H = false;
              _hasH2HError = false;
            });
          }

          if (mounted) {
            VSPFeedback.showSuccess(
              context,
              isArabic
                  ? 'تم التحقق من الفريق المنافس: ${oppTeam.name}'
                  : 'Opponent team verified: ${oppTeam.name}',
            );
          }
          return;
        }
      }

      if (!mounted) return;
      setState(() => _isLookingUpCode = false);
      final err = res['error']?.toString() ?? '';
      String errorMsg;
      if (err == 'CODE_INVALID_OR_USED') {
        errorMsg = isArabic ? 'كود التحدي غير صالح أو تم استخدامه مسبقاً.' : 'This challenge code is invalid or has already been used.';
      } else if (err == 'CODE_EXPIRED') {
        errorMsg = isArabic ? 'كود التحدي منتهي الصلاحية.' : 'This challenge code has expired.';
      } else if (err == 'CALLER_NOT_A_CAPTAIN') {
        errorMsg = isArabic ? 'يجب أن تكون كابتن فريق لتحدي هذا الكود.' : 'Only a team captain can use this challenge code.';
      } else if (err == 'CANNOT_CHALLENGE_OWN_TEAM') {
        errorMsg = isArabic ? 'لا يمكنك إدخال كود فريقك نفسه.' : 'You cannot enter your own team code.';
      } else if (err == 'TEAM_NOT_FOUND') {
        errorMsg = isArabic ? 'تعذر العثور على الفريق التابع لهذا الكود.' : 'The team linked to this code could not be found.';
      } else {
        errorMsg = isArabic ? 'تعذر التحقق من كود التحدي. تأكد من الكود وأعد المحاولة.' : 'Could not verify the challenge code. Check it and retry.';
      }
      VSPFeedback.showError(context, errorMsg);
    } catch (e) {
      if (mounted) {
        setState(() => _isLookingUpCode = false);
        VSPFeedback.showError(
          context,
          isArabic ? 'حدث خطأ أثناء فحص الكود.' : 'An error occurred while checking the code.',
        );
      }
    }
  }

  void _clearSelectedOpponent() {
    setState(() {
      _selectedTeam = null;
      _appliedChallengeCode = null;
      _h2hStats = null;
      _isLoadingH2H = false;
      _hasH2HError = false;
      _challengeCodeController.clear();
    });
  }

  Future<void> _showMyChallengeCodeModal() async {
    if (_userTeam == null) return;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    setState(() => _isGeneratingCode = true);

    try {
      final res = await TeamRepository().generateChallengeCode(_userTeam!.id);
      if (!mounted) return;
      setState(() => _isGeneratingCode = false);

      if (res['success'] != true || res['code'] == null) {
        final err = res['error']?.toString();
        VSPFeedback.showError(
          context,
          err == 'CAPTAIN_ONLY'
              ? (isArabic ? 'توليد الكود متاح لكابتن الفريق فقط.' : 'Only the team captain can generate a code.')
              : (isArabic ? 'تعذر توليد كود التحدي حالياً.' : 'Could not generate the challenge code right now.'),
        );
        return;
      }

      final code = res['code'].toString();
      _displayChallengeCodeBottomSheet(code);
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingCode = false);
        VSPFeedback.showError(
          context,
          isArabic ? 'حدث خطأ أثناء توليد الكود.' : 'An error occurred while generating the code.',
        );
      }
    }
  }

  void _displayChallengeCodeBottomSheet(String code) {
    final teamName = _userTeam?.name ?? 'فريقنا';
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.9,
        ),
        padding: const EdgeInsets.fromLTRB(
          VSPSpacing.lg,
          VSPSpacing.md,
          VSPSpacing.lg,
          VSPSpacing.lg,
        ),
        decoration: const BoxDecoration(
          color: VSPColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
        ),
        child: SafeArea(
          top: false,
          bottom: true,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: VSPColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VSPColors.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Iconsax.ticket_star_copy, color: VSPColors.accent, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              isArabic ? 'كود تحدي فريقك' : 'Team Challenge Code',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isArabic
                  ? 'شارك هذا الكود مع كابتن الفريق المنافس ليحجز ضدكم الماتش فوراً'
                  : 'Share this code with opponent captain to book the challenge match directly',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: VSPColors.textSecondary.withValues(alpha: 0.8),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: VSPColors.background,
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(color: VSPColors.accent.withValues(alpha: 0.5)),
              ),
              child: SelectableText(
                code,
                style: const TextStyle(
                  color: VSPColors.accent,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: VSPColors.divider),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                    ),
                    icon: const Icon(Iconsax.copy_copy, size: 18, color: Colors.white),
                    label: Text(isArabic ? 'نسخ الكود' : 'Copy', style: const TextStyle(color: Colors.white)),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      Navigator.pop(ctx);
                      VSPFeedback.showSuccess(context, isArabic ? 'تم نسخ كود التحدي' : 'Code copied');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VSPColors.whatsApp,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: Text(isArabic ? 'مشاركة واتساب' : 'WhatsApp', style: const TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      final msg = isArabic
                          ? 'كابتن! يلا نلعب ماتش تحدي على تطبيق VSP.\nكود التحدي لفريقنا ($teamName) هو:\n$code\nادخل الكود في التطبيق واحجز الماتش ضدنا!'
                          : 'Captain! Let us play a challenge match on VSP.\nOur team code ($teamName) is:\n$code\nEnter this code in VSP app to challenge us!';
                      VSPLauncherUtils.openWhatsApp(context, phone: '', message: msg);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return VSPScaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        leading: const VSPBackButton(),
        centerTitle: true,
        title: Text(
          isArabic ? 'مباراة تحدي' : 'Challenge Match',
          style: Theme.of(context).textTheme.displaySmall,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic ? 'تأكيد الخصم عبر كود التحدي' : 'Confirm Opponent by Challenge Code',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isArabic
                        ? 'مباريات التحدي تتم حصرياً عبر كود صادر من كابتن الفريق المنافس لضمان الجدية والأهلية.'
                        : 'Challenge matches are created exclusively using a code issued by the opponent captain.',
                    style: TextStyle(
                      color: VSPColors.textSecondary.withValues(alpha: 0.7),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (_isLoadingUserTeam)
                    const LinearProgressIndicator(
                      minHeight: 2,
                      color: VSPColors.accent,
                      backgroundColor: VSPColors.surfaceAlt,
                    )
                  else if (_hasUserTeamLoadError)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(VSPSpacing.md),
                      decoration: BoxDecoration(
                        color: VSPColors.warning.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(VSPRadius.md),
                        border: Border.all(color: VSPColors.warning.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              isArabic
                                  ? 'تعذر التحقق من فريقك. أعد المحاولة قبل متابعة الحجز.'
                                  : 'Could not verify your team. Retry before continuing.',
                              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                            ),
                          ),
                          TextButton(
                            onPressed: _loadUserTeam,
                            child: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
                          ),
                        ],
                      ),
                    )
                  else if (_userTeam == null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(VSPSpacing.md),
                      decoration: BoxDecoration(
                        color: VSPColors.surface,
                        borderRadius: BorderRadius.circular(VSPRadius.md),
                        border: Border.all(color: VSPColors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isArabic
                                ? 'تحتاج إلى الانضمام لفريق قبل متابعة مباراة التحدي.'
                                : 'Join or create a team before continuing with a challenge match.',
                            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                          ),
                          const SizedBox(height: VSPSpacing.sm),
                          TextButton(
                            onPressed: _openCreateTeam,
                            child: Text(isArabic ? 'إنشاء فريق' : 'Create team'),
                          ),
                        ],
                      ),
                    ),

                  // كرت كود فريق الكابتن الحالي للمشاركة
                  if (_userTeam != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: VSPColors.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(VSPRadius.lg),
                        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: VSPColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(VSPRadius.md),
                            ),
                            child: const Icon(Iconsax.ticket_star_copy, color: VSPColors.accent, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isArabic ? 'كود التحدي لفريقك' : 'Your Team Challenge Code',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isArabic
                                      ? 'شارك الكود مع الخصم ليحجز ضدكم فوراً'
                                      : 'Share with opponent to book directly',
                                  style: TextStyle(
                                    color: VSPColors.textSecondary.withValues(alpha: 0.8),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: _isGeneratingCode ? null : _showMyChallengeCodeModal,
                            style: TextButton.styleFrom(
                              backgroundColor: VSPColors.accent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.sm)),
                            ),
                            child: _isGeneratingCode
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                  )
                                : Text(
                                    isArabic ? 'مشاركة' : 'Share',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // حقل إدخال والتحقق من كود التحدي
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: VSPColors.surface,
                      borderRadius: BorderRadius.circular(VSPRadius.lg),
                      border: Border.all(
                        color: _appliedChallengeCode != null ? VSPColors.accent : VSPColors.divider,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Iconsax.key_copy, color: VSPColors.accent, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              isArabic ? 'كود التحدي من كابتن الخصم' : 'Opponent Challenge Code',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            if (_appliedChallengeCode != null) ...[
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: VSPColors.accent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(VSPRadius.full),
                                ),
                                child: Text(
                                  _appliedChallengeCode!,
                                  style: const TextStyle(
                                    color: VSPColors.accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 46,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: VSPColors.background,
                                  borderRadius: BorderRadius.circular(VSPRadius.md),
                                  border: Border.all(color: VSPColors.divider),
                                ),
                                child: TextField(
                                  controller: _challengeCodeController,
                                  textCapitalization: TextCapitalization.characters,
                                  enabled: !_isLookingUpCode,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: isArabic
                                        ? 'أدخل الكود (مثال: VSP-7K9A2)'
                                        : 'Enter code (e.g. VSP-7K9A2)',
                                    hintStyle: TextStyle(
                                      color: VSPColors.textSecondary.withValues(alpha: 0.5),
                                      fontSize: 13,
                                      letterSpacing: 0,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  onSubmitted: (_) => _handleLookupCode(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              height: 46,
                              child: ElevatedButton(
                                onPressed: _isLookingUpCode ? null : _handleLookupCode,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: VSPColors.accent,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 18),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(VSPRadius.md),
                                  ),
                                ),
                                child: _isLookingUpCode
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.black,
                                        ),
                                      )
                                    : Text(
                                        isArabic ? 'تحقق' : 'Verify',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // بطاقة الفريق المعتمد بعد نجاح الكود
                  if (_selectedTeam != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isArabic ? 'الفريق المنافس المعتمد' : 'Verified Opponent Team',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        TextButton.icon(
                          onPressed: _clearSelectedOpponent,
                          icon: const Icon(Iconsax.refresh_copy, size: 14, color: VSPColors.textSecondary),
                          label: Text(
                            isArabic ? 'تغيير الكود' : 'Change',
                            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildVerifiedTeamCard(_selectedTeam!),
                  ] else ...[
                    // إرشادات عند عدم إدخال كود بعد
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: VSPColors.surface.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(VSPRadius.lg),
                        border: Border.all(color: VSPColors.divider.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Iconsax.shield_tick_copy,
                            color: VSPColors.textSecondary.withValues(alpha: 0.3),
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isArabic
                                ? 'أدخل كود التحدي من كابتن الفريق المنافس للتحقق'
                                : 'Enter the challenge code from opponent captain to verify',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: VSPColors.textSecondary.withValues(alpha: 0.6),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // زر المتابعة - مفعل حصرياً عند التحقق من الكود والفريق
          Container(
            padding: const EdgeInsets.all(VSPSpacing.lg),
            decoration: const BoxDecoration(
              color: VSPColors.surface,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(VSPRadius.xl),
                topRight: Radius.circular(VSPRadius.xl),
              ),
              boxShadow: [VSPShadow.subtle],
            ),
            child: SafeArea(
              child: PrimaryButton(
                text: AppLocalizations.of(context)!.continueButton,
                isLoading: _isContinuing,
                onPressed: (_selectedTeam == null ||
                        _appliedChallengeCode == null ||
                        _isLoadingUserTeam ||
                        _hasUserTeamLoadError ||
                        _userTeam == null ||
                        _isContinuing)
                    ? null
                    : _continueWithChallenge,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifiedTeamCard(Team team) {
    _check1v1ChampionForTeam(team.id);
    final bool hasChampion = _championStatusMap[team.id] ?? false;

    return ChallengeTeamCard(
      team: team,
      isSelected: true,
      hasChampion: hasChampion,
      isLoadingH2H: _isLoadingH2H,
      hasH2HError: _hasH2HError,
      h2hStats: _h2hStats,
      onTap: () {},
    );
  }
}
