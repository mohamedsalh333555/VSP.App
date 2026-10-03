import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/user_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/providers/stadium_provider.dart';
import '../../../core/repositories/match_repository.dart';
import '../../../core/repositories/user_repository.dart';
import '../../../core/services/sharing_service.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../data/models.dart';
import '../../../l10n/app_localizations.dart';

class CollectiveMatchInviteSheet extends StatefulWidget {
  final String? bookingId;
  final String? inviteToken;
  final Booking? initialBooking;
  final Map<String, dynamic>? initialInviteData;

  const CollectiveMatchInviteSheet({super.key, this.bookingId, this.inviteToken, this.initialBooking, this.initialInviteData})
      : assert(bookingId != null || inviteToken != null);

  static Future<void> showForBooking(BuildContext context, {required String bookingId, Booking? initialBooking}) => showModalBottomSheet<void>(
        context: context, isScrollControlled: true, useSafeArea: true, backgroundColor: Colors.transparent,
        builder: (_) => CollectiveMatchInviteSheet(bookingId: bookingId, initialBooking: initialBooking),
      );

  static Future<void> showForInvite(BuildContext context, {required String inviteToken, Map<String, dynamic>? initialInviteData}) => showModalBottomSheet<void>(
        context: context, isScrollControlled: true, useSafeArea: true, backgroundColor: Colors.transparent,
        builder: (_) => CollectiveMatchInviteSheet(inviteToken: inviteToken, initialInviteData: initialInviteData),
      );

  @override
  State<CollectiveMatchInviteSheet> createState() => _CollectiveMatchInviteSheetState();
}

class _CollectiveMatchInviteSheetState extends State<CollectiveMatchInviteSheet> {
  final _repo = MatchRepository();
  final Map<String, UserModel> _users = {};
  Booking? _booking;
  Stadium? _stadium;
  String? _inviteToken;
  String? _inviteCode;
  bool _loading = true;
  bool _joining = false;
  bool _leaving = false;
  bool _updatingManual = false;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _booking = widget.initialBooking;
    _inviteToken = widget.inviteToken;
    if (widget.initialInviteData != null) _applyInviteData(widget.initialInviteData!);
    _load();
  }

  void _applyInviteData(Map<String, dynamic> data) {
    final id = data['id']?.toString();
    if (id == null || id.isEmpty) return;
    _booking = Booking.fromFirestore(data, id);
    _inviteToken ??= data['invite_token']?.toString();
    _inviteCode ??= data['collective_invite_code']?.toString();
  }

  Future<void> _load() async {
    try {
      if (_inviteToken != null && _inviteToken!.isNotEmpty) {
        final data = await _repo.getPrivateCollectiveInviteDetails(_inviteToken!);
        if (data != null) _applyInviteData(data);
      } else if (widget.bookingId != null) {
        _booking = await _repo.getPrivateCollectiveMatchDetails(widget.bookingId!);
      }
      final booking = _booking;
      if (booking != null) {
        _stadium = await context.read<StadiumProvider>().getStadiumById(booking.stadiumId);
        await _loadUsers(booking.joinedUserIds);
        if (_inviteToken == null) {
          final credentials = await _repo.getCollectiveInviteCredentials(booking.id);
          _inviteToken = credentials?['invite_token']?.toString();
          _inviteCode = credentials?['invite_code']?.toString();
        }
      }
    } catch (e) {
      VSPLogger.w('Collective invite load failed: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _reload() async {
    final id = _booking?.id ?? widget.bookingId;
    if (id == null || id.isEmpty) return;
    final booking = await _repo.getPrivateCollectiveMatchDetails(id);
    if (!mounted || booking == null) return;
    setState(() => _booking = booking);
    await _loadUsers(booking.joinedUserIds);
  }

  Future<void> _loadUsers(List<String> ids) async {
    final missing = ids.where((id) => id.isNotEmpty && !_users.containsKey(id)).toList();
    if (missing.isEmpty) return;
    try {
      final users = await UserRepository().getUsersByIds(missing);
      if (!mounted) return;
      setState(() { for (final user in users) { _users[user.uid] = user; } });
    } catch (_) {}
  }

  Future<void> _join() async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null || _inviteToken == null || _joining) return;
    setState(() => _joining = true);
    try {
      await _repo.joinPrivateCollectiveMatch(inviteToken: _inviteToken!, userId: uid);
      await _reload();
      if (mounted) VSPFeedback.showSuccess(context, Localizations.localeOf(context).languageCode == 'ar' ? 'تم انضمامك للمباراة بنجاح.' : 'You joined the match successfully.');
    } catch (e) {
      if (mounted) VSPFeedback.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _leave() async {
    final booking = _booking;
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (booking == null || uid == null || _leaving) return;
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        title: Text(ar ? 'مغادرة التجميعية؟' : 'Leave collective match?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: Text(ar ? 'سيتم إتاحة مكانك مرة أخرى.' : 'Your place will become available again.', style: const TextStyle(color: VSPColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ar ? 'إلغاء' : 'Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: VSPColors.error), onPressed: () => Navigator.pop(ctx, true), child: Text(ar ? 'مغادرة' : 'Leave')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _leaving = true);
    try {
      await _repo.leavePrivateCollectiveMatch(booking.id, uid);
      await _reload();
      if (mounted) VSPFeedback.showSuccess(context, ar ? 'تمت المغادرة.' : 'You left the match.');
    } catch (e) {
      if (mounted) VSPFeedback.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _leaving = false);
    }
  }

  Future<void> _setManual(int value) async {
    final booking = _booking;
    if (booking == null || _updatingManual) return;
    final max = (booking.totalFieldCapacity - booking.joinedUserIds.length).clamp(0, booking.totalFieldCapacity);
    final next = value.clamp(0, max);
    if (next == booking.manualPlayerCount) return;
    setState(() => _updatingManual = true);
    try {
      final ok = await _repo.updateCollectiveManualPlayers(bookingId: booking.id, manualPlayerCount: next);
      if (!ok) throw Exception('تعذر تحديث عدد اللاعبين.');
      await _reload();
    } catch (e) {
      if (mounted) VSPFeedback.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _updatingManual = false);
    }
  }

  Future<void> _remove(String participantId) async {
    final booking = _booking;
    if (booking == null || participantId == booking.createdByUserId) return;
    try {
      await _repo.removePrivateCollectiveParticipant(booking.id, participantId);
      await _reload();
    } catch (e) {
      if (mounted) VSPFeedback.showError(context, e.toString());
    }
  }

  Future<void> _share() async {
    final booking = _booking;
    if (booking == null) return;
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final credentials = await _repo.getCollectiveInviteCredentials(booking.id);
    final token = credentials?['invite_token']?.toString();
    final code = credentials?['invite_code']?.toString();
    final active = credentials?['active'] == true && credentials?['status'] == 'confirmed';
    if (token == null || token.isEmpty || code == null || code.isEmpty || !active) {
      if (mounted) VSPFeedback.showInfo(context, ar ? 'يمكن مشاركة الدعوة بعد تأكيد الحجز.' : 'The invitation becomes available after confirmation.');
      return;
    }
    _inviteToken = token; _inviteCode = code;
    await SharingService.shareCollectiveInvite(inviteToken: token, inviteCode: code, stadiumName: booking.stadiumName, date: booking.formattedDate + ' - ' + booking.formattedTimeRange, hostName: booking.hostName ?? (ar ? 'المنشئ' : 'Host'));
  }

  Future<void> _cancel() async {
    final booking = _booking;
    if (booking == null || _cancelling) return;
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        title: Text(ar ? 'إلغاء التجميعية؟' : 'Cancel collective match?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: Text(ar ? 'سيتم إلغاء الحجز وإيقاف رابط الدعوة.' : 'The booking will be cancelled and the invitation will stop working.', style: const TextStyle(color: VSPColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ar ? 'رجوع' : 'Back')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: VSPColors.error), onPressed: () => Navigator.pop(ctx, true), child: Text(ar ? 'إلغاء الحجز' : 'Cancel booking')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _cancelling = true);
    try {
      final success = await context.read<BookingProvider>().cancelBooking(booking.id);
      if (!success) throw Exception(ar ? 'تعذر إلغاء الحجز.' : 'Unable to cancel booking.');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) VSPFeedback.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _openLocation() async {
    final url = _stadium?.googleMapsUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final booking = _booking;
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (_loading && booking == null) return const SizedBox(height: 420, child: Center(child: CircularProgressIndicator(color: VSPColors.accent)));
    if (booking == null) return _empty(ar);
    final isHost = uid != null && booking.createdByUserId == uid;
    final joined = uid != null && booking.joinedUserIds.contains(uid);
    final full = booking.currentPlayers >= booking.totalFieldCapacity;
    final ended = booking.endTime.isBefore(DateTime.now());
    final maxManual = (booking.totalFieldCapacity - booking.joinedUserIds.length).clamp(0, booking.totalFieldCapacity);

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .90),
      decoration: const BoxDecoration(color: VSPColors.surfaceAlt, borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl))),
      child: Column(children: [
        const SizedBox(height: 10),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: VSPColors.divider, borderRadius: BorderRadius.circular(4))),
        Padding(padding: const EdgeInsets.fromLTRB(20, 14, 12, 8), child: Row(children: [
          const Icon(Iconsax.people_copy, color: VSPColors.accent, size: 22), const SizedBox(width: 10),
          Expanded(child: Text(ar ? 'التجميعية الخاصة' : 'Private Collective Match', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Iconsax.close_circle_copy, color: VSPColors.textSecondary)),
        ])),
        Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 20), children: [
          if (booking.stadiumImageUrl.isNotEmpty) ClipRRect(borderRadius: BorderRadius.circular(VSPRadius.lg), child: CachedNetworkImage(imageUrl: booking.stadiumImageUrl, height: 155, fit: BoxFit.cover)),
          const SizedBox(height: 14),
          Row(children: [
            CircleAvatar(radius: 23, backgroundColor: VSPColors.surface, backgroundImage: booking.hostAvatarUrl?.isNotEmpty == true ? CachedNetworkImageProvider(booking.hostAvatarUrl!) : null, child: booking.hostAvatarUrl?.isNotEmpty == true ? null : const Icon(Iconsax.user_copy, color: VSPColors.accent)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(booking.hostName ?? (ar ? 'منشئ الحجز' : 'Host'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)), Text(booking.stadiumName, style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700))])),
            _badge(ar ? 'خاص' : 'PRIVATE'),
          ]),
          const SizedBox(height: 14),
          _infoRow(Iconsax.calendar_1_copy, ar ? 'التاريخ' : 'Date', booking.formattedDate),
          _infoRow(Iconsax.clock_copy, ar ? 'الوقت' : 'Time', booking.formattedTimeRange),
          _infoRow(Iconsax.money_copy, ar ? 'إجمالي الحجز' : 'Total booking', booking.totalPrice.toInt().toString() + (ar ? ' ج.م' : ' EGP')),
          _infoRow(Iconsax.card_copy, ar ? 'الدفع' : 'Payment', booking.paymentMethod.toLowerCase() == 'cash' ? (ar ? 'كاش — على المنظم' : 'Cash — host pays') : (ar ? 'أونلاين — على المنظم' : 'Online — host pays')),
          _infoRow(Iconsax.location_copy, ar ? 'موقع الملعب' : 'Stadium location', _stadium?.location ?? booking.stadiumName),
          if (_stadium?.googleMapsUrl?.isNotEmpty == true) OutlinedButton.icon(onPressed: _openLocation, icon: const Icon(Iconsax.routing_2_copy, size: 18), label: Text(ar ? 'فتح موقع الملعب' : 'Open stadium location'), style: OutlinedButton.styleFrom(foregroundColor: VSPColors.accent, side: BorderSide(color: VSPColors.accent.withValues(alpha: .45)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)))),
          const SizedBox(height: 14),
          _sectionHeader(ar ? 'اللاعبون في الحجز' : 'Players in booking', booking.currentPlayers.toString() + ' / ' + booking.totalFieldCapacity.toString()),
          const SizedBox(height: 6),
          ...booking.joinedUserIds.map((id) {
            final user = _users[id];
            final name = user?.name?.trim().isNotEmpty == true ? user!.name! : (id == booking.createdByUserId ? (ar ? 'المنشئ' : 'Host') : (ar ? 'لاعب' : 'Player'));
            final hostRow = id == booking.createdByUserId;
            return ListTile(contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(backgroundColor: VSPColors.surface, backgroundImage: user?.profileImageUrl?.isNotEmpty == true ? CachedNetworkImageProvider(user!.profileImageUrl!) : null, child: user?.profileImageUrl?.isNotEmpty == true ? null : const Icon(Iconsax.user_copy, color: VSPColors.textSecondary)),
              title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              subtitle: hostRow ? Text(ar ? 'منشئ الحجز' : 'Host', style: const TextStyle(color: VSPColors.accent, fontSize: 11)) : null,
              trailing: isHost && !hostRow ? IconButton(onPressed: () => _remove(id), icon: const Icon(Icons.remove_circle_outline, color: VSPColors.error)) : null,
            );
          }),
          if (booking.manualPlayerCount > 0) Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(VSPRadius.md), border: Border.all(color: VSPColors.divider)), child: Row(children: [const Icon(Iconsax.user_octagon_copy, color: VSPColors.textSecondary, size: 19), const SizedBox(width: 10), Expanded(child: Text(ar ? booking.manualPlayerCount.toString() + ' لاعب مضاف بدون تطبيق' : booking.manualPlayerCount.toString() + ' players added without the app', style: const TextStyle(color: VSPColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 12)))])),
          if (isHost) ...[
            const SizedBox(height: 14),
            _manualCounter(ar, booking.manualPlayerCount, maxManual),
            if (_inviteCode?.isNotEmpty == true) ...[const SizedBox(height: 14), _codeCard(ar)],
          ],
          const SizedBox(height: 10),
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: VSPColors.accent.withValues(alpha: .08), borderRadius: BorderRadius.circular(VSPRadius.md), border: Border.all(color: VSPColors.accent.withValues(alpha: .18))), child: Text(ar ? 'لا يوجد دفع منفصل عند الانضمام. تكلفة الحجز كاملة على منشئ التجميعية.' : 'There is no separate payment when joining. The host is responsible for the full booking cost.', style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11, height: 1.45))),
        ])),
        Padding(padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.paddingOf(context).bottom + 12), child: _bottomActions(ar, isHost, joined, full, ended)),
      ]),
    );
  }

  Widget _manualCounter(bool ar, int value, int max) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(VSPRadius.lg), border: Border.all(color: VSPColors.divider)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(ar ? 'إضافة لاعبين بدون تطبيق' : 'Add players without the app', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
    const SizedBox(height: 4),
    Text(ar ? 'للأشخاص الذين أكدوا حضورهم خارج VSP.' : 'For people who confirmed outside VSP.', style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11)),
    const SizedBox(height: 12),
    Row(children: [_counter(Iconsax.minus_copy, value > 0 && !_updatingManual, () => _setManual(value - 1)), Expanded(child: Center(child: _updatingManual ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: VSPColors.accent)) : Text(value.toString(), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)))), _counter(Iconsax.add_copy, value < max && !_updatingManual, () => _setManual(value + 1))]),
    const SizedBox(height: 8),
    Center(child: Text(ar ? 'الإجمالي: ' + (_booking?.currentPlayers.toString() ?? '0') + ' من ' + (_booking?.totalFieldCapacity.toString() ?? '0') : 'Total: ' + (_booking?.currentPlayers.toString() ?? '0') + ' of ' + (_booking?.totalFieldCapacity.toString() ?? '0'), style: const TextStyle(color: VSPColors.accent, fontSize: 12, fontWeight: FontWeight.w800))),
  ]));

  Widget _codeCard(bool ar) => Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(VSPRadius.lg), border: Border.all(color: VSPColors.divider)), child: Row(children: [
    const Icon(Iconsax.key_copy, color: VSPColors.accent), const SizedBox(width: 10),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(ar ? 'كود الدعوة' : 'Invite code', style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11)), const SizedBox(height: 2), Text(_inviteCode ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.2))])),
    IconButton(onPressed: () { Clipboard.setData(ClipboardData(text: _inviteCode ?? '')); VSPFeedback.showSuccess(context, ar ? 'تم نسخ الكود.' : 'Code copied.'); }, icon: const Icon(Iconsax.copy_copy, color: VSPColors.accent)),
  ]));

  Widget _bottomActions(bool ar, bool isHost, bool joined, bool full, bool ended) {
    if (isHost) return Row(children: [Expanded(child: OutlinedButton.icon(onPressed: _share, icon: const Icon(Iconsax.share_copy, size: 18), label: Text(ar ? 'مشاركة الدعوة' : 'Share invite'), style: _outline(VSPColors.accent))), const SizedBox(width: 10), Expanded(child: OutlinedButton(onPressed: _cancelling ? null : _cancel, style: _outline(VSPColors.error), child: _cancelling ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(ar ? 'إلغاء الحجز' : 'Cancel booking')))]);
    if (joined) return OutlinedButton(onPressed: _leaving ? null : _leave, style: _outline(VSPColors.error), child: _leaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(ar ? 'مغادرة' : 'Leave'));
    if (ended || full) return OutlinedButton(onPressed: null, style: _outline(VSPColors.textSecondary), child: Text(ended ? (ar ? 'انتهت' : 'Ended') : (ar ? 'اكتملت' : 'Full')));
    return ElevatedButton(onPressed: _inviteToken == null || _joining ? null : _join, style: ElevatedButton.styleFrom(backgroundColor: VSPColors.accent, foregroundColor: VSPColors.background, minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.button))), child: _joining ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(ar ? 'انضمام' : 'Join', style: const TextStyle(fontWeight: FontWeight.w900)));
  }

  ButtonStyle _outline(Color color) => OutlinedButton.styleFrom(foregroundColor: color, side: BorderSide(color: color.withValues(alpha: .5)), minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.button)));
  Widget _counter(IconData icon, bool enabled, VoidCallback onTap) => SizedBox(width: 44, height: 44, child: IconButton(onPressed: enabled ? onTap : null, style: IconButton.styleFrom(backgroundColor: VSPColors.surfaceAlt, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md))), icon: Icon(icon, size: 18)));
  Widget _sectionHeader(String title, String count) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)), Text(count, style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.w900))]);
  Widget _badge(String text) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: VSPColors.accent.withValues(alpha: .12), borderRadius: BorderRadius.circular(VSPRadius.full), border: Border.all(color: VSPColors.accent.withValues(alpha: .35))), child: Text(text, style: const TextStyle(color: VSPColors.accent, fontSize: 10, fontWeight: FontWeight.w800)));
  Widget _infoRow(IconData icon, String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: VSPColors.accent, size: 18), const SizedBox(width: 10), Text(label, style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12)), const SizedBox(width: 8), Expanded(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)))]));
  Widget _empty(bool ar) => SizedBox(height: 320, child: Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 76, height: 76, decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: VSPColors.divider)), child: const Icon(Iconsax.link_2_copy, color: VSPColors.textSecondary, size: 38)), const SizedBox(height: 18), Text(ar ? 'الدعوة غير متاحة' : 'Invitation unavailable', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)), const SizedBox(height: 8), Text(ar ? 'قد يكون الحجز أُلغي أو انتهى أو لم يعد الرابط صالحاً.' : 'The booking may be cancelled, ended, or the invitation is no longer valid.', textAlign: TextAlign.center, style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12, height: 1.55))]))));
}