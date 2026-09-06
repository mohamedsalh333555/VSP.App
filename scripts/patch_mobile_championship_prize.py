import re

# 1. Update lib/data/models.dart
models_path = 'lib/data/models.dart'
with open(models_path, 'r', encoding='utf-8') as f:
    models_code = f.read()

# Add fields to Championship class
old_fields = """  // TOURNAMENT Lifecycle
  final String status; // 'open', 'ongoing', 'completed'
  final String? championTeamId;
  final String? championTeamName;

  // Entry Fee Tracking
  final List<String> paidTeams;"""

new_fields = """  // TOURNAMENT Lifecycle
  final String status; // 'open', 'ongoing', 'completed'
  final String? championTeamId;
  final String? championTeamName;

  // Entry Fee Tracking
  final List<String> paidTeams;

  // Financial Prize Pool & Ledger
  final double prizePool;
  final bool prizeDelivered;
  final DateTime? prizeDeliveredAt;
  final String? prizeDeliveredBy;
  final String? prizeDeliveryNotes;"""

if 'prizePool' not in models_code:
    models_code = models_code.replace(old_fields, new_fields)

# Add to constructor
old_ctor = """    this.championTeamId,
    this.championTeamName,
    this.paidTeams = const [],
  });"""

new_ctor = """    this.championTeamId,
    this.championTeamName,
    this.paidTeams = const [],
    this.prizePool = 0.0,
    this.prizeDelivered = false,
    this.prizeDeliveredAt,
    this.prizeDeliveredBy,
    this.prizeDeliveryNotes,
  });"""

if old_ctor in models_code:
    models_code = models_code.replace(old_ctor, new_ctor)

# Add to fromFirestore
old_from = """        status: data['status']?.toString() ?? 'open',
        championTeamId: data['champion_team_id'] ?? data['championTeamId']?.toString(),
        championTeamName: data['champion_team_name'] ?? data['championTeamName']?.toString(),
        paidTeams: (data['paid_teams'] as List? ?? data['paidTeams'] as List?)?.map((e) => e.toString()).toList() ?? <String>[],
      );"""

new_from = """        status: data['status']?.toString() ?? 'open',
        championTeamId: data['champion_team_id'] ?? data['championTeamId']?.toString(),
        championTeamName: data['champion_team_name'] ?? data['championTeamName']?.toString(),
        paidTeams: (data['paid_teams'] as List? ?? data['paidTeams'] as List?)?.map((e) => e.toString()).toList() ?? <String>[],
        prizePool: double.tryParse((data['prize_pool'] ?? data['prizePool'] ?? 0).toString()) ?? 0.0,
        prizeDelivered: data['prize_delivered'] == true || data['prizeDelivered'] == true,
        prizeDeliveredAt: data['prize_delivered_at'] != null ? DateTime.tryParse(data['prize_delivered_at'].toString()) : null,
        prizeDeliveredBy: (data['prize_delivered_by'] ?? data['prizeDeliveredBy'])?.toString(),
        prizeDeliveryNotes: (data['prize_delivery_notes'] ?? data['prizeDeliveryNotes'])?.toString(),
      );"""

if old_from in models_code:
    models_code = models_code.replace(old_from, new_from)

# Add to copyWith
old_copy = """    String? championTeamId,
    String? championTeamName,
    List<String>? paidTeams,
  }) {"""

new_copy = """    String? championTeamId,
    String? championTeamName,
    List<String>? paidTeams,
    double? prizePool,
    bool? prizeDelivered,
    DateTime? prizeDeliveredAt,
    String? prizeDeliveredBy,
    String? prizeDeliveryNotes,
  }) {"""

if old_copy in models_code:
    models_code = models_code.replace(old_copy, new_copy)

old_copy_ret = """      championTeamId: championTeamId ?? this.championTeamId,
      championTeamName: championTeamName ?? this.championTeamName,
      paidTeams: paidTeams ?? this.paidTeams,
    );"""

new_copy_ret = """      championTeamId: championTeamId ?? this.championTeamId,
      championTeamName: championTeamName ?? this.championTeamName,
      paidTeams: paidTeams ?? this.paidTeams,
      prizePool: prizePool ?? this.prizePool,
      prizeDelivered: prizeDelivered ?? this.prizeDelivered,
      prizeDeliveredAt: prizeDeliveredAt ?? this.prizeDeliveredAt,
      prizeDeliveredBy: prizeDeliveredBy ?? this.prizeDeliveredBy,
      prizeDeliveryNotes: prizeDeliveryNotes ?? this.prizeDeliveryNotes,
    );"""

if old_copy_ret in models_code:
    models_code = models_code.replace(old_copy_ret, new_copy_ret)

# Add to toFirestore
old_to_fire = """      'is_two_legs': isTwoLegs,
      'status': status,"""

new_to_fire = """      'is_two_legs': isTwoLegs,
      'status': status,
      'prize_pool': prizePool,
      'prize_delivered': prizeDelivered,
      'prize_delivered_at': prizeDeliveredAt?.toIso8601String(),
      'prize_delivered_by': prizeDeliveredBy,
      'prize_delivery_notes': prizeDeliveryNotes,"""

if old_to_fire in models_code and 'prize_pool' not in models_code[models_code.find('toFirestore'):]:
    models_code = models_code.replace(old_to_fire, new_to_fire)

with open(models_path, 'w', encoding='utf-8') as f:
    f.write(models_code)
print("Updated lib/data/models.dart")

# 2. Update TournamentRepository
repo_path = 'lib/core/repositories/tournament_repository.dart'
with open(repo_path, 'r', encoding='utf-8') as f:
    repo_code = f.read()

new_repo_method = """  /// Atomically marks a championship prize as delivered in the financial ledger
  Future<Map<String, dynamic>> markChampionshipPrizeDelivered(
    String championshipId, {
    String? notes,
  }) async {
    try {
      final res = await _supabase.rpc(
        'mark_championship_prize_delivered_atomic',
        params: {
          'p_championship_id': championshipId,
          'p_notes': notes,
        },
      );
      return Map<String, dynamic>.from(res as Map);
    } catch (e, s) {
      VSPLogger.e('Error marking championship prize delivered', e, s);
      rethrow;
    }
  }

"""

if 'markChampionshipPrizeDelivered' not in repo_code:
    target_pos = repo_code.find('  // ==================== MATCHES & BRACKETS ====================')
    if target_pos != -1:
        repo_code = repo_code[:target_pos] + new_repo_method + repo_code[target_pos:]
        with open(repo_path, 'w', encoding='utf-8') as f:
            f.write(repo_code)
        print("Updated lib/core/repositories/tournament_repository.dart")
    else:
        print("Could not find target in tournament_repository.dart")
else:
    print("markChampionshipPrizeDelivered already in tournament_repository.dart")

# 3. Update ChampionshipDetailsScreen
details_path = 'lib/features/player/screens/championship_details_screen.dart'
with open(details_path, 'r', encoding='utf-8') as f:
    details_code = f.read()

old_stat = """                        _buildStatCard(
                          icon: Iconsax.cup_copy,
                          iconColor: VSPColors.accent,
                          label: isArabic ? 'الجائزة الكبرى' : 'Grand Prize',
                          value: championship.grandPrize > 0 ? '${championship.grandPrize.toInt()} ${isArabic ? "ج.م" : "EGP"}' : (isArabic ? 'كأس وميداليات' : 'Cup & Medals'),
                        ),"""

new_stat = """                        _buildStatCard(
                          icon: Iconsax.cup_copy,
                          iconColor: VSPColors.accent,
                          label: isArabic ? 'الجائزة' : 'Prize',
                          value: championship.prizePool > 0
                              ? '${championship.prizePool.toInt()} ${isArabic ? "ج.م" : "EGP"}'
                              : (championship.grandPrize > 0
                                  ? '${championship.grandPrize.toInt()} ${isArabic ? "ج.م" : "EGP"}'
                                  : (isArabic ? 'كأس وميداليات' : 'Cup & Medals')),
                        ),"""

if old_stat in details_code:
    details_code = details_code.replace(old_stat, new_stat)

# Add Delivery Status Banner in ChampionshipDetailsScreen
old_header_end = """                    if (championship.status == 'open' && !isFull && championship.startDate.isAfter(DateTime.now())) ...[
                      const SizedBox(height: 12),
                      VSPCountdownTimer(targetDate: championship.startDate),
                    ],"""

new_header_end = """                    if (championship.status == 'open' && !isFull && championship.startDate.isAfter(DateTime.now())) ...[
                      const SizedBox(height: 12),
                      VSPCountdownTimer(targetDate: championship.startDate),
                    ],
                    if (championship.status == 'completed') ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: championship.prizeDelivered
                              ? const Color(0xFF10B981).withValues(alpha: 0.1)
                              : const Color(0xFFF59E0B).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(VSPRadius.md),
                          border: Border.all(
                            color: championship.prizeDelivered
                                ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                : const Color(0xFFF59E0B).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              championship.prizeDelivered ? Iconsax.verify_copy : Iconsax.clock_copy,
                              color: championship.prizeDelivered ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                championship.prizeDelivered
                                    ? (isArabic ? 'تم تسليم الجائزة المالية للبطل وتوثيقها رسمياً' : 'Prize officially delivered to champion')
                                    : (isArabic ? 'بانتظار تسليم الجائزة المالية للبطل' : 'Pending prize delivery to champion'),
                                style: TextStyle(
                                  color: championship.prizeDelivered ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],"""

if old_header_end in details_code and 'championship.prizeDelivered' not in details_code:
    details_code = details_code.replace(old_header_end, new_header_end)

with open(details_path, 'w', encoding='utf-8') as f:
    f.write(details_code)
print("Updated lib/features/player/screens/championship_details_screen.dart")

# 4. Update OwnerTournamentDashboardScreen
owner_path = 'lib/features/owner/screens/owner_tournament_dashboard_screen.dart'
with open(owner_path, 'r', encoding='utf-8') as f:
    owner_code = f.read()

# Add Prize Pool & Delivery Status in Owner Card
old_owner_card = """                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoItem(
                      AppLocalizations.of(context)!.statusLabel, 
                      currentChamp.status.toUpperCase(), 
                      color: currentChamp.status == 'completed' ? VSPColors.error : VSPColors.accent,
                    ),
                    _buildInfoItem(AppLocalizations.of(context)!.categoryLabel, currentChamp.type),
                  ],
                ),
                const Divider(color: VSPColors.divider, height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoItem(
                      AppLocalizations.of(context)!.datesLabel, 
                      '${DateFormat('MMM d').format(currentChamp.startDate)} - ${DateFormat('MMM d').format(currentChamp.endDate)}',
                    ),
                    _buildInfoItem(
                      AppLocalizations.of(context)!.teamsLabel, 
                      '${currentChamp.joinedTeams.length} / ${currentChamp.maxTeams}',
                      isLtr: true,
                    ),
                  ],
                ),"""

new_owner_card = """                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoItem(
                      AppLocalizations.of(context)!.statusLabel, 
                      currentChamp.status.toUpperCase(), 
                      color: currentChamp.status == 'completed' ? VSPColors.error : VSPColors.accent,
                    ),
                    _buildInfoItem(AppLocalizations.of(context)!.categoryLabel, currentChamp.type),
                  ],
                ),
                const Divider(color: VSPColors.divider, height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoItem(
                      AppLocalizations.of(context)!.datesLabel, 
                      '${DateFormat('MMM d').format(currentChamp.startDate)} - ${DateFormat('MMM d').format(currentChamp.endDate)}',
                    ),
                    _buildInfoItem(
                      AppLocalizations.of(context)!.teamsLabel, 
                      '${currentChamp.joinedTeams.length} / ${currentChamp.maxTeams}',
                      isLtr: true,
                    ),
                  ],
                ),
                const Divider(color: VSPColors.divider, height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoItem(
                      Localizations.localeOf(context).languageCode == 'ar' ? 'وعاء الجوائز' : 'Prize Pool',
                      currentChamp.prizePool > 0
                          ? '${currentChamp.prizePool.toInt()} ${Localizations.localeOf(context).languageCode == 'ar' ? "ج.م" : "EGP"}'
                          : (currentChamp.grandPrize > 0 ? '${currentChamp.grandPrize.toInt()} EGP' : 'كأس وميداليات'),
                      color: VSPColors.accent,
                    ),
                    if (currentChamp.status == 'completed')
                      _buildInfoItem(
                        Localizations.localeOf(context).languageCode == 'ar' ? 'تسليم الجائزة' : 'Prize Status',
                        currentChamp.prizeDelivered
                            ? (Localizations.localeOf(context).languageCode == 'ar' ? 'تم التسليم' : 'Delivered')
                            : (Localizations.localeOf(context).languageCode == 'ar' ? 'بانتظار التسليم' : 'Pending'),
                        color: currentChamp.prizeDelivered ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      ),
                  ],
                ),"""

if old_owner_card in owner_code:
    owner_code = owner_code.replace(old_owner_card, new_owner_card)
    with open(owner_path, 'w', encoding='utf-8') as f:
        f.write(owner_code)
    print("Updated lib/features/owner/screens/owner_tournament_dashboard_screen.dart")

