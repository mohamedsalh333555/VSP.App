import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
      homePenalties = int.tryParse(_homePenaltiesController.text.trim());
      awayPenalties = int.tryParse(_awayPenaltiesController.text.trim());
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

  Future<void> _handleForfeit(bool homeForfeited) async {
    final forfeitedTeamName = homeForfeited ? widget.match.homeTeamName : widget.match.awayTeamName;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        title: const Text('تأكيد عدم حضور الفريق', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(
          'سيتم احتساب الفريق ($forfeitedTeamName) خاسراً بنتيجة 3-0 لعدم الحضور للمباراة.',
          style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(color: VSPColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الانسحاب 3-0', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final homeScore = homeForfeited ? 0 : 3;
    final awayScore = homeForfeited ? 3 : 0;
    final forfeitTeamId = homeForfeited ? widget.match.homeTeamId : widget.match.awayTeamId;

    setState(() => _isLoading = true);
    try {
      await widget.onSubmit(homeScore, awayScore, null, null);

      try {
        await Supabase.instance.client
            .from('tournament_matches')
            .update({
              'is_forfeit': true,
              'forfeit_team_id': forfeitTeamId,
            })
            .eq('id', widget.match.id);
      } catch (e) {
        debugPrint('Notice saving forfeit flag: $e');
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء تسجيل الانسحاب: $e')),
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
            OutlinedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: VSPColors.surface,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.lg)),
                        ),
                        builder: (bCtx) => SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('تحديد الفريق الغائب / المنسحب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                const SizedBox(height: 12),
                                ListTile(
                                  leading: const Icon(Iconsax.close_circle_copy, color: Colors.redAccent),
                                  title: Text(widget.match.homeTeamName, style: const TextStyle(color: Colors.white)),
                                  subtitle: const Text('تسجيل غياب واحتسابه خاسراً 0-3', style: TextStyle(color: VSPColors.textSecondary, fontSize: 11)),
                                  onTap: () {
                                    Navigator.pop(bCtx);
                                    _handleForfeit(true);
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Iconsax.close_circle_copy, color: Colors.redAccent),
                                  title: Text(widget.match.awayTeamName, style: const TextStyle(color: Colors.white)),
                                  subtitle: const Text('تسجيل غياب واحتسابه خاسراً 0-3', style: TextStyle(color: VSPColors.textSecondary, fontSize: 11)),
                                  onTap: () {
                                    Navigator.pop(bCtx);
                                    _handleForfeit(false);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
              icon: const Icon(Iconsax.close_circle_copy, size: 16, color: Colors.redAccent),
              label: const Text('الفريق لم يحضر / انسحاب 🚫', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
            const SizedBox(height: VSPSpacing.md),

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
