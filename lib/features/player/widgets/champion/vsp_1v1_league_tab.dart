import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/egypt_governorates.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/repositories/league_repository.dart';
import '../../../../core/services/paymob_service.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../data/models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/vsp_error_state.dart';
import '../../../../shared/widgets/vsp_fade_in_item.dart';
import '../../screens/paymob_web_view_screen.dart';
import 'champion_podium_components.dart';

class Vsp1v1LeagueTab extends StatefulWidget {
  final String selectedLocation;
  final ValueChanged<String> onLocationChanged;
  final Stream<Map<String, dynamic>?> Function(String) getActive1v1Stream;
  final Stream<List<Map<String, dynamic>>> Function(String) getTournamentPlayersStream;
  final Stream<List<VSP1v1Player>> Function(String?) getStandingsStream;
  final VoidCallback onRetry;

  const Vsp1v1LeagueTab({
    super.key,
    required this.selectedLocation,
    required this.onLocationChanged,
    required this.getActive1v1Stream,
    required this.getTournamentPlayersStream,
    required this.getStandingsStream,
    required this.onRetry,
  });

  @override
  State<Vsp1v1LeagueTab> createState() => _Vsp1v1LeagueTabState();
}

class _Vsp1v1LeagueTabState extends State<Vsp1v1LeagueTab> {
  bool _isProcessingPayment = false;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final userGovRaw = auth.userModel?.governorate ?? auth.governorate;
    final userGov = EgyptGovernorates.resolveGoogleName(userGovRaw) ?? userGovRaw;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    // Fallback prompt if player has no governorate set in profile
    if (userGov.trim().isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: VSPColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: VSPColors.divider.withValues(alpha: 0.3)),
                ),
                child: const Icon(Iconsax.location_slash_copy, size: 38, color: VSPColors.accent),
              ),
              const SizedBox(height: 16),
              Text(
                isArabic ? 'يرجى تحديد محافظتك من الملف الشخصي' : 'Please set your governorate in profile',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                isArabic
                    ? 'حدد محافظتك لمشاهدة بطولات منطقتك والمشاركة بها'
                    : 'Set your home governorate to view and join local 1v1 tournaments',
                textAlign: TextAlign.center,
                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/edit-profile');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: VSPColors.accent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                icon: const Icon(Iconsax.edit_2_copy, size: 16, color: Colors.black),
                label: Text(
                  isArabic ? 'تحديد المحافظة الآن' : 'Set Governorate',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Effective governorate for 1v1: uses widget.selectedLocation (supports curious browsing)
    final effectiveLocation = widget.selectedLocation == 'All' ? userGov : widget.selectedLocation;
    final isBrowsingDifferentGov =
        userGov.isNotEmpty && effectiveLocation.toLowerCase() != userGov.toLowerCase();

    return StreamBuilder<Map<String, dynamic>?>(
      stream: widget.getActive1v1Stream(effectiveLocation),
      builder: (context, tourneySnap) {
        if (tourneySnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
        }

        final tournament = tourneySnap.data;
        if (tournament == null) {
          final locName = championTranslateItem(context, effectiveLocation);
          return Column(
            children: [
              if (isBrowsingDifferentGov) _buildGovBrowsingBanner(userGov, isArabic),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: VSPColors.surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: VSPColors.divider.withValues(alpha: 0.3)),
                          ),
                          child: const Icon(Iconsax.cup_copy, size: 38, color: VSPColors.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isArabic
                              ? 'لا توجد بطولة فردية نشطة حالياً في $locName'
                              : 'No active 1v1 tournament in $locName',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isArabic
                              ? 'ترقبوا إعلان موعد وتفاصيل بطولة 1vs1 القادمة قريباً!'
                              : 'Stay tuned for upcoming 1v1 announcements!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        final status = tournament['status'] as String? ?? 'registration_open';
        final isCompleted = status == 'completed' || status == 'published';

        return Column(
          children: [
            if (isBrowsingDifferentGov) _buildGovBrowsingBanner(userGov, isArabic),
            Expanded(
              child: isCompleted
                  ? _build1v1StandingsPhase(tournament)
                  : _build1v1RegistrationPhase(
                      tournament,
                      isBrowsingDifferentGov: isBrowsingDifferentGov,
                      userGov: userGov,
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGovBrowsingBanner(String userGov, bool isArabic) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Iconsax.location_copy, color: VSPColors.accent, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isArabic
                  ? 'تتصفح بطولات: ${championTranslateItem(context, widget.selectedLocation)}'
                  : 'Viewing: ${championTranslateItem(context, widget.selectedLocation)}',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          InkWell(
            onTap: () => widget.onLocationChanged(userGov),
            borderRadius: BorderRadius.circular(VSPRadius.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                isArabic ? 'بطولاتي ($userGov)' : 'My City ($userGov)',
                style: const TextStyle(color: VSPColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _build1v1RegistrationPhase(
    Map<String, dynamic> tournament, {
    bool isBrowsingDifferentGov = false,
    String userGov = '',
  }) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.currentUser?.uid;
    final tournamentId = tournament['id']?.toString() ?? '';
    final tourneyName = tournament['name'] as String? ?? 'بطولة VSP فردي 1vs1';
    final targetCount = (tournament['target_player_count'] as num?)?.toInt() ?? 16;
    final scheduledAt = tournament['scheduled_at'] as String?;
    final status = tournament['status'] as String? ?? 'registration_open';
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final entryFee = (tournament['entry_fee'] as num?)?.toDouble() ?? 0.0;
    final prizePool = (tournament['prize_pool'] as num?)?.toDouble() ?? 0.0;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: widget.getTournamentPlayersStream(tournamentId),
      builder: (context, playersSnap) {
        final players = playersSnap.data ?? [];
        final registeredCount = players.length;
        final remainingCount = (targetCount - registeredCount).clamp(0, 999);
        final progress = targetCount > 0 ? (registeredCount / targetCount).clamp(0.0, 1.0) : 0.0;
        final isRegistered = currentUserId != null && players.any((p) => p['user_id'] == currentUserId);
        final myIndex = isRegistered ? players.indexWhere((p) => p['user_id'] == currentUserId) + 1 : null;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: VSPScrollPadding.forList(context, hasFloatingNavBar: true, top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Hero Countdown & Timeline Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E2614), VSPColors.surface],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: VSPColors.accent.withValues(alpha: 0.35)),
                  boxShadow: [
                    BoxShadow(
                      color: VSPColors.accent.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tourneyName,
                                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (tournament['governorate'] != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Iconsax.location_copy, size: 13, color: VSPColors.accent),
                                    const SizedBox(width: 4),
                                    Text(
                                      championTranslateItem(context, tournament['governorate'].toString()),
                                      style: const TextStyle(
                                          color: VSPColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: status == 'registration_open' ? const Color(0xFF14301A) : const Color(0xFF332B10),
                            borderRadius: BorderRadius.circular(VSPRadius.full),
                            border: Border.all(
                              color: status == 'registration_open' ? const Color(0xFF22C55E) : const Color(0xFFEAB308),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            status == 'registration_open'
                                ? (isArabic ? 'التسجيل متاح' : 'Open')
                                : (isArabic ? 'التسجيل مغلق' : 'Closed'),
                            style: TextStyle(
                              color: status == 'registration_open' ? const Color(0xFF4ADE80) : const Color(0xFFFDE047),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Date & Countdown Badges
                    if (scheduledAt != null) ...[
                      Row(
                        children: [
                          const Icon(Iconsax.calendar_1_copy, size: 16, color: VSPColors.accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _formatScheduledDate(scheduledAt),
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Iconsax.clock_copy, size: 16, color: VSPColors.accent),
                          const SizedBox(width: 8),
                          Text(
                            _calculateCountdown(scheduledAt),
                            style: const TextStyle(color: VSPColors.accent, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Capacity Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isArabic ? 'المقاعد المحجوزة' : 'Seats Reserved',
                          style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                        ),
                        Text(
                          '$registeredCount / $targetCount ($remainingCount ${isArabic ? "متبقي" : "left"})',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: VSPColors.surfaceAlt,
                        valueColor: const AlwaysStoppedAnimation<Color>(VSPColors.accent),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 2. Financial Prize Pool & Entry Fee Transparency Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: VSPColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: VSPColors.divider.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    // Entry Fee Column
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: VSPColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: VSPColors.divider.withValues(alpha: 0.25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Iconsax.ticket_copy, size: 15, color: VSPColors.textSecondary),
                                const SizedBox(width: 6),
                                Text(
                                  isArabic ? 'رسوم الاشتراك' : 'Entry Fee',
                                  style: const TextStyle(
                                      color: VSPColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${entryFee.toStringAsFixed(0)} ${isArabic ? "ج.م" : "EGP"}',
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isArabic ? 'دفع إلكتروني إلزامي' : 'Mandatory e-pay',
                              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Prize Pool Column (Live Accumulator)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF162512),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: VSPColors.accent.withValues(alpha: 0.35)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Iconsax.moneys_copy, size: 15, color: VSPColors.accent),
                                const SizedBox(width: 6),
                                Text(
                                  isArabic ? 'الجائزة التراكمية' : 'Live Prize Pool',
                                  style: const TextStyle(
                                      color: VSPColors.accent, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${prizePool.toStringAsFixed(0)} ${isArabic ? "ج.م" : "EGP"}',
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$registeredCount ${isArabic ? "دفعوا واشتركوا" : "paid entries"}',
                              style: const TextStyle(
                                  color: Color(0xFF86EFAC), fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 3. Interactive Registration Action Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: isRegistered
                    ? Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF142E18),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Iconsax.tick_circle_copy, color: Color(0xFF22C55E), size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isArabic ? 'أنت مسجل في البطولة بنجاح!' : 'You are registered!',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isArabic
                                        ? 'رقم مقعدك في الجدول: #$myIndex (تم سداد الاشتراك)'
                                        : 'Your seat number: #$myIndex (Entry fee paid)',
                                    style: const TextStyle(color: Color(0xFF86EFAC), fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    : isBrowsingDifferentGov
                        ? Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF231C10),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFEAB308).withValues(alpha: 0.4)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    const Icon(Iconsax.info_circle_copy, color: Color(0xFFFDE047), size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        isArabic
                                            ? 'أنت تتصفح بطولة خارج محافظتك (${championTranslateItem(context, tournament['governorate'] ?? widget.selectedLocation)}). الاشتراك متاح فقط في بطولات محافظتك ($userGov).'
                                            : 'Viewing tournament in ${championTranslateItem(context, tournament['governorate'] ?? widget.selectedLocation)}. Registration is available only in your home city ($userGov).',
                                        style: const TextStyle(
                                            color: Color(0xFFFDE047), fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  height: 44,
                                  child: OutlinedButton.icon(
                                    onPressed: () => widget.onLocationChanged(userGov),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFFEAB308)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    icon: const Icon(Iconsax.location_copy, size: 16, color: Color(0xFFFDE047)),
                                    label: Text(
                                      isArabic
                                          ? 'الانتقال إلى بطولات محافظتي ($userGov)'
                                          : 'Switch to My City ($userGov)',
                                      style: const TextStyle(
                                          color: Color(0xFFFDE047), fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : (status == 'registration_open' && remainingCount > 0)
                            ? PrimaryButton(
                                text: _isProcessingPayment
                                    ? (isArabic ? 'جاري فتح بوابة الدفع...' : 'Opening payment...')
                                    : (isArabic
                                        ? 'سداد الاشتراك والانضمام (${entryFee.toStringAsFixed(0)} ج.م)'
                                        : 'Pay & Join (${entryFee.toStringAsFixed(0)} EGP)'),
                                height: 50,
                                color: VSPColors.accent,
                                textColor: Colors.black,
                                onPressed: _isProcessingPayment ? () {} : () => _handleJoin1v1(tournamentId, entryFee),
                              )
                            : Container(
                                padding: const EdgeInsets.all(14),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: VSPColors.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: VSPColors.divider),
                                ),
                                child: Text(
                                  isArabic ? 'اكتمل العدد أو تم إغلاق باب التسجيل' : 'Registration is closed or full',
                                  style: const TextStyle(
                                      color: VSPColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ),
              ),

              const SizedBox(height: 24),

              // 4. Registered Players Table Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isArabic ? 'جدول المسجلين بالبطولة' : 'Registered Roster',
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: VSPColors.surface,
                        borderRadius: BorderRadius.circular(VSPRadius.full),
                        border: Border.all(color: VSPColors.divider, width: 0.5),
                      ),
                      child: Text(
                        '$registeredCount ${isArabic ? "لاعبين" : "players"}',
                        style: const TextStyle(color: VSPColors.accent, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 5. Registered Players List
              if (players.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      isArabic
                          ? 'كن أول من يسجل ويسدد للاشتراك في هذه البطولة!'
                          : 'Be the first to register and join this tournament!',
                      style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: players.length,
                  itemBuilder: (ctx, idx) {
                    final p = players[idx];
                    final pName = p['player_name'] ?? 'لاعب';
                    final pAvatar = p['avatar_url'] as String? ?? '';
                    final isMe = currentUserId != null && p['user_id'] == currentUserId;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isMe ? const Color(0xFF1B2A16) : VSPColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isMe ? VSPColors.accent : VSPColors.divider.withValues(alpha: 0.3),
                          width: isMe ? 1.5 : 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 28,
                            child: Text(
                              '#${idx + 1}',
                              style: TextStyle(
                                color: isMe ? VSPColors.accent : VSPColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: VSPColors.surfaceAlt,
                              border: Border.all(color: isMe ? VSPColors.accent : VSPColors.divider, width: 1),
                            ),
                            child: ClipOval(
                              child: pAvatar.isNotEmpty
                                  ? CachedNetworkImage(imageUrl: pAvatar, fit: BoxFit.cover)
                                  : Center(
                                      child: Text(
                                        pName.isNotEmpty ? pName[0].toUpperCase() : 'P',
                                        style: TextStyle(
                                            color: isMe ? VSPColors.accent : Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              pName + (isMe ? (isArabic ? ' (أنت)' : ' (You)') : ''),
                              style: TextStyle(
                                color: isMe ? VSPColors.accent : Colors.white,
                                fontWeight: isMe ? FontWeight.w900 : FontWeight.w600,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF142E18),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.3), width: 0.5),
                            ),
                            child: Text(
                              isArabic ? 'مسجل ومسدد' : 'Paid & Confirmed',
                              style:
                                  const TextStyle(color: Color(0xFF86EFAC), fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _build1v1StandingsPhase(Map<String, dynamic> tournament) {
    final tourneyId = tournament['id']?.toString();
    return StreamBuilder<List<VSP1v1Player>>(
      stream: widget.getStandingsStream(tourneyId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
        }
        if (snapshot.hasError) {
          return VSPErrorState(
            customMessage: snapshot.error?.toString(),
            onRetry: () => setState(() {}),
          );
        }
        final players = snapshot.data ?? [];
        if (players.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: VSPColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: VSPColors.divider.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Iconsax.cup_copy, size: 38, color: VSPColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.noOneVsOneRanked,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        }

        final top3 = players.take(3).toList();
        final rest = players.skip(3).toList();

        if (players.length < 3) {
          return ListView.builder(
            padding: EdgeInsets.fromLTRB(16, VSPSpacing.md, 16, MediaQuery.of(context).padding.bottom + 24),
            physics: const BouncingScrollPhysics(),
            itemCount: players.length,
            itemBuilder: (ctx, i) => VSPFadeInItem(
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _build1v1RankListItem(players[i], i + 1),
              ),
            ),
          );
        }

        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: VSPScrollPadding.forList(context, hasFloatingNavBar: true, top: 12),
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // Premium 1v1 Podium
              SizedBox(
                height: 290,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Rank 2 - Left (Silver)
                    Expanded(
                      child: VSPFadeInItem(
                        index: 1,
                        child: ChampionPodiumItem(
                          rank: 2,
                          name: top3[1].name,
                          logo: top3[1].avatarUrl,
                          points: top3[1].totalPoints,
                          badgeIcon: Iconsax.medal_star_copy,
                          borderColor: const Color(0xFFC0C0C0),
                          bgColor: VSPColors.surface,
                          pointsLabel: Localizations.localeOf(context).languageCode == 'ar' ? 'نقطة' : 'PTS',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Rank 1 - Center (Gold Champion)
                    Expanded(
                      child: VSPFadeInItem(
                        index: 0,
                        child: ChampionPodiumItem(
                          rank: 1,
                          name: top3[0].name,
                          logo: top3[0].avatarUrl,
                          points: top3[0].totalPoints,
                          badgeIcon: Iconsax.crown_copy,
                          borderColor: VSPColors.accent,
                          bgColor: const Color(0xFF1E2614),
                          isCenter: true,
                          pointsLabel: Localizations.localeOf(context).languageCode == 'ar' ? 'نقطة' : 'PTS',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Rank 3 - Right (Bronze)
                    Expanded(
                      child: VSPFadeInItem(
                        index: 2,
                        child: ChampionPodiumItem(
                          rank: 3,
                          name: top3[2].name,
                          logo: top3[2].avatarUrl,
                          points: top3[2].totalPoints,
                          badgeIcon: Iconsax.award_copy,
                          borderColor: const Color(0xFFCD7F32),
                          bgColor: VSPColors.surface,
                          pointsLabel: Localizations.localeOf(context).languageCode == 'ar' ? 'نقطة' : 'PTS',
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Expanded Ranking List (#4, #5...)
              ...List.generate(rest.length, (index) {
                final player = rest[index];
                final rank = index + 4;
                return VSPFadeInItem(
                  index: index + 3,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _build1v1RankListItem(player, rank),
                  ),
                );
              }),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _build1v1RankListItem(VSP1v1Player player, int rank) {
    final initialLetter =
        player.name.trim().isNotEmpty ? player.name.trim().split(' ').last.substring(0, 1).toUpperCase() : 'P';
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: VSPColors.divider.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Rank Number
          SizedBox(
            width: 28,
            child: Text(
              '#$rank',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: rank <= 3 ? VSPColors.accent : VSPColors.textSecondary,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
            ),
          ),

          // Player Avatar / Initial
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: VSPColors.surfaceAlt,
              border: Border.all(color: VSPColors.divider, width: 1),
            ),
            child: ClipOval(
              child: player.avatarUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: player.avatarUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          ChampionInitialBadge(letter: initialLetter, accentColor: VSPColors.accent),
                    )
                  : ChampionInitialBadge(letter: initialLetter, accentColor: VSPColors.accent),
            ),
          ),
          const SizedBox(width: 12),

          // Player Name & Breakdown
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  isArabic
                      ? 'قطع كرات: ${player.tackles}  •  أهداف: ${player.goals}  •  مهارات: ${player.skillPoints}'
                      : 'Tackles: ${player.tackles}  •  Goals: ${player.goals}  •  Skills: ${player.skillPoints}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: VSPColors.textSecondary,
                        fontSize: 11,
                      ),
                ),
              ],
            ),
          ),

          // Total Points Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: VSPColors.surfaceAlt,
              borderRadius: BorderRadius.circular(VSPRadius.md),
              border: Border.all(color: VSPColors.divider.withValues(alpha: 0.4)),
            ),
            child: Text(
              '${player.totalPoints} ${isArabic ? "نقطة" : "PTS"}',
              style: const TextStyle(
                color: VSPColors.accent,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleJoin1v1(String tournamentId, double entryFee) async {
    if (_isProcessingPayment) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    if (user == null) {
      VSPFeedback.showError(context, isArabic ? 'يجب تسجيل الدخول أولاً للمشاركة.' : 'Please log in to join.');
      return;
    }

    setState(() => _isProcessingPayment = true);

    try {
      // 1. Create atomic payment order on database
      final orderRes = await LeagueRepository().create1v1PaymentOrder(tournamentId);
      if (orderRes['success'] != true) {
        if (!mounted) return;
        VSPFeedback.showError(
          context,
          orderRes['error']?.toString() ??
              (isArabic ? 'فشل إنشاء طلب الاشتراك في البطولة.' : 'Failed to create registration order.'),
        );
        return;
      }

      final orderRef = orderRes['order_reference'] as String;
      final orderAmount = (orderRes['amount'] as num?)?.toDouble() ?? entryFee;

      final userName = auth.userModel?.name ?? 'Player';
      final userPhone = auth.userModel?.phone ?? '';
      final userEmail = user.email ?? 'player@vsp.app';

      // 2. Obtain secure Paymob checkout URL via Supabase Edge Function
      final checkoutUrl = await PaymobService.getCheckoutUrlFromServer(
        amountInEgp: orderAmount,
        bookingId: orderRef,
        userEmail: userEmail,
        userName: userName,
        userPhone: userPhone,
        isTournamentPayment: true,
      );

      if (!mounted) return;

      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        VSPFeedback.showError(
          context,
          isArabic ? 'تعذر فتح بوابة الدفع الآمنة، يرجى المحاولة لاحقاً.' : 'Unable to open secure checkout gateway.',
        );
        return;
      }

      // 3. Open Paymob WebView Screen
      final isPaidSuccess = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PaymobWebViewScreen(
            initialUrl: checkoutUrl,
            title: isArabic ? 'سداد اشتراك البطولة' : 'Tournament Checkout',
            bookingId: orderRef,
          ),
        ),
      );

      if (!mounted) return;

      // 4. Verification Check
      final isRegistered = await LeagueRepository().isUserRegisteredIn1v1(tournamentId, user.uid);
      if (!mounted) return;

      if (isPaidSuccess == true || isRegistered) {
        VSPFeedback.showSuccess(
          context,
          isArabic
              ? 'تم تأكيد الدفع وتسجيلك في البطولة بنجاح!'
              : 'Payment confirmed! You are registered in the tournament.',
        );
        setState(() {});
      } else {
        VSPFeedback.showError(
          context,
          isArabic ? 'لم يتم إتمام الدفع، لم يتم تسجيلك في البطولة.' : 'Payment not completed. You were not registered.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Error in _handleJoin1v1: $e');
      VSPFeedback.showError(
        context,
        isArabic ? 'حدث خطأ أثناء معالجة الدفع: $e' : 'Payment error occurred: $e',
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessingPayment = false);
      }
    }
  }

  String _formatScheduledDate(String? rawIso) {
    if (rawIso == null) return 'قريباً';
    try {
      final dt = DateTime.parse(rawIso).toLocal();
      final dayNames = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
      final monthNames = [
        '',
        'يناير',
        'فبراير',
        'مارس',
        'أبريل',
        'مايو',
        'يونيو',
        'يوليو',
        'أغسطس',
        'سبتمبر',
        'أكتوبر',
        'نوفمبر',
        'ديسمبر'
      ];
      final dayName = dayNames[dt.weekday - 1];
      final monthName = monthNames[dt.month];
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final period = dt.hour >= 12 ? 'م' : 'ص';
      final min = dt.minute.toString().padLeft(2, '0');
      return '$dayName، ${dt.day} $monthName - $hour:$min $period';
    } catch (_) {
      return rawIso;
    }
  }

  String _calculateCountdown(String? rawIso) {
    if (rawIso == null) return '';
    try {
      final dt = DateTime.parse(rawIso).toLocal();
      final now = DateTime.now();
      final diff = dt.difference(now);
      if (diff.isNegative) return 'انطلقت الفعالية الآن ⏱️';
      if (diff.inDays > 0) {
        final hours = diff.inHours % 24;
        return 'متبقي ${diff.inDays} يوم و $hours ساعة';
      }
      if (diff.inHours > 0) {
        final mins = diff.inMinutes % 60;
        return 'متبقي ${diff.inHours} ساعة و $mins دقيقة';
      }
      return 'متبقي ${diff.inMinutes} دقيقة';
    } catch (_) {
      return '';
    }
  }
}
