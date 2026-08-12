import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/ui/components/vsp_card.dart';
import '../../../core/repositories/tournament_repository.dart';
import '../../../core/providers/stadium_provider.dart';
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
  String _selectedCategory = 'All';

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
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 100.0),
        child: FloatingActionButton(
          onPressed: () => _showTournamentTypeSheet(context, isArabic, l10n),
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
        automaticallyImplyLeading: false, 
        centerTitle: true,
        title: Text(
          l10n.tournamentsTitle,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // 1. التبويبات العلوية الكبسولية الفاخرة الموحدة (Pill Shape)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.xs),
            child: Container(
              height: 48,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: BorderRadius.circular(VSPRadius.full),
                border: Border.all(color: VSPColors.divider, width: 0.5),
              ),
              child: Stack(
                children: [
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    alignment: _selectedTab == 0 
                        ? AlignmentDirectional.centerStart 
                        : (_selectedTab == 1 ? AlignmentDirectional.center : AlignmentDirectional.centerEnd),
                    child: FractionallySizedBox(
                      widthFactor: 1 / 3,
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
                      _buildTabButton(l10n.coming, 0),
                      _buildTabButton(l10n.ongoing, 1),
                      _buildTabButton(l10n.finished, 2),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // 2. الفلاتر المنسدلة الموحدة بتناسق الـ Corner Radius (16px)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(
                  child: _buildFilterDropdown(
                    availableSports, 
                    _selectedSport, 
                    (v) => setState(() => _selectedSport = v!)
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildFilterDropdown(
                    ['All', 'Cup', 'League', 'GroupsAndKnockout'], 
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
                  final isRightCategory = _selectedCategory == 'All' || c.type.toLowerCase() == _selectedCategory.toLowerCase();
                  
                  final now = DateTime.now();
                  final todayStart = DateTime(now.year, now.month, now.day);
                  final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

                  bool isRightStatus = false;
                  if (_selectedTab == 0) { // Coming (Upcoming)
                    isRightStatus = c.startDate.isAfter(todayEnd);
                  } else if (_selectedTab == 1) { // Ongoing
                    isRightStatus = (c.startDate.isBefore(todayEnd) || c.startDate.isAtSameMomentAs(todayEnd)) &&
                                    (c.endDate.isAfter(todayStart) || c.endDate.isAtSameMomentAs(todayStart));
                  } else if (_selectedTab == 2) { // Finished
                    isRightStatus = c.endDate.isBefore(todayStart);
                  }
                  
                  return isRightCategory && isRightStatus;
                }).toList();

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  widget.onTournamentListChanged?.call(filtered.isEmpty);
                });

                if (filtered.isEmpty) {
                  final String emptyTitle;
                  final String emptySubtitle;
                  final bool hasAnyChampionships = championships.isNotEmpty;

                  if (_selectedTab == 0) {
                    emptyTitle = isArabic ? 'لا توجد بطولات قادمة' : 'No upcoming tournaments';
                    emptySubtitle = isArabic ? 'قم بإنشاء بطولة جديدة لتظهر هنا' : 'Create a tournament to show it here';
                  } else if (_selectedTab == 1) {
                    emptyTitle = isArabic ? 'لا توجد بطولات جارية حالياً' : 'No ongoing tournaments currently';
                    emptySubtitle = isArabic ? 'البطولات المبدوءة والمستمرة ستظهر هنا' : 'Active ongoing tournaments will appear here';
                  } else {
                    emptyTitle = isArabic ? 'لا توجد بطولات منتهية بعد' : 'No finished tournaments yet';
                    emptySubtitle = isArabic ? 'البطولات المكتملة ستظهر في هذا الأرشيف' : 'Completed tournaments will be archived here';
                  }

                  return VSPEmptyState(
                    icon: Iconsax.cup_copy,
                    title: emptyTitle,
                    subtitle: emptySubtitle,
                    buttonText: hasAnyChampionships ? null : l10n.createYourFirst,
                    onButtonPressed: hasAnyChampionships ? null : () {
                      CreateTournamentWizard.open(context);
                    },
                  );
                }

                return ListView.builder(
                  padding: VSPScrollPadding.forList(context, hasFloatingNavBar: true, top: 0, horizontal: VSPSpacing.md),
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

  void _showTournamentTypeSheet(BuildContext context, bool isArabic, dynamic l10n) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: VSPColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: Color(0xFF3F3F46), width: 2)),
          ),
          padding: EdgeInsets.fromLTRB(
            20, 20, 20,
            MediaQuery.of(ctx).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: VSPColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isArabic ? 'اختر نظام البطولة' : 'Choose Tournament Format',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isArabic
                    ? 'اختر النظام التنافسي الأنسب لملعبك وعملائك'
                    : 'Select the best competitive style for your pitch',
                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12.5),
              ),
              const SizedBox(height: 20),
              _buildTypeOption(
                ctx,
                icon: Iconsax.cup_copy,
                title: isArabic ? 'خروج المغلوب (كأس)' : 'Knockout (Cup)',
                subtitle: isArabic
                    ? 'مناسب للمنافسات السريعة (الخاسر يخرج فوراً)'
                    : 'Single elimination — Fast & highly competitive',
                badgeText: isArabic ? 'الأسرع حاسميًا ⚡' : 'Fastest ⚡',
                color: const Color(0xFFFFD700),
                isArabic: isArabic,
                onTap: () {
                  Navigator.pop(ctx);
                  CreateTournamentWizard.open(context, preselectedType: 'Cup');
                },
              ),
              const SizedBox(height: 12),
              _buildTypeOption(
                ctx,
                icon: Iconsax.security_safe_copy,
                title: isArabic ? 'مجموعات + تصفيات' : 'Groups & Knockout',
                subtitle: isArabic
                    ? 'مناسب لبطولات رمضان والشركات (مجموعات ثم أدوار إقصائية)'
                    : 'Group stage followed by knockout bracket',
                badgeText: isArabic ? 'الأكثر شعبية ⭐' : 'Most Popular ⭐',
                color: const Color(0xFFA78BFA),
                isArabic: isArabic,
                onTap: () {
                  Navigator.pop(ctx);
                  CreateTournamentWizard.open(context, preselectedType: 'GroupsAndKnockout');
                },
              ),
              const SizedBox(height: 12),
              _buildTypeOption(
                ctx,
                icon: Iconsax.award_copy,
                title: isArabic ? 'دوري نقاط كامل' : 'Full League',
                subtitle: isArabic
                    ? 'مناسب للمواسم والبطولات الطويلة (كل الفرق تلعب والترتيب بالنقاط)'
                    : 'Round-robin season — ranked by points',
                color: VSPColors.accent,
                isArabic: isArabic,
                onTap: () {
                  Navigator.pop(ctx);
                  CreateTournamentWizard.open(context, preselectedType: 'League');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTypeOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isArabic,
    required VoidCallback onTap,
    String? badgeText,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF27272A), width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      if (badgeText != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFFA1A1AA),
                      fontSize: 11.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isArabic ? Iconsax.arrow_left_2_copy : Iconsax.arrow_right_3_copy,
              color: const Color(0xFFA1A1AA),
              size: 16,
            ),
          ],
        ),
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
      if (val == 'All') return 'جميع البطولات';
      if (val == 'Cup') return 'كأس';
      if (val == 'League') return 'دوري';
      if (val == 'GroupsAndKnockout') return 'مجموعات وتصفيات';
      if (val == 'Football') return 'كرة القدم';
      if (val == 'Basketball') return 'كرة السلة';
      if (val == 'Padel') return 'بادل';
      if (val == 'Volleyball') return 'كرة الطائرة';
      if (val == 'Handball') return 'كرة اليد';
      return val;
    }

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
          value: items.contains(value) ? value : items.first,
          dropdownColor: VSPColors.surface,
          isExpanded: true,
          icon: const Icon(Iconsax.arrow_down_1_copy, color: VSPColors.accent, size: 16),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: VSPColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                translateItem(item),
                style: const TextStyle(
                  color: VSPColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
                    ? const Icon(Iconsax.cup_copy, color: VSPColors.accent, size: 22) 
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
                    child: const Icon(Iconsax.share_copy, color: VSPColors.textSecondary, size: 18),
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
                            child: const Icon(Iconsax.people_copy, color: VSPColors.accent, size: 14),
                          ),
                        );
                      }),
                    ),
                  ),
                if (tournament.joinedTeams.isNotEmpty) const SizedBox(width: 8),
                
                Text(
                  isArabic 
                      ? '${tournament.joinedTeams.length} / ${tournament.maxTeams} فريق'
                      : '${tournament.joinedTeams.length} / ${tournament.maxTeams} Teams',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: VSPColors.textSecondary,
                    fontWeight: FontWeight.bold,
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
