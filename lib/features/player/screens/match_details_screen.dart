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
import '../../../core/repositories/user_repository.dart';

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
      VSPFeedback.showError(context, AppLocalizations.of(context)!.loginToJoinError);
      return;
    }

    setState(() => _isJoining = true);
    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    final success = await bookingProvider.joinPublicMatch(widget.bookingId, auth.currentUser!.uid);
    
    if (mounted) {
      setState(() => _isJoining = false);
      if (success) {
        VSPFeedback.showSuccess(context, AppLocalizations.of(context)!.matchJoinSuccess);
        _fetchMatchDetails(); // Refresh
      }
    }
  }

  void _onReport() {
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
                      final success = await UserRepository().reportEntity(
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
              Icon(Icons.error_outline, color: VSPColors.error, size: 48),
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
                          AppLocalizations.of(context)!.vsMatchFormat('${(_booking!.maxPlayers ~/ 2)}', '${(_booking!.maxPlayers ~/ 2)}'),
                          style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: VSPSpacing.md),
                  
                  _buildDetailRow(Icons.calendar_today, AppLocalizations.of(context)!.date, _booking!.formattedDate),
                  _buildDetailRow(Icons.access_time, AppLocalizations.of(context)!.time, _booking!.formattedTimeRange),
                  _buildDetailRow(Icons.location_on, AppLocalizations.of(context)!.location, _stadium?.location ?? 'Unknown'),
                  
                  const Divider(color: VSPColors.divider, height: 40),
                  
                  Text(
                    AppLocalizations.of(context)!.playersCount(_booking!.joinedUserIds.length, _booking!.maxPlayers),
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
                        title: Text(AppLocalizations.of(context)!.playerLabel(index + 1), style: const TextStyle(color: Colors.white)),
                        trailing: index == 0 ? Text(AppLocalizations.of(context)!.host, style: const TextStyle(color: VSPColors.accent)) : null,
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
          text: alreadyJoined ? AppLocalizations.of(context)!.joined : (isFull ? AppLocalizations.of(context)!.matchFull : AppLocalizations.of(context)!.joinMatch),
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
