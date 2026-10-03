import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/stadium_provider.dart';
import '../../../core/repositories/match_repository.dart';
import '../../../core/repositories/user_repository.dart';
import '../../../core/models/user_model.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../data/models.dart';
import '../../../l10n/app_localizations.dart';
import '../screens/match_details_screen.dart';

class CollectiveMatchInviteSheet extends StatefulWidget {
  final String bookingId;
  final Booking? initialBooking;
  const CollectiveMatchInviteSheet({super.key, required this.bookingId, this.initialBooking});

  static Future<void> show(BuildContext context, {required String bookingId, Booking? initialBooking}) {
    return showModalBottomSheet<void>(
      context: context, isScrollControlled: true, useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CollectiveMatchInviteSheet(bookingId: bookingId, initialBooking: initialBooking),
    );
  }

  @override
  State<CollectiveMatchInviteSheet> createState() => _CollectiveMatchInviteSheetState();
}

class _CollectiveMatchInviteSheetState extends State<CollectiveMatchInviteSheet> {
  Booking? _booking;
  Stadium? _stadium;
  final Map<String, UserModel> _users = {};
  bool _loading = true, _joining = false, _leaving = false;

  @override
  void initState() {
    super.initState();
    _booking = widget.initialBooking;
    _load();
  }

  Future<void> _load() async {
    try {
      final booking = await MatchRepository().getPublicMatchDetails(widget.bookingId);
      if (!mounted) return;
      if (booking != null) {
        _booking = booking;
        _stadium = await context.read<StadiumProvider>().getStadiumById(booking.stadiumId);
        await _loadUsers(booking.joinedUserIds);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadUsers(List<String> ids) async {
    final missing = ids.where((id) => !_users.containsKey(id)).toList();
    if (missing.isEmpty) return;
    try {
      final users = await UserRepository().getUsersByIds(missing);
      if (!mounted) return;
      setState(() { for (final user in users) { _users[user.uid] = user; } });
    } catch (_) {}
  }

  Future<void> _join() async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) {
      VSPFeedback.showError(context, AppLocalizations.of(context)!.loginToJoinError);
      return;
    }
    if (_joining) return;
    setState(() => _joining = true);
    try {
      await MatchRepository().joinPublicMatch(widget.bookingId, uid);
      await _load();
      if (mounted) VSPFeedback.showSuccess(context, Localizations.localeOf(context).languageCode == 'ar' ? 'تم انضمامك للمباراة وتأكيد مكانك بنجاح.' : 'Joined match successfully.');
    } catch (e) {
      if (mounted) VSPFeedback.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _leave() async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null || _leaving) return;
    setState(() => _leaving = true);
    try {
      await MatchRepository().leavePublicMatch(widget.bookingId, uid);
      await _load();
      if (mounted) VSPFeedback.showSuccess(context, Localizations.localeOf(context).languageCode == 'ar' ? 'تمت مغادرة المباراة بنجاح.' : 'You left the match successfully.');
    } catch (e) {
      if (mounted) VSPFeedback.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _leaving = false);
    }
  }

  Future<void> _openLocation() async {
    final raw = _stadium?.googleMapsUrl;
    if (raw == null || raw.isEmpty) return;
    final uri = Uri.tryParse(raw);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final booking = _booking;
    final uid = context.read<AuthProvider>().currentUser?.uid;
    final isHost = booking != null && booking.createdByUserId == uid;
    final joined = booking != null && uid != null && booking.joinedUserIds.contains(uid);
    final full = booking != null && booking.currentPlayers >= booking.totalFieldCapacity;
    final ended = booking != null && booking.endTime.isBefore(DateTime.now());
    final cancelled = booking?.status == BookingStatus.cancelled;
    final perPlayer = booking == null || booking.totalFieldCapacity <= 0 ? 0 : (booking.totalPrice / booking.totalFieldCapacity).round();

    if (_loading && booking == null) {
      return const SizedBox(height: 360, child: Center(child: CircularProgressIndicator(color: VSPColors.accent)));
    }
    if (booking == null) {
      return SizedBox(height: 300, child: Center(child: Text(ar ? 'لم تعد هذه المباراة التجميعية متاحة.' : 'This collective match is no longer available.', style: const TextStyle(color: VSPColors.textSecondary))));
    }

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .90),
      decoration: const BoxDecoration(color: VSPColors.surfaceAlt, borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl))),
      child: Column(children: [
        const SizedBox(height: 10),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: VSPColors.divider, borderRadius: BorderRadius.circular(4))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
          child: Row(children: [
            Expanded(child: Text(ar ? 'دعوة مباراة تجميعية' : 'Collective Match Invitation', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Iconsax.close_circle_copy, color: VSPColors.textSecondary)),
          ]),
        ),
        Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 20), children: [
          if (_stadium?.imageUrl.isNotEmpty == true)
            ClipRRect(borderRadius: BorderRadius.circular(VSPRadius.lg), child: CachedNetworkImage(imageUrl: _stadium!.imageUrl, height: 150, fit: BoxFit.cover)),
          const SizedBox(height: 14),
          Row(children: [
            CircleAvatar(radius: 24, backgroundColor: VSPColors.surface, backgroundImage: booking.hostAvatarUrl?.isNotEmpty == true ? CachedNetworkImageProvider(booking.hostAvatarUrl!) : null, child: booking.hostAvatarUrl?.isNotEmpty == true ? null : const Icon(Iconsax.user_copy, color: VSPColors.accent)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(booking.hostName ?? (ar ? 'منشئ الحجز' : 'Host'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
              Text(booking.stadiumName, style: const TextStyle(color: VSPColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12)),
            ])),
            _badge(ar ? 'خاص' : 'Private'),
          ]),
          const SizedBox(height: 14),
          _infoRow(Iconsax.calendar_1_copy, ar ? 'التاريخ' : 'Date', booking.formattedDate),
          _infoRow(Iconsax.clock_copy, ar ? 'الوقت' : 'Time', booking.formattedTimeRange),
          _infoRow(Iconsax.money_copy, ar ? 'تكلفة الحجز' : 'Booking cost', booking.totalPrice.toInt().toString() + (ar ? ' ج.م' : ' EGP')),
          _infoRow(Iconsax.wallet_1_copy, ar ? 'نصيب الفرد' : 'Per player', perPlayer.toString() + (ar ? ' ج.م' : ' EGP')),
          _infoRow(Iconsax.location_copy, ar ? 'الموقع' : 'Location', _stadium?.location ?? booking.stadiumName),
          if (_stadium?.googleMapsUrl?.isNotEmpty == true)
            OutlinedButton.icon(onPressed: _openLocation, icon: const Icon(Iconsax.routing_2_copy, size: 18), label: Text(ar ? 'فتح موقع الملعب' : 'Open stadium location'), style: OutlinedButton.styleFrom(foregroundColor: VSPColors.accent, side: BorderSide(color: VSPColors.accent.withValues(alpha: .45)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)))),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(VSPRadius.lg), border: Border.all(color: VSPColors.divider)),
            child: Row(children: [
              const Icon(Iconsax.profile_2user_copy, color: VSPColors.accent), const SizedBox(width: 10),
              Expanded(child: Text(ar ? 'المنضمون' : 'Joined players', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
              Text(booking.currentPlayers.toString() + ' / ' + booking.totalFieldCapacity.toString(), style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.w900)),
            ]),
          ),
          ...booking.joinedUserIds.map((id) {
            final user = _users[id];
            final name = user?.name?.isNotEmpty == true ? user!.name! : (id == booking.createdByUserId ? (ar ? 'المنشئ' : 'Host') : (ar ? 'لاعب' : 'Player'));
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(backgroundColor: VSPColors.surface, backgroundImage: user?.profileImageUrl?.isNotEmpty == true ? CachedNetworkImageProvider(user!.profileImageUrl!) : null, child: user?.profileImageUrl?.isNotEmpty == true ? null : const Icon(Iconsax.user_copy, color: VSPColors.textSecondary)),
              title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              subtitle: id == booking.createdByUserId ? Text(ar ? 'منشئ الحجز' : 'Host', style: const TextStyle(color: VSPColors.accent, fontSize: 11)) : null,
            );
          }),
          const SizedBox(height: 8),
          Text(ar ? 'لا يوجد دفع منفصل عند انضمام اللاعبين؛ تكلفة الحجز مسؤولية المنشئ.' : 'Players do not pay separately when joining; the host is responsible for the booking cost.', style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12, height: 1.4)),
        ])),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.paddingOf(context).bottom + 12),
          child: isHost
              ? OutlinedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MatchDetailsScreen(bookingId: booking.id))),
                  style: OutlinedButton.styleFrom(foregroundColor: VSPColors.accent, side: BorderSide(color: VSPColors.accent.withValues(alpha: .5)), minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.button))),
                  child: Text(ar ? 'إدارة الحجز' : 'Manage booking'),
                )
              : Row(children: [
                  Expanded(child: ElevatedButton(
                    onPressed: cancelled || ended || full || joined ? null : _join,
                    style: ElevatedButton.styleFrom(backgroundColor: VSPColors.accent, foregroundColor: Colors.black, minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.button))),
                    child: _joining ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(joined ? (ar ? 'أنت منضم' : 'You joined') : (full ? (ar ? 'اكتملت' : 'Full') : (ar ? 'انضمام' : 'Join')), style: const TextStyle(fontWeight: FontWeight.w900)),
                  )),
                  if (joined) ...[
                    const SizedBox(width: 10),
                    Expanded(child: OutlinedButton(onPressed: ended || cancelled ? null : _leave, style: OutlinedButton.styleFrom(foregroundColor: VSPColors.error, side: BorderSide(color: VSPColors.error.withValues(alpha: .5)), minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.button))), child: _leaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(ar ? 'مغادرة' : 'Leave'))),
                  ],
                ]),
        ),
      ]),
    );
  }

  Widget _badge(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: VSPColors.accent.withValues(alpha: .12), borderRadius: BorderRadius.circular(VSPRadius.full), border: Border.all(color: VSPColors.accent.withValues(alpha: .35))),
    child: Text(text, style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.w800, fontSize: 11)),
  );

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: VSPColors.accent, size: 19), const SizedBox(width: 10),
      Text(label, style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12)), const SizedBox(width: 8),
      Expanded(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13))),
    ]),
  );
}
