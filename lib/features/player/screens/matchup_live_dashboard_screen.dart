import 'package:flutter/material.dart';
import '../../../core/ui/vsp_ui.dart';
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
  bool _hasLoadError = false;

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
    setState(() {
      _isLoading = true;
      _hasLoadError = false;
    });
    try {
      final teams = await _matchupRepo.getMatchupTeams(widget.bookingId);
      final results = await _matchupRepo.getMatchupResults(widget.bookingId);
      final standings = _matchupRepo.calculateStandings(teams, results);

      if (mounted) {
        setState(() {
          _teams = teams;
          _results = results;
          _standings = standings;
          _hasLoadError = false;
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
        setState(() {
          _isLoading = false;
          _hasLoadError = true;
        });
      }
    }
  }

  Future<void> _submitMatchResult() async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final validationError = MatchupDashboardService.validateResultSubmission(
      teamAId: _selectedTeamAId,
      teamBId: _selectedTeamBId,
      isArabic: isArabic,
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
      VSPFeedback.showSuccess(
        context,
        isArabic ? 'تم تسجيل نتيجة المباراة وتحديث الترتيب بنجاح!' : 'Match result recorded and standings updated successfully!',
      );
      await _loadMatchupData();
    } catch (e) {
      debugPrint('Error submitting match result: $e');
      if (mounted) {
        VSPFeedback.showError(
          context,
          isArabic ? 'تعذر تسجيل النتيجة. حاول مرة أخرى.' : 'Could not record the result. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _closeMatchup() async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    if (!MatchupDashboardService.canCloseMatchup(_results.length)) {
      VSPFeedback.showWarning(
        context,
        isArabic ? 'يجب تسجيل نتيجة مباراة واحدة على الأقل قبل إغلاق المواجهة' : 'Record at least one match result before closing the matchup.',
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        backgroundColor: VSPColors.surface,
        title: Text(isArabic ? 'إغلاق المواجهة؟' : 'Close matchup?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          isArabic
              ? 'بعد إغلاق المواجهة لن تتمكن من إضافة نتائج جديدة لهذه الجلسة وسيتم اعتماد الترتيب النهائي.'
              : 'After closing, no more results can be added to this session and the final standings will be locked.',
          style: TextStyle(color: VSPColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isArabic ? 'تراجع' : 'Cancel', style: const TextStyle(color: VSPColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: VSPColors.error),
            child: Text(isArabic ? 'إغلاق المواجهة' : 'Close matchup', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      await _matchupRepo.closeMatchup(widget.bookingId);
      if (!mounted) return;
      VSPFeedback.showSuccess(
        context,
        isArabic ? 'تم إغلاق المواجهة واعتماد النتائج النهائية بنجاح!' : 'Matchup closed and final standings confirmed!',
      );
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error closing matchup: $e');
      if (mounted) {
        VSPFeedback.showError(
          context,
          isArabic ? 'تعذر إغلاق المواجهة. حاول مرة أخرى.' : 'Could not close the matchup. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    if (_isLoading) {
      return const VSPScaffold(
        backgroundColor: VSPColors.background,
        body: SafeArea(top: false, bottom: true, child: Center(child: CircularProgressIndicator(color: VSPColors.accent))),
      );
    }

    if (_hasLoadError) {
      return VSPScaffold(
        backgroundColor: VSPColors.background,
        appBar: AppBar(
          backgroundColor: VSPColors.background,
          elevation: 0,
          leading: const VSPBackButton(),
          title: Text(isArabic ? 'لوحة المواجهات الحية' : 'Live Matchup Dashboard'),
        ),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(VSPSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Iconsax.warning_2_copy, color: VSPColors.warning, size: 42),
                  const SizedBox(height: VSPSpacing.md),
                  Text(
                    isArabic ? 'تعذر تحميل بيانات المواجهة.' : 'Could not load matchup data.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: VSPColors.textPrimary),
                  ),
                  const SizedBox(height: VSPSpacing.md),
                  PrimaryButton(
                    text: isArabic ? 'إعادة المحاولة' : 'Retry',
                    onPressed: _loadMatchupData,
                    height: 48,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return VSPScaffold(
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
      body: SafeArea(top: false, bottom: true, child: SingleChildScrollView(
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
      )),
    );
  }
}
