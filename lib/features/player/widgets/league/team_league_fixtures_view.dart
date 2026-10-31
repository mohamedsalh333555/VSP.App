import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import '../../../../core/repositories/league/team_league_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

class TeamLeagueFixturesView extends StatelessWidget {
  final List<TeamLeagueMatch> matches;
  final String userTeamId;
  final bool isCreator;
  final Function(TeamLeagueMatch match) onBookMatch;
  final Function(TeamLeagueMatch match) onRecordScore;
  final Function(TeamLeagueMatch match) onResolveDispute;

  const TeamLeagueFixturesView({
    super.key,
    required this.matches,
    required this.userTeamId,
    required this.isCreator,
    required this.onBookMatch,
    required this.onRecordScore,
    required this.onResolveDispute,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    if (matches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(VSPSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Iconsax.calendar_copy, size: 60, color: VSPColors.textSecondary.withValues(alpha: 0.3)),
              const SizedBox(height: 12),
              Text(
                isArabic
                    ? 'سيتم توليد جدول المباريات فور اكتمال فرق الدوري'
                    : 'The fixture schedule will be generated when all league teams have joined',
                textAlign: TextAlign.center,
                style: TextStyle(color: VSPColors.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    // Group matches by round / week
    final Map<int, List<TeamLeagueMatch>> roundMap = {};
    for (final m in matches) {
      roundMap.putIfAbsent(m.weekNumber, () => []).add(m);
    }

    final sortedRounds = roundMap.keys.toList()..sort();

    // Check if creator has matches that need review/confirmation (awaiting confirmation or dispute)
    final pendingCreatorMatches = matches.where((m) => m.isDisputed || m.isAwaitingConfirmation).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // 🚨 Section for Creator when action is needed: "يحتاج تدخلك"
        if (isCreator && pendingCreatorMatches.isNotEmpty) ...[
          _buildCreatorReviewHeader(pendingCreatorMatches.length, isArabic),
          ...pendingCreatorMatches.map((m) => _buildCreatorReviewCard(context, m)),
          const SizedBox(height: VSPSpacing.md),
          const Divider(color: VSPColors.divider, height: 24),
        ],

        // Rounds and Fixtures
        ...sortedRounds.map((round) {
          final roundMatches = roundMap[round] ?? [];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRoundHeader(isArabic ? 'الجولة $round' : 'Round $round'),
              ...roundMatches.map((m) => _buildMatchCard(context, m)),
              const SizedBox(height: VSPSpacing.md),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildCreatorReviewHeader(int count, bool isArabic) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Iconsax.judge_copy, color: Colors.amber, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isArabic ? 'مباريات بانتظار اعتمادك (منشئ الدوري)' : 'Matches awaiting your approval (league creator)',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
          ),
            style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13.5),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreatorReviewCard(BuildContext context, TeamLeagueMatch match) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isConflict = match.isDisputed;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(
          color: isConflict ? Colors.amber : VSPColors.accent,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${match.homeTeamName} × ${match.awayTeamName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isConflict ? Colors.amber : VSPColors.accent).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isConflict
                      ? (isArabic ? 'اختلاف نتيجتين' : 'Conflicting results')
                      : (isArabic ? 'بانتظار الاعتماد' : 'Awaiting approval'),
                  style: TextStyle(
                    color: isConflict ? Colors.amber : VSPColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              isConflict
                  ? (isArabic
                      ? 'الفريقان سجلا نتيجتين مختلفتين ويحتاج تدخلك لحسم النتيجة.'
                      : 'The teams submitted different results. Review and resolve the outcome.')
                  : (isArabic
                      ? 'الفريقان سجلا النتيجة بتطابق، اضغط للاعتماد النهائي وبدء عداد الـ 15 دقيقة.'
                      : 'Both teams submitted the same result. Approve it to start the 15-minute correction window.'),
              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12.5),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => onResolveDispute(match),
              style: ElevatedButton.styleFrom(
                backgroundColor: isConflict ? Colors.amber : VSPColors.accent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
              ),
              icon: const Icon(Iconsax.judge_copy, size: 18),
              label: Text(
                isConflict
                    ? (isArabic ? 'مراجعة النزاع وحسم النتيجة' : 'Review and resolve dispute')
                    : (isArabic ? 'اعتماد نتيجة المباراة' : 'Approve match result'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: VSPColors.accent,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _buildMatchCard(BuildContext context, TeamLeagueMatch match) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isUserMatch = match.homeTeamId == userTeamId || match.awayTeamId == userTeamId;
    final hasBooking = match.bookingId != null;
    final now = DateTime.now();
    final matchTime = match.scheduledTime;
    final isPastMatchTime = matchTime != null && now.isAfter(matchTime);

    // Format Match Day (e.g. السبت، 10 أكتوبر)
    String dateStr = isArabic ? 'يحدد لاحقاً' : 'To be scheduled';
    if (match.matchDay != null) {
      dateStr = DateFormat(isArabic ? 'EEEE، d MMMM' : 'EEEE, d MMMM', isArabic ? 'ar' : 'en').format(match.matchDay!);
    } else if (match.scheduledTime != null) {
      dateStr = DateFormat(isArabic ? 'EEEE، d MMMM' : 'EEEE, d MMMM', isArabic ? 'ar' : 'en').format(match.scheduledTime!);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(
          color: match.isDisputed
              ? Colors.amber.withValues(alpha: 0.6)
              : isUserMatch
                  ? VSPColors.accent.withValues(alpha: 0.5)
                  : VSPColors.borderLight,
          width: isUserMatch || match.isDisputed ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(VSPSpacing.md),
        child: Column(
          children: [
            // Status bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMatchStatusBadge(match, hasBooking, isArabic),
                if (isUserMatch)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: VSPColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isArabic ? 'مباراة فريقك ⭐' : 'Your team’s match ⭐',
                      style: TextStyle(color: VSPColors.accent, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Teams Row (No numbers/goals!)
            Row(
              children: [
                // Home Team
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        match.homeTeamName,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: match.homeTeamId == userTeamId ? VSPColors.accent : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (match.isConfirmed && match.winnerId == match.homeTeamId)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            isArabic ? 'فوز 🟢' : 'Win 🟢',
                            style: TextStyle(color: VSPColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),

                // Center VS / Outcome
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: match.isConfirmed
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: VSPColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: VSPColors.divider, width: 0.5),
                          ),
                          child: Text(
                            match.confirmedOutcome == 'draw'
                                ? (isArabic ? 'تعادل 🟡' : 'Draw 🟡')
                                : (isArabic ? 'انتهت' : 'Finished'),
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: VSPColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'VS',
                            style: TextStyle(
                              color: VSPColors.accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                ),

                // Away Team
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        match.awayTeamName,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: match.awayTeamId == userTeamId ? VSPColors.accent : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (match.isConfirmed && match.winnerId == match.awayTeamId)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            isArabic ? 'فوز 🟢' : 'Win 🟢',
                            style: TextStyle(color: VSPColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Date & Pitch Info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: VSPColors.surfaceAlt,
                borderRadius: BorderRadius.circular(VSPRadius.md),
              ),
              child: Row(
                children: [
                  const Icon(Iconsax.calendar_1_copy, size: 14, color: VSPColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    dateStr,
                    style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                  ),
                  if (match.stadiumName != null && match.stadiumName!.isNotEmpty) ...[
                    const Spacer(),
                    const Icon(Iconsax.location_copy, size: 14, color: VSPColors.accent),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        match.stadiumName!,
                        style: const TextStyle(color: VSPColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Contextual Action Buttons (Section 45 & 47)
            _buildContextualActionButton(
              context: context,
              match: match,
              isUserMatch: isUserMatch,
              hasBooking: hasBooking,
              isPastMatchTime: isPastMatchTime,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchStatusBadge(TeamLeagueMatch match, bool hasBooking, bool isArabic) {
    if (match.isLocked) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: VSPColors.accentSoft,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: VSPColors.accent, width: 0.5),
        ),
        child: Text(isArabic ? 'نتيجة معتمدة 🔒' : 'Result locked 🔒', style: const TextStyle(color: VSPColors.accent, fontSize: 11, fontWeight: FontWeight.bold)), 
      );
    }
    if (match.isConfirmed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: VSPColors.accentSoft,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(isArabic ? 'معتمدة (مهلة تعديل ⏱️)' : 'Approved (correction window ⏱️)', style: const TextStyle(color: VSPColors.accent, fontSize: 11, fontWeight: FontWeight.bold)), 
      );
    }
    if (match.isDisputed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: VSPColors.warning.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(isArabic ? 'اختلاف بالنتيجة' : 'Result disputed', style: const TextStyle(color: VSPColors.warning, fontSize: 11, fontWeight: FontWeight.bold)), 
      );
    }
    if (match.isAwaitingConfirmation) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: VSPColors.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(isArabic ? 'بانتظار الاعتماد' : 'Awaiting approval', style: const TextStyle(color: VSPColors.accent, fontSize: 11, fontWeight: FontWeight.bold)), 
      );
    }
    if (match.isAwaitingSubmissions) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: VSPColors.info.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(isArabic ? 'بانتظار الطرف الآخر' : 'Awaiting opponent', style: const TextStyle(color: VSPColors.info, fontSize: 11, fontWeight: FontWeight.bold)), 
      );
    }
    if (hasBooking) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: VSPColors.accentSoft,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.tick_circle_copy, size: 12, color: VSPColors.accent),
            SizedBox(width: 4),
            Text(isArabic ? 'تم الحجز' : 'Booked', style: const TextStyle(color: VSPColors.accent, fontSize: 11, fontWeight: FontWeight.bold)), 
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: VSPColors.surfaceAlt,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(isArabic ? 'مجدولة' : 'Scheduled', style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11)), 
    );
  }

  Widget _buildContextualActionButton({
    required BuildContext context,
    required TeamLeagueMatch match,
    required bool isUserMatch,
    required bool hasBooking,
    required bool isPastMatchTime,
  }) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    // 1. If Creator Action Needed (Dispute or Awaiting Confirmation):
    if (isCreator && (match.isDisputed || match.isAwaitingConfirmation)) {
      final isConflict = match.isDisputed;
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => onResolveDispute(match),
          style: ElevatedButton.styleFrom(
            backgroundColor: isConflict ? Colors.amber : VSPColors.accent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
          ),
          icon: const Icon(Iconsax.judge_copy, size: 16),
          label: Text(
            isConflict
                ? (isArabic ? 'مراجعة النزاع (منشئ الدوري)' : 'Review dispute (league creator)')
                : (isArabic ? 'اعتماد النتيجة (منشئ الدوري)' : 'Approve result (league creator)'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      );
    }

    // 2. If Disputed (non-creator view):
    if (match.isDisputed) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(VSPRadius.md),
        ),
        child: Text(
          isArabic ? 'النتيجة قيد المراجعة من منشئ الدوري' : 'The league creator is reviewing this result',
          style: TextStyle(color: Colors.amber, fontSize: 12.5, fontWeight: FontWeight.bold),
        ),
      );
    }

    // 3. If Awaiting Confirmation (non-creator view):
    if (match.isAwaitingConfirmation) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: VSPColors.accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(VSPRadius.md),
        ),
        child: Text(
          isArabic ? 'سجل الفريقان النتيجة - بانتظار اعتماد منشئ الدوري' : 'Both teams submitted a result — awaiting league creator approval',
          style: TextStyle(color: VSPColors.accent, fontSize: 12.5, fontWeight: FontWeight.bold),
        ),
      );
    }

    // 4. If Confirmed:
    if (match.isConfirmed) {
      if (!match.isLocked && isCreator) {
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => onResolveDispute(match),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: VSPColors.accent),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
            ),
            icon: const Icon(Iconsax.edit_2_copy, size: 16, color: VSPColors.accent),
            label: Text(
              isArabic ? 'تعديل النتيجة (مهلة 15 دقيقة)' : 'Edit result (15-minute window)',
              style: const TextStyle(color: VSPColors.accent, fontSize: 12),
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    // 5. If user submitted and waiting for opponent:
    if (isUserMatch && match.myTeamSubmission != null && match.opponentTeamSubmission == null) {
      final subText = match.myTeamSubmission == 'win'
          ? (isArabic ? 'فوز' : 'Win')
          : match.myTeamSubmission == 'draw'
              ? (isArabic ? 'تعادل' : 'Draw')
              : (isArabic ? 'خسارة' : 'Loss');
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: VSPColors.surfaceAlt,
          borderRadius: BorderRadius.circular(VSPRadius.md),
        ),
        child: Text(
          isArabic
              ? 'تم تسجيل نتيجتك ($subText) - بانتظار الفريق الآخر'
              : 'Your result ($subText) is submitted — waiting for the other team',
          style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12.5),
        ),
      );
    }

    // A match must be booked before its result can be submitted.
    if (!hasBooking && isUserMatch) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => onBookMatch(match),
          style: ElevatedButton.styleFrom(
            backgroundColor: VSPColors.surfaceAlt,
            foregroundColor: Colors.white,
            side: const BorderSide(color: VSPColors.accent, width: 1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
          ),
          icon: const Icon(Iconsax.calendar_tick_copy, size: 16, color: VSPColors.accent),
          label: Text(isArabic ? 'حجز موعد المباراة' : 'Book match time', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      );
    }

    // Result submission is exposed only after the scheduled kickoff time.
    if (isUserMatch && match.myTeamSubmission == null) {
      if (!isPastMatchTime) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: VSPColors.surfaceAlt,
            borderRadius: BorderRadius.circular(VSPRadius.md),
          ),
          child: Text(
            match.scheduledTime == null
                ? (isArabic ? 'سيظهر تسجيل النتيجة بعد تحديد موعد المباراة.' : 'Result submission opens after a match time is scheduled.')
                : (isArabic ? 'يمكن تسجيل النتيجة بعد موعد المباراة.' : 'You can submit the result after the scheduled match time.'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12.5),
          ),
        );
      }
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => onRecordScore(match),
          style: ElevatedButton.styleFrom(
            backgroundColor: VSPColors.accent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
          ),
          icon: const Icon(Iconsax.tick_circle_copy, size: 16),
          label: Text(isArabic ? 'تسجيل نتيجة فريقك' : 'Submit your team’s result', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
