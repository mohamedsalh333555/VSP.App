import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../core/repositories/team_repository.dart';
import '../../../core/repositories/tournament_repository.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/roster_parser_utils.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../data/models.dart';
import '../../../shared/widgets/primary_button.dart';
import '../widgets/roster/roster_capacity_card.dart';
import '../widgets/roster/roster_guest_players_section.dart';
import '../widgets/roster/roster_team_members_section.dart';
import '../widgets/roster/roster_tournament_header.dart';

/// Screen allowing captains to manage their tournament squad/roster,
/// toggling registered team players and adding guest participants.
class ManageTournamentRosterScreen extends StatefulWidget {
  final Championship championship;
  final Team team;

  const ManageTournamentRosterScreen({
    super.key,
    required this.championship,
    required this.team,
  });

  @override
  State<ManageTournamentRosterScreen> createState() => _ManageTournamentRosterScreenState();
}

class _ManageTournamentRosterScreenState extends State<ManageTournamentRosterScreen> {
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
      widget.championship.status == 'open' && DateTime.now().isBefore(widget.championship.startDate);

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
      final roster = await TournamentRepository().getSingleTeamRoster(
        widget.championship.id,
        widget.team.id,
      );

      final loadedPlayerIds = List<String>.from(roster['player_ids'] ?? []);
      final loadedGuests = List<String>.from(roster['guest_names'] ?? []);

      final members = await TeamRepository().getTeamMemberProfiles(widget.team.id);

      if (mounted) {
        setState(() {
          _teamMembers = members;
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

  Future<void> _pasteFromWhatsApp(bool isAr) async {
    if (!_canEdit) {
      _showLockedWarning(isAr);
      return;
    }

    final parsedNames = await RosterParserUtils.showImportSquadDialog(context);
    if (parsedNames.isEmpty) {
      if (mounted) {
        VSPFeedback.showError(
          context,
          isAr ? 'لم يتم العثور على أسماء واضحة في النص الملصوق.' : 'No clear names found in pasted text.',
        );
      }
      return;
    }

    int addedCount = 0;
    setState(() {
      for (final name in parsedNames) {
        if (_currentTotal >= _maxPlayers) break;
        if (!_guestNames.contains(name)) {
          _guestNames.add(name);
          addedCount++;
        }
      }
    });

    if (addedCount > 0 && mounted) {
      HapticFeedback.mediumImpact();
      VSPFeedback.showSuccess(
        context,
        isAr
            ? 'تمت إضافة $addedCount لاعبين من نص التشكيلة بنجاح! '
            : 'Successfully added $addedCount players from WhatsApp text! ',
      );
    }
  }

  void _showLockedWarning(bool isAr) {
    VSPFeedback.showError(
      context,
      isAr
          ? 'تم إغلاق باب تعديل التشكيلة لبدء فعاليات البطولة '
          : 'Roster editing is locked as the tournament has started ',
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
          isAr ? 'تم تحديث تشكيلة الفريق بالبطولة بنجاح! ' : 'Tournament roster updated successfully! ',
        );
        Navigator.pop(context, true);
      } else if (mounted) {
        VSPFeedback.showError(
          context,
          isAr ? 'حدث خطأ أثناء حفظ التشكيلة، حاول مجدداً' : 'Failed to save roster, please try again.',
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

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.surface,
        elevation: 0,
        centerTitle: true,
        title: Text(
          isAr ? 'إدارة تشكيلة الفريق بالبطولة' : 'Manage Tournament Roster',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(
            isAr ? Iconsax.arrow_right_1_copy : Iconsax.arrow_left_2_copy,
            color: VSPColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: VSPColors.accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(VSPSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Tournament Deadline & Status Header
                  RosterTournamentHeader(
                    teamName: widget.team.name,
                    championshipName: widget.championship.name,
                    startDate: widget.championship.startDate,
                    canEdit: _canEdit,
                    isArabic: isAr,
                  ),

                  const SizedBox(height: VSPSpacing.lg),

                  // 2. Capacity Progress Counter Card
                  RosterCapacityCard(
                    currentTotal: _currentTotal,
                    minPlayers: _minPlayers,
                    maxPlayers: _maxPlayers,
                    isArabic: isAr,
                  ),

                  const SizedBox(height: VSPSpacing.xl),

                  // 3. Registered Team Members Section
                  RosterTeamMembersSection(
                    teamMembers: _teamMembers,
                    selectedPlayerIds: _selectedPlayerIds,
                    captainPhone: widget.team.captainPhone ?? '',
                    canEdit: _canEdit,
                    isArabic: isAr,
                    onTogglePlayer: (uid) => _togglePlayerSelection(uid, isAr),
                  ),

                  const SizedBox(height: VSPSpacing.xl),

                  // 4. Offline Guests Section (with WhatsApp import)
                  RosterGuestPlayersSection(
                    guestNames: _guestNames,
                    guestController: _guestController,
                    canEdit: _canEdit,
                    isArabic: isAr,
                    onAddGuest: () => _addGuestName(isAr),
                    onRemoveGuest: (index) => _removeGuestName(index, isAr),
                    onPasteFromWhatsApp: () => _pasteFromWhatsApp(isAr),
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
            text: isAr ? 'حفظ وتأكيد تشكيلة البطولة ' : 'Save & Confirm Roster ',
            isLoading: _isSaving,
            onPressed: (_isSaving || !_canEdit || _isLoading) ? () {} : () => _handleSaveRoster(isAr),
          ),
        ),
      ),
    );
  }
}
