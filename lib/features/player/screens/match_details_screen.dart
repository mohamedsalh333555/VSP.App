import '../../../core/repositories/booking_repository.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../data/models.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/providers/stadium_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../core/services/sharing_service.dart';
import '../../../core/repositories/report_repository.dart';
import '../../../core/utils/vsp_match_invite_formatter.dart';
import '../../../core/repositories/user_repository.dart';
import '../../../core/repositories/match_repository.dart';
import '../../../core/models/user_model.dart';
import 'chat_screen.dart';

class MatchDetailsScreen extends StatefulWidget {
 final String bookingId;

 const MatchDetailsScreen({super.key, required this.bookingId});

 @override
 State<MatchDetailsScreen> createState() => _MatchDetailsScreenState();
}

class _MatchDetailsScreenState extends State<MatchDetailsScreen> {
 bool _isLoading = true;
 Booking? _booking;
 Stadium? _stadium;
 bool _isJoining = false;
  bool _isActionProcessing = false;
  final Map<String, UserModel> _joinedUserProfiles = {};
  late final Stream<List<Map<String, dynamic>>> _bookingStream;

  Future<void> _loadJoinedUsers(List<String> userIds) async {
    if (userIds.isEmpty) return;
    try {
      final users = await UserRepository().getUsersByIds(userIds);
      if (mounted) {
        setState(() {
          for (final u in users) {
            _joinedUserProfiles[u.uid] = u;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading joined users: $e');
    }
  }

 @override
 void initState() {
 super.initState();
 _bookingStream = SupabaseBookingRepository().streamBookingRaw(widget.bookingId);
    _fetchMatchDetails();
 }

 Future<void> _fetchMatchDetails() async {
 setState(() => _isLoading = true);
 try {
 final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
 final stadiumProvider = Provider.of<StadiumProvider>(context, listen: false);

 final booking = await bookingProvider.getBookingById(widget.bookingId);
 if (booking != null) {
 _booking = booking;
        _stadium = await stadiumProvider.getStadiumById(booking.stadiumId);
        if (booking.joinedUserIds.isNotEmpty) {
          _loadJoinedUsers(booking.joinedUserIds);
        }
 }
 } catch (e) {
 debugPrint('Error fetching match details: ');
 } finally {
 if (mounted) setState(() => _isLoading = false);
 }
 }

 Future<void> _onJoin() async {
 if (_isJoining || _isActionProcessing) return;
 final auth = Provider.of<AuthProvider>(context, listen: false);
 if (!auth.isAuthenticated) {
 VSPFeedback.showError(context, AppLocalizations.of(context)!.loginToJoinError);
 return;
 }

 setState(() {
 _isJoining = true;
 _isActionProcessing = true;
 });
 final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
 final success = await bookingProvider.joinPublicMatch(widget.bookingId, auth.currentUser!.uid);
 
 if (mounted) {
 setState(() {
 _isJoining = false;
 _isActionProcessing = false;
 });
 if (success) {
 VSPFeedback.showSuccess(context, AppLocalizations.of(context)!.matchJoinSuccess);
 _fetchMatchDetails();
 } else {
 final errorMsg = bookingProvider.errorMessage ?? '';
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';
 if (errorMsg == 'time_conflict') {
 VSPFeedback.showError(
 context,
 isArabic 
 ? 'لديك حجز متداخل أو مباراة أخرى في نفس هذا الوقت! ' 
 : 'You have a conflicting booking or match at this time! ',
 );
 } else if (errorMsg == 'match_is_full') {
 VSPFeedback.showError(
 context,
 isArabic 
 ? 'عذراً، هذه المباراة مكتملة العدد بالكامل! ' 
 : 'Sorry, this match is completely full! ',
 );
 } else if (errorMsg == 'already_joined') {
 VSPFeedback.showError(
 context,
 isArabic 
 ? 'لقد انضممت بالفعل لهذه المباراة!' 
 : 'You have already joined this match!',
 );
 } else {
 VSPFeedback.showError(
 context,
 errorMsg.isNotEmpty ? errorMsg : (isArabic ? 'فشل الانضمام للمباراة' : 'Failed to join match'),
 );
 }
 }
 }
 }

 void _onReport() {
 if (_isActionProcessing) return;
 final auth = Provider.of<AuthProvider>(context, listen: false);
 if (!auth.isAuthenticated) {
 VSPFeedback.showError(context, AppLocalizations.of(context)!.loginToJoinError);
 return;
 }

 String selectedReason = 'Spam';
 final Map<String, String> reasons = {
 'Spam': AppLocalizations.of(context)!.reportReasonSpam,
 'Inappropriate Content': AppLocalizations.of(context)!.reportReasonInappropriate,
 'Harassment': AppLocalizations.of(context)!.reportReasonHarassment,
 'Fake Match': AppLocalizations.of(context)!.reportReasonFake,
 'Other': AppLocalizations.of(context)!.reportReasonOther,
 };

 showDialog(
 context: context,
 builder: (context) => StatefulBuilder(
 builder: (context, setDialogState) => AlertDialog(
 backgroundColor: VSPColors.surface,
 title: Text(AppLocalizations.of(context)!.reportMatch, style: const TextStyle(color: Colors.white)),
 content: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Text(
 AppLocalizations.of(context)!.reportSubtitle,
 style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
 ),
 const SizedBox(height: 16),
 DropdownButton<String>(
 value: selectedReason,
 dropdownColor: VSPColors.surface,
 isExpanded: true,
 items: reasons.entries.map((entry) => DropdownMenuItem(
 value: entry.key,
 child: Text(entry.value, style: const TextStyle(color: Colors.white)),
 )).toList(),
 onChanged: (val) {
 if (val != null) setDialogState(() => selectedReason = val);
 },
 ),
 ],
 ),
 actionsPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.md),
 actions: [
 Row(
 children: [
 Expanded(
 child: PrimaryButton(
 text: AppLocalizations.of(context)!.cancel,
 height: 48,
 color: VSPColors.surfaceAlt,
 textColor: VSPColors.textPrimary,
 onPressed: () => Navigator.pop(context),
 ),
 ),
 const SizedBox(width: VSPSpacing.md),
 Expanded(
 child: PrimaryButton(
 text: AppLocalizations.of(context)!.report,
 height: 48,
 color: VSPColors.error,
 textColor: Colors.white,
 onPressed: () async {
 final success = await ReportRepository().reportEntity(
 reporterId: auth.currentUser!.uid,
 targetId: widget.bookingId,
 targetType: 'match',
 reason: selectedReason,
 );
 if (!context.mounted) return;
 Navigator.pop(context);
 if (success) {
 VSPFeedback.showSuccess(context, AppLocalizations.of(context)!.reportSubmitted);
 } else {
 VSPFeedback.showError(context, AppLocalizations.of(context)!.reportFailed);
 }
 },
 ),
 ),
 ],
 ),
 ],
 ),
 ),
 );
 }

 Future<void> _onLeaveMatch() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.currentUser?.uid;
    if (currentUserId == null || _isActionProcessing) return;

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
        title: Row(
          children: [
            const Icon(Iconsax.warning_2_copy, color: VSPColors.error, size: 22),
            const SizedBox(width: 8),
            Text(
              isArabic ? 'مغادرة المباراة' : 'Leave Match',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          isArabic
              ? 'هل أنت متأكد من رغبتك في مغادرة المباراة؟ سيتم إتاحة مكانك للاعبين آخرين.'
              : 'Are you sure you want to leave this match? Your spot will be made available to other players.',
          style: const TextStyle(color: VSPColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isArabic ? 'إلغاء' : 'Cancel', style: const TextStyle(color: VSPColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: VSPColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isArabic ? 'تأكيد المغادرة' : 'Leave'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isActionProcessing = true);
    try {
      final success = await MatchRepository().leavePublicMatch(widget.bookingId, currentUserId);
      if (mounted) {
        setState(() => _isActionProcessing = false);
        if (success) {
          VSPFeedback.showSuccess(
            context,
            isArabic ? 'تمت مغادرة المباراة بنجاح' : 'Successfully left the match',
          );
          _fetchMatchDetails();
        } else {
          VSPFeedback.showError(
            context,
            isArabic ? 'تعذر مغادرة المباراة، يرجى المحاولة مرة أخرى' : 'Failed to leave match',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActionProcessing = false);
        VSPFeedback.showError(context, '$e');
      }
    }
  }

  Widget _buildHostSettingsCard(BuildContext context) {
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';
 return Container(
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: VSPColors.accent.withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(VSPRadius.md),
 border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
 ),
 child: Row(
 children: [
 const Icon(Iconsax.star_copy, color: VSPColors.accent),
 const SizedBox(width: 12),
 Expanded(
 child: Text(
 isArabic 
 ? 'أنت مستضيف هذه المباراة يمكنك مشاركة رابط المباراة ودعوة أصدقائك لاكتمال الفريق.' 
 : 'You are the host of this match Share the link to invite friends and complete your squad.',
 style: const TextStyle(color: VSPColors.accent, fontSize: 13, fontWeight: FontWeight.bold),
 ),
 ),
 ],
 ),
 );
 }

 @override
 Widget build(BuildContext context) {
 final currentUserId = Provider.of<AuthProvider>(context, listen: false).currentUser?.uid;

 return StreamBuilder<List<Map<String, dynamic>>>(
 stream: _bookingStream,
 builder: (context, snapshot) {
 if (snapshot.hasData && snapshot.data!.isNotEmpty) {
 _booking = Booking.fromFirestore(snapshot.data!.first, widget.bookingId);
      if (_booking != null && _booking!.joinedUserIds.isNotEmpty) {
        final missing = _booking!.joinedUserIds.where((id) => !_joinedUserProfiles.containsKey(id)).toList();
        if (missing.isNotEmpty) {
          _loadJoinedUsers(missing);
        }
      }
 }

 if (_isLoading) {
 return const Scaffold(
 backgroundColor: VSPColors.background,
 body: Center(child: CircularProgressIndicator(color: VSPColors.accent)),
 );
 }

 if (_booking == null) {
 return Scaffold(
 backgroundColor: VSPColors.background,
 appBar: AppBar(backgroundColor: Colors.transparent),
 body: Center(
 child: Column(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 const Icon(Iconsax.warning_2_copy, color: VSPColors.error, size: 48),
 const SizedBox(height: 16),
 Text(AppLocalizations.of(context)!.matchNotFound, style: const TextStyle(color: Colors.white)),
 TextButton(
 onPressed: () => Navigator.pop(context),
 child: Text(AppLocalizations.of(context)!.goBack, style: const TextStyle(color: VSPColors.accent)),
 )
 ],
 ),
 ),
 );
 }

 final isHost = _booking!.createdByUserId == currentUserId;
 final isFull = _booking!.currentPlayers >= _booking!.maxPlayers || _booking!.joinedUserIds.length >= _booking!.maxPlayers;
 final alreadyJoined = _booking!.joinedUserIds.contains(currentUserId);

 return Scaffold(
 backgroundColor: VSPColors.background,
 body: CustomScrollView(
 slivers: [
 SliverAppBar(
 expandedHeight: 250,
 pinned: true,
 backgroundColor: VSPColors.background,
 actions: [
 IconButton(
 icon: const Icon(Iconsax.share_copy, color: Colors.white),
 onPressed: () {
 if (_booking != null) {
 final isAr = Localizations.localeOf(context).languageCode == 'ar';
 final msg = VSPMatchInviteFormatter.buildInviteMessage(
 stadiumName: _stadium?.name ?? 'ملعب VSP',
 bookingId: widget.bookingId,
 startTime: _booking!.startTime,
 endTime: _booking!.endTime,
 googleMapsUrl: _stadium?.googleMapsUrl,
 currentPlayers: _booking!.currentPlayers > _booking!.joinedUserIds.length ? _booking!.currentPlayers : _booking!.joinedUserIds.length,
 maxPlayers: _booking!.maxPlayers,
 totalPrice: _booking!.totalPrice,
 hostName: _booking!.hostName,
 isArabic: isAr,
 );
 SharingService.shareMatchFormatted(msg);
 }
 },
 ),
 if (alreadyJoined && !isHost)
              IconButton(
                icon: const Icon(Iconsax.logout_copy, color: VSPColors.error),
                tooltip: Localizations.localeOf(context).languageCode == 'ar' ? 'مغادرة المباراة' : 'Leave Match',
                onPressed: _onLeaveMatch,
              ),
            IconButton(
 icon: const Icon(Iconsax.warning_2_copy, color: VSPColors.textSecondary),
 onPressed: _onReport,
 ),
 const SizedBox(width: 8),
 ],
 flexibleSpace: FlexibleSpaceBar(
 background: _stadium != null
 ? CachedNetworkImage(
 imageUrl: _stadium!.imageUrl,
 fit: BoxFit.cover,
 )
 : Container(color: VSPColors.surface),
 ),
 ),
 SliverToBoxAdapter(
 child: Padding(
 padding: const EdgeInsets.all(VSPSpacing.lg),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Expanded(
 child: Text(
 AppLocalizations.of(context)!.publicMatchAt(_stadium?.name ?? "Stadium"),
 style: Theme.of(context).textTheme.headlineSmall?.copyWith(
 fontWeight: FontWeight.bold,
 color: VSPColors.textPrimary,
 ),
 ),
 ),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
 decoration: BoxDecoration(
 color: VSPColors.accent.withValues(alpha: 0.2),
 borderRadius: BorderRadius.circular(VSPRadius.xl),
 ),
 child: Text(
 AppLocalizations.of(context)!.vsMatchFormat('', ''),
 style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold),
 ),
 ),
 ],
 ),
 const SizedBox(height: VSPSpacing.md),
 _buildDetailRow(Iconsax.clock_copy, AppLocalizations.of(context)!.time, _booking!.formattedTimeRange),
 const SizedBox(height: VSPSpacing.sm),
 _buildDetailRow(Iconsax.calendar_1_copy, AppLocalizations.of(context)!.date, _booking!.formattedDate),
 const SizedBox(height: VSPSpacing.sm),
 _buildDetailRow(Iconsax.money_copy, AppLocalizations.of(context)!.price, '${_booking!.totalPrice.toInt()} EGP'),
 const SizedBox(height: VSPSpacing.md),
 
 // WhatsApp Group Share Button
 PrimaryButton(
 text: Localizations.localeOf(context).languageCode == 'ar' 
 ? 'دعوة أصحابك عبر جروب الواتساب ' 
 : 'Invite Friends via WhatsApp Group ',
 height: 48,
 color: VSPColors.whatsApp,
 textColor: Colors.white,
 onPressed: () async {
 final isAr = Localizations.localeOf(context).languageCode == 'ar';
 final msg = VSPMatchInviteFormatter.buildInviteMessage(
 stadiumName: _stadium?.name ?? 'ملعب VSP',
 bookingId: widget.bookingId,
 startTime: _booking!.startTime,
 endTime: _booking!.endTime,
 googleMapsUrl: _stadium?.googleMapsUrl,
 currentPlayers: _booking!.currentPlayers > _booking!.joinedUserIds.length ? _booking!.currentPlayers : _booking!.joinedUserIds.length,
 maxPlayers: _booking!.maxPlayers,
 totalPrice: _booking!.totalPrice,
 hostName: _booking!.hostName,
 isArabic: isAr,
 );
 await VSPMatchInviteFormatter.shareToWhatsApp(
 context: context,
 message: msg,
 );
 },
 ),
 const SizedBox(height: VSPSpacing.md),

 _buildDetailRow(Iconsax.location_copy, AppLocalizations.of(context)!.location, _stadium?.location ?? 'Unknown'),
 if (isHost) ...[
                    const SizedBox(height: 16),
                    _buildHostSettingsCard(context),
                  ] else if (alreadyJoined) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: VSPColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(VSPRadius.md),
                        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Iconsax.tick_circle_copy, color: VSPColors.accent),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              Localizations.localeOf(context).languageCode == 'ar'
                                  ? 'أنت منضم لهذه المباراة! استخدم زر المحادثة بالأسفل للتنسيق مع باقي اللاعبين.'
                                  : 'You are registered for this match! Use the chat button below to coordinate with the team.',
                              style: const TextStyle(color: VSPColors.accent, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
 const Divider(color: VSPColors.divider, height: 40),
 Text(
 AppLocalizations.of(context)!.playersCount(
 _booking!.currentPlayers > _booking!.joinedUserIds.length
 ? _booking!.currentPlayers
 : _booking!.joinedUserIds.length,
 _booking!.maxPlayers,
 ),
 style: Theme.of(context).textTheme.titleLarge,
 ),
 const SizedBox(height: VSPSpacing.md),
 ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _booking!.joinedUserIds.length,
                    itemBuilder: (context, index) {
                      final uid = _booking!.joinedUserIds[index];
                      final user = _joinedUserProfiles[uid];
                      final isUserHost = (uid == _booking!.createdByUserId && uid.isNotEmpty) || (index == 0 && _booking!.createdByUserId.isEmpty);
                      final displayName = user?.name?.isNotEmpty == true
                          ? user!.name!
                          : AppLocalizations.of(context)!.playerLabel(index + 1);

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: VSPColors.surface,
                          backgroundImage: (user?.profileImageUrl != null && user!.profileImageUrl!.isNotEmpty)
                              ? CachedNetworkImageProvider(user.profileImageUrl!)
                              : null,
                          child: (user?.profileImageUrl == null || user!.profileImageUrl!.isEmpty)
                              ? const Icon(Iconsax.user_copy, color: VSPColors.textSecondary, size: 20)
                              : null,
                        ),
                        title: Text(
                          displayName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        subtitle: user?.position != null
                            ? Text(user!.position!, style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12))
                            : null,
                        trailing: isUserHost
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: VSPColors.accent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(VSPRadius.full),
                                  border: Border.all(color: VSPColors.accent.withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  AppLocalizations.of(context)!.host,
                                  style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              )
                            : null,
                      );
                    },
 ),
 const SizedBox(height: 24),
 ],
 ),
 ),
 ),
 ],
 ),
 bottomSheet: Container(
        padding: const EdgeInsets.all(VSPSpacing.lg),
        color: VSPColors.background,
        child: (alreadyJoined || isHost)
            ? PrimaryButton(
                text: Localizations.localeOf(context).languageCode == 'ar'
                    ? '💬 محادثة وتنسيق المباراة'
                    : '💬 Match Chat & Coordination',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(booking: _booking!),
                    ),
                  );
                },
                color: VSPColors.accent,
                textColor: VSPColors.background,
              )
            : PrimaryButton(
                text: isFull
                    ? AppLocalizations.of(context)!.matchFull
                    : AppLocalizations.of(context)!.join,
                onPressed: isFull ? null : _onJoin,
                isLoading: _isJoining,
              ),
      ),
 );
 },
 );
 }

 Widget _buildDetailRow(IconData icon, String label, String value) {
 return Row(
 children: [
 Icon(icon, color: VSPColors.accent, size: 20),
 const SizedBox(width: 12),
 Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(label, style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12)),
 Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
 ],
 ),
 ],
 );
 }
}
