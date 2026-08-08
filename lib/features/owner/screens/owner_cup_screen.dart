import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/ui/components/vsp_card.dart';
import '../../../core/repositories/tournament_repository.dart';
import '../../../data/models.dart';
import '../../../shared/widgets/vsp_empty_state.dart';
import '../../../shared/widgets/vsp_fade_in_item.dart';
import '../../../core/services/sharing_service.dart';
import 'owner_tournament_dashboard_screen.dart';
import 'create_tournament_wizard.dart';

class OwnerCupScreen extends StatefulWidget {
  final Function(bool isEmpty)? onTournamentListChanged;
  const OwnerCupScreen({super.key, this.onTournamentListChanged});

  @override
  State<OwnerCupScreen> createState() => _OwnerCupScreenState();
}

class _OwnerCupScreenState extends State<OwnerCupScreen> {
  int _selectedTab = 0; // 0: Coming, 1: Ongoing, 2: Finished
  String _selectedSport = 'Football';
  String _selectedCategory = 'Cup';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    
    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        automaticallyImplyLeading: false, 
        centerTitle: true,
        title: Text(
          l10n.tournamentsTitle,
          style: Theme.of(context).textTheme.displayLarge,
        ),
      ),
      body: Column(
        children: [
          // 1. التبويبات العلوية (القادمة، الجارية، المنتهية)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.sm),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: BorderRadius.circular(VSPRadius.xl),
              ),
              child: Stack(
                children: [
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    alignment: _selectedTab == 0 
                        ? AlignmentDirectional.centerStart 
                        : (_selectedTab == 1 ? AlignmentDirectional.center : AlignmentDirectional.centerEnd),
                    child: FractionallySizedBox(
                      widthFactor: 1 / 3,
                      child: Container(
                        height: 44,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: VSPColors.accent,
                          borderRadius: BorderRadius.circular(VSPRadius.xl),
                          boxShadow: [
                            BoxShadow(
                              color: VSPColors.accent.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      _buildTabButton(l10n.coming, 0),
                      _buildTabButton(l10n.ongoing, 1),
                      _buildTabButton(l10n.finished, 2),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 2. الفلاتر المنسدلة
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(
                  child: _buildFilterDropdown(
                    VSPConstants.sports, 
                    _selectedSport, 
                    (v) => setState(() => _selectedSport = v!)
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildFilterDropdown(
                    ['Cup', 'League'], 
                    _selectedCategory, 
                    (v) => setState(() => _selectedCategory = v!)
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 3. قائمة البطولات
          Expanded(
            child: StreamBuilder<List<Championship>>(
              stream: TournamentRepository().getChampionshipsStream(
                sportType: _selectedSport,
                isOwner: true,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
                }
                
                final championships = snapshot.data ?? [];
                
                final filtered = championships.where((c) {
                  final isRightCategory = c.type.toLowerCase() == _selectedCategory.toLowerCase();
                  
                  final now = DateTime.now();
                  bool isRightStatus = false;
                  if (_selectedTab == 0) {
                    isRightStatus = c.startDate.isAfter(now);
                  } else if (_selectedTab == 1) {
                    isRightStatus = c.startDate.isBefore(now) && c.endDate.isAfter(now);
                  } else if (_selectedTab == 2) {
                    isRightStatus = c.endDate.isBefore(now);
                  }
                  
                  return isRightCategory && isRightStatus;
                }).toList();

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  widget.onTournamentListChanged?.call(filtered.isEmpty);
                });

                if (filtered.isEmpty) {
                  return VSPEmptyState(
                    icon: LucideIcons.trophy,
                    title: l10n.noTournamentsTitle,
                    subtitle: l10n.noTournamentsSubtitle,
                    buttonText: l10n.createYourFirst,
                    onButtonPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CreateTournamentWizard()),
                      );
                    },
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.fromLTRB(VSPSpacing.md, 0, VSPSpacing.md, MediaQuery.of(context).padding.bottom + 110),
                  physics: const BouncingScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    return VSPFadeInItem(
                      index: index,
                      child: _buildTournamentCard(filtered[index], isArabic),
                    );
                  },
                );
              }
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String text, int index) {
    bool isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTab = index;
          });
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          alignment: Alignment.center,
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: isSelected ? Colors.black : VSPColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterDropdown(List<String> items, String value, Function(String?) onChanged) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    
    String translateItem(String val) {
      if (!isArabic) return val;
      if (val == 'Cup') return 'كأس';
      if (val == 'League') return 'دوري';
      if (val == 'Football') return 'كرة القدم';
      if (val == 'Basketball') return 'كرة السلة';
      if (val == 'Padel') return 'بادل';
      if (val == 'Volleyball') return 'كرة الطائرة';
      if (val == 'Handball') return 'كرة اليد';
      return val;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: 40,
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.sm), 
        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3), width: 1), 
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          dropdownColor: VSPColors.surface,
          icon: const Icon(LucideIcons.chevronDown, color: VSPColors.accent),
          style: Theme.of(context).textTheme.bodySmall,
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(translateItem(item), style: Theme.of(context).textTheme.bodySmall),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  /// 🏆 كارت البطولة المصلح بالكامل
  Widget _buildTournamentCard(Championship tournament, bool isArabic) {
    final String startDateStr = isArabic
        ? '${tournament.startDate.day} ${_getArabicMonth(tournament.startDate.month)}'
        : DateFormat('MMM d').format(tournament.startDate);
    final String endDateStr = isArabic
        ? '${tournament.endDate.day} ${_getArabicMonth(tournament.endDate.month)}'
        : DateFormat('MMM d').format(tournament.endDate);
    final dateRange = '$startDateStr - $endDateStr';

    final String translatedSport = isArabic
        ? (tournament.sportType == 'Football' ? 'كرة القدم' : tournament.sportType)
        : tournament.sportType;
    final String translatedCategory = isArabic
        ? (tournament.type == 'Cup' ? 'كأس' : 'دوري')
        : tournament.type;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OwnerTournamentDashboardScreen(championship: tournament),
          ),
        );
      },
      borderRadius: BorderRadius.circular(VSPRadius.lg),
      child: VSPCard(
        margin: const EdgeInsets.only(bottom: VSPSpacing.md),
        padding: const EdgeInsets.all(VSPSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: tournament.imageUrl.isNotEmpty 
                      ? DecorationImage(image: NetworkImage(tournament.imageUrl), fit: BoxFit.cover)
                      : null,
                    color: VSPColors.background,
                    border: Border.all(color: VSPColors.divider, width: 1),
                  ),
                  child: tournament.imageUrl.isEmpty 
                    ? const Icon(LucideIcons.trophy, color: VSPColors.accent, size: 22) 
                    : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tournament.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$translatedSport • $translatedCategory',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () {
                    SharingService.shareChampionship(
                      id: tournament.id,
                      name: tournament.name,
                      startDateStr: startDateStr,
                      endDateStr: endDateStr,
                      grandPrize: tournament.grandPrize,
                      entryFee: tournament.entryFee,
                      joinedTeamsCount: tournament.joinedTeams.length,
                      maxTeams: tournament.maxTeams,
                      sportType: tournament.sportType,
                      governorate: tournament.governorate,
                      isArabic: isArabic,
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: VSPColors.surfaceAlt,
                      shape: BoxShape.circle,
                      border: Border.all(color: VSPColors.divider.withValues(alpha: 0.1)),
                    ),
                    child: const Icon(LucideIcons.share2, color: VSPColors.textSecondary, size: 18),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoColumn(isArabic ? 'التاريخ' : 'DATE', dateRange),
                _buildInfoColumn(isArabic ? 'رسوم الدخول' : 'ENTRY FEE', '${tournament.entryFee.toInt()} ${isArabic ? "ج.م" : "EGP"}'),
                _buildInfoColumn(isArabic ? 'الجائزة الكبرى' : 'GRAND PRIZE', '${tournament.grandPrize.toInt()} ${isArabic ? "ج.م" : "EGP"}'),
              ],
            ),
            
            const SizedBox(height: 20),
             
            Row(
              children: [
                if (tournament.joinedTeams.isNotEmpty) 
                  SizedBox(
                    width: 30 + (tournament.joinedTeams.length.clamp(1, 4) - 1) * 20.0,
                    height: 30,
                    child: Stack(
                      children: List.generate(tournament.joinedTeams.length.clamp(0, 4), (i) {
                        return Positioned(
                          left: i * 18.0,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: VSPColors.surfaceAlt,
                              border: Border.all(color: VSPColors.surface, width: 2),
                            ),
                            child: const Icon(LucideIcons.users, color: VSPColors.accent, size: 14),
                          ),
                        );
                      }),
                    ),
                  ),
                if (tournament.joinedTeams.isNotEmpty) const SizedBox(width: 8),
                
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    '${tournament.joinedTeams.length} / ${tournament.maxTeams} ${isArabic ? "فرق" : "Teams"}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: VSPColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getArabicMonth(int month) {
    const months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    return months[month - 1];
  }

  Widget _buildInfoColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(), 
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary, fontSize: 10),
        ),
        const SizedBox(height: 4),
        Text(
          value, 
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
