import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/egypt_governorates.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/league_repository.dart';
import '../../../core/repositories/team_repository.dart';
import '../../../core/repositories/tournament_repository.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../data/models.dart';
import '../../../l10n/app_localizations.dart';
import '../widgets/champion/champion_podium_components.dart';
import '../widgets/champion/championships_list_tab.dart';
import '../widgets/champion/teams_ranking_tab.dart';
import '../widgets/champion/vsp_1v1_league_tab.dart';

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
        automaticallyImplyLeading: false,
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
                  ChampionshipsListTab(
                    championshipsStream: _getChampionshipsStream(),
                    selectedLocation: _selectedLocation,
                    onLocationChanged: (loc) => setState(() => _selectedLocation = loc),
                    onRetry: () => setState(() {}),
                  ),
                  TeamsRankingTab(
                    teamsStream: _getTeamsStream(),
                    selectedLocation: _selectedLocation,
                    selectedSport: _selectedSport,
                    onRetry: () => setState(() {}),
                  ),
                  Vsp1v1LeagueTab(
                    selectedLocation: _selectedLocation,
                    onLocationChanged: (loc) => setState(() => _selectedLocation = loc),
                    getActive1v1Stream: _getActive1v1Stream,
                    getTournamentPlayersStream: _getTournamentPlayersStream,
                    getStandingsStream: _getStandingsStream,
                    onRetry: () => setState(() {}),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFunctionalDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
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
                    championTranslateItem(context, item),
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
                championTranslateItem(context, item),
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white, fontSize: 13),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
