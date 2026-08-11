import 'dart:async';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/widgets/shimmer_image.dart';
import '../../../core/services/remote_config_service.dart';
import '../../../core/repositories/league_repository.dart';
import '../../../data/models.dart';
import '../../../shared/widgets/vsp_fade_in_item.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/vsp_feedback.dart';

class OfficialLeagueStandingsScreen extends StatefulWidget {
  const OfficialLeagueStandingsScreen({super.key});

  @override
  State<OfficialLeagueStandingsScreen> createState() => _OfficialLeagueStandingsScreenState();
}

class _OfficialLeagueStandingsScreenState extends State<OfficialLeagueStandingsScreen> {
  int _registrationCount = 0;
  bool _hasUserRegistered = false;
  bool _isRegistrationOpen = true;
  bool _isLoadingRegistration = true;
  bool _isSubmitting = false;
  StreamSubscription<int>? _registrationsSubscription;

  @override
  void initState() {
    super.initState();
    _loadRegistrationData();
    _subscribeToRegistrations();
  }

  void _subscribeToRegistrations() {
    _registrationsSubscription = LeagueRepository().stream1v1RegistrationsCount().listen((count) {
      if (mounted) {
        setState(() {
          _registrationCount = count;
        });
      }
    });
  }

  @override
  void dispose() {
    _registrationsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadRegistrationData() async {
    setState(() => _isLoadingRegistration = true);
    try {
      await RemoteConfigService().fetchConfig();
      final isOpen = RemoteConfigService().is1v1RegistrationOpen;

      final leagueRepo = LeagueRepository();
      final count = await leagueRepo.get1v1RegistrationsCount();
      
      if (!mounted) return;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final userId = auth.currentUser?.uid;
      
      bool hasRegistered = false;
      if (userId != null) {
        hasRegistered = await leagueRepo.hasUserRegistered1v1(userId);
      }
      
      if (mounted) {
        setState(() {
          _isRegistrationOpen = isOpen;
          _registrationCount = count;
          _hasUserRegistered = hasRegistered;
          _isLoadingRegistration = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading registration data: $e');
      if (mounted) setState(() => _isLoadingRegistration = false);
    }
  }

  Future<void> _handleRegistration() async {
    HapticFeedback.mediumImpact();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.userModel;
    if (user == null) {
      VSPFeedback.showError(context, 'الرجاء تسجيل الدخول أولاً للمتابعة.');
      return;
    }

    if (!_isRegistrationOpen) {
      VSPFeedback.showError(context, 'عذراً، التسجيل مغلق حالياً من قِبل الإدارة.');
      return;
    }

    if (_registrationCount >= 32) {
      VSPFeedback.showError(context, 'عذراً، اكتمل العدد المسموح به لهذه الجولة.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final success = await LeagueRepository().registerFor1v1(user.uid);
      if (mounted) {
        if (success) {
          setState(() {
            _hasUserRegistered = true;
            _registrationCount += 1;
            _isSubmitting = false;
          });
          VSPFeedback.showSuccess(context, 'تم إرسال طلب تسجيلك في بطولة 1ضد1 بنجاح! 🏆');
        } else {
          setState(() => _isSubmitting = false);
          VSPFeedback.showError(context, 'حدث خطأ أثناء التسجيل، يرجى المحاولة لاحقاً.');
        }
      }
    } catch (e) {
      debugPrint('Error handling registration: $e');
      if (mounted) {
        setState(() => _isSubmitting = false);
        VSPFeedback.showError(context, 'حدث خطأ أثناء التسجيل.');
      }
    }
  }

  Future<void> _launchHighlights() async {
    final Uri url = Uri.parse('https://instagram.com/vsp.app');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  Widget _buildRegistrationButton(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    if (_isLoadingRegistration) {
      return const SizedBox(
        height: 44,
        child: Center(
          child: CircularProgressIndicator(color: VSPColors.accent, strokeWidth: 2),
        ),
      );
    }

    String labelText;
    IconData iconData;
    VoidCallback? onPressed;
    Color buttonColor;
    Color textColor;

    if (!_isRegistrationOpen) {
      labelText = isArabic ? 'التسجيل مغلق حالياً 🛑' : 'Registration Closed 🛑';
      iconData = Iconsax.slash_copy;
      onPressed = null;
      buttonColor = VSPColors.surfaceAlt;
      textColor = VSPColors.textSecondary;
    } else if (_hasUserRegistered) {
      labelText = isArabic ? 'تم إرسال الطلب ⏳' : 'Request Sent ⏳';
      iconData = Iconsax.clock_copy;
      onPressed = null;
      buttonColor = VSPColors.surfaceAlt;
      textColor = VSPColors.textSecondary;
    } else if (_registrationCount >= 32) {
      labelText = isArabic ? 'اكتمل العدد 🔒' : 'Roster Full 🔒';
      iconData = Iconsax.lock_copy;
      onPressed = null;
      buttonColor = VSPColors.surfaceAlt;
      textColor = VSPColors.textSecondary;
    } else {
      labelText = isArabic ? 'سجل الآن' : 'Register Now';
      iconData = Iconsax.user_add_copy;
      onPressed = _isSubmitting ? null : _handleRegistration;
      buttonColor = VSPColors.accent;
      textColor = Colors.black;
    }

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: _isSubmitting
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
          : Icon(iconData, color: textColor, size: 20),
      label: Text(
        labelText,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        disabledBackgroundColor: VSPColors.surfaceAlt,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.xl)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Iconsax.arrow_left_2_copy, color: VSPColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'VSP 1V1 LEAGUE',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
                color: VSPColors.textPrimary,
              ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<List<VSP1v1Player>>(
        stream: LeagueRepository().get1v1Standings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
          }
          
          final players = snapshot.data ?? [];
          if (players.isEmpty) {
             return const Center(child: Text("No players found", style: TextStyle(color: VSPColors.textSecondary)));
          }

          final top3 = players.take(3).toList();
          final rest = players.skip(3).toList();

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Header Banner
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(VSPSpacing.lg),
                  decoration: BoxDecoration(
                    border: const Border(bottom: BorderSide(color: VSPColors.divider, width: 1)),
                    color: VSPColors.surfaceAlt.withValues(alpha: 0.5),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'SEASON 1 • ROUND 2',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: VSPColors.accent,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 3.0,
                            ),
                      ),
                      const SizedBox(height: VSPSpacing.md),
                      ElevatedButton.icon(
                        onPressed: _launchHighlights,
                        icon: Icon(Iconsax.play_circle_copy, color: Colors.black, size: 20),
                        label: const Text(
                          'WATCH HIGHLIGHTS',
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VSPColors.textPrimary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.xl)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildRegistrationButton(context),
                    ],
                  ),
                ),
              ),

              // Podium Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  child: _buildPodium(context, top3),
                ),
              ),

              // Rest of the list
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return VSPFadeInItem(
                        index: index + 3,
                        child: _PlayerStandingRow(player: rest[index]),
                      );
                    },
                    childCount: rest.length,
                  ),
                ),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPodium(BuildContext context, List<VSP1v1Player> top3) {
    if (top3.isEmpty) return const SizedBox.shrink();

    // Reorder to [Rank 2, Rank 1, Rank 3] for Podium Row
    List<VSP1v1Player?> podiumOrder = List.filled(3, null);
    if (top3.isNotEmpty) podiumOrder[1] = top3[0]; // Rank 1 at Center
    if (top3.length >= 2) podiumOrder[0] = top3[1]; // Rank 2 at Left
    if (top3.length >= 3) podiumOrder[2] = top3[2]; // Rank 3 at Right

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Rank 2
        Expanded(
          child: podiumOrder[0] != null 
            ? VSPFadeInItem(
                index: 1, 
                child: GestureDetector(
                  onTap: () => _showPlayerStatsModal(context, podiumOrder[0]!),
                  behavior: HitTestBehavior.opaque,
                  child: _buildPodiumCard(context, podiumOrder[0]!, false),
                ),
              )
            : const SizedBox.shrink(),
        ),
        const SizedBox(width: 8),
        // Rank 1
        Expanded(
          flex: 12, // Using integer for flex
          child: podiumOrder[1] != null 
            ? VSPFadeInItem(index: 0, child: _buildPodiumCard(context, podiumOrder[1]!, true))
            : const SizedBox.shrink(),
        ),
        const SizedBox(width: 8),
        // Rank 3
        Expanded(
          child: podiumOrder[2] != null 
            ? VSPFadeInItem(
                index: 2, 
                child: GestureDetector(
                  onTap: () => _showPlayerStatsModal(context, podiumOrder[2]!),
                  behavior: HitTestBehavior.opaque,
                  child: _buildPodiumCard(context, podiumOrder[2]!, false),
                ),
              )
            : const SizedBox.shrink(),
        ),
      ],
    );
  }

  void _showPlayerStatsModal(BuildContext context, VSP1v1Player player) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(VSPSpacing.xl),
        decoration: const BoxDecoration(
          color: VSPColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(VSPRadius.xl),
            topRight: Radius.circular(VSPRadius.xl),
          ),
          border: Border(top: BorderSide(color: VSPColors.accent, width: 2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: VSPColors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                ShimmerImage(
                  imageUrl: player.avatarUrl,
                  width: 80,
                  height: 80,
                  borderRadius: 40,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RANK ${player.rank}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: VSPColors.accent,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                        ),
                      ),
                      Text(
                        player.name.toUpperCase(),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                      if (player.titles > 0)
                        Row(
                          children: List.generate(
                            player.titles, 
                            (i) => const Padding(
                              padding: EdgeInsets.only(right: 4, top: 4),
                              child: Icon(Iconsax.cup_copy, color: VSPColors.accent, size: 18),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(VSPSpacing.lg),
              decoration: BoxDecoration(
                color: VSPColors.surfaceAlt,
                borderRadius: BorderRadius.circular(VSPRadius.lg),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildDetailStat('SKILL', player.skillPoints.toString(), context),
                  _buildDetailStat('GOALS', player.goals.toString(), context),
                  _buildDetailStat('TACKLES', player.tackles.toString(), context),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                 Text(
                   'TOTAL POINTS: ',
                   style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary),
                 ),
                 Text(
                   '${player.totalPoints}',
                   style: Theme.of(context).textTheme.titleLarge?.copyWith(
                     color: VSPColors.accent,
                     fontWeight: FontWeight.w900,
                   ),
                 ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailStat(String label, String value, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: VSPColors.textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 9,
                letterSpacing: 0.5,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: VSPColors.accent,
                fontWeight: FontWeight.w900,
              ),
        ),
      ],
    );
  }

  Widget _buildPodiumCard(BuildContext context, VSP1v1Player player, bool isWinner) {
    final height = isWinner ? 260.0 : 190.0;
    final bgColor = isWinner ? VSPColors.accent : VSPColors.surface;
    final textColor = isWinner ? Colors.black : VSPColors.textPrimary;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        boxShadow: isWinner ? [
          BoxShadow(
            color: VSPColors.accent.withValues(alpha: 0.3),
            blurRadius: 15,
            spreadRadius: 2,
          )
        ] : [],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Rank Label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isWinner ? Colors.black.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(VSPRadius.xl),
            ),
            child: Text(
              'RANK ${player.rank}',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w900,
                fontSize: 10,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Avatar
          Container(
             decoration: BoxDecoration(
               shape: BoxShape.circle,
               border: Border.all(color: textColor.withValues(alpha: 0.2), width: 2),
             ),
             child: ShimmerImage(
               imageUrl: player.avatarUrl,
               width: isWinner ? 72 : 54,
               height: isWinner ? 72 : 54,
               borderRadius: isWinner ? 36 : 27,
             ),
          ),
          const SizedBox(height: 12),
          
          // Name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              player.name.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w800,
                fontSize: isWinner ? 14 : 11,
              ),
            ),
          ),
          
          // Points
          Text(
            '${player.totalPoints}',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w900,
              fontSize: isWinner ? 24 : 18,
              height: 1.1,
            ),
          ),
          Text(
            'POINTS',
            style: TextStyle(
              color: textColor.withValues(alpha: 0.6),
              fontWeight: FontWeight.bold,
              fontSize: 8,
              letterSpacing: 1.0,
            ),
          ),

          if (isWinner) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(VSPRadius.sm),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'SKL ${player.skillPoints} | GL ${player.goals} | TCK ${player.tackles}',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 7,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            if (player.titles > 0) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(player.titles, (i) => const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 1),
                    child: Icon(Iconsax.cup_copy, color: Colors.black, size: 14),
                  )),
                )
            ]
          ]
        ],
      ),
    );
  }
}

class _PlayerStandingRow extends StatefulWidget {
  final VSP1v1Player player;
  const _PlayerStandingRow({required this.player});

  @override
  State<_PlayerStandingRow> createState() => _PlayerStandingRowState();
}

class _PlayerStandingRowState extends State<_PlayerStandingRow> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Container(
            color: _isExpanded ? VSPColors.surface : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Row(
                    children: [
                      Text(
                        '${widget.player.rank}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: VSPColors.textSecondary,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      _buildTrendIcon(widget.player.trend),
                    ],
                  ),
                ),
                ShimmerImage(
                  imageUrl: widget.player.avatarUrl,
                  width: 32,
                  height: 32,
                  borderRadius: 16,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.player.name.toUpperCase(),
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                        ),
                      ),
                      if (widget.player.titles > 0)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Row(
                            children: List.generate(
                              widget.player.titles, 
                              (i) => Icon(Iconsax.cup_copy, color: VSPColors.accent, size: 12)
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '${widget.player.totalPoints}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: VSPColors.textPrimary,
                      ),
                ),
                const SizedBox(width: 12),
                Icon(
                  _isExpanded ? Iconsax.arrow_up_1_copy : Iconsax.arrow_down_1_copy,
                  color: VSPColors.textSecondary.withValues(alpha: 0.4),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 250),
          crossFadeState: _isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(74, 8, 24, 20),
            color: VSPColors.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildDetailStat('SKILL', widget.player.skillPoints.toString(), context),
                _buildDetailStat('GOALS', widget.player.goals.toString(), context),
                _buildDetailStat('TACKLES', widget.player.tackles.toString(), context),
              ],
            ),
          ),
          secondChild: const SizedBox.shrink(),
        ),
        const Divider(color: VSPColors.divider, height: 1),
      ],
    );
  }

  Widget _buildTrendIcon(String trend) {
    if (trend == 'up') return Icon(Iconsax.arrow_up_1_copy, color: VSPColors.accent, size: 16);
    if (trend == 'down') return Icon(Iconsax.arrow_down_1_copy, color: Colors.red, size: 16);
    return Icon(Iconsax.minus_cirlce_copy, color: VSPColors.textSecondary, size: 12);
  }

  Widget _buildDetailStat(String label, String value, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: VSPColors.textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 9,
                letterSpacing: 0.5,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: VSPColors.accent,
                fontWeight: FontWeight.w900,
              ),
        ),
      ],
    );
  }
}

