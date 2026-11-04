import '../../../core/ui/components/vsp_segmented_control.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/vsp_ui.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../core/constants/egypt_governorates.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/league_repository.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
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
  late TabController _tabController;
  int _selectedTabIndex = 0;

  // Filter states
  String _selectedLocation = 'All';
  String _selectedSport = 'All';
  bool _locationInitialized = false;

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
  
  void switchToTab(int index) {
    if (index >= 0 && index < _tabController.length) {
      _tabController.animateTo(index);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_locationInitialized) return;
    final governorate = context.read<AuthProvider>().governorate.trim();
    if (governorate.isNotEmpty && EgyptGovernorates.allGovernorates.contains(governorate)) {
      _selectedLocation = governorate;
    }
    _locationInitialized = true;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VSPScaffold(
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: VSPSegmentedControl(
                labels: [
                  Localizations.localeOf(context).languageCode == 'ar' ? 'البطولات' : 'Tournaments',
                  AppLocalizations.of(context)!.teams,
                  Localizations.localeOf(context).languageCode == 'ar' ? '1 ضد 1' : '1vs1',
                ],
                selectedIndex: _selectedTabIndex,
                onSelected: (index) => _tabController.animateTo(index),
                textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 13),
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
                      items: ['All', ...VSPConstants.sports],
                      onChanged: (val) => setState(() => _selectedSport = val!),
                      isSport: true,
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
                    selectedLocation: _selectedLocation,
                    selectedSport: _selectedSport,
                    onLocationChanged: (loc) => setState(() => _selectedLocation = loc),
                    onRetry: () => setState(() {}),
                  ),
                  TeamsRankingTab(
                    selectedLocation: _selectedLocation,
                    selectedSport: _selectedSport,
                    onRetry: () => setState(() {}),
                  ),
                  Vsp1v1LeagueTab(
                    selectedLocation: _selectedLocation,
                    onLocationChanged: (loc) => setState(() => _selectedLocation = loc),
                    getActive1v1Stream: (loc) => LeagueRepository().getActive1v1TournamentStream(governorate: loc),
                    getTournamentPlayersStream: (id) => LeagueRepository().getTournamentPlayersStream(id, isCompleted: false),
                    getStandingsStream: (id) => LeagueRepository().get1v1Standings(tournamentId: id),
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
    bool isSport = false,
  }) {
    final effectiveValue = items.contains(value) ? value : items.first;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      height: 48,
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
                    championTranslateItem(context, item, isSport: isSport),
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
                championTranslateItem(context, item, isSport: isSport),
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.white, fontSize: 13),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
