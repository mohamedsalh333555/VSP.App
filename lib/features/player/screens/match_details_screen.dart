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
import '../../../core/services/database_service.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchMatchDetails();
  }

  Future<void> _fetchMatchDetails() async {
    setState(() => _isLoading = true);
    try {
      final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
      final stadiumProvider = Provider.of<StadiumProvider>(context, listen: false);

      // Fetch booking
      final booking = await bookingProvider.getBookingById(widget.bookingId);
      if (booking != null) {
        _booking = booking;
        // Fetch stadium
        _stadium = await stadiumProvider.getStadiumById(booking.stadiumId);
      }
    } catch (e) {
      debugPrint('Error fetching match details: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onJoin() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      VSPFeedback.showError(context, 'Please login to join matches');
      return;
    }

    setState(() => _isJoining = true);
    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    final success = await bookingProvider.joinPublicMatch(widget.bookingId, auth.currentUser!.uid);
    
    if (mounted) {
      setState(() => _isJoining = false);
      if (success) {
        VSPFeedback.showSuccess(context, 'Successfully joined the match!');
        _fetchMatchDetails(); // Refresh
      }
    }
  }

  void _onReport() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      VSPFeedback.showError(context, 'Please login to report');
      return;
    }

    String selectedReason = 'Spam';
    final List<String> reasons = ['Spam', 'Inappropriate Content', 'Harassment', 'Fake Match', 'Other'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: VSPColors.surface,
          title: const Text('Report Match', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Help us maintain a safe community. Why are you reporting this match?',
                style: TextStyle(color: VSPColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              DropdownButton<String>(
                value: selectedReason,
                dropdownColor: VSPColors.surface,
                isExpanded: true,
                items: reasons.map((r) => DropdownMenuItem(
                  value: r,
                  child: Text(r, style: const TextStyle(color: Colors.white)),
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
                    text: 'Cancel',
                    height: 48,
                    color: VSPColors.surfaceAlt,
                    textColor: VSPColors.textPrimary,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: VSPSpacing.md),
                Expanded(
                  child: PrimaryButton(
                    text: 'Report',
                    height: 48,
                    color: VSPColors.error,
                    textColor: Colors.white,
                    onPressed: () async {
                      final success = await DatabaseService().reportEntity(
                        reporterId: auth.currentUser!.uid,
                        targetId: widget.bookingId,
                        targetType: 'match',
                        reason: selectedReason,
                      );
                      if (mounted) {
                        Navigator.pop(context);
                        if (success) {
                          VSPFeedback.showSuccess(context, 'Report submitted for review.');
                        } else {
                          VSPFeedback.showError(context, 'Failed to submit report.');
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

  @override
  Widget build(BuildContext context) {
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
              const Icon(Icons.error_outline, color: VSPColors.error, size: 48),
              const SizedBox(height: 16),
              const Text('Match not found', style: TextStyle(color: Colors.white)),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go back', style: TextStyle(color: VSPColors.accent)),
              )
            ],
          ),
        ),
      );
    }

    final isHost = _booking!.createdByUserId == Provider.of<AuthProvider>(context, listen: false).currentUser?.uid;
    final isFull = _booking!.joinedUserIds.length >= _booking!.maxPlayers;
    final alreadyJoined = _booking!.joinedUserIds.contains(Provider.of<AuthProvider>(context, listen: false).currentUser?.uid);

    return Scaffold(
      backgroundColor: VSPColors.background,
      body: CustomScrollView(
        slivers: [
          // Header Widget with Stadium Image
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: VSPColors.background,
            actions: [
              IconButton(
                icon: const Icon(Icons.share, color: Colors.white),
                onPressed: () {
                  if (_booking != null) {
                    SharingService.shareMatch(
                      bookingId: widget.bookingId,
                      teamName: 'VSP Public Match',
                      stadiumName: _stadium?.name ?? 'Stadium',
                      date: '${_booking!.formattedDate} at ${_booking!.formattedTimeRange}',
                    );
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.report_problem_outlined, color: VSPColors.textSecondary),
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
                          'Public Match at ${_stadium?.name ?? "Stadium"}',
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
                          '${(_booking!.maxPlayers ~/ 2)} VS ${(_booking!.maxPlayers ~/ 2)}',
                          style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: VSPSpacing.md),
                  
                  _buildDetailRow(Icons.calendar_today, 'Date', _booking!.formattedDate),
                  _buildDetailRow(Icons.access_time, 'Time', _booking!.formattedTimeRange),
                  _buildDetailRow(Icons.location_on, 'Location', _stadium?.location ?? 'Unknown'),
                  
                  const Divider(color: VSPColors.divider, height: 40),
                  
                  Text(
                    'Players (${_booking!.joinedUserIds.length}/${_booking!.maxPlayers})',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: VSPSpacing.md),
                  
                  // Players List
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _booking!.joinedUserIds.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: VSPColors.surface,
                          child: Icon(Icons.person, color: VSPColors.textSecondary),
                        ),
                        title: Text('Player ${index + 1}', style: const TextStyle(color: Colors.white)),
                        trailing: index == 0 ? const Text('Host', style: TextStyle(color: VSPColors.accent)) : null,
                      );
                    },
                  ),
                  
                  const SizedBox(height: 100), // Space for bottom button
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(VSPSpacing.lg),
        color: VSPColors.background,
        child: PrimaryButton(
          text: alreadyJoined ? 'Joined' : (isFull ? 'Match Full' : 'Join Match'),
          onPressed: (alreadyJoined || isFull || isHost) ? null : _onJoin,
          isLoading: _isJoining,
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
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
      ),
    );
  }
}
