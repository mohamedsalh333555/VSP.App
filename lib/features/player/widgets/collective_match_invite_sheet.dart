import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/stadium_provider.dart';
import '../../../core/repositories/match_repository.dart';
import '../../../core/repositories/booking_repository.dart';
import '../../../core/repositories/user_repository.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/sharing_service.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../data/models.dart';
import '../../../l10n/app_localizations.dart';
import '../screens/match_details_screen.dart';

class CollectiveMatchInviteSheet extends StatefulWidget {
  final String? bookingId;
  final String? inviteToken;
  final Booking? initialBooking;

  const CollectiveMatchInviteSheet({
    super.key,
    this.bookingId,
    this.inviteToken,
    this.initialBooking,
  }) : assert(bookingId != null || inviteToken != null);

  static Future<void> show(
    BuildContext context, {
    String? bookingId,
    String? inviteToken,
    Booking? initialBooking,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CollectiveMatchInviteSheet(
        bookingId: bookingId,
        inviteToken: inviteToken,
        initialBooking: initialBooking,
      ),
    );
  }

  static Future<void> showInviteData(
    BuildContext context,
    Map<String, dynamic> inviteData,
  ) {
    final id = inviteData['id']?.toString();
    final token = inviteData['invite_token']?.toString();
    if (id == null || id.isEmpty || token == null || token.isEmpty) {
      return Future.value();
    }
    return show(
      context,
      bookingId: id,
      inviteToken: token,
      initialBooking: Booking.fromFirestore(inviteData, id),
    );
  }

  @override
  State<CollectiveMatchInviteSheet> createState() => _CollectiveMatchInviteSheetState();
}

class _CollectiveMatchInviteSheetState extends State<CollectiveMatchInviteSheet> {
  Booking? _booking;
  Stadium? _stadium;
  final Map<String, UserModel> _users = {};
  String? _inviteToken;
  String? _inviteCode;
  bool _loading = true;
  bool _joining = false;
  bool _leaving = false;
  bool _updatingManualPlayers = false;

  @override
  void initState() {
    super.initState();
    _booking = widget.initialBooking;
    _inviteToken = widget.inviteToken;
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      Booking? booking = _booking;

      if (_inviteToken != null && _inviteToken!.isNotEmpty) {
        final invite = await MatchRepository().getPrivateCollectiveInviteDetails(_inviteToken!);
        if (invite != null) {
          final id = invite['id']?.toString() ?? widget.bookingId ?? '';
          booking = Booking.fromFirestore(invite, id);
          _inviteToken = invite['invite_token']?.toString() ?? _inviteToken;
          _inviteCode = invite['collective_invite_code']?.toString();
        }
      } else if (widget.bookingId != null) {
        booking = await MatchRepository().getPrivateCollectiveMatchDetails(widget.bookingId!);
      }

      if (!mounted) return;
      if (booking != null) {
        _booking = booking;
        _stadium = await context.read<StadiumProvider>().getStadiumById(booking.stadiumId);
        await _loadUsers(booking.joinedUserIds);

        final uid = context.read<AuthProvider>().currentUser?.uid;
        if (uid == booking.createdByUserId) {
          final credentials = await MatchRepository().getCollectiveInviteCredentials(booking.id);
          if (credentials != null) {
            _inviteToken = credentials['invite_token']?.toString() ?? _inviteToken;
            _inviteCode = credentials['invite_code']?.toString();
          }
        }
      }
    } catch (e) {
      if (mounted) VSPFeedback.showError(context, e.toString());
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
      setState(() {
        for (final user in users) {
          _users[user.uid] = user;
        }
      });
    } catch (_) {}
  }

  Future<void> _join() async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null || _inviteToken == null || _inviteToken!.isEmpty || _joining) return;
    setState(() => _joining = true);
    try {
      await MatchRepository().joinPrivateCollectiveMatch(
        inviteToken: _inviteToken!,
        userId: uid,
      );
      await _load();
      if (mounted) {
        VSPFeedback.showSuccess(
          context,
          Localizations.localeOf(context).languageCode == 'ar'
              ? 'تم انضمامك للمباراة وتأكيد مكانك بنجاح.'
              : 'You joined the match successfully.',
        );
      }
    } catch (e) {
      if (mounted) VSPFeedback.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _leave() async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null || _leaving || _booking == null) return;
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(ar ? 'مغادرة المباراة؟' : 'Leave match?'),
        content: Text(
          ar
              ? 'هل أنت متأكد أنك تريد مغادرة المباراة؟ سيتم إتاحة مكانك للاعبين الآخرين.'
              : 'Are you sure you want to leave this match? Your place will become available to other players.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(ar ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: VSPColors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(ar ? 'تأكيد المغادرة' : 'Confirm leave'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _leaving = true);
    try {
      await MatchRepository().leavePublicMatch(_booking!.id, uid);
      await _load();
      if (mounted) VSPFeedback.showSuccess(context, ar ? 'تمت مغادرة المباراة بنجاح.' : 'You left the match successfully.');
    } catch (e) {
      if (mounted) VSPFeedback.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _leaving = false);
    }
  }

  Future<void> _removeParticipant(String participantId) async {
    final booking = _booking;
    if (booking == null) return;
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(ar ? 'إزالة اللاعب؟' : 'Remove player?'),
        content: Text(
          ar
              ? 'سيتم إخراج هذا اللاعب من التجميعية وسيصبح مكانه متاحًا.'
              : 'This player will be removed from the collective match and the place will become available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(ar ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(ar ? 'إزالة' : 'Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final ok = await MatchRepository().removePrivateCollectiveParticipant(
        bookingId: booking.id,
        participantId: participantId,
      );
      if (!ok && mounted) {
        VSPFeedback.showError(context, ar ? 'تعذر إزالة اللاعب.' : 'Could not remove the player.');
      }
      await _load();
    } catch (e) {
      if (mounted) VSPFeedback.showError(context, e.toString());
    }
  }

  Future<void> _cancelBooking() async {
    final booking = _booking;
    if (booking == null) return;
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(ar ? 'إلغاء التجميعية؟' : 'Cancel collective match?'),
        content: Text(
          ar
              ? 'سيتم إلغاء الحجز وإيقاف رابط الدعوة. أي مبلغ مستحق للاسترداد سيُعالج حسب طريقة الدفع.'
              : 'The booking will be cancelled and the invite will be disabled. Any eligible refund will be processed according to the payment method.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(ar ? 'الاحتفاظ بالحجز' : 'Keep booking'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: VSPColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(ar ? 'إلغاء الحجز' : 'Cancel booking'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final ok = await SupabaseBookingRepository().cancelBooking(booking.id);
      if (!mounted) return;
      if (ok) {
        VSPFeedback.showSuccess(context, ar ? 'تم إلغاء التجميعية.' : 'Collective match cancelled.');
        Navigator.pop(context);
      } else {
        VSPFeedback.showError(context, ar ? 'تعذر إلغاء الحجز.' : 'Could not cancel the booking.');
      }
    } catch (e) {
      if (mounted) VSPFeedback.showError(context, e.toString());
    }
  }

  Future<void> _requestReschedule() async {
    final booking = _booking;
    if (booking == null) return;
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final now = DateTime.now();
    final initialDate = booking.startTime.isBefore(now) ? now : booking.startTime;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(booking.startTime),
    );
    if (pickedTime == null || !mounted) return;
    final newStart = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    final newEnd = newStart.add(booking.endTime.difference(booking.startTime));
    try {
      await SupabaseBookingRepository().requestReschedule(
        bookingId: booking.id,
        newStartTime: newStart,
        newEndTime: newEnd,
      );
      await _load();
      if (mounted) {
        VSPFeedback.showSuccess(
          context,
          ar ? 'تم إرسال طلب تعديل الموعد.' : 'The reschedule request was submitted.',
        );
      }
    } catch (e) {
      if (mounted) VSPFeedback.showError(context, e.toString());
    }
  }

  Future<void> _changeManualPlayers(int next) async {
    final booking = _booking;
    if (booking == null || _updatingManualPlayers) return;
    final manualMax = (booking.totalFieldCapacity - booking.joinedUserIds.length).clamp(0, booking.totalFieldCapacity);
    if (next < 0 || next > manualMax) return;
    setState(() => _updatingManualPlayers = true);
    try {
      final ok = await MatchRepository().updateCollectiveManualPlayers(
        bookingId: booking.id,
        manualPlayerCount: next,
      );
      if (!ok && mounted) {
        VSPFeedback.showError(context, Localizations.localeOf(context).languageCode == 'ar' ? 'تعذر تحديث العدد.' : 'Could not update the player count.');
      }
      await _load();
    } finally {
      if (mounted) setState(() => _updatingManualPlayers = false);
    }
  }

  Future<void> _shareInvite() async {
    final booking = _booking;
    if (booking == null) return;
    final credentials = await MatchRepository().getCollectiveInviteCredentials(booking.id);
    if (!mounted) return;
    final token = credentials?['invite_token']?.toString();
    final code = credentials?['invite_code']?.toString();
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    if (token == null || token.isEmpty || code == null || code.isEmpty) {
      VSPFeedback.showInfo(context, ar ? 'لا توجد دعوة صالحة للمشاركة حاليًا.' : 'No active invite is available.');
      return;
    }
    _inviteToken = token;
    _inviteCode = code;
    await SharingService.shareCollectiveInvite(
      inviteToken: token,
      inviteCode: code,
      stadiumName: booking.stadiumName,
      date: booking.formattedDate + ' - ' + booking.formattedTimeRange,
      hostName: booking.hostName ?? (ar ? 'المنشئ' : 'Host'),
    );
  }

  Future<void> _copy(String value, String message) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) VSPFeedback.showSuccess(context, message);
  }

  Future<void> _openLocation() async {
    final url = _stadium?.googleMapsUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _paymentText(Booking booking, bool ar) {
    if (booking.paymentMethod.toLowerCase() == 'cash') {
      return ar ? 'المنشئ يدفع نقدًا عند الملعب' : 'Host pays cash at the stadium';
    }
    if (booking.paymentStatus == 'paid' || booking.isPaid) {
      return ar ? 'تم السداد إلكترونيًا بواسطة المنشئ' : 'Paid online by the host';
    }
    return ar ? 'الدفع الإلكتروني بواسطة المنشئ قبل بدء المباراة' : 'Host must complete online payment before the match';
  }

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final booking = _booking;
    final uid = context.read<AuthProvider>().currentUser?.uid;

    if (_loading && booking == null) {
      return const SizedBox(height: 360, child: Center(child: CircularProgressIndicator(color: VSPColors.accent)));
    }
    if (booking == null) {
      return SizedBox(height: 300, child: Center(child: Text(ar ? 'لم تعد هذه التجميعية متاحة.' : 'This collective match is no longer available.', style: const TextStyle(color: VSPColors.textSecondary))));
    }

    final isHost = booking.createdByUserId == uid;
    final joined = uid != null && booking.joinedUserIds.contains(uid);
    final full = booking.currentPlayers >= booking.totalFieldCapacity;
    final ended = booking.endTime.isBefore(DateTime.now());
    final cancelled = booking.status == BookingStatus.cancelled;
    final manualMax = (booking.totalFieldCapacity - booking.joinedUserIds.length).clamp(0, booking.totalFieldCapacity);

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .92),
      decoration: const BoxDecoration(color: VSPColors.surfaceAlt, borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl))),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: VSPColors.divider, borderRadius: BorderRadius.circular(4))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(children: [
              Expanded(child: Text(ar ? 'التجميعية' : 'Collective Match', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
              if (isHost) IconButton(onPressed: _shareInvite, icon: const Icon(Iconsax.share_copy, color: VSPColors.accent)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Iconsax.close_circle_copy, color: VSPColors.textSecondary)),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              children: [
                if (_stadium?.imageUrl.isNotEmpty == true)
                  ClipRRect(borderRadius: BorderRadius.circular(VSPRadius.lg), child: CachedNetworkImage(imageUrl: _stadium!.imageUrl, height: 150, fit: BoxFit.cover)),
                const SizedBox(height: 14),
                Row(children: [
                  CircleAvatar(radius: 24, backgroundColor: VSPColors.surface, backgroundImage: booking.hostAvatarUrl?.isNotEmpty == true ? CachedNetworkImageProvider(booking.hostAvatarUrl!) : null, child: booking.hostAvatarUrl?.isNotEmpty == true ? null : const Icon(Iconsax.user_copy, color: VSPColors.accent)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(booking.hostName ?? (ar ? 'المنشئ' : 'Host'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
                    Text(booking.stadiumName, style: const TextStyle(color: VSPColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12)),
                  ])),
                  _badge(ar ? 'خاص' : 'Private'),
                ]),
                const SizedBox(height: 14),
                _infoRow(Iconsax.calendar_1_copy, ar ? 'التاريخ' : 'Date', booking.formattedDate),
                _infoRow(Iconsax.clock_copy, ar ? 'الوقت' : 'Time', booking.formattedTimeRange),
                _infoRow(Iconsax.wallet_1_copy, ar ? 'إجمالي الحجز' : 'Total booking', booking.totalPrice.toInt().toString() + (ar ? ' ج.م' : ' EGP')),
                _infoRow(Iconsax.money_copy, ar ? 'الدفع' : 'Payment', _paymentText(booking, ar)),
                _infoRow(Iconsax.location_copy, ar ? 'الموقع' : 'Location', _stadium?.location ?? booking.stadiumName),
                if (_stadium?.googleMapsUrl?.isNotEmpty == true)
                  OutlinedButton.icon(onPressed: _openLocation, icon: const Icon(Iconsax.routing_2_copy, size: 18), label: Text(ar ? 'الاتجاه إلى الملعب' : 'Get directions'), style: OutlinedButton.styleFrom(foregroundColor: VSPColors.accent, side: BorderSide(color: VSPColors.accent.withValues(alpha: .45)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)))),
                const SizedBox(height: 12),
                Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(VSPRadius.lg), border: Border.all(color: VSPColors.divider)), child: Row(children: [
                  const Icon(Iconsax.profile_2user_copy, color: VSPColors.accent), const SizedBox(width: 10),
                  Expanded(child: Text(ar ? 'إجمالي الموجودين في الحجز' : 'Total people in booking', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                  Text(booking.currentPlayers.toString() + ' / ' + booking.totalFieldCapacity.toString(), style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.w900)),
                ])),
                const SizedBox(height: 12),
                _sectionTitle(ar ? 'المنضمون عبر VSP' : 'Joined through VSP'),
                ...booking.joinedUserIds.map((id) {
                  final user = _users[id];
                  final name = user?.name?.isNotEmpty == true ? user!.name! : (id == booking.createdByUserId ? (ar ? 'المنشئ' : 'Host') : (ar ? 'لاعب' : 'Player'));
                  return ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(backgroundColor: VSPColors.surface, backgroundImage: user?.profileImageUrl?.isNotEmpty == true ? CachedNetworkImageProvider(user!.profileImageUrl!) : null, child: user?.profileImageUrl?.isNotEmpty == true ? null : const Icon(Iconsax.user_copy, color: VSPColors.textSecondary)), title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)), subtitle: id == booking.createdByUserId ? Text(ar ? 'المنشئ' : 'Host', style: const TextStyle(color: VSPColors.accent, fontSize: 11)) : null, trailing: isHost && id != booking.createdByUserId ? IconButton(icon: const Icon(Iconsax.user_remove_copy, color: VSPColors.error, size: 18), onPressed: () => _removeParticipant(id)) : null);
                }),
                const SizedBox(height: 8),
                Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(VSPRadius.lg), border: Border.all(color: VSPColors.divider)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [const Icon(Iconsax.user_add_copy, color: VSPColors.accent), const SizedBox(width: 10), Expanded(child: Text(ar ? 'لاعبون مضافون بدون تطبيق' : 'Players added without the app', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))), Text(booking.manualPlayerCount.toString(), style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.w900))]),
                  if (isHost) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      IconButton(onPressed: booking.manualPlayerCount > 0 && !_updatingManualPlayers ? () => _changeManualPlayers(booking.manualPlayerCount - 1) : null, icon: const Icon(Iconsax.minus_copy, color: Colors.white)),
                      Expanded(child: Center(child: Text(booking.manualPlayerCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)))),
                      IconButton(onPressed: booking.manualPlayerCount < manualMax && !_updatingManualPlayers ? () => _changeManualPlayers(booking.manualPlayerCount + 1) : null, icon: const Icon(Iconsax.add_copy, color: Colors.white)),
                    ]),
                    Text(ar ? 'لأشخاص أكدوا حضورهم معك ولا يحتاجون تطبيق VSP.' : 'For people who confirmed with you and do not need the VSP app.', style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11, height: 1.4)),
                  ]
                ])),
                if (isHost && _inviteToken != null && _inviteCode != null) ...[
                  const SizedBox(height: 10),
                  Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(VSPRadius.lg), border: Border.all(color: VSPColors.divider)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(ar ? 'رابط وكود الدعوة' : 'Invite link & code', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Row(children: [Expanded(child: SelectableText(_inviteCode!, style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 18))), IconButton(onPressed: () => _copy(_inviteCode!, ar ? 'تم نسخ الكود.' : 'Code copied.'), icon: const Icon(Iconsax.copy_copy, color: VSPColors.textSecondary))]),
                    Text(SharingService.getCollectiveInviteLink(_inviteToken!), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11)),
                    const SizedBox(height: 6),
                    Text(ar ? 'ابعت الرابط في WhatsApp. الكود بديل لو الرابط لم يفتح.' : 'Send the link in WhatsApp. The code is a fallback if the link cannot open.', style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11, height: 1.4)),
                  ])),
                ],
              ],
            ),
          ),
          if (isHost && !cancelled && !ended) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _requestReschedule,
                      icon: const Icon(Iconsax.calendar_edit_copy, size: 18),
                      label: Text(ar ? 'تعديل الموعد' : 'Change time'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _cancelBooking,
                      icon: const Icon(Iconsax.trash_copy, size: 18),
                      label: Text(ar ? 'إلغاء الحجز' : 'Cancel booking'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: VSPColors.error,
                        side: BorderSide(color: VSPColors.error.withValues(alpha: .5)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Padding(
            padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.paddingOf(context).bottom + 12),
            child: isHost
                ? OutlinedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MatchDetailsScreen(bookingId: booking.id))),
                    style: OutlinedButton.styleFrom(foregroundColor: VSPColors.accent, side: BorderSide(color: VSPColors.accent.withValues(alpha: .5)), minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.button))),
                    child: Text(ar ? 'إدارة الحجز' : 'Manage booking'),
                  )
                : ElevatedButton(
                    onPressed: cancelled || ended || full || joined || _inviteToken == null ? null : _join,
                    style: ElevatedButton.styleFrom(backgroundColor: VSPColors.accent, foregroundColor: Colors.black, minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.button))),
                    child: _joining ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(joined ? (ar ? 'أنت منضم' : 'You joined') : (full ? (ar ? 'اكتملت' : 'Full') : (ar ? 'انضمام' : 'Join')), style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(color: VSPColors.textSecondary, fontWeight: FontWeight.w800, fontSize: 12)),
  );

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
      Expanded(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),),
    ]),
  );
}