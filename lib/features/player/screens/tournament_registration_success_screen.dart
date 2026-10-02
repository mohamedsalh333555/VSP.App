import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import '../../../core/ui/vsp_ui.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/egypt_governorates.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/vsp_launcher_utils.dart';
import 'champion_screen.dart';
import 'player_home_screen.dart';

/// الشاشة الاحتفالية بنجاح الاشتراك في البطولات (1v1، دوري الـ 4 فرق، والبطولات المجمعة)
/// تعرض بيانات ديناميكية حقيقية 100% مسترجعة لحظياً من قاعدة البيانات (Supabase)
class TournamentRegistrationSuccessScreen extends StatefulWidget {
  /// '1v1' أو 'championship' أو 'team_league'
  final String tournamentType;
  final String tournamentId;
  final String? orderReference;
  final String? userId;
  final String? teamId;
  final String? teamName;
  final String? initialTournamentName;

  const TournamentRegistrationSuccessScreen({
    super.key,
    required this.tournamentType,
    required this.tournamentId,
    this.orderReference,
    this.userId,
    this.teamId,
    this.teamName,
    this.initialTournamentName,
  });

  @override
  State<TournamentRegistrationSuccessScreen> createState() =>
      _TournamentRegistrationSuccessScreenState();
}

class _TournamentRegistrationSuccessScreenState
    extends State<TournamentRegistrationSuccessScreen>
    with SingleTickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _badgeAnimController;
  late Animation<double> _scaleAnimation;

  bool _isLoading = true;
  String _tournamentName = '';
  String _governorate = '';
  DateTime? _scheduledDate;
  double _entryFee = 0.0;
  double _prizePool = 0.0;
  int _myPosition = 0;
  int _totalParticipants = 0;
  int _maxCapacity = 0;
  String? _stadiumName;

  @override
  void initState() {
    super.initState();

    // 1. إعداد الاحتفال والكونفيتي
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 4));

    // 2. أنيميشن نبض الكأس والتحقق
    _badgeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _badgeAnimController,
      curve: Curves.elasticOut,
    );

    _badgeAnimController.forward();

    // 3. تشغيل الكونفيتي والاهتزاز بعد نصف ثانية
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _confettiController.play();
        HapticFeedback.heavyImpact();
      }
    });

    // 4. جلب البيانات اللحظية من السيرفر
    _fetchLiveTournamentDetails();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _badgeAnimController.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveTournamentDetails() async {
    try {
      final supabase = Supabase.instance.client;

      if (widget.tournamentType == '1v1') {
        // جلب بيانات بطولة 1 ضد 1
        final tourneyRes = await supabase
            .from('vsp_1v1_tournaments')
            .select()
            .eq('id', widget.tournamentId)
            .maybeSingle();

        // جلب قائمة اللاعبين المسجلين الفعليين المسددين للرسوم
        final playersRes = await supabase
            .from('vsp_1v1_tournament_players')
            .select('id, user_id, player_name, registered_at')
            .eq('tournament_id', widget.tournamentId)
            .eq('payment_status', 'paid')
            .order('registered_at', ascending: true);

        final currentUid =
            widget.userId ?? supabase.auth.currentUser?.id ?? '';
        final playersList =
            List<Map<String, dynamic>>.from(playersRes as List? ?? []);

        int resolvedIndex =
            playersList.indexWhere((p) => p['user_id'] == currentUid) + 1;
        if (resolvedIndex <= 0) {
          resolvedIndex = 0;
        }

        if (mounted) {
          setState(() {
            _tournamentName = tourneyRes?['name']?.toString() ??
                widget.initialTournamentName ??
                '';
            final rawGov = tourneyRes?['governorate']?.toString() ?? '';
            _governorate = EgyptGovernorates.governorateToArabic[rawGov] ??
                rawGov;
            if (tourneyRes?['scheduled_at'] != null) {
              _scheduledDate = DateTime.tryParse(
                      tourneyRes!['scheduled_at'].toString())
                  ?.toLocal();
            }
            _entryFee =
                (tourneyRes?['entry_fee'] as num?)?.toDouble() ?? 0.0;
            _prizePool =
                (tourneyRes?['prize_pool'] as num?)?.toDouble() ?? 0.0;
            _maxCapacity =
                (tourneyRes?['target_player_count'] as num?)?.toInt() ?? 0;
            _myPosition = resolvedIndex;
            _totalParticipants = playersList.length;
            _isLoading = false;
          });
        }
      } else if (widget.tournamentType == 'team_league') {
        // جلب بيانات دوري الـ 4 فرق
        final leagueRes = await supabase
            .from('championships')
            .select('*, stadiums(name)')
            .eq('id', widget.tournamentId)
            .maybeSingle();

        final rostersRes = await supabase
            .from('championship_rosters')
            .select('id, team_id, created_at')
            .eq('championship_id', widget.tournamentId)
            .order('created_at', ascending: true);

        final rostersList =
            List<Map<String, dynamic>>.from(rostersRes as List? ?? []);
        int teamOrder = 1;
        if (widget.teamId != null) {
          teamOrder =
              rostersList.indexWhere((r) => r['team_id'] == widget.teamId) + 1;
        }
        if (teamOrder <= 0) {
          teamOrder = 0;
        }

        if (mounted) {
          setState(() {
            _tournamentName = leagueRes?['name']?.toString() ??
                widget.initialTournamentName ??
                '';
            final rawGov = leagueRes?['governorate']?.toString() ?? '';
            _governorate = EgyptGovernorates.governorateToArabic[rawGov] ??
                rawGov;
            if (leagueRes?['start_date'] != null) {
              _scheduledDate = DateTime.tryParse(
                      leagueRes!['start_date'].toString())
                  ?.toLocal();
            }
            _stadiumName = leagueRes?['stadiums']?['name']?.toString();
            _entryFee = 30.0; // رسوم تنظيم المنصة الثابتة
            _prizePool =
                (leagueRes?['prize'] as num?)?.toDouble() ?? 0.0;
            _maxCapacity = 4;
            _myPosition = teamOrder;
            _totalParticipants = rostersList.length;
            _isLoading = false;
          });
        }
      } else {
        // بطولات الفرق العامة (Championships)
        final champRes = await supabase
            .from('championships')
            .select('*, stadiums(name)')
            .eq('id', widget.tournamentId)
            .maybeSingle();

        final rostersRes = await supabase
            .from('championship_rosters')
            .select('id, team_id, created_at')
            .eq('championship_id', widget.tournamentId)
            .order('created_at', ascending: true);

        final rostersList =
            List<Map<String, dynamic>>.from(rostersRes as List? ?? []);
        int teamOrder = 1;
        if (widget.teamId != null) {
          teamOrder =
              rostersList.indexWhere((r) => r['team_id'] == widget.teamId) + 1;
        }
        if (teamOrder <= 0) {
          teamOrder = rostersList.isNotEmpty ? rostersList.length : 1;
        }

        if (mounted) {
          setState(() {
            _tournamentName = champRes?['name']?.toString() ??
                widget.initialTournamentName ??
                '';
            final rawGov = champRes?['governorate']?.toString() ?? '';
            _governorate = EgyptGovernorates.governorateToArabic[rawGov] ??
                rawGov;
            if (champRes?['start_date'] != null) {
              _scheduledDate =
                  DateTime.tryParse(champRes!['start_date'].toString())
                      ?.toLocal();
            }
            _stadiumName = champRes?['stadiums']?['name']?.toString();
            _entryFee =
                (champRes?['entry_fee'] as num?)?.toDouble() ?? 0.0;
            _prizePool =
                (champRes?['prize'] as num?)?.toDouble() ?? 0.0;
            _maxCapacity =
                (champRes?['max_teams'] as num?)?.toInt() ?? 0;
            _myPosition = teamOrder;
            _totalParticipants = rostersList.length;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching live tournament details: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _shareViaWhatsApp() {
    final bool isSolo = widget.tournamentType == '1v1';
    final String shareMessage;

    final ref = widget.orderReference ??
        widget.tournamentId.substring(0, min(8, widget.tournamentId.length));
    if (isSolo) {
      final ranking = (_myPosition > 0 && _maxCapacity > 0)
          ? '🏆 ترتيبي: اللاعب رقم #$_myPosition من أصل $_maxCapacity لاعب.'
          : '';
      shareMessage = [
        '🔥 أنا اشتركت رسمي في "$_tournamentName" على تطبيق VSP!',
        if (ranking.isNotEmpty) ranking,
        '⚽ مين قد التحدي؟ حمل التطبيق وسجل مكانك قبل اكتمال المقاعد!',
        '📌 كود الحجز: $ref',
      ].join('\n');
    } else {
      final team = widget.teamName?.trim().isNotEmpty == true ? widget.teamName!.trim() : 'فريقك';
      final ranking = (_myPosition > 0 && _maxCapacity > 0)
          ? '🏆 ترتيبنا: الفريق رقم #$_myPosition من أصل $_maxCapacity فرق.'
          : '';
      shareMessage = [
        '🔥 سجلنا رسمي لفريق "$team" في "$_tournamentName" على تطبيق VSP!',
        if (ranking.isNotEmpty) ranking,
        '⚽ جهزوا نفسكم للمنافسة على الكأس!',
        '📌 كود الحجز: $ref',
      ].join('\n');
    }

    VSPLauncherUtils.openWhatsApp(context, phone: '', message: shareMessage);
  }

  void _copyOrderReference() {
    final ref = widget.orderReference ??
        widget.tournamentId.substring(0, min(8, widget.tournamentId.length));
    Clipboard.setData(ClipboardData(text: ref));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'تم نسخ كود الاشتراك بنجاح',
          style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
        ),
        backgroundColor: VSPColors.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VSPRadius.sm)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _navigateToStandingsOrSchedule() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    // تفعيل تبويب الأبطال (index 2 في الشريط السفلي)
    playerHomeScreenKey.currentState?.switchToTab(2);

    if (widget.tournamentType == '1v1') {
      championScreenKey.currentState?.switchToTab(2);
    } else {
      championScreenKey.currentState?.switchToTab(0);
    }
  }

  void _returnHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    playerHomeScreenKey.currentState?.switchToTab(0);
  }

  @override
  Widget build(BuildContext context) {
    final isSolo = widget.tournamentType == '1v1';
    final participantLabel = isSolo ? 'اللاعب' : 'الفريق';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _returnHome();
      },
      child: VSPScaffold(
        backgroundColor: VSPColors.background,
        body: Stack(
          children: [
            // خلفية نيونية خافتة ناعمة
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: VSPColors.backgroundAura,
                ),
              ),
            ),

            // تأثير الكونفيتي المتساقط
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.directional,
                shouldLoop: false,
                numberOfParticles: 12,
                gravity: 0.18,
                colors: const [
                  VSPColors.accent,
                  VSPColors.white,
                  Color(0xFFFFD700), // ذهبي
                  Color(0xFF00E5FF), // سيان
                ],
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  // شريط علوي بسيط بزر إغلاق
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 40),
                        const Text(
                          'تأكيد الاشتراك',
                          style: TextStyle(
                            color: VSPColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Iconsax.close_circle_copy,
                              color: VSPColors.textSecondary, size: 26),
                          onPressed: _returnHome,
                        ),
                      ],
                    ),
                  ),

                  // محتوى قابل للتمرير
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Column(
                        children: [
                          const SizedBox(height: 12),

                          // شارة الكأس الاحتفالية المتحركة
                          ScaleTransition(
                            scale: _scaleAnimation,
                            child: Container(
                              width: 104,
                              height: 104,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: VSPColors.surfaceAlt,
                                border: Border.all(
                                  color: VSPColors.accent,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: VSPColors.accent.withValues(alpha: 0.35),
                                    blurRadius: 32,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Iconsax.cup_copy,
                                  color: VSPColors.accent,
                                  size: 52,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // عنوان التهاني
                          const Text(
                            'تم تأكيد الاشتراك بنجاح',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: VSPColors.textPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'تم تسجيلك رسميًا في البطولة',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: VSPColors.textSecondary.withValues(alpha: 0.9),
                              fontSize: 13,
                            ),
                          ),

                          const SizedBox(height: 24),

                          // بطاقة المقعد والترتيب اللحظي الديناميكي (أنت اللاعب رقم X من Y)
                          _buildDynamicPositionCard(participantLabel),

                          const SizedBox(height: 16),

                          // كارت تفاصيل البطولة المسترجعة ديناميكياً من السيرفر
                          _buildTournamentDetailsCard(),

                          const SizedBox(height: 24),

                          // Primary next step: open the tournament
                          SizedBox(
                            width: double.infinity,
                            height: VSPSize.buttonHeight,
                            child: ElevatedButton(
                              onPressed: _navigateToStandingsOrSchedule,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: VSPColors.accent,
                                foregroundColor: Colors.black,
                                shape: const StadiumBorder(),
                                elevation: 0,
                              ),
                              child: Text(
                                isSolo
                                    ? 'عرض البطولة والمباريات'
                                    : 'فتح البطولة وإدارة الفريق',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: VSPSpacing.sm),

                          // Secondary share action
                          SizedBox(
                            width: double.infinity,
                            height: VSPSize.buttonHeight,
                            child: OutlinedButton.icon(
                              onPressed: _shareViaWhatsApp,
                              icon: const Icon(Iconsax.message_copy, size: 19),
                              label: Text(
                                isSolo
                                    ? 'مشاركة الاشتراك'
                                    : 'مشاركة تسجيل الفريق',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: VSPColors.textPrimary,
                                side: const BorderSide(color: VSPColors.divider),
                                shape: const StadiumBorder(),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // زر العودة للرئيسية
                          TextButton(
                            onPressed: _returnHome,
                            child: const Text(
                              'العودة للصفحة الرئيسية',
                              style: TextStyle(
                                color: VSPColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// كارت الترتيب الديناميكي المباشر
  Widget _buildDynamicPositionCard(String participantLabel) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: VSPColors.surface,
          borderRadius: BorderRadius.circular(VSPRadius.card),
          border: Border.all(color: VSPColors.divider),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: VSPColors.accent,
            ),
          ),
        ),
      );
    }

    final bool hasCapacity = _maxCapacity > 0;
    final bool hasPosition = _myPosition > 0;
    final double fillPercentage = hasCapacity && hasPosition
        ? (_myPosition / _maxCapacity).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.card),
        border: Border.all(
          color: VSPColors.accent.withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F9FDF02),
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: VSPColors.accentSoft,
                  borderRadius: BorderRadius.circular(VSPRadius.full),
                  border: Border.all(
                      color: VSPColors.accent.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Iconsax.verify_copy,
                        color: VSPColors.accent, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      hasPosition && hasCapacity
                          ? 'أنت $participantLabel رقم #$_myPosition من $_maxCapacity'
                          : 'تم تأكيد اشتراكك بنجاح',
                      style: const TextStyle(
                        color: VSPColors.accent,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        fontFamily: 'Tajawal',
                        fontFamilyFallback: ['Poppins', 'sans-serif'],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // شريط التقدم اللحظي للسعة
          ClipRRect(
            borderRadius: BorderRadius.circular(VSPRadius.full),
            child: LinearProgressIndicator(
              value: fillPercentage,
              backgroundColor: VSPColors.surfaceAlt,
              valueColor: const AlwaysStoppedAnimation<Color>(VSPColors.accent),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                hasCapacity
                    ? 'المقاعد المحجوزة: $_totalParticipants / $_maxCapacity'
                    : 'بيانات السعة غير متاحة حالياً',
                style: const TextStyle(
                  color: VSPColors.textSecondary,
                  fontSize: 12,
                  fontFamily: 'Tajawal',
                  fontFamilyFallback: ['Poppins', 'sans-serif'],
                ),
              ),
              Text(
                hasCapacity
                    ? (_maxCapacity - _totalParticipants > 0
                        ? 'متبقي ${_maxCapacity - _totalParticipants} مقاعد فقط'
                        : 'اكتملت المقاعد!')
                    : 'السعة غير متاحة',
                style: TextStyle(
                  color: _maxCapacity - _totalParticipants <= 2
                      ? VSPColors.warning
                      : VSPColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// كارت تفاصيل البطولة الحقيقية من الداتا
  Widget _buildTournamentDetailsCard() {
    final formattedDate = _scheduledDate != null
        ? DateFormat('EEEE، d MMMM yyyy', 'ar').format(_scheduledDate!)
        : 'موعد الانطلاق غير محدد';

    final refCode = widget.orderReference ??
        (widget.tournamentId.length >= 8
            ? widget.tournamentId.substring(0, 8).toUpperCase()
            : widget.tournamentId.toUpperCase());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: VSPColors.surfaceAlt,
        borderRadius: BorderRadius.circular(VSPRadius.card),
        border: Border.all(color: VSPColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Iconsax.note_copy, color: VSPColors.accent, size: 18),
              const SizedBox(width: 8),
              const Text(
                'بيانات الاشتراك المعتمدة',
                style: TextStyle(
                  color: VSPColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: VSPColors.accentSoft,
                  borderRadius: BorderRadius.circular(VSPRadius.sm),
                ),
                child: const Text(
                  'مدفوع إلكترونياً ✓',
                  style: TextStyle(
                    color: VSPColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: VSPColors.divider, height: 1),
          const SizedBox(height: 14),

          // اسم البطولة
          _buildDetailRow(
            icon: Iconsax.award_copy,
            label: 'البطولة:',
            value: _tournamentName.isNotEmpty
                ? _tournamentName
                : 'اسم البطولة غير متاح',
            isBold: true,
          ),
          const SizedBox(height: 10),

          // المحافظة / الملعب
          _buildDetailRow(
            icon: Iconsax.location_copy,
            label: 'المكان:',
            value: _stadiumName != null
                ? '$_stadiumName${_governorate.isNotEmpty ? ' ($_governorate)' : ''}'
                : (_governorate.isNotEmpty ? _governorate : 'المكان غير محدد'),
          ),
          const SizedBox(height: 10),

          // موعد الانطلاق
          _buildDetailRow(
            icon: Iconsax.calendar_copy,
            label: 'موعد الانطلاق:',
            value: formattedDate,
          ),
          const SizedBox(height: 10),

          // الجائزة الأولى (إن وجدت)
          if (_prizePool > 0) ...[
            _buildDetailRow(
              icon: Iconsax.moneys_copy,
              label: 'مجموع الجوائز:',
              value: '${_prizePool.toStringAsFixed(0)} ج.م',
              valueColor: const Color(0xFFFFD700),
              isBold: true,
            ),
            const SizedBox(height: 10),
          ],

          // رسوم الاشتراك المدفوعة
          _buildDetailRow(
            icon: Iconsax.card_pos_copy,
            label: 'رسوم الاشتراك المسددة:',
            value: '${_entryFee.toStringAsFixed(0)} ج.م (باي موب)',
          ),
          const SizedBox(height: 12),

          // كود الحجز المرجعي مع زر النسخ
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: VSPColors.background,
              borderRadius: BorderRadius.circular(VSPRadius.sm),
              border: Border.all(color: VSPColors.divider),
            ),
            child: Row(
              children: [
                const Icon(Iconsax.ticket_copy,
                    color: VSPColors.textSecondary, size: 16),
                const SizedBox(width: 8),
                const Text(
                  'كود الحجز:',
                  style: TextStyle(
                    color: VSPColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    refCode,
                    style: const TextStyle(
                      color: VSPColors.accent,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                InkWell(
                  onTap: _copyOrderReference,
                  borderRadius: BorderRadius.circular(VSPRadius.xs),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Iconsax.copy_copy,
                        color: VSPColors.textSecondary, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool isBold = false,
  }) {
    return Row(
      children: [
        Icon(icon, color: VSPColors.textSecondary, size: 16),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: VSPColors.textSecondary,
            fontSize: 12.5,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: valueColor ?? VSPColors.textPrimary,
              fontSize: 12.5,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontFamily: 'Tajawal',
              fontFamilyFallback: const ['Poppins', 'sans-serif'],
            ),
          ),
        ),
      ],
    );
  }
}
