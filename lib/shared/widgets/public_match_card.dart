import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/ui/tokens/vsp_tokens.dart';
import '../../core/providers/auth_provider.dart' as app_auth;
import '../../core/services/sharing_service.dart';
import '../../core/utils/vsp_feedback.dart';
import '../../data/models.dart';
import '../../core/models/user_model.dart';
import '../../core/repositories/match_repository.dart';
import '../../core/repositories/user_repository.dart';
import '../../core/services/notification_handler.dart';


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
        VSPFeedback.showSuccess(context, "تم إرسال طلب الانضمام للمستضيف بنجاح! 📩");
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ManageParticipantsModal(booking: widget.booking),
    );
  }

  String _formatTimeShort(String timeRange) {
    final parts = timeRange.split(' - ');
    if (parts.length == 2) {
      return '${parts[0].replaceAll(':00', '')}-${parts[1].replaceAll(':00', '')}';
    }
    return timeRange;
  }

  Widget _buildTypeBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: VSPColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(VSPRadius.xs),
        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
      ),
      child: Text(text, style: const TextStyle(color: VSPColors.accent, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
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

  Widget _buildCompactInfo(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: VSPColors.accent, size: 14),
        const SizedBox(width: 6),
        Flexible(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() => Container(width: 1, height: 14, color: Colors.white10);

  Widget _buildRawButton({required String label, required Color color, required VoidCallback? onTap, bool isOutlined = false}) {
    return AbsorbPointer(
      absorbing: _isLoading,
      child: GestureDetector(
        onTap: _isLoading ? null : onTap,
        child: Container(
          height: 44.0,
          padding: const EdgeInsets.symmetric(horizontal: 32),
          decoration: BoxDecoration(
            color: isOutlined ? Colors.transparent : color,
            borderRadius: BorderRadius.circular(VSPRadius.md),
            border: isOutlined ? Border.all(color: color, width: 2) : null,
            boxShadow: isOutlined ? null : [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: Center(
            child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)) 
                : Text(label, style: TextStyle(color: isOutlined ? color : Colors.black, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.0)),
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
    final authProvider = Provider.of<app_auth.AuthProvider>(context);
    final currentUser = authProvider.currentUser;
    final booking = widget.booking;
    
    final bool hasJoined = currentUser != null && booking.joinedUserIds.contains(currentUser.uid);
    final bool isPending = currentUser != null && booking.pendingUserIds.contains(currentUser.uid);
    final bool isHost = currentUser != null && booking.createdByUserId == currentUser.uid;
    
    final totalFieldCapacity = booking.totalFieldCapacity;
    final remainingPlayers = (booking.totalFieldCapacity - booking.currentPlayers).clamp(0, booking.totalFieldCapacity);
    final entryFee = (booking.totalPrice / totalFieldCapacity).toStringAsFixed(0);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: VSPColors.surface, 
        borderRadius: BorderRadius.circular(VSPRadius.xl),
        border: Border.all(color: widget.highlighted ? VSPColors.accent : VSPColors.divider, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTypeBadge(booking.bookingType.name.toUpperCase()),
              if (isHost)
                _buildStatusBadge(AppLocalizations.of(context)!.myMatch, VSPColors.accent)
              else if (hasJoined)
                _buildStatusBadge(AppLocalizations.of(context)!.joined, Colors.blue)
              else if (isPending)
                _buildStatusBadge(isArabic ? 'طلب معلق ⏳' : 'Pending ⏳', Colors.orange)
              else if (booking.currentPlayers >= totalFieldCapacity)
                _buildStatusBadge(AppLocalizations.of(context)!.full, VSPColors.textSecondary)
              else
                _buildStatusBadge(AppLocalizations.of(context)!.open, Colors.green),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(color: VSPColors.surfaceAlt, shape: BoxShape.circle, border: Border.all(color: VSPColors.divider, width: 1)),
                child: ClipOval(
                  child: (booking.hostAvatarUrl != null && booking.hostAvatarUrl!.isNotEmpty)
                      ? CachedNetworkImage(imageUrl: booking.hostAvatarUrl!, fit: BoxFit.cover, errorWidget: (_, __, ___) => const Icon(FontAwesomeIcons.user, color: VSPColors.accent, size: 20), placeholder: (_, __) => Container(color: VSPColors.surfaceAlt))
                      : (booking.playerTeamLogoUrl != null && booking.playerTeamLogoUrl!.isNotEmpty)
                          ? CachedNetworkImage(imageUrl: booking.playerTeamLogoUrl!, fit: BoxFit.cover, errorWidget: (_, __, ___) => const Icon(FontAwesomeIcons.user, color: VSPColors.accent, size: 20), placeholder: (_, __) => Container(color: VSPColors.surfaceAlt))
                          : const Icon(FontAwesomeIcons.user, color: VSPColors.accent, size: 20),
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
              IconButton(visualDensity: VisualDensity.compact, icon: const Icon(FontAwesomeIcons.shareNodes, color: VSPColors.textSecondary, size: 18), onPressed: () => _handleShare(booking)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(VSPRadius.md)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(child: Center(child: _buildCompactInfo(FontAwesomeIcons.calendarDays, booking.formattedDate))),
                _buildDivider(),
                Expanded(child: Center(child: _buildCompactInfo(FontAwesomeIcons.clock, _formatTimeShort(booking.formattedTimeRange)))),
                _buildDivider(),
                Expanded(child: Center(child: _buildCompactInfo(FontAwesomeIcons.moneyBill, "$entryFee ${AppLocalizations.of(context)!.egCurrency}"))),
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
                return _buildRawButton(label: isArabic ? 'طلب انضمام' : 'Request Join', color: VSPColors.accent, onTap: () => _handleJoin(context, currentUser?.uid));
              }),
            ],
          ),
        ],
      ),
    );
  }
}

class _ManageParticipantsModal extends StatefulWidget {
  final Booking booking;
  const _ManageParticipantsModal({required this.booking});
  @override
  State<_ManageParticipantsModal> createState() => _ManageParticipantsModalState();
}

class _ManageParticipantsModalState extends State<_ManageParticipantsModal> {
  bool _isLoading = true;
  bool _isProcessing = false; // click lock state
  List<UserModel> _participants = [];
  List<UserModel> _pending = [];

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final joined = await UserRepository().getUsersByIds(widget.booking.joinedUserIds);
      final pend = await UserRepository().getUsersByIds(widget.booking.pendingUserIds);
      if (mounted) {
        setState(() {
          _participants = joined;
          _pending = pend;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        VSPFeedback.showError(context, e.toString());
      }
    }
  }

  void _acceptUser(String userId) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await MatchRepository().acceptJoinRequest(widget.booking.id, userId);
      // ✅ Use NotificationHandler instead of deprecated DatabaseService().sendNotification()
      await NotificationHandler.notifyPlayerJoinedMatch(
        hostId: userId,
        playerName: '',
        stadiumName: widget.booking.stadiumName,
        bookingId: widget.booking.id,
      );
      _fetchUsers();
    } catch(e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().contains('match_is_full') ? 'عذراً، اكتمل العدد ولا يمكن قبول المزيد' : 'Error')));
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _rejectUser(String userId) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await MatchRepository().rejectJoinRequest(widget.booking.id, userId);
      // ✅ Use NotificationHandler instead of deprecated DatabaseService().sendNotification()
      await NotificationHandler.notifyChallengeDeclined(
        challengerCaptainId: userId,
        opponentTeamName: widget.booking.playerTeamName ?? widget.booking.stadiumName,
      );
      _fetchUsers();
    } catch (e) {
      if (!mounted) return;
      VSPFeedback.showError(context, e.toString());
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _removeUser(String userId) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await MatchRepository().removeParticipantFromPublicMatch(widget.booking.id, userId);
      _fetchUsers();
    } catch (e) {
      if (!mounted) return;
      VSPFeedback.showError(context, e.toString());
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Widget _buildUserAvatar({required String? profileImageUrl, required double radius, required Color badgeColor}) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: const BoxDecoration(
        color: VSPColors.surfaceAlt,
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: (profileImageUrl != null && profileImageUrl.isNotEmpty)
            ? CachedNetworkImage(
                imageUrl: profileImageUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Icon(FontAwesomeIcons.user, color: badgeColor, size: radius),
                placeholder: (_, __) => Container(color: VSPColors.surfaceAlt),
              )
            : Icon(FontAwesomeIcons.user, color: badgeColor, size: radius),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final bottomInset = MediaQuery.of(context).padding.bottom + MediaQuery.of(context).viewInsets.bottom + 16;
    
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: VSPColors.surfaceAlt,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(VSPRadius.xl), topRight: Radius.circular(VSPRadius.xl)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: VSPColors.divider, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(AppLocalizations.of(context)!.manageMatch, style: Theme.of(context).textTheme.displaySmall),
                IconButton(icon: const Icon(FontAwesomeIcons.xmark, color: VSPColors.textSecondary), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(color: VSPColors.divider),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: VSPColors.accent))
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        if (_pending.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Align(alignment: Alignment.centerLeft, child: Text(isArabic ? 'طلبات الانضمام المعلقة:' : 'Pending Requests:', style: const TextStyle(color: VSPColors.warning, fontWeight: FontWeight.bold))),
                          ),
                          ..._pending.map((u) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(VSPRadius.md), border: Border.all(color: VSPColors.warning)),
                            child: Row(
                              children: [
                                _buildUserAvatar(profileImageUrl: u.profileImageUrl, radius: 16, badgeColor: VSPColors.warning),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(u.name ?? 'Player', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      Text(u.position ?? 'Player', style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ],
                                  )
                                ),
                                if (u.phone != null && u.phone!.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(FontAwesomeIcons.phone, color: Colors.blue, size: 16), 
                                    onPressed: _isProcessing 
                                        ? null 
                                        : () async {
                                            try {
                                              await launchUrl(Uri.parse('tel:${u.phone}'));
                                            } catch (_) {
                                              if (context.mounted) {
                                                VSPFeedback.showError(context, 'Could not launch dialer');
                                              }
                                            }
                                          },
                                  ),
                                IconButton(
                                  icon: const Icon(FontAwesomeIcons.circleCheck, color: VSPColors.success, size: 18), 
                                  onPressed: _isProcessing ? null : () => _acceptUser(u.uid),
                                ),
                                IconButton(
                                  icon: const Icon(FontAwesomeIcons.circleXmark, color: VSPColors.error, size: 18), 
                                  onPressed: _isProcessing ? null : () => _rejectUser(u.uid),
                                ),
                              ],
                            ),
                          )),
                        ],
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Align(alignment: Alignment.centerLeft, child: Text(AppLocalizations.of(context)!.joinedFromApp, style: const TextStyle(color: VSPColors.textSecondary, fontWeight: FontWeight.bold))),
                        ),
                        if (_participants.isEmpty)
                          Center(child: Text(AppLocalizations.of(context)!.noPlayersYet, style: const TextStyle(color: VSPColors.textSecondary)))
                        else
                          ..._participants.map((u) {
                            final isHost = u.uid == widget.booking.createdByUserId;
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(VSPRadius.md), border: Border.all(color: VSPColors.divider, width: 0.5)),
                              child: Row(
                                children: [
                                  _buildUserAvatar(profileImageUrl: u.profileImageUrl, radius: 20, badgeColor: VSPColors.accent),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                u.name ?? AppLocalizations.of(context)!.player, 
                                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isHost) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), 
                                                decoration: BoxDecoration(
                                                  color: VSPColors.accent.withValues(alpha: 0.1), 
                                                  borderRadius: BorderRadius.circular(4), 
                                                  border: Border.all(color: VSPColors.accent, width: 0.5),
                                                ), 
                                                child: Text(
                                                  AppLocalizations.of(context)!.host.toUpperCase(), 
                                                  style: const TextStyle(color: VSPColors.accent, fontSize: 8, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        Text(u.position ?? "Midfielder", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  if (!isHost)
                                    IconButton(
                                      icon: const Icon(FontAwesomeIcons.userMinus, color: VSPColors.error, size: 16), 
                                      onPressed: _isProcessing ? null : () => _removeUser(u.uid),
                                    ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

