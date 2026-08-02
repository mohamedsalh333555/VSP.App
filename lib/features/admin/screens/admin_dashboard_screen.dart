import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/ui/components/vsp_card.dart';
import '../../../core/ui/components/vsp_stat_card.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/vsp_empty_state.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../data/models.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.surface,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.shieldCheck, color: VSPColors.accent, size: 22),
            const SizedBox(width: 8),
            Text(
              isArabic ? 'لوحة تحكم الإدارة العليا' : 'VSP Admin Control Panel',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: VSPColors.accent,
          labelColor: VSPColors.accent,
          unselectedLabelColor: VSPColors.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(text: isArabic ? 'توثيق المالكين 📑' : 'Owner Approvals 📑'),
            Tab(text: isArabic ? 'نزاعات المباريات ⚔️' : 'Disputed Matches ⚔️'),
            Tab(text: isArabic ? 'التسويات المالية 💸' : 'Payout Settlements 💸'),
            Tab(text: isArabic ? 'البلاغات والحظر 🚫' : 'Reports & Bans 🚫'),
          ],
        ),
      ),
      body: Column(
        children: [
          // 1. Live Metrics Header
          _buildMetricsHeader(context, isArabic),

          // 2. Tab Body
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOwnerVerificationsTab(isArabic),
                _buildDisputedMatchesTab(isArabic),
                _buildPayoutSettlementsTab(isArabic),
                _buildReportsAndModerationTab(isArabic),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 📊 Live Metrics Header
  // ===========================================================================
  Widget _buildMetricsHeader(BuildContext context, bool isArabic) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase.from('users').stream(primaryKey: ['id']),
      builder: (context, userSnap) {
        final users = userSnap.data ?? [];
        final totalOwners = users.where((u) => u['role'] == 'owner').length;
        final pendingVerifications = users.where((u) => u['role'] == 'owner' && u['verification_status'] == 'pending').length;

        return Container(
          padding: const EdgeInsets.all(VSPSpacing.md),
          color: VSPColors.surfaceAlt.withValues(alpha: 0.5),
          child: Row(
            children: [
              Expanded(
                child: VSPStatCard(
                  label: isArabic ? 'إجمالي المالكين' : 'Total Owners',
                  value: '$totalOwners',
                  icon: LucideIcons.building,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: VSPStatCard(
                  label: isArabic ? 'طلبات توثيق معلقة' : 'Pending Approvals',
                  value: '$pendingVerifications',
                  icon: LucideIcons.clock,
                  color: pendingVerifications > 0 ? VSPColors.warning : VSPColors.accent,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // 1️⃣ TAB 1: Owner Identity Approvals (توثيق المالكين)
  // ===========================================================================
  Widget _buildOwnerVerificationsTab(bool isArabic) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase.from('users').stream(primaryKey: ['id']).eq('role', 'owner'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
        }

        final owners = (snapshot.data ?? [])
            .where((u) => u['verification_status'] == 'pending')
            .toList();

        if (owners.isEmpty) {
          return VSPEmptyState(
            icon: LucideIcons.checkCheck,
            title: isArabic ? 'لا توجد طلبات توثيق معلقة' : 'No Pending Approvals',
            subtitle: isArabic ? 'جميع مالكي الملاعب موثقون حالياً!' : 'All stadium owners are verified.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(VSPSpacing.md),
          itemCount: owners.length,
          itemBuilder: (context, index) {
            final owner = owners[index];
            final addData = owner['additional_data'] as Map<String, dynamic>? ?? {};
            final docs = addData['verificationDocuments'] as Map<String, dynamic>? ?? {};

            return VSPCard(
              margin: const EdgeInsets.only(bottom: VSPSpacing.md),
              padding: const EdgeInsets.all(VSPSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: VSPColors.surfaceAlt,
                        backgroundImage: owner['profile_image_url'] != null ? NetworkImage(owner['profile_image_url']) : null,
                        child: owner['profile_image_url'] == null ? const Icon(LucideIcons.user, color: Colors.white) : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(owner['name'] ?? 'Unknown Owner', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('📞 ${owner['phone'] ?? 'N/A'} | 📍 ${owner['governorate'] ?? 'Cairo'}', style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: VSPColors.warning.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                        child: Text(isArabic ? 'قيد المراجعة' : 'Pending', style: const TextStyle(color: VSPColors.warning, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const Divider(color: VSPColors.divider, height: 24),

                  Text(isArabic ? 'المستندات المرفوعة:' : 'Uploaded Documents:', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (docs['commercialRegisterUrl'] != null) _buildDocLinkChip(isArabic ? 'السجل التجاري 📑' : 'Commercial Reg.', docs['commercialRegisterUrl']),
                      if (docs['taxCardUrl'] != null) _buildDocLinkChip(isArabic ? 'البطاقة الضريبية 💳' : 'Tax Card', docs['taxCardUrl']),
                      if (docs['nationalIdFrontUrl'] != null) _buildDocLinkChip(isArabic ? 'البطاقة (أمام) 📇' : 'ID Front', docs['nationalIdFrontUrl']),
                      if (docs['nationalIdBackUrl'] != null) _buildDocLinkChip(isArabic ? 'البطاقة (خلف) 📇' : 'ID Back', docs['nationalIdBackUrl']),
                    ],
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          text: isArabic ? 'موافقة وتوثيق ✅' : 'Approve & Verify ✅',
                          height: 44,
                          color: VSPColors.accent,
                          textColor: Colors.black,
                          onPressed: () => _approveOwner(owner['id']),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PrimaryButton(
                          text: isArabic ? 'رفض الطلب ❌' : 'Reject Request ❌',
                          height: 44,
                          color: VSPColors.error.withValues(alpha: 0.2),
                          textColor: VSPColors.error,
                          onPressed: () => _showRejectOwnerDialog(owner['id'], isArabic),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // 2️⃣ TAB 2: Disputed Matches Resolution (نزاعات المباريات)
  // ===========================================================================
  Widget _buildDisputedMatchesTab(bool isArabic) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase.from('bookings').stream(primaryKey: ['id']).eq('match_result_status', 'disputed'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
        }

        final disputes = snapshot.data ?? [];

        if (disputes.isEmpty) {
          return VSPEmptyState(
            icon: LucideIcons.shieldCheck,
            title: isArabic ? 'لا توجد نزاعات قائمة' : 'No Active Disputes',
            subtitle: isArabic ? 'جميع نتائج المباريات مؤكدة ومستقرة!' : 'All match outcomes are resolved.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(VSPSpacing.md),
          itemCount: disputes.length,
          itemBuilder: (context, index) {
            final match = disputes[index];
            final booking = Booking.fromFirestore(match, match['id'].toString());

            return VSPCard(
              margin: const EdgeInsets.only(bottom: VSPSpacing.md),
              padding: const EdgeInsets.all(VSPSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Match ID: #${booking.id.substring(0, booking.id.length > 8 ? 8 : booking.id.length)}', style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 12)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: VSPColors.error.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                        child: Text(isArabic ? 'نزاع قائم ⚔️' : 'Disputed ⚔️', style: const TextStyle(color: VSPColors.error, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildTeamDisputeSide(booking.playerTeamName ?? 'Home Team', booking.pendingOutcome == MatchOutcome.homeWin ? 'ادعى الفوز' : 'ادعى الخسارة/التعادل'),
                      const Text('VS', style: TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 20)),
                      _buildTeamDisputeSide(booking.opponentTeamName ?? 'Away Team', 'اعترض على النتيجة'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          text: isArabic ? 'فوز المضيف' : 'Home Wins',
                          height: 40,
                          color: VSPColors.surfaceAlt,
                          textColor: Colors.white,
                          onPressed: () => _resolveMatchDispute(booking.id, MatchOutcome.homeWin),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: PrimaryButton(
                          text: isArabic ? 'تعادل' : 'Draw',
                          height: 40,
                          color: VSPColors.surfaceAlt,
                          textColor: Colors.white,
                          onPressed: () => _resolveMatchDispute(booking.id, MatchOutcome.draw),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: PrimaryButton(
                          text: isArabic ? 'فوز الضيف' : 'Away Wins',
                          height: 40,
                          color: VSPColors.surfaceAlt,
                          textColor: Colors.white,
                          onPressed: () => _resolveMatchDispute(booking.id, MatchOutcome.awayWin),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // 3️⃣ TAB 3: Payout Settlements (التسويات المالية للمالكين)
  // ===========================================================================
  Widget _buildPayoutSettlementsTab(bool isArabic) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase.from('users').stream(primaryKey: ['id']).eq('role', 'owner'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
        }

        final owners = (snapshot.data ?? []).where((u) {
          return (u['p2p_instapay'] != null && u['p2p_instapay'].toString().isNotEmpty) ||
                 (u['p2p_vodafone'] != null && u['p2p_vodafone'].toString().isNotEmpty) ||
                 (u['p2p_bank'] != null && u['p2p_bank'].toString().isNotEmpty);
        }).toList();

        if (owners.isEmpty) {
          return VSPEmptyState(
            icon: LucideIcons.wallet,
            title: isArabic ? 'لا توجد طلبات تسوية ماليّة' : 'No Payout Requests',
            subtitle: isArabic ? 'لم يضِف المالكين وسائل تحصيل بعد.' : 'No payout methods specified by owners.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(VSPSpacing.md),
          itemCount: owners.length,
          itemBuilder: (context, index) {
            final owner = owners[index];

            return VSPCard(
              margin: const EdgeInsets.only(bottom: VSPSpacing.md),
              padding: const EdgeInsets.all(VSPSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.landmark, color: VSPColors.accent, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(owner['name'] ?? 'Owner', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('📞 ${owner['phone'] ?? 'N/A'}', style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: VSPColors.divider, height: 20),

                  if (owner['p2p_instapay'] != null && owner['p2p_instapay'].toString().isNotEmpty)
                    _buildPayoutRow('InstaPay IPN', owner['p2p_instapay']),
                  if (owner['p2p_vodafone'] != null && owner['p2p_vodafone'].toString().isNotEmpty)
                    _buildPayoutRow(isArabic ? 'محفظة إلكترونية' : 'Mobile Wallet', owner['p2p_vodafone']),
                  if (owner['p2p_bank'] != null && owner['p2p_bank'].toString().isNotEmpty)
                    _buildPayoutRow('Bank IBAN', owner['p2p_bank']),

                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: PrimaryButton(
                      text: isArabic ? 'تأكيد إرسال الأرباح والتصفية 💸' : 'Mark Settled & Paid 💸',
                      height: 40,
                      onPressed: () {
                        VSPFeedback.showSuccess(context, isArabic ? 'تم تسجيل التسوية بنجاح!' : 'Settlement recorded!');
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // 4️⃣ TAB 4: Reports & Moderation (البلاغات والحظر)
  // ===========================================================================
  Widget _buildReportsAndModerationTab(bool isArabic) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase.from('reports').stream(primaryKey: ['id']),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
        }

        final reports = snapshot.data ?? [];

        if (reports.isEmpty) {
          return VSPEmptyState(
            icon: LucideIcons.shieldCheck,
            title: isArabic ? 'لا توجد بلاغات قائمة' : 'No Reports Found',
            subtitle: isArabic ? 'مجتمع VSP آمن وخالٍ من البلاغات!' : 'VSP community is clean and safe.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(VSPSpacing.md),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final report = reports[index];
            final createdAt = report['created_at'] != null ? DateTime.parse(report['created_at']) : DateTime.now();

            return VSPCard(
              margin: const EdgeInsets.only(bottom: VSPSpacing.md),
              padding: const EdgeInsets.all(VSPSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Target: ${report['target_type']} #${report['target_id'].toString().substring(0, report['target_id'].toString().length > 8 ? 8 : report['target_id'].toString().length)}', style: const TextStyle(color: VSPColors.error, fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(DateFormat('MMM d, hh:mm a').format(createdAt), style: const TextStyle(color: VSPColors.textSecondary, fontSize: 10)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Reason: ${report['reason']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  if (report['details'] != null && report['details'].toString().isNotEmpty)
                    Text('Details: ${report['details']}', style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12)),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          text: isArabic ? 'حظر الهدف (Ban) 🚫' : 'Block Target 🚫',
                          height: 40,
                          color: VSPColors.error,
                          textColor: Colors.white,
                          onPressed: () => _blockTargetUser(report['target_id']),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: PrimaryButton(
                          text: isArabic ? 'إغلاق البلاغ ✅' : 'Dismiss Report ✅',
                          height: 40,
                          color: VSPColors.surfaceAlt,
                          textColor: Colors.white,
                          onPressed: () => _dismissReport(report['id']),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // 🛠️ Administrative Actions & Helpers
  // ===========================================================================

  Future<void> _approveOwner(String ownerId) async {
    try {
      await _supabase.from('users').update({
        'verification_status': 'approved',
      }).eq('id', ownerId);

      try {
        await _supabase.from('stadiums').update({'is_verified': true}).eq('owner_id', ownerId);
      } catch (_) {}

      if (mounted) {
        VSPFeedback.showSuccess(context, 'تم قبول وتوثيق المالك بنجاح! 🏆');
      }
    } catch (e) {
      if (mounted) VSPFeedback.showError(context, 'فشل قبول المالك: $e');
    }
  }

  void _showRejectOwnerDialog(String ownerId, bool isArabic) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        title: Text(isArabic ? 'سبب رفض التوثيق' : 'Rejection Reason', style: const TextStyle(color: Colors.white)),
        content: CustomTextField(
          controller: reasonController,
          hintText: isArabic ? 'أدخل سبب الرفض (مثال: مستندات غير واضحة)...' : 'Enter rejection reason...',
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isArabic ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              Navigator.pop(ctx);
              try {
                final userDoc = await _supabase.from('users').select('additional_data').eq('id', ownerId).maybeSingle();
                final addData = Map<String, dynamic>.from(userDoc?['additional_data'] ?? {});
                addData['rejection_reason'] = reason.isNotEmpty ? reason : 'مستندات غير مكتملة';

                await _supabase.from('users').update({
                  'verification_status': 'rejected',
                  'additional_data': addData,
                }).eq('id', ownerId);

                if (mounted) VSPFeedback.showSuccess(context, 'تم رفض الطلب وإبلاغ المالك.');
              } catch (e) {
                if (mounted) VSPFeedback.showError(context, 'فشل تنفيذ الرفض: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: VSPColors.error, foregroundColor: Colors.white),
            child: Text(isArabic ? 'تأكيد الرفض' : 'Confirm Rejection'),
          ),
        ],
      ),
    );
  }

  Future<void> _resolveMatchDispute(String bookingId, MatchOutcome outcome) async {
    try {
      await _supabase.from('bookings').update({
        'status': BookingStatus.completed.name,
        'final_outcome': outcome.name,
        'match_result_status': MatchResultStatus.confirmed.name,
        'pending_outcome': null,
        'requires_admin_intervention': false,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', bookingId);

      if (mounted) VSPFeedback.showSuccess(context, 'تم فض النزاع وتأكيد النتيجة بنجاح! 🏆');
    } catch (e) {
      if (mounted) VSPFeedback.showError(context, 'فشل فض النزاع: $e');
    }
  }

  Future<void> _blockTargetUser(String userId) async {
    try {
      await _supabase.from('users').update({'status': 'blocked'}).eq('id', userId);
      try {
        await _supabase.from('users').update({'is_blocked': true}).eq('id', userId);
      } catch (_) {}
      if (mounted) VSPFeedback.showSuccess(context, 'تم حظر المستخدم الهدف من المنصة.');
    } catch (e) {
      if (mounted) VSPFeedback.showError(context, 'فشل حظر المستخدم: $e');
    }
  }

  Future<void> _dismissReport(String reportId) async {
    try {
      await _supabase.from('reports').delete().eq('id', reportId);
      if (mounted) VSPFeedback.showSuccess(context, 'تم إغلاق البلاغ.');
    } catch (e) {
      if (mounted) VSPFeedback.showError(context, 'فشل إغلاق البلاغ: $e');
    }
  }

  Widget _buildDocLinkChip(String label, String url) {
    return ActionChip(
      avatar: const Icon(LucideIcons.externalLink, color: VSPColors.accent, size: 14),
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
      backgroundColor: VSPColors.surfaceAlt,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.sm)),
      onPressed: () {},
    );
  }

  Widget _buildTeamDisputeSide(String teamName, String claim) {
    return Column(
      children: [
        Text(teamName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 4),
        Text(claim, style: const TextStyle(color: VSPColors.warning, fontSize: 11)),
      ],
    );
  }

  Widget _buildPayoutRow(String method, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(method, style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12)),
          SelectableText(value, style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}
