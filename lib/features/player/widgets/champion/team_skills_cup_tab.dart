import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/config/app_env.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/repositories/team_skills_cup_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../services/team_skills_ranking_service.dart';

/// Fail closed unless build explicitly names a matching Supabase project.
bool get teamSkillsCupEnabled => AppEnv.teamSkillsCupEnabled;

class TeamSkillsCupTab extends StatefulWidget {
  final String selectedLocation;
  final TeamSkillsCupRepository? repository;
  const TeamSkillsCupTab({super.key, required this.selectedLocation, this.repository});

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
          ar ? 'بطولة مهارات الفرق قيد التجهيز. قريبًا ستقدر تشارك بفريقك في 12 مرحلة، والفريق الأعلى نقاطًا يتوج بالبطل.'
              : 'Team Skills Cup is being prepared. Your team will compete across 12 skills stages for 100 points.',
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
        final cups = snapshot.data ?? const <Map<String, dynamic>>[];
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
                  Text(cup['name']?.toString() ?? 'VSP Team Skills Cup',
                      style: const TextStyle(color: VSPColors.white,
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('${cup['governorate']} • ${cup['max_teams']} ${ar ? 'فرق' : 'teams'} • 100 ${ar ? 'نقطة' : 'points'}',
                      style: const TextStyle(color: VSPColors.textSecondary)),
                  const SizedBox(height: 6),
                  Text(status == 'registration'
                      ? (ar ? 'التسجيل مفتوح' : 'Registration open')
                      : status == 'live'
                          ? (ar ? 'البطولة جارية' : 'In progress')
                          : (ar ? 'بطولة منتهية' : 'Completed'),
                      style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.w700)),
                  Text(ar ? 'التفاصيل والتسجيل والترتيب' : 'Details, registration & leaderboard',
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
  Map<String, String> _teamNames = {};
  String? _selectedTeamId;
  String? _goalkeeperId;
  String? _representativeId;
  final Set<String> _selectedPlayers = {};
  bool _submitting = false;
  String? _feedback;

  String get cupId => widget.cup['id'].toString();

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
      _rankedLeaderboard = [];
      _approvedScores = [];
      _awards = [];
      _teamNames = {};
      _memberTeamIds = <String>{};
      _captainTeams = [];
      _rosterOptions = [];
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
          _selectedPlayers.clear();
          _goalkeeperId = null;
          _representativeId = null;
        }
        _hasLiveRefreshError = false;
      });
    } catch (_) {
      if (mounted && generation == _readGeneration) {
        setState(() => _hasLiveRefreshError = true);
      }
    }
  }

  Future<void> _reload() async {
    final generation = ++_readGeneration;
    final currentUserId = context.read<AuthProvider>().currentUser?.id;
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
    final rankedLeaderboard = TeamSkillsRankingService.rank(ranks);
    final names = await widget.repository.getTeamNames(
      [...ranks.map((e) => e['team_id'].toString()),
       ...registrations.map((e) => e['team_id'].toString())]);
    if (!mounted || generation != _readGeneration ||
        context.read<AuthProvider>().currentUser?.id != currentUserId) {
      return;
    }
    setState(() {
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
        _selectedPlayers.clear();
        _goalkeeperId = null;
        _representativeId = null;
      } else if (!teams.any((t) => t['id'].toString() == _selectedTeamId)) {
        _selectedTeamId = teams.first['id'].toString();
        _rosterOptions = [];
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
    try {
      final roster = await widget.repository.getRosterOptions(teamId);
      if (!mounted || teamId != _selectedTeamId ||
          generation != _readGeneration || viewerId != _viewerUserId) {
        return;
      }
      setState(() {
        _rosterOptions = roster;
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
          _feedback = 'تعذر التحقق من أعضاء الفريق. أعد المحاولة.';
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_submitting || _selectedTeamId == null ||
        _selectedPlayers.length != 5 ||
        !_selectedPlayers.contains(_goalkeeperId) ||
        !_selectedPlayers.contains(_representativeId)) {
      return;
    }
    final viewerId = _viewerUserId;
    if (viewerId == null || viewerId.isEmpty) return;
    final submittedTeamId = _selectedTeamId!;
    setState(() { _submitting = true; _feedback = null; });
    try {
      await widget.repository.registerTeam(
        cupId: cupId, teamId: submittedTeamId,
        playerIds: _selectedPlayers.toList()..sort(),
        goalkeeperId: _goalkeeperId!, representativeId: _representativeId!,
      );
      if (!mounted || viewerId != _viewerUserId) return;
      await _reload();
      if (mounted && viewerId == _viewerUserId) {
        final queued = _registrations.any((registration) =>
            registration['team_id']?.toString() == submittedTeamId &&
            registration['status'] == 'waitlist');
        setState(() => _feedback = queued
            ? 'تم تسجيل فريقك في قائمة الانتظار. ستراجع الإدارة طلبك عند توفر مكان.'
            : 'تم إرسال طلب تسجيل الفريق. في انتظار موافقة إدارة البطولة.');
      }
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
                ? 'طلب فريقك مسجل بالفعل على قائمة الانتظار.'
                : registered['status'] == 'approved'
                    ? 'تم اعتماد مشاركة فريقك بالفعل.'
                    : 'طلب فريقك مسجل بالفعل وينتظر مراجعة الإدارة.';
          });
          return;
        }
      } catch (_) {
        // No network confirmation is not evidence that the server rolled back.
      }
      if (mounted && viewerId == _viewerUserId) {
        setState(() => _feedback =
            'تعذر التحقق من حالة التسجيل. راجع حالة الفريق قبل إعادة المحاولة.');
      }
    } finally {
      if (mounted && viewerId == _viewerUserId) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    const style = TextStyle(color: VSPColors.white);
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
        title: Text(widget.cup['name']?.toString() ?? 'Team Skills Cup')),
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
            Text(ar ? '6 اختبارات • 12 مرحلة • 100 نقطة'
                : '6 disciplines • 12 stages • 100 points',
                style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(ar ? 'مدة البطولة المستهدفة من ساعتين إلى 3 ساعات. الفريق الأعلى نقاطًا هو بطل المهارات. ختام 1 ضد 1 وجائزة الحارس مستقلان.'
                : '2–3 hours. Highest skills score wins; 1v1 and best goalkeeper awards are independent.',
                style: const TextStyle(color: VSPColors.textSecondary)),
            const SizedBox(height: 8),
            Text('${widget.cup['hospitality_fee']} ${ar ? 'جنيه ضيافة للفريق' : 'EGP hospitality per team'}',
                style: style),
            const SizedBox(height: 20),
            Text(ar ? 'مراحل البطولة' : 'Skills stages',
                style: const TextStyle(color: VSPColors.white,fontSize:18,fontWeight:FontWeight.bold)),
            ..._phases.map((phase)=>ListTile(
              dense:true,
              title:Text(phase['name_ar']?.toString() ?? '',style:style),
              trailing:Text('${phase['weight']} / 100',
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
              return ExpansionTile(
                iconColor: VSPColors.accent,
                collapsedIconColor: VSPColors.textSecondary,
                title: Text('#${entry.rank} ${_teamNames[entry.data['team_id'].toString()] ?? entry.data['team_id']}',
                    style: style),
                subtitle: Text(
                    '${entry.data['points']} / 100 • ${entry.data['completed_stages']}/12 • '
                    '${entry.complete ? (ar ? 'مكتمل' : 'Complete') : (ar ? 'قيد الاعتماد' : 'Pending stages')}',
                    style: const TextStyle(color: VSPColors.accent)),
                children: [
                  ..._phases.map((phase) {
                    final stageNo = phase['stage_no']?.toString();
                    final rows = approvedForTeam.where(
                      (score) => score['stage_no']?.toString() == stageNo,
                    ).toList();
                    final verified = rows.isNotEmpty
                        ? rows.first['computed_points']?.toString() ?? '0'
                        : '—';
                    return ListTile(
                      dense: true,
                      title: Text(phase['name_ar']?.toString() ?? '',
                          style: const TextStyle(color: VSPColors.textPrimary)),
                      trailing: Text('$verified / ${phase['weight']}',
                          style: const TextStyle(color: VSPColors.textSecondary)),
                    );
                  }),
                ],
              );
            }),
            const SizedBox(height: 14),
            if (_awards.isNotEmpty) ...[
              Text(ar ? 'الأبطال المعتمدون' : 'Official winners',style:style),
              ..._awards.map((a)=>ListTile(
                title:Text(a['award_type'].toString(),style:style),
                subtitle:Text(_teamNames[a['team_id'].toString()] ?? '',
                    style:const TextStyle(color:VSPColors.textSecondary)),
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
                trailing: Icon(
                  registration['checked_in_at'] != null
                      ? Icons.how_to_reg_outlined
                      : Icons.schedule_outlined,
                  color: VSPColors.textSecondary,
                ),
              )),
            ],
            if (widget.cup['status'] == 'registration' && _captainTeams.isNotEmpty) ...[
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
                    _selectedTeamId=teamId;_rosterOptions=[];_selectedPlayers.clear();
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
                    onChanged:_submitting?null:(checked){
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
                  onChanged:_submitting?null:(v)=>setState(()=>_goalkeeperId=v),
                ),
                DropdownButton<String>(
                  hint:Text(ar?'ممثل الفريق في ختام 1 ضد 1':'1v1 representative',style:style),
                  value:_representativeId,isExpanded:true,dropdownColor:VSPColors.surface,style:style,
                  items:_rosterOptions.where((p)=>_selectedPlayers.contains(p['uid'].toString()))
                    .map((p)=>DropdownMenuItem(value:p['uid'].toString(),
                      child:Text(p['name']?.toString()??'Player'))).toList(),
                  onChanged:_submitting?null:(v)=>setState(()=>_representativeId=v),
                ),
                FilledButton(
                  onPressed:_submitting || _selectedPlayers.length!=5 ||
                      !_selectedPlayers.contains(_goalkeeperId) ||
                      !_selectedPlayers.contains(_representativeId)
                          ? null:_submit,
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
