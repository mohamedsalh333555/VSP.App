import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart' as app_auth;
import '../../../core/services/database_service.dart';
import '../../../data/models.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';

class TeamDashboardScreen extends StatelessWidget {
  const TeamDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          'Matches',
          style: Theme.of(context).textTheme.displayMedium,
        ),
      ),
      body: StreamBuilder<List<Booking>>(
        stream: DatabaseService().getPublicMatches(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
          }
          
          final bookings = snapshot.data ?? [];
          
          if (bookings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.sports_soccer_outlined, color: Colors.white.withValues(alpha: 0.1), size: 80),
                   const SizedBox(height: VSPSpacing.md),
                    Text(
                    'No public matches available right now.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    'Be the first to host one!',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: VSPColors.accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.fromLTRB(VSPSpacing.md, VSPSpacing.md, VSPSpacing.md, MediaQuery.of(context).padding.bottom + 110),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: VSPSpacing.md),
                child: PublicMatchCard(booking: bookings[index]),
              );
            },
          );
        }
      ),
    );
  }
}

class PublicMatchCard extends StatefulWidget {
  final Booking booking;
  const PublicMatchCard({super.key, required this.booking});

  @override
  State<PublicMatchCard> createState() => _PublicMatchCardState();
}

class _PublicMatchCardState extends State<PublicMatchCard> {
  bool _isLoading = false;
  String? _hostName;

  @override
  void initState() {
    super.initState();
    // If no team name provided, fetch the host user's name
    if (widget.booking.playerTeamName == null || widget.booking.playerTeamName!.isEmpty) {
      _fetchHostName();
    }
  }

  Future<void> _fetchHostName() async {
    final users = await DatabaseService().getUsersByIds([widget.booking.createdByUserId]);
    if (users.isNotEmpty && mounted) {
      setState(() {
        _hostName = users.first.name;
      });
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
    
    // Per-player price calculation
    final entryFee = (booking.totalPrice / (booking.maxPlayers > 0 ? booking.maxPlayers : 1)).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(VSPSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF2D4B15), // Deep Green from mockup
        borderRadius: BorderRadius.circular(VSPRadius.xl),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- HEADER ROW: Avatar + Names + Join Button ---
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF1E330E), 
                ),
                child: ClipOval(
                  child: Image.network(
                    (isHost && currentUserImage != null && currentUserImage.isNotEmpty)
                        ? currentUserImage
                        : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(booking.playerTeamName ?? _hostName ?? 'H')}&background=random',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.person, color: VSPColors.accent),
                  ),
                ),
              ),
              const SizedBox(width: VSPSpacing.md),
              
              // Names
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.playerTeamName ?? _hostName ?? "Host Player",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Captain',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),

              // Action Button (Join / Leave / Edit)
              if (_isLoading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: VSPColors.accent),
                )
              else if (isHost)
                // --- HOST ACTION: EDIT MATCH (MANAGE PARTICIPANTS) ---
                GestureDetector(
                  onTap: () => _manageParticipants(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: VSPColors.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "Edit Match",
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: VSPColors.background,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
              else if (hasJoined)
                // --- PARTICIPANT ACTION: LEAVE ---
                GestureDetector(
                  onTap: () => _handleLeave(context, currentUser.uid),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border.all(color: VSPColors.error, width: 1.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "Leave",
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: VSPColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
              else
                // --- PUBLIC ACTION: JOIN ---
                GestureDetector(
                  onTap: booking.currentPlayers >= booking.maxPlayers 
                      ? null 
                      : () => _handleJoin(context, currentUser?.uid),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: booking.currentPlayers >= booking.maxPlayers ? VSPColors.textSecondary : VSPColors.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      booking.currentPlayers >= booking.maxPlayers ? "Full" : "Join",
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: VSPColors.background,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 12),

          // --- INFO ROW: The Premium Inner Box ---
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(child: _buildInfoColumn("DATE", booking.formattedDate)),
                Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.1)),
                Expanded(child: _buildInfoColumn("TIME", _formatTimeShort(booking.formattedTimeRange))),
                Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.1)),
                Expanded(child: _buildInfoColumn("PRICE", "$entryFee EGP / player")),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // --- FOOTER ROW: Dynamic Avatar Stack & Remaining text ---
          Row(
            children: [
              // Dynamic Avatar Stack (Shows icons based on current count)
              if (booking.currentPlayers > 0)
                SizedBox(
                  width: (booking.currentPlayers.clamp(0, 3) * 18.0) + 14, 
                  height: 32,
                  child: Stack(
                    children: List.generate(
                      booking.currentPlayers.clamp(0, 3), 
                      (index) => _buildStackedAvatar(index, 'https://ui-avatars.com/api/?name=Player+${index+1}&background=random&color=fff')
                    ),
                  ),
                ),
              const SizedBox(width: VSPSpacing.xs),
              
              // Remaining text: "X spots left"
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.6)),
                    children: [
                      TextSpan(
                        text: "$remainingPlayers",
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                      ),
                      const TextSpan(text: " spots left"),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

    Widget _buildInfoColumn(String label, String value) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center, // ALL centered
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      );
    }

  Widget _buildStackedAvatar(int index, String url) {
    return Positioned(
      left: index * 18.0,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF2D4B15), width: 2),
          image: DecorationImage(
            image: NetworkImage(url),
            fit: BoxFit.cover,
          ),
        ),
      ),
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
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Joined Match Successfully!", style: TextStyle(color: VSPColors.background)),
          backgroundColor: VSPColors.accent,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to join match."), backgroundColor: VSPColors.error),
      );
    }
  }

  void _handleLeave(BuildContext context, String userId) async {
    setState(() => _isLoading = true);
    final success = await DatabaseService().leavePublicMatch(widget.booking.id, userId);
    if (!context.mounted) return;
    setState(() => _isLoading = false);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Left Match Successfully."),
          backgroundColor: VSPColors.warning,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to leave match."), backgroundColor: VSPColors.error),
      );
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

  // دالة صغيرة لتقصير شكل الوقت عشان يكفي المربع
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Participant removed."), backgroundColor: VSPColors.warning),
      );
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
                Text(
                  "Manage Match",
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: VSPColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
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
                              backgroundImage: (user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty)
                                ? NetworkImage(user.profileImageUrl!)
                                : null,
                              child: (user.profileImageUrl == null || user.profileImageUrl!.isEmpty)
                                ? const Icon(Icons.person, color: VSPColors.accent, size: 20)
                                : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        user.name ?? "Player",
                                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      if (isHost) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: VSPColors.accent.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: VSPColors.accent, width: 0.5),
                                          ),
                                          child: const Text(
                                            "HOST",
                                            style: TextStyle(color: VSPColors.accent, fontSize: 8, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    user.position ?? "Midfielder",
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            if (!isHost)
                              IconButton(
                                icon: const Icon(Icons.person_remove_outlined, color: VSPColors.error, size: 20),
                                onPressed: () => _removeUser(user.uid),
                              )
                            else
                              const Padding(
                                padding: EdgeInsets.only(right: 12),
                                child: Icon(Icons.shield, color: VSPColors.accent, size: 18),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).padding.bottom + 20),
            child: SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                text: "Done",
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
