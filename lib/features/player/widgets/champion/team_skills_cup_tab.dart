import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/config/app_env.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/repositories/team_skills_cup_repository.dart';
import 'team_skills_roster_correction_screen.dart';
import 'team_skills_published_details.dart';
import 'team_skills_history_section.dart';
import 'team_skills_request_messages.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../services/team_skills_ranking_service.dart';

/// Fail closed unless build explicitly names a matching Supabase project.
bool get teamSkillsCupEnabled => AppEnv.teamSkillsCupEnabled;

class TeamSkillsCupTab extends StatefulWidget {
  final String selectedLocation;
  final TeamSkillsCupRepository? repository;
  const TeamSkillsCupTab({super.key, required this.selectedLocation, this.repository});
  /// The entry form may only submit five members from its most recently
  /// verified roster, even when a previous fetch or account was successful.
  static bool canSubmitVerifiedRoster({
    required bool rosterVerified,
    required Iterable<Map<String, dynamic>> rosterOptions,
    required Set<String> selectedPlayers,
    required String? goalkeeperId,
    required String? representativeId,
  }) {
    if (!rosterVerified || selectedPlayers.length != 5 ||
        goalkeeperId == null || representativeId == null ||
        !selectedPlayers.contains(goalkeeperId) ||
        !selectedPlayers.contains(representativeId)) {
      return false;
    }
    final allowedIds = <String>{
      for (final player in rosterOptions)
        if (player['uid'] is String &&
            (player['uid'] as String).trim().isNotEmpty)
          player['uid'] as String,
    };
    return selectedPlayers.every(allowedIds.contains);
  }

  /// Compare structured public values, not map insertion order: Supabase
  /// pages can return the same published prize object with reordered keys.
  /// A conflicting nested value must never pick whichever page came first.
  static bool _samePublicValue(Object? a, Object? b) {
    if (identical(a, b)) return true;
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_samePublicValue(a[i], b[i])) return false;
      }
      return true;
    }
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key) || !_samePublicValue(a[key], b[key])) {
          return false;
        }
      }
      return true;
    }
    return a == b;
  }

  /// Only cups with a canonical ID, published status, and real name
  /// can be opened or advertised on the player competitions screen.
  static List<Map<String, dynamic>> visiblePublishedCups(
    Iterable<Map<String, dynamic>> rows, {String selectedLocation = 'All'}
  ) {
    final byId = <String, Map<String, dynamic>>{};
    final conflicts = <String>{};
    final uuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    for (final row in rows) {
      final id = row['id'];
      final name = row['name'];
      final status = row['status'];
      final governorate = row['governorate'];
      if (id is! String || !uuid.hasMatch(id) ||
          name is! String || name.trim().isEmpty ||
          !const {'registration', 'live', 'completed'}.contains(status) ||
          (selectedLocation != 'All' && governorate != selectedLocation)) {
        continue;
      }
      if (conflicts.contains(id)) continue;
      final previous = byId[id];
      if (previous == null) {
        byId[id] = row;
      } else if (previous['name'] != name ||
          previous['status'] != status ||
          previous['governorate'] != governorate ||
          // Repeated pages must not silently choose an outdated public fee,
          // capacity, date or venue from two conflicting versions.
          previous['hospitality_fee'] != row['hospitality_fee'] ||
          previous['max_teams'] != row['max_teams'] ||
          previous['starts_at'] != row['starts_at'] ||
          previous['ends_at'] != row['ends_at'] ||
          previous['stadium_id'] != row['stadium_id'] ||
          previous['image_url'] != row['image_url'] ||
          !_samePublicValue(previous['prizes'], row['prizes'])) {
        byId.remove(id);
        conflicts.add(id);
      }
    }
    return byId.values.toList(growable: false);
  }

  /// One verified numeric stage record: zero is real; missing or disputed
  /// values are unknown and must never display as an invented zero.
  static String verifiedStagePoints(Iterable<Map<String, dynamic>> rows) =>
      verifiedWeightedStagePoints(rows, 25);

  /// The configured stage's weight is a stricter limit than the global
  /// database score cap. A missing/invalid weight must never invent points.
  static String verifiedWeightedStagePoints(
    Iterable<Map<String, dynamic>> rows,
    Object? stageWeight,
  ) {
    if (stageWeight is! num || !stageWeight.isFinite ||
        stageWeight <= 0 || stageWeight > 25) return '—';
    final values = rows.toList(growable: false);
    if (values.length != 1) return '—';
    final score = values.single['computed_points'];
    if (score is! num || !score.isFinite ||
        score < 0 || score > stageWeight) return '—';
    return score.toString();
  }

  /// Announced stages must have one unambiguous definition. Overlapping
  /// pages may repeat identical stages, but conflicting stage metadata must
  /// not make a duplicate drill or a fabricated completion denominator.
  static List<Map<String, dynamic>> visiblePublishedPhases(
      Iterable<Map<String, dynamic>> phases) {
    final byNumber = <int, Map<String, dynamic>>{};
    final conflicting = <int>{};
    for (final phase in phases) {
      final n = phase['stage_no'];
      if (n is! int || n < 1 || n > 100 || conflicting.contains(n)) continue;
      final previous = byNumber[n];
      if (previous == null) {
        byNumber[n] = phase;
      } else if (previous['name_ar'] != phase['name_ar'] ||
          previous['weight'] != phase['weight'] ||
          previous['metric'] != phase['metric']) {
        byNumber.remove(n);
        conflicting.add(n);
      }
    }
    final sorted = byNumber.keys.toList()..sort();
    return [for (final n in sorted) byNumber[n]!];
  }

  /// A server completion flag is necessary but insufficient to display a
  /// complete stage count when the public phase list is partial, invalid or
  /// contradictory. Duplicate identical phase rows are harmless.
  static bool canShowVerifiedCompletion({
    required bool serverApproved,
    required dynamic completedStages,
    required Iterable<Map<String, dynamic>> phases,
  }) {
    if (!serverApproved || completedStages is! int || completedStages < 1) {
      return false;
    }
    final source = phases.toList(growable: false);
    final announced = visiblePublishedPhases(source);
    if (announced.isEmpty || announced.length != completedStages) {
      return false;
    }
    final stageNos = <int>{};
    for (final phase in source) {
      final n = phase['stage_no'];
      final weight = phase['weight'];
      if (n is! int || n < 1 || n > 100 ||
          weight is! num || !weight.isFinite || weight <= 0 ||
          weight > 25) return false;
      stageNos.add(n);
    }
    // A duplicate with conflicting metadata reduces announced, but does not
    // reduce the unique source stage number count.
    return stageNos.length == announced.length;
  }

  /// Display the official published Arabic drill label without inventing an
  /// English translation. English users still see the stage number clearly.
  /// Never present a null/blank or malformed title as a verified drill name.
  static String publishedStageLabel(
    Map<String, dynamic> phase, {required bool isArabic}
  ) {
    final number = phase['stage_no'];
    final index = number is int && number > 0 && number <= 100
        ? number.toString() : '—';
    final name = phase['name_ar'];
    final officialName = name is String ? name.trim() : '';
    if (officialName.isEmpty) {
      return isArabic ? 'مرحلة $index' : 'Stage $index';
    }
    return isArabic ? officialName : 'Stage $index · $officialName';
  }

  /// Never invent a fixed 12-stage format for an unpublished plan.
  static String publishedStageSummary(
    Iterable<Map<String, dynamic>> phases, {required bool isArabic}
  ) {
    final count = visiblePublishedPhases(phases).length;
    if (count <= 0) {
      return isArabic
          ? 'مراحل البطولة لم تُعلن بعد'
          : 'Competition stages have not been announced yet';
    }
    if (!isArabic) {
      return '$count announced ${count == 1 ? 'stage' : 'stages'}';
    }
    if (count == 1) return 'مرحلة واحدة معلنة';
    if (count == 2) return 'مرحلتان معلنتان';
    if (count <= 10) return '$count مراحل معلنة';
    return '$count مرحلة معلنة';
  }

  /// The existence of a row in the awards table is not publication.
  /// Results display only after the cup is completed and announcement was
  /// recorded, with a known recipient for every individual award.
  static List<Map<String, dynamic>> visiblePublishedAwards({
    required Map<String, dynamic>? cup,
    required Iterable<Map<String, dynamic>> awards,
  }) {
    if (cup?['status'] != 'completed') return const [];
    final cupId = cup?['id'];
    final cupName = cup?['name'];
    if (cupId is! String || cupId.trim().isEmpty ||
        cupName is! String || cupName.trim().isEmpty) return const [];
    return TeamSkillsHistorySection.visibleAwards(
      awards.where((row) =>
          row['cup_id'] is String && row['cup_id'] == cupId)
          .map((row) => <String, dynamic>{
            ...row, 'cup_name': cupName,
          }),
    );
  }

  /// Use only fields from a published cup. Missing capacity or location
  /// must not become the literal string "null", or an invented seat count.
  static String publishedMetadata(
    Map<String, dynamic> cup, {required bool isArabic}
  ) {
    final parts = <String>[];
    final governorate = cup['governorate'];
    if (governorate is String && governorate.trim().isNotEmpty) {
      parts.add(governorate.trim());
    }
    final maxTeams = cup['max_teams'];
    if (maxTeams is int && maxTeams > 0 && maxTeams <= 1000) {
      parts.add('$maxTeams ${isArabic ? 'فرق' : 'teams'}');
    }
    return parts.join(' • ');
  }

  static String statusLabel(String? status, {required bool isArabic}) {
    switch (status) {
      case 'registration':
        return isArabic ? 'التسجيل مفتوح' : 'Registration open';
      case 'live':
        return isArabic ? 'البطولة جارية' : 'In progress';
      case 'completed':
        return isArabic ? 'بطولة منتهية' : 'Completed';
      default:
        return isArabic ? 'حالة البطولة غير متاحة' : 'Tournament status unavailable';
    }
  }

  static String actionLabel(String? status, {required bool isArabic}) {
    switch (status) {
      case 'registration':
        return isArabic ? 'التفاصيل والتسجيل' : 'Details and registration';
      case 'live':
        return isArabic ? 'تفاصيل البطولة والترتيب' : 'Tournament details and standings';
      case 'completed':
        return isArabic ? 'النتائج والجوائز المعلنة' : 'Results and announced awards';
      default:
        return isArabic ? 'تفاصيل البطولة' : 'Tournament details';
    }
  }


  @override
  State<TeamSkillsCupTab> createState() => _TeamSkillsCupTabState();
}

class _TeamSkillsCupTabState extends State<TeamSkillsCupTab> {
  late Future<List<Map<String, dynamic>>> _cups;
  Timer? _cupsRefreshTimer;
  TeamSkillsCupRepository get _repo => widget.repository ?? TeamSkillsCupRepository();

  @override
  void initState() {
    super.initState();
    _reload();
    if (teamSkillsCupEnabled) {
      _cupsRefreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
        if (mounted) setState(_reload);
      });
    }
  }

  @override
  void dispose() {
    _cupsRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TeamSkillsCupTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedLocation != widget.selectedLocation ||
        oldWidget.repository != widget.repository) {
      _reload();
    }
  }

  void _reload() {
    _cups = teamSkillsCupEnabled
        ? _repo.listCups(governorate: widget.selectedLocation)
        : Future.value(<Map<String, dynamic>>[]);
  }

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    if (!teamSkillsCupEnabled) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          ar ? 'بطولة مهارات الفرق قيد التجهيز. تفاصيل المراحل والتسجيل هتظهر بعد الإعلان الرسمي.'
              : 'Team Skills Cup is being prepared. Stages and registration details will appear once officially announced.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: VSPColors.textSecondary, fontSize: 15),
        ),
      ));
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _cups,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(ar ? 'تعذر تحميل البطولات' : 'Could not load tournaments',
                style: const TextStyle(color: VSPColors.textPrimary)),
            TextButton(
              onPressed: () => setState(_reload),
              child: Text(ar ? 'إعادة المحاولة' : 'Retry'),
            ),
          ]));
        }
        final rawCups = snapshot.data ?? const <Map<String, dynamic>>[];
        final cups = TeamSkillsCupTab.visiblePublishedCups(
          rawCups, selectedLocation: widget.selectedLocation);
        if (cups.isEmpty && rawCups.isNotEmpty) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(ar ? 'تعذر التحقق من بيانات البطولات المعلنة'
                    : 'Published competition data could not be verified',
                textAlign: TextAlign.center,
                style: const TextStyle(color: VSPColors.textSecondary)),
            TextButton(
              onPressed: () => setState(_reload),
              child: Text(ar ? 'إعادة المحاولة' : 'Retry'),
            ),
          ]));
        }
        if (cups.isEmpty) {
          return Center(child: Text(
            ar ? 'لا توجد بطولة مهارات فرق معلنة حاليًا' : 'No published Team Skills Cup yet',
            style: const TextStyle(color: VSPColors.textSecondary),
          ));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: cups.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final cup = cups[index];
            final status = cup['status']?.toString() ?? '';
            return InkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => TeamSkillsCupDetailsScreen(cup: cup, repository: _repo),
              )),
              borderRadius: BorderRadius.circular(VSPRadius.lg),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: VSPColors.surface,
                  border: Border.all(color: VSPColors.divider),
                  borderRadius: BorderRadius.circular(VSPRadius.lg),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text((cup['name'] as String).trim(),
                      style: const TextStyle(color: VSPColors.white,
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  if (TeamSkillsCupTab.publishedMetadata(
                      cup, isArabic: ar).isNotEmpty) ...[
                    Text(TeamSkillsCupTab.publishedMetadata(cup, isArabic: ar),
                        style: const TextStyle(color: VSPColors.textSecondary)),
                    const SizedBox(height: 6),
                  ],
                  Text(TeamSkillsCupTab.statusLabel(status, isArabic: ar),
                      style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.w700)),
                  Text(TeamSkillsCupTab.actionLabel(status, isArabic: ar),
                      style: const TextStyle(color: VSPColors.textPrimary)),
                ]),
              ),
            );
          },
        );
      },
    );
  }
}

class TeamSkillsCupDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> cup;
  final TeamSkillsCupRepository repository;
  const TeamSkillsCupDetailsScreen({super.key, required this.cup, required this.repository});

  @override
  State<TeamSkillsCupDetailsScreen> createState() => _TeamSkillsCupDetailsScreenState();
}

class _TeamSkillsCupDetailsScreenState extends State<TeamSkillsCupDetailsScreen> {
  late Future<void> _loadFuture;
  List<RankedTeamSkillsEntry> _rankedLeaderboard = [];
  Timer? _liveRefreshTimer;
  bool _hasLiveRefreshError = false;
  Map<String, dynamic>? _currentCup;
  String? _venueName;
  bool _cupStateCurrent = false;
  int _readGeneration = 0;
  bool _hasBoundViewer = false;
  String? _viewerUserId;
  List<Map<String, dynamic>> _phases = [];
  List<Map<String, dynamic>> _approvedScores = [];
  List<Map<String, dynamic>> _awards = [];
  List<Map<String, dynamic>> _registrations = [];
  List<Map<String, dynamic>> _captainTeams = [];
  Set<String> _memberTeamIds = <String>{};
  List<Map<String, dynamic>> _rosterOptions = [];
  bool _rosterVerified = false;
  Map<String, String> _teamNames = {};
  String? _selectedTeamId;
  String? _goalkeeperId;
  String? _representativeId;
  final Set<String> _selectedPlayers = {};
  bool _submitting = false;
  String? _feedback;

  String get cupId => widget.cup['id'].toString();

  String _notice(TeamSkillsRequestNotice notice) =>
      TeamSkillsRequestMessages.localize(notice,
          isArabic: Localizations.localeOf(context).languageCode == 'ar');

  @override
  void initState() {
    super.initState();
    _loadFuture = Future<void>.value();
    _liveRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted && !_submitting) {
        _refreshLatest();
      }
    });
  }

  /// AuthProvider is the owner of the current identity. A route may survive
  /// logout/login, so never keep showing the previous viewer's team state.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final actorId = context.watch<AuthProvider>().currentUser?.id;
    if (!_hasBoundViewer || _viewerUserId != actorId) {
      _hasBoundViewer = true;
      _viewerUserId = actorId;
      ++_readGeneration;
      _registrations = [];
      _currentCup = null;
      _venueName = null;
      _cupStateCurrent = false;
      _rankedLeaderboard = [];
      _approvedScores = [];
      _awards = [];
      _teamNames = {};
      _memberTeamIds = <String>{};
      _captainTeams = [];
      _rosterOptions = [];
      _rosterVerified = false;
      _selectedTeamId = null;
      _selectedPlayers.clear();
      _goalkeeperId = null;
      _representativeId = null;
      _feedback = null;
      _submitting = false;
      _loadFuture = _reload();
    }
  }

  @override
  void dispose() {
    _liveRefreshTimer?.cancel();
    ++_readGeneration;
    super.dispose();
  }

  Future<void> _refreshLatest() async {
    final generation = ++_readGeneration;
    final currentUserId = context.read<AuthProvider>().currentUser?.id;
    try {
      final cupFuture = widget.repository.getCupById(cupId);
      final memberFuture = currentUserId == null
          ? Future.value(<String>{})
          : widget.repository.getMemberTeamIds(currentUserId);
      final values = await Future.wait([
        widget.repository.getLeaderboard(cupId),
        widget.repository.getRegistrations(cupId),
        widget.repository.getAwards(cupId),
        widget.repository.getApprovedScores(cupId),
        currentUserId == null
            ? Future.value(<Map<String, dynamic>>[])
            : widget.repository.getCaptainTeams(currentUserId),
      ]);
      final memberIds = await memberFuture;
      final currentCup = await cupFuture;
      final venueName = currentCup == null ? null
          : await widget.repository.getVenueName(
              currentCup['stadium_id']?.toString() ?? '');
      final ranking = TeamSkillsRankingService.rank(values[0]);
      final names = await widget.repository.getTeamNames([
        ...values[0].map((row) => row['team_id'].toString()),
        ...values[1].map((row) => row['team_id'].toString()),
      ]);
      if (!mounted || generation != _readGeneration ||
          context.read<AuthProvider>().currentUser?.id != currentUserId) {
        return;
      }
      setState(() {
        _currentCup = currentCup;
        _venueName = venueName;
        _cupStateCurrent = currentCup != null;
        _rankedLeaderboard = ranking;
        _registrations = values[1];
        _awards = values[2];
        _approvedScores = values[3];
        _captainTeams = values[4];
        _memberTeamIds = memberIds;
        _teamNames = names;
        if (!_captainTeams.any(
            (team) => team['id'].toString() == _selectedTeamId)) {
          _selectedTeamId = _captainTeams.isEmpty
              ? null
              : _captainTeams.first['id'].toString();
          _rosterOptions = [];
          _rosterVerified = false;
          _selectedPlayers.clear();
          _goalkeeperId = null;
          _representativeId = null;
        }
        _hasLiveRefreshError = currentCup == null;
      });
    } catch (_) {
      if (mounted && generation == _readGeneration &&
          context.read<AuthProvider>().currentUser?.id == currentUserId) {
        setState(() {
          _hasLiveRefreshError = true;
          _cupStateCurrent = false;
        });
      }
    }
  }

  Future<void> _reload() async {
    final generation = ++_readGeneration;
    _cupStateCurrent = false;
    final currentUserId = context.read<AuthProvider>().currentUser?.id;
    final cupFuture = widget.repository.getCupById(cupId);
    final memberTeamsFuture = currentUserId == null
        ? Future.value(<String>{})
        : widget.repository.getMemberTeamIds(currentUserId);
    final values = await Future.wait([
      widget.repository.getLeaderboard(cupId),
      widget.repository.getPhases(cupId),
      widget.repository.getAwards(cupId),
      widget.repository.getRegistrations(cupId),
      widget.repository.getApprovedScores(cupId),
      currentUserId == null
          ? Future.value(<Map<String, dynamic>>[])
          : widget.repository.getCaptainTeams(currentUserId),
    ]);
    final ranks = values[0], phases = values[1], awards = values[2],
        registrations = values[3], approvedScores = values[4],
        teams = values[5];
    final memberTeamIds = await memberTeamsFuture;
    final latestCup = await cupFuture;
    final venueName = latestCup == null ? null
        : await widget.repository.getVenueName(
            latestCup['stadium_id']?.toString() ?? '');
    final rankedLeaderboard = TeamSkillsRankingService.rank(ranks);
    final names = await widget.repository.getTeamNames(
      [...ranks.map((e) => e['team_id'].toString()),
       ...registrations.map((e) => e['team_id'].toString())]);
    if (!mounted || generation != _readGeneration ||
        context.read<AuthProvider>().currentUser?.id != currentUserId) {
      return;
    }
    if (latestCup == null) {
      _cupStateCurrent = false;
      _currentCup = null;
      _venueName = null;
      throw StateError('TEAM_SKILLS_CUP_NOT_PUBLISHED');
    }
    setState(() {
      _currentCup = latestCup;
      _venueName = venueName;
      _cupStateCurrent = true;
      _hasLiveRefreshError = false;
      _rankedLeaderboard = rankedLeaderboard;
      _approvedScores = approvedScores;
      _phases = phases;
      _awards = awards;
      _registrations = registrations;
      _captainTeams = teams;
      _memberTeamIds = memberTeamIds;
      _teamNames = names;
      if (teams.isEmpty) {
        _selectedTeamId = null;
        _rosterOptions = [];
        _rosterVerified = false;
        _selectedPlayers.clear();
        _goalkeeperId = null;
        _representativeId = null;
      } else if (!teams.any((t) => t['id'].toString() == _selectedTeamId)) {
        _selectedTeamId = teams.first['id'].toString();
        _rosterOptions = [];
        _rosterVerified = false;
        _selectedPlayers.clear();
        _goalkeeperId = null;
        _representativeId = null;
      }
    });
    if (_selectedTeamId != null && teams.any((t)=>t['id'].toString()==_selectedTeamId)) {
      await _loadRoster(_selectedTeamId!);
    }
  }

  Future<void> _loadRoster(String teamId) async {
    final viewerId = _viewerUserId;
    final generation = _readGeneration;
    if (!mounted) return;
    // Deny new submissions immediately while re-verifying this roster.
    setState(() => _rosterVerified = false);
    try {
      final roster = await widget.repository.getRosterOptions(teamId);
      if (!mounted || teamId != _selectedTeamId ||
          generation != _readGeneration || viewerId != _viewerUserId) {
        return;
      }
      setState(() {
        _rosterOptions = roster;
        _rosterVerified = true;
        final allowedIds = roster.map((r)=>r['uid'].toString()).toSet();
        _selectedPlayers.removeWhere((id)=>!allowedIds.contains(id));
        if (!_selectedPlayers.contains(_goalkeeperId)) {
          _goalkeeperId = null;
        }
        if (!_selectedPlayers.contains(_representativeId)) {
          _representativeId = null;
        }
      });
    } catch (_) {
      if (mounted && teamId == _selectedTeamId &&
          generation == _readGeneration && viewerId == _viewerUserId) {
        setState(() {
          _rosterOptions = [];
          _rosterVerified = false;
          _selectedPlayers.clear();
          _goalkeeperId = null;
          _representativeId = null;
          _feedback = _notice(TeamSkillsRequestNotice.rosterUnavailable);
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!TeamSkillsCupRepository.registrationOpen(
        _cupStateCurrent ? _currentCup : null)) return;
    if (_submitting || _selectedTeamId == null ||
        !TeamSkillsCupTab.canSubmitVerifiedRoster(
          rosterVerified: _rosterVerified,
          rosterOptions: _rosterOptions,
          selectedPlayers: _selectedPlayers,
          goalkeeperId: _goalkeeperId,
          representativeId: _representativeId,
        )) {
      return;
    }
    final viewerId = _viewerUserId;
    if (viewerId == null || viewerId.isEmpty) return;
    final submittedTeamId = _selectedTeamId!;
    final submittedPlayers = _selectedPlayers.toList()..sort();
    final submittedGoalkeeperId = _goalkeeperId!;
    final submittedRepresentativeId = _representativeId!;
    final submissionGeneration = _readGeneration;
    setState(() { _submitting = true; _feedback = null; });
    try {
      // Read the live published status immediately before submission: a card
      // can remain open when an admin starts or cancels the competition.
      final freshCup = await widget.repository.getCupById(cupId);
      if (!mounted || viewerId != _viewerUserId) return;
      if (!TeamSkillsCupRepository.registrationOpen(freshCup)) {
        setState(() {
          _currentCup = freshCup;
          _cupStateCurrent = freshCup != null;
          _feedback = _notice(TeamSkillsRequestNotice.registrationClosed);
        });
        return;
      }
      // A previously pending roster refresh can complete while fetching
      // the latest cup status. Never submit a silently replaced player list.
      if (submissionGeneration != _readGeneration ||
          _selectedTeamId != submittedTeamId ||
          !TeamSkillsCupTab.canSubmitVerifiedRoster(
            rosterVerified: _rosterVerified,
            rosterOptions: _rosterOptions,
            selectedPlayers: _selectedPlayers,
            goalkeeperId: _goalkeeperId,
            representativeId: _representativeId,
          ) ||
          submittedGoalkeeperId != _goalkeeperId ||
          submittedRepresentativeId != _representativeId ||
          submittedPlayers.length != _selectedPlayers.length ||
          !submittedPlayers.every(_selectedPlayers.contains)) {
        setState(() => _feedback =
            _notice(TeamSkillsRequestNotice.rosterUnavailable));
        return;
      }
      setState(() {
        _currentCup = freshCup;
        _cupStateCurrent = true;
      });
      final receiptId = await widget.repository.registerTeam(
        cupId: cupId, teamId: submittedTeamId,
        playerIds: submittedPlayers,
        goalkeeperId: submittedGoalkeeperId,
        representativeId: submittedRepresentativeId,
      );
      if (!mounted || viewerId != _viewerUserId) return;
      // A periodic refresh may supersede _reload(). Confirm the exact RPC
      // receipt against a direct, current captain read instead.
      final latest = await widget.repository.getRegistrations(cupId);
      if (!mounted || viewerId != _viewerUserId) return;
      final candidate = TeamSkillsCupRepository.findCaptainRegistration(
        latest, teamId: submittedTeamId, captainId: viewerId,
      );
      final confirmed = candidate?['id']?.toString() == receiptId
          ? candidate : null;
      setState(() {
        _registrations = latest;
        _feedback = confirmed == null
            ? _notice(TeamSkillsRequestNotice.registrationUnconfirmed)
            : confirmed['status'] == 'waitlist'
                ? _notice(TeamSkillsRequestNotice.waitlisted)
                : confirmed['status'] == 'approved'
                    ? _notice(TeamSkillsRequestNotice.approved)
                    : _notice(TeamSkillsRequestNotice.pending);
      });
    } catch (_) {
      // The server may have committed a registration even when the network
      // response was lost. Read the existing row under the current user's
      // RLS privileges instead of submitting another registration.
      if (!mounted || viewerId != _viewerUserId) return;
      try {
        final latest = await widget.repository.getRegistrations(cupId);
        if (!mounted || viewerId != _viewerUserId) return;
        final registered = TeamSkillsCupRepository.findCaptainRegistration(
          latest, teamId: submittedTeamId, captainId: viewerId,
        );
        if (registered != null) {
          setState(() {
            _registrations = latest;
            _feedback = registered['status'] == 'waitlist'
                ? _notice(TeamSkillsRequestNotice.alreadyWaitlisted)
                : registered['status'] == 'approved'
                    ? _notice(TeamSkillsRequestNotice.approved)
                    : _notice(TeamSkillsRequestNotice.alreadyPending);
          });
          return;
        }
      } catch (_) {
        // No network confirmation is not evidence that the server rolled back.
      }
      if (mounted && viewerId == _viewerUserId) {
        setState(() => _feedback =
            _notice(TeamSkillsRequestNotice.registrationCheckUnavailable));
      }
    } finally {
      if (mounted && viewerId == _viewerUserId) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _editRegistration(Map<String, dynamic> registration) async {
    if (_submitting || _viewerUserId == null || !_cupStateCurrent) return;
    final viewerId = _viewerUserId!;
    if (!TeamSkillsCupRepository.canCorrectRoster(
      cupStatus: _currentCup?['status']?.toString(),
      status: registration['status']?.toString(),
      captainId: registration['captain_id']?.toString(),
      viewerId: viewerId,
      hospitalityStatus:
          registration['hospitality_payment_status']?.toString(),
      hasCheckedIn: registration['checked_in_at'] != null,
    )) return;

    // Opening a route is asynchronous. Lock immediately to prevent double
    // taps opening multiple roster editors for the same application.
    setState(() => _submitting = true);
    try {
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(builder: (_) => TeamSkillsRosterCorrectionScreen(
          cupId: cupId,
          registrationId: registration['id'].toString(),
          teamId: registration['team_id'].toString(),
          captainId: viewerId,
          initialGoalkeeperId: registration['goalkeeper_id'].toString(),
          initialRepresentativeId: registration['representative_id'].toString(),
          repository: widget.repository,
        )),
      );
      if (!mounted || viewerId != _viewerUserId || saved != true) return;
      setState(() => _feedback = null);
      try {
        // Read directly: a timed refresh can supersede _reload().
        final latest = await widget.repository.getRegistrations(cupId);
        if (!mounted || viewerId != _viewerUserId) return;
        final current = latest.where((row) =>
            row['id']?.toString() == registration['id']?.toString() &&
            row['cup_id']?.toString() == cupId &&
            row['team_id']?.toString() == registration['team_id']?.toString() &&
            row['captain_id']?.toString() == viewerId).toList();
        final status = current.length == 1
            ? current.single['status']?.toString() : null;
        setState(() {
          _registrations = latest;
          _feedback = status == 'approved'
              ? _notice(TeamSkillsRequestNotice.rosterSavedApproved)
              : status == 'waitlist'
                  ? _notice(TeamSkillsRequestNotice.rosterSavedWaitlist)
                  : status == 'pending'
                      ? _notice(TeamSkillsRequestNotice.rosterSavedPending)
                      : _notice(TeamSkillsRequestNotice.rosterSavedUnconfirmed);
          _loadFuture = _reload();
        });
      } catch (_) {
        if (mounted && viewerId == _viewerUserId) {
          setState(() {
            _feedback =
                _notice(TeamSkillsRequestNotice.rosterSavedRefreshFailed);
            _loadFuture = _reload();
          });
        }
      }
    } finally {
      // Also release when the editor is cancelled or the route is closed.
      if (mounted && viewerId == _viewerUserId) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _withdrawRegistration(String registrationId) async {
    if (_submitting || _viewerUserId == null ||
        !TeamSkillsCupRepository.registrationOpen(
            _cupStateCurrent ? _currentCup : null)) return;
    final actorId = _viewerUserId;
    // Lock before opening the dialog: two quick taps must never open two
    // confirmation windows or issue duplicate destructive requests.
    setState(() { _submitting = true; _feedback = null; });
    try {
      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(isArabic
              ? 'سحب طلب مشاركة الفريق'
              : 'Withdraw team registration'),
          content: Text(isArabic
              ? 'سيتم إلغاء طلب الفريق وتحرير مكانه واللاعبين الخمسة. '
                  'لن تستطيع إعادة تقديم نفس الفريق في هذه البطولة بعد السحب.'
              : 'The application will be withdrawn, releasing its spot '
                  'and the five selected players. This team cannot apply '
                  'again to the same cup after withdrawal.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(isArabic ? 'العودة' : 'Back'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(isArabic ? 'تأكيد السحب' : 'Confirm withdrawal'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted || actorId != _viewerUserId) return;
      try {
        await widget.repository.withdrawRegistration(registrationId);
        if (!mounted || actorId != _viewerUserId) return;
        // A direct read is independent from overlapping leaderboard polls.
        final latest = await widget.repository.getRegistrations(cupId);
        if (!mounted || actorId != _viewerUserId) return;
        final withdrawn = TeamSkillsCupRepository.isCaptainWithdrawalConfirmed(
          latest, registrationId: registrationId, captainId: actorId!,
        );
        setState(() {
          _registrations = latest;
          _feedback = withdrawn
              ? _notice(TeamSkillsRequestNotice.withdrawn)
              : _notice(TeamSkillsRequestNotice.withdrawalUnconfirmed);
        });
      } catch (_) {
        if (!mounted || actorId != _viewerUserId) return;
        // An offline reply is ambiguous: confirm the terminal status rather
        // than offering another destructive request or claiming failure.
        try {
          final latest = await widget.repository.getRegistrations(cupId);
          if (!mounted || actorId != _viewerUserId) return;
          final withdrawn = TeamSkillsCupRepository.isCaptainWithdrawalConfirmed(
            latest, registrationId: registrationId, captainId: actorId!,
          );
          setState(() {
            _registrations = latest;
            _feedback = withdrawn
                ? _notice(TeamSkillsRequestNotice.alreadyWithdrawn)
                : _notice(TeamSkillsRequestNotice.withdrawalRetryUnconfirmed);
          });
        } catch (_) {
          if (mounted && actorId == _viewerUserId) {
            setState(() => _feedback =
                _notice(TeamSkillsRequestNotice.withdrawalCheckUnavailable));
          }
        }
      }
    } finally {
      // Also unlock on cancel, system back, dialog errors or account changes.
      if (mounted && actorId == _viewerUserId) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    const style = TextStyle(color: VSPColors.white);
    final visibleCup = _cupStateCurrent ? _currentCup : null;
    final displayCup = _currentCup ?? widget.cup;
    final viewerTeamIds = <String>{
      ..._memberTeamIds,
      ..._captainTeams.map((team) => team['id'].toString()),
    };
    final myRegistrations = _registrations
        .where((registration) =>
            viewerTeamIds.contains(registration['team_id'].toString()))
        .toList();
    final activeTeamRegistration = myRegistrations.where(
      (r) => r['team_id'].toString() == _selectedTeamId,
    ).toList();
    String statusText(String? status) {
      switch (status) {
        case 'pending': return ar ? 'بانتظار مراجعة الإدارة' : 'Pending approval';
        case 'approved': return ar ? 'تم قبول الفريق' : 'Approved';
        case 'waitlist': return ar ? 'قائمة الانتظار' : 'Waitlisted';
        case 'rejected': return ar ? 'غير مقبول' : 'Rejected';
        case 'withdrawn': return ar ? 'منسحب' : 'Withdrawn';
        default: return ar ? 'حالة غير معروفة' : 'Unknown status';
      }
    }
    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(backgroundColor: VSPColors.background,
        title: Text(displayCup['name']?.toString() ?? 'Team Skills Cup')),
      body: FutureBuilder<void>(
        future: _loadFuture,
        builder: (context,snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: TextButton(
              onPressed: () => setState(() => _loadFuture = _reload()),
              child: Text(ar ? 'تعذر التحميل — إعادة المحاولة' : 'Retry loading cup'),
            ));
          }
          final visiblePhases = TeamSkillsCupTab.visiblePublishedPhases(_phases);
          return ListView(padding: const EdgeInsets.all(16), children: [
            if (_hasLiveRefreshError) ...[
              Row(children: [
                Expanded(child: Text(
                    ar ? 'تعذر تحديث النتائج، المعروض آخر بيانات تم التحقق منها.'
                        : 'Live refresh unavailable. Showing last verified data.',
                    style: const TextStyle(color: VSPColors.warning))),
                TextButton(
                  onPressed: _refreshLatest,
                  child: Text(ar ? 'تحديث' : 'Refresh')),
              ]),
              const SizedBox(height: 12),
            ],
            Text(TeamSkillsCupTab.publishedStageSummary(
                visiblePhases, isArabic: ar),
                style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(ar ? 'الجوائز الرسمية تُعلن بعد اعتماد نتائج البطولة.'
                : 'Official awards appear after the competition results are approved.',
                style: const TextStyle(color: VSPColors.textSecondary)),
            const SizedBox(height: 8),
            TeamSkillsPublishedDetails(
              cup: displayCup,
              stadiumName: _venueName,
              isArabic: ar,
            ),
            const SizedBox(height: 20),
            Text(ar ? 'مراحل البطولة' : 'Skills stages',
                style: const TextStyle(color: VSPColors.white,fontSize:18,fontWeight:FontWeight.bold)),
            ...visiblePhases.map((phase)=>ListTile(
              dense:true,
              title:Text(TeamSkillsCupTab.publishedStageLabel(phase, isArabic: ar),style:style),
              trailing:Text(phase['weight'] is num && (phase['weight'] as num) > 0
                  ? '${phase['weight']} ${ar ? 'نقطة' : 'points'}'
                  : '—',
                  style:const TextStyle(color:VSPColors.accent)),
            )),
            const SizedBox(height: 18),
            Text(ar ? 'ترتيب مهارات الفرق' : 'Skills leaderboard',
                style: const TextStyle(color: VSPColors.white,fontSize:18,fontWeight:FontWeight.bold)),
            ..._rankedLeaderboard.map((entry) {
              final registrationId = entry.data['registration_id']?.toString();
              final approvedForTeam = _approvedScores
                  .where((score) => score['registration_id']?.toString() == registrationId)
                  .toList();
              final verifiedCompletion = TeamSkillsCupTab.canShowVerifiedCompletion(
                serverApproved: entry.complete,
                completedStages: entry.data['completed_stages'],
                phases: _phases,
              );
              return ExpansionTile(
                iconColor: VSPColors.accent,
                collapsedIconColor: VSPColors.textSecondary,
                title: Text('#${entry.rank} ${_teamNames[entry.data['team_id'].toString()] ?? entry.data['team_id']}',
                    style: style),
                subtitle: Text(
                    '${entry.data['points']} ${ar ? 'نقطة' : 'points'} • '
                    '${entry.data['completed_stages'] is int && entry.data['completed_stages'] >= 0 && entry.data['completed_stages'] <= visiblePhases.length ? entry.data['completed_stages'] : '—'}' 
                    '${visiblePhases.isEmpty ? '' : '/${visiblePhases.length}'} • '
                    '${verifiedCompletion ? (ar ? 'مكتمل' : 'Complete') : entry.complete ? (ar ? 'تعذر التحقق من الاكتمال' : 'Completion unverified') : (ar ? 'قيد الاعتماد' : 'Pending stages')}',
                    style: const TextStyle(color: VSPColors.accent)),
                children: [
                  ...visiblePhases.map((phase) {
                    final stageNo = phase['stage_no']?.toString();
                    final rows = approvedForTeam.where(
                      (score) => score['stage_no']?.toString() == stageNo,
                    ).toList();
                    final verified = TeamSkillsCupTab.verifiedWeightedStagePoints(
                      rows, phase['weight']);
                    return ListTile(
                      dense: true,
                      title: Text(TeamSkillsCupTab.publishedStageLabel(phase, isArabic: ar),
                          style: const TextStyle(color: VSPColors.textPrimary)),
                      trailing: Text('$verified / ${phase['weight'] is num && (phase['weight'] as num).isFinite && (phase['weight'] as num) > 0 && (phase['weight'] as num) <= 25 ? phase['weight'] : '—'}',
                          style: const TextStyle(color: VSPColors.textSecondary)),
                    );
                  }),
                ],
              );
            }),
            const SizedBox(height: 14),
            if (TeamSkillsCupTab.visiblePublishedAwards(
                cup: visibleCup, awards: _awards).isNotEmpty) ...[
              Text(ar ? 'الجوائز الرسمية المعلنة' : 'Published official awards',
                  style: style),
              ...TeamSkillsCupTab.visiblePublishedAwards(
                  cup: visibleCup, awards: _awards).map((award) => ListTile(
                title: Text(TeamSkillsHistorySection.awardTitle(
                    award['award_type']?.toString(), isArabic: ar),
                    style: style),
                subtitle: Text(
                  _teamNames[award['team_id']?.toString()] ??
                      (ar ? 'فريق غير متاح' : 'Team unavailable'),
                  style: const TextStyle(color: VSPColors.textSecondary),
                ),
              )),
            ],
            if (myRegistrations.isNotEmpty) ...[
              const Divider(color: VSPColors.divider),
              Text(ar ? 'حالة مشاركة فرقك' : 'Your teams in this cup',
                  style: const TextStyle(color: VSPColors.white,
                      fontSize: 18, fontWeight: FontWeight.bold)),
              ...myRegistrations.map((registration) => ListTile(
                title: Text(
                  _teamNames[registration['team_id'].toString()] ??
                      (ar ? 'فريقك' : 'Your team'),
                  style: const TextStyle(color: VSPColors.textPrimary),
                ),
                subtitle: Text(
                  statusText(registration['status']?.toString()),
                  style: const TextStyle(color: VSPColors.accent),
                ),
                trailing: TeamSkillsCupRepository.canCorrectRoster(
                  cupStatus: visibleCup?['status']?.toString(),
                  status: registration['status']?.toString(),
                  captainId: registration['captain_id']?.toString(),
                  viewerId: _viewerUserId,
                  hospitalityStatus:
                      registration['hospitality_payment_status']?.toString(),
                  hasCheckedIn: registration['checked_in_at'] != null,
                )
                    ? PopupMenuButton<String>(
                        tooltip: ar ? 'إدارة طلب الفريق' : 'Manage team request',
                        enabled: !_submitting,
                        icon: const Icon(Icons.more_horiz, color: VSPColors.accent),
                        onSelected: (action) {
                          if (action == 'edit') {
                            _editRegistration(registration);
                          } else if (action == 'withdraw') {
                            _withdrawRegistration(registration['id'].toString());
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text(ar ? 'تعديل التشكيلة' : 'Edit roster'),
                          ),
                          PopupMenuItem(
                            value: 'withdraw',
                            child: Text(ar ? 'سحب الطلب' : 'Withdraw request'),
                          ),
                        ],
                      )
                    : Icon(
                        registration['checked_in_at'] != null
                            ? Icons.how_to_reg_outlined
                            : Icons.schedule_outlined,
                        color: VSPColors.textSecondary,
                      ),
              )),
            ],
            if (TeamSkillsCupRepository.registrationOpen(visibleCup) && _captainTeams.isNotEmpty) ...[
              const Divider(color: VSPColors.divider),
              Text(ar ? 'تسجيل فريقك (للكابتن فقط)' : 'Register your team (captains only)',
                  style:const TextStyle(color:VSPColors.white,fontSize:18,fontWeight:FontWeight.bold)),
              DropdownButton<String>(
                value: _selectedTeamId,
                isExpanded:true,
                dropdownColor: VSPColors.surface,
                style:style,
                items: _captainTeams.map((t)=>DropdownMenuItem(
                  value:t['id'].toString(),child:Text(t['name'].toString()),
                )).toList(),
                onChanged: _submitting ? null : (teamId) {
                  if (teamId == null) return;
                  setState(() {
                    _selectedTeamId=teamId;_rosterOptions=[];_rosterVerified=false;_selectedPlayers.clear();
                    _goalkeeperId=null;_representativeId=null;
                  });
                  _loadRoster(teamId);
                },
              ),
              if (activeTeamRegistration.isNotEmpty)
                Text(statusText(activeTeamRegistration.first['status']?.toString()),
                    style: const TextStyle(color: VSPColors.accent)),
              if (activeTeamRegistration.isEmpty) ...[
                Text(ar ? 'اختر 5 لاعبين من أعضاء فريقك' : 'Choose 5 current team members',
                    style: const TextStyle(color:VSPColors.textSecondary)),
                ..._rosterOptions.map((player) {
                  final uid=player['uid'].toString();
                  final selected=_selectedPlayers.contains(uid);
                  return CheckboxListTile(
                    title:Text(player['name']?.toString()??'Player',style:style),
                    value:selected,
                    activeColor:VSPColors.accent,
                    onChanged:_submitting || !_rosterVerified ? null : (checked){
                      if(checked == true && _selectedPlayers.length>=5) return;
                      setState(() {
                        if(checked==true) { _selectedPlayers.add(uid); }
                        else { _selectedPlayers.remove(uid);
                          if(_goalkeeperId==uid)_goalkeeperId=null;
                          if(_representativeId==uid)_representativeId=null;
                        }
                      });
                    },
                  );
                }),
                DropdownButton<String>(
                  hint:Text(ar?'اختر الحارس':'Choose goalkeeper',style:style),
                  value:_goalkeeperId, isExpanded:true,dropdownColor:VSPColors.surface,style:style,
                  items:_rosterOptions.where((p)=>_selectedPlayers.contains(p['uid'].toString()))
                    .map((p)=>DropdownMenuItem(value:p['uid'].toString(),
                      child:Text(p['name']?.toString()??'Player'))).toList(),
                  onChanged:_submitting || !_rosterVerified ? null : (v)=>setState(()=>_goalkeeperId=v),
                ),
                DropdownButton<String>(
                  hint:Text(ar?'ممثل الفريق في ختام 1 ضد 1':'1v1 representative',style:style),
                  value:_representativeId,isExpanded:true,dropdownColor:VSPColors.surface,style:style,
                  items:_rosterOptions.where((p)=>_selectedPlayers.contains(p['uid'].toString()))
                    .map((p)=>DropdownMenuItem(value:p['uid'].toString(),
                      child:Text(p['name']?.toString()??'Player'))).toList(),
                  onChanged:_submitting || !_rosterVerified ? null : (v)=>setState(()=>_representativeId=v),
                ),
                FilledButton(
                  onPressed: _submitting ||
                      !TeamSkillsCupTab.canSubmitVerifiedRoster(
                        rosterVerified: _rosterVerified,
                        rosterOptions: _rosterOptions,
                        selectedPlayers: _selectedPlayers,
                        goalkeeperId: _goalkeeperId,
                        representativeId: _representativeId,
                      ) ? null : _submit,
                  child:Text(ar ? 'إرسال طلب تسجيل الفريق' : 'Submit team registration'),
                ),
              ],
            ],
            if (_feedback!=null)Padding(padding:const EdgeInsets.only(top:12),
              child:Text(_feedback!,style:const TextStyle(color:VSPColors.warning))),
          ]);
        },
      ),
    );
  }
}
