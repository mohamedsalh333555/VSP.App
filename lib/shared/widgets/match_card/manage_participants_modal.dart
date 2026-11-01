import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/user_model.dart';
import '../../../core/repositories/match_repository.dart';
import '../../../core/repositories/user_repository.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/notification_handler.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../data/models.dart';
import '../../../l10n/app_localizations.dart';

/// Modal bottom sheet allowing match hosts to inspect, accept, reject,
/// and remove participants in an open-join or challenge match.
class ManageParticipantsModal extends StatefulWidget {
  final Booking booking;

  const ManageParticipantsModal({super.key, required this.booking});

  /// Static helper to display the modal bottom sheet.
  static void show(BuildContext context, {required Booking booking}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ManageParticipantsModal(booking: booking),
    );
  }

  @override
  State<ManageParticipantsModal> createState() => _ManageParticipantsModalState();
}

class _ManageParticipantsModalState extends State<ManageParticipantsModal> {
  bool _isLoading = true;
  bool _hasLoadError = false;
  bool _isProcessing = false; // click lock state
  List<UserModel> _participants = [];
  List<UserModel> _pending = [];
  late List<String> _joinedUserIds;
  late List<String> _pendingUserIds;

  @override
  void initState() {
    super.initState();
    _joinedUserIds = List<String>.from(widget.booking.joinedUserIds);
    _pendingUserIds = List<String>.from(widget.booking.pendingUserIds);
    _fetchUsers();
  }

  Future<void> _refreshBookingAndUsers() async {
    final updatedBooking = await Provider.of<BookingProvider>(
      context,
      listen: false,
    ).getBookingById(widget.booking.id);
    if (!mounted) return;
    if (updatedBooking != null) {
      _joinedUserIds = List<String>.from(updatedBooking.joinedUserIds);
      _pendingUserIds = List<String>.from(updatedBooking.pendingUserIds);
    }
    await _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final allUserIds = [..._joinedUserIds, ..._pendingUserIds];
      if (allUserIds.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final users = await UserRepository().getUsersByIds(allUserIds);

      if (mounted) {
        setState(() {
          _participants = users.where((u) => _joinedUserIds.contains(u.uid)).toList();
          _pending = users.where((u) => _pendingUserIds.contains(u.uid)).toList();
          _isLoading = false;
          _hasLoadError = false;
        });
      }
    } catch (e, stack) {
      VSPLogger.e('Error fetching participants in bulk', e, stack);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasLoadError = true;
        });
      }
    }
  }

  void _acceptUser(String userId) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final accepted = await MatchRepository().acceptJoinRequest(widget.booking.id, userId);
      if (!accepted) throw StateError('accept_join_request_failed');
      try {
        await NotificationHandler.notifyJoinRequestAccepted(
          playerId: userId,
          stadiumName: widget.booking.stadiumName,
          bookingId: widget.booking.id,
        );
      } catch (notificationError, stackTrace) {
        VSPLogger.e(
          'Failed to notify player that their join request was accepted',
          notificationError,
          stackTrace,
        );
      }
      _pendingUserIds.remove(userId);
      if (!_joinedUserIds.contains(userId)) _joinedUserIds.add(userId);
      await _refreshBookingAndUsers();
    } catch (e, stackTrace) {
      debugPrint('Participant acceptance failed: $e\n$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().contains('match_is_full')
            ? (Localizations.localeOf(context).languageCode == 'ar'
                ? 'عذراً، اكتمل العدد ولا يمكن قبول المزيد.'
                : 'The match is full. No more players can be accepted.')
            : (Localizations.localeOf(context).languageCode == 'ar'
                ? 'تعذر قبول طلب الانضمام. حاول مرة أخرى.'
                : 'Could not accept the join request. Please try again.')),
      ));
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
      final rejected = await MatchRepository().rejectJoinRequest(widget.booking.id, userId);
      if (!rejected) throw StateError('reject_join_request_failed');
      try {
        await NotificationHandler.notifyJoinRequestRejected(
          playerId: userId,
          stadiumName: widget.booking.stadiumName,
        );
      } catch (notificationError, stackTrace) {
        VSPLogger.e(
          'Failed to notify player that their join request was rejected',
          notificationError,
          stackTrace,
        );
      }
      _pendingUserIds.remove(userId);
      await _refreshBookingAndUsers();
    } catch (e, stackTrace) {
      debugPrint('Participant request rejection failed: $e\n$stackTrace');
      if (!mounted) return;
      VSPFeedback.showError(
        context,
        Localizations.localeOf(context).languageCode == 'ar'
            ? 'تعذر رفض طلب الانضمام. حاول مرة أخرى.'
            : 'Could not reject the join request. Please try again.',
      );
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
      final removed = await MatchRepository().removeParticipantFromPublicMatch(widget.booking.id, userId);
      if (!removed) throw StateError('remove_participant_failed');
      _joinedUserIds.remove(userId);
      await _refreshBookingAndUsers();
    } catch (e, stackTrace) {
      debugPrint('Participant removal failed: $e\n$stackTrace');
      if (!mounted) return;
      VSPFeedback.showError(
        context,
        Localizations.localeOf(context).languageCode == 'ar'
            ? 'تعذر إزالة اللاعب من المباراة. حاول مرة أخرى.'
            : 'Could not remove the player from the match. Please try again.',
      );
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
                memCacheWidth: (radius * 4).round(),
                memCacheHeight: (radius * 4).round(),
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Icon(Iconsax.user_copy, color: badgeColor, size: radius),
                placeholder: (_, __) => Container(color: VSPColors.surfaceAlt),
              )
            : Icon(Iconsax.user_copy, color: badgeColor, size: radius),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final media = MediaQuery.of(context);
    final bottomInset = media.padding.bottom + 16;
    final availableHeight = (media.size.height -
            media.viewInsets.bottom -
            media.padding.top -
            media.padding.bottom -
            24)
        .clamp(0.0, media.size.height * 0.88)
        .toDouble();

    return Container(
      constraints: BoxConstraints(maxHeight: availableHeight),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: VSPColors.surfaceAlt,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(VSPRadius.xl),
          topRight: Radius.circular(VSPRadius.xl),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: VSPColors.divider, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.manageMatch,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                ),
                IconButton(
                  tooltip: isArabic ? 'إغلاق' : 'Close',
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  icon: const Icon(Iconsax.close_circle_copy, color: VSPColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: VSPColors.divider),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: VSPColors.accent))
                : _hasLoadError
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(VSPSpacing.lg),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isArabic
                                    ? 'تعذر تحميل قائمة اللاعبين.'
                                    : 'Could not load the player list.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: VSPColors.textSecondary),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _isLoading = true;
                                    _hasLoadError = false;
                                  });
                                  _fetchUsers();
                                },
                                child: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                    child: Column(
                      children: [
                        if (_pending.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                isArabic ? 'طلبات الانضمام المعلقة:' : 'Pending Requests:',
                                style: const TextStyle(color: VSPColors.warning, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          ..._pending.map((u) => Container(
                                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: VSPColors.surface,
                                  borderRadius: BorderRadius.circular(VSPRadius.md),
                                  border: Border.all(color: VSPColors.warning),
                                ),
                                child: Row(
                                  children: [
                                    _buildUserAvatar(
                                      profileImageUrl: u.profileImageUrl,
                                      radius: 16,
                                      badgeColor: VSPColors.warning,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            u.name ?? (isArabic ? 'اسم غير متاح' : 'Name unavailable'),
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            u.position ?? (isArabic ? 'المركز غير متاح' : 'Position unavailable'),
                                            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (u.phone != null && u.phone!.isNotEmpty)
                                      IconButton(
                                        tooltip: isArabic ? 'اتصال' : 'Call',
                                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                        icon: const Icon(Iconsax.call_copy, color: Colors.blue, size: 16),
                                        onPressed: _isProcessing
                                            ? null
                                            : () async {
                                                try {
                                                  await launchUrl(Uri.parse('tel:${u.phone}'));
                                                } catch (_) {
                                                  if (context.mounted) {
                                                    VSPFeedback.showError(
                                                      context,
                                                      isArabic
                                                          ? 'تعذر فتح تطبيق الاتصال.'
                                                          : 'Could not open the phone app.',
                                                    );
                                                  }
                                                }
                                              },
                                      ),
                                    IconButton(
                                      tooltip: isArabic ? 'قبول الطلب' : 'Accept request',
                                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                      icon: const Icon(Iconsax.tick_circle_copy, color: VSPColors.success, size: 18),
                                      onPressed: _isProcessing ? null : () => _acceptUser(u.uid),
                                    ),
                                    IconButton(
                                      tooltip: isArabic ? 'رفض الطلب' : 'Reject request',
                                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                      icon: const Icon(Iconsax.close_circle_copy, color: VSPColors.error, size: 18),
                                      onPressed: _isProcessing ? null : () => _rejectUser(u.uid),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              AppLocalizations.of(context)!.joinedFromApp,
                              style: const TextStyle(color: VSPColors.textSecondary, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        if (_participants.isEmpty)
                          Center(
                            child: Text(
                              AppLocalizations.of(context)!.noPlayersYet,
                              style: const TextStyle(color: VSPColors.textSecondary),
                            ),
                          )
                        else
                          ..._participants.map((u) {
                            final isHost = u.uid == widget.booking.createdByUserId;
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: VSPColors.surface,
                                borderRadius: BorderRadius.circular(VSPRadius.md),
                                border: Border.all(color: VSPColors.divider, width: 0.5),
                              ),
                              child: Row(
                                children: [
                                  _buildUserAvatar(
                                    profileImageUrl: u.profileImageUrl,
                                    radius: 20,
                                    badgeColor: VSPColors.accent,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                u.name ?? (isArabic ? 'اسم غير متاح' : 'Name unavailable'),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyLarge
                                                    ?.copyWith(fontWeight: FontWeight.bold),
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
                                                  style: const TextStyle(
                                                    color: VSPColors.accent,
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        Text(
                                          u.position ?? (isArabic ? 'المركز غير متاح' : 'Position unavailable'),
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(color: VSPColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!isHost)
                                    IconButton(
                                      tooltip: isArabic ? 'إزالة اللاعب' : 'Remove player',
                                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                      icon: const Icon(Iconsax.user_remove_copy, color: VSPColors.error, size: 16),
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
