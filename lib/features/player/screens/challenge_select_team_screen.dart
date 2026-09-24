import 'dart:async';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/repositories/team_repository.dart';
import '../../../core/providers/auth_provider.dart' as app_auth;
import '../services/challenge_team_service.dart';
import '../widgets/challenge/challenge_team_card.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/vsp_back_button.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../data/models.dart';
import 'booking_confirmation_screen.dart';

class ChallengeSelectTeamScreen extends StatefulWidget {
 final Stadium stadium;
 final String bookingType;

 const ChallengeSelectTeamScreen({
 super.key,
 required this.stadium,
 required this.bookingType,
 });

 @override
 State<ChallengeSelectTeamScreen> createState() => _ChallengeSelectTeamScreenState();
}

class _ChallengeSelectTeamScreenState extends State<ChallengeSelectTeamScreen> {
 final TextEditingController _searchController = TextEditingController();
 String _searchQuery = '';
 Team? _selectedTeam;
 Timer? _debounce;
 bool _isSearching = false;
 List<Team> _searchedTeams = [];
 Map<String, int>? _h2hStats;
 bool _isLoadingH2H = false;
 final Map<String, bool> _championStatusMap = {};

 // Real History Teams fetched from bookings
 List<Team> _historyTeams = [];
 bool _isLoadingHistory = true;

 Future<void> _check1v1ChampionForTeam(String teamId) async {
 if (_championStatusMap.containsKey(teamId)) return;
 try {
 final hasChamp = await TeamRepository().has1v1Champion(teamId);
 if (mounted) {
 setState(() {
 _championStatusMap[teamId] = hasChamp;
 });
 }
 } catch (e) {
 debugPrint('Error checking 1v1 champion for team $teamId: $e');
 }
 }

 @override
 void initState() {
 super.initState();
 _fetchHistory();
 }

 Future<void> _fetchHistory() async {
 final auth = Provider.of<app_auth.AuthProvider>(context, listen: false);
 final uid = auth.currentUser?.uid;
 if (uid != null) {
 final team = await TeamRepository().getUserTeam(uid);
 if (team != null) {
 final history = await TeamRepository().getPreviousOpponents(team.id);
 if (mounted) {
 setState(() {
 _historyTeams = history;
 _isLoadingHistory = false;
 });
 }
 } else {
 if (mounted) setState(() => _isLoadingHistory = false);
 }
 } else {
 if (mounted) setState(() => _isLoadingHistory = false);
 }
 }

 void _onSearchChanged(String query) {
 if (_debounce?.isActive ?? false) _debounce!.cancel();
 
 setState(() {
 _searchQuery = query;
 });

 if (query.isEmpty) {
 setState(() {
 _searchedTeams = [];
 _isSearching = false;
 });
 return;
 }

 _debounce = Timer(const Duration(milliseconds: 500), () async {
 setState(() => _isSearching = true);
 
 final String? myTeamId = context.read<BookingProvider>().currentDraft?.playerTeamId;
 final results = await TeamRepository().searchOpponentTeams(query);
 
 if (mounted) {
 setState(() {
 // Filter out the player's own team
 _searchedTeams = results.where((team) => team.id != myTeamId).toList();
 _isSearching = false;
 });
 }
 });
 }

 @override
 void dispose() {
 _searchController.dispose();
 _debounce?.cancel();
 super.dispose();
 }

 @override
 Widget build(BuildContext context) {
 return Scaffold(
 backgroundColor: VSPColors.background,
 appBar: AppBar(
 backgroundColor: VSPColors.background,
 elevation: 0,
 leading: const VSPBackButton(),
 centerTitle: true,
 title: Text(
 AppLocalizations.of(context)!.selectOpponentTeam,
 style: Theme.of(context).textTheme.displaySmall,
 ),
 ),
 body: Column(
 children: [
 Expanded(
 child: SingleChildScrollView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
 padding: const EdgeInsets.all(16),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 AppLocalizations.of(context)!.chooseOpponent,
 style: Theme.of(context).textTheme.displaySmall,
 ),
 const SizedBox(height: 8),
 Text(
 AppLocalizations.of(context)!.chooseOpponentSubtitle,
 style: TextStyle(
 color: VSPColors.textSecondary.withValues(alpha: 0.7),
 fontSize: 14,
 ),
 ),
 const SizedBox(height: 24),

 // Search Field
 Container(
 decoration: BoxDecoration(
 color: VSPColors.surface,
 borderRadius: BorderRadius.circular(VSPRadius.md),
 border: Border.all(color: VSPColors.divider),
 ),
 child: TextField(
 controller: _searchController,
 style: Theme.of(context).textTheme.bodyLarge,
 onChanged: _onSearchChanged,
 decoration: InputDecoration(
 hintText: AppLocalizations.of(context)!.searchTeamPlaceholder,
 hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary),
 prefixIcon: const Icon(Iconsax.search_normal_copy, color: VSPColors.accent),
 border: InputBorder.none,
 contentPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: 14),
 ),
 ),
 ),

 const SizedBox(height: 32),

 // Search Results or History
 if (_searchQuery.isNotEmpty) ...[
 Text(
 AppLocalizations.of(context)!.searchResults,
 style: Theme.of(context).textTheme.titleLarge,
 ),
 const SizedBox(height: 16),
 if (_isSearching)
 const Center(
 child: Padding(
 padding: EdgeInsets.symmetric(vertical: 40),
 child: CircularProgressIndicator(color: VSPColors.accent),
 ),
 )
 else if (_searchedTeams.isEmpty)
 Center(
 child: Padding(
 padding: const EdgeInsets.symmetric(vertical: 40),
 child: Column(
 children: [
 Icon(Iconsax.search_normal_copy, color: VSPColors.textSecondary.withValues(alpha: 0.3), size: 48),
 const SizedBox(height: 16),
 Text(
 AppLocalizations.of(context)!.noTeamsFound(_searchQuery),
 style: TextStyle(color: VSPColors.textSecondary.withValues(alpha: 0.5)),
 ),
 ],
 ),
 ),
 )
 else
 ..._searchedTeams.map((team) => _buildTeamCard(team)),
 ] else ...[
 Text(
 AppLocalizations.of(context)!.previousOpponents,
 style: Theme.of(context).textTheme.titleLarge,
 ),
 const SizedBox(height: 16),
 if (_isLoadingHistory)
 const Center(
 child: Padding(
 padding: EdgeInsets.symmetric(vertical: 40),
 child: CircularProgressIndicator(color: VSPColors.accent),
 ),
 )
 else if (_historyTeams.isEmpty)
 Container(
 width: double.infinity,
 padding: const EdgeInsets.symmetric(vertical: 40),
 decoration: BoxDecoration(
 color: VSPColors.surface,
 borderRadius: BorderRadius.circular(VSPRadius.lg),
 ),
 child: Column(
 children: [
 Icon(Iconsax.rotate_left_copy, color: VSPColors.textSecondary.withValues(alpha: 0.3), size: 48),
 const SizedBox(height: 16),
 Text(
 AppLocalizations.of(context)!.noPreviousOpponents,
 textAlign: TextAlign.center,
 style: TextStyle(color: VSPColors.textSecondary.withValues(alpha: 0.5), fontSize: 13),
 ),
 ],
 ),
 )
 else
 ..._historyTeams.map((team) => _buildTeamCard(team)),
 ],
 ],
 ),
 ),
 ),

 // Continue Button
 Container(
 padding: const EdgeInsets.all(VSPSpacing.lg),
 decoration: const BoxDecoration(
 color: VSPColors.surface,
 borderRadius: BorderRadius.only(
 topLeft: Radius.circular(VSPRadius.xl),
 topRight: Radius.circular(VSPRadius.xl),
 ),
 boxShadow: [VSPShadow.subtle],
 ),
 child: SafeArea(
 child: PrimaryButton(
 text: AppLocalizations.of(context)!.continueButton,
 onPressed: _selectedTeam == null
 ? null
 : () async {
 if (!ChallengeTeamService.isFairPlayEligible(_selectedTeam)) {
 if (context.mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(AppLocalizations.of(context)!.fairPlayBannedError),
 backgroundColor: VSPColors.error,
 ),
 );
 }
 return;
 }

 final auth = Provider.of<app_auth.AuthProvider>(context, listen: false);
 final uid = auth.currentUser?.uid;
 if (uid != null) {
 final team = await TeamRepository().getUserTeam(uid);
 if (team != null) {
 // Official challenges require both teams to have at least 5 registered players.
 if (team.memberUids.length < 5 || _selectedTeam!.memberUids.length < 5) {
   if (context.mounted) {
     final isArabic = Localizations.localeOf(context).languageCode == 'ar';
     final incompleteTeam = team.memberUids.length < 5
         ? team.name
         : _selectedTeam!.name;
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text(
           isArabic
               ? 'لا يمكن بدء التحدي. فريق $incompleteTeam لديه أقل من 5 لاعبين.'
               : 'Challenge cannot start. Team $incompleteTeam has fewer than 5 players.',
         ),
         backgroundColor: VSPColors.error,
       ),
     );
   }
   return;
 }
 if (!ChallengeTeamService.isFairPlayEligible(team)) {
 if (context.mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(AppLocalizations.of(context)!.fairPlayBannedError),
 backgroundColor: VSPColors.error,
 ),
 );
 }
 return;
 }
 if (context.mounted) {
 context.read<BookingProvider>().updateDraft(
 opponentTeamId: _selectedTeam!.id,
 opponentTeamName: _selectedTeam!.name,
 playerTeamId: team.id,
 playerTeamName: team.name,
 );
 }
 }
 } else if (context.mounted) {
 context.read<BookingProvider>().updateDraft(
 opponentTeamId: _selectedTeam!.id,
 opponentTeamName: _selectedTeam!.name,
 );
 }

 if (!context.mounted) return;
 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (context) => BookingConfirmationScreen(
 stadium: widget.stadium,
 bookingType: widget.bookingType,
 opponentTeam: _selectedTeam,
 ),
 ),
 );
 },
 ),
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildTeamCard(Team team) {
 final bool isSelected = _selectedTeam?.id == team.id;
 _check1v1ChampionForTeam(team.id);
 final bool hasChampion = _championStatusMap[team.id] ?? false;

    return ChallengeTeamCard(
      team: team,
      isSelected: isSelected,
      hasChampion: hasChampion,
      isLoadingH2H: _isLoadingH2H,
      h2hStats: _h2hStats,
      onTap: () async {
        HapticFeedback.selectionClick();
        if (isSelected) return;

        setState(() {
          _selectedTeam = team;
          _isLoadingH2H = true;
          _h2hStats = null;
        });

        final String? myTeamId =
            context.read<BookingProvider>().currentDraft?.playerTeamId;
        if (myTeamId != null) {
          final stats =
              await TeamRepository().getHeadToHeadStats(myTeamId, team.id);
          if (mounted) {
            setState(() {
              _h2hStats = stats;
              _isLoadingH2H = false;
            });
          }
        } else {
          if (mounted) setState(() => _isLoadingH2H = false);
        }
      },
    );
  }
}
