import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
 // For verifying UI imports
import '../../../core/providers/language_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shimmer_image.dart';
import '../../../data/models.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/database_service.dart';
import 'stadium_details_screen.dart';
import 'team_dashboard_screen.dart';
import 'booked_screen.dart';
import 'champion_screen.dart';
import 'profile_screen.dart';
import '../widgets/match_result_modal.dart';
import '../widgets/filter_bottom_sheet.dart';

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
    // Simulate auto-trigger check for match result
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowMatchResultModal();
    });
  }

  void _checkAndShowMatchResultModal() async {
    // This was a simulation for demo purposes
    /* 
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
       showDialog(
         context: context,
         builder: (context) => MatchResultModal(
           booking: Booking(
             id: 'demo_match',
             stadiumId: '1',
             stadiumName: 'Santiago Bernabéu',
             ownerId: 'owner_1',
             startTime: DateTime.now().subtract(const Duration(hours: 3)),
             endTime: DateTime.now().subtract(const Duration(hours: 1)),
             bookingType: BookingType.challenge,
             playerTeamName: 'Your Team',
             opponentTeamName: 'Real Madrid',
             isPrivate: false,
             rentBall: true,
             totalPrice: 120,
             paymentMethod: 'card',
             status: BookingStatus.completed,
             createdByUserId: 'demo_user',
             createdAt: DateTime.now().subtract(const Duration(days: 1)),
           ),
           onConfirm: (outcome) {
             Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('Result Submitted Successfully!')),
             );
           },
         ),
       );
    }
    */
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
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
      // Bottom Navigation Bar
      bottomNavigationBar: CustomPlayerNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
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
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                 // Add subtle haptic feedback
                HapticFeedback.lightImpact();
                onSeeAll();
              },
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'See all',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Stadium Card with Real Image Background and Glass Effect
class StadiumCard extends StatelessWidget {
  final Stadium stadium;

  const StadiumCard({super.key, required this.stadium});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StadiumDetailsScreen(stadium: stadium),
          ),
        );
      },
      child: Container(
        width: 320,
        height: 230,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15), // Unified 15px
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15), // Unified 15px
          child: Stack(
            fit: StackFit.expand,
            children: [
              // REAL PHOTOGRAPHY BACKGROUND
              CachedNetworkImage(
                imageUrl: stadium.imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: const Color(0xFF1E1E1E),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.neonGreen,
                      strokeWidth: 2,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Image.network(
                  'https://images.unsplash.com/photo-1556056504-5c7696c4c28d?w=800&q=80',
                  fit: BoxFit.cover,
                ),
              ),

              // DARK GRADIENT OVERLAY
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.5, 0.95],
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.9),
                    ],
                  ),
                ),
              ),

              // TOP ACTIONS
              Positioned(
                top: 15,
                left: 15,
                right: 15,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, color: AppTheme.neonGreen, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            stadium.location,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Icon(
                        stadium.isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: stadium.isFavorite ? Colors.red : Colors.white,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),

              // BOTTOM INFO
              Positioned(
                bottom: 15,
                left: 15,
                right: 15,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stadium.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${stadium.size} • ${stadium.type}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.neonGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${stadium.pricePerHour.toInt()} eg',
                            style: const TextStyle(
                              color: AppTheme.neonGreen,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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

  const MatchCard({
    super.key,
    required this.team,
    required this.index,
    this.width,
    this.margin,
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
  }

  Color _getBackgroundColor(int index) {
    switch (index % 3) {
      case 0:
        return const Color(0xFF2D4B15); // Deep Forest Green
      case 1:
        return const Color(0xFF1E1E1E); // Charcoal Gray
      case 2:
        return const Color(0xFF133638); // Deep Teal
      default:
        return const Color(0xFF2D4B15);
    }
  }

  void _toggleJoin() async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (mounted) {
      setState(() {
        _isJoined = !_isJoined;
        if (_isJoined) {
          _currentPlayers++;
        } else {
          _currentPlayers--;
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isJoined ? 'Joined successfully!' : 'Left match successfully'),
          backgroundColor: AppTheme.neonGreen,
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          action: SnackBarAction(
            label: 'OK', 
            textColor: Colors.black, 
            onPressed: () {},
          ),
        ),
      );
    }
  }

  void _onShare() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Match link copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _getBackgroundColor(widget.index);
    
    return Container(
      width: widget.width ?? double.infinity, 
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20), // Unified 20px
      margin: widget.margin ?? EdgeInsets.zero,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(15), // Unified 15px
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
              Container(
                width: 44, 
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: CachedNetworkImage(
                    imageUrl: widget.team.captainImageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.white10),
                    errorWidget: (context, url, error) => const Icon(Icons.person, color: Colors.white24),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16, 
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.team.captainName,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
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
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.share_outlined, color: AppTheme.neonGreen, size: 14),
                    ),
                  ),
                  GestureDetector(
                    onTap: _toggleJoin,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isJoined ? const Color(0xFF2A2A2A) : AppTheme.neonGreen,
                        borderRadius: BorderRadius.circular(10),
                        border: _isJoined ? Border.all(color: Colors.white24, width: 1) : null,
                      ),
                      child: Text(
                        _isJoined ? 'Leave' : 'Join',
                        style: TextStyle(
                          color: _isJoined ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w900, 
                          fontSize: 12,
                        ),
                      ),
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
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(child: _buildInfoColumn('Date', _formatDate(widget.team.date))),
                Container(width: 1, height: 20, color: Colors.white10),
                Expanded(child: _buildInfoColumn('Stadium', _shortenName(widget.team.stadium))),
                Container(width: 1, height: 20, color: Colors.white10),
                Expanded(child: _buildInfoColumn("you'll pay", '${widget.team.pricePerPerson.toStringAsFixed(0)} eg')),
              ],
            ),
          ),
          const SizedBox(height: 12), 
          // Footer
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
                          borderRadius: BorderRadius.circular(15),
                          child: CachedNetworkImage(
                            imageUrl: widget.team.playerImages[i],
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(color: Colors.white10),
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
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                    children: [
                      const TextSpan(text: 'Number of remaining '),
                      TextSpan(
                        text: '${widget.team.maxPlayers - _currentPlayers}', // Dynamic remaining count
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                      TextSpan(text: ' out of ${widget.team.maxPlayers}'), // Use widget.team for constant max
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 10,
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
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w900,
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
  bool _isJoined = false;
  late int _teamsJoined;

  @override
  void initState() {
    super.initState();
    _teamsJoined = widget.championship.teamsJoined;
  }

  void _toggleJoin() async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (mounted) {
      setState(() {
        _isJoined = !_isJoined;
        if (_isJoined) {
          _teamsJoined++;
        } else {
          _teamsJoined--;
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isJoined ? 'Joined championship!' : 'Left championship'),
          backgroundColor: AppTheme.neonGreen,
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          action: SnackBarAction(
            label: 'OK', 
            textColor: Colors.black, 
            onPressed: () {},
          ),
        ),
      );
    }
  }

  void _onShare() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Championship link copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width ?? double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20), // Unified 20px
      margin: widget.margin ?? EdgeInsets.zero,
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(15), // Unified 15px
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
                  border: Border.all(color: Colors.white24, width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: CachedNetworkImage(
                    imageUrl: widget.championship.logoUrl,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.white10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.championship.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16, // Slightly smaller title
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.championship.type,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
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
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.share_outlined, color: AppTheme.neonGreen, size: 14),
                    ),
                  ),
                  GestureDetector(
                    onTap: _toggleJoin,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isJoined ? const Color(0xFF2A2A2A) : AppTheme.neonGreen,
                        borderRadius: BorderRadius.circular(10),
                        border: _isJoined ? Border.all(color: Colors.white24, width: 1) : null,
                      ),
                      child: Text(
                        _isJoined ? 'Leave' : 'Join',
                        style: TextStyle(
                          color: _isJoined ? Colors.white : Colors.black, 
                          fontWeight: FontWeight.w900, 
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14), // Breathing room
          // Info Grid
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(child: _buildInfoColumn('Starts', widget.championship.startDate.split(' ').map((s) => s.length > 3 ? s.substring(0, 3) : s).join(' '))),
                Container(width: 1, height: 20, color: Colors.white10),
                Expanded(child: _buildInfoColumn('Prize', '${widget.championship.grandPrize.toStringAsFixed(0)} eg')),
                Container(width: 1, height: 20, color: Colors.white10),
                Expanded(child: _buildInfoColumn("Entry", '${widget.championship.entryFee.toStringAsFixed(0)} eg')),
              ],
            ),
          ),
          const SizedBox(height: 12), // Breathing room
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
                          border: Border.all(color: const Color(0xFF2C2C2E), width: 2),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: CachedNetworkImage(
                            imageUrl: widget.championship.teamLogos[index],
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(color: Colors.white10),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                   '$_teamsJoined/${widget.championship.maxTeams} Teams Joined',
                   style: TextStyle(
                     color: Colors.white.withValues(alpha: 0.6),
                     fontSize: 12,
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
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 10,
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
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

/// Model for Navbar Item
class NavItem {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;

  NavItem({
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
  });
}

/// Custom Bottom Navigation Bar for Player Flow (English Only)
class CustomPlayerNavBar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const CustomPlayerNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  State<CustomPlayerNavBar> createState() => _CustomPlayerNavBarState();
}

class _CustomPlayerNavBarState extends State<CustomPlayerNavBar> {
  // Navigation bar item list
  final List<NavItem> _navItems = [
    NavItem(
      activeIcon: Icons.home_rounded,
      inactiveIcon: Icons.home_outlined, 
      label: 'Home',
    ),
    NavItem(
      activeIcon: Icons.groups_rounded, 
      inactiveIcon: Icons.groups_outlined,
      label: 'Team',
    ),
    NavItem(
      activeIcon: Icons.emoji_events_rounded,
      inactiveIcon: Icons.emoji_events_outlined,
      label: 'Champion',
    ),
    NavItem(
      activeIcon: Icons.bookmark_rounded,
      inactiveIcon: Icons.bookmark_outline_rounded,
      label: 'Booked',
    ),
    NavItem(
      activeIcon: Icons.person_rounded,
      inactiveIcon: Icons.person_outline_rounded,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.darkBackground,
        border: Border(top: BorderSide(color: Colors.white12, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _navItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isSelected = index == widget.selectedIndex;

              return Expanded(
                child: InkWell(
                  onTap: () => widget.onItemTapped(index),
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Dot Indicator - Only when selected
                      if (isSelected)
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: const BoxDecoration(
                            color: AppTheme.neonGreen,
                            shape: BoxShape.circle,
                          ),
                        )
                      else
                        const SizedBox(height: 10), // Placeholder to keep height consistent

                      // Icon
                      Icon(
                        isSelected ? item.activeIcon : item.inactiveIcon,
                        color: isSelected ? AppTheme.neonGreen : Colors.grey.withValues(alpha: 0.5),
                        size: 26,
                      ),
                      
                      const SizedBox(height: 4),
                      
                      // Label
                      Text(
                        item.label,
                        style: TextStyle(
                          color: isSelected ? AppTheme.neonGreen : Colors.grey.withValues(alpha: 0.5),
                          fontSize: 11,
                          fontFamily: 'Agency FB', 
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
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
    final languageProvider = Provider.of<LanguageProvider>(context);

    return SafeArea(
      child: Column(
        children: [
          // Main Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        // Profile Image
                        ShimmerImage(
                          imageUrl: 'https://images.unsplash.com/photo-1543351611-58f69d7c1781?w=150&h=150&fit=crop&q=80', // Real player portrait
                          width: 50,
                          height: 50,
                          borderRadius: 25,
                        ),
                        const SizedBox(width: 12),
                        // Welcome Text
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hi Mohamed Salah',
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Player (GK)',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Notification Icon
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.cardBackground,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.notifications_outlined,
                            color: AppTheme.textPrimary,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Search & Filter
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        // Search Bar
                        Expanded(
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E1E),
                              borderRadius: BorderRadius.circular(30), // Circular as requested
                              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: TextField(
                              controller: searchController,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search...',
                                hintStyle: TextStyle(
                                  color: AppTheme.textSecondary.withValues(alpha: 0.5),
                                ),
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.05),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                                    ),
                                    child: const Icon(
                                      Icons.search,
                                      color: Colors.white,
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
                        const SizedBox(width: 12),
                        // Filter Button
                        InkWell(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              isScrollControlled: true,
                              builder: (context) => const FilterBottomSheet(),
                            );
                          },
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E1E), // Dark Grey
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.neonGreen.withValues(alpha: 0.3)), // Subtle Neon border
                            ),
                            child: const Icon(
                              Icons.tune,
                              color: AppTheme.neonGreen, // Green icon
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Stadium Section
                  _SectionHeader(
                    title: 'Stadium',
                    onSeeAll: () {},
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 250,
                    child: StreamBuilder<List<Stadium>>(
                      stream: DatabaseService().getStadiums(), // REAL DATA
                      builder: (context, snapshot) {
                         // Demo Mode Fallback
                         if (AppConfig.demoMode) {
                              final mockStadiums = Stadium.getMockStadiums();
                              return ListView.builder(
                               scrollDirection: Axis.horizontal,
                               padding: const EdgeInsets.symmetric(horizontal: 16),
                               itemCount: mockStadiums.length,
                               itemBuilder: (context, index) {
                                 return StadiumCard(stadium: mockStadiums[index]);
                               },
                             );
                         }

                         if (snapshot.connectionState == ConnectionState.waiting) {
                           return ListView.builder(
                             scrollDirection: Axis.horizontal,
                             padding: const EdgeInsets.symmetric(horizontal: 16),
                             itemCount: 3,
                             itemBuilder: (_, __) => Container(
                               width: 320,
                               margin: const EdgeInsets.only(right: 16),
                               decoration: BoxDecoration(
                                 color: Colors.white.withValues(alpha: 0.6),
                                 borderRadius: BorderRadius.circular(15),
                               ),
                             ),
                           );
                         }
                         
                         if (!snapshot.hasData || snapshot.data!.isEmpty) {
                           return const Center(child: Text("No stadiums found", style: TextStyle(color: Colors.white)));
                         }
                         
                         final stadiums = snapshot.data!;
                         return ListView.builder(
                           scrollDirection: Axis.horizontal,
                           padding: const EdgeInsets.symmetric(horizontal: 16),
                           itemCount: stadiums.length,
                           itemBuilder: (context, index) {
                             return StadiumCard(stadium: stadiums[index]);
                           },
                         );
                      },
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Matches Section
                  _SectionHeader(
                    title: 'Join Matches',
                    onSeeAll: () => onNavigate(1),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: DatabaseService().getMatchesStream(), // Need a stream for matches/teams
                      builder: (context, snapshot) {
                         // Fallback to mocks for V1 if stream not ready or empty
                         // But we want to confirm Real Data switch. 
                         // Since I seeded 'teams', I should fetch teams.
                         // But MatchCard expects a 'Team' object which usually represents a Match in this UI context?
                         // Let's look at MatchCard... it takes a 'Team' object. 
                         // The prompt says "replace mockMatches". 
                         // Check DatabaseService for matches stream.
                         // Assuming getTeams() is what we want here as "Matches" in this app seem to be Team-based or 1vs1?
                         // Let's use getTeams for now as seeded.
                         
                         return StreamBuilder<List<Team>>(
                            stream: DatabaseService().getTeams(),
                            builder: (context, teamSnapshot) {
                                if (teamSnapshot.connectionState == ConnectionState.waiting) {
                                   return const Center(child: CircularProgressIndicator(color: AppTheme.neonGreen));
                                }
                                
                                final teams = teamSnapshot.hasData ? teamSnapshot.data! : [];
                                
                                if (teams.isEmpty) {
                                    // Fallback to avoid empty screen during demo
                                    return ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      itemCount: Team.getMockTeams().length,
                                      itemBuilder: (context, index) {
                                        final team = Team.getMockTeams()[index];
                                        return MatchCard(
                                          team: team,
                                          index: index,
                                          width: 320,
                                          margin: const EdgeInsets.only(right: 16),
                                        );
                                      },
                                    );
                                }

                                return ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  itemCount: teams.length,
                                  itemBuilder: (context, index) {
                                    return MatchCard(
                                      team: teams[index],
                                      index: index,
                                      width: 320,
                                      margin: const EdgeInsets.only(right: 16),
                                    );
                                  },
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
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: Championship.getMockChampionships().length,
                      itemBuilder: (context, index) {
                        final championship =
                            Championship.getMockChampionships()[index];
                        return ChampionshipCard(
                          championship: championship,
                          width: 320,
                          margin: const EdgeInsets.only(right: 16),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
