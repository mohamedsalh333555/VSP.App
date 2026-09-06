import os

path = r'K:\.gemini\antigravity\scratch\vsp_application\lib\features\player\screens\champion_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    text = f.read()

# Make sure needed imports exist
if "import '../../../core/utils/vsp_feedback.dart';" not in text:
    text = text.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport '../../../core/utils/vsp_feedback.dart';")

new_1v1_block = '''  Widget _build1v1PlayersRanking() {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: LeagueRepository().getActive1v1TournamentStream(),
      builder: (context, tourneySnap) {
        if (tourneySnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
        }

        final tournament = tourneySnap.data;
        if (tournament == null) {
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
                  const Text(
                    'لا توجد بطولة فردية نشطة حالياً',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'ترقبوا إعلان موعد وتفاصيل بطولة 1vs1 القادمة قريباً!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }

        final status = tournament['status'] as String? ?? 'registration_open';
        final isCompleted = status == 'completed' || status == 'published';

        if (!isCompleted) {
          // ==================== REGISTRATION & COUNTDOWN PHASE ====================
          return _build1v1RegistrationPhase(tournament);
        }

        // ==================== COMPLETED STANDINGS & PODIUM PHASE ====================
        return _build1v1StandingsPhase(tournament);
      },
    );
  }

  Widget _build1v1RegistrationPhase(Map<String, dynamic> tournament) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.currentUser?.uid;
    final tournamentId = tournament['id']?.toString() ?? '';
    final tourneyName = tournament['name'] as String? ?? 'بطولة VSP فردي 1vs1';
    final targetCount = (tournament['target_player_count'] as num?)?.toInt() ?? 16;
    final scheduledAt = tournament['scheduled_at'] as String?;
    final status = tournament['status'] as String? ?? 'registration_open';
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: LeagueRepository().getTournamentPlayersStream(tournamentId, isCompleted: false),
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
                          child: Text(
                            tourneyName,
                            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                                ? (isArabic ? 'التسجيل متاح 🟢' : 'Open 🟢')
                                : (isArabic ? 'التسجيل مغلق ⏱️' : 'Closed ⏱️'),
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

              const SizedBox(height: 16),

              // 2. Interactive Registration Action Card
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
                                    isArabic ? 'أنت مسجل في البطولة بنجاح! 🏆' : 'You are registered! 🏆',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isArabic ? 'رقم مقعدك في الجدول: #$myIndex' : 'Your seat number: #$myIndex',
                                    style: const TextStyle(color: Color(0xFF86EFAC), fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            if (status == 'registration_open')
                              TextButton(
                                onPressed: () => _handleLeave1v1(tournamentId),
                                child: Text(
                                  isArabic ? 'إلغاء' : 'Cancel',
                                  style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                      )
                    : (status == 'registration_open' && remainingCount > 0)
                        ? PrimaryButton(
                            text: isArabic ? 'انضم للبطولة الآن ⚡' : 'Join Tournament Now ⚡',
                            height: 50,
                            color: VSPColors.accent,
                            textColor: Colors.black,
                            onPressed: () => _handleJoin1v1(tournamentId),
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
                              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
              ),

              const SizedBox(height: 24),

              // 3. Registered Players Table Header
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

              // 4. Registered Players List
              if (players.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      isArabic ? 'كن أول من يسجل وينضم لهذه البطولة! ⚡' : 'Be the first to join this tournament! ⚡',
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
                                        style: TextStyle(color: isMe ? VSPColors.accent : Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              pName + (isMe ? ' (أنت)' : ''),
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
                              color: VSPColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isArabic ? 'مسجل رسمي' : 'Confirmed',
                              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
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
    return StreamBuilder<List<VSP1v1Player>>(
      stream: LeagueRepository().get1v1Standings(),
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
                        child: _buildTopRankItem(
                          rank: 2,
                          name: top3[1].name,
                          logo: top3[1].avatarUrl,
                          points: top3[1].totalPoints,
                          badgeIcon: Iconsax.medal_star_copy,
                          borderColor: const Color(0xFFC0C0C0),
                          bgColor: VSPColors.surface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Rank 1 - Center (Gold Champion)
                    Expanded(
                      child: VSPFadeInItem(
                        index: 0,
                        child: _buildTopRankItem(
                          rank: 1,
                          name: top3[0].name,
                          logo: top3[0].avatarUrl,
                          points: top3[0].totalPoints,
                          badgeIcon: Iconsax.crown_copy,
                          borderColor: VSPColors.accent,
                          bgColor: const Color(0xFF1E2614),
                          isCenter: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Rank 3 - Right (Bronze)
                    Expanded(
                      child: VSPFadeInItem(
                        index: 2,
                        child: _buildTopRankItem(
                          rank: 3,
                          name: top3[2].name,
                          logo: top3[2].avatarUrl,
                          points: top3[2].totalPoints,
                          badgeIcon: Iconsax.award_copy,
                          borderColor: const Color(0xFFCD7F32),
                          bgColor: VSPColors.surface,
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

  Future<void> _handleJoin1v1(String tournamentId) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.currentUser == null) {
      VSPFeedback.showError(context, 'يجب تسجيل الدخول أولاً للمشاركة.');
      return;
    }

    try {
      final res = await LeagueRepository().join1v1Tournament(tournamentId);
      if (!mounted) return;
      if (res['success'] == true) {
        VSPFeedback.showSuccess(context, res['message'] ?? 'تم تسجيلك بنجاح! ⚡');
        setState(() {});
      } else {
        VSPFeedback.showError(context, res['error'] ?? 'فشل التسجيل في البطولة.');
      }
    } catch (e) {
      if (!mounted) return;
      VSPFeedback.showError(context, 'حدث خطأ: $e');
    }
  }

  Future<void> _handleLeave1v1(String tournamentId) async {
    try {
      final res = await LeagueRepository().leave1v1Tournament(tournamentId);
      if (!mounted) return;
      if (res['success'] == true) {
        VSPFeedback.showSuccess(context, 'تم إلغاء التسجيل.');
        setState(() {});
      } else {
        VSPFeedback.showError(context, res['error'] ?? 'فشل إلغاء التسجيل.');
      }
    } catch (e) {
      if (!mounted) return;
      VSPFeedback.showError(context, 'حدث خطأ: $e');
    }
  }

  String _formatScheduledDate(String? rawIso) {
    if (rawIso == null) return 'قريباً';
    try {
      final dt = DateTime.parse(rawIso).toLocal();
      final dayNames = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
      final monthNames = ['', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
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
  }'''

# Replace from 'Widget _build1v1PlayersRanking()' to 'Widget _buildTeamsRankingStream()'
start_marker = '  Widget _build1v1PlayersRanking()'
end_marker = '  Widget _buildTeamsRankingStream()'

start_idx = text.find(start_marker)
end_idx = text.find(end_marker)

assert start_idx != -1, 'start_marker not found'
assert end_idx != -1, 'end_marker not found'

new_text = text[:start_idx] + new_1v1_block + '\n\n' + text[end_idx:]

with open(path, 'w', encoding='utf-8') as f:
    f.write(new_text)

print('Successfully patched champion_screen.dart with complete 1v1 adaptive lifecycle!')
