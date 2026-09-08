import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../core/repositories/matchup_repository.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../data/models.dart';
import '../../../shared/widgets/vsp_back_button.dart';
import '../services/matchup_dashboard_service.dart';
import '../widgets/matchup/matchup_record_result_card.dart';
import '../widgets/matchup/matchup_results_timeline.dart';
import '../widgets/matchup/matchup_standings_table.dart';

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
    final validationError = MatchupDashboardService.validateResultSubmission(
      teamAId: _selectedTeamAId,
      teamBId: _selectedTeamBId,
    );

    if (validationError != null) {
      if (_selectedTeamAId == null || _selectedTeamBId == null) {
        VSPFeedback.showWarning(context, validationError);
      } else {
        VSPFeedback.showError(context, validationError);
      }
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
    if (!MatchupDashboardService.canCloseMatchup(_results.length)) {
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
            MatchupStandingsTable(standings: _standings),

            const SizedBox(height: VSPSpacing.xl),

            // 2. Record Match Result Form Card
            MatchupRecordResultCard(
              teams: _teams,
              selectedTeamAId: _selectedTeamAId,
              selectedTeamBId: _selectedTeamBId,
              selectedOutcome: _selectedOutcome,
              isSubmitting: _isSubmitting,
              onTeamAChanged: (val) => setState(() => _selectedTeamAId = val),
              onTeamBChanged: (val) => setState(() => _selectedTeamBId = val),
              onOutcomeChanged: (val) => setState(() => _selectedOutcome = val),
              onSubmit: _submitMatchResult,
            ),

            const SizedBox(height: VSPSpacing.xl),

            // 3. Match Results Timeline
            MatchupResultsTimeline(
              results: _results,
              teams: _teams,
            ),

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
}
