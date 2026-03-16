import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../shared/widgets/vsp_bottom_nav_bar.dart';
import 'package:flutter/services.dart'; 
import 'dart:ui';
import 'package:intl/intl.dart';
import 'championship_details_screen.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../data/models.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/database_service.dart';
import 'stadium_details_screen.dart';
import 'team_dashboard_screen.dart';
import 'booked_screen.dart';
import 'champion_screen.dart';
import 'profile_screen.dart';
import 'notifications_center_screen.dart';
import '../../../core/ui/components/vsp_section_title.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../../../shared/widgets/stadium_card.dart';
import '../../../shared/widgets/vsp_fade_in_item.dart';
import '../../../core/utils/vsp_feedback.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/providers/stadium_provider.dart';
import '../widgets/match_result_modal.dart';

/// Player Home Page (English Only)
class PlayerHomeScreen extends StatefulWidget {
  const PlayerHomeScreen({super.key});

  @override
  State<PlayerHomeScreen> createState() => _PlayerHomeScreenState();
}

class _PlayerHomeScreenState extends State<PlayerHomeScreen> {
  int _selectedIndex = 0;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Fetch stadiums data via provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<StadiumProvider>(context, listen: false).listenToStadiums();
      _checkAndShowMatchResultModal();
    });
  }

  void _checkAndShowMatchResultModal() async {
    // Wait a moment for providers to load data
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    final userId = authProvider.currentUser?.uid;
    if (userId == null) return;

    // Get user's team to know their teamId
    final myTeam = await DatabaseService().getUserTeam(userId);
    final myTeamId = myTeam?.id;

    if (!mounted) return;

    // Find first challenge booking that needs a result from this user
    final historyBookings = bookingProvider.historyBookings;
    for (final booking in historyBookings) {
      // 🚨 STRICT CHECK: ONLY Challenge mode with a valid opponent MUST trigger result prompt.
      if (booking.bookingType != BookingType.challenge) continue;
      if (booking.opponentTeamId == null || booking.playerTeamId == null) continue;
      
      if (booking.matchResultStatus == MatchResultStatus.confirmed) continue;
      if (booking.matchResultStatus.toString().contains('disputed')) continue;

      // If this user already submitted their result, skip
      if (booking.resultSubmittedByTeamId == myTeamId && myTeamId != null) continue;

      // Found a booking needing result submission!
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => MatchResultModal(
            booking: booking,
            submittingTeamId: myTeamId ?? userId,
            onConfirm: (outcome, rating, review) async {
              final success = await bookingProvider.submitMatchResult(
                bookingId: booking.id,
                teamId: myTeamId ?? userId,
                outcome: outcome,
                rating: rating,
                review: review,
              );
              if (ctx.mounted) {
                Navigator.pop(ctx);
                if (success) {
                  VSPFeedback.showSuccess(ctx, 'Result submitted!');
                }
              }
            },
          ),
        );
      }
      break; // Only show one at a time
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: VSPColors.background,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // 0: Home
          _HomeContent(
            searchController: _searchController,
            onNavigate: (index, {arguments}) {
              setState(() {
                _selectedIndex = index;
                // If arguments are passed, we might need a way to pass them to the destination screen.
                // For a simple tab switch within IndexedStack, screens mainly preserve state.
                // However, specifically for ChampionScreen, users want to switch internal tabs.
                // We'll use a GlobalKey or a broadcast system, but since IndexedStack keeps state,
                // we can just pass parameters if the screen was rebuilt, OR, better:
                // Use a static/global method or event bus. simpler here:
                if (index == 2 && arguments != null && arguments['initialTab'] != null) {
                   // This is a quick fix for the task using a specialized event/notification or just re-creating.
                   // Ideally, we'd use a Provider approach, but let's try a static key approach for simplicity if allowed.
                   // Actually, since IndexedStack keeps the widget alive, passing constructor params only works on init.
                   // We will use a notification listener or a simple provider method.
                   // Let's assume we can trigger a method on the ChampionScreen via a key.
                   championScreenKey.currentState?.switchToTab(arguments['initialTab']);
                }
              });
            },
          ),
          // 1: Team
          const TeamDashboardScreen(),
          // 2: Champion
          ChampionScreen(key: championScreenKey),
          // 3: Booked
          const BookedScreen(),
          // 4: Profile
          const ProfileScreen(),
        ],
      ),
      // Bottom Navigation Bar - Updated to use Unified Widget
      bottomNavigationBar: VspBottomNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: [
          VspNavItem(
            activeIcon: Icons.home_rounded,
            inactiveIcon: Icons.home_outlined, 
            label: 'Home',
          ),
          VspNavItem(
            activeIcon: Icons.groups_rounded, 
            inactiveIcon: Icons.groups_outlined,
            label: 'Matches',
          ),
          VspNavItem(
            activeIcon: Icons.emoji_events_rounded,
            inactiveIcon: Icons.emoji_events_outlined,
            label: 'Champion',
          ),
          VspNavItem(
            activeIcon: Icons.bookmark_rounded,
            inactiveIcon: Icons.bookmark_outline_rounded,
            label: 'Booked',
          ),
          VspNavItem(
            activeIcon: Icons.person_rounded,
            inactiveIcon: Icons.person_outline_rounded,
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

/// Section Header with "See all" button
class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onSeeAll;

  const _SectionHeader({
    required this.title,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          VSPSectionTitle(title),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                 // Add subtle haptic feedback
                HapticFeedback.lightImpact();
                onSeeAll();
              },
              borderRadius: BorderRadius.circular(VSPRadius.xs),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'See all',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: VSPColors.textSecondary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Match Card - High-Fidelity Professional Design
class MatchCard extends StatefulWidget {
  final Team team;
  final int index;
  final double? width;
  final EdgeInsetsGeometry? margin;
  final Booking? booking;

  const MatchCard({
    super.key,
    required this.team,
    required this.index,
    this.width,
    this.margin,
    this.booking,
  });

  @override
  State<MatchCard> createState() => _MatchCardState();
}

class _MatchCardState extends State<MatchCard> {
  bool _isJoined = false;
  late int _currentPlayers;

  @override
  void initState() {
    super.initState();
    _currentPlayers = widget.team.currentPlayers;
    
    // Check if user is already in joinedUserIds if booking is provided
    if (widget.booking != null) {
      final userId = Provider.of<AuthProvider>(context, listen: false).currentUser?.uid ?? '';
      _isJoined = widget.booking!.joinedUserIds.contains(userId);
    }
  }

  Color _getBackgroundColor(int index) {
    switch (index % 3) {
      case 0:
        return const Color(0xFF2D4B15); // Keeping these specific decorative colors as they define the "Match Card" variety
      case 1:
        return const Color(0xFF1E1E1E); 
      case 2:
        return const Color(0xFF133638);
      default:
        return const Color(0xFF2D4B15);
    }
  }

  void _toggleJoin() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      VSPFeedback.showError(context, 'Please login to join matches');
      return;
    }

    final userId = auth.currentUser!.uid;
    final db = DatabaseService();
    
    // If we have a real booking, use DB transaction
    if (widget.booking != null) {
      setState(() => _isLoading = true);
      
      bool success = false;
      if (!_isJoined) {
        success = await db.joinPublicMatch(widget.booking!.id, userId);
      } else {
        // We might want to add leaveMatch for bookings too, but for now we follow the task
        // which focused on joinMatch. If needed I can add leavePublicMatch later.
        // For now, let's keep it simple as per instructions.
        success = true; // Placeholder for leave logic if not defined
      }

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
           setState(() {
            _isJoined = !_isJoined;
            if (_isJoined) {
              _currentPlayers++;
            } else {
              _currentPlayers--;
            }
           });
        }
      }
    } else {
      // Fallback for mock/UI testing
      setState(() {
        _isJoined = !_isJoined;
        if (_isJoined) {
          _currentPlayers++;
        } else {
          _currentPlayers--;
        }
      });
    }
  }

  bool _isLoading = false;

  void _onShare() {
    final shareContent = 'Match on VSP: ${widget.team.name} vs ${widget.team.stadium} - Ref# ${widget.team.id}';
    Clipboard.setData(ClipboardData(text: shareContent));
    VSPFeedback.showSuccess(context, 'Match reference copied to clipboard!');
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _getBackgroundColor(widget.index);
    
    return Container(
      width: widget.width ?? double.infinity, 
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      margin: widget.margin ?? EdgeInsets.zero,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(VSPRadius.md), 
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25), 
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start, 
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Section
          Row(
            children: [
              if (widget.booking?.bookingType == BookingType.challenge) ...[
                // Challenge View: Team A vs Team B
                Expanded(
                  child: Row(
                    children: [
                      _buildTeamAvatar(widget.booking!.playerTeamName ?? 'Team A'),
                      const SizedBox(width: 8),
                      Text('VS', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: VSPColors.accent, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      _buildTeamAvatar(widget.booking!.opponentTeamName ?? 'Team B'),
                    ],
                  ),
                ),
              ] else ...[
                // Standard Public/Team View
                Container(
                  width: 44, 
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: VSPColors.textPrimary.withValues(alpha: 0.1), width: 1.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(VSPRadius.full),
                    child: CachedNetworkImage(
                      imageUrl: widget.team.captainImageUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 80,
                      memCacheHeight: 80,
                      placeholder: (context, url) => Container(color: VSPColors.surface),
                      errorWidget: (context, url, error) => const Icon(Icons.person, color: VSPColors.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.team.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.team.captainName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: _onShare,
                    child: Container(
                      width: 30,
                      height: 30,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: VSPColors.textPrimary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.share_outlined, color: VSPColors.accent, size: 14),
                    ),
                  ),
                  SizedBox(
                    height: 32,
                    child: PrimaryButton(
                      text: _isJoined ? 'Leave' : 'Join Match',
                      isLoading: _isLoading,
                      color: _isJoined ? VSPColors.surface : VSPColors.accent,
                      textColor: _isJoined ? VSPColors.textPrimary : VSPColors.background,
                      onPressed: _isLoading ? null : _toggleJoin,
                      padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14), 
              // Info Grid
              Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: BoxDecoration(
              color: VSPColors.background.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(VSPRadius.sm),
            ),
            child: Row(
              children: [
                Expanded(child: _buildInfoColumn('Date', _formatDate(widget.team.date))),
                Container(width: 1, height: 20, color: VSPColors.divider.withValues(alpha: 0.2)),
                Expanded(child: _buildInfoColumn('Stadium', _shortenName(widget.team.stadium))),
                Container(width: 1, height: 20, color: VSPColors.divider.withValues(alpha: 0.2)),
                Expanded(child: _buildInfoColumn("you'll pay", '${widget.team.pricePerPerson.toStringAsFixed(0)} eg')),
              ],
            ),
          ),
          const SizedBox(height: 12), 
          // Footer with Progress Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 90,
                    height: 32,
                    child: Stack(
                      children: List.generate(
                        widget.team.playerImages.take(4).length,
                        (i) => Positioned(
                          left: i * 20.0,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: bgColor, width: 2),
                            ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(VSPRadius.full),
                                child: CachedNetworkImage(
                                  imageUrl: widget.team.playerImages[i],
                                  fit: BoxFit.cover,
                                  memCacheWidth: 60,
                                  memCacheHeight: 60,
                                  placeholder: (context, url) => Container(color: VSPColors.textPrimary.withValues(alpha: 0.1)),
                                ),
                              ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
                        children: [
                          const TextSpan(text: 'Number of remaining '),
                          TextSpan(
                            text: '${widget.team.maxPlayers - _currentPlayers}', 
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: VSPColors.textPrimary),
                          ),
                          TextSpan(text: ' out of ${widget.team.maxPlayers}'), 
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Availability Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(VSPRadius.xs),
                child: LinearProgressIndicator(
                  value: _currentPlayers / (widget.team.maxPlayers > 0 ? widget.team.maxPlayers : 1),
                  backgroundColor: VSPColors.divider.withValues(alpha: 0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(VSPColors.accent),
                  minHeight: 4,
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatDate(String fullDate) {
    if (fullDate.contains('August')) return 'Aug ${fullDate.split(' ')[1].replaceAll('th', '')}';
    return fullDate.split(' ')[0];
  }

  String _shortenName(String name) {
    if (name.length > 7) {
       return '${name.substring(0, 5)}..';
    }
    return name;
  }

  Widget _buildTeamAvatar(String name) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: VSPColors.textPrimary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: VSPColors.textPrimary.withValues(alpha: 0.1), width: 1),
          ),
          child: const Center(child: Icon(Icons.shield, color: VSPColors.accent, size: 16)),
        ),
        const SizedBox(height: 4),
        Text(
          name.length > 8 ? '${name.substring(0, 6)}..' : name,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textPrimary, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

/// Championship Card with optimized image loading
class ChampionshipCard extends StatefulWidget {
  final Championship championship;
  final double? width;
  final EdgeInsetsGeometry? margin;

  const ChampionshipCard({
     super.key, 
     required this.championship,
     this.width,
     this.margin,
  });

  @override
  State<ChampionshipCard> createState() => _ChampionshipCardState();
}

class _ChampionshipCardState extends State<ChampionshipCard> {
  late int _teamsJoined;

  @override
  void initState() {
    super.initState();
    _teamsJoined = widget.championship.teamsJoined;
  }

  void _onShare() {
    final shareContent = 'Tournament on VSP: ${widget.championship.name} - Ref# ${widget.championship.id}';
    Clipboard.setData(ClipboardData(text: shareContent));
    VSPFeedback.showSuccess(context, 'Championship reference copied to clipboard!');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width ?? double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      margin: widget.margin ?? EdgeInsets.zero,
      decoration: BoxDecoration(
        color: VSPColors.surfaceAlt,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        boxShadow: VSPShadow.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // Essential for auto-sizing
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44, // Slightly smaller avatar
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: VSPColors.textPrimary.withValues(alpha: 0.1), width: 1.5),
                ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(VSPRadius.full),
                    child: CachedNetworkImage(
                    imageUrl: widget.championship.logoUrl,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    memCacheWidth: 80,
                    memCacheHeight: 80,
                    placeholder: (context, url) => Container(color: VSPColors.surface),
                  ),
                ),
              ),
              const SizedBox(width: VSPSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.championship.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.championship.type,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: _onShare,
                    child: Container(
                      width: 30,
                      height: 30,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: VSPColors.textPrimary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.share_outlined, color: VSPColors.accent, size: 14),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChampionshipDetailsScreen(championship: widget.championship),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: VSPColors.accent,
                        borderRadius: BorderRadius.circular(VSPRadius.sm),
                      ),
                      child: Text(
                        (widget.championship.status == 'ongoing' || widget.championship.status == 'completed') 
                            ? 'Brackets' 
                            : 'Join',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.black, 
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: VSPSpacing.md), // Breathing room
          // Info Grid
          Container(
            padding: const EdgeInsets.symmetric(vertical: VSPSpacing.sm, horizontal: VSPSpacing.sm),
            decoration: BoxDecoration(
              color: VSPColors.background.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(VSPRadius.sm),
            ),
            child: Row(
              children: [
                Expanded(child: _buildInfoColumn('Starts', DateFormat('MMM d').format(widget.championship.startDate))),
                Container(width: 1, height: 20, color: VSPColors.divider.withValues(alpha: 0.2)),
                Expanded(child: _buildInfoColumn('Prize', '${widget.championship.grandPrize.toStringAsFixed(0)} eg')),
                Container(width: 1, height: 20, color: VSPColors.divider.withValues(alpha: 0.2)),
                Expanded(child: _buildInfoColumn("Entry", '${widget.championship.entryFee.toStringAsFixed(0)} eg')),
              ],
            ),
          ),
          const SizedBox(height: VSPSpacing.sm), // Breathing room
          // Teams Joined
          Row(
            children: [
              SizedBox(
                width: 90,
                height: 32,
                child: Stack(
                  children: List.generate(
                    widget.championship.teamLogos.take(4).length,
                    (index) => Positioned(
                      left: index * 20.0,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: VSPColors.surface, width: 2),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(VSPRadius.full),
                          child: CachedNetworkImage(
                            imageUrl: widget.championship.teamLogos[index],
                            fit: BoxFit.cover,
                            memCacheWidth: 60,
                            memCacheHeight: 60,
                            placeholder: (context, url) => Container(color: VSPColors.surface),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: VSPSpacing.sm),
              Expanded(
                child: Text(
                   '$_teamsJoined/${widget.championship.maxTeams} Teams Joined',
                   style: Theme.of(context).textTheme.labelSmall?.copyWith(
                     color: VSPColors.textSecondary.withValues(alpha: 0.6),
                     fontWeight: FontWeight.w500,
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: VSPColors.textSecondary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: VSPColors.textPrimary,
                fontWeight: FontWeight.w900,
              ),
        ),
      ],
    );
  }
}

class _HomeContent extends StatelessWidget {
  final TextEditingController searchController;
  final Function(int, {Map<String, dynamic>? arguments}) onNavigate;

  const _HomeContent({
    required this.searchController,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // 🔹 FIXED HEADER SECTION
          Container(
            padding: const EdgeInsets.all(VSPSpacing.md),
            decoration: BoxDecoration(
              color: VSPColors.background,
              border: Border(bottom: BorderSide(color: VSPColors.divider.withValues(alpha: 0.1))),
            ),
            child: Column(
              children: [
                // Profile & Welcome Row
                Row(
                  children: [
                    // Profile Image with Consumer for instant sync
                    Consumer<AuthProvider>(
                      builder: (context, auth, _) {
                        final userProfileUrl = auth.userModel?.profileImageUrl;
                        final authLoading = auth.isLoading;
                        
                        return GestureDetector(
                          onTap: () async {
                            final picker = ImagePicker();
                            final XFile? image = await picker.pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 70,
                            );
                            if (image != null) {
                              auth.updateProfilePhoto(image);
                              if (context.mounted) {
                                VSPFeedback.showSuccess(context, 'Profile photo updated!');
                              }
                            }
                          },
                          child: Stack(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: VSPColors.divider.withValues(alpha: 0.1), width: 1),
                                ),
                                child: CircleAvatar(
                                  backgroundColor: VSPColors.surface,
                                  backgroundImage: (userProfileUrl != null && userProfileUrl.isNotEmpty)
                                      ? CachedNetworkImageProvider(userProfileUrl)
                                      : null,
                                  child: (userProfileUrl == null || userProfileUrl.isEmpty)
                                      ? Icon(Icons.person, color: VSPColors.textSecondary.withValues(alpha: 0.5), size: 28)
                                      : null,
                                ),
                              ),
                              if (authLoading)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: VSPColors.background.withValues(alpha: 0.45),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(VSPColors.accent),
                                      ),
                                    ),
                                  ),
                                ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: VSPColors.accent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.add, size: 12, color: VSPColors.background)),
                              ),
                            ],
                          ),
                        );
                      }
                    ),
                    const SizedBox(width: VSPSpacing.sm),
                    // Welcome Text
                    Expanded(
                      child: Consumer<AuthProvider>(
                        builder: (context, auth, _) {
                          final userName = auth.userModel?.name;
                          
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hi ${userName ?? "Player"}',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 2),
                              // 📍 Location Selector
                              GestureDetector(
                                onTap: () => _showLocationPicker(context, auth),
                                child: Row(
                                  children: [
                                    const Icon(Icons.location_on, color: VSPColors.accent, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      auth.userModel?.governorate ?? 'Select Location',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: VSPColors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        decoration: TextDecoration.underline,
                                        decorationColor: VSPColors.textSecondary.withValues(alpha: 0.5),
                                      ),
                                    ),
                                    const Icon(Icons.arrow_drop_down, color: VSPColors.textSecondary, size: 16),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }
                      ),
                    ),
                    // Notification Icon
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NotificationsCenterScreen(),
                          ),
                        );
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: VSPColors.surface,
                          borderRadius: BorderRadius.circular(VSPRadius.sm),
                        ),
                        child: const Icon(
                          Icons.notifications_outlined,
                          color: VSPColors.textPrimary,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: VSPSpacing.md),

                // Search & Filter
                Row(
                  children: [
                    // Search Bar
                    Expanded(
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: VSPColors.surface,
                          borderRadius: BorderRadius.circular(VSPRadius.full),
                          border: Border.all(color: VSPColors.divider.withValues(alpha: 0.1)),
                        ),
                        child: TextField(
                          controller: searchController,
                          style: Theme.of(context).textTheme.bodyMedium,
                          decoration: InputDecoration(
                            hintText: 'Search...',
                            hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: VSPColors.textSecondary.withValues(alpha: 0.5),
                            ),
                            prefixIcon: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: VSPColors.surfaceAlt,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: VSPColors.divider.withValues(alpha: 0.1)),
                                ),
                                child: const Icon(
                                  Icons.search,
                                  color: VSPColors.textPrimary,
                                  size: 18,
                                ),
                              ),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: VSPSpacing.sm),
                    // Filter Button
                    InkWell(
                      onTap: () async {
                        final result = await showModalBottomSheet<Map<String, dynamic>>(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (context) => Padding(
                            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                            child: const FilterBottomSheet(),
                          ),
                        );

                        if (result != null && context.mounted) {
                          context.read<StadiumProvider>().applyFilters(result);
                        }
                      },
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: VSPColors.surface,
                          borderRadius: BorderRadius.circular(VSPRadius.md),
                          border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(
                          Icons.tune,
                          color: VSPColors.accent,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: VSPSpacing.sm),
              ],
            ),
          ),

          // 🔹 SCROLLABLE CONTENT SECTION
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(top: VSPSpacing.lg, bottom: MediaQuery.of(context).padding.bottom + 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stadium Section
                  _SectionHeader(
                    title: 'Stadium',
                    onSeeAll: () {},
                  ),
                  const SizedBox(height: VSPSpacing.md),
                  SizedBox(
                    height: 250,
                    child: Consumer<StadiumProvider>(
                      builder: (context, provider, _) {
                         final isLoading = provider.isLoading;
                         final stadiums = provider.stadiums;

                         if (isLoading && stadiums.isEmpty) {
                           return ListView.builder(
                             scrollDirection: Axis.horizontal,
                             padding: const EdgeInsets.symmetric(horizontal: 16),
                             itemCount: 3,
                             itemBuilder: (_, __) => Container(
                               width: 320,
                               margin: const EdgeInsets.only(right: 16),
                               decoration: BoxDecoration(
                                 color: VSPColors.surface,
                                 borderRadius: BorderRadius.circular(VSPRadius.md),
                                ),
                              ),
                            );
                          }
                          
                          if (stadiums.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off, size: 48, color: VSPColors.textSecondary.withOpacity(0.3)),
                                  const SizedBox(height: 8),
                                  Text(
                                    provider.isFilterActive ? "No stadiums match your filters" : "No stadiums found", 
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary),
                                  ),
                                  if (provider.isFilterActive)
                                    TextButton(
                                      onPressed: () => provider.clearFilters(),
                                      child: const Text('Clear Filters', style: TextStyle(color: VSPColors.accent)),
                                    ),
                                ],
                              ),
                            );
                          }
                          
                           return ListView.builder(
                             scrollDirection: Axis.horizontal,
                             padding: const EdgeInsets.symmetric(horizontal: 16),
                             itemCount: stadiums.length,
                             itemBuilder: (context, index) {
                               return VSPFadeInItem(
                                 index: index,
                                 child: Container(
                                   width: 320,
                                   margin: const EdgeInsets.only(right: 16),
                                   child: StadiumCard(
                                     stadium: stadiums[index],
                                     onTap: () {
                                       Navigator.push(
                                         context,
                                         MaterialPageRoute(
                                           builder: (context) => StadiumDetailsScreen(stadium: stadiums[index]),
                                         ),
                                       );
                                      },
                                   ),
                                 ),
                               );
                             },
                           );
                       },
                    ),
                  ),

                  const SizedBox(height: VSPSpacing.xl),

                  // Matches Section
                  _SectionHeader(
                    title: 'Join Matches',
                    onSeeAll: () => onNavigate(1),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 250, // Increased height for the new card
                    child: StreamBuilder<List<Booking>>( 
                      stream: DatabaseService().getPublicMatches(), 
                      builder: (context, matchSnapshot) {
                          if (matchSnapshot.connectionState == ConnectionState.waiting) {
                             return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
                          }
                          
                          final matches = matchSnapshot.hasData ? matchSnapshot.data! : [];
                          
                          if (matches.isEmpty) {
                            return const Center(
                              child: Text(
                                "No public matches available",
                                style: TextStyle(color: VSPColors.textSecondary),
                              ),
                            );
                          }

                          return ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: matches.length,
                            itemBuilder: (context, index) {
                              return VSPFadeInItem(
                                index: index,
                                child: Container(
                                  width: 320,
                                  margin: const EdgeInsets.only(right: 16),
                                  child: PublicMatchCard(booking: matches[index]), 
                                ),
                              );
                            },
                          );
                      },
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Join Championships Section
                  _SectionHeader(
                    title: 'Join Championships',
                    onSeeAll: () => onNavigate(2, arguments: {'initialTab': 1}),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 190,
                    child: StreamBuilder<List<Championship>>(
                      stream: DatabaseService().getChampionshipsStream(
                        governorate: Provider.of<AuthProvider>(context, listen: false).userModel?.governorate,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
                        }

                        List<Championship> championships = snapshot.data ?? [];

                        // Fallback to mock only if empty AND demo mode is on
                        if (championships.isEmpty && AppConfig.demoMode) {
                          championships = Championship.getMockChampionships();
                        }

                         if (championships.isEmpty) {
                          return Center(
                            child: Text(
                              "No championships active in your area",
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary),
                            ),
                          );
                        }

                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: championships.length,
                          itemBuilder: (context, index) {
                            final championship = championships[index];
                            return VSPFadeInItem(
                              index: index,
                              child: Container(
                                width: 320,
                                margin: const EdgeInsets.only(right: 16),
                                child: ChampionshipCard(
                                  championship: championship,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 📍 Helper to show manual picker
  void _showLocationPicker(BuildContext context, AuthProvider auth) {
    final governorates = [
      'Cairo', 'Alexandria', 'Giza', 'Dakahlia', 'Red Sea', 
      'Luxor', 'Aswan', 'Gharbia', 'Port Said', 'Suez', 
      'Ismailia', 'Minya', 'Assiut', 'Qena', 'Sohag'
    ];
    
    showModalBottomSheet(
      context: context,
      backgroundColor: VSPColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.lg)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Select Location', style: Theme.of(context).textTheme.titleLarge),
                  IconButton(
                    icon: const Icon(Icons.my_location, color: VSPColors.accent),
                    onPressed: () {
                      Navigator.pop(context);
                      auth.updateUserLocation();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // List
              Expanded(
                child: ListView.builder(
                  itemCount: governorates.length,
                  itemBuilder: (context, index) {
                    final gov = governorates[index];
                    final isSelected = auth.userModel?.governorate == gov;
                    
                    return ListTile(
                      leading: Icon(
                        Icons.location_city, 
                        color: isSelected ? VSPColors.accent : VSPColors.textSecondary
                      ),
                       title: Text(
                        gov, 
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isSelected ? VSPColors.accent : VSPColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        )
                      ),
                      trailing: isSelected ? const Icon(Icons.check, color: VSPColors.accent) : null,
                      onTap: () {
                        auth.updateProfile({'governorate': gov});
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
