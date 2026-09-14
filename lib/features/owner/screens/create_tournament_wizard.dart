import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/stadium_repository.dart';
import '../../../core/repositories/tournament_repository.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../data/models.dart';
import '../../../shared/widgets/vsp_back_button.dart';
import '../widgets/tournament/wizard/tournament_basics_step.dart';
import '../widgets/tournament/wizard/tournament_scheduling_step.dart';
import '../widgets/tournament/wizard/tournament_step_indicator.dart';
import '../widgets/tournament/wizard/tournament_system_step.dart';
import '../widgets/tournament/wizard/tournament_wizard_bottom_bar.dart';
import '../widgets/tournament/wizard/tournament_wizard_coordinator.dart';
import '../widgets/tournament/wizard/tournament_wizard_draft_service.dart';
import 'owner_tournament_dashboard_screen.dart';

class CreateTournamentWizard extends StatefulWidget {
  final Championship? tournament;
  final String? preselectedType;
  const CreateTournamentWizard({super.key, this.tournament, this.preselectedType});

  /// إتاحة إنشاء البطولة لجميع الملاك بدون استثناء
  static void open(BuildContext context, {Championship? tournament, String? preselectedType}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateTournamentWizard(
          tournament: tournament,
          preselectedType: preselectedType,
        ),
      ),
    );
  }

  @override
  State<CreateTournamentWizard> createState() => _CreateTournamentWizardState();
}

class _CreateTournamentWizardState extends State<CreateTournamentWizard> {
  int _currentStep = 0;
  bool _isLoading = false;

  // Step 1: Basics
  final _nameController = TextEditingController();
  String _selectedSport = 'Football';
  final _feeController = TextEditingController();

  // Step 2: System
  String _selectedType = 'Cup'; // Cup, League, GroupsAndKnockout
  String _selectedTeams = '8';
  int _numberOfGroups = 2;
  int _qualifyingPerGroup = 2;
  bool _isTwoLegs = false;

  // Step 3: Scheduling
  DateTime _startDate = DateTime.now().add(const Duration(days: 7));
  DateTime _endDate = DateTime.now().add(const Duration(days: 37));
  final _durationController = TextEditingController(text: '30');
  final _prizeController = TextEditingController(text: '5000');

  List<String> _availableSports = ['Football'];
  StreamSubscription? _stadiumSubscription;

  String _getDraftPrefix() {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final uid = auth.userModel?.uid ?? auth.currentUser?.id ?? '';
      return TournamentWizardDraftService.getDraftPrefix(uid);
    } catch (_) {
      return 'temp_tournament_';
    }
  }

  Future<void> _saveTournamentDraft() async {
    if (widget.tournament != null) return;
    await TournamentWizardDraftService.saveDraft(
      prefix: _getDraftPrefix(),
      name: _nameController.text,
      sport: _selectedSport,
      fee: _feeController.text,
      prize: _prizeController.text,
      type: _selectedType,
      teams: _selectedTeams,
      groups: _numberOfGroups,
      qualifying: _qualifyingPerGroup,
      twoLegs: _isTwoLegs,
      startDate: _startDate,
      endDate: _endDate,
      duration: _durationController.text,
      currentStep: _currentStep,
    );
  }

  Future<void> _loadTournamentDraft() async {
    if (widget.tournament != null) return;
    final draft = await TournamentWizardDraftService.loadDraft(_getDraftPrefix());

    final savedName = draft['name'] as String?;
    if (savedName != null && savedName.isNotEmpty) {
      _nameController.text = savedName;
    }
    final savedSport = draft['sport'] as String?;
    if (savedSport != null && savedSport.isNotEmpty) {
      _selectedSport = savedSport;
    }
    final savedFee = draft['fee'] as String?;
    if (savedFee != null && savedFee.isNotEmpty) {
      _feeController.text = savedFee;
    }
    final savedPrize = draft['prize'] as String?;
    if (savedPrize != null && savedPrize.isNotEmpty) {
      _prizeController.text = savedPrize;
    }
    final savedType = draft['type'] as String?;
    if (savedType != null && savedType.isNotEmpty) {
      _selectedType = savedType;
    }
    final savedTeams = draft['teams'] as String?;
    if (savedTeams != null && savedTeams.isNotEmpty) {
      _selectedTeams = savedTeams;
    }
    _numberOfGroups = (draft['groups'] as int?) ?? _numberOfGroups;
    _qualifyingPerGroup = (draft['qualifying'] as int?) ?? _qualifyingPerGroup;
    _isTwoLegs = (draft['two_legs'] as bool?) ?? _isTwoLegs;

    final savedStart = draft['start_date'] as String?;
    if (savedStart != null) {
      final parsed = DateTime.tryParse(savedStart);
      if (parsed != null && parsed.isAfter(DateTime.now().subtract(const Duration(days: 1)))) {
        _startDate = parsed;
      }
    }
    final savedEnd = draft['end_date'] as String?;
    if (savedEnd != null) {
      final parsed = DateTime.tryParse(savedEnd);
      if (parsed != null && parsed.isAfter(_startDate)) {
        _endDate = parsed;
      }
    }

    final savedDuration = draft['duration'] as String?;
    if (savedDuration != null && savedDuration.isNotEmpty) {
      _durationController.text = savedDuration;
    }

    final savedStep = (draft['current_step'] as int?) ?? 0;
    if (savedStep > 0 && savedStep <= 2) {
      _currentStep = savedStep;
    }
    if (mounted) setState(() {});
  }

  void _setupAutoSaveListeners() {
    _nameController.addListener(_saveTournamentDraft);
    _feeController.addListener(_saveTournamentDraft);
    _durationController.addListener(_saveTournamentDraft);
    _prizeController.addListener(_saveTournamentDraft);
  }

  Future<void> _clearTournamentDraft() async {
    await TournamentWizardDraftService.clearDraft(_getDraftPrefix());
  }

  @override
  void initState() {
    super.initState();
    _loadOwnerSports();
    if (widget.tournament != null) {
      final t = widget.tournament!;
      _nameController.text = t.name;
      _selectedSport = t.sportType;
      _feeController.text = t.entryFee.toInt().toString();
      _selectedType = t.type;
      _selectedTeams = t.maxTeams.toString();
      _numberOfGroups = t.numberOfGroups;
      _qualifyingPerGroup = t.qualifyingPerGroup;
      _isTwoLegs = t.isTwoLegs;
      _startDate = t.startDate;
      _endDate = t.endDate;
      _durationController.text = t.matchDuration.toString();
      _prizeController.text = t.grandPrize.toInt().toString();
    } else {
      if (widget.preselectedType != null) {
        _selectedType = widget.preselectedType!;
      }
      _loadTournamentDraft().then((_) {
        _setupAutoSaveListeners();
      });
    }
  }

  void _loadOwnerSports() {
    final uid = Provider.of<AuthProvider>(context, listen: false).currentUser?.uid;
    if (uid != null) {
      _stadiumSubscription?.cancel();
      _stadiumSubscription = StadiumRepository().getOwnerStadiums(uid).listen((stadiums) {
        if (stadiums.isNotEmpty && mounted) {
          final sports = stadiums
              .map((s) => s.sportType)
              .where((s) => s.isNotEmpty)
              .toSet()
              .toList();
          if (sports.isNotEmpty) {
            setState(() {
              _availableSports = sports;
              if (!_availableSports.contains(_selectedSport)) {
                _selectedSport = _availableSports.first;
              }
            });
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _stadiumSubscription?.cancel();
    _nameController.dispose();
    _feeController.dispose();
    _durationController.dispose();
    _prizeController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (pickerCtx, child) => Theme(
        data: Theme.of(pickerCtx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: VSPColors.accent,
            onPrimary: Colors.black,
            surface: VSPColors.surface,
            onSurface: VSPColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate.add(const Duration(days: 14));
          }
        } else {
          _endDate = picked;
        }
      });
      _saveTournamentDraft();
    }
  }

  void _nextStep() {
    if (_currentStep == 0 && _nameController.text.trim().isEmpty) {
      VSPFeedback.showError(context, 'Please enter tournament name');
      return;
    }
    if (_currentStep < 2) {
      setState(() => _currentStep++);
      _saveTournamentDraft();
    } else {
      _handleSave();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _saveTournamentDraft();
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _handleSave() async {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final error = TournamentWizardCoordinator.validateSubmission(
      name: _nameController.text,
      fee: _feeController.text,
      prize: _prizeController.text,
      startDate: _startDate,
      endDate: _endDate,
      selectedTeams: _selectedTeams,
      isAr: isAr,
    );
    if (error != null) {
      VSPFeedback.showError(context, error);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final currentUid = auth.currentUser?.id ??
          auth.userModel?.uid ??
          '';
      final currentGov = auth.governorate.trim().isNotEmpty
          ? auth.governorate
          : (auth.userModel?.governorate ?? 'القاهرة');

      final champData = TournamentWizardCoordinator.buildTournamentPayload(
        name: _nameController.text,
        type: _selectedType,
        sportType: _selectedSport,
        startDate: _startDate,
        endDate: _endDate,
        governorate: currentGov,
        ownerId: currentUid,
        selectedTeams: _selectedTeams,
        prize: _prizeController.text,
        fee: _feeController.text,
        numberOfGroups: _numberOfGroups,
        qualifyingPerGroup: _qualifyingPerGroup,
        isTwoLegs: _isTwoLegs,
        duration: _durationController.text,
        existingTournament: widget.tournament,
      );

      final isEditing = widget.tournament != null;
      final result = await TournamentWizardCoordinator.submitTournament(
        payload: champData,
        isEditing: isEditing,
        tournamentId: widget.tournament?.id,
      );

      if (result.success && mounted) {
        if (isEditing) {
          VSPFeedback.showSuccess(context, 'Tournament updated successfully.');
          Navigator.pop(context);
        } else {
          await _clearTournamentDraft();
          if (!mounted) return;
          VSPFeedback.showSuccess(context, 'Tournament created successfully.');
          Navigator.pop(context);

          try {
            final newChampList = await TournamentRepository()
                .getChampionshipsStream(sportType: _selectedSport)
                .first;
            final newChamp =
                newChampList.firstWhere((c) => c.id == result.createdId);
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OwnerTournamentDashboardScreen(
                    championship: newChamp,
                  ),
                ),
              );
            }
          } catch (_) {}
        }
      } else if (mounted && result.errorMessage != null) {
        VSPFeedback.showError(context, result.errorMessage!);
      }
    } catch (e) {
      if (mounted) VSPFeedback.showError(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.tournament != null;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        leading: VSPBackButton(onTap: _prevStep),
        centerTitle: true,
        title: Text(
          isEditing ? l10n.editTournamentTitle : l10n.createTournamentTitle,
          style: Theme.of(context).textTheme.displaySmall,
        ),
      ),
      body: Column(
        children: [
          // Step Indicator
          TournamentStepIndicator(currentStep: _currentStep),
          const SizedBox(height: VSPSpacing.md),

          // Step Content
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md),
              physics: const BouncingScrollPhysics(),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _currentStep == 0
                    ? TournamentBasicsStep(
                        nameController: _nameController,
                        selectedSport: _selectedSport,
                        availableSports: _availableSports,
                        onSportChanged: (sport) =>
                            setState(() => _selectedSport = sport),
                        feeController: _feeController,
                        selectedType: _selectedType,
                        onTypeChanged: (type) =>
                            setState(() => _selectedType = type),
                        isEditing: isEditing,
                      )
                    : _currentStep == 1
                        ? TournamentSystemStep(
                            selectedType: _selectedType,
                            selectedTeams: _selectedTeams,
                            onTeamsChanged: (teams) =>
                                setState(() => _selectedTeams = teams),
                            numberOfGroups: _numberOfGroups,
                            onGroupsChanged: (g) =>
                                setState(() => _numberOfGroups = g),
                            qualifyingPerGroup: _qualifyingPerGroup,
                            onQualifyingChanged: (q) =>
                                setState(() => _qualifyingPerGroup = q),
                            isTwoLegs: _isTwoLegs,
                            onTwoLegsChanged: (v) =>
                                setState(() => _isTwoLegs = v),
                          )
                        : TournamentSchedulingStep(
                            startDate: _startDate,
                            endDate: _endDate,
                            onSelectStartDate: () => _selectDate(true),
                            onSelectEndDate: () => _selectDate(false),
                            durationController: _durationController,
                            prizeController: _prizeController,
                          ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: TournamentWizardBottomBar(
        currentStep: _currentStep,
        isLoading: _isLoading,
        isEditing: isEditing,
        onPrev: _prevStep,
        onNext: _nextStep,
      ),
    );
  }
}
