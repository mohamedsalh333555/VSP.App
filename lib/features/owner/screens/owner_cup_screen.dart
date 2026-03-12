import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/ui/components/vsp_card.dart';
import '../../../core/services/database_service.dart';
import '../../../data/models.dart';
import '../../../shared/widgets/vsp_empty_state.dart';
import '../../../shared/widgets/vsp_fade_in_item.dart';
import 'owner_tournament_dashboard_screen.dart';
import 'create_tournament_screen.dart';

class OwnerCupScreen extends StatefulWidget {
  const OwnerCupScreen({super.key});

  @override
  State<OwnerCupScreen> createState() => _OwnerCupScreenState();
}

class _OwnerCupScreenState extends State<OwnerCupScreen> {
  int _selectedTab = 0; // 0: Coming, 1: Ongoing, 2: Finished
  String _selectedSport = 'Football';
  String _selectedCategory = 'Cup';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        automaticallyImplyLeading: false, // Root tab, no back button
        centerTitle: true,
        title: Text(
          'Cup',
          style: Theme.of(context).textTheme.displayLarge,
        ),
      ),
      body: Column(
        children: [
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
                  // Animated background pill
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    alignment: _selectedTab == 0 
                        ? Alignment.centerLeft 
                        : (_selectedTab == 1 ? Alignment.center : Alignment.centerRight),
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
                      _buildTabButton('Coming', 0),
                      _buildTabButton('Ongoing', 1),
                      _buildTabButton('Finished', 2),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 2. Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end, // Align to right if constrained, but Expanded fills width
              children: [
                Expanded(
                  child: _buildFilterDropdown(
                    ['Football', 'Basketball', 'Volleyball', 'Padel'], 
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

          // 3. List of Tournaments - Wired to Firestore
          Expanded(
            child: StreamBuilder<List<Championship>>(
              stream: DatabaseService().getChampionshipsStream(
                sportType: _selectedSport,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
                }
                
                final championships = snapshot.data ?? [];
                
                // Filter by category locally and status
                final filtered = championships.where((c) {
                  final isRightCategory = c.type.toLowerCase() == _selectedCategory.toLowerCase();
                  
                  // Simple status filter (mock status since it might not be in DB yet, 
                  // or derived from dates)
                  final now = DateTime.now();
                  bool isRightStatus = false;
                  if (_selectedTab == 0) isRightStatus = c.startDate.isAfter(now);
                  else if (_selectedTab == 1) isRightStatus = c.startDate.isBefore(now) && c.endDate.isAfter(now);
                  else if (_selectedTab == 2) isRightStatus = c.endDate.isBefore(now);
                  
                  return isRightCategory && isRightStatus;
                }).toList();

                if (filtered.isEmpty) {
                  return VSPEmptyState(
                    icon: Icons.emoji_events_outlined,
                    title: 'No ${_selectedCategory}s Found',
                    subtitle: 'Create a tournament to start hosting competitions at your stadium!',
                    buttonText: 'Create Tournament',
                    onButtonPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CreateTournamentScreen()),
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
                      child: _buildTournamentCard(filtered[index]),
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
          decoration: const BoxDecoration(
            color: Colors.transparent,
          ),
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
          icon: const Icon(Icons.keyboard_arrow_down, color: VSPColors.accent),
          style: Theme.of(context).textTheme.bodySmall,
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item, style: Theme.of(context).textTheme.bodySmall),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTournamentCard(Championship tournament) {
    final dateRange = '${DateFormat('MMM d').format(tournament.startDate)} - ${DateFormat('MMM d').format(tournament.endDate)}';
    
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
          // Header: Logo, Title, Actions
          Row(
            children: [
              // Logo
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
                  ? Icon(Icons.emoji_events, color: VSPColors.textSecondary.withValues(alpha: 0.3)) 
                  : null,
              ),
              const SizedBox(width: 12),
              // Title & Subtitle
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
                      '${tournament.sportType} • ${tournament.type}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
                    ),
                  ],
                ),
              ),
              // Owner Actions
              Row(
                children: [
                   // Edit Button
                   InkWell(
                     onTap: () {
                       // Navigate to Edit
                     },
                     borderRadius: BorderRadius.circular(20),
                     child: Container(
                       width: 36,
                       height: 36,
                      decoration: BoxDecoration(
                        color: VSPColors.accent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.edit_outlined, color: VSPColors.accent, size: 18),
                    ),
                   ),
                   const SizedBox(width: 8),
                   // Share Button
                   InkWell(
                     onTap: () {
                       // Share logic
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
                       child: const Icon(Icons.share_outlined, color: VSPColors.textSecondary, size: 18),
                     ),
                   ),
                ],
              )
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Info Grid (Date, Entry Fee, Grand Prize)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoColumn('Date', dateRange),
              _buildInfoColumn('Entry Fee', '${tournament.entryFee.toInt()} eg'),
              _buildInfoColumn('Grand Prize', '${tournament.grandPrize.toInt()} eg'),
            ],
          ),
          
          const SizedBox(height: 20),
           
           // Footer: Teams Joined
           Row(
             children: [
               if (tournament.joinedTeams.isNotEmpty) 
                 SizedBox(
                   width: 30 + (tournament.joinedTeams.length.clamp(1, 5) - 1) * 22.0,
                   height: 30,
                   child: Stack(
                     children: List.generate(tournament.joinedTeams.length.clamp(0, 5), (i) {
                       return _buildAvatar(i, 'https://cdn-icons-png.flaticon.com/512/166/166165.png'); // Placeholder
                     }),
                   ),
                 ),
               if (tournament.joinedTeams.isNotEmpty) const SizedBox(width: 8),
               Text(
                 'Teams Joined: ${tournament.joinedTeams.length} / ${tournament.maxTeams}',
                 style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: VSPColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
               ),
             ],
           )
        ],
      ),
    ),
  );
}
  
  Widget _buildAvatar(int index, String url) {
    return Positioned(
      left: index * 22.0, // Slight overlap
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: VSPColors.surface, width: 2), // Ring effect to separate
          image: DecorationImage(
            image: NetworkImage(url),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label, 
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

