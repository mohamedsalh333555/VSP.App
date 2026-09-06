import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/material.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../core/constants/egypt_governorates.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../data/models.dart';
import '../../../core/repositories/league_repository.dart';
import '../../../core/repositories/team_repository.dart';
import '../../../core/repositories/tournament_repository.dart';
import 'championship_details_screen.dart';
import 'player_home_screen.dart'; // For ChampionshipCard
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/services/paymob_service.dart';
import 'paymob_web_view_screen.dart';
import '../../../shared/widgets/vsp_fade_in_item.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/vsp_error_state.dart';

final GlobalKey<ChampionScreenState> championScreenKey = GlobalKey<ChampionScreenState>();

class ChampionScreen extends StatefulWidget {
  const ChampionScreen({super.key});

  @override
  State<ChampionScreen> createState() => ChampionScreenState();
}

class ChampionScreenState extends State<ChampionScreen>
    with SingleTickerProviderStateMixin {
  // Stream memoization to prevent recreation on rebuild
  Stream<List<Championship>>? _championshipsStream;
  String? _lastChampionshipsKey;
  Stream<List<Championship>> _getChampionshipsStream() {
    final key = '${_selectedLocation}_$_selectedSport';
    if (_championshipsStream != null && _lastChampionshipsKey == key) {
      return _championshipsStream!;
    }
    _lastChampionshipsKey = key;
    _championshipsStream = TournamentRepository().getChampionshipsStream(
      governorate: _selectedLocation,
      sportType: _selectedSport,
    );
    return _championshipsStream!;
  }

  Stream<List<Team>>? _teamsStream;
  Stream<List<Team>> _getTeamsStream() {
    _teamsStream ??= TeamRepository().getTeams();
    return _teamsStream!;
  }

  Stream<Map<String, dynamic>?>? _active1v1Stream;
  String? _last1v1Location;
  Stream<Map<String, dynamic>?> _getActive1v1Stream(String effectiveLocation) {
    if (_active1v1Stream != null && _last1v1Location == effectiveLocation) {
      return _active1v1Stream!;
    }
    _last1v1Location = effectiveLocation;
    _active1v1Stream = LeagueRepository().getActive1v1TournamentStream(governorate: effectiveLocation);
    return _active1v1Stream!;
  }

  Stream<List<Map<String, dynamic>>>? _tournamentPlayersStream;
  String? _lastTourneyPlayersId;
  Stream<List<Map<String, dynamic>>> _getTournamentPlayersStream(String tournamentId) {
    if (_tournamentPlayersStream != null && _lastTourneyPlayersId == tournamentId) {
      return _tournamentPlayersStream!;
    }
    _lastTourneyPlayersId = tournamentId;
    _tournamentPlayersStream = LeagueRepository().getTournamentPlayersStream(tournamentId, isCompleted: false);
    return _tournamentPlayersStream!;
  }

  Stream<List<VSP1v1Player>>? _standingsStream;
  String? _lastStandingsId;
  Stream<List<VSP1v1Player>> _getStandingsStream(String? tourneyId) {
    if (_standingsStream != null && _lastStandingsId == tourneyId) {
      return _standingsStream!;
    }
    _lastStandingsId = tourneyId;
    _standingsStream = LeagueRepository().get1v1Standings(tournamentId: tourneyId);
    return _standingsStream!;
  }
  late TabController _tabController;
  int _selectedTabIndex = 0;

  // Filter states
  String _selectedLocation = 'Cairo'; 
  String _selectedSport = 'Football'; 
  bool _isLocationInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isLocationInitialized) {
      final auth = Provider.of<AuthProvider>(context);
      final rawGov = auth.userModel?.governorate ?? auth.governorate;
      final resolvedGov = EgyptGovernorates.resolveGoogleName(rawGov);
      if (resolvedGov != null && EgyptGovernorates.allGovernorates.contains(resolvedGov)) {
        _selectedLocation = resolvedGov;
      } else {
        final matchedGov = EgyptGovernorates.allGovernorates.firstWhere(
          (g) => g.toLowerCase() == rawGov.toLowerCase(),
          orElse: () => 'Cairo',
        );
        _selectedLocation = matchedGov;
      }
      _isLocationInitialized = true;
    }
  }
  
  void switchToTab(int index) {
    if (_tabController.length > index) {
      _tabController.animateTo(index);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false, // Maintain no back button
        title: Text(
          AppLocalizations.of(context)!.champion,
          style: Theme.of(context).textTheme.displayMedium,
        ),
      ),
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 48,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: BorderRadius.circular(VSPRadius.full),
                border: Border.all(color: VSPColors.divider, width: 0.5),
              ),
              child: Stack(
                children: [
                  // Animated background pill for 3 tabs
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    alignment: Directionality.of(context) == TextDirection.rtl 
                        ? (_selectedTabIndex == 0
                            ? Alignment.centerRight
                            : (_selectedTabIndex == 1
                                ? Alignment.center
                                : Alignment.centerLeft)) 
                        : (_selectedTabIndex == 0
                            ? Alignment.centerLeft
                            : (_selectedTabIndex == 1
                                ? Alignment.center
                                : Alignment.centerRight)),
                    child: FractionallySizedBox(
                      widthFactor: 1.0 / 3.0,
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: VSPColors.accent,
                          borderRadius: BorderRadius.circular(VSPRadius.full),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      // Tab 0: Championships
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _tabController.animateTo(0),
                          behavior: HitTestBehavior.opaque,
                          child: Center(
                            child: Builder(
                              builder: (context) {
                                final isArabic = Localizations.localeOf(context).languageCode == 'ar';
                                final label = isArabic ? 'البطولات' : 'Tournaments';
                                return Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: _selectedTabIndex == 0 ? Colors.black : Colors.white,
                                        fontWeight: _selectedTabIndex == 0 ? FontWeight.w900 : FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      // Tab 1: Teams
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _tabController.animateTo(1),
                          behavior: HitTestBehavior.opaque,
                          child: Center(
                            child: Text(
                              AppLocalizations.of(context)!.teams,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: _selectedTabIndex == 1 ? Colors.black : Colors.white,
                                    fontWeight: _selectedTabIndex == 1 ? FontWeight.w900 : FontWeight.bold,
                                    fontSize: 13,
                                  ),
                            ),
                          ),
                        ),
                      ),
                      // Tab 2: 1VS1
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _tabController.animateTo(2),
                          behavior: HitTestBehavior.opaque,
                          child: Center(
                            child: Text(
                              '1VS1',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: _selectedTabIndex == 2 ? Colors.black : Colors.white,
                                    fontWeight: _selectedTabIndex == 2 ? FontWeight.w900 : FontWeight.bold,
                                    fontSize: 13,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: VSPSpacing.md),

            // Filters Row - 2 Symmetrical Wide Dropdowns
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Dropdown 1: Governorates (with 'All' / 'كل المحافظات' at start)
                  Expanded(
                    child: _buildFunctionalDropdown(
                      value: _selectedLocation,
                      items: ['All', ...EgyptGovernorates.allGovernorates],
                      onChanged: (val) => setState(() => _selectedLocation = val!),
                    ),
                  ),
                  const SizedBox(width: 10), 
                  // Dropdown 2: Team Sports
                  Expanded(
                    child: _buildFunctionalDropdown(
                      value: _selectedSport,
                      items: VSPConstants.sports,
                      onChanged: (val) => setState(() => _selectedSport = val!),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: VSPSpacing.lg),

            // Tab Views with smooth swipe gestures
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildChampionshipsTab(),
                  _buildTeamsRankingStream(),
                  _build1v1PlayersRanking(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _translateItem(String item) {
    final isArabic = AppLocalizations.of(context)!.localeName == 'ar';
    if (item == 'All') {
      return isArabic ? 'كل المحافظات' : 'All Governorates';
    }
    if (!isArabic) return item;
    if (EgyptGovernorates.sportsTranslations.containsKey(item)) {
      return EgyptGovernorates.getLocalizedSport(item, true);
    }
    return EgyptGovernorates.getLocalizedName(item, true);
  }

  Widget _buildFunctionalDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    // Ensure value is in items, otherwise fallback to first
    final effectiveValue = items.contains(value) ? value : items.first;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      height: 44,
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: VSPColors.divider, width: 0.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: effectiveValue,
          icon: const Icon(Iconsax.arrow_down_1_copy, color: VSPColors.accent, size: 16),
          dropdownColor: VSPColors.surface,
          isExpanded: true,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
          onChanged: onChanged,
          selectedItemBuilder: (BuildContext context) {
            return items.map<Widget>((String item) {
              return Container(
                alignment: AlignmentDirectional.centerStart,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _translateItem(item),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                  ),
                ),
              );
            }).toList();
          },
          items: items.map<DropdownMenuItem<String>>((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                _translateItem(item),
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white, fontSize: 13),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }


  Widget _build1v1PlayersRanking() {
    final auth = Provider.of<AuthProvider>(context);
    final userGovRaw = auth.userModel?.governorate ?? auth.governorate;
    final userGov = EgyptGovernorates.resolveGoogleName(userGovRaw) ?? userGovRaw;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    // Fallback prompt if player has no governorate set in profile
    if (userGov.trim().isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: VSPColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: VSPColors.divider.withValues(alpha: 0.3)),
                ),
                child: const Icon(Iconsax.location_slash_copy, size: 38, color: VSPColors.accent),
              ),
              const SizedBox(height: 16),
              Text(
                isArabic ? 'يرجى تحديد محافظتك من الملف الشخصي' : 'Please set your governorate in profile',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                isArabic
                    ? 'حدد محافظتك لمشاهدة بطولات منطقتك والمشاركة بها'
                    : 'Set your home governorate to view and join local 1v1 tournaments',
                textAlign: TextAlign.center,
                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/edit-profile');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: VSPColors.accent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                icon: const Icon(Iconsax.edit_2_copy, size: 16, color: Colors.black),
                label: Text(
                  isArabic ? 'تحديد المحافظة الآن' : 'Set Governorate',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Effective governorate for 1v1: uses _selectedLocation (supports curious browsing)
    final effectiveLocation = _selectedLocation == 'All' ? userGov : _selectedLocation;
    final isBrowsingDifferentGov = userGov.isNotEmpty &&
        effectiveLocation.toLowerCase() != userGov.toLowerCase();

    return StreamBuilder<Map<String, dynamic>?>(
      stream: _getActive1v1Stream(effectiveLocation),
      builder: (context, tourneySnap) {
        if (tourneySnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
        }

        final tournament = tourneySnap.data;
        if (tournament == null) {
          final locName = _translateItem(effectiveLocation);
          return Column(
            children: [
              if (isBrowsingDifferentGov)
                _buildGovBrowsingBanner(userGov, isArabic),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: VSPColors.surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: VSPColors.divider.withValues(alpha: 0.3)),
                          ),
                          child: const Icon(Iconsax.cup_copy, size: 38, color: VSPColors.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isArabic ? 'لا توجد بطولة فردية نشطة حالياً في $locName' : 'No active 1v1 tournament in $locName',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isArabic ? 'ترقبوا إعلان موعد وتفاصيل بطولة 1vs1 القادمة قريباً!' : 'Stay tuned for upcoming 1v1 announcements!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        final status = tournament['status'] as String? ?? 'registration_open';
        final isCompleted = status == 'completed' || status == 'published';

        return Column(
          children: [
            if (isBrowsingDifferentGov)
              _buildGovBrowsingBanner(userGov, isArabic),
            Expanded(
              child: isCompleted
                  ? _build1v1StandingsPhase(tournament)
                  : _build1v1RegistrationPhase(
                      tournament,
                      isBrowsingDifferentGov: isBrowsingDifferentGov,
                      userGov: userGov,
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGovBrowsingBanner(String userGov, bool isArabic) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Iconsax.location_copy, color: VSPColors.accent, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isArabic
                  ? 'تتصفح بطولات: ${_translateItem(_selectedLocation)}'
                  : 'Viewing: ${_translateItem(_selectedLocation)}',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          InkWell(
            onTap: () {
              setState(() {
                _selectedLocation = userGov;
              });
            },
            borderRadius: BorderRadius.circular(VSPRadius.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                isArabic ? 'بطولاتي ($userGov)' : 'My City ($userGov)',
                style: const TextStyle(color: VSPColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _build1v1RegistrationPhase(
    Map<String, dynamic> tournament, {
    bool isBrowsingDifferentGov = false,
    String userGov = '',
  }) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.currentUser?.uid;
    final tournamentId = tournament['id']?.toString() ?? '';
    final tourneyName = tournament['name'] as String? ?? 'بطولة VSP فردي 1vs1';
    final targetCount = (tournament['target_player_count'] as num?)?.toInt() ?? 16;
    final scheduledAt = tournament['scheduled_at'] as String?;
    final status = tournament['status'] as String? ?? 'registration_open';
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final entryFee = (tournament['entry_fee'] as num?)?.toDouble() ?? 0.0;
    final prizePool = (tournament['prize_pool'] as num?)?.toDouble() ?? 0.0;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getTournamentPlayersStream(tournamentId),
      builder: (context, playersSnap) {
        final players = playersSnap.data ?? [];
        final registeredCount = players.length;
        final remainingCount = (targetCount - registeredCount).clamp(0, 999);
        final progress = targetCount > 0 ? (registeredCount / targetCount).clamp(0.0, 1.0) : 0.0;
        final isRegistered = currentUserId != null && players.any((p) => p['user_id'] == currentUserId);
        final myIndex = isRegistered ? players.indexWhere((p) => p['user_id'] == currentUserId) + 1 : null;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: VSPScrollPadding.forList(context, hasFloatingNavBar: true, top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Hero Countdown & Timeline Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E2614), VSPColors.surface],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: VSPColors.accent.withValues(alpha: 0.35)),
                  boxShadow: [
                    BoxShadow(
                      color: VSPColors.accent.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tourneyName,
                                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (tournament['governorate'] != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Iconsax.location_copy, size: 13, color: VSPColors.accent),
                                    const SizedBox(width: 4),
                                    Text(
                                      _translateItem(tournament['governorate'].toString()),
                                      style: const TextStyle(color: VSPColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: status == 'registration_open' ? const Color(0xFF14301A) : const Color(0xFF332B10),
                            borderRadius: BorderRadius.circular(VSPRadius.full),
                            border: Border.all(
                              color: status == 'registration_open' ? const Color(0xFF22C55E) : const Color(0xFFEAB308),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            status == 'registration_open'
                                ? (isArabic ? 'التسجيل متاح' : 'Open')
                                : (isArabic ? 'التسجيل مغلق' : 'Closed'),
                            style: TextStyle(
                              color: status == 'registration_open' ? const Color(0xFF4ADE80) : const Color(0xFFFDE047),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Date & Countdown Badges
                    if (scheduledAt != null) ...[
                      Row(
                        children: [
                          const Icon(Iconsax.calendar_1_copy, size: 16, color: VSPColors.accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _formatScheduledDate(scheduledAt),
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Iconsax.clock_copy, size: 16, color: VSPColors.accent),
                          const SizedBox(width: 8),
                          Text(
                            _calculateCountdown(scheduledAt),
                            style: const TextStyle(color: VSPColors.accent, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Capacity Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isArabic ? 'المقاعد المحجوزة' : 'Seats Reserved',
                          style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                        ),
                        Text(
                          '$registeredCount / $targetCount ($remainingCount ${isArabic ? "متبقي" : "left"})',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: VSPColors.surfaceAlt,
                        valueColor: const AlwaysStoppedAnimation<Color>(VSPColors.accent),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 2. Financial Prize Pool & Entry Fee Transparency Card (Directly before Join Button)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: VSPColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: VSPColors.divider.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    // Entry Fee Column
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: VSPColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: VSPColors.divider.withValues(alpha: 0.25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Iconsax.ticket_copy, size: 15, color: VSPColors.textSecondary),
                                const SizedBox(width: 6),
                                Text(
                                  isArabic ? 'رسوم الاشتراك' : 'Entry Fee',
                                  style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${entryFee.toStringAsFixed(0)} ${isArabic ? "ج.م" : "EGP"}',
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isArabic ? 'دفع إلكتروني إلزامي' : 'Mandatory e-pay',
                              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Prize Pool Column (Live Accumulator)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF162512),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: VSPColors.accent.withValues(alpha: 0.35)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Iconsax.moneys_copy, size: 15, color: VSPColors.accent),
                                const SizedBox(width: 6),
                                Text(
                                  isArabic ? 'الجائزة التراكمية' : 'Live Prize Pool',
                                  style: const TextStyle(color: VSPColors.accent, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${prizePool.toStringAsFixed(0)} ${isArabic ? "ج.م" : "EGP"}',
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$registeredCount ${isArabic ? "دفعوا واشتركوا" : "paid entries"}',
                              style: const TextStyle(color: Color(0xFF86EFAC), fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 3. Interactive Registration Action Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: isRegistered
                    ? Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF142E18),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Iconsax.tick_circle_copy, color: Color(0xFF22C55E), size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isArabic ? 'أنت مسجل في البطولة بنجاح!' : 'You are registered!',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isArabic
                                        ? 'رقم مقعدك في الجدول: #$myIndex (تم سداد الاشتراك)'
                                        : 'Your seat number: #$myIndex (Entry fee paid)',
                                    style: const TextStyle(color: Color(0xFF86EFAC), fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    : isBrowsingDifferentGov
                        ? Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF231C10),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFEAB308).withValues(alpha: 0.4)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    const Icon(Iconsax.info_circle_copy, color: Color(0xFFFDE047), size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        isArabic
                                            ? 'أنت تتصفح بطولة خارج محافظتك (${_translateItem(tournament['governorate'] ?? _selectedLocation)}). الاشتراك متاح فقط في بطولات محافظتك ($userGov).'
                                            : 'Viewing tournament in ${_translateItem(tournament['governorate'] ?? _selectedLocation)}. Registration is available only in your home city ($userGov).',
                                        style: const TextStyle(color: Color(0xFFFDE047), fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  height: 44,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _selectedLocation = userGov;
                                      });
                                    },
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFFEAB308)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    icon: const Icon(Iconsax.location_copy, size: 16, color: Color(0xFFFDE047)),
                                    label: Text(
                                      isArabic ? 'الانتقال إلى بطولات محافظتي ($userGov)' : 'Switch to My City ($userGov)',
                                      style: const TextStyle(color: Color(0xFFFDE047), fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : (status == 'registration_open' && remainingCount > 0)
                            ? PrimaryButton(
                                text: _isProcessingPayment
                                    ? (isArabic ? 'جاري فتح بوابة الدفع...' : 'Opening payment...')
                                    : (isArabic
                                        ? 'سداد الاشتراك والانضمام (${entryFee.toStringAsFixed(0)} ج.م)'
                                        : 'Pay & Join (${entryFee.toStringAsFixed(0)} EGP)'),
                                height: 50,
                                color: VSPColors.accent,
                                textColor: Colors.black,
                                onPressed: _isProcessingPayment ? () {} : () => _handleJoin1v1(tournamentId, entryFee),
                              )
                            : Container(
                                padding: const EdgeInsets.all(14),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: VSPColors.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: VSPColors.divider),
                                ),
                                child: Text(
                                  isArabic ? 'اكتمل العدد أو تم إغلاق باب التسجيل' : 'Registration is closed or full',
                                  style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ),
              ),

              const SizedBox(height: 24),

              // 3. Registered Players Table Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isArabic ? 'جدول المسجلين بالبطولة' : 'Registered Roster',
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: VSPColors.surface,
                        borderRadius: BorderRadius.circular(VSPRadius.full),
                        border: Border.all(color: VSPColors.divider, width: 0.5),
                      ),
                      child: Text(
                        '$registeredCount ${isArabic ? "لاعبين" : "players"}',
                        style: const TextStyle(color: VSPColors.accent, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 4. Registered Players List
              if (players.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      isArabic ? 'كن أول من يسجل ويسدد للاشتراك في هذه البطولة!' : 'Be the first to register and join this tournament!',
                      style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: players.length,
                  itemBuilder: (ctx, idx) {
                    final p = players[idx];
                    final pName = p['player_name'] ?? 'لاعب';
                    final pAvatar = p['avatar_url'] as String? ?? '';
                    final isMe = currentUserId != null && p['user_id'] == currentUserId;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isMe ? const Color(0xFF1B2A16) : VSPColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isMe ? VSPColors.accent : VSPColors.divider.withValues(alpha: 0.3),
                          width: isMe ? 1.5 : 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 28,
                            child: Text(
                              '#${idx + 1}',
                              style: TextStyle(
                                color: isMe ? VSPColors.accent : VSPColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: VSPColors.surfaceAlt,
                              border: Border.all(color: isMe ? VSPColors.accent : VSPColors.divider, width: 1),
                            ),
                            child: ClipOval(
                              child: pAvatar.isNotEmpty
                                  ? CachedNetworkImage(imageUrl: pAvatar, fit: BoxFit.cover)
                                  : Center(
                                      child: Text(
                                        pName.isNotEmpty ? pName[0].toUpperCase() : 'P',
                                        style: TextStyle(color: isMe ? VSPColors.accent : Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              pName + (isMe ? (isArabic ? ' (أنت)' : ' (You)') : ''),
                              style: TextStyle(
                                color: isMe ? VSPColors.accent : Colors.white,
                                fontWeight: isMe ? FontWeight.w900 : FontWeight.w600,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF142E18),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.3), width: 0.5),
                            ),
                            child: Text(
                              isArabic ? 'مسجل ومسدد' : 'Paid & Confirmed',
                              style: const TextStyle(color: Color(0xFF86EFAC), fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _build1v1StandingsPhase(Map<String, dynamic> tournament) {
    final tourneyId = tournament['id']?.toString();
    return StreamBuilder<List<VSP1v1Player>>(
      stream: _getStandingsStream(tourneyId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
        }
        if (snapshot.hasError) {
          return VSPErrorState(
            customMessage: snapshot.error?.toString(),
            onRetry: () => setState(() {}),
          );
        }
        final players = snapshot.data ?? [];
        if (players.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: VSPColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: VSPColors.divider.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Iconsax.cup_copy, size: 38, color: VSPColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.noOneVsOneRanked,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        }

        final top3 = players.take(3).toList();
        final rest = players.skip(3).toList();

        if (players.length < 3) {
          return ListView.builder(
            padding: EdgeInsets.fromLTRB(16, VSPSpacing.md, 16, MediaQuery.of(context).padding.bottom + 24),
            physics: const BouncingScrollPhysics(),
            itemCount: players.length,
            itemBuilder: (ctx, i) => VSPFadeInItem(
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _build1v1RankListItem(players[i], i + 1),
              ),
            ),
          );
        }

        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: VSPScrollPadding.forList(context, hasFloatingNavBar: true, top: 12),
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // Premium 1v1 Podium
              SizedBox(
                height: 290,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Rank 2 - Left (Silver)
                    Expanded(
                      child: VSPFadeInItem(
                        index: 1,
                        child: _buildTopRankItem(
                          rank: 2,
                          name: top3[1].name,
                          logo: top3[1].avatarUrl,
                          points: top3[1].totalPoints,
                          badgeIcon: Iconsax.medal_star_copy,
                          borderColor: const Color(0xFFC0C0C0),
                          bgColor: VSPColors.surface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Rank 1 - Center (Gold Champion)
                    Expanded(
                      child: VSPFadeInItem(
                        index: 0,
                        child: _buildTopRankItem(
                          rank: 1,
                          name: top3[0].name,
                          logo: top3[0].avatarUrl,
                          points: top3[0].totalPoints,
                          badgeIcon: Iconsax.crown_copy,
                          borderColor: VSPColors.accent,
                          bgColor: const Color(0xFF1E2614),
                          isCenter: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Rank 3 - Right (Bronze)
                    Expanded(
                      child: VSPFadeInItem(
                        index: 2,
                        child: _buildTopRankItem(
                          rank: 3,
                          name: top3[2].name,
                          logo: top3[2].avatarUrl,
                          points: top3[2].totalPoints,
                          badgeIcon: Iconsax.award_copy,
                          borderColor: const Color(0xFFCD7F32),
                          bgColor: VSPColors.surface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Expanded Ranking List (#4, #5...)
              ...List.generate(rest.length, (index) {
                final player = rest[index];
                final rank = index + 4;
                return VSPFadeInItem(
                  index: index + 3,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _build1v1RankListItem(player, rank),
                  ),
                );
              }),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _build1v1RankListItem(VSP1v1Player player, int rank) {
    final initialLetter = player.name.trim().isNotEmpty
        ? player.name.trim().split(' ').last.substring(0, 1).toUpperCase()
        : 'P';
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: VSPColors.divider.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Rank Number
          SizedBox(
            width: 28,
            child: Text(
              '#',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: rank <= 3 ? VSPColors.accent : VSPColors.textSecondary,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
            ),
          ),

          // Player Avatar / Initial
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: VSPColors.surfaceAlt,
              border: Border.all(color: VSPColors.divider, width: 1),
            ),
            child: ClipOval(
              child: player.avatarUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: player.avatarUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _buildInitialBadge(initialLetter, VSPColors.accent),
                    )
                  : _buildInitialBadge(initialLetter, VSPColors.accent),
            ),
          ),
          const SizedBox(width: 12),

          // Player Name & Breakdown
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  isArabic
                      ? 'قطع كرات: ${player.tackles}  •  أهداف: ${player.goals}  •  مهارات: ${player.skillPoints}'
                      : 'Tackles: ${player.tackles}  •  Goals: ${player.goals}  •  Skills: ${player.skillPoints}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: VSPColors.textSecondary,
                        fontSize: 11,
                      ),
                ),
              ],
            ),
          ),

          // Total Points Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: VSPColors.surfaceAlt,
              borderRadius: BorderRadius.circular(VSPRadius.md),
              border: Border.all(color: VSPColors.divider.withValues(alpha: 0.4)),
            ),
            child: Text(
              '${player.totalPoints} ${isArabic ? "نقطة" : "PTS"}',
              style: const TextStyle(
                color: VSPColors.accent,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isProcessingPayment = false;

  Future<void> _handleJoin1v1(String tournamentId, double entryFee) async {
    if (_isProcessingPayment) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    if (user == null) {
      VSPFeedback.showError(context, isArabic ? 'يجب تسجيل الدخول أولاً للمشاركة.' : 'Please log in to join.');
      return;
    }

    setState(() => _isProcessingPayment = true);

    try {
      // 1. Create atomic payment order on database
      final orderRes = await LeagueRepository().create1v1PaymentOrder(tournamentId);
      if (orderRes['success'] != true) {
        if (!mounted) return;
        VSPFeedback.showError(
          context,
          orderRes['error']?.toString() ?? (isArabic ? 'فشل إنشاء طلب الاشتراك في البطولة.' : 'Failed to create registration order.'),
        );
        return;
      }

      final orderRef = orderRes['order_reference'] as String;
      final orderAmount = (orderRes['amount'] as num?)?.toDouble() ?? entryFee;

      final userName = auth.userModel?.name ?? 'Player';
      final userPhone = auth.userModel?.phone ?? '';
      final userEmail = user.email ?? 'player@vsp.app';

      // 2. Obtain secure Paymob checkout URL via Supabase Edge Function
      final checkoutUrl = await PaymobService.getCheckoutUrlFromServer(
        amountInEgp: orderAmount,
        bookingId: orderRef,
        userEmail: userEmail,
        userName: userName,
        userPhone: userPhone,
        isTournamentPayment: true,
      );

      if (!mounted) return;

      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        VSPFeedback.showError(
          context,
          isArabic ? 'تعذر فتح بوابة الدفع الآمنة، يرجى المحاولة لاحقاً.' : 'Unable to open secure checkout gateway.',
        );
        return;
      }

      // 3. Open Paymob WebView Screen
      final isPaidSuccess = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PaymobWebViewScreen(
            initialUrl: checkoutUrl,
            title: isArabic ? 'سداد اشتراك البطولة' : 'Tournament Checkout',
            bookingId: orderRef,
          ),
        ),
      );

      if (!mounted) return;

      // 4. Verification Check
      final isRegistered = await LeagueRepository().isUserRegisteredIn1v1(tournamentId, user.uid);
      if (!mounted) return;

      if (isPaidSuccess == true || isRegistered) {
        VSPFeedback.showSuccess(
          context,
          isArabic ? 'تم تأكيد الدفع وتسجيلك في البطولة بنجاح!' : 'Payment confirmed! You are registered in the tournament.',
        );
        setState(() {});
      } else {
        VSPFeedback.showError(
          context,
          isArabic ? 'لم يتم إتمام الدفع، لم يتم تسجيلك في البطولة.' : 'Payment not completed. You were not registered.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Error in _handleJoin1v1: $e');
      VSPFeedback.showError(
        context,
        isArabic ? 'حدث خطأ أثناء معالجة الدفع: $e' : 'Payment error occurred: $e',
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessingPayment = false);
      }
    }
  }

  String _formatScheduledDate(String? rawIso) {
    if (rawIso == null) return 'قريباً';
    try {
      final dt = DateTime.parse(rawIso).toLocal();
      final dayNames = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
      final monthNames = ['', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
      final dayName = dayNames[dt.weekday - 1];
      final monthName = monthNames[dt.month];
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final period = dt.hour >= 12 ? 'م' : 'ص';
      final min = dt.minute.toString().padLeft(2, '0');
      return '$dayName، ${dt.day} $monthName - $hour:$min $period';
    } catch (_) {
      return rawIso;
    }
  }

  String _calculateCountdown(String? rawIso) {
    if (rawIso == null) return '';
    try {
      final dt = DateTime.parse(rawIso).toLocal();
      final now = DateTime.now();
      final diff = dt.difference(now);
      if (diff.isNegative) return 'انطلقت الفعالية الآن ⏱️';
      if (diff.inDays > 0) {
        final hours = diff.inHours % 24;
        return 'متبقي ${diff.inDays} يوم و $hours ساعة';
      }
      if (diff.inHours > 0) {
        final mins = diff.inMinutes % 60;
        return 'متبقي ${diff.inHours} ساعة و $mins دقيقة';
      }
      return 'متبقي ${diff.inMinutes} دقيقة';
    } catch (_) {
      return '';
    }
  }

  Widget _buildTeamsRankingStream() {
    return StreamBuilder<List<Team>>(
      stream: _getTeamsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
        }
        if (snapshot.hasError) {
          return VSPErrorState(
            customMessage: snapshot.error?.toString(),
            onRetry: () => setState(() {}),
          );
        }

        final List<Team> allTeams = snapshot.data ?? [];

        final teams = allTeams.where((team) {
          final matchesLocation = _selectedLocation == 'All' ||
              team.governorate.toLowerCase() == _selectedLocation.toLowerCase() ||
              EgyptGovernorates.resolveGoogleName(team.governorate) == _selectedLocation ||
              (EgyptGovernorates.resolveGoogleName(team.governorate) != null &&
                  EgyptGovernorates.resolveGoogleName(team.governorate) == EgyptGovernorates.resolveGoogleName(_selectedLocation));

          final matchesSport = team.sportType.toLowerCase() == _selectedSport.toLowerCase();

          return matchesLocation && matchesSport;
        }).toList();

        if (teams.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                AppLocalizations.of(context)!.noTeamsInLoc(_translateItem(_selectedLocation)), 
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.textSecondary),
              ),
            ),
          );
        }

        // Sort by points desc
        teams.sort((a, b) => b.points.compareTo(a.points)); 

        final totalTeams = teams.length;
        final top3 = teams.take(3).toList();
        final rest = teams.skip(3).toList();
        
        if (teams.length < 3) {
          return ListView.builder(
            padding: EdgeInsets.fromLTRB(16, VSPSpacing.md, 16, MediaQuery.of(context).padding.bottom + 24),
            physics: const BouncingScrollPhysics(),
            itemCount: teams.length,
            itemBuilder: (ctx, i) => VSPFadeInItem(
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildRankListItem(teams[i], i + 1, totalTeams: totalTeams),
              ),
            ),
          );
        }

        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: VSPScrollPadding.forList(context, hasFloatingNavBar: true, top: 12),
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // Premium Podium
              SizedBox(
                height: 290,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Rank 2 - Left (Silver)
                    Expanded(
                      child: VSPFadeInItem(
                        index: 1,
                        child: _buildTopRankItem(
                          rank: 2,
                          name: top3[1].name,
                          logo: top3[1].logoUrl.isNotEmpty ? top3[1].logoUrl : top3[1].captainImageUrl,
                          points: top3[1].points,
                          badgeIcon: Iconsax.medal_star_copy,
                          borderColor: const Color(0xFFC0C0C0),
                          bgColor: VSPColors.surface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Rank 1 - Center (Gold)
                    Expanded(
                      child: VSPFadeInItem(
                        index: 0,
                        child: _buildTopRankItem(
                          rank: 1,
                          name: top3[0].name,
                          logo: top3[0].logoUrl.isNotEmpty ? top3[0].logoUrl : top3[0].captainImageUrl,
                          points: top3[0].points,
                          badgeIcon: Iconsax.crown_copy,
                          borderColor: VSPColors.accent,
                          bgColor: const Color(0xFF1E2614),
                          isCenter: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Rank 3 - Right (Bronze)
                    Expanded(
                      child: VSPFadeInItem(
                        index: 2,
                        child: _buildTopRankItem(
                          rank: 3,
                          name: top3[2].name,
                          logo: top3[2].logoUrl.isNotEmpty ? top3[2].logoUrl : top3[2].captainImageUrl,
                          points: top3[2].points,
                          badgeIcon: Iconsax.award_copy,
                          borderColor: const Color(0xFFCD7F32),
                          bgColor: VSPColors.surface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Expanded Ranking List (#4, #5...)
              ...List.generate(rest.length, (index) {
                final team = rest[index];
                final rank = index + 4;
                return VSPFadeInItem(
                  index: index + 3,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildRankListItem(team, rank, totalTeams: totalTeams),
                  ),
                );
              }),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopRankItem({
    required int rank,
    required String name,
    required String logo,
    required int points,
    required IconData badgeIcon,
    required Color borderColor,
    required Color bgColor,
    bool isCenter = false,
  }) {
    final height = isCenter ? 260.0 : 210.0;
    final initialLetter = name.trim().isNotEmpty ? name.trim().split(' ').last.substring(0, 1).toUpperCase() : 'V';

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: borderColor.withValues(alpha: isCenter ? 0.9 : 0.4), width: isCenter ? 2 : 1),
        boxShadow: isCenter
            ? [
                BoxShadow(
                  color: VSPColors.accent.withValues(alpha: 0.25),
                  blurRadius: 16,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                )
              ]
            : [],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top Crown / Medal Icon
          Icon(badgeIcon, color: borderColor, size: isCenter ? 24 : 18),

          // Team Logo / Initial Avatar
          Container(
            width: isCenter ? 62 : 48,
            height: isCenter ? 62 : 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: VSPColors.surfaceAlt,
              border: Border.all(color: borderColor, width: 2),
            ),
            child: ClipOval(
              child: logo.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: logo,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _buildInitialBadge(initialLetter, borderColor),
                    )
                  : _buildInitialBadge(initialLetter, borderColor),
            ),
          ),

          // Team Name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isCenter ? 13 : 11,
                  ),
            ),
          ),

          // Points Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: borderColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(VSPRadius.sm),
            ),
            child: Text(
              '$points ${AppLocalizations.of(context)!.pts}',
              style: TextStyle(
                color: isCenter ? VSPColors.accent : Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Rank Pill Badge at Bottom
          Container(
            width: isCenter ? 36 : 28,
            height: isCenter ? 36 : 28,
            decoration: BoxDecoration(
              color: isCenter ? VSPColors.accent : VSPColors.surfaceAlt,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$rank',
              style: TextStyle(
                color: isCenter ? Colors.black : Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: isCenter ? 18 : 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialBadge(String letter, Color accentColor) {
    return Container(
      color: VSPColors.surfaceAlt,
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: accentColor,
          fontWeight: FontWeight.w900,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _buildRankListItem(Team team, int rank, {bool isMyTeam = false, int totalTeams = 10}) {
    final initialLetter = team.name.trim().isNotEmpty ? team.name.trim().split(' ').last.substring(0, 1).toUpperCase() : 'T';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: isMyTeam ? Border.all(color: VSPColors.accent.withValues(alpha: 0.6)) : Border.all(color: VSPColors.divider.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Rank Number
          SizedBox(
            width: 28,
            child: Text(
              '#$rank',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: rank <= 3 ? VSPColors.accent : VSPColors.textSecondary,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
            ),
          ),

          // Team Logo / Initial Avatar
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: VSPColors.surfaceAlt,
              border: Border.all(color: VSPColors.divider, width: 1),
            ),
            child: ClipOval(
              child: team.logoUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: team.logoUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _buildInitialBadge(initialLetter, VSPColors.accent),
                    )
                  : _buildInitialBadge(initialLetter, VSPColors.accent),
            ),
          ),
          const SizedBox(width: 12),

          // Team Name & Match Stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        team.name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    FutureBuilder<bool>(
                      future: TeamRepository().has1v1Champion(team.id),
                      builder: (context, champSnap) {
                        if (champSnap.data == true) {
                          return Container(
                            margin: const EdgeInsetsDirectional.only(start: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF332608),
                              borderRadius: BorderRadius.circular(VSPRadius.full),
                              border: Border.all(color: const Color(0xFFEAB308), width: 0.8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Iconsax.crown_copy, size: 11, color: Color(0xFFFDE047)),
                                SizedBox(width: 3),
                                Text(
                                  'بطل 1v1',
                                  style: TextStyle(color: Color(0xFFFDE047), fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  AppLocalizations.of(context)!.teamStats(team.matchesPlayed, team.wins, team.draws, team.losses),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
                ),
              ],
            ),
          ),
          // Points Column
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: VSPColors.surfaceAlt,
              borderRadius: BorderRadius.circular(VSPRadius.md),
              border: Border.all(color: VSPColors.divider.withValues(alpha: 0.4)),
            ),
            child: Text(
              AppLocalizations.of(context)!.pointsCount(team.points),
              style: const TextStyle(
                color: VSPColors.accent,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChampionshipsTab() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userGovRaw = auth.userModel?.governorate ?? auth.governorate;
    final userGov = EgyptGovernorates.resolveGoogleName(userGovRaw) ?? userGovRaw;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isDifferentGov = userGov.isNotEmpty && _selectedLocation.toLowerCase() != userGov.toLowerCase();

    return StreamBuilder<List<Championship>>(
      stream: _getChampionshipsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
        }
        if (snapshot.hasError && (!snapshot.hasData || snapshot.data!.isEmpty)) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.refresh, color: VSPColors.warning, size: 36),
                  const SizedBox(height: 12),
                  Text(
                    isArabic ? 'تعذر التحديث اللحظي، اسحب للأسفل للتحديث' : 'Realtime update unavailable, pull to refresh',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  TextButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh, color: VSPColors.accent, size: 16),
                    label: Text(
                      isArabic ? 'إعادة المحاولة' : 'Retry',
                      style: const TextStyle(color: VSPColors.accent, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final championships = snapshot.data ?? [];

        return Column(
          children: [
            // Quick return banner if browsing a different governorate
            if (isDifferentGov)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: VSPColors.surface,
                  borderRadius: BorderRadius.circular(VSPRadius.lg),
                  border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Iconsax.location_copy, color: VSPColors.accent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isArabic ? 'تتصفح بطولات: $_selectedLocation' : 'Viewing: $_selectedLocation',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _selectedLocation = userGov;
                        });
                      },
                      borderRadius: BorderRadius.circular(VSPRadius.sm),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(
                          isArabic ? 'بطولاتي ($userGov)' : 'My City ($userGov)',
                          style: const TextStyle(color: VSPColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Content List
            Expanded(
              child: championships.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Iconsax.cup_copy, color: Colors.white.withValues(alpha: 0.1), size: 64),
                            const SizedBox(height: 16),
                            Text(
                              AppLocalizations.of(context)!.noChampionshipsInLoc(_selectedLocation),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary),
                            ),
                            if (isDifferentGov) ...[
                              const SizedBox(height: 16),
                              PrimaryButton(
                                text: isArabic ? 'العودة لبطولات $userGov' : 'Return to $userGov Tournaments',
                                height: 44,
                                onPressed: () {
                                  setState(() {
                                    _selectedLocation = userGov;
                                  });
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: VSPScrollPadding.forList(context, hasFloatingNavBar: true, horizontal: 0, top: isDifferentGov ? 0 : 16),
                      physics: const BouncingScrollPhysics(),
                      itemCount: championships.length,
                      itemBuilder: (context, index) {
                        final championship = championships[index];
                        return VSPFadeInItem(
                          index: index,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChampionshipDetailsScreen(championship: championship),
                                  ),
                                );
                              },
                              child: ChampionshipCard(championship: championship),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
