import 'package:flutter/material.dart';
import '../../../core/ui/vsp_ui.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../core/constants/egypt_governorates.dart';
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
                          color: VSPColors.background,
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
                                        color: _selectedTabIndex == 0 ? VSPColors.textPrimary : VSPColors.textSecondary,
                                        fontWeight: _selectedTabIndex == 0 ? FontWeight.w900 : FontWeight.w600,
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
                                    color: _selectedTabIndex == 1 ? VSPColors.textPrimary : VSPColors.textSecondary,
                                    fontWeight: _selectedTabIndex == 1 ? FontWeight.w900 : FontWeight.w600,
                                    fontSize: 13,
                                  ),
                            ),
                          ),
                        ),
                      ),
                      // Tab 2: 1vs1
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _tabController.animateTo(2),
                          behavior: HitTestBehavior.opaque,
                          child: Center(
                            child: Text(
                              Localizations.localeOf(context).languageCode == 'ar'
                                  ? '1 ضد 1'
                                  : '1v1',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: _selectedTabIndex == 2 ? VSPColors.textPrimary : VSPColors.textSecondary,
                                    fontWeight: _selectedTabIndex == 2 ? FontWeight.w900 : FontWeight.w600,
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

            // 1v1 only needs governorate; sport does not apply.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _selectedTabIndex == 2
                  ? _buildFunctionalDropdown(
                      value: _selectedLocation,
                      items: ['All', ...EgyptGovernorates.allGovernorates],
                      onChanged: (val) => setState(() => _selectedLocation = val!),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _buildFunctionalDropdown(
                            value: _selectedLocation,
                            items: ['All', ...EgyptGovernorates.allGovernorates],
                            onChanged: (val) => setState(() => _selectedLocation = val!),
                          ),
                        ),
                        const SizedBox(width: 10),
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

            const SizedBox(height: VSPSpacing.md),

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
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white, fontSize: 13),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
