import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/providers/auth_provider.dart' as app_auth;
import '../../../core/services/database_service.dart';
import '../../../core/services/sharing_service.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../data/models.dart';

class PublicMatchCard extends StatefulWidget {
  final Booking booking;
  final bool highlighted;
  
  const PublicMatchCard({
    super.key, 
    required this.booking, 
    this.highlighted = false,
  });

  @override
  State<PublicMatchCard> createState() => _PublicMatchCardState();
}

class _PublicMatchCardState extends State<PublicMatchCard> {
  bool _isLoading = false;
  String? _hostName;
  Team? _hostTeam;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    // Fetch Host Name
    if (widget.booking.playerTeamName == null || widget.booking.playerTeamName!.isEmpty) {
      final users = await DatabaseService().getUsersByIds([widget.booking.createdByUserId]);
      if (users.isNotEmpty && mounted) {
        setState(() => _hostName = users.first.name);
      }
    }

    // Fetch Host Team Elo if it's a team match
    if (widget.booking.playerTeamId != null) {
      final teams = await DatabaseService().getTeamsByIds([widget.booking.playerTeamId!]);
      if (teams.isNotEmpty && mounted) {
        setState(() => _hostTeam = teams.first);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<app_auth.AuthProvider>(context);
    final currentUser = authProvider.currentUser;
    final currentUserImage = authProvider.userModel?.profileImageUrl;
    final bool hasJoined = currentUser != null && widget.booking.joinedUserIds.contains(currentUser.uid);
    final bool isHost = currentUser != null && widget.booking.createdByUserId == currentUser.uid;
    final booking = widget.booking;
    final remainingPlayers = booking.maxPlayers - booking.currentPlayers;
    
    final entryFee = (booking.totalPrice / (booking.maxPlayers > 0 ? booking.maxPlayers : 1)).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(VSPSpacing.md),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: widget.highlighted 
            ? Border.all(color: VSPColors.accent, width: 1.5) 
            : Border.all(color: VSPColors.divider, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          if (widget.highlighted)
            BoxShadow(
              color: VSPColors.accent.withValues(alpha: 0.1),
              blurRadius: 15,
            ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER ROW with Host Info
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: VSPColors.accent.withValues(alpha: 0.1),
                  border: Border.all(color: VSPColors.accent.withValues(alpha: 0.2)),
                ),
                child: ClipOval(
                  child: (isHost && currentUserImage != null && currentUserImage.isNotEmpty)
                      ? Image.network(
                          currentUserImage,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.person, color: VSPColors.accent, size: 20),
                        )
                      : (booking.playerTeamLogoUrl != null && booking.playerTeamLogoUrl!.isNotEmpty)
                          ? Image.network(
                              booking.playerTeamLogoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.groups, color: VSPColors.accent, size: 20),
                            )
                          : const Icon(Icons.person, color: VSPColors.accent, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.playerTeamName ?? _hostName ?? "Host Player",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Text(
                          _hostTeam != null ? 'Elo: ${_hostTeam!.points}' : 'Match Host',
                          style: TextStyle(
                            color: VSPColors.textSecondary.withValues(alpha: 0.7),
                            fontSize: 11,
                          ),
                        ),
                        if (_hostTeam != null) ...[
                          const SizedBox(width: 4),
                          _buildRankBadge(_hostTeam!.points),
                        ],
                        if (widget.highlighted) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.star, color: VSPColors.accent, size: 10),
                          const SizedBox(width: 2),
                          const Text(
                            'PRO',
                            style: TextStyle(color: VSPColors.accent, fontSize: 10, fontWeight: FontWeight.black),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.ios_share, color: Colors.white60, size: 18),
                onPressed: () => _handleShare(booking),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // STADIUM NAME & BADGES
          Text(
            booking.stadiumName,
            style: const TextStyle(
              color: VSPColors.accent,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),

          // INFO GRID
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                Expanded(child: _buildInfoItem(Icons.calendar_today, booking.formattedDate)),
                Container(width: 1, height: 20, color: Colors.white10),
                Expanded(child: _buildInfoItem(Icons.access_time, _formatTimeShort(booking.formattedTimeRange))),
                Container(width: 1, height: 20, color: Colors.white10),
                Expanded(child: _buildInfoItem(Icons.payments_outlined, "$entryFee EGP")),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // FOOTER: SPOTS & ACTION
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                      children: [
                        TextSpan(
                          text: "$remainingPlayers", 
                          style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 18)
                        ),
                        const TextSpan(text: " spots left"),
                      ],
                    ),
                  ),
                  Text(
                    "${booking.currentPlayers}/${booking.maxPlayers} joined",
                    style: TextStyle(color: VSPColors.textSecondary.withValues(alpha: 0.5), fontSize: 10),
                  ),
                ],
              ),
              const Spacer(),
              if (_isLoading)
                const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: VSPColors.accent))
              else if (isHost)
                _buildActionButton("Edit", VSPColors.accent, () => _manageParticipants(context))
              else if (hasJoined)
                _buildActionButton("Leave", VSPColors.error, () => _handleLeave(context, currentUser.uid), isOutlined: true)
              else
                _buildActionButton(
                  booking.currentPlayers >= booking.maxPlayers ? "Full" : "Join", 
                  booking.currentPlayers >= booking.maxPlayers ? Colors.white24 : VSPColors.accent, 
                  booking.currentPlayers >= booking.maxPlayers ? null : () => _handleJoin(context, currentUser?.uid)
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String value) {
    return Column(
      children: [
        Icon(icon, size: 12, color: VSPColors.textSecondary),
        const SizedBox(height: 4),
        Text(
          value, 
          textAlign: TextAlign.center, 
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback? onTap, {bool isOutlined = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isOutlined ? Colors.transparent : color,
          borderRadius: BorderRadius.circular(VSPRadius.md),
          border: isOutlined ? Border.all(color: color, width: 1.5) : null,
        ),
        child: Text(
          label, 
          style: TextStyle(
            color: isOutlined ? color : VSPColors.background, 
            fontWeight: FontWeight.w900, 
            fontSize: 13
          )
        ),
      ),
    );
  }

  Widget _buildRankBadge(int points) {
    Color color = Colors.grey;
    String label = 'BRONZE';
    if (points >= 2000) { color = Colors.amber; label = 'GOLD'; }
    else if (points >= 1500) { color = Colors.blueGrey; label = 'SILVER'; }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15), 
        borderRadius: BorderRadius.circular(4), 
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.5)
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold)),
    );
  }

  void _handleShare(Booking booking) {
    SharingService.shareMatch(
      bookingId: booking.id,
      teamName: booking.playerTeamName ?? _hostName ?? "VSP Team",
      stadiumName: booking.stadiumName,
      date: '${booking.formattedDate} at ${booking.formattedTimeRange}',
    );
  }

  void _handleJoin(BuildContext context, String? userId) async {
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login first')));
      return;
    }
    setState(() => _isLoading = true);
    final success = await DatabaseService().joinPublicMatch(widget.booking.id, userId);
    if (!context.mounted) return;
    setState(() => _isLoading = false);
    if (success) { VSPFeedback.showSuccess(context, "Joined Match Successfully!"); }
    else { VSPFeedback.showError(context, "Failed to join match."); }
  }

  void _handleLeave(BuildContext context, String userId) async {
    setState(() => _isLoading = true);
    final success = await DatabaseService().leavePublicMatch(widget.booking.id, userId);
    if (!context.mounted) return;
    setState(() => _isLoading = false);
    if (success) { VSPFeedback.showSuccess(context, "Left Match Successfully."); }
    else { VSPFeedback.showError(context, "Failed to leave match."); }
  }

  void _manageParticipants(BuildContext context) {
    showModalBottomSheet(
      context: context, 
      isScrollControlled: true, 
      backgroundColor: Colors.transparent, 
      builder: (context) => _ManageParticipantsModal(booking: widget.booking)
    );
  }

  String _formatTimeShort(String timeRange) {
    final parts = timeRange.split(' - ');
    if (parts.length == 2) {
      final start = parts[0].replaceAll(':00', '');
      final end = parts[1].replaceAll(':00', '');
      return '$start-$end';
    }
    return timeRange;
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
  List<UserModel> _participants = [];

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    final users = await DatabaseService().getUsersByIds(widget.booking.joinedUserIds);
    if (mounted) {
      setState(() {
        _participants = users;
        _isLoading = false;
      });
    }
  }

  void _removeUser(String userId) async {
    final success = await DatabaseService().removeParticipantFromPublicMatch(widget.booking.id, userId);
    if (success && mounted) {
      setState(() {
        _participants.removeWhere((u) => u.uid == userId);
      });
      VSPFeedback.showSuccess(context, "Participant removed.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
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
          Container(width: 40, height: 4, decoration: BoxDecoration(color: VSPColors.divider, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Manage Match", style: Theme.of(context).textTheme.displaySmall),
                IconButton(icon: const Icon(Icons.close, color: VSPColors.textSecondary), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(color: VSPColors.divider),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: VSPColors.accent))
              : _participants.isEmpty
                ? const Center(child: Text("No players joined yet", style: TextStyle(color: VSPColors.textSecondary)))
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _participants.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final user = _participants[index];
                      final isHost = user.uid == widget.booking.createdByUserId;
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(VSPRadius.md), border: Border.all(color: VSPColors.divider, width: 0.5)),
                        child: Row(
                          children: [
                            CircleAvatar(radius: 20, backgroundColor: VSPColors.surfaceAlt, backgroundImage: (user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty) ? NetworkImage(user.profileImageUrl!) : null, child: (user.profileImageUrl == null || user.profileImageUrl!.isEmpty) ? const Icon(Icons.person, color: VSPColors.accent, size: 20) : null),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Text(user.name ?? "Player", style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)), if (isHost) ...[const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: VSPColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: VSPColors.accent, width: 0.5)), child: const Text("HOST", style: TextStyle(color: VSPColors.accent, fontSize: 8, fontWeight: FontWeight.bold)))]]), Text(user.position ?? "Midfielder", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary))])),
                            if (!isHost) IconButton(icon: const Icon(Icons.person_remove_outlined, color: VSPColors.error, size: 20), onPressed: () => _removeUser(user.uid)) else const Padding(padding: EdgeInsets.only(right: 12), child: Icon(Icons.shield, color: VSPColors.accent, size: 18)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).padding.bottom + 20),
            child: SizedBox(width: double.infinity, child: PrimaryButton(text: "Done", onPressed: () => Navigator.pop(context))),
          ),
        ],
      ),
    );
  }
}
