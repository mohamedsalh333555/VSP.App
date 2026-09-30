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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار نتيجة فريقك')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await widget.onSubmitResult(_selectedResult!);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء حفظ النتيجة: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHome = widget.match.homeTeamId == widget.userTeamId;
    final myTeamName = isHome ? widget.match.homeTeamName : widget.match.awayTeamName;
    final opponentName = isHome ? widget.match.awayTeamName : widget.match.homeTeamName;

    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
      ),
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
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'نتيجة المباراة',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'ماذا كانت نتيجة فريقك؟',
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
                  child: const Text('ضد', style: TextStyle(color: VSPColors.textSecondary, fontSize: 12)),
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
                  title: 'فوز',
                  icon: Iconsax.cup_copy,
                  value: 'win',
                  activeColor: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 10),
              // 🟡 DRAW
              Expanded(
                child: _buildChoiceButton(
                  title: 'تعادل',
                  icon: Iconsax.pause_copy,
                  value: 'draw',
                  activeColor: const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 10),
              // 🔴 LOSS
              Expanded(
                child: _buildChoiceButton(
                  title: 'خسارة',
                  icon: Iconsax.close_circle_copy,
                  value: 'loss',
                  activeColor: const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Submit Button
          PrimaryButton(
            text: widget.match.myTeamSubmission != null ? 'تعديل النتيجة' : 'تأكيد وإرسال النتيجة',
            isLoading: _isLoading,
            onPressed: _selectedResult == null ? null : _submit,
          ),
        ],
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

  String _formatResultText(String? result) {
    if (result == 'win') return 'فوز 🟢';
    if (result == 'draw') return 'تعادل 🟡';
    if (result == 'loss') return 'خسارة 🔴';
    return 'لم يسجل';
  }

  Future<void> _confirmAndResolve() async {
    if (_selectedResolution == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        title: const Text('اعتماد نتيجة المباراة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'سيتم اعتماد هذه النتيجة وتحديث جدول الدوري.',
          style: TextStyle(color: VSPColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(color: VSPColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: VSPColors.accent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('اعتماد النتيجة', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await widget.onResolveDispute(_selectedResolution!);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
      ),
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
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مراجعة نتيجة المباراة',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'يوجد اختلاف في تسجيل النتيجة بين الفريقين',
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
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(widget.match.homeTeamName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text(
                      'سجل: ${_formatResultText(widget.match.myTeamSubmission ?? widget.match.opponentTeamSubmission)}',
                      style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Divider(color: VSPColors.divider, height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(widget.match.awayTeamName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text(
                      'سجل: ${_formatResultText(widget.match.opponentTeamSubmission ?? widget.match.myTeamSubmission)}',
                      style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          const Text(
            'اختر النتيجة المعتمدة للمباراة:',
            style: TextStyle(color: VSPColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          // 3 Resolution Options
          _buildResolutionRadio(
            title: 'فوز ${widget.match.homeTeamName}',
            value: 'home_win',
          ),
          const SizedBox(height: 8),
          _buildResolutionRadio(
            title: 'تعادل',
            value: 'draw',
          ),
          const SizedBox(height: 8),
          _buildResolutionRadio(
            title: 'فوز ${widget.match.awayTeamName}',
            value: 'away_win',
          ),
          const SizedBox(height: 20),

          // Primary Button
          PrimaryButton(
            text: 'اعتماد النتيجة',
            isLoading: _isLoading,
            onPressed: _selectedResolution == null ? null : _confirmAndResolve,
          ),
        ],
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
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : VSPColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
