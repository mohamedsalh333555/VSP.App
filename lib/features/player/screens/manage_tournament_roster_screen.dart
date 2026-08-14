import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/repositories/tournament_repository.dart';
import '../../../core/repositories/team_repository.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/vsp_countdown_timer.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../data/models.dart';

class ManageTournamentRosterScreen extends StatefulWidget {
  final Championship championship;
  final Team team;

  const ManageTournamentRosterScreen({
    super.key,
    required this.championship,
    required this.team,
  });

  @override
  State<ManageTournamentRosterScreen> createState() =>
      _ManageTournamentRosterScreenState();
}

class _ManageTournamentRosterScreenState
    extends State<ManageTournamentRosterScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  List<String> _selectedPlayerIds = [];
  List<String> _guestNames = [];
  List<Map<String, String>> _teamMembers = [];

  final TextEditingController _guestController = TextEditingController();

  int get _minPlayers =>
      widget.championship.minPlayersPerTeam > 0 ? widget.championship.minPlayersPerTeam : 5;

  int get _maxPlayers =>
      widget.championship.maxPlayersPerTeam > 0 ? widget.championship.maxPlayersPerTeam : 11;

  int get _currentTotal => _selectedPlayerIds.length + _guestNames.length;

  bool get _canEdit =>
      widget.championship.status == 'open' &&
      DateTime.now().isBefore(widget.championship.startDate);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _guestController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch current roster from DB
      final roster = await TournamentRepository().getSingleTeamRoster(
        widget.championship.id,
        widget.team.id,
      );

      final loadedPlayerIds = List<String>.from(roster['player_ids'] ?? []);
      final loadedGuests = List<String>.from(roster['guest_names'] ?? []);

      // 2. Load detailed user profiles for team members
      final members = await TeamRepository().getTeamMemberProfiles(widget.team.id);

      if (mounted) {
        setState(() {
          _teamMembers = members;
          // If no roster saved yet, default to team member IDs up to maxPlayers
          if (loadedPlayerIds.isEmpty && loadedGuests.isEmpty) {
            _selectedPlayerIds = members
                .map((m) => m['uid'] ?? '')
                .where((uid) => uid.isNotEmpty)
                .take(_maxPlayers)
                .toList();
            _guestNames = [];
          } else {
            _selectedPlayerIds = loadedPlayerIds;
            _guestNames = loadedGuests;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading tournament roster data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _togglePlayerSelection(String uid, bool isAr) {
    if (!_canEdit) {
      _showLockedWarning(isAr);
      return;
    }

    setState(() {
      if (_selectedPlayerIds.contains(uid)) {
        _selectedPlayerIds.remove(uid);
      } else {
        if (_currentTotal >= _maxPlayers) {
          VSPFeedback.showError(
            context,
            isAr
                ? 'وصلت للحد الأقصى لتشكيلة البطولة ($_maxPlayers لاعبين)!'
                : 'Reached maximum roster limit of $_maxPlayers players!',
          );
          return;
        }
        _selectedPlayerIds.add(uid);
      }
    });
  }

  void _addGuestName(bool isAr) {
    if (!_canEdit) {
      _showLockedWarning(isAr);
      return;
    }

    final name = _guestController.text.trim();
    if (name.isEmpty) {
      VSPFeedback.showError(
        context,
        isAr ? 'يرجى إدخال اسم اللاعب الضيف' : 'Please enter guest player name',
      );
      return;
    }

    if (_currentTotal >= _maxPlayers) {
      VSPFeedback.showError(
        context,
        isAr
            ? 'وصلت للحد الأقصى لتشكيلة البطولة ($_maxPlayers لاعبين)!'
            : 'Reached maximum roster limit of $_maxPlayers players!',
      );
      return;
    }

    setState(() {
      _guestNames.add(name);
      _guestController.clear();
    });
  }

  void _removeGuestName(int index, bool isAr) {
    if (!_canEdit) {
      _showLockedWarning(isAr);
      return;
    }

    setState(() {
      _guestNames.removeAt(index);
    });
  }

  void _showLockedWarning(bool isAr) {
    VSPFeedback.showError(
      context,
      isAr
          ? 'تم إغلاق باب تعديل التشكيلة لبدء فعاليات البطولة 🔒'
          : 'Roster editing is locked as the tournament has started 🔒',
    );
  }

  Future<void> _handleSaveRoster(bool isAr) async {
    if (!_canEdit) {
      _showLockedWarning(isAr);
      return;
    }

    if (_currentTotal < _minPlayers) {
      VSPFeedback.showError(
        context,
        isAr
            ? 'يجب أن تضم التشكيلة $_minPlayers لاعبين على الأقل للمشاركة!'
            : 'Roster must contain at least $_minPlayers players!',
      );
      return;
    }

    if (_currentTotal > _maxPlayers) {
      VSPFeedback.showError(
        context,
        isAr
            ? 'تجاوزت الحد الأقصى المسموح به ($_maxPlayers لاعبين)!'
            : 'Roster exceeds maximum allowed of $_maxPlayers players!',
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final success = await TournamentRepository().updateSingleTeamRoster(
        championshipId: widget.championship.id,
        teamId: widget.team.id,
        playerIds: _selectedPlayerIds,
        guestNames: _guestNames,
      );

      if (success && mounted) {
        HapticFeedback.heavyImpact();
        VSPFeedback.showSuccess(
          context,
          isAr
              ? 'تم تحديث تشكيلة الفريق بالبطولة بنجاح! ⚽'
              : 'Tournament roster updated successfully! ⚽',
        );
        Navigator.pop(context, true);
      } else if (mounted) {
        VSPFeedback.showError(
          context,
          isAr
              ? 'حدث خطأ أثناء حفظ التشكيلة، حاول مجدداً'
              : 'Failed to save roster, please try again.',
        );
      }
    } catch (e) {
      if (mounted) VSPFeedback.showError(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final progressRatio = (_currentTotal / _maxPlayers).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.surface,
        elevation: 0,
        centerTitle: true,
        title: Text(
          isAr ? 'إدارة تشكيلة الفريق بالبطولة' : 'Manage Tournament Roster',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(
            isAr ? Iconsax.arrow_right_3_copy : Iconsax.arrow_left_2_copy,
            color: VSPColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: VSPColors.accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(VSPSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ⏱️ Header Card: Tournament & Deadline Status
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(VSPSpacing.md),
                    decoration: BoxDecoration(
                      color: VSPColors.surface,
                      borderRadius: BorderRadius.circular(VSPRadius.xl),
                      border: Border.all(
                        color: _canEdit
                            ? VSPColors.accent.withValues(alpha: 0.3)
                            : VSPColors.error.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: VSPColors.accent.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Iconsax.people_copy,
                                color: VSPColors.accent,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.team.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    widget.championship.name,
                                    style: const TextStyle(
                                      color: VSPColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _canEdit
                                    ? VSPColors.success.withValues(alpha: 0.15)
                                    : VSPColors.error.withValues(alpha: 0.15),
                                borderRadius:
                                    BorderRadius.circular(VSPRadius.sm),
                              ),
                              child: Text(
                                _canEdit
                                    ? (isAr ? 'مفتوح للتعديل' : 'Editable')
                                    : (isAr ? 'مغلق رسمياً 🔒' : 'Locked 🔒'),
                                style: TextStyle(
                                  color: _canEdit
                                      ? VSPColors.success
                                      : VSPColors.error,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_canEdit) ...[
                          const SizedBox(height: 12),
                          VSPCountdownTimer(
                              targetDate: widget.championship.startDate),
                        ] else ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: VSPColors.error.withValues(alpha: 0.1),
                              borderRadius:
                                  BorderRadius.circular(VSPRadius.md),
                            ),
                            child: Row(
                              children: [
                                const Icon(Iconsax.info_circle_copy,
                                    color: VSPColors.error, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    isAr
                                        ? 'تم إغلاق تعديل التشكيلة لبدء فعاليات البطولة.'
                                        : 'Roster editing is locked as tournament started.',
                                    style: const TextStyle(
                                      color: VSPColors.error,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: VSPSpacing.lg),

                  // 📊 Progress & Roster Counter Box
                  Container(
                    padding: const EdgeInsets.all(VSPSpacing.md),
                    decoration: BoxDecoration(
                      color: VSPColors.surface,
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                      border: Border.all(color: VSPColors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isAr ? 'إجمالي عدد التشكيلة' : 'Total Roster',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '$_currentTotal / $_maxPlayers',
                              style: TextStyle(
                                color: (_currentTotal >= _minPlayers &&
                                        _currentTotal <= _maxPlayers)
                                    ? VSPColors.accent
                                    : VSPColors.error,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progressRatio,
                            minHeight: 8,
                            backgroundColor: VSPColors.background,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _currentTotal >= _minPlayers
                                  ? VSPColors.accent
                                  : VSPColors.error,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isAr
                                  ? 'الحد الأدنى: $_minPlayers لاعبين'
                                  : 'Min: $_minPlayers players',
                              style: const TextStyle(
                                color: VSPColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              isAr
                                  ? 'الحد الأقصى: $_maxPlayers لاعبين'
                                  : 'Max: $_maxPlayers players',
                              style: const TextStyle(
                                color: VSPColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: VSPSpacing.xl),

                  // 👥 Section 1: Team Members (VSP App Users)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isArabic(context)
                            ? 'لاعبو الفريق (عبر التطبيق)'
                            : 'Team Players (In App)',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: VSPColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_selectedPlayerIds.length} ${isAr ? "محدد" : "selected"}',
                          style: const TextStyle(
                            color: VSPColors.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: VSPSpacing.sm),

                  if (_teamMembers.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(VSPSpacing.md),
                      decoration: BoxDecoration(
                        color: VSPColors.surface,
                        borderRadius: BorderRadius.circular(VSPRadius.md),
                      ),
                      child: Text(
                        isAr
                            ? 'لا يوجد أعضاء آخرين في الفريق، يمكنك إضافة ضيوف بالأسفل.'
                            : 'No other team members found, you can add guest players below.',
                        style: const TextStyle(color: VSPColors.textSecondary),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _teamMembers.length,
                      itemBuilder: (context, index) {
                        final member = _teamMembers[index];
                        final uid = member['uid'] ?? '';
                        final name = member['name'] ?? 'Player';
                        final phone = member['phone'] ?? '';
                        final position = member['position'] ?? '';
                        final isSelected = _selectedPlayerIds.contains(uid);
                        final isCaptain = phone.isNotEmpty && phone == widget.team.captainPhone;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? VSPColors.accent.withValues(alpha: 0.1)
                                : VSPColors.surface,
                            borderRadius:
                                BorderRadius.circular(VSPRadius.md),
                            border: Border.all(
                              color: isSelected
                                  ? VSPColors.accent
                                  : VSPColors.divider,
                              width: isSelected ? 1.5 : 0.5,
                            ),
                          ),
                          child: CheckboxListTile(
                            value: isSelected,
                            activeColor: VSPColors.accent,
                            checkColor: Colors.black,
                            onChanged: _canEdit
                                ? (_) => _togglePlayerSelection(uid, isAr)
                                : null,
                            title: Row(
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : VSPColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                if (isCaptain) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      isAr ? 'كابتن 👑' : 'Captain 👑',
                                      style: const TextStyle(
                                        color: Colors.amber,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(
                              position.isNotEmpty
                                  ? position
                                  : (isAr ? 'لاعب كرة قدم' : 'Footballer'),
                              style: const TextStyle(
                                color: VSPColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                            secondary: CircleAvatar(
                              backgroundColor: VSPColors.surfaceAlt,
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'P',
                                style: const TextStyle(
                                  color: VSPColors.accent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: VSPSpacing.xl),

                  // 👤 Section 2: Offline Guests (مرافقين / بدون تطبيق)
                  Text(
                    isAr
                        ? 'لاعبون ضيوف (بدون حساب على التطبيق)'
                        : 'Guest Players (No App Account)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                  ),
                  const SizedBox(height: VSPSpacing.sm),

                  if (_canEdit) ...[
                    Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            controller: _guestController,
                            hintText: isAr
                                ? 'اسم اللاعب الضيف (مثال: أحمد مصطفى)'
                                : 'Guest player name',
                            maxLength: 30,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _addGuestName(isAr),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: VSPColors.accent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(VSPRadius.input),
                            ),
                          ),
                          child: Text(
                            isAr ? 'إضافة' : 'Add',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (_guestNames.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(VSPSpacing.md),
                      decoration: BoxDecoration(
                        color: VSPColors.surface,
                        borderRadius: BorderRadius.circular(VSPRadius.md),
                      ),
                      child: Text(
                        isAr
                            ? 'لم يتم إضافة لاعبين ضيوف حتى الآن.'
                            : 'No guest players added yet.',
                        style: const TextStyle(color: VSPColors.textSecondary),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _guestNames.length,
                      itemBuilder: (context, index) {
                        final name = _guestNames[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: VSPColors.surface,
                            borderRadius: BorderRadius.circular(VSPRadius.md),
                            border: Border.all(color: VSPColors.divider),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Iconsax.user_copy,
                                      color: VSPColors.accent, size: 18),
                                  const SizedBox(width: 10),
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: VSPColors.surfaceAlt,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isAr ? 'ضيف' : 'Guest',
                                      style: const TextStyle(
                                        color: VSPColors.textSecondary,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_canEdit)
                                IconButton(
                                  icon: const Icon(Iconsax.trash_copy,
                                      color: VSPColors.error, size: 18),
                                  onPressed: () => _removeGuestName(index, isAr),
                                ),
                            ],
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          VSPSpacing.md,
          VSPSpacing.md,
          VSPSpacing.md,
          MediaQuery.of(context).padding.bottom > 0
              ? MediaQuery.of(context).padding.bottom + VSPSpacing.md
              : VSPSpacing.md,
        ),
        color: VSPColors.background,
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: PrimaryButton(
            text: isArabic(context)
                ? 'حفظ وتأكيد تشكيلة البطولة ⚽'
                : 'Save & Confirm Roster ⚽',
            isLoading: _isSaving,
            onPressed: (_isSaving || !_canEdit || _isLoading)
                ? () {}
                : () => _handleSaveRoster(isArabic(context)),
          ),
        ),
      ),
    );
  }

  bool isArabic(BuildContext context) {
    return Localizations.localeOf(context).languageCode == 'ar';
  }
}
