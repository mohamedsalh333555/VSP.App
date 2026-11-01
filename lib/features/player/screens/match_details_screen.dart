import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/ui/vsp_ui.dart';
import '../../../data/models.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/providers/stadium_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/vsp_error_state.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../core/services/sharing_service.dart';
import '../../../core/repositories/report_repository.dart';
import '../../../core/repositories/chat_repository.dart';
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
 bool _hasLoadError = false;
 Booking? _booking;
 Stadium? _stadium;
 bool _isJoining = false;
  bool _isActionProcessing = false;
  bool _isReportingOwnerIssue = false;
  final Map<String, UserModel> _joinedUserProfiles = {};
  late Stream<Booking?> _bookingStream;

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
 _bookingStream = MatchRepository().streamPublicMatchDetails(widget.bookingId);
    _fetchMatchDetails();
 }

 Future<void> _fetchMatchDetails() async {
 if (!mounted) return;
 setState(() {
   _isLoading = true;
   _hasLoadError = false;
 });
 try {
 final stadiumProvider = Provider.of<StadiumProvider>(context, listen: false);

 final booking = await MatchRepository().getPublicMatchDetails(widget.bookingId) ??
     await MatchRepository().getPrivateCollectiveMatchDetails(widget.bookingId);
 if (booking != null) {
 _booking = booking;
        _stadium = await stadiumProvider.getStadiumById(booking.stadiumId);
        if (booking.joinedUserIds.isNotEmpty) {
          _loadJoinedUsers(booking.joinedUserIds);
        }
 }
 } catch (e, stackTrace) {
 debugPrint('Error fetching match details: $e');
 debugPrintStack(stackTrace: stackTrace);
 if (mounted) setState(() => _hasLoadError = true);
 } finally {
 if (mounted) setState(() => _isLoading = false);
 }
 }

 void _retryMatchDetails() {
   _bookingStream = MatchRepository().streamPublicMatchDetails(widget.bookingId);
   _fetchMatchDetails();
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
 if (_booking?.isOpenJoin == true) {
   if (mounted) {
     setState(() {
       _isJoining = false;
       _isActionProcessing = false;
     });
   }
   VSPFeedback.showInfo(context, Localizations.localeOf(context).languageCode == 'ar' ? 'هذه تجميعية خاصة. استخدم رابط الدعوة للانضمام.' : 'This is a private collective match. Use the invitation link to join.');
   return;
 }

 final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
 final success = await bookingProvider.joinPublicMatch(widget.bookingId, auth.currentUser!.id);
 
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
 isArabic ? 'تعذر الانضمام للمباراة. حاول مرة أخرى.' : 'Could not join the match. Please try again.',
 );
 }
 }
 }
 }

 Future<void> _openOwnerChat() async {
   final booking = _booking;
   final auth = Provider.of<AuthProvider>(context, listen: false);
   final currentUserId = auth.currentUser?.id;
   final ownerId = booking?.ownerId;
   if (booking == null || currentUserId == null || ownerId == null || ownerId.isEmpty) {
     VSPFeedback.showError(
       context,
       Localizations.localeOf(context).languageCode == 'ar'
           ? 'لا يوجد مالك مؤهل للمحادثة لهذا الحجز.'
           : 'No eligible stadium owner is available for this booking.',
     );
     return;
   }
   try {
     final chat = await ChatRepository().getOrCreateDirectChat(
       otherUserId: ownerId,
       isArabic: Localizations.localeOf(context).languageCode == 'ar',
       contextType: 'match',
       contextId: booking.id,
     );
     final conversationId = chat['id']?.toString();
     if (!mounted || conversationId == null || conversationId.isEmpty) return;
     Navigator.push(
       context,
       MaterialPageRoute(
         builder: (_) => ChatScreen(
           booking: booking,
           conversationId: conversationId,
           otherUserId: ownerId,
           reportContextType: 'match',
           reportContextId: booking.id,
           reportBookingId: booking.id,
         ),
       ),
     );
   } catch (_) {
     if (mounted) {
       VSPFeedback.showError(
         context,
         Localizations.localeOf(context).languageCode == 'ar'
             ? 'تعذر فتح محادثة مالك الملعب.'
             : 'Could not open the stadium owner chat.',
       );
     }
   }
 }

 Future<void> _reportOwnerIssue() async {
   if (_isReportingOwnerIssue) return;
   final booking = _booking;
   final ownerId = booking?.ownerId;
   if (booking == null || ownerId == null || ownerId.isEmpty) return;

   final ar = Localizations.localeOf(context).languageCode == 'ar';
   final reasonController = TextEditingController();
   final detailsController = TextEditingController();

   final submitted = await showDialog<bool>(
     context: context,
     builder: (dlgCtx) => AlertDialog(
       scrollable: true,
       backgroundColor: VSPColors.surface,
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.dialog)),
       title: Text(
         ar ? 'إبلاغ عن مشكلة بالملعب/المالك' : 'Report Stadium/Owner Issue',
         style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
       ),
       content: Column(
         mainAxisSize: MainAxisSize.min,
         children: [
           Text(
             ar
                 ? 'سيتم ربط البلاغ بهذا الحجز ومراجعته إداريًا. لن يتم حظر الطرف الآخر تلقائيًا.'
                 : 'The report will be linked to this booking for administrative review. The other party will not be auto-blocked.',
             style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
           ),
           const SizedBox(height: VSPSpacing.md),
           TextField(
             controller: reasonController,
             decoration: InputDecoration(
               hintText: ar ? 'سبب البلاغ' : 'Reason',
             ),
           ),
           const SizedBox(height: VSPSpacing.sm),
           TextField(
             controller: detailsController,
             maxLines: 3,
             decoration: InputDecoration(
               hintText: ar ? 'تفاصيل إضافية (اختياري)' : 'Additional details (optional)',
             ),
           ),
         ],
       ),
       actions: [
         TextButton(
           onPressed: () => Navigator.pop(dlgCtx, false),
           child: Text(ar ? 'إلغاء' : 'Cancel'),
         ),
         ElevatedButton(
           onPressed: () => Navigator.pop(dlgCtx, reasonController.text.trim().isNotEmpty),
           style: ElevatedButton.styleFrom(
             backgroundColor: VSPColors.error,
             foregroundColor: Colors.white,
           ),
           child: Text(ar ? 'إرسال البلاغ' : 'Submit Report'),
         ),
       ],
     ),
   );

   final reason = reasonController.text.trim();
   final details = detailsController.text.trim();
   reasonController.dispose();
   detailsController.dispose();

   if (submitted != true || reason.isEmpty || !mounted) return;

   final currentUserId = Provider.of<AuthProvider>(context, listen: false).currentUser?.id;
   if (currentUserId == null) return;

   if (!mounted) return;
   setState(() => _isReportingOwnerIssue = true);
   var ok = false;
   try {
     ok = await ReportRepository().reportEntity(
       reporterId: currentUserId,
       targetId: ownerId,
       targetType: 'user',
       reason: reason,
       details: details.isEmpty ? null : details,
       contextType: 'booking',
       contextId: booking.id,
       bookingId: booking.id,
     );
   } catch (error, stackTrace) {
     debugPrint('Error submitting booking owner report: $error');
     debugPrintStack(stackTrace: stackTrace);
   } finally {
     if (mounted) setState(() => _isReportingOwnerIssue = false);
   }

   if (mounted) {
     if (ok) {
       VSPFeedback.showSuccess(
         context,
         ar ? 'تم إرسال البلاغ للمراجعة الإدارية.' : 'Report submitted for administrative review.',
       );
     } else {
       VSPFeedback.showError(
         context,
         ar ? 'تعذر إرسال البلاغ. حاول مرة أخرى.' : 'Could not submit the report. Please try again.',
       );
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

 final reporterId = auth.currentUser?.id;
 if (reporterId == null) {
   VSPFeedback.showError(context, AppLocalizations.of(context)!.loginToJoinError);
   return;
 }
 bool isSubmittingReport = false;
 final pageContext = context;
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
 scrollable: true,
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
 onPressed: isSubmittingReport ? null : () => Navigator.pop(context),
 ),
 ),
 const SizedBox(width: VSPSpacing.md),
 Expanded(
 child: PrimaryButton(
 text: AppLocalizations.of(context)!.report,
 height: 48,
 isLoading: isSubmittingReport,
 color: VSPColors.error,
 textColor: Colors.white,
 onPressed: isSubmittingReport ? null : () async {
 setDialogState(() => isSubmittingReport = true);
 try {
   final success = await ReportRepository().reportEntity(
     reporterId: reporterId,
     targetId: widget.bookingId,
     targetType: 'match',
     reason: selectedReason,
     contextType: 'match',
     contextId: widget.bookingId,
     bookingId: widget.bookingId,
   );
   if (!context.mounted) return;
   Navigator.pop(context);
   if (!pageContext.mounted) return;
   if (success) {
     VSPFeedback.showSuccess(pageContext, AppLocalizations.of(pageContext)!.reportSubmitted);
   } else {
     VSPFeedback.showError(pageContext, AppLocalizations.of(pageContext)!.reportFailed);
   }
 } catch (_) {
   if (!context.mounted) return;
   setDialogState(() => isSubmittingReport = false);
   if (pageContext.mounted) {
     VSPFeedback.showError(pageContext, AppLocalizations.of(pageContext)!.reportFailed);
   }
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
    final currentUserId = auth.currentUser?.id;
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
      final success = _booking?.isOpenJoin == true
         ? await MatchRepository().leavePrivateCollectiveMatch(widget.bookingId, currentUserId)
         : await MatchRepository().leavePublicMatch(widget.bookingId, currentUserId);
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
        VSPFeedback.showError(
          context,
          isArabic ? 'تعذر مغادرة المباراة. حاول مرة أخرى.' : 'Could not leave the match. Please try again.',
        );
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
 final currentUserId = Provider.of<AuthProvider>(context, listen: false).currentUser?.id;
 final isAr = Localizations.localeOf(context).languageCode == 'ar';

 return StreamBuilder<Booking?>(
 stream: _bookingStream,
 builder: (context, snapshot) {
 if (snapshot.hasData && snapshot.data != null) {
 _booking = snapshot.data;
      if (_booking != null && _booking!.joinedUserIds.isNotEmpty) {
        final missing = _booking!.joinedUserIds.where((id) => !_joinedUserProfiles.containsKey(id)).toList();
        if (missing.isNotEmpty) {
          _loadJoinedUsers(missing);
        }
      }
 }

 if (_isLoading) {
 return const VSPScaffold(
 backgroundColor: VSPColors.background,
 body: SafeArea(
   child: Center(
     child: CircularProgressIndicator(color: VSPColors.accent),
   ),
 ),
 );
 }

 if (_booking == null && _hasLoadError) {
 return VSPScaffold(
 backgroundColor: VSPColors.background,
 appBar: AppBar(backgroundColor: Colors.transparent),
 body: SafeArea(
   child: VSPErrorState(
     customMessage: isAr
         ? 'تعذر تحميل تفاصيل المباراة. تحقق من الاتصال ثم أعد المحاولة.'
         : 'Could not load match details. Check your connection and try again.',
     retryButtonText: isAr ? 'إعادة المحاولة' : 'Retry',
     onRetry: _retryMatchDetails,
   ),
 ),
 );
 }

 if (_booking == null) {
 return VSPScaffold(
 backgroundColor: VSPColors.background,
 appBar: AppBar(backgroundColor: Colors.transparent),
 body: SafeArea(
   child: Center(
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
 ),
 );
 }

 final isHost = _booking!.createdByUserId == currentUserId;
 final isFull = _booking!.currentPlayers >= _booking!.maxPlayers || _booking!.joinedUserIds.length >= _booking!.maxPlayers;
 final alreadyJoined = _booking!.joinedUserIds.contains(currentUserId);

 String statusLabel;
 Color statusColor;
 IconData statusIcon;
 switch (_booking!.status) {
 case BookingStatus.pending:
 statusLabel = isAr ? 'قيد الإنشاء' : 'Pending';
 statusColor = VSPColors.warning;
 statusIcon = Icons.hourglass_top_rounded;
 break;
 case BookingStatus.confirmed:
 statusLabel = isAr ? 'مؤكدة' : 'Confirmed';
 statusColor = VSPColors.accent;
 statusIcon = Iconsax.verify_copy;
 break;
 case BookingStatus.upcoming:
 statusLabel = isAr ? 'قادمة' : 'Upcoming';
 statusColor = VSPColors.accent;
 statusIcon = Iconsax.clock_copy;
 break;
 case BookingStatus.completed:
 statusLabel = isAr ? 'مكتملة' : 'Completed';
 statusColor = VSPColors.textSecondary;
 statusIcon = Iconsax.tick_circle_copy;
 break;
 case BookingStatus.noShow:
 statusLabel = isAr ? 'لم يحضر' : 'No-show';
 statusColor = VSPColors.error;
 statusIcon = Iconsax.close_circle_copy;
 break;
 case BookingStatus.cancelled:
 statusLabel = isAr ? 'ملغاة' : 'Cancelled';
 statusColor = VSPColors.error;
 statusIcon = Iconsax.close_circle_copy;
 break;
 case BookingStatus.expired:
 statusLabel = isAr ? 'منتهية' : 'Expired';
 statusColor = VSPColors.textSecondary;
 statusIcon = Icons.timer_off_outlined;
 break;
 }

 return VSPScaffold(
 backgroundColor: VSPColors.background,
 body: CustomScrollView(
 slivers: [
 SliverAppBar(
 expandedHeight: 250,
 pinned: true,
 backgroundColor: VSPColors.background,
 actions: [
 if (_booking?.isOpenJoin != true || isHost)
 IconButton(
 icon: const Icon(Iconsax.share_copy, color: Colors.white),
 onPressed: () async {
 if (_booking == null) return;
 final isAr = Localizations.localeOf(context).languageCode == 'ar';
 if (_booking!.isOpenJoin) {
   if (!isHost) return;
   final credentials = await MatchRepository().getCollectiveInviteCredentials(widget.bookingId);
   final token = credentials?['invite_token']?.toString();
   final code = credentials?['invite_code']?.toString();
   if (!context.mounted) return;
   if (token == null || code == null || token.isEmpty || code.isEmpty || credentials?['active'] != true) {
     VSPFeedback.showInfo(context, isAr ? 'يمكن مشاركة الدعوة بعد تأكيد الحجز.' : 'The invite can be shared after confirmation.');
     return;
   }
   await SharingService.shareCollectiveInvite(
     inviteToken: token,
     inviteCode: code,
     stadiumName: _booking!.stadiumName,
     date: '${_booking!.formattedDate} - ${_booking!.formattedTimeRange}',
     hostName: _booking!.hostName ?? (isAr ? 'المنشئ' : 'Host'),
   );
   return;
 }
 final msg = VSPMatchInviteFormatter.buildInviteMessage(
   stadiumName: _stadium?.name ?? 'ملعب VSP',
   bookingId: widget.bookingId,
   startTime: _booking!.startTime,
   endTime: _booking!.endTime,
   googleMapsUrl: _stadium?.googleMapsUrl,
   currentPlayers: _booking!.currentPlayers,
   maxPlayers: _booking!.maxPlayers,
   totalPrice: _booking!.totalPrice,
   hostName: _booking!.hostName,
   isArabic: isAr,
   isCollective: false,
 );
 await SharingService.shareMatchFormatted(msg);
 },
 ),
 if (alreadyJoined || isHost)
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
 if (snapshot.hasError && _booking != null)
   SliverToBoxAdapter(
     child: Padding(
       padding: const EdgeInsets.fromLTRB(VSPSpacing.md, VSPSpacing.sm, VSPSpacing.md, 0),
       child: Container(
         padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.sm),
         decoration: BoxDecoration(
           color: VSPColors.warning.withValues(alpha: 0.10),
           borderRadius: BorderRadius.circular(VSPRadius.md),
           border: Border.all(color: VSPColors.warning.withValues(alpha: 0.30)),
         ),
         child: Row(
           children: [
             const Icon(Iconsax.warning_2_copy, color: VSPColors.warning, size: 18),
             const SizedBox(width: VSPSpacing.sm),
             Expanded(
               child: Text(
                 isAr
                     ? 'توقفت التحديثات المباشرة للمباراة. قد تكون البيانات المعروضة قديمة.'
                     : 'Live match updates paused. Displayed details may be out of date.',
                 style: const TextStyle(color: VSPColors.warning, fontSize: 11.5),
               ),
             ),
             TextButton(
               onPressed: _retryMatchDetails,
               child: Text(isAr ? 'إعادة المحاولة' : 'Retry'),
             ),
           ],
         ),
       ),
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
 _booking!.isChallenge
     ? (isAr ? 'مباراة تحدي في ${_stadium?.name ?? "الملعب"}' : 'Challenge Match at ${_stadium?.name ?? "Stadium"}')
     : (_booking!.isOpenJoin
         ? (isAr ? 'تجميعية في \${_stadium?.name ?? "الملعب"}' : 'Collective match at \${_stadium?.name ?? "Stadium"}')
         : (isAr ? 'حجز ملعب ${_stadium?.name ?? ""}' : 'Pitch Booking at ${_stadium?.name ?? ""}')),
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
 _booking!.isChallenge
     ? (isAr ? 'تحدي فرق' : 'Challenge')
     : (_booking!.isOpenJoin ? (isAr ? 'خاص' : 'Private') : (isAr ? 'حجز خاص' : 'Personal')),
 style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold),
 ),
 ),
 ],
 ),
 const SizedBox(height: VSPSpacing.sm),
 VSPStatusPill(
 label: statusLabel,
 color: statusColor,
 icon: statusIcon,
 ),
 if (_booking!.isChallenge) ...[
   const SizedBox(height: VSPSpacing.md),
   Container(
     padding: const EdgeInsets.all(16),
     decoration: BoxDecoration(
       color: VSPColors.surface,
       borderRadius: BorderRadius.circular(VSPRadius.lg),
       border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
     ),
     child: Row(
       children: [
         Expanded(
           child: Column(
             children: [
               CircleAvatar(
                 radius: 24,
                 backgroundColor: VSPColors.background,
                 backgroundImage: (_booking!.playerTeamLogoUrl != null && _booking!.playerTeamLogoUrl!.isNotEmpty)
                     ? CachedNetworkImageProvider(_booking!.playerTeamLogoUrl!)
                     : null,
                 child: (_booking!.playerTeamLogoUrl == null || _booking!.playerTeamLogoUrl!.isEmpty)
                     ? const Icon(Iconsax.shield_tick_copy, color: VSPColors.accent)
                     : null,
               ),
               const SizedBox(height: 8),
               Text(
                 _booking!.playerTeamName ?? (isAr ? 'فريقنا' : 'Our Team'),
                 style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                 textAlign: TextAlign.center,
                 maxLines: 1,
                 overflow: TextOverflow.ellipsis,
               ),
             ],
           ),
         ),
         Container(
           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
           decoration: BoxDecoration(
             color: VSPColors.accent.withValues(alpha: 0.15),
             shape: BoxShape.circle,
           ),
           child: const Text(
             'VS',
             style: TextStyle(color: VSPColors.accent, fontWeight: FontWeight.w900, fontSize: 14),
           ),
         ),
         Expanded(
           child: Column(
             children: [
               CircleAvatar(
                 radius: 24,
                 backgroundColor: VSPColors.background,
                 backgroundImage: (_booking!.opponentTeamLogoUrl != null && _booking!.opponentTeamLogoUrl!.isNotEmpty)
                     ? CachedNetworkImageProvider(_booking!.opponentTeamLogoUrl!)
                     : null,
               child: (_booking!.opponentTeamLogoUrl == null || _booking!.opponentTeamLogoUrl!.isEmpty)
                   ? const Icon(Iconsax.shield_tick_copy, color: VSPColors.textSecondary)
                   : null,
               ),
               const SizedBox(height: 8),
               Text(
                 _booking!.opponentTeamName ?? (isAr ? 'الخصم' : 'Opponent'),
                 style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                 textAlign: TextAlign.center,
                 maxLines: 1,
                 overflow: TextOverflow.ellipsis,
               ),
             ],
           ),
         ),
       ],
     ),
   ),
 ],
 const SizedBox(height: VSPSpacing.md),
 _buildDetailRow(Iconsax.clock_copy, AppLocalizations.of(context)!.time, _booking!.formattedTimeRange),
 const SizedBox(height: VSPSpacing.sm),
 _buildDetailRow(Iconsax.calendar_1_copy, AppLocalizations.of(context)!.date, _booking!.formattedDate),
 const SizedBox(height: VSPSpacing.sm),
 _buildDetailRow(Iconsax.money_copy, AppLocalizations.of(context)!.price, '${_booking!.totalPrice.toInt()} EGP'),
 const SizedBox(height: VSPSpacing.md),
 
 // Private collective invitations use the dedicated VSP invite sheet.
 if (!_booking!.isOpenJoin)
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
 currentPlayers: _booking!.currentPlayers,
 maxPlayers: _booking!.maxPlayers,
 totalPrice: _booking!.totalPrice,
 hostName: _booking!.hostName,
 isCollective: _booking!.isOpenJoin,
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
 if (_booking!.isOpenJoin) ...[
 const Divider(color: VSPColors.divider, height: 40),
 Text(
 AppLocalizations.of(context)!.playersCount(
 _booking!.currentPlayers,
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
 ],
 ),
 ),
 ),
 ],
 ),
 bottomSheet: Container(
        padding: const EdgeInsets.all(VSPSpacing.lg),
        color: VSPColors.background,
        child: isHost
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      text: isAr
                          ? 'التواصل مع مالك الملعب'
                          : 'Chat with Stadium Owner',
                      onPressed: _openOwnerChat,
                      color: VSPColors.accent,
                      textColor: VSPColors.background,
                    ),
                  ),
                  const SizedBox(height: VSPSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _reportOwnerIssue,
                      icon: const Icon(Iconsax.flag_copy, color: VSPColors.warning),
                      label: Text(
                        isAr ? 'الإبلاغ عن مشكلة بالملعب/المالك' : 'Report Stadium/Owner Issue',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: VSPColors.warning,
                        side: const BorderSide(color: VSPColors.warning),
                      ),
                    ),
                  ),
                ],
              )
            : alreadyJoined
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: PrimaryButton(
                              text: isAr ? 'مراسلة المالك' : 'Chat with Owner',
                              onPressed: _openOwnerChat,
                              color: VSPColors.accent,
                              textColor: VSPColors.background,
                            ),
                          ),
                          const SizedBox(width: VSPSpacing.sm),
                          Expanded(
                            child: PrimaryButton(
                              text: isAr ? 'خروج' : 'Leave',
                              onPressed: _isActionProcessing ? null : _onLeaveMatch,
                              isLoading: _isActionProcessing,
                              color: VSPColors.surfaceAlt,
                              textColor: VSPColors.error,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: VSPSpacing.sm),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _reportOwnerIssue,
                          icon: const Icon(Iconsax.flag_copy, color: VSPColors.warning),
                          label: Text(
                            isAr ? 'الإبلاغ عن مشكلة بالملعب/المالك' : 'Report Stadium/Owner Issue',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: VSPColors.warning,
                            side: const BorderSide(color: VSPColors.warning),
                          ),
                        ),
                      ),
                    ],
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
