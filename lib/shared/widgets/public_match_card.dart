import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/ui/tokens/vsp_tokens.dart';
import '../../core/providers/auth_provider.dart' as app_auth;
import '../../core/services/database_service.dart';
import '../../core/services/sharing_service.dart';
import '../../core/utils/vsp_feedback.dart';
import 'primary_button.dart';
import '../../data/models.dart';
import '../../core/models/user_model.dart';
import '../../core/repositories/tournament_repository.dart';

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
    final users = await DatabaseService().getUsersByIds([
      widget.booking.createdByUserId,
    ]);
    if (users.isNotEmpty && mounted) {
      if (users.first.name != null && users.first.name!.isNotEmpty) {
        setState(() => _hostName = users.first.name);
      }
    }

    if (widget.booking.playerTeamId != null) {
      final teams = await TournamentRepository().getTeamsByIds([
        widget.booking.playerTeamId!,
      ]);
      if (teams.isNotEmpty && mounted) {
        setState(() => _hostTeam = teams.first);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<app_auth.AuthProvider>(context);
    final currentUser = authProvider.currentUser;
    final booking = widget.booking;
    final bool hasJoined =
        currentUser != null &&
        booking.joinedUserIds.contains(currentUser.uid);
    final bool isHost =
        currentUser != null &&
        booking.createdByUserId == currentUser.uid;
    
    final totalFieldCapacity = booking.maxPlayers > 0 ? booking.maxPlayers * 2 : 10;
    final remainingPlayers = (totalFieldCapacity - booking.currentPlayers).clamp(0, totalFieldCapacity);
    final entryFee = (booking.totalPrice / totalFieldCapacity).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VSPColors.surface, 
        borderRadius: BorderRadius.circular(VSPRadius.xl),
        border: Border.all(
          color: widget.highlighted ? VSPColors.accent : VSPColors.divider,
          width: 1,
        ),
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
                _buildStatusBadge('MY MATCH', VSPColors.accent)
              else if (hasJoined)
                _buildStatusBadge('JOINED', Colors.blue)
              else if (booking.currentPlayers >= totalFieldCapacity)
                _buildStatusBadge('FULL', VSPColors.textSecondary)
              else
                _buildStatusBadge('OPEN', Colors.green),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: VSPColors.surfaceAlt,
                  shape: BoxShape.circle,
                  border: Border.all(color: VSPColors.divider, width: 1),
                ),
                child: ClipOval(
                  child: (booking.playerTeamLogoUrl != null && booking.playerTeamLogoUrl!.isNotEmpty)
                      ? Image.network(booking.playerTeamLogoUrl!, fit: BoxFit.cover)
                      : const Icon(Icons.person, color: VSPColors.accent, size: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _hostName ?? booking.playerTeamName ?? "Host",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      booking.stadiumName,
                      style: const TextStyle(
                        color: VSPColors.textSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.ios_share, color: VSPColors.textSecondary, size: 20),
                onPressed: () => _handleShare(booking),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCompactInfo(Icons.calendar_month, booking.formattedDate),
                _buildDivider(),
                _buildCompactInfo(Icons.schedule, _formatTimeShort(booking.formattedTimeRange)),
                _buildDivider(),
                _buildCompactInfo(Icons.payments_outlined, "$entryFee EGP"),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSpotsIndicator(remainingPlayers, booking.currentPlayers, totalFieldCapacity),
              _buildMainButton(
                context: context,
                isHost: isHost,
                hasJoined: hasJoined,
                isFull: booking.currentPlayers >= totalFieldCapacity,
                currentUser: currentUser,
              ),
            ],
          ),
        ],
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
            Text(
              "$remaining",
              style: const TextStyle(
                color: VSPColors.accent,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              "SPOTS LEFT",
              style: TextStyle(
                color: VSPColors.textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ],
        ),
        Text(
          "$current/$total PLAYERS JOINED",
          style: TextStyle(
            color: VSPColors.textSecondary.withValues(alpha: 0.6),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildTypeBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: VSPColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(VSPRadius.xs),
        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: VSPColors.accent,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
        ),
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
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
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
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 14,
      color: Colors.white10,
    );
  }

  Widget _buildMainButton({
    required BuildContext context,
    required bool isHost,
    required bool hasJoined,
    required bool isFull,
    dynamic currentUser,
  }) {
    if (_isLoading) {
      return const SizedBox(
        width: 100,
        height: 44,
        child: Center(child: CircularProgressIndicator(color: VSPColors.accent, strokeWidth: 2)),
      );
    }

    if (isHost) {
      return _buildRawButton(
        label: "MANAGE",
        color: VSPColors.accent,
        onTap: () => _manageParticipants(context),
        isOutlined: false,
      );
    }

    if (hasJoined) {
      return _buildRawButton(
        label: "LEAVE",
        color: Colors.redAccent,
        onTap: () => _handleLeave(context, currentUser?.uid),
        isOutlined: true,
      );
    }

    if (isFull) {
      return _buildRawButton(
        label: "FULL",
        color: VSPColors.textSecondary,
        onTap: null,
      );
    }

    return _buildRawButton(
      label: "JOIN",
      color: VSPColors.accent,
      onTap: () => _handleJoin(context, currentUser?.uid),
    );
  }

  Widget _buildRawButton({
    required String label,
    required Color color,
    required VoidCallback? onTap,
    bool isOutlined = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44.0,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        decoration: BoxDecoration(
          color: isOutlined ? Colors.transparent : color,
          borderRadius: BorderRadius.circular(12),
          border: isOutlined ? Border.all(color: color, width: 2) : null,
          boxShadow: isOutlined ? null : [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isOutlined ? color : Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
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
    final success = await DatabaseService().joinPublicMatch(
      widget.booking.id,
      userId,
    );
    if (!context.mounted) return;
    setState(() => _isLoading = false);
    if (success) {
      VSPFeedback.showSuccess(context, "Joined Match Successfully!");
    } else {
      VSPFeedback.showError(context, "Failed to join match.");
    }
  }

  void _handleLeave(BuildContext context, String userId) async {
    setState(() => _isLoading = true);
    final success = await DatabaseService().leavePublicMatch(
      widget.booking.id,
      userId,
    );
    if (!context.mounted) return;
    setState(() => _isLoading = false);
    if (success) {
      VSPFeedback.showSuccess(context, "Left Match Successfully.");
    } else {
      VSPFeedback.showError(context, "Failed to leave match.");
    }
  }

  void _manageParticipants(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ManageParticipantsModal(booking: widget.booking),
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
  int _hostBasePlayers = 0;
  bool _isUpdatingCount = false;

  @override
  void initState() {
    super.initState();
    _hostBasePlayers = widget.booking.currentPlayers - widget.booking.joinedUserIds.length;
    if (_hostBasePlayers < 0) _hostBasePlayers = 0;
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
    final success = await DatabaseService().removeParticipantFromPublicMatch(
      widget.booking.id,
      userId,
    );
    if (success && mounted) {
      setState(() {
        _participants.removeWhere((u) => u.uid == userId);
      });
      VSPFeedback.showSuccess(context, "Participant removed.");
    }
  }

  void _updateHostPlayers(int delta) async {
    final newCount = _hostBasePlayers + delta;
    if (newCount < 0) return;
    
    final max = widget.booking.maxPlayers > 0 ? widget.booking.maxPlayers : 5;
    final totalFieldCapacity = max * 2;
    if (newCount + widget.booking.joinedUserIds.length > totalFieldCapacity) {
      VSPFeedback.showError(context, "Maximum stadium capacity reached.");
      return;
    }

    setState(() => _isUpdatingCount = true);
    final success = await DatabaseService().updatePublicMatchHostSpots(
      widget.booking.id,
      newCount,
    );
    
    if (mounted) {
      setState(() {
        _isUpdatingCount = false;
        if (success) {
          _hostBasePlayers = newCount;
        } else {
          VSPFeedback.showError(context, "Failed to update spots.");
        }
      });
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
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: VSPColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Manage Match", style: Theme.of(context).textTheme.displaySmall),
                IconButton(
                  icon: const Icon(Icons.close, color: VSPColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(color: VSPColors.divider.withValues(alpha: 0.1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Players you are bringing", style: TextStyle(fontWeight: FontWeight.bold)),
                      Text("Manage your reserved spots", style: TextStyle(color: VSPColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: (_isUpdatingCount || _hostBasePlayers <= 0) ? null : () => _updateHostPlayers(-1),
                        icon: Icon(Icons.remove_circle_outline, color: _hostBasePlayers <= 0 ? VSPColors.textSecondary : VSPColors.error),
                      ),
                      SizedBox(
                        width: 24,
                        child: Center(
                          child: _isUpdatingCount 
                             ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                             : Text("$_hostBasePlayers", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        ),
                      ),
                      IconButton(
                        onPressed: _isUpdatingCount ? null : () => _updateHostPlayers(1),
                        icon: const Icon(Icons.add_circle_outline, color: VSPColors.accent),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Divider(color: VSPColors.divider),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text("Joined from App", style: TextStyle(color: VSPColors.textSecondary, fontWeight: FontWeight.bold)),
            ),
          ),
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
                        decoration: BoxDecoration(
                          color: VSPColors.surface,
                          borderRadius: BorderRadius.circular(VSPRadius.md),
                          border: Border.all(color: VSPColors.divider, width: 0.5),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: VSPColors.surfaceAlt,
                              backgroundImage: (user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty) ? NetworkImage(user.profileImageUrl!) : null,
                              child: (user.profileImageUrl == null || user.profileImageUrl!.isEmpty) ? const Icon(Icons.person, color: VSPColors.accent, size: 20) : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(user.name ?? "Player", style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                                      if (isHost) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: VSPColors.accent.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: VSPColors.accent, width: 0.5),
                                          ),
                                          child: const Text("HOST", style: TextStyle(color: VSPColors.accent, fontSize: 8, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(user.position ?? "Midfielder", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary)),
                                ],
                              ),
                            ),
                            if (!isHost)
                              IconButton(
                                icon: const Icon(Icons.person_remove_outlined, color: VSPColors.error, size: 20),
                                onPressed: () => _removeUser(user.uid),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
