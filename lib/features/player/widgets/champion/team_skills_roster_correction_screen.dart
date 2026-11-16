import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/auth_provider.dart';
import '../../../../core/repositories/team_skills_cup_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

/// Edits a single, already-submitted Team Skills roster. No booking or
/// payment actions are exposed here; the SQL RPC enforces eligibility.
class TeamSkillsRosterCorrectionScreen extends StatefulWidget {
  final String cupId;
  final String registrationId;
  final String teamId;
  final String captainId;
  final String initialGoalkeeperId;
  final String initialRepresentativeId;
  final TeamSkillsCupRepository repository;

  const TeamSkillsRosterCorrectionScreen({
    super.key,
    required this.cupId,
    required this.registrationId,
    required this.teamId,
    required this.captainId,
    required this.initialGoalkeeperId,
    required this.initialRepresentativeId,
    required this.repository,
  });

  @override
  State<TeamSkillsRosterCorrectionScreen> createState() =>
      _TeamSkillsRosterCorrectionScreenState();
}

class _TeamSkillsRosterCorrectionScreenState
    extends State<TeamSkillsRosterCorrectionScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _rosterVerified = false;
  bool _identityBound = false;
  String? _viewerUserId;
  int _sessionGeneration = 0;
  int _loadGeneration = 0;
  String? _error;
  List<Map<String, dynamic>> _members = [];
  final Set<String> _selectedPlayers = {};
  Set<String> _originalPlayers = {};
  String? _goalkeeper;
  String? _representative;

  bool get _hasChanges =>
      !_selectedPlayers.containsAll(_originalPlayers) ||
      !_originalPlayers.containsAll(_selectedPlayers) ||
      _goalkeeper != widget.initialGoalkeeperId ||
      _representative != widget.initialRepresentativeId;

  bool get _valid =>
      _rosterVerified && _selectedPlayers.length == 5 &&
      _selectedPlayers.contains(_goalkeeper) &&
      _selectedPlayers.contains(_representative) && _hasChanges;

  bool _isSameCaptain() =>
      context.read<AuthProvider>().currentUser?.id == widget.captainId;

  /// The edit route can survive an account switch. Invalidate all private
  /// roster state and pending responses before the new account can interact.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final actorId = context.watch<AuthProvider>().currentUser?.id;
    if (_identityBound && actorId == _viewerUserId) return;
    _identityBound = true;
    _viewerUserId = actorId;
    ++_sessionGeneration;
    ++_loadGeneration;
    _members = [];
    _originalPlayers = {};
    _selectedPlayers.clear();
    _goalkeeper = null;
    _representative = null;
    _saving = false;
    _rosterVerified = false;
    _loading = actorId == widget.captainId;
    _error = _loading ? null : 'الحساب الحالي ليس قائد الفريق.';
    if (_loading) {
      final generation = _sessionGeneration;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && generation == _sessionGeneration) _load();
      });
    }
  }

  @override
  void dispose() {
    ++_sessionGeneration;
    ++_loadGeneration;
    super.dispose();
  }

  Future<void> _load() async {
    if (_saving) return;
    final session = _sessionGeneration;
    final request = ++_loadGeneration;
    if (!_isSameCaptain()) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'الحساب الحالي ليس قائد الفريق.';
        });
      }
      return;
    }
    setState(() {
      _loading = true;
      _rosterVerified = false;
      _error = null;
    });
    try {
      final members = await widget.repository.getRosterOptions(widget.teamId);
      final roster = await widget.repository
          .getActiveRoster(widget.registrationId);
      if (!mounted || session != _sessionGeneration ||
          request != _loadGeneration || !_isSameCaptain()) return;

      final availableIds = members
          .map((row) => row['uid']?.toString() ?? '').toSet();
      final original = roster
          .map((row) => row['player_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty).toSet();
      setState(() {
        _members = members;
        _rosterVerified = true;
        _originalPlayers = original;
        _selectedPlayers
          ..clear()
          ..addAll(original.intersection(availableIds));
        _goalkeeper = _selectedPlayers.contains(widget.initialGoalkeeperId)
            ? widget.initialGoalkeeperId : null;
        _representative = _selectedPlayers.contains(widget.initialRepresentativeId)
            ? widget.initialRepresentativeId : null;
        _loading = false;
        _error = original.length != 5 ||
                _selectedPlayers.length != original.length
            ? 'بعض لاعبي التشكيلة لم يعودوا ضمن الفريق. '
                'اختر خمسة أعضاء حاليين لإصلاح الطلب.'
            : null;
      });
    } catch (_) {
      if (mounted && session == _sessionGeneration &&
          request == _loadGeneration && _isSameCaptain()) {
        setState(() {
          _loading = false;
          _error = 'تعذر التحقق من التشكيلة الحالية. أعد تحميلها.';
        });
      }
    }
  }

  /// An RPC can commit even if its HTTP response is lost. A signed-in captain
  /// confirms the actual persisted roster before reporting success.
  Future<bool> _confirmedOnServer() async {
    final latestRoster = await widget.repository
        .getActiveRoster(widget.registrationId);
    if (!_isSameCaptain()) return false;
    final latestRegistration = (await widget.repository
        .getRegistrations(widget.cupId)).where((row) =>
          row['id']?.toString() == widget.registrationId &&
          row['captain_id']?.toString() == widget.captainId).toList();
    if (latestRegistration.length != 1) return false;
    final row = latestRegistration.single;
    final ids = latestRoster
        .map((r) => r['player_id']?.toString()).whereType<String>().toSet();
    return ids.length == 5 &&
        ids.containsAll(_selectedPlayers) &&
        row['goalkeeper_id']?.toString() == _goalkeeper &&
        row['representative_id']?.toString() == _representative;
  }

  Future<void> _save() async {
    if (_loading || _saving || !_valid || !_isSameCaptain()) return;
    final session = _sessionGeneration;
    setState(() {
      _saving = true;
      _error = null;
    });
    final ids = _selectedPlayers.toList()..sort();
    try {
      await widget.repository.correctRoster(
        registrationId: widget.registrationId,
        playerIds: ids,
        goalkeeperId: _goalkeeper!,
        representativeId: _representative!,
      );
      if (!mounted || session != _sessionGeneration ||
          !_isSameCaptain()) return;
      final verified = await _confirmedOnServer();
      if (!mounted || session != _sessionGeneration ||
          !_isSameCaptain()) return;
      if (verified) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        _error = 'تم إرسال التعديل لكن تعذر تأكيد حفظ التشكيلة. '
            'راجع الطلب قبل المحاولة مجددًا.';
      });
    } catch (_) {
      if (!mounted || session != _sessionGeneration ||
          !_isSameCaptain()) return;
      bool verified = false;
      try {
        verified = await _confirmedOnServer();
      } catch (_) {
        // No server reply is not proof of a failed transaction.
      }
      if (!mounted || session != _sessionGeneration ||
          !_isSameCaptain()) return;
      if (verified) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        _error = 'تعذر تأكيد تعديل التشكيلة. قد تكون الإدارة اعتمدت الطلب '
            'أو تغيّرت عضوية الفريق؛ تحقق من الحالة قبل إعادة المحاولة.';
      });
    } finally {
      // Always release the in-flight lock, even if the account changed.
      if (mounted && session == _sessionGeneration) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewerId = context.watch<AuthProvider>().currentUser?.id;
    final authorizedViewer = viewerId == widget.captainId;
    const textStyle = TextStyle(color: VSPColors.textPrimary);
    final selectedMembers = _members.where(
      (p) => _selectedPlayers.contains(p['uid']?.toString()),
    ).toList();

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        title: const Text('تعديل تشكيلة مهارات الفرق'),
      ),
      body: !authorizedViewer
          ? const Center(child: Text('انتهت جلسة قائد الفريق. أعد فتح الطلب.',
              style: textStyle))
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text('يمكن تعديل الخمسة لاعبين والحارس وممثل 1V1 '
                        'قبل موافقة الإدارة فقط، وطالما لم تتم تسوية الضيافة.',
                        style: TextStyle(color: VSPColors.textSecondary)),
                    const SizedBox(height: 16),
                    if (_error != null) ...[
                      Text(_error!, style: const TextStyle(color: VSPColors.warning)),
                      const SizedBox(height: 8),
                    ],
                    Text('اللاعبون المختارون: ${_selectedPlayers.length} من 5',
                        style: textStyle),
                    ..._members.map((player) {
                      final id = player['uid']?.toString() ?? '';
                      final checked = _selectedPlayers.contains(id);
                      return CheckboxListTile(
                        title: Text(player['name']?.toString() ?? 'لاعب',
                            style: textStyle),
                        value: checked,
                        activeColor: VSPColors.accent,
                        onChanged: !_rosterVerified || _saving || id.isEmpty
                            ? null
                            : (value) {
                                if (value == true && _selectedPlayers.length >= 5) {
                                  return;
                                }
                                setState(() {
                                  if (value == true) {
                                    _selectedPlayers.add(id);
                                  } else {
                                    _selectedPlayers.remove(id);
                                    if (_goalkeeper == id) _goalkeeper = null;
                                    if (_representative == id) _representative = null;
                                  }
                                });
                              },
                      );
                    }),
                    const SizedBox(height: 12),
                    DropdownButton<String>(
                      value: _selectedPlayers.contains(_goalkeeper)
                          ? _goalkeeper : null,
                      hint: const Text('اختار حارس المرمى',style: textStyle),
                      isExpanded: true,
                      dropdownColor: VSPColors.surface,
                      style: textStyle,
                      items: selectedMembers.map((p) => DropdownMenuItem<String>(
                        value: p['uid']?.toString(),
                        child: Text(p['name']?.toString() ?? 'لاعب'),
                      )).toList(),
                      onChanged: !_rosterVerified || _saving ? null :
                          (value) => setState(() => _goalkeeper = value),
                    ),
                    DropdownButton<String>(
                      value: _selectedPlayers.contains(_representative)
                          ? _representative : null,
                      hint: const Text('اختار ممثل الفريق في 1 ضد 1',
                          style: textStyle),
                      isExpanded: true,
                      dropdownColor: VSPColors.surface,
                      style: textStyle,
                      items: selectedMembers.map((p) => DropdownMenuItem<String>(
                        value: p['uid']?.toString(),
                        child: Text(p['name']?.toString() ?? 'لاعب'),
                      )).toList(),
                      onChanged: !_rosterVerified || _saving ? null :
                          (value) => setState(() => _representative = value),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _valid && !_saving ? _save : null,
                      child: Text(_saving ? 'جارٍ تأكيد التعديل...' : 'حفظ التشكيلة'),
                    ),
                    if (_error != null)
                      TextButton(
                        onPressed: _saving ? null : _load,
                        child: const Text('إعادة تحميل التشكيلة'),
                      ),
                  ],
                ),
    );
  }
}
