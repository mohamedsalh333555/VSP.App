import 'package:flutter/material.dart';
import '../../../../core/repositories/league/team_league_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

class TeamLeagueMatchDialog extends StatefulWidget {
  final TeamLeagueMatch match;
  final Future<void> Function(int homeScore, int awayScore, int? homePenalties, int? awayPenalties) onSubmit;

  const TeamLeagueMatchDialog({
    super.key,
    required this.match,
    required this.onSubmit,
  });

  @override
  State<TeamLeagueMatchDialog> createState() => _TeamLeagueMatchDialogState();
}

class _TeamLeagueMatchDialogState extends State<TeamLeagueMatchDialog> {
  final TextEditingController _homeController = TextEditingController(text: '0');
  final TextEditingController _awayController = TextEditingController(text: '0');
  final TextEditingController _homePenaltiesController = TextEditingController();
  final TextEditingController _awayPenaltiesController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _homeController.dispose();
    _awayController.dispose();
    _homePenaltiesController.dispose();
    _awayPenaltiesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final home = int.tryParse(_homeController.text.trim());
    final away = int.tryParse(_awayController.text.trim());
    if (home == null || away == null || home < 0 || away < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال أهداف صحيحة')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final isPlayoff = widget.match.stage == 'playoff';
    int? homePenalties;
    int? awayPenalties;
    if (isPlayoff && home == away) {
      homePenalties = int.tryParse(__homePenaltiesController.text.trim());
      awayPenalties = int.tryParse(__awayPenaltiesController.text.trim());
      if (homePenalties == null || awayPenalties == null || homePenalties < 0 || awayPenalties < 0 || homePenalties == awayPenalties) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('في حالة التعادل يجب تحديد ركلات ترجيح مختلفة لتحديد الفائز')));
        return;
      }
    } else if (!isPlayoff && (_homePenaltiesController.text.trim().isNotEmpty || _awayPenaltiesController.text.trim().isNotEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ركلات الترجيح غير مسموحة في مباريات الدوري')));
      return;
    }
    if (isPlayoff && home != away && (_homePenaltiesController.text.trim().isNotEmpty || _awayPenaltiesController.text.trim().isNotEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ركلات الترجيح تستخدم فقط عند التعادل')));
      return;
    }
    await widget.onSubmit(home, away, homePenalties, awayPenalties);
      if (mounted) Navigator.pop(context);
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
    return Dialog(
      backgroundColor: VSPColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
      child: Padding(
        padding: const EdgeInsets.all(VSPSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'تسجيل نتيجة المباراة',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'الجولة ${widget.match.weekNumber}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: VSPColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: VSPSpacing.lg),

            Row(
              children: [
                // Home Team
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        widget.match.homeTeamName,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 64,
                        child: TextField(
                          controller: _homeController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: VSPColors.accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: VSPColors.surfaceAlt,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(VSPRadius.md),
                              borderSide: const BorderSide(color: VSPColors.borderLight),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    ':',
                    style: TextStyle(
                      color: VSPColors.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),

                // Away Team
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        widget.match.awayTeamName,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 64,
                        child: TextField(
                          controller: _awayController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: VSPColors.accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: VSPColors.surfaceAlt,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(VSPRadius.md),
                              borderSide: const BorderSide(color: VSPColors.borderLight),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (widget.match.stage == 'playoff') ...[
              const SizedBox(height: VSPSpacing.md),
              const Text('إذا انتهت المباراة بالتعادل: ركلات الترجيح', textAlign: TextAlign.center, style: TextStyle(color: VSPColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: _homePenaltiesController, keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: const InputDecoration(labelText: 'ركلات المضيف', filled: true, fillColor: VSPColors.surfaceAlt))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _awayPenaltiesController, keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: const InputDecoration(labelText: 'ركلات الضيف', filled: true, fillColor: VSPColors.surfaceAlt))),
              ]),
            ],
            const SizedBox(height: VSPSpacing.xl),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: VSPColors.textSecondary,
                      side: const BorderSide(color: VSPColors.borderLight),
                    ),
                    child: const Text('إلغاء'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VSPColors.accent,
                      foregroundColor: VSPColors.background,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Text('حفظ النتيجة', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
