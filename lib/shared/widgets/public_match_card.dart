import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../core/providers/auth_provider.dart' as app_auth;
import '../../core/repositories/match_repository.dart';
import '../../core/services/sharing_service.dart';
import '../../core/ui/tokens/vsp_tokens.dart';
import '../../core/utils/vsp_feedback.dart';
import '../../data/models.dart';
import 'match_card/manage_participants_modal.dart';
import 'match_card/public_match_card_formatter.dart';


class PublicMatchCard extends StatefulWidget {
 final Booking booking;
 final bool highlighted;

 const PublicMatchCard({super.key, required this.booking, this.highlighted = false});

 @override
 State<PublicMatchCard> createState() => _PublicMatchCardState();
}

class _PublicMatchCardState extends State<PublicMatchCard> {
 bool _isLoading = false;

 void _rejectRequest(BuildContext context, String? userId) async {
 if (userId == null) return;
 setState(() => _isLoading = true);
 try {
 await MatchRepository().rejectJoinRequest(widget.booking.id, userId);
 } catch (e) {
 if (!mounted) return;
 VSPFeedback.showError(this.context, e.toString());
 } finally {
 if (mounted) {
 setState(() => _isLoading = false);
 }
 }
 }

 void _handleShare(Booking booking) {
 SharingService.shareMatch(
 bookingId: booking.id,
 teamName: booking.playerTeamName ?? booking.hostName ?? AppLocalizations.of(context)!.vspTeam,
 stadiumName: booking.stadiumName,
 date: '${booking.formattedDate} at ${booking.formattedTimeRange}',
 );
 }

 void _handleJoin(BuildContext context, String? userId) async {
 if (userId == null) {
 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.loginFirst)));
 return;
 }
 setState(() => _isLoading = true);
 try {
 final success = await MatchRepository().joinPublicMatch(widget.booking.id, userId);
 if (!context.mounted) return;
 if (success) {
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';
 VSPFeedback.showSuccess(context, isArabic ? 'تم انضمامك للمباراة وتأكيد مكانك بنجاح.' : 'Joined match successfully.');
 } else {
 VSPFeedback.showError(context, AppLocalizations.of(context)!.joinFailed);
 }
 } catch (e) {
 if (context.mounted) {
 VSPFeedback.showError(context, e.toString());
 }
 } finally {
 if (mounted) {
 setState(() => _isLoading = false);
 }
 }
 }

 void _handleLeave(BuildContext context, String? userId) async {
 if (userId == null) return;
 setState(() => _isLoading = true);
 try {
 final success = await MatchRepository().leavePublicMatch(widget.booking.id, userId);
 if (!context.mounted) return;
 if (success) {
 VSPFeedback.showSuccess(context, AppLocalizations.of(context)!.leaveSuccess);
 } else {
 VSPFeedback.showError(context, AppLocalizations.of(context)!.leaveFailed);
 }
 } catch (e) {
 if (context.mounted) {
 VSPFeedback.showError(context, e.toString());
 }
 } finally {
 if (mounted) {
 setState(() => _isLoading = false);
 }
 }
 }

 void _manageParticipants(BuildContext context) {
    ManageParticipantsModal.show(context, booking: widget.booking);
  }

 Widget _buildTypeBadge(String text) {
 return Text(
 text,
 style: const TextStyle(
 color: Colors.white,
 fontSize: 13,
 fontWeight: FontWeight.bold,
 ),
 );
 }

 Widget _buildStatusBadge(String text, Color color) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
 decoration: BoxDecoration(
 color: color.withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(VSPRadius.full),
 border: Border.all(color: color.withValues(alpha: 0.4)),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
 const SizedBox(width: 6),
 Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
 ],
 ),
 );
 }

 Widget _buildCompactInfo(IconData? icon, String headerTitle, String value) {
 return Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 Text(
 headerTitle,
 style: TextStyle(
 color: Colors.white.withValues(alpha: 0.5),
 fontSize: 9.5,
 fontWeight: FontWeight.w600,
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 const SizedBox(height: 3),
 Flexible(
 child: Directionality(
 textDirection: TextDirection.ltr,
 child: Text(
 value,
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
 ),
 ),
 ),
 ],
 );
 }

 Widget _buildDivider() => Container(width: 1, height: 22, color: Colors.white10);

 Widget _buildRawButton({required String label, required Color color, required VoidCallback? onTap, bool isOutlined = false}) {
 return AbsorbPointer(
 absorbing: _isLoading,
 child: GestureDetector(
 onTap: _isLoading ? null : onTap,
 child: Container(
 height: 42.0,
 padding: const EdgeInsets.symmetric(horizontal: 16),
 decoration: BoxDecoration(
 color: isOutlined ? Colors.transparent : color,
 borderRadius: BorderRadius.circular(VSPRadius.sm),
 border: isOutlined ? Border.all(color: color, width: 1.5) : null,
 boxShadow: isOutlined ? null : [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
 ),
 child: Center(
 child: _isLoading 
 ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)) 
 : Text(label, style: TextStyle(color: isOutlined ? color : Colors.black, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
 ),
 ),
 ),
 );
 }

 Widget _buildSpotsIndicator(int remaining, int current, int total) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.baseline,
 textBaseline: TextBaseline.alphabetic,
 children: [
 Text("$remaining", style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.w900, fontSize: 20)),
 const SizedBox(width: 4),
 Text(AppLocalizations.of(context)!.spotsLeft.toUpperCase(), style: const TextStyle(color: VSPColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 10)),
 ],
 ),
 Text(AppLocalizations.of(context)!.playersJoined(current, total), style: TextStyle(color: VSPColors.textSecondary.withValues(alpha: 0.6), fontSize: 10, fontWeight: FontWeight.w500)),
 ],
 );
 }

 @override
 Widget build(BuildContext context) {
    final currentUser = context.select((app_auth.AuthProvider a) => a.currentUser);
    final booking = widget.booking;
    
    final bool hasJoined = currentUser != null && booking.joinedUserIds.contains(currentUser.uid);
    final bool isPending = currentUser != null && booking.pendingUserIds.contains(currentUser.uid);
    final bool isHost = currentUser != null && booking.createdByUserId == currentUser.uid;
    
    final totalFieldCapacity = booking.totalFieldCapacity;
    final remainingPlayers = PublicMatchCardFormatter.calculateRemainingSpots(
      totalCapacity: totalFieldCapacity,
      currentPlayers: booking.currentPlayers,
    );
    final entryFee = PublicMatchCardFormatter.calculateEntryFee(
      totalPrice: booking.totalPrice,
      totalCapacity: totalFieldCapacity,
    );
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return RepaintBoundary(
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VSPColors.surface, 
        borderRadius: BorderRadius.circular(VSPRadius.xl),
        border: Border.all(color: widget.highlighted ? VSPColors.accent : Colors.white.withValues(alpha: 0.08), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 _buildTypeBadge(PublicMatchCardFormatter.getLocalizedBookingType(booking.bookingType, isArabic: isArabic)),
  if (isHost)
  _buildStatusBadge(AppLocalizations.of(context)!.myMatch, VSPColors.accent)
  else if (hasJoined)
  _buildStatusBadge(AppLocalizations.of(context)!.joined, VSPColors.info)
  else if (isPending)
  _buildStatusBadge(isArabic ? 'طلب معلق ' : 'Pending ', VSPColors.warning)
  else if (booking.currentPlayers >= totalFieldCapacity)
  _buildStatusBadge(AppLocalizations.of(context)!.full, VSPColors.textSecondary)
  else
  _buildStatusBadge(AppLocalizations.of(context)!.open, VSPColors.success),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Container(
 width: 48, height: 48,
 decoration: BoxDecoration(color: VSPColors.surfaceAlt, shape: BoxShape.circle, border: Border.all(color: VSPColors.divider, width: 1)),
 child: ClipOval(
 child: (booking.hostAvatarUrl != null && booking.hostAvatarUrl!.isNotEmpty)
 ? CachedNetworkImage(imageUrl: booking.hostAvatarUrl!, memCacheWidth: 200, memCacheHeight: 200, fit: BoxFit.cover, errorWidget: (_, __, ___) => const Icon(Iconsax.user_copy, color: VSPColors.accent, size: 20), placeholder: (_, __) => Container(color: VSPColors.surfaceAlt))
 : (booking.playerTeamLogoUrl != null && booking.playerTeamLogoUrl!.isNotEmpty)
 ? CachedNetworkImage(imageUrl: booking.playerTeamLogoUrl!, memCacheWidth: 200, memCacheHeight: 200, fit: BoxFit.cover, errorWidget: (_, __, ___) => const Icon(Iconsax.user_copy, color: VSPColors.accent, size: 20), placeholder: (_, __) => Container(color: VSPColors.surfaceAlt))
 : const Icon(Iconsax.user_copy, color: VSPColors.accent, size: 20),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(booking.hostName ?? booking.playerTeamName ?? AppLocalizations.of(context)!.host, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 0.5), maxLines: 1, overflow: TextOverflow.ellipsis),
 Text(booking.stadiumName, style: const TextStyle(color: VSPColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
 ],
 ),
 ),
 IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Iconsax.share_copy, color: VSPColors.textSecondary, size: 18), onPressed: () => _handleShare(booking)),
 ],
 ),
 const SizedBox(height: 12),
 Container(
 padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
 decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(VSPRadius.md)),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.spaceAround,
 children: [
 Expanded(child: Center(child: _buildCompactInfo(Iconsax.calendar_1_copy, isArabic ? 'التاريخ' : 'DATE', booking.formattedDate))),
 _buildDivider(),
 Expanded(child: Center(child: _buildCompactInfo(Iconsax.clock_copy, isArabic ? 'الوقت' : 'TIME', PublicMatchCardFormatter.formatTimeShort(booking.formattedTimeRange)))),
 _buildDivider(),
 Expanded(child: Center(child: _buildCompactInfo(Iconsax.wallet_1_copy, isArabic ? 'رسوم الفرد' : 'PER PLAYER', "$entryFee ${AppLocalizations.of(context)!.egCurrency}"))),
 ],
 ),
 ),
 const SizedBox(height: 12),
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Expanded(
 child: _buildSpotsIndicator(remainingPlayers, booking.currentPlayers, totalFieldCapacity),
 ),
 const SizedBox(width: 12),
 Builder(builder: (context) {
 if (_isLoading) return const SizedBox(width: 100, height: 44, child: Center(child: CircularProgressIndicator(color: VSPColors.accent, strokeWidth: 2)));
 if (isHost) return _buildRawButton(label: AppLocalizations.of(context)!.manage, color: VSPColors.accent, onTap: () => _manageParticipants(context), isOutlined: false);
 if (hasJoined) return _buildRawButton(label: AppLocalizations.of(context)!.leave, color: VSPColors.error, onTap: () => _handleLeave(context, currentUser.uid), isOutlined: true);
 if (isPending) {
 return _buildRawButton(label: isArabic ? 'إلغاء الطلب' : 'Cancel Request', color: VSPColors.error, onTap: () => _rejectRequest(context, currentUser.uid), isOutlined: true);
 }
                  if (booking.currentPlayers >= totalFieldCapacity) return _buildRawButton(label: AppLocalizations.of(context)!.full, color: VSPColors.textSecondary, onTap: null);
                  return _buildRawButton(label: isArabic ? 'انضمام' : 'Join', color: VSPColors.accent, onTap: () => _handleJoin(context, currentUser?.uid));
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
