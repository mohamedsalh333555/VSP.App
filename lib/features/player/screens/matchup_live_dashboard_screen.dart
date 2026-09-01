import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../core/repositories/matchup_repository.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../data/models.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/vsp_back_button.dart';

class MatchupLiveDashboardScreen extends StatefulWidget {
  final String bookingId;

  const MatchupLiveDashboardScreen({
    super.key,
    required this.bookingId,
  });

  @override
  State<MatchupLiveDashboardScreen> createState() => _MatchupLiveDashboardScreenState();
}

class _MatchupLiveDashboardScreenState extends State<MatchupLiveDashboardScreen> {
  final MatchupRepository _matchupRepo = MatchupRepository();

  List<MatchupTeam> _teams = [];
  List<MatchupResult> _results = [];
  List<MatchupStandingsItem> _standings = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  // Form State for Recording Result
  String? _selectedTeamAId;
  String? _selectedTeamBId;
  String _selectedOutcome = 'team_a_win'; // 'team_a_win', 'team_b_win', 'draw'

  @override
  void initState() {
    super.initState();
    _loadMatchupData();
  }

  Future<void> _loadMatchupData() async {
    setState(() => _isLoading = true);
    try {
      final teams = await _matchupRepo.getMatchupTeams(widget.bookingId);
      final results = await _matchupRepo.getMatchupResults(widget.bookingId);
      final standings = _matchupRepo.calculateStandings(teams, results);

      if (mounted) {
        setState(() {
          _teams = teams;
          _results = results;
          _standings = standings;
          if (_teams.length >= 2) {
            _selectedTeamAId ??= _teams[0].teamId;
            _selectedTeamBId ??= _teams[1].teamId;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading matchup data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitMatchResult() async {
    if (_selectedTeamAId == null || _selectedTeamBId == null) {
      VSPFeedback.showWarning(context, 'يرجى اختيار الفريقين المتنافسين');
      return;
    }

    if (_selectedTeamAId == _selectedTeamBId) {
      VSPFeedback.showError(context, 'لا يمكن تسجيل مباراة بين نفس الفريق');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _matchupRepo.recordMatchupResult(
        bookingId: widget.bookingId,
        teamAId: _selectedTeamAId!,
        teamBId: _selectedTeamBId!,
        outcome: _selectedOutcome,
      );

      if (!mounted) return;
      VSPFeedback.showSuccess(context, 'تم تسجيل نتيجة المباراة وتحديث الترتيب بنجاح!');
      await _loadMatchupData();
    } catch (e) {
      debugPrint('Error submitting match result: $e');
      if (mounted) {
        VSPFeedback.showError(context, 'فشل تسجيل النتيجة: $e');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _closeMatchup() async {
    if (_results.isEmpty) {
      VSPFeedback.showWarning(context, 'يجب تسجيل نتيجة مباراة واحدة على الأقل قبل إغلاق المواجهة');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        title: const Text('إغلاق المواجهة؟', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'بعد إغلاق المواجهة لن تتمكن من إضافة نتائج جديدة لهذه الجلسة وسيتم اعتماد الترتيب النهائي.',
          style: TextStyle(color: VSPColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('تراجع', style: TextStyle(color: VSPColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: VSPColors.error),
            child: const Text('إغلاق المواجهة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSubmitting = true);
    try {
      await _matchupRepo.closeMatchup(widget.bookingId);
      if (!mounted) return;
      VSPFeedback.showSuccess(context, 'تم إغلاق المواجهة واعتماد النتائج النهائية بنجاح!');
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error closing matchup: $e');
      if (mounted) {
        VSPFeedback.showError(context, 'تعذر إغلاق المواجهة: $e');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: VSPColors.background,
        body: Center(child: CircularProgressIndicator(color: VSPColors.accent)),
      );
    }

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        leading: const VSPBackButton(),
        title: Text(
          isArabic ? 'لوحة المواجهات الحية' : 'Live Matchup Dashboard',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(VSPSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Live Standings Table Card
            _buildStandingsSection(),

            const SizedBox(height: VSPSpacing.xl),

            // 2. Record Match Result Form Card
            _buildRecordResultSection(),

            const SizedBox(height: VSPSpacing.xl),

            // 3. Match Results Timeline
            _buildResultsTimeline(),

            const SizedBox(height: VSPSpacing.xxl),

            // 4. Close Matchup CTA
            OutlinedButton.icon(
              onPressed: _isSubmitting ? null : _closeMatchup,
              icon: const Icon(Iconsax.slash_copy, color: VSPColors.error),
              label: Text(
                isArabic ? 'إنهاء وإغلاق المواجهة' : 'Finish & Close Matchup',
                style: const TextStyle(color: VSPColors.error, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                side: const BorderSide(color: VSPColors.error),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
              ),
            ),
            const SizedBox(height: VSPSpacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _buildStandingsSection() {
    return Container(
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: VSPColors.borderLight),
      ),
      padding: const EdgeInsets.all(VSPSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Iconsax.ranking_copy, color: VSPColors.accent, size: 20),
              SizedBox(width: 8),
              Text(
                'جدول ترتيب المواجهة الحية',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'حساب النقاط: (فوز = 3 نقاط | تعادل = 1 نقطة)',
            style: TextStyle(color: VSPColors.textSecondary, fontSize: 12),
          ),
          const Divider(color: VSPColors.divider, height: 24),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _standings.length,
            separatorBuilder: (_, __) => const Divider(color: VSPColors.surfaceAlt, height: 12),
            itemBuilder: (context, index) {
              final item = _standings[index];
              final isLeader = index == 0 && item.points > 0;

              return Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isLeader ? VSPColors.accent : VSPColors.surfaceAlt,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: isLeader ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.teamName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    'لعب: ${item.matchesPlayed} | ف: ${item.wins} | ت: ${item.draws} | خ: ${item.losses}',
                    style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: VSPColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${item.points} نقطة',
                      style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecordResultSection() {
    if (_teams.length < 2) return const SizedBox.shrink();

    final teamA = _teams.firstWhere((t) => t.teamId == _selectedTeamAId, orElse: () => _teams[0]);
    final teamB = _teams.firstWhere((t) => t.teamId == _selectedTeamBId, orElse: () => _teams[1]);

    return Container(
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(VSPSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Iconsax.direct_up_copy, color: VSPColors.accent, size: 20),
              SizedBox(width: 8),
              Text(
                'تسجيل نتيجة مباراة جديدة',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Team Selection Pickers
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedTeamAId,
                  dropdownColor: VSPColors.surfaceAlt,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'الفريق الأول',
                    labelStyle: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                    filled: true,
                    fillColor: VSPColors.surfaceAlt,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: _teams.map((t) => DropdownMenuItem(value: t.teamId, child: Text(t.teamName))).toList(),
                  onChanged: (val) => setState(() => _selectedTeamAId = val),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('VS', style: TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedTeamBId,
                  dropdownColor: VSPColors.surfaceAlt,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'الفريق الثاني',
                    labelStyle: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                    filled: true,
                    fillColor: VSPColors.surfaceAlt,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: _teams.map((t) => DropdownMenuItem(value: t.teamId, child: Text(t.teamName))).toList(),
                  onChanged: (val) => setState(() => _selectedTeamBId = val),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Outcome Selector Chips
          const Text('النتيجة:', style: TextStyle(color: VSPColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildOutcomeChip(
                  label: 'فوز ${teamA.teamName}',
                  value: 'team_a_win',
                  isSelected: _selectedOutcome == 'team_a_win',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildOutcomeChip(
                  label: 'تعادل',
                  value: 'draw',
                  isSelected: _selectedOutcome == 'draw',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildOutcomeChip(
                  label: 'فوز ${teamB.teamName}',
                  value: 'team_b_win',
                  isSelected: _selectedOutcome == 'team_b_win',
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          PrimaryButton(
            text: 'تسجيل النتيجة واعتماد الترتيب',
            onPressed: _isSubmitting ? null : _submitMatchResult,
          ),
        ],
      ),
    );
  }

  Widget _buildOutcomeChip({
    required String label,
    required String value,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => setState(() => _selectedOutcome = value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? VSPColors.accent : VSPColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? VSPColors.accent : VSPColors.borderLight),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildResultsTimeline() {
    if (_results.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(VSPSpacing.lg),
        alignment: Alignment.center,
        child: const Text(
          'لم تُسجل أي مباريات في هذه المواجهة بعد',
          style: TextStyle(color: VSPColors.textSecondary, fontSize: 13),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'سجل مباريات الجلسة (${_results.length})',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _results.reversed.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final result = _results.reversed.toList()[index];
            final tA = _teams.firstWhere((t) => t.teamId == result.teamAId, orElse: () => MatchupTeam(id: '', bookingId: '', teamId: result.teamAId, teamName: 'فريق أ', addedByUserId: '', joinedAt: DateTime.now()));
            final tB = _teams.firstWhere((t) => t.teamId == result.teamBId, orElse: () => MatchupTeam(id: '', bookingId: '', teamId: result.teamBId, teamName: 'فريق ب', addedByUserId: '', joinedAt: DateTime.now()));

            String outcomeText = 'تعادل';
            Color outcomeColor = VSPColors.warning;
            if (result.outcome == 'team_a_win') {
              outcomeText = 'فوز ${tA.teamName}';
              outcomeColor = VSPColors.success;
            } else if (result.outcome == 'team_b_win') {
              outcomeText = 'فوز ${tB.teamName}';
              outcomeColor = VSPColors.success;
            }

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(color: VSPColors.borderLight),
              ),
              child: Row(
                children: [
                  const Icon(Iconsax.activity_copy, color: VSPColors.accent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${tA.teamName} ضد ${tB.teamName}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: outcomeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      outcomeText,
                      style: TextStyle(color: outcomeColor, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
