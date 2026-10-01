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
import '../../../core/utils/vsp_feedback.dart';
import '../../../core/utils/vsp_launcher_utils.dart';
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
 final TextEditingController _challengeCodeController = TextEditingController();
 String _searchQuery = '';
 Team? _selectedTeam;
 Team? _userTeam;
 String? _appliedChallengeCode;
 Timer? _debounce;
 bool _isSearching = false;
 bool _isLookingUpCode = false;
 bool _isGeneratingCode = false;
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
 _userTeam = team;
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
 _challengeCodeController.dispose();
 _debounce?.cancel();
 super.dispose();
 }

 Future<void> _handleLookupCode() async {
 final code = _challengeCodeController.text.trim();
 if (code.isEmpty) return;

 FocusScope.of(context).unfocus();
 setState(() => _isLookingUpCode = true);

 try {
 final res = await TeamRepository().lookupChallengeCode(code);
 if (!mounted) return;

 if (res['success'] == true && res['opponent_team_id'] != null) {
 final oppId = res['opponent_team_id'].toString();
 final oppTeam = await TeamRepository().getTeam(oppId);
 if (!mounted) return;

 if (oppTeam != null) {
 setState(() {
 _selectedTeam = oppTeam;
 _appliedChallengeCode = code.toUpperCase();
 _isLookingUpCode = false;
 });
 VSPFeedback.showSuccess(
 context,
 'تم العثور على الفريق المنافس: ${oppTeam.name}',
 );
 return;
 }
 }

 if (!mounted) return;
 setState(() => _isLookingUpCode = false);
 final err = res['error']?.toString() ?? '';
 String errorMsg;
 if (err == 'CODE_INVALID_OR_USED') {
 errorMsg = 'كود التحدي غير صالح أو تم استخدامه مسبقاً.';
 } else if (err == 'CALLER_NOT_A_CAPTAIN') {
 errorMsg = 'يجب أن تكون كابتن فريق لتحدي هذا الكود.';
 } else if (err == 'CANNOT_CHALLENGE_OWN_TEAM') {
 errorMsg = 'لا يمكنك إدخال كود فريقك نفسه.';
 } else if (err == 'TEAM_NOT_FOUND') {
 errorMsg = 'تعذر العثور على الفريق التابع لهذا الكود.';
 } else {
 errorMsg = 'تعذر التحقق من كود التحدي. تأكد من الكود وأعد المحاولة.';
 }
 VSPFeedback.showError(context, errorMsg);
 } catch (e) {
 if (mounted) {
 setState(() => _isLookingUpCode = false);
 VSPFeedback.showError(context, 'حدث خطأ أثناء فحص الكود');
 }
 }
 }

 Future<void> _showMyChallengeCodeModal() async {
 if (_userTeam == null) return;
 setState(() => _isGeneratingCode = true);

 try {
 final res = await TeamRepository().generateChallengeCode(_userTeam!.id);
 if (!mounted) return;
 setState(() => _isGeneratingCode = false);

 if (res['success'] != true || res['code'] == null) {
 final err = res['error']?.toString();
 VSPFeedback.showError(
 context,
 err == 'CAPTAIN_ONLY'
 ? 'توليد الكود متاح لكابتن الفريق فقط.'
 : 'تعذر توليد كود التحدي حالياً.',
 );
 return;
 }

 final code = res['code'].toString();
 _displayChallengeCodeBottomSheet(code);
 } catch (e) {
 if (mounted) {
 setState(() => _isGeneratingCode = false);
 VSPFeedback.showError(context, 'حدث خطأ أثناء توليد الكود');
 }
 }
 }

 void _displayChallengeCodeBottomSheet(String code) {
 final teamName = _userTeam?.name ?? 'فريقنا';
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';

 showModalBottomSheet(
 context: context,
 backgroundColor: Colors.transparent,
 isScrollControlled: true,
 builder: (ctx) => Container(
 padding: EdgeInsets.fromLTRB(
 VSPSpacing.lg,
 VSPSpacing.md,
 VSPSpacing.lg,
 MediaQuery.of(ctx).padding.bottom + VSPSpacing.lg,
 ),
 decoration: const BoxDecoration(
 color: VSPColors.surface,
 borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
 ),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Center(
 child: Container(
 width: 40,
 height: 4,
 decoration: BoxDecoration(
 color: VSPColors.divider,
 borderRadius: BorderRadius.circular(2),
 ),
 ),
 ),
 const SizedBox(height: 20),
 Container(
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: VSPColors.accent.withValues(alpha: 0.1),
 shape: BoxShape.circle,
 ),
 child: const Icon(Iconsax.ticket_star_copy, color: VSPColors.accent, size: 32),
 ),
 const SizedBox(height: 14),
 Text(
 isArabic ? 'كود التحدي الخاص بفريقك' : 'Your Team Challenge Code',
 style: Theme.of(ctx).textTheme.displaySmall?.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
 ),
 const SizedBox(height: 6),
 Text(
 isArabic
 ? 'شارك هذا الكود مع كابتن الفريق المنافس ليدخل به ويحجز ضدكم فوراً.'
 : 'Share this code with the opposing captain to challenge your team.',
 textAlign: TextAlign.center,
 style: TextStyle(color: VSPColors.textSecondary.withValues(alpha: 0.8), fontSize: 13),
 ),
 const SizedBox(height: 20),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
 decoration: BoxDecoration(
 color: VSPColors.background,
 borderRadius: BorderRadius.circular(VSPRadius.lg),
 border: Border.all(color: VSPColors.accent.withValues(alpha: 0.5), width: 1.5),
 ),
 child: SelectableText(
 code,
 style: const TextStyle(
 fontSize: 28,
 fontWeight: FontWeight.w900,
 letterSpacing: 4,
 color: VSPColors.accent,
 ),
 ),
 ),
 const SizedBox(height: 24),
 Row(
 children: [
 Expanded(
 child: OutlinedButton.icon(
 style: OutlinedButton.styleFrom(
 padding: const EdgeInsets.symmetric(vertical: 14),
 side: const BorderSide(color: VSPColors.divider),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
 ),
 icon: const Icon(Iconsax.copy_copy, size: 18, color: Colors.white),
 label: Text(isArabic ? 'نسخ الكود' : 'Copy', style: const TextStyle(color: Colors.white)),
 onPressed: () {
 Clipboard.setData(ClipboardData(text: code));
 Navigator.pop(ctx);
 VSPFeedback.showSuccess(context, isArabic ? 'تم نسخ كود التحدي' : 'Code copied');
 },
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: ElevatedButton.icon(
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFF25D366),
 foregroundColor: Colors.white,
 padding: const EdgeInsets.symmetric(vertical: 14),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
 ),
 icon: const Icon(Icons.chat_bubble_outline, size: 18),
 label: Text(isArabic ? 'مشاركة واتساب' : 'WhatsApp', style: const TextStyle(fontWeight: FontWeight.bold)),
 onPressed: () {
 Navigator.pop(ctx);
 final msg = isArabic
 ? 'كابتن! يلا نلعب ماتش تحدي على تطبيق VSP.\nكود التحدي لفريقنا ($teamName) هو:\n$code\nادخل الكود في التطبيق واحجز الماتش ضدنا!'
 : 'Captain! Let us play a challenge match on VSP.\nOur team code ($teamName) is:\n$code\nEnter this code in VSP app to challenge us!';
 VSPLauncherUtils.openWhatsApp(context, phone: '', message: msg);
 },
 ),
 ),
 ],
 ),
 ],
 ),
 ),
 );
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
 const SizedBox(height: 20),

 if (_userTeam != null) ...[
 Container(
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: VSPColors.accent.withValues(alpha: 0.08),
 borderRadius: BorderRadius.circular(VSPRadius.lg),
 border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
 ),
 child: Row(
 children: [
 Container(
 padding: const EdgeInsets.all(10),
 decoration: BoxDecoration(
 color: VSPColors.accent.withValues(alpha: 0.15),
 borderRadius: BorderRadius.circular(VSPRadius.md),
 ),
 child: const Icon(Iconsax.ticket_star_copy, color: VSPColors.accent, size: 22),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 Localizations.localeOf(context).languageCode == 'ar'
 ? 'كود التحدي لفريقك'
 : 'Your Team Challenge Code',
 style: const TextStyle(
 color: Colors.white,
 fontWeight: FontWeight.bold,
 fontSize: 14,
 ),
 ),
 const SizedBox(height: 2),
 Text(
 Localizations.localeOf(context).languageCode == 'ar'
 ? 'شارك الكود مع الخصم ليحجز ضدكم فوراً'
 : 'Share with opponent to book directly',
 style: TextStyle(
 color: VSPColors.textSecondary.withValues(alpha: 0.8),
 fontSize: 12,
 ),
 ),
 ],
 ),
 ),
 TextButton(
 onPressed: _isGeneratingCode ? null : _showMyChallengeCodeModal,
 style: TextButton.styleFrom(
 backgroundColor: VSPColors.accent,
 foregroundColor: Colors.black,
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.sm)),
 ),
 child: _isGeneratingCode
 ? const SizedBox(
 width: 14,
 height: 14,
 child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
 )
 : Text(
 Localizations.localeOf(context).languageCode == 'ar' ? 'مشاركة' : 'Share',
 style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 16),
 ],

 Container(
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: VSPColors.surface,
 borderRadius: BorderRadius.circular(VSPRadius.lg),
 border: Border.all(
 color: _appliedChallengeCode != null
 ? VSPColors.accent
 : VSPColors.divider,
 ),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Icon(Iconsax.key_copy, color: VSPColors.accent, size: 18),
 const SizedBox(width: 8),
 Text(
 Localizations.localeOf(context).languageCode == 'ar'
 ? 'معاك كود تحدي من الخصم؟'
 : 'Have a challenge code?',
 style: const TextStyle(
 color: Colors.white,
 fontWeight: FontWeight.w600,
 fontSize: 13,
 ),
 ),
 if (_appliedChallengeCode != null) ...[
 const Spacer(),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
 decoration: BoxDecoration(
 color: VSPColors.accent.withValues(alpha: 0.15),
 borderRadius: BorderRadius.circular(VSPRadius.full),
 ),
 child: Text(
 _appliedChallengeCode!,
 style: const TextStyle(
 color: VSPColors.accent,
 fontSize: 11,
 fontWeight: FontWeight.bold,
 ),
 ),
 ),
 ],
 ],
 ),
 const SizedBox(height: 10),
 Row(
 children: [
 Expanded(
 child: Container(
 height: 42,
 padding: const EdgeInsets.symmetric(horizontal: 12),
 decoration: BoxDecoration(
 color: VSPColors.background,
 borderRadius: BorderRadius.circular(VSPRadius.md),
 border: Border.all(color: VSPColors.divider),
 ),
 child: TextField(
 controller: _challengeCodeController,
 textCapitalization: TextCapitalization.characters,
 style: const TextStyle(
 color: Colors.white,
 fontSize: 14,
 fontWeight: FontWeight.bold,
 letterSpacing: 1.5,
 ),
 decoration: InputDecoration(
 hintText: Localizations.localeOf(context).languageCode == 'ar'
 ? 'أدخل الكود (مثال: VSP-7K9A2)'
 : 'Enter code (e.g. VSP-7K9A2)',
 hintStyle: TextStyle(
 color: VSPColors.textSecondary.withValues(alpha: 0.5),
 fontSize: 12,
 letterSpacing: 0,
 ),
 border: InputBorder.none,
 contentPadding: const EdgeInsets.symmetric(vertical: 10),
 ),
 ),
 ),
 ),
 const SizedBox(width: 8),
 SizedBox(
 height: 42,
 child: ElevatedButton(
 onPressed: _isLookingUpCode ? null : _handleLookupCode,
 style: ElevatedButton.styleFrom(
 backgroundColor: VSPColors.surfaceLight,
 foregroundColor: Colors.white,
 padding: const EdgeInsets.symmetric(horizontal: 16),
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(VSPRadius.md),
 side: const BorderSide(color: VSPColors.divider),
 ),
 ),
 child: _isLookingUpCode
 ? const SizedBox(
 width: 16,
 height: 16,
 child: CircularProgressIndicator(
 strokeWidth: 2,
 color: VSPColors.accent,
 ),
 )
 : Text(
 Localizations.localeOf(context).languageCode == 'ar' ? 'تحقق' : 'Verify',
 style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
 ),
 ),
 ),
 ],
 ),
 ],
 ),
 ),
 const SizedBox(height: 20),
 Row(
 children: [
 const Expanded(child: Divider(color: VSPColors.divider)),
 Padding(
 padding: const EdgeInsets.symmetric(horizontal: 12),
 child: Text(
 Localizations.localeOf(context).languageCode == 'ar'
 ? 'أو ابحث عن فريق منافس'
 : 'Or search for an opponent team',
 style: TextStyle(
 color: VSPColors.textSecondary.withValues(alpha: 0.6),
 fontSize: 12,
 ),
 ),
 ),
 const Expanded(child: Divider(color: VSPColors.divider)),
 ],
 ),
 const SizedBox(height: 16),

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

 if (_appliedChallengeCode == null || _appliedChallengeCode!.isEmpty) {
   if (_challengeCodeController.text.trim().isNotEmpty) {
     await _handleLookupCode();
   }
   if (_appliedChallengeCode == null || _appliedChallengeCode!.isEmpty) {
     if (context.mounted) {
       final isArabic = Localizations.localeOf(context).languageCode == 'ar';
       VSPFeedback.showInfo(
         context,
         isArabic
              ? 'يرجى إدخال والتحقق من كود التحدي الخاص بفريق ${_selectedTeam!.name} للمتابعة يا كابتن.'
              : 'Please enter and verify the challenge code for ${_selectedTeam!.name} to continue.',
       );
     }
     return;
   }
 }

 if (!context.mounted) return;

 final auth = Provider.of<app_auth.AuthProvider>(context, listen: false);
 final uid = auth.currentUser?.uid;
 if (uid != null) {
 final team = await TeamRepository().getUserTeam(uid);
 if (team != null) {
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
 challengeCode: _appliedChallengeCode,
 );
 }
 }
 } else if (context.mounted) {
 context.read<BookingProvider>().updateDraft(
 opponentTeamId: _selectedTeam!.id,
 opponentTeamName: _selectedTeam!.name,
 challengeCode: _appliedChallengeCode,
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
