import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/repositories/league/team_league_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../shared/widgets/primary_button.dart';

/// 1. Bottom Sheet for a participating team to submit match outcome:
/// 🟢 فوز | 🟡 تعادل | 🔴 خسارة (No numerical goals)
class TeamLeagueMatchResultSheet extends StatefulWidget {
  final TeamLeagueMatch match;
  final String userTeamId;
  final Future<void> Function(String result) onSubmitResult;

  const TeamLeagueMatchResultSheet({
    super.key,
    required this.match,
    required this.userTeamId,
    required this.onSubmitResult,
  });

  @override
  State<TeamLeagueMatchResultSheet> createState() => _TeamLeagueMatchResultSheetState();
}

class _TeamLeagueMatchResultSheetState extends State<TeamLeagueMatchResultSheet> {
  String? _selectedResult; // 'win', 'draw', 'loss'
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedResult = widget.match.myTeamSubmission;
  }

  Future<void> _submit() async {
    if (_selectedResult == null) {
      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isArabic ? 'يرجى اختيار نتيجة فريقك' : 'Select your team result first.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await widget.onSubmitResult(_selectedResult!);
      if (mounted) Navigator.pop(context, true);
    } catch (e, stackTrace) {
      debugPrint('League match result submission failed: $e\n$stackTrace');
      if (mounted) {
        final isArabic = Localizations.localeOf(context).languageCode == 'ar';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArabic
                ? 'تعذر حفظ نتيجة المباراة. حاول مرة أخرى.'
                : 'Could not save the match result. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isHome = widget.match.homeTeamId == widget.userTeamId;
    final myTeamName = isHome ? widget.match.homeTeamName : widget.match.awayTeamName;
    final opponentName = isHome ? widget.match.awayTeamName : widget.match.homeTeamName;

    final media = MediaQuery.of(context);
    final availableHeight = (media.size.height -
            media.viewInsets.bottom -
            media.padding.top -
            media.padding.bottom -
            24)
        .clamp(0.0, media.size.height)
        .toDouble();
    return Container(
      constraints: BoxConstraints(maxHeight: availableHeight),
      padding: EdgeInsets.only(
        top: 24,
        left: 20,
        right: 20,
        bottom: media.padding.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: VSPColors.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Iconsax.judge_copy, color: VSPColors.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'نتيجة المباراة' : 'Match result',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    SizedBox(height: 2),
                    Text(
                      isArabic ? 'ماذا كانت نتيجة فريقك؟' : 'What was your team’s result?',
                      style: TextStyle(color: VSPColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Match Context Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: VSPColors.surfaceAlt,
              borderRadius: BorderRadius.circular(VSPRadius.lg),
              border: Border.all(color: VSPColors.divider, width: 0.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: Text(
                    myTeamName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: VSPColors.surface,
                    borderRadius: BorderRadius.circular(VSPRadius.sm),
                  ),
                  child: Text(isArabic ? 'ضد' : 'VS', style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12)),
                ),
                Expanded(
                  child: Text(
                    opponentName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // The 3 Big Outcome Choices
          Row(
            children: [
              // 🟢 WIN
              Expanded(
                child: _buildChoiceButton(
                  title: isArabic ? 'فوز' : 'Win',
                  icon: Iconsax.cup_copy,
                  value: 'win',
                  activeColor: VSPColors.accent,
                ),
              ),
              const SizedBox(width: 10),
              // 🟡 DRAW
              Expanded(
                child: _buildChoiceButton(
                  title: isArabic ? 'تعادل' : 'Draw',
                  icon: Iconsax.pause_copy,
                  value: 'draw',
                  activeColor: VSPColors.warning,
                ),
              ),
              const SizedBox(width: 10),
              // 🔴 LOSS
              Expanded(
                child: _buildChoiceButton(
                  title: isArabic ? 'خسارة' : 'Loss',
                  icon: Iconsax.close_circle_copy,
                  value: 'loss',
                  activeColor: VSPColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Submit Button
          PrimaryButton(
            text: widget.match.myTeamSubmission != null
                ? (isArabic ? 'تعديل النتيجة' : 'Edit result')
                : (isArabic ? 'تأكيد وإرسال النتيجة' : 'Confirm and submit result'),
            isLoading: _isLoading,
            onPressed: _selectedResult == null ? null : _submit,
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceButton({
    required String title,
    required IconData icon,
    required String value,
    required Color activeColor,
  }) {
    final isSelected = _selectedResult == value;
    return InkWell(
      onTap: () => setState(() => _selectedResult = value),
      borderRadius: BorderRadius.circular(VSPRadius.lg),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.2) : VSPColors.surfaceAlt,
          borderRadius: BorderRadius.circular(VSPRadius.lg),
          border: Border.all(
            color: isSelected ? activeColor : VSPColors.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? activeColor : VSPColors.textSecondary, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : VSPColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 2. Bottom Sheet for League Creator to Review & Resolve a Disputed Match
class TeamLeagueDisputeResolutionSheet extends StatefulWidget {
  final TeamLeagueMatch match;
  final Future<void> Function(String resolution) onResolveDispute;

  const TeamLeagueDisputeResolutionSheet({
    super.key,
    required this.match,
    required this.onResolveDispute,
  });

  @override
  State<TeamLeagueDisputeResolutionSheet> createState() => _TeamLeagueDisputeResolutionSheetState();
}

class _TeamLeagueDisputeResolutionSheetState extends State<TeamLeagueDisputeResolutionSheet> {
  String? _selectedResolution; // 'home_win', 'draw', 'away_win'
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // If the match already has a suggested confirmedOutcome (e.g. matching submissions), preselect it
    _selectedResolution = widget.match.confirmedOutcome;
  }

  String _formatResultText(String? result, {required bool isArabic}) {
    if (result == 'win') return isArabic ? 'فوز 🟢' : 'Win 🟢';
    if (result == 'draw') return isArabic ? 'تعادل 🟡' : 'Draw 🟡';
    if (result == 'loss') return isArabic ? 'خسارة 🔴' : 'Loss 🔴';
    return isArabic ? 'لم يسجل بعد' : 'Not submitted';
  }

  Future<void> _confirmAndResolve() async {
    if (_selectedResolution == null) return;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        backgroundColor: VSPColors.surface,
        title: Text(isArabic ? 'اعتماد نتيجة المباراة' : 'Confirm match result', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          isArabic ? 'سيتم اعتماد هذه النتيجة وتحديث جدول الدوري.' : 'This result will be confirmed and the league table will be updated.',
          style: TextStyle(color: VSPColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isArabic ? 'إلغاء' : 'Cancel', style: const TextStyle(color: VSPColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: VSPColors.accent),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isArabic ? 'اعتماد النتيجة' : 'Confirm result', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await widget.onResolveDispute(_selectedResolution!);
      if (mounted) Navigator.pop(context, true);
    } catch (e, stackTrace) {
      debugPrint('League dispute resolution failed: $e\n$stackTrace');
      if (mounted) {
        final isArabic = Localizations.localeOf(context).languageCode == 'ar';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArabic
                ? 'تعذر اعتماد نتيجة المباراة. حاول مرة أخرى.'
                : 'Could not confirm the match result. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final media = MediaQuery.of(context);
    final availableHeight = (media.size.height -
            media.viewInsets.bottom -
            media.padding.top -
            media.padding.bottom -
            24)
        .clamp(0.0, media.size.height)
        .toDouble();
    return Container(
      constraints: BoxConstraints(maxHeight: availableHeight),
      padding: EdgeInsets.only(
        top: 24,
        left: 20,
        right: 20,
        bottom: media.padding.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Iconsax.info_circle_copy, color: Colors.amber, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'مراجعة نتيجة المباراة' : 'Review match result',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    SizedBox(height: 2),
                    Text(
                      isArabic ? 'يوجد اختلاف في تسجيل النتيجة بين الفريقين' : 'The two teams submitted different results',
                      style: TextStyle(color: VSPColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // What each team submitted
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: VSPColors.surfaceAlt,
              borderRadius: BorderRadius.circular(VSPRadius.lg),
              border: Border.all(
                color: widget.match.isDisputed 
                    ? Colors.redAccent.withValues(alpha: 0.4) 
                    : VSPColors.accent.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.match.homeTeamName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '${isArabic ? 'سجل' : 'Submitted'}: ${_formatResultText(widget.match.homeSubmission, isArabic: isArabic)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const Divider(color: VSPColors.divider, height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.match.awayTeamName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '${isArabic ? 'سجل' : 'Submitted'}: ${_formatResultText(widget.match.awaySubmission, isArabic: isArabic)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          Text(
            isArabic ? 'اختر النتيجة المعتمدة للمباراة:' : 'Choose the final match result:', 
            style: TextStyle(color: VSPColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          // 3 Resolution Options
          _buildResolutionRadio(
            title: isArabic ? 'فوز ${widget.match.homeTeamName}' : '${widget.match.homeTeamName} win',
            value: 'home_win',
          ),
          const SizedBox(height: 8),
          _buildResolutionRadio(
            title: isArabic ? 'تعادل' : 'Draw',
            value: 'draw',
          ),
          const SizedBox(height: 8),
          _buildResolutionRadio(
            title: isArabic ? 'فوز ${widget.match.awayTeamName}' : '${widget.match.awayTeamName} win',
            value: 'away_win',
          ),
          const SizedBox(height: 20),

          // Primary Button
          PrimaryButton(
            text: isArabic ? 'اعتماد النتيجة' : 'Confirm result',
            isLoading: _isLoading,
            onPressed: _selectedResolution == null ? null : _confirmAndResolve,
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildResolutionRadio({required String title, required String value}) {
    final isSelected = _selectedResolution == value;
    return InkWell(
      onTap: () => setState(() => _selectedResolution = value),
      borderRadius: BorderRadius.circular(VSPRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? VSPColors.accent.withValues(alpha: 0.15) : VSPColors.surfaceAlt,
          borderRadius: BorderRadius.circular(VSPRadius.md),
          border: Border.all(
            color: isSelected ? VSPColors.accent : VSPColors.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Iconsax.tick_circle_copy : Iconsax.record_copy,
              color: isSelected ? VSPColors.accent : VSPColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? Colors.white : VSPColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
