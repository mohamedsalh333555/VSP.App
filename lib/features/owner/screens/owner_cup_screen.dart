import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/stadium_provider.dart';
import '../../../core/repositories/tournament_repository.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../data/models.dart';
import '../../../shared/widgets/vsp_back_button.dart';
import '../../../shared/widgets/vsp_fade_in_item.dart';
import '../widgets/tournament/cups/cups_tab_selector.dart';
import '../widgets/tournament/cups/cups_filter_dropdowns.dart';
import '../widgets/tournament/cups/owner_cup_card.dart';
import '../widgets/tournament/cups/owner_cup_empty_view.dart';
import '../widgets/tournament/cups/owner_cup_format_modal.dart';

class OwnerCupScreen extends StatefulWidget {
  final Function(bool isEmpty)? onTournamentListChanged;
  const OwnerCupScreen({super.key, this.onTournamentListChanged});

  @override
  State<OwnerCupScreen> createState() => _OwnerCupScreenState();
}

class _OwnerCupScreenState extends State<OwnerCupScreen> {
  int _selectedTab = 0; // 0: Coming, 1: Ongoing, 2: Finished
  String _selectedSport = 'Football';
  String _selectedCategory = 'All';
  bool _hasAnyChampionships = true;

  Stream<List<Championship>>? _championshipsStream;
  String? _lastSport;
  String? _lastOwnerId;

  Stream<List<Championship>> _getChampionshipsStream(String sportType, String? ownerId) {
    if (_championshipsStream != null && _lastSport == sportType && _lastOwnerId == ownerId) {
      return _championshipsStream!;
    }
    _lastSport = sportType;
    _lastOwnerId = ownerId;
    _championshipsStream = TournamentRepository().getChampionshipsStream(
      sportType: sportType,
      isOwner: true,
      ownerId: ownerId,
    );
    return _championshipsStream!;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final stadiumProvider = Provider.of<StadiumProvider>(context);
    final ownerStadiums = stadiumProvider.stadiums;

    final List<String> availableSports = ownerStadiums
        .map((s) => s.type.trim())
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();

    if (availableSports.isEmpty) {
      availableSports.add('Football');
    }

    if (!availableSports.contains(_selectedSport)) {
      _selectedSport = availableSports.first;
    }

    return Scaffold(
      backgroundColor: VSPColors.background,
      floatingActionButton: !_hasAnyChampionships
          ? null
          : Padding(
              padding: EdgeInsets.only(
                bottom: VSPScrollPadding.bottom(context, hasFloatingNavBar: true, extra: 14.0),
              ),
              child: FloatingActionButton(
                onPressed: () => showOwnerCupFormatModal(context),
                backgroundColor: VSPColors.accent,
                shape: const CircleBorder(),
                elevation: 6,
                child: const Icon(Icons.add_rounded, color: Colors.black, size: 30),
              ),
            ),
      floatingActionButtonLocation: isArabic
          ? FloatingActionButtonLocation.startFloat
          : FloatingActionButtonLocation.endFloat,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        leading: Navigator.canPop(context) ? const VSPBackButton() : null,
        centerTitle: true,
        title: Text(
          l10n.tournamentsTitle,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // 1. Pill Tabs
          CupsTabSelector(
            selectedTab: _selectedTab,
            onTabSelected: (idx) => setState(() => _selectedTab = idx),
            comingLabel: l10n.coming,
            ongoingLabel: l10n.ongoing,
            finishedLabel: l10n.finished,
          ),

          const SizedBox(height: 10),

          // 2. Filter Dropdowns (Sport + Format/Category)
          CupsFilterDropdowns(
            availableSports: availableSports,
            selectedSport: _selectedSport,
            onSportChanged: (sport) => setState(() => _selectedSport = sport),
            selectedCategory: _selectedCategory,
            onCategoryChanged: (cat) => setState(() => _selectedCategory = cat),
          ),

          const SizedBox(height: 20),

          // 3. Championships List Stream
          Expanded(
            child: StreamBuilder<List<Championship>>(
              stream: _getChampionshipsStream(
                _selectedSport,
                Provider.of<AuthProvider>(context, listen: false).currentUser?.uid,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
                }

                final championships = snapshot.data ?? [];
                final hasAny = championships.isNotEmpty;
                if (_hasAnyChampionships != hasAny) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _hasAnyChampionships = hasAny;
                      });
                    }
                  });
                }

                final filtered = championships.where((c) {
                  final isRightCategory = _selectedCategory == 'All' ||
                      c.type.toLowerCase() == _selectedCategory.toLowerCase();

                  bool isRightStatus = false;
                  final status = c.status.toLowerCase();

                  if (_selectedTab == 0) {
                    isRightStatus = status == 'open';
                  } else if (_selectedTab == 1) {
                    isRightStatus = status == 'ongoing';
                  } else if (_selectedTab == 2) {
                    isRightStatus = status == 'completed' || status == 'finished';
                  }

                  return isRightCategory && isRightStatus;
                }).toList();

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  widget.onTournamentListChanged?.call(filtered.isEmpty);
                });

                if (filtered.isEmpty) {
                  return OwnerCupEmptyView(
                    selectedTab: _selectedTab,
                    hasAnyChampionships: championships.isNotEmpty,
                    createFirstText: l10n.createYourFirst,
                    onOpenFormatSheet: () => showOwnerCupFormatModal(context),
                  );
                }

                return ListView.builder(
                  padding: VSPScrollPadding.forList(
                    context,
                    hasFloatingNavBar: true,
                    top: 0,
                    horizontal: VSPSpacing.md,
                  ),
                  physics: const BouncingScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    return VSPFadeInItem(
                      index: index,
                      child: OwnerCupCard(tournament: filtered[index]),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
