import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/repositories/block_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/ui/vsp_ui.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../shared/widgets/vsp_back_button.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final BlockRepository _repo = BlockRepository();
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _repo.getBlockedUsers();
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  Future<void> _unblock(String blockedId, bool isAr) async {
    final ok = await _repo.unblockUser(blockedId);
    if (!mounted) return;
    if (ok) {
      VSPFeedback.showSuccess(context, isAr ? 'تم إلغاء الحظر بنجاح.' : 'User unblocked.');
      _load();
    } else {
      VSPFeedback.showError(context, isAr ? 'تعذر إلغاء الحظر.' : 'Could not unblock user.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return VSPScaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        leading: const VSPBackButton(),
        centerTitle: true,
        title: Text(
          isAr ? 'المستخدمون المحظورون' : 'Blocked Users',
          style: Theme.of(context).textTheme.displaySmall,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: VSPColors.accent))
          : _items.isEmpty
              ? Center(
                  child: Text(
                    isAr ? 'لا يوجد مستخدمون محظورون حالياً.' : 'No blocked users.',
                    style: const TextStyle(color: VSPColors.textSecondary, fontSize: 14),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(VSPSpacing.md),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: VSPSpacing.sm),
                  itemBuilder: (context, index) {
                    final row = _items[index];
                    final blockedId = row['blocked_id']?.toString() ?? '';
                    final shortId = blockedId.length > 8 ? blockedId.substring(0, 8) : blockedId;
                    return Container(
                      padding: const EdgeInsets.all(VSPSpacing.md),
                      decoration: BoxDecoration(
                        color: VSPColors.surface,
                        borderRadius: BorderRadius.circular(VSPRadius.lg),
                        border: Border.all(color: VSPColors.divider),
                      ),
                      child: Row(
                        children: [
                          const Icon(Iconsax.slash_copy, color: VSPColors.error, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isAr ? 'مستخدم ($shortId)' : 'User ($shortId)',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _unblock(blockedId, isAr),
                            child: Text(
                              isAr ? 'إلغاء الحظر' : 'Unblock',
                              style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
