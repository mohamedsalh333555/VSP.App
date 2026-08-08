import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/team_repository.dart';
import '../../../core/repositories/tournament_repository.dart';
import '../../../core/services/sharing_service.dart';
import '../../../core/utils/app_date_formatter.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../shared/widgets/vsp_countdown_timer.dart';
import '../../../data/models.dart';
import '../../owner/screens/tournament_brackets_screen.dart';

class ChampionshipDetailsScreen extends StatefulWidget {
  final Championship championship;

  const ChampionshipDetailsScreen({super.key, required this.championship});

  @override
  State<ChampionshipDetailsScreen> createState() => _ChampionshipDetailsScreenState();
}

class _ChampionshipDetailsScreenState extends State<ChampionshipDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _showRosterSelectionSheet(Team team) async {
    final maxPlayers = widget.championship.maxPlayersPerTeam;
    final minPlayers = widget.championship.minPlayersPerTeam;

    List<Map<String, dynamic>> members = [];
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('id, name, profile_image_url')
          .inFilter('id', team.memberUids);
      members = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching team members details: $e');
    }

    for (final uid in team.memberUids) {
      if (!members.any((m) => m['id'] == uid)) {
        members.add({
          'id': uid,
          'name': uid == team.captainName ? team.captainName : 'لاعب ${members.length + 1}',
          'profile_image_url': '',
        });
      }
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.currentUser?.uid;

    List<String> selectedPlayerIds = [];
    if (team.memberUids.contains(currentUserId)) {
      selectedPlayerIds.add(currentUserId!);
    } else if (team.memberUids.isNotEmpty) {
      selectedPlayerIds.add(team.memberUids.first);
    }

    List<String> offlineGuestNames = [];
    final guestController = TextEditingController();

    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            final totalCount = selectedPlayerIds.length + offlineGuestNames.length;
            final isSelectionValid = totalCount >= minPlayers && totalCount <= maxPlayers;

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: VSPColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(VSPSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    const SizedBox(height: 16),
                    Text(
                      'تشكيلة الفريق للبطولة',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'الحد الأدنى: $minPlayers لاعبين | الحد الأقصى: $maxPlayers لاعبين',
                      style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelectionValid ? VSPColors.accent.withValues(alpha: 0.1) : VSPColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelectionValid ? VSPColors.accent.withValues(alpha: 0.3) : VSPColors.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'تم اختيار: $totalCount لاعبين',
                            style: TextStyle(
                              color: isSelectionValid ? VSPColors.accent : VSPColors.error,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          if (totalCount < minPlayers)
                            Text(
                              'متبقي ${minPlayers - totalCount} لاعبين على الأقل',
                              style: const TextStyle(color: VSPColors.error, fontSize: 12),
                            )
                          else if (totalCount > maxPlayers)
                            const Text(
                              'تجاوزت الحد الأقصى!',
                              style: TextStyle(color: VSPColors.error, fontSize: 12),
                            )
                          else
                            const Text(
                              'العدد مكتمل ومناسب للبطولة ✓',
                              style: TextStyle(color: VSPColors.accent, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'لاعبو الفريق:',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: members.length,
                              itemBuilder: (context, index) {
                                final member = members[index];
                                final isSelected = selectedPlayerIds.contains(member['id']);
                                final isCaptain = member['id'] == currentUserId;

                                return CheckboxListTile(
                                  value: isSelected,
                                  activeColor: VSPColors.accent,
                                  title: Text(
                                    member['name'] ?? '',
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                  ),
                                  subtitle: isCaptain
                                    ? const Text('قائد الفريق (إجباري)', style: TextStyle(color: VSPColors.accent, fontSize: 11))
                                    : null,
                                  secondary: CircleAvatar(
                                    radius: 18,
                                    backgroundImage: (member['profile_image_url'] != null && member['profile_image_url'].toString().isNotEmpty)
                                      ? NetworkImage(member['profile_image_url'])
                                      : null,
                                    backgroundColor: VSPColors.surfaceAlt,
                                    child: (member['profile_image_url'] == null || member['profile_image_url'].toString().isEmpty)
                                      ? const Icon(LucideIcons.user, color: VSPColors.textSecondary, size: 18)
                                      : null,
                                  ),
                                  onChanged: isCaptain
                                    ? null
                                    : (val) {
                                        setSheetState(() {
                                          if (val == true) {
                                            selectedPlayerIds.add(member['id']);
                                          } else {
                                            selectedPlayerIds.remove(member['id']);
                                          }
                                        });
                                      },
                                );
                              },
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'إضافة أصدقاء من خارج التطبيق:',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: guestController,
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: 'اسم الصديق (مثال: محمد أحمد)',
                                      hintStyle: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                                      filled: true,
                                      fillColor: VSPColors.surface,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(VSPRadius.md),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () {
                                    final name = guestController.text.trim();
                                    if (name.isEmpty) return;
                                    if (offlineGuestNames.contains(name)) return;
                                    if (selectedPlayerIds.length + offlineGuestNames.length >= maxPlayers) {
                                      final isAr = Localizations.localeOf(context).languageCode == 'ar';
                                      VSPFeedback.showError(
                                        context,
                                        isAr
                                            ? 'تجاوزت الحد الأقصى للاعبين في الفريق ($maxPlayers لاعبين)!'
                                            : 'Maximum limit of $maxPlayers players reached!',
                                      );
                                      return;
                                    }
                                    setSheetState(() {
                                      offlineGuestNames.add(name);
                                      guestController.clear();
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: VSPColors.accent,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(VSPRadius.md),
                                    ),
                                  ),
                                  child: const Text('إضافة', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (offlineGuestNames.isNotEmpty) ...[
                              const Text(
                                'الأصدقاء المضافون:',
                                style: TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: offlineGuestNames.map((name) {
                                  return Chip(
                                    backgroundColor: VSPColors.surface,
                                    label: Text(name, style: const TextStyle(color: Colors.white, fontSize: 12)),
                                    deleteIcon: const Icon(LucideIcons.x, size: 14, color: Colors.red),
                                    onDeleted: () {
                                      setSheetState(() {
                                        offlineGuestNames.remove(name);
                                      });
                                    },
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(VSPRadius.md),
                                      side: const BorderSide(color: VSPColors.divider),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      text: 'تأكيد التشكيلة والانتقال للدفع',
                      onPressed: isSelectionValid
                        ? () {
                            Navigator.pop(sheetContext, {
                              'selectedPlayerIds': selectedPlayerIds,
                              'offlineGuestNames': offlineGuestNames,
                            });
                          }
                        : null,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleJoin() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.loginToJoinError)));
      return;
    }

    setState(() => _isJoining = true);

    try {
      final userPhone = auth.userModel?.phone ?? '';
      final team = await TeamRepository().getTeamByCaptainPhone(userPhone);

      if (team == null) {
        if (mounted) {
          _showErrorDialog(AppLocalizations.of(context)!.captainRequiredError);
        }
        return;
      }

      if (widget.championship.joinedTeams.contains(team.id)) {
        if (mounted) {
           _showErrorDialog(AppLocalizations.of(context)!.alreadyJoinedError);
        }
        return;
      }

      if (!mounted) return;
      final roster = await _showRosterSelectionSheet(team);
      if (roster == null) return;

      final List<String> selectedPlayerIds = roster['selectedPlayerIds'] ?? [];
      final List<String> offlineGuestNames = roster['offlineGuestNames'] ?? [];

      if (mounted) {
        final confirmed = await _showPaymentDialog(team);
        if (confirmed == true) {
          final success = await TournamentRepository().joinChampionship(
            widget.championship.id,
            team.id,
            selectedPlayerIds: selectedPlayerIds,
            offlineGuestNames: offlineGuestNames,
          );
          if (success && mounted) {
            _showSuccessSnackBar(AppLocalizations.of(context)!.tournamentJoinSuccess(team.name));
            Navigator.pop(context);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VSPColors.surface,
        title: Text(AppLocalizations.of(context)!.errorLabel, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: VSPColors.error)),
        content: Text(message, style: Theme.of(context).textTheme.bodyMedium),
        actionsPadding: const EdgeInsets.all(VSPSpacing.md),
        actions: [
          PrimaryButton(
            text: AppLocalizations.of(context)!.ok,
            height: 48,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showPaymentDialog(Team team) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
        title: Column(
          children: [
            const Icon(LucideIcons.creditCard, color: VSPColors.accent, size: 48),
            const SizedBox(height: VSPSpacing.md),
            Text(
              AppLocalizations.of(context)!.joinConfirmation,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             Text(
              AppLocalizations.of(context)!.entryFee(widget.championship.entryFee.toInt(), AppLocalizations.of(context)!.egCurrency),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(color: VSPColors.accent),
            ),
            const SizedBox(height: VSPSpacing.md),
            Text(
              AppLocalizations.of(context)!.tournamentPaymentDesc,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.textSecondary),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.all(VSPSpacing.md),
        actions: [
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  text: AppLocalizations.of(context)!.cancel,
                  height: 48,
                  color: VSPColors.surfaceAlt,
                  textColor: VSPColors.textPrimary,
                  onPressed: () => Navigator.pop(context, false),
                ),
              ),
              const SizedBox(width: VSPSpacing.md),
              Expanded(
                child: PrimaryButton(
                  text: AppLocalizations.of(context)!.confirmAndPay,
                  height: 48,
                  onPressed: () => Navigator.pop(context, true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: VSPColors.background, fontWeight: FontWeight.bold)),
        backgroundColor: VSPColors.accent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final championship = widget.championship;
    final isFull = championship.isFull || championship.joinedTeams.length >= championship.maxTeams;

    final startDateDisplay = AppDateFormatter.formatDayMonth(championship.startDate, isArabic ? 'ar' : 'en');
    final endDateDisplay = AppDateFormatter.formatDayMonth(championship.endDate, isArabic ? 'ar' : 'en');

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.surface,
        elevation: 0,
        centerTitle: true,
        title: Text(
          isArabic ? 'تفاصيل البطولة' : 'Championship Details',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(
            isArabic ? LucideIcons.chevronRight : LucideIcons.chevronLeft,
            color: VSPColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.share2, color: VSPColors.accent, size: 20),
            onPressed: () {
              SharingService.shareChampionshipObject(
                context: context,
                championship: championship,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 🏆 1. Modern Glassmorphic Header Card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(VSPSpacing.md),
            padding: const EdgeInsets.all(VSPSpacing.md),
            decoration: BoxDecoration(
              color: VSPColors.surface,
              borderRadius: BorderRadius.circular(VSPRadius.xl),
              border: Border.all(color: VSPColors.divider, width: 0.5),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: VSPColors.accent, width: 1.5),
                      ),
                      child: ClipOval(
                        child: championship.logoUrl.isNotEmpty
                            ? Image.network(championship.logoUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(LucideIcons.trophy, color: VSPColors.accent))
                            : const Icon(LucideIcons.trophy, color: VSPColors.accent, size: 24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            championship.name,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(LucideIcons.mapPin, color: VSPColors.textSecondary, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                championship.governorate.isNotEmpty ? championship.governorate : (isArabic ? 'مصر' : 'Egypt'),
                                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isFull || championship.status != 'open')
                            ? VSPColors.error.withValues(alpha: 0.15)
                            : VSPColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(VSPRadius.sm),
                      ),
                      child: Text(
                        isFull
                            ? (isArabic ? 'مكتمل العدد' : 'Full')
                            : (championship.status == 'open' ? (isArabic ? 'مفتوح للتسجيل' : 'Open') : championship.status.toUpperCase()),
                        style: TextStyle(
                          color: (isFull || championship.status != 'open') ? VSPColors.error : VSPColors.success,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                if (championship.status == 'open' && !isFull && championship.startDate.isAfter(DateTime.now())) ...[
                  const SizedBox(height: 12),
                  VSPCountdownTimer(targetDate: championship.startDate),
                ],
                const SizedBox(height: 16),
                // 📊 Stats Grid
                Row(
                  children: [
                    _buildStatCard(
                      icon: LucideIcons.trophy,
                      iconColor: VSPColors.accent,
                      label: isArabic ? 'الجائزة الكبرى' : 'Grand Prize',
                      value: '${championship.grandPrize.toInt()} ${isArabic ? "ج.م" : "EGP"}',
                    ),
                    const SizedBox(width: 8),
                    _buildStatCard(
                      icon: LucideIcons.banknote,
                      iconColor: VSPColors.accent,
                      label: isArabic ? 'رسوم الاشتراك' : 'Entry Fee',
                      value: '${championship.entryFee.toInt()} ${isArabic ? "ج.م" : "EGP"}',
                    ),
                    const SizedBox(width: 8),
                    _buildStatCard(
                      icon: LucideIcons.calendar,
                      iconColor: VSPColors.accent,
                      label: isArabic ? 'الموعد' : 'Date',
                      value: startDateDisplay,
                    ),
                    const SizedBox(width: 8),
                    _buildStatCard(
                      icon: LucideIcons.users,
                      iconColor: VSPColors.accent,
                      label: isArabic ? 'الفرق' : 'Teams',
                      value: '${championship.joinedTeams.length}/${championship.maxTeams}',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 📑 2. VSP Design System Pill Segmented Switcher
          Container(
            margin: const EdgeInsets.symmetric(horizontal: VSPSpacing.md),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: VSPColors.surface,
              borderRadius: BorderRadius.circular(VSPRadius.full),
              border: Border.all(color: VSPColors.divider, width: 0.5),
            ),
            child: AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) {
                final currentIndex = _tabController.index;
                return Row(
                  children: [
                    _buildPillTabItem(
                      index: 0,
                      currentIndex: currentIndex,
                      title: isArabic ? 'الجدول والقرعة' : 'Brackets',
                      icon: LucideIcons.calendar,
                    ),
                    _buildPillTabItem(
                      index: 1,
                      currentIndex: currentIndex,
                      title: isArabic ? 'الهدافين' : 'Scorers',
                      icon: LucideIcons.trophy,
                    ),
                    _buildPillTabItem(
                      index: 2,
                      currentIndex: currentIndex,
                      title: isArabic ? 'التفاصيل والقواعد' : 'Rules',
                      icon: LucideIcons.fileText,
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // 📄 3. Tab Body Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 📅 TAB 1: Timeline & Brackets
                _buildTimelineAndBracketsTab(isArabic, startDateDisplay, endDateDisplay),

                // ⚽ TAB 2: Top Scorers Leaderboard
                _buildTopScorersTab(isArabic),

                // 📜 TAB 3: Rules & Details
                _buildRulesAndInfoTab(isArabic),
              ],
            ),
          ),

          // 🔘 4. Floating Action / Bottom Button Area
          Container(
            padding: EdgeInsets.fromLTRB(
              VSPSpacing.md,
              VSPSpacing.sm,
              VSPSpacing.md,
              MediaQuery.of(context).padding.bottom + VSPSpacing.md,
            ),
            decoration: const BoxDecoration(
              color: VSPColors.surface,
              border: Border(top: BorderSide(color: VSPColors.divider, width: 0.5)),
            ),
            child: (isFull || championship.status == 'ongoing' || championship.status == 'completed')
                ? PrimaryButton(
                    text: isFull && championship.status != 'ongoing' && championship.status != 'completed'
                        ? (isArabic ? 'مكتمل العدد (مشاهدة القرعة والجدول)' : 'Fully Booked (View Brackets)')
                        : AppLocalizations.of(context)!.viewBrackets,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TournamentBracketsScreen(
                            championship: championship,
                            isOwner: false,
                          ),
                        ),
                      );
                    },
                  )
                : PrimaryButton(
                    text: isArabic ? 'انضمام للبطولة الآن ⚽' : AppLocalizations.of(context)!.join,
                    isLoading: _isJoining,
                    onPressed: _handleJoin,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillTabItem({
    required int index,
    required int currentIndex,
    required String title,
    required IconData icon,
  }) {
    final isSelected = currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _tabController.animateTo(index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? VSPColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(VSPRadius.full),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.black : VSPColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? Colors.black : VSPColors.textSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: VSPColors.background,
          borderRadius: BorderRadius.circular(VSPRadius.md),
          border: Border.all(color: VSPColors.divider, width: 0.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 16),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 9),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineAndBracketsTab(bool isArabic, String startDateDisplay, String endDateDisplay) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(VSPSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(VSPSpacing.md),
            decoration: BoxDecoration(
              color: VSPColors.surface,
              borderRadius: BorderRadius.circular(VSPRadius.lg),
              border: Border.all(color: VSPColors.divider, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isArabic ? 'الجدول الزمني للبطولة' : 'Tournament Schedule',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TournamentBracketsScreen(
                              championship: widget.championship,
                              isOwner: false,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(LucideIcons.trophy, size: 14, color: VSPColors.accent),
                      label: Text(
                        isArabic ? 'عرض القرعة' : 'View Brackets',
                        style: const TextStyle(color: VSPColors.accent, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTimelineStep(startDateDisplay, isArabic ? 'تاريخ البدء وانطلاق البطولة' : 'Tournament Start Date', true, true),
                _buildTimelineStep(isArabic ? 'اليوم الأول للمباريات' : 'Match Day 1', isArabic ? 'دور المجموعات والتصفيات' : 'Group Stage & Qualifiers', true, true),
                _buildTimelineStep(isArabic ? 'اليوم الثاني للمباريات' : 'Match Day 2', isArabic ? 'ربع النهائي ونصف النهائي' : 'Quarter & Semi Finals', false, true),
                _buildTimelineStep(endDateDisplay, isArabic ? 'المباراة النهائية والتتويج' : 'Final Match & Coronation', false, false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopScorersTab(bool isArabic) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: TournamentRepository().getTopScorersForChampionship(widget.championship.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
        }

        final scorers = snapshot.data ?? [];
        if (scorers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.medal, color: VSPColors.textSecondary, size: 40),
                const SizedBox(height: 12),
                Text(
                  isArabic ? 'لم يتم تسجيل أهداف بعد في هذه البطولة' : 'No goals recorded yet in this tournament',
                  style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(VSPSpacing.md),
          itemCount: scorers.length,
          itemBuilder: (context, index) {
            final item = scorers[index];
            final bool isOwnGoalCategory = item['isOwnGoalCategory'] == true || item['name'] == 'أهداف عكسية';
            final rank = index + 1;
            final String name = item['name'] ?? '';
            final String team = item['team'] ?? '';
            final int goals = item['goals'] as int? ?? 0;

            Color rankColor = VSPColors.surfaceAlt;
            String rankEmoji = '#$rank';
            if (!isOwnGoalCategory) {
              if (rank == 1) {
                rankColor = VSPColors.accent;
                rankEmoji = '🥇';
              } else if (rank == 2) {
                rankColor = VSPColors.accent.withValues(alpha: 0.7);
                rankEmoji = '🥈';
              } else if (rank == 3) {
                rankColor = VSPColors.accent.withValues(alpha: 0.5);
                rankEmoji = '🥉';
              }
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(color: VSPColors.divider, width: 0.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isOwnGoalCategory ? VSPColors.error.withValues(alpha: 0.15) : rankColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: isOwnGoalCategory
                          ? const Icon(LucideIcons.repeat, color: VSPColors.error, size: 18)
                          : Text(
                              rankEmoji,
                              style: TextStyle(
                                color: rank <= 3 ? rankColor : VSPColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: rank <= 3 ? 16 : 12,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isOwnGoalCategory ? (isArabic ? 'أهداف عكسية' : 'Own Goals') : name,
                          style: TextStyle(
                            color: isOwnGoalCategory ? Colors.white70 : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (team.isNotEmpty && team != 'فريق غير محدد') ...[
                          const SizedBox(height: 2),
                          Text(
                            team,
                            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOwnGoalCategory ? VSPColors.error.withValues(alpha: 0.15) : VSPColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(VSPRadius.sm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(isOwnGoalCategory ? LucideIcons.repeat : LucideIcons.trophy, color: isOwnGoalCategory ? VSPColors.error : VSPColors.accent, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          '$goals ${isArabic ? "أهداف" : "goals"}',
                          style: TextStyle(color: isOwnGoalCategory ? VSPColors.error : VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
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

  Widget _buildRulesAndInfoTab(bool isArabic) {
    final championship = widget.championship;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(VSPSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoSection(
            isArabic ? 'وصف عن البطولة' : 'About Tournament',
            championship.rules.isNotEmpty
                ? championship.rules
                : (isArabic ? 'بطولة رسمية تنافسية لفرق كرة القدم بمدينة ${championship.governorate.isNotEmpty ? championship.governorate : "مصر"}.' : 'Official competitive football tournament.'),
          ),
          const SizedBox(height: 16),
          _buildInfoSection(
            isArabic ? 'قوانين المباريات' : 'Match Rules',
            isArabic
                ? '• مدة المباراة: ${championship.matchDuration} دقيقة.\n'
                  '• عدد اللاعبين الأساسيين لكل فريق: ${championship.minPlayersPerTeam} لاعبين.\n'
                  '• الحد الأقصى للاعبين في التشكيلة: ${championship.maxPlayersPerTeam} لاعبين.\n'
                  '• احتساب النقاط: ${championship.winningPoints} نقاط للفوز، ${championship.drawPoints} نقطة للتعادل، ${championship.lossPoints} للهزيمة.'
                : '• Match Duration: ${championship.matchDuration} mins.\n'
                  '• Min Players: ${championship.minPlayersPerTeam}.\n'
                  '• Max Players: ${championship.maxPlayersPerTeam}.\n'
                  '• Points: ${championship.winningPoints} Win / ${championship.drawPoints} Draw / ${championship.lossPoints} Loss.',
          ),
          const SizedBox(height: 16),
          _buildInfoSection(
            isArabic ? 'تعليمات وإرشادات مهمة' : 'Important Instructions',
            isArabic
                ? '• يرجى التواجد بالملعب قبل موعد المباراة بـ 15 دقيقة على الأقل.\n'
                  '• يجب التزام جميع الفرق بالزي الرياضي الموحد.\n'
                  '• أي بطاقة حمراء تؤدي لإيقاف اللاعب المباراة التالية.'
                : '• Please arrive 15 minutes prior to kickoff.\n'
                  '• Unified sports gear is required.\n'
                  '• Red card suspends player for next match.',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(VSPSpacing.md),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep(String date, String title, bool isActive, bool hasNext) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: isActive ? VSPColors.accent : VSPColors.divider.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                ),
                if (hasNext)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: VSPColors.divider.withValues(alpha: 0.2),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date,
                    style: TextStyle(
                      color: isActive ? Colors.white : VSPColors.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
