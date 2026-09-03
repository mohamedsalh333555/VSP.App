import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/repositories/tournament_repository.dart';
import '../../../data/models.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/vsp_back_button.dart';
import '../../../core/utils/vsp_feedback.dart';

class TournamentBracketsScreen extends StatefulWidget {
 final Championship championship;
 final bool isOwner;

 const TournamentBracketsScreen({super.key, required this.championship, required this.isOwner});

 @override
 State<TournamentBracketsScreen> createState() => _TournamentBracketsScreenState();
}

class _TournamentBracketsScreenState extends State<TournamentBracketsScreen> {
 int _refreshKey = 0;
 final TransformationController _transformController = TransformationController();

 Future<Map<String, List<String>>> _fetchRosters(String homeTeamId, String awayTeamId) async {
 return TournamentRepository().fetchRosters(widget.championship.id, homeTeamId, awayTeamId);
 }

 void _refreshMatches() {
 if (mounted) {
 setState(() {
 _refreshKey++;
 });
 }
 }

 @override
 void dispose() {
 _transformController.dispose();
 super.dispose();
 }

 @override
 Widget build(BuildContext context) {
 final l10n = AppLocalizations.of(context)!;
 return StreamBuilder<List<TournamentMatch>>(
 key: ValueKey(_refreshKey),
 stream: TournamentRepository().getTournamentMatches(widget.championship.id),
 builder: (context, snapshot) {
 if (!snapshot.hasData) {
 return const Scaffold(
 backgroundColor: VSPColors.background,
 body: Center(child: CircularProgressIndicator(color: VSPColors.accent)),
 );
 }

 final matches = snapshot.data!;
 if (matches.isEmpty) {
 return Scaffold(
 backgroundColor: VSPColors.background,
 appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: const VSPBackButton()),
 body: Center(child: Text(l10n.noBracketsYet, style: const TextStyle(color: VSPColors.textSecondary))),
 );
 }

 // تجميع المباريات حسب رقم الدور
 final Map<int, List<TournamentMatch>> groupedMatches = {};
 for (var match in matches) {
 groupedMatches.putIfAbsent(match.roundIndex, () => []).add(match);
 }

 final sortedRounds = groupedMatches.keys.toList()..sort((a, b) => b.compareTo(a));

 return DefaultTabController(
 length: sortedRounds.length,
 child: Scaffold(
 backgroundColor: VSPColors.background,
 appBar: AppBar(
 backgroundColor: Colors.transparent,
 elevation: 0,
 centerTitle: true,
 leading: const VSPBackButton(),
 title: Text(l10n.tournamentBrackets, style: Theme.of(context).textTheme.displaySmall),
 bottom: TabBar(
 isScrollable: true,
 indicatorColor: VSPColors.accent,
 labelColor: VSPColors.accent,
 unselectedLabelColor: VSPColors.textSecondary,
 tabs: sortedRounds.map((roundIdx) {
 return Tab(text: _getRoundLabel(context, roundIdx, sortedRounds.length));
 }).toList(),
 ),
 ),
 body: TabBarView(
 children: sortedRounds.map((roundIdx) {
 final roundMatches = groupedMatches[roundIdx]!;
 return ListView(
 padding: EdgeInsets.fromLTRB(16, 16, 16, VSPScrollPadding.bottom(context, hasFloatingNavBar: true)),
 children: [
 if (roundIdx == 0 && roundMatches.isNotEmpty && roundMatches.first.winnerId != null) ...[
 Container(
 padding: const EdgeInsets.all(16),
 margin: const EdgeInsets.only(bottom: 16),
 decoration: BoxDecoration(
 color: VSPColors.accent.withValues(alpha: 0.18),
 borderRadius: BorderRadius.circular(VSPRadius.lg),
 border: Border.all(color: VSPColors.accent, width: 2),
 boxShadow: [
 BoxShadow(color: VSPColors.accent.withValues(alpha: 0.25), blurRadius: 12),
 ],
 ),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 const Icon(Iconsax.cup_copy, color: VSPColors.accent, size: 28),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 Localizations.localeOf(context).languageCode == 'ar'
 ? 'بطل البطولة النهائي'
 : 'Final Tournament Champion',
 style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 13),
 ),
 const SizedBox(height: 2),
 Text(
 roundMatches.first.winnerId == roundMatches.first.homeTeamId
 ? (roundMatches.first.homeTeamName ?? 'Winner')
 : (roundMatches.first.awayTeamName ?? 'Winner'),
 style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 ],
 if (widget.isOwner) ...[
 _buildAutoScheduleBanner(context, roundIdx, roundMatches, sortedRounds.length),
 const SizedBox(height: 16),
 ],
 ...roundMatches.map((match) => _buildMatchCard(context, match)),
 ],
 );
 }).toList(),
 ),
 ),
 );
 },
 );
 }

 String _getRoundLabel(BuildContext context, int roundIndex, int totalRounds) {
 final l10n = AppLocalizations.of(context)!;
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';

 switch (roundIndex) {
 case 0:
 return l10n.finalRound;
 case 1:
 return l10n.semiFinalRound;
 case 2:
 return l10n.quarterFinalRound;
 case 3:
 return isArabic ? 'دور الـ 16' : 'Round of 16';
 case 4:
 return isArabic ? 'دور الـ 32' : 'Round of 32';
 default:
 if (roundIndex == totalRounds - 1) {
 return isArabic ? 'الجولة التمهيدية' : 'Preliminary Round';
 }
 return 'Round ${roundIndex + 1}';
 }
 }

 Widget _buildMatchCard(BuildContext context, TournamentMatch match) {
 final l10n = AppLocalizations.of(context)!;
 final hasSchedule = match.scheduledTime != null;
 final isTimePassed = hasSchedule && DateTime.now().isAfter(match.scheduledTime!);

 return Container(
 margin: const EdgeInsets.only(bottom: 16),
 decoration: BoxDecoration(
 color: VSPColors.surface,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: VSPColors.divider),
 ),
 child: Column(
 children: [
 Container(
 padding: const EdgeInsets.all(12),
 decoration: const BoxDecoration(
 color: VSPColors.surfaceAlt,
 borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
 ),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text(
 hasSchedule 
 ? DateFormat('MMM d, hh:mm a').format(match.scheduledTime!) 
 : l10n.notScheduled,
 style: TextStyle(color: hasSchedule ? VSPColors.accent : VSPColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
 ),
 if (widget.isOwner)
 GestureDetector(
 onTap: () async {
 final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
 if (time != null) {
 final dt = DateTime.now();
 await TournamentRepository().updateMatchScheduledTime(
 matchId: match.id,
 scheduledTime: DateTime(dt.year, dt.month, dt.day, time.hour, time.minute),
 );
 _refreshMatches();
 }
 },
 child: const Icon(Iconsax.calendar_1_copy, color: Colors.white, size: 16),
 ),
 ],
 ),
 ),
 ListTile(
 title: Text('${match.homeTeamName ?? "TBD"} vs ${match.awayTeamName ?? "TBD"}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
 subtitle: Text(
 match.winnerId != null 
 ? 'Winner: ${match.winnerId == match.homeTeamId ? match.homeTeamName : match.awayTeamName} (${match.homeScore} - ${match.awayScore})' 
 : 'Pending', 
 style: TextStyle(color: match.winnerId != null ? VSPColors.accent : Colors.white54)
 ),
 // أيقونة التعديل تفتح الآن نافذة تسجيل النتيجة وعرض الكشوفات التفاعلية
 trailing: widget.isOwner && match.winnerId == null && match.homeTeamId != null && match.awayTeamId != null 
 ? IconButton(
 icon: Icon(
 Iconsax.edit_copy, 
 color: (!hasSchedule || !isTimePassed) ? VSPColors.textSecondary.withValues(alpha: 0.5) : VSPColors.accent, 
 size: 18,
 ),
 onPressed: () {
 final isAr = Localizations.localeOf(context).languageCode == 'ar';
 if (!hasSchedule) {
 VSPFeedback.showError(context, isAr ? 'يجب تحديد موعد المباراة أولاً!' : 'Match must be scheduled first!');
 return;
 }
 if (!isTimePassed) {
 VSPFeedback.showError(context, isAr ? 'لا يمكن إدخال النتيجة إلا بعد انتهاء وقت المباراة المجدول! ' : 'Cannot enter score before scheduled match time!');
 return;
 }
 // واجهة تسجيل النتيجة المتقدمة وتسجيل الهدافين الأونلاين واليدويين
 _showScoreInputDialog(context, match);
 },
 ) 
 : null,
 ),
 ],
 ),
 );
 }

 // واجهة تسجيل النتيجة المتقدمة وتسجيل الهدافين الأونلاين واليدويين
 void _showScoreInputDialog(BuildContext context, TournamentMatch match) {
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';
 List<GoalItem> goalDetails = List.from(match.goalDetails);
 
 // Cache the Future ONCE so FutureBuilder doesn't re-trigger loading on every setModalState!
 final Future<Map<String, List<String>>> rostersFuture = _fetchRosters(match.homeTeamId ?? '', match.awayTeamId ?? '');

 // حساب الأهداف الأولية بناءً على الأهداف المسجلة أو نتيجة المباراة الحالية
 int homeScore = match.homeScore ?? goalDetails.where((g) => g.teamId == match.homeTeamId).length;
 int awayScore = match.awayScore ?? goalDetails.where((g) => g.teamId == match.awayTeamId).length;
 int homePenalties = match.homePenalties ?? 0;
 int awayPenalties = match.awayPenalties ?? 0;
 String? selectedWinnerId = match.winnerId;
 bool isSubmitting = false;

 showModalBottomSheet(
 context: context,
 isScrollControlled: true,
 useSafeArea: true,
 backgroundColor: Colors.transparent,
 builder: (sheetContext) {
 return Container(
 constraints: BoxConstraints(
 maxHeight: MediaQuery.of(sheetContext).size.height * 0.92,
 ),
 decoration: const BoxDecoration(
 color: VSPColors.background,
 borderRadius: BorderRadius.only(
 topLeft: Radius.circular(VSPRadius.xl),
 topRight: Radius.circular(VSPRadius.xl),
 ),
 ),
 child: FutureBuilder<Map<String, List<String>>>(
 future: rostersFuture,
 builder: (context, rosterSnapshot) {
 final homeRoster = rosterSnapshot.data?['home'] ?? [];
 final awayRoster = rosterSnapshot.data?['away'] ?? [];

 return StatefulBuilder(
 builder: (BuildContext context, StateSetter setModalState) {
 final isKnockoutOrCup = widget.championship.type == 'Cup' || match.stage == 'knockout' || match.stage == 'preliminary';
 final isCupAndTied = isKnockoutOrCup && homeScore == awayScore;

 if (isCupAndTied && homePenalties != awayPenalties) {
 if (homePenalties > awayPenalties) {
 selectedWinnerId = match.homeTeamId;
 } else if (awayPenalties > homePenalties) {
 selectedWinnerId = match.awayTeamId;
 }
 }

 final bool isValidToSubmit = !isCupAndTied || selectedWinnerId != null;

 final homeGoals = goalDetails.where((g) => g.teamId == match.homeTeamId).toList();
 final awayGoals = goalDetails.where((g) => g.teamId == match.awayTeamId).toList();

 return Column(
 children: [
 const SizedBox(height: 12),
 Container(
 width: 40, height: 4,
 decoration: BoxDecoration(color: VSPColors.divider, borderRadius: BorderRadius.circular(2)),
 ),
 const SizedBox(height: 20),
 Padding(
 padding: const EdgeInsets.symmetric(horizontal: 20),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text(isArabic ? 'تسجيل نتيجة وهدافي المباراة ' : 'Submit Score & Goal Scorers ', style: Theme.of(context).textTheme.displaySmall),
 IconButton(
 icon: const Icon(Iconsax.close_circle_copy, color: VSPColors.textSecondary, size: 18),
 onPressed: () => Navigator.pop(sheetContext),
 ),
 ],
 ),
 ),
 const Divider(color: VSPColors.divider),
 
 Expanded(
 child: SingleChildScrollView(
 padding: const EdgeInsets.all(20),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // واجهة تسجيل الأهداف التفاعلية لكلا الفريقين
 Row(
 children: [
 // الفريق الأول (المستضيف)
 Expanded(
 child: _buildScoreCounterColumn(
 teamName: match.homeTeamName ?? 'Team A',
 score: homeScore,
 onIncrement: () {
 _openAddGoalModal(
 context,
 teamId: match.homeTeamId ?? 'home',
 teamName: match.homeTeamName ?? 'Team A',
 roster: homeRoster,
 onGoalAdded: (goal) {
 setModalState(() {
 goalDetails.add(goal);
 homeScore++;
 selectedWinnerId = null;
 });
 },
 );
 },
 onDecrement: () => setModalState(() {
 if (homeScore > 0) {
 homeScore--;
 if (homeGoals.isNotEmpty) {
 goalDetails.remove(homeGoals.last);
 }
 selectedWinnerId = null;
 }
 }),
 ),
 ),
 const Text('VS', style: TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 24)),
 // الفريق الثاني (الضيف)
 Expanded(
 child: _buildScoreCounterColumn(
 teamName: match.awayTeamName ?? 'Team B',
 score: awayScore,
 onIncrement: () {
 _openAddGoalModal(
 context,
 teamId: match.awayTeamId ?? 'away',
 teamName: match.awayTeamName ?? 'Team B',
 roster: awayRoster,
 onGoalAdded: (goal) {
 setModalState(() {
 goalDetails.add(goal);
 awayScore++;
 selectedWinnerId = null;
 });
 },
 );
 },
 onDecrement: () => setModalState(() {
 if (awayScore > 0) {
 awayScore--;
 if (awayGoals.isNotEmpty) {
 goalDetails.remove(awayGoals.last);
 }
 selectedWinnerId = null;
 }
 }),
 ),
 ),
 ],
 ),
 const SizedBox(height: 16),

 // قائمة هدافي المباراة المسجلين
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // هدافو الفريق الأول
 Expanded(
 child: _buildGoalScorersList(
 teamName: match.homeTeamName ?? 'Team A',
 goals: homeGoals,
 onRemoveGoal: (goal) {
 setModalState(() {
 goalDetails.remove(goal);
 if (homeScore > 0) homeScore--;
 });
 },
 isArabic: isArabic,
 ),
 ),
 const SizedBox(width: 12),
 // هدافو الفريق الثاني
 Expanded(
 child: _buildGoalScorersList(
 teamName: match.awayTeamName ?? 'Team B',
 goals: awayGoals,
 onRemoveGoal: (goal) {
 setModalState(() {
 goalDetails.remove(goal);
 if (awayScore > 0) awayScore--;
 });
 },
 isArabic: isArabic,
 ),
 ),
 ],
 ),
 const SizedBox(height: 20),

 // سيناريو التعادل في الكأس / الإقصائيات (ركلات الترجيح)
 if (isCupAndTied) ...[
 Container(
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: VSPColors.warning.withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(VSPRadius.md),
 border: Border.all(color: VSPColors.warning.withValues(alpha: 0.3)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 isArabic 
 ? 'ركلات الترجيح / Penalties Shootout' 
 : 'Penalty Shootout (Knockout Draw)',
 style: const TextStyle(color: VSPColors.warning, fontWeight: FontWeight.bold, fontSize: 13),
 ),
 const SizedBox(height: 4),
 Text(
 isArabic 
 ? 'أدخل أهداف ركلات الترجيح وحدد الفريق المتأهل:' 
 : 'Enter penalty goals & select advancing team:',
 style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: _buildScoreCounterColumn(
 teamName: '${match.homeTeamName ?? "Home"} (ركلات)',
 score: homePenalties,
 onIncrement: () => setModalState(() {
 homePenalties++;
 if (homePenalties > awayPenalties) selectedWinnerId = match.homeTeamId;
 }),
 onDecrement: () => setModalState(() {
 if (homePenalties > 0) homePenalties--;
 if (homePenalties > awayPenalties) {
 selectedWinnerId = match.homeTeamId;
 } else if (awayPenalties > homePenalties) {
 selectedWinnerId = match.awayTeamId;
 }
 }),
 ),
 ),
 const SizedBox(width: 8),
 Expanded(
 child: _buildScoreCounterColumn(
 teamName: '${match.awayTeamName ?? "Away"} (ركلات)',
 score: awayPenalties,
 onIncrement: () => setModalState(() {
 awayPenalties++;
 if (awayPenalties > homePenalties) selectedWinnerId = match.awayTeamId;
 }),
 onDecrement: () => setModalState(() {
 if (awayPenalties > 0) awayPenalties--;
 if (homePenalties > awayPenalties) {
 selectedWinnerId = match.homeTeamId;
 } else if (awayPenalties > homePenalties) {
 selectedWinnerId = match.awayTeamId;
 }
 }),
 ),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: _buildPenaltyWinnerButton(
 label: match.homeTeamName ?? 'Home',
 isSelected: selectedWinnerId == match.homeTeamId,
 onTap: () => setModalState(() => selectedWinnerId = match.homeTeamId),
 ),
 ),
 const SizedBox(width: 8),
 Expanded(
 child: _buildPenaltyWinnerButton(
 label: match.awayTeamName ?? 'Away',
 isSelected: selectedWinnerId == match.awayTeamId,
 onTap: () => setModalState(() => selectedWinnerId = match.awayTeamId),
 ),
 ),
 ],
 ),
 ],
 ),
 ),
 const SizedBox(height: 24),
 ],

 const Divider(color: VSPColors.divider),
 const SizedBox(height: 12),

 // جلب وعرض كشف أسماء اللاعبين (Roster Viewer)
 Text(
 isArabic ? ' كشف أسماء اللاعبين المشاركين بالبطولة:' : ' Championship Team Rosters:',
 style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
 ),
 const SizedBox(height: 12),
 if (rosterSnapshot.connectionState == ConnectionState.waiting)
 const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: VSPColors.accent)))
 else
 Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(child: _buildRosterListColumn(match.homeTeamName ?? 'Home', homeRoster)),
 const SizedBox(width: 12),
 Expanded(child: _buildRosterListColumn(match.awayTeamName ?? 'Away', awayRoster)),
 ],
 ),
 ],
 ),
 ),
 ),

 // أزرار التأكيد والإرسال
 Container(
 padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(sheetContext).padding.bottom + MediaQuery.of(sheetContext).viewInsets.bottom + 16),
 decoration: const BoxDecoration(
 border: Border(top: BorderSide(color: VSPColors.divider, width: 0.5)),
 ),
 child: Row(
 children: [
 Expanded(
 child: PrimaryButton(
 text: isArabic ? 'إلغاء' : 'Cancel',
 color: VSPColors.surfaceAlt,
 textColor: VSPColors.textPrimary,
 onPressed: () => Navigator.pop(sheetContext),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: PrimaryButton(
 text: isArabic ? 'تأكيد النتيجة والهدافين ' : 'Submit & Advance',
 isLoading: isSubmitting,
 onPressed: !isValidToSubmit ? null : () async {
 setModalState(() => isSubmitting = true);
 try {
 final finalWinnerId = (homeScore == awayScore)
 ? selectedWinnerId
 : (homeScore > awayScore ? match.homeTeamId : match.awayTeamId);

 final finalWinnerName = finalWinnerId == match.homeTeamId
 ? match.homeTeamName
 : match.awayTeamName;

 await TournamentRepository().updateTournamentMatchScore(
 matchId: match.id,
 homeScore: homeScore,
 awayScore: awayScore,
 homePenalties: isCupAndTied ? homePenalties : null,
 awayPenalties: isCupAndTied ? awayPenalties : null,
 winnerId: finalWinnerId,
 winnerName: finalWinnerName,
 goalDetails: goalDetails,
 );

 if (sheetContext.mounted) {
 Navigator.pop(sheetContext);
 }
 if (context.mounted) {
 _refreshMatches();
 VSPFeedback.showSuccess(
 context,
 isArabic
 ? 'تم تسجيل نتيجة المباراة وهدافيها وتصعيد $finalWinnerName بنجاح.'
 : 'Match score, goal scorers saved & $finalWinnerName advanced successfully.',
 );
 }
 } catch (e) {
 setModalState(() => isSubmitting = false);
 if (sheetContext.mounted) {
 VSPFeedback.showError(sheetContext, isArabic ? 'حدث خطأ أثناء تسجيل النتيجة' : 'Error submitting score');
 }
 }
 },
 ),
 ),
 ],
 ),
 ),
 ],
 );
 },
 );
 },
 ),
 );
 },
 );
 }

 // مكوّن عداد الأهداف التفاعلي
 Widget _buildScoreCounterColumn({
 required String teamName,
 required int score,
 required VoidCallback onIncrement,
 required VoidCallback onDecrement,
 }) {
 return Column(
 children: [
 Text(teamName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
 const SizedBox(height: 12),
 Row(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 GestureDetector(
 onTap: onDecrement,
 child: Container(
 padding: const EdgeInsets.all(8),
 decoration: const BoxDecoration(color: VSPColors.surfaceAlt, shape: BoxShape.circle),
 child: const Icon(Iconsax.minus_cirlce_copy, color: Colors.white, size: 14),
 ),
 ),
 Padding(
 padding: const EdgeInsets.symmetric(horizontal: 16),
 child: Text('$score', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
 ),
 GestureDetector(
 onTap: onIncrement,
 child: Container(
 padding: const EdgeInsets.all(8),
 decoration: const BoxDecoration(color: VSPColors.accent, shape: BoxShape.circle),
 child: const Icon(Iconsax.add_circle_copy, color: Colors.black, size: 14),
 ),
 ),
 ],
 ),
 ],
 );
 }

 // HELPER: Build Goal Scorers Chip List
 Widget _buildGoalScorersList({
 required String teamName,
 required List<GoalItem> goals,
 required Function(GoalItem goal) onRemoveGoal,
 required bool isArabic,
 }) {
 return Container(
 padding: const EdgeInsets.all(10),
 decoration: BoxDecoration(
 color: VSPColors.surface,
 borderRadius: BorderRadius.circular(VSPRadius.md),
 border: Border.all(color: VSPColors.divider),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Icon(Iconsax.element_4_copy, color: VSPColors.accent, size: 12),
 const SizedBox(width: 6),
 Expanded(
 child: Text(
 isArabic ? 'هدافو $teamName' : '$teamName Scorers',
 style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 11),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 ),
 ],
 ),
 const SizedBox(height: 8),
 if (goals.isEmpty)
 Text(isArabic ? 'لم يتم تسجيل أهداف بعد' : 'No goals recorded', style: const TextStyle(color: VSPColors.textSecondary, fontSize: 10))
 else
 Wrap(
 spacing: 6,
 runSpacing: 6,
 children: goals.map((g) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
 decoration: BoxDecoration(
 color: VSPColors.surfaceAlt,
 borderRadius: BorderRadius.circular(VSPRadius.sm),
 border: Border.all(color: VSPColors.accent.withValues(alpha: 0.4)),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Text(
 '⚽ ${g.playerName}',
 style: const TextStyle(
 color: Colors.white,
 fontSize: 10,
 fontWeight: FontWeight.w600,
 ),
 ),
 const SizedBox(width: 4),
 GestureDetector(
 onTap: () => onRemoveGoal(g),
 child: const Icon(Iconsax.close_circle_copy, color: Colors.white54, size: 10),
 ),
 ],
 ),
 );
 }).toList(),
 ),
 ],
 ),
 );
 }

 // HELPER: Open Add Goal Modal
 void _openAddGoalModal(
 BuildContext context, {
 required String teamId,
 required String teamName,
 required List<String> roster,
 required Function(GoalItem goal) onGoalAdded,
 }) {
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';
 final TextEditingController customNameController = TextEditingController();
 String? selectedFromRoster;

 showDialog(
 context: context,
 builder: (dlgCtx) {
 return StatefulBuilder(
 builder: (context, setDlgState) {
 return AlertDialog(
 backgroundColor: VSPColors.surface,
 surfaceTintColor: Colors.transparent,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
 title: Row(
 children: [
 const Icon(Iconsax.element_4_copy, color: VSPColors.accent, size: 18),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 isArabic ? 'تسجيل هدف لـ $teamName ' : 'Record Goal for $teamName ',
 style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
 ),
 ),
 ],
 ),
 content: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Player Selection from Roster
 if (roster.isNotEmpty) ...[
 Text(
 isArabic ? 'اختر اسم الهداف من كشف اللاعبين:' : 'Select scorer from roster:',
 style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
 ),
 const SizedBox(height: 6),
 Container(
 width: double.infinity,
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
 decoration: BoxDecoration(
 color: VSPColors.surfaceAlt,
 borderRadius: BorderRadius.circular(VSPRadius.md),
 border: Border.all(color: VSPColors.divider),
 ),
 child: DropdownButton<String>(
 value: selectedFromRoster,
 isExpanded: true,
 hint: Text(isArabic ? 'اختر لاعباً...' : 'Select a player...', style: const TextStyle(color: Colors.white54, fontSize: 12)),
 dropdownColor: VSPColors.surface,
 underline: const SizedBox(),
 style: const TextStyle(color: Colors.white, fontSize: 12),
 items: roster.map((name) {
 return DropdownMenuItem<String>(
 value: name,
 child: Text(name),
 );
 }).toList(),
 onChanged: (val) {
 setDlgState(() {
 selectedFromRoster = val;
 if (val != null) customNameController.text = val;
 });
 },
 ),
 ),
 const SizedBox(height: 10),
 Center(
 child: Text(isArabic ? 'أو' : 'OR', style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
 ),
 const SizedBox(height: 10),
 ],

 // Manual Player Name Text Field
 Text(
 isArabic ? 'ادخل اسم الهداف يدوياً (للقوائم اليدوية):' : 'Enter scorer name manually:',
 style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
 ),
 const SizedBox(height: 6),
 TextField(
 controller: customNameController,
 style: const TextStyle(color: Colors.white, fontSize: 13),
 decoration: InputDecoration(
 hintText: isArabic ? 'مثال: أحمد حسام / لاعب 1' : 'e.g. Ahmed / Player 1',
 hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
 filled: true,
 fillColor: VSPColors.surfaceAlt,
 contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
 border: OutlineInputBorder(borderRadius: BorderRadius.circular(VSPRadius.md), borderSide: const BorderSide(color: VSPColors.divider)),
 ),
 onChanged: (val) {
 if (selectedFromRoster != null && val != selectedFromRoster) {
 setDlgState(() => selectedFromRoster = null);
 }
 },
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(dlgCtx),
 child: Text(isArabic ? 'إلغاء' : 'Cancel', style: const TextStyle(color: VSPColors.textSecondary)),
 ),
 ElevatedButton(
 style: ElevatedButton.styleFrom(
 backgroundColor: VSPColors.accent,
 foregroundColor: Colors.black,
 ),
 onPressed: () {
 final finalName = customNameController.text.trim().isNotEmpty
 ? customNameController.text.trim()
 : (selectedFromRoster ?? (isArabic ? 'لاعب مجهول' : 'Unknown Player'));

 onGoalAdded(GoalItem(
 id: DateTime.now().millisecondsSinceEpoch.toString(),
 teamId: teamId,
 playerName: finalName,
 isOwnGoal: false,
 ));
 Navigator.pop(dlgCtx);
 },
 child: Text(isArabic ? 'حفظ الهدف ' : 'Save Goal ', style: const TextStyle(fontWeight: FontWeight.bold)),
 ),
 ],
 );
 },
 );
 },
 ).then((_) {
 customNameController.dispose();
 });
 }

 // زر تحديد الفائز بركلات الترجيح
 Widget _buildPenaltyWinnerButton({
 required String label,
 required bool isSelected,
 required VoidCallback onTap,
 }) {
 return GestureDetector(
 onTap: onTap,
 child: AnimatedContainer(
 duration: const Duration(milliseconds: 200),
 padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
 alignment: Alignment.center,
 decoration: BoxDecoration(
 color: isSelected ? VSPColors.accent : VSPColors.surface,
 borderRadius: BorderRadius.circular(VSPRadius.md),
 border: Border.all(color: isSelected ? VSPColors.accent : VSPColors.divider, width: 1.5),
 ),
 child: Text(
 label,
 style: TextStyle(
 color: isSelected ? Colors.black : Colors.white,
 fontWeight: FontWeight.bold,
 fontSize: 12,
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 ),
 );
 }

 // عمود كشف اللاعبين المشاركين
 Widget _buildRosterListColumn(String teamName, List<String> roster) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(teamName, style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
 const SizedBox(height: 6),
 Container(
 width: double.infinity,
 padding: const EdgeInsets.all(8),
 decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(8)),
 child: roster.isEmpty
 ? const Text('لا يوجد لاعبون مسجلون', style: TextStyle(color: VSPColors.textSecondary, fontSize: 11))
 : Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: roster.asMap().entries.map((entry) {
 final idx = entry.key;
 final name = entry.value;
 return Padding(
 padding: const EdgeInsets.symmetric(vertical: 4),
 child: Text('${idx + 1}. $name', style: const TextStyle(color: Colors.white70, fontSize: 11)),
 );
 }).toList(),
 ),
 ),
 ],
 );
 }

 // BANNER: Auto Schedule Button Banner for Round
 Widget _buildAutoScheduleBanner(BuildContext context, int roundIdx, List<TournamentMatch> matches, int totalRounds) {
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';
 final roundName = _getRoundLabel(context, roundIdx, totalRounds);
 final bool hasScheduledMatches = matches.any((m) => m.scheduledTime != null);
 final bool isRoundStartedOrFinished = matches.any((m) => m.winnerId != null || m.homeScore != null);

 // منع إعادة الجدولة التلقائية أو التصفير بعد بدء أو انتهاء مباريات هذا الدور
 if (isRoundStartedOrFinished) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 decoration: BoxDecoration(
 color: VSPColors.surfaceAlt,
 borderRadius: BorderRadius.circular(VSPRadius.md),
 border: Border.all(color: VSPColors.divider),
 ),
 child: Row(
 children: [
 Container(
 padding: const EdgeInsets.all(8),
 decoration: const BoxDecoration(
 color: Colors.white10,
 shape: BoxShape.circle,
 ),
 child: const Icon(Iconsax.lock_copy, color: VSPColors.textSecondary, size: 14),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 isArabic ? 'جدول مباريات $roundName (مُغلق )' : '$roundName Schedule (Locked )',
 style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
 ),
 const SizedBox(height: 2),
 Text(
 isArabic
 ? 'تم بدء مباريات هذا الدور وتسجيل نتائجها (لا يمكن إعادة الجدولة التلقائية)'
 : 'Matches in this round have started (Auto-scheduling locked)',
 style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
 ),
 ],
 ),
 ),
 ],
 ),
 );
 }

 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
 decoration: BoxDecoration(
 color: VSPColors.accent.withValues(alpha: 0.12),
 borderRadius: BorderRadius.circular(VSPRadius.md),
 border: Border.all(color: VSPColors.accent.withValues(alpha: 0.4)),
 ),
 child: Row(
 children: [
 Container(
 padding: const EdgeInsets.all(10),
 decoration: BoxDecoration(
 color: VSPColors.accent.withValues(alpha: 0.2),
 shape: BoxShape.circle,
 ),
 child: const Icon(Iconsax.magic_star_copy, color: VSPColors.accent, size: 16),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 isArabic
 ? (hasScheduledMatches ? 'تعديل جدول $roundName' : 'جدولة تلقائية لمباريات $roundName')
 : (hasScheduledMatches ? 'Manage $roundName Schedule' : 'Auto-Schedule $roundName'),
 style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
 ),
 const SizedBox(height: 2),
 Text(
 isArabic
 ? (hasScheduledMatches ? 'تم جدولة مباريات هذا الدور. يمكنك التصفير أو إعادة الجدولة' : 'توليد المواعيد والتواريخ تلقائياً لـ ${matches.length} مباراة')
 : (hasScheduledMatches ? 'Matches scheduled. You can reset or re-schedule.' : 'Auto generate dates for ${matches.length} matches'),
 style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
 ),
 ],
 ),
 ),
 if (hasScheduledMatches) ...[
 IconButton(
 tooltip: isArabic ? 'تصفير الجدول وإلغاء المواعيد ' : 'Reset Round Schedule',
 icon: const Icon(Iconsax.rotate_left_copy, color: VSPColors.error, size: 16),
 onPressed: () => _confirmResetRoundSchedule(context, roundIdx, matches, roundName),
 ),
 const SizedBox(width: 4),
 ],
 ElevatedButton(
 style: ElevatedButton.styleFrom(
 backgroundColor: VSPColors.accent,
 foregroundColor: Colors.black,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.sm)),
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 ),
 onPressed: () => _showAutoScheduleDialog(context, roundIdx, matches, roundName),
 child: Text(
 isArabic
 ? (hasScheduledMatches ? 'إعادة الجدولة ' : 'جدولة ')
 : (hasScheduledMatches ? 'Re-Schedule ' : 'Schedule '),
 style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
 ),
 ),
 ],
 ),
 );
 }

 // CONFIRMATION: Reset All Match Schedules for Round
 void _confirmResetRoundSchedule(BuildContext context, int roundIdx, List<TournamentMatch> matches, String roundName) {
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';

 showDialog(
 context: context,
 builder: (dialogCtx) {
 return AlertDialog(
 backgroundColor: VSPColors.surface,
 surfaceTintColor: Colors.transparent,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
 title: Row(
 children: [
 const Icon(Iconsax.rotate_left_copy, color: VSPColors.warning, size: 18),
 const SizedBox(width: 8),
 Text(
 isArabic ? 'تصفير جدول $roundName' : 'Reset $roundName Schedule',
 style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
 ),
 ],
 ),
 content: Text(
 isArabic
 ? 'هل أنت تأكد من إلغاء وتصفير مواعيد جميع مباريات ($roundName) وإعادتها إلى "غير مجدول"؟'
 : 'Are you sure you want to reset all match dates for ($roundName) to unscheduled?',
 style: const TextStyle(color: Colors.white70, fontSize: 13),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(dialogCtx),
 child: Text(isArabic ? 'إلغاء' : 'Cancel', style: const TextStyle(color: VSPColors.textSecondary)),
 ),
 ElevatedButton(
 style: ElevatedButton.styleFrom(
 backgroundColor: VSPColors.error,
 foregroundColor: Colors.white,
 ),
 onPressed: () async {
 Navigator.pop(dialogCtx);
 final success = await TournamentRepository().clearRoundMatchSchedules(
 championshipId: widget.championship.id,
 roundIndex: roundIdx,
 matches: matches,
 );

 if (success && context.mounted) {
 _refreshMatches();
 VSPFeedback.showSuccess(
 context,
 isArabic
 ? ' تم تصفير وإلغاء جدول مباريات $roundName بنجاح!'
 : ' Reset schedule for $roundName successfully!',
 );
 }
 },
 child: Text(isArabic ? 'تأكيد التصفير ' : 'Confirm Reset'),
 ),
 ],
 );
 },
 );
 }

 // POPUP MODAL: Auto Schedule Options Popup
 void _showAutoScheduleDialog(BuildContext context, int roundIdx, List<TournamentMatch> matches, String roundName) {
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';
 int daysCount = 1;
 DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
 TimeOfDay selectedTime = const TimeOfDay(hour: 18, minute: 0);
 // Default to the exact duration set during tournament creation (e.g. 20 mins)!
 final int presetDuration = widget.championship.matchDuration;
 int selectedMatchDuration = presetDuration;

 final List<int> durationOptions = [15, 20, 30, 45, 60, 90];
 if (!durationOptions.contains(presetDuration)) {
 durationOptions.add(presetDuration);
 durationOptions.sort();
 }

 List<int> availableDaysOptions = [1];
 if (matches.length >= 8) {
 availableDaysOptions = [1, 2, 4];
 } else if (matches.length >= 4) {
 availableDaysOptions = [1, 2];
 }

 showModalBottomSheet(
 context: context,
 isScrollControlled: true,
 backgroundColor: Colors.transparent,
 builder: (modalCtx) {
 return StatefulBuilder(
 builder: (context, setModalState) {
 final matchesPerDay = (matches.length / daysCount).ceil();

 return Container(
 padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(modalCtx).padding.bottom + 20),
 decoration: const BoxDecoration(
 color: VSPColors.background,
 borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
 ),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Center(
 child: Container(
 width: 40, height: 4,
 decoration: BoxDecoration(color: VSPColors.divider, borderRadius: BorderRadius.circular(2)),
 ),
 ),
 const SizedBox(height: 16),
 Row(
 children: [
 Container(
 padding: const EdgeInsets.all(8),
 decoration: const BoxDecoration(color: VSPColors.accent, shape: BoxShape.circle),
 child: const Icon(Iconsax.magic_star_copy, color: Colors.black, size: 14),
 ),
 const SizedBox(width: 10),
 Expanded(
 child: Text(
 isArabic ? 'الجدولة التلقائية ($roundName)' : 'Auto Schedule ($roundName)',
 style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 ),
 IconButton(
 icon: const Icon(Iconsax.close_circle_copy, color: VSPColors.textSecondary, size: 18),
 onPressed: () => Navigator.pop(modalCtx),
 ),
 ],
 ),
 const Divider(color: VSPColors.divider),
 const SizedBox(height: 14),

 // 1. Days Distribution Options
 Text(
 isArabic ? 'كيف تريد توزيع مباريات الدور (${matches.length} مباراة)؟' : 'How to divide ${matches.length} matches?',
 style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
 ),
 const SizedBox(height: 12),
 Row(
 children: availableDaysOptions.map((d) {
 final isSelected = daysCount == d;
 final mPerD = (matches.length / d).ceil();
 
 String title = isArabic 
 ? (d == 1 ? 'يوم واحد' : (d == 2 ? 'يومان' : '4 أيام'))
 : (d == 1 ? '1 Day' : '$d Days');
 String subtitle = isArabic ? '$mPerD مباريات/يوم' : '$mPerD matches/day';
 if (d == 1) subtitle = isArabic ? '$mPerD مباراة' : '$mPerD matches';

 return Expanded(
 child: GestureDetector(
 onTap: () => setModalState(() => daysCount = d),
 child: AnimatedContainer(
 duration: const Duration(milliseconds: 200),
 margin: const EdgeInsets.symmetric(horizontal: 4),
 padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
 decoration: BoxDecoration(
 color: isSelected ? VSPColors.accent : VSPColors.surface,
 borderRadius: BorderRadius.circular(VSPRadius.md),
 border: Border.all(color: isSelected ? VSPColors.accent : VSPColors.divider, width: 1.5),
 ),
 child: Column(
 children: [
 Icon(
 d == 1 ? Iconsax.calendar_1_copy : (d == 2 ? Iconsax.calendar_1_copy : Iconsax.calendar_1_copy),
 color: isSelected ? Colors.black : VSPColors.accent,
 size: 16,
 ),
 const SizedBox(height: 6),
 Text(
 title,
 textAlign: TextAlign.center,
 style: TextStyle(
 color: isSelected ? Colors.black : Colors.white,
 fontWeight: FontWeight.bold,
 fontSize: 12,
 ),
 ),
 const SizedBox(height: 2),
 Text(
 subtitle,
 textAlign: TextAlign.center,
 style: TextStyle(
 color: isSelected ? Colors.black87 : VSPColors.textSecondary,
 fontSize: 10,
 ),
 ),
 ],
 ),
 ),
 ),
 );
 }).toList(),
 ),
 const SizedBox(height: 20),

 // 2. Start Date & Start Time Pickers
 Row(
 children: [
 // Date Picker
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(isArabic ? 'تاريخ أول مباراة:' : 'Start Date:', style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12)),
 const SizedBox(height: 6),
 InkWell(
 onTap: () async {
 final d = await showDatePicker(
 context: context,
 initialDate: selectedDate,
 firstDate: DateTime.now(),
 lastDate: DateTime.now().add(const Duration(days: 90)),
 );
 if (d != null) setModalState(() => selectedDate = d);
 },
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
 decoration: BoxDecoration(
 color: VSPColors.surface,
 borderRadius: BorderRadius.circular(VSPRadius.md),
 border: Border.all(color: VSPColors.divider),
 ),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text(
 DateFormat('yyyy-MM-dd').format(selectedDate),
 style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
 ),
 const Icon(Iconsax.calendar_1_copy, color: VSPColors.accent, size: 14),
 ],
 ),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(width: 12),
 // Time Picker
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(isArabic ? 'وقت أول مباراة:' : 'Start Time:', style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12)),
 const SizedBox(height: 6),
 InkWell(
 onTap: () async {
 final t = await showTimePicker(context: context, initialTime: selectedTime);
 if (t != null) setModalState(() => selectedTime = t);
 },
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
 decoration: BoxDecoration(
 color: VSPColors.surface,
 borderRadius: BorderRadius.circular(VSPRadius.md),
 border: Border.all(color: VSPColors.divider),
 ),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text(
 selectedTime.format(context),
 style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
 ),
 const Icon(Iconsax.clock_copy, color: VSPColors.accent, size: 14),
 ],
 ),
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 const SizedBox(height: 16),

 // 3. Match Duration Selector (Defaults to tournament setting, fully editable)
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Row(
 children: [
 const Icon(Iconsax.clock_copy, color: VSPColors.accent, size: 14),
 const SizedBox(width: 8),
 Text(
 isArabic ? 'مدة المباراة / الفاصل:' : 'Match Duration:',
 style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
 ),
 ],
 ),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
 decoration: BoxDecoration(
 color: VSPColors.surface,
 borderRadius: BorderRadius.circular(VSPRadius.md),
 border: Border.all(color: VSPColors.divider),
 ),
 child: DropdownButton<int>(
 value: selectedMatchDuration,
 underline: const SizedBox(),
 dropdownColor: VSPColors.surface,
 style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 12),
 items: durationOptions.map((mins) {
 return DropdownMenuItem<int>(
 value: mins,
 child: Text(
 mins == presetDuration 
 ? '$mins دقيقة (إعدادات البطولة)' 
 : '$mins دقيقة',
 ),
 );
 }).toList(),
 onChanged: (v) {
 if (v != null) setModalState(() => selectedMatchDuration = v);
 },
 ),
 ),
 ],
 ),
 const SizedBox(height: 16),

 // 4. Summary Preview Box
 Container(
 width: double.infinity,
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: VSPColors.surfaceAlt,
 borderRadius: BorderRadius.circular(VSPRadius.md),
 border: Border.all(color: VSPColors.divider),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Text('', style: TextStyle(fontSize: 14)),
 const SizedBox(width: 6),
 Text(
 isArabic ? 'ملخص الجدولة التلقائية:' : 'Schedule Summary:',
 style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 13),
 ),
 ],
 ),
 const SizedBox(height: 8),
 Text(
 isArabic
 ? '• سيتم إدراج $matchesPerDay ${matchesPerDay == 1 ? 'مباراة' : 'مباريات'} يومياً على مدار ${daysCount == 1 ? 'يوم واحد' : (daysCount == 2 ? 'يومين' : '$daysCount أيام')}.'
 : '• $matchesPerDay matches daily over $daysCount day(s).',
 style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
 ),
 const SizedBox(height: 4),
 Text(
 isArabic
 ? '• تبدأ المباريات يومياً الساعة ${selectedTime.format(context)} بفاصل $selectedMatchDuration دقيقة.'
 : '• Matches start at ${selectedTime.format(context)} with $selectedMatchDuration min interval.',
 style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
 ),
 ],
 ),
 ),
 const SizedBox(height: 20),

 // 5. Confirm Button
 SizedBox(
 width: double.infinity,
 child: PrimaryButton(
 text: isArabic ? 'تأكيد وحفظ الجدولة التلقائية ' : 'Save Auto-Schedule ',
 onPressed: () async {
 Navigator.pop(modalCtx);
 final success = await TournamentRepository().autoScheduleRoundMatches(
 championshipId: widget.championship.id,
 roundIndex: roundIdx,
 matches: matches,
 startDate: selectedDate,
 startTime: selectedTime,
 daysCount: daysCount,
 matchDurationMinutes: selectedMatchDuration,
 );

 if (success && context.mounted) {
 _refreshMatches();
 VSPFeedback.showSuccess(
 context,
 isArabic
 ? ' تم جدولة جميع مباريات $roundName تلقائياً بنجاح!'
 : ' Auto-scheduled all $roundName matches successfully!',
 );
 } else if (!success && context.mounted) {
 VSPFeedback.showError(context, isArabic ? 'حدث خطأ أثناء الجدولة التلقائية' : 'Error auto-scheduling matches');
 }
 },
 ),
 ),
 ],
 ),
 );
 },
 );
 },
 );
 }
}
