import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/vsp_animated_button.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/database_service.dart';
import '../../../core/repositories/tournament_repository.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../data/models.dart';

/// Quick Template preset data
class _TournamentTemplate {
  final String name;
  final String icon;
  final String type;
  final String sport;
  final int teams;
  final double fee;
  final double prize;
  final int durationMinutes;

  const _TournamentTemplate({
    required this.name,
    required this.icon,
    required this.type,
    required this.sport,
    required this.teams,
    required this.fee,
    required this.prize,
    required this.durationMinutes,
  });
}

const _quickTemplates = [
  _TournamentTemplate(
    name: 'Ramadan Cup',
    icon: '🌙',
    type: 'Cup',
    sport: 'Football',
    teams: 16,
    fee: 500,
    prize: 5000,
    durationMinutes: 25,
  ),
  _TournamentTemplate(
    name: 'Fast 5s Tournament',
    icon: '⚡',
    type: 'Cup',
    sport: 'Football',
    teams: 8,
    fee: 300,
    prize: 3000,
    durationMinutes: 20,
  ),
  _TournamentTemplate(
    name: 'Pro League',
    icon: '🏆',
    type: 'League',
    sport: 'Football',
    teams: 8,
    fee: 1000,
    prize: 10000,
    durationMinutes: 45,
  ),
];

class CreateTournamentWizard extends StatefulWidget {
  final Championship? tournament;
  const CreateTournamentWizard({super.key, this.tournament});

  @override
  State<CreateTournamentWizard> createState() => _CreateTournamentWizardState();
}

class _CreateTournamentWizardState extends State<CreateTournamentWizard> {
  int _currentStep = 0;
  bool _isLoading = false;

  // Step 1: Basics
  final _nameController = TextEditingController();
  String _selectedSport = 'Football';
  final _feeController = TextEditingController(text: '500');
  String? _selectedTemplateName;

  // Step 2: System
  String _selectedType = 'Cup'; // Cup, League
  String _selectedTeams = '8';

  // Step 3: Scheduling
  DateTime _startDate = DateTime.now().add(const Duration(days: 7));
  DateTime _endDate = DateTime.now().add(const Duration(days: 37));
  final _durationController = TextEditingController(text: '30');
  final _prizeController = TextEditingController(text: '5000');

  @override
  void initState() {
    super.initState();
    if (widget.tournament != null) {
      final t = widget.tournament!;
      _nameController.text = t.name;
      _selectedSport = t.sportType;
      _feeController.text = t.entryFee.toInt().toString();
      _selectedType = t.type;
      _selectedTeams = t.maxTeams.toString();
      _startDate = t.startDate;
      _endDate = t.endDate;
      _durationController.text = t.matchDuration.toString();
      _prizeController.text = t.grandPrize.toInt().toString();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _feeController.dispose();
    _durationController.dispose();
    _prizeController.dispose();
    super.dispose();
  }

  void _applyTemplate(_TournamentTemplate t) {
    setState(() {
      _selectedTemplateName = t.name;
      _nameController.text = t.name;
      _selectedSport = t.sport;
      _feeController.text = t.fee.toStringAsFixed(0);
      _selectedType = t.type;
      _selectedTeams = t.teams.toString();
      _durationController.text = t.durationMinutes.toString();
      _prizeController.text = t.prize.toStringAsFixed(0);
    });
    VSPFeedback.showSuccess(context, 'Template applied: ${t.name}');
  }

  Future<void> _selectDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)), // Allow past for editing old ones
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
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
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _nextStep() {
    if (_currentStep == 0 && _nameController.text.trim().isEmpty) {
      VSPFeedback.showError(context, 'Please enter tournament name');
      return;
    }
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      _handleSave();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _handleSave() async {
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);

      final champData = {
        'name': _nameController.text.trim(),
        'type': _selectedType,
        'sportType': _selectedSport,
        'startDate': _startDate.toIso8601String(),
        'endDate': _endDate.toIso8601String(),
        'governorate': auth.governorate,
        'ownerId': auth.currentUser?.uid,
        'image': widget.tournament?.imageUrl ?? '',
        'teamsCount': int.parse(_selectedTeams),
        'maxTeams': int.parse(_selectedTeams),
        'prize': double.tryParse(_prizeController.text) ?? 5000.0,
        'fees': double.tryParse(_feeController.text) ?? 500.0,
        'rules': widget.tournament?.rules ?? '',
        'paymentMethods': widget.tournament?.paymentMethods ?? ['cash'],
        'settings': {
          'maxPlayers': widget.tournament?.maxPlayersPerTeam ?? 11,
          'minPlayers': widget.tournament?.minPlayersPerTeam ?? 5,
          'winningPoints': widget.tournament?.winningPoints ?? 3,
          'drawPoints': widget.tournament?.drawPoints ?? 1,
          'lossPoints': widget.tournament?.lossPoints ?? 0,
          'matchDuration': _durationController.text.trim(),
          'isBackAndForth': widget.tournament?.isBackAndForth ?? false,
          'trophyMedals': widget.tournament?.trophyMedals ?? true,
          'redCardSuspension': widget.tournament?.redCardSuspension ?? true,
          'fairPlayScoring': widget.tournament?.fairPlayScoring ?? false,
        },
      };

      if (widget.tournament != null) {
        // UPDATE
        final success = await TournamentRepository().updateChampionship(widget.tournament!.id, champData);
        if (success && mounted) {
           Navigator.pop(context);
           VSPFeedback.showSuccess(context, 'Tournament updated successfully! 🏆');
        }
      } else {
        // CREATE
        final id = await TournamentRepository().createChampionship(champData);
        if (id != null && mounted) {
          Navigator.pop(context);
          VSPFeedback.showSuccess(context, 'Tournament created successfully! 🏆');
        }
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: VSPColors.textPrimary),
          onPressed: _prevStep,
        ),
        centerTitle: true,
        title: Text(
          isEditing ? l10n.editTournamentTitle : l10n.createTournamentTitle,
          style: Theme.of(context).textTheme.displaySmall,
        ),
      ),
      body: Column(
        children: [
          // Step Indicator
          _buildStepIndicator(),
          const SizedBox(height: VSPSpacing.md),

          // Step Content
          Expanded(
            child: SingleChildScrollView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
              padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md),
              physics: const BouncingScrollPhysics(),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _currentStep == 0
                    ? _buildStep1()
                    : _currentStep == 1
                        ? _buildStep2()
                        : _buildStep3(),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(VSPSpacing.md, VSPSpacing.md, VSPSpacing.md, MediaQuery.of(context).padding.bottom + VSPSpacing.md),
        color: VSPColors.background,
        child: Row(
          children: [
            if (_currentStep > 0) ...[
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: _prevStep,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: VSPColors.textSecondary,
                      side: const BorderSide(color: VSPColors.divider),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                    ),
                    child: Text(l10n.backButton),
                  ),
                ),
              ),
              const SizedBox(width: VSPSpacing.md),
            ],
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 56,
                child: PrimaryButton(
                  text: _currentStep == 2 
                      ? (isEditing ? l10n.updateChanges : l10n.createTournamentTitle) 
                      : l10n.nextButton,
                  isLoading: _isLoading,
                  onPressed: _isLoading ? () {} : _nextStep,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final l10n = AppLocalizations.of(context)!;
    final labels = [
      l10n.basicsStep,
      l10n.systemStep,
      l10n.schedulingStep,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.lg, vertical: VSPSpacing.sm),
      child: Row(
        children: List.generate(3, (i) {
          final isActive = i <= _currentStep;
          final isCurrent = i == _currentStep;
          return Expanded(
            child: Row(
              children: [
                if (i > 0)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isActive ? VSPColors.accent : VSPColors.divider,
                    ),
                  ),
                Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive ? VSPColors.accent : VSPColors.surface,
                        border: Border.all(
                          color: isActive ? VSPColors.accent : VSPColors.divider,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: i < _currentStep
                            ? const Icon(Icons.check, color: Colors.black, size: 16)
                            : Text(
                                '${i + 1}',
                                style: TextStyle(
                                  color: isActive ? Colors.black : VSPColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      labels[i],
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: isCurrent ? VSPColors.accent : VSPColors.textSecondary,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                            fontSize: 9,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── STEP 1: Basics ──────────────────────────────
  Widget _buildStep1() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      key: const ValueKey('step1'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick Templates
        Text(l10n.quickTemplates, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        Text(l10n.choosePresetSubtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.textSecondary)),
        const SizedBox(height: VSPSpacing.md),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _quickTemplates.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final t = _quickTemplates[i];
              final isSelected = _selectedTemplateName == t.name;
              return GestureDetector(
                onTap: () => _applyTemplate(t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 145,
                  padding: const EdgeInsets.all(VSPSpacing.sm),
                  decoration: BoxDecoration(
                    color: isSelected ? VSPColors.accent.withValues(alpha: 0.1) : VSPColors.surface,
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    border: Border.all(
                      color: isSelected ? VSPColors.accent : VSPColors.accent.withValues(alpha: 0.3),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(t.icon, style: const TextStyle(fontSize: 20)),
                      const SizedBox(height: 4),
                      Text(
                        t.name,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? VSPColors.accent : VSPColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${t.teams} ${l10n.teams} • ${t.fee.toStringAsFixed(0)} ${l10n.currency}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isSelected ? VSPColors.accent.withValues(alpha: 0.7) : VSPColors.textSecondary, 
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: VSPSpacing.xl),

        _buildLabel(l10n.tournamentNameLabel),
        _buildTextField(_nameController, hint: 'e.g. Star Cup', autofocus: widget.tournament == null),
        const SizedBox(height: VSPSpacing.md),

        _buildLabel(l10n.sportTypeLabel),
        _buildDropdown(VSPConstants.sports, _selectedSport, (v) => setState(() => _selectedSport = v!)),
        const SizedBox(height: VSPSpacing.md),

        _buildLabel(l10n.entryFeeLabel),
        _buildTextField(_feeController, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
        const SizedBox(height: 80),
      ],
    );
  }

  // ── STEP 2: Tournament System ───────────────────
  Widget _buildStep2() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      key: const ValueKey('step2'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(l10n.tournamentSystemLabel),
        const SizedBox(height: VSPSpacing.sm),
        Row(
          children: [
            _buildSystemOption('Cup', l10n.knockoutType, Icons.emoji_events_outlined),
            const SizedBox(width: VSPSpacing.md),
            _buildSystemOption('League', l10n.leagueType, Icons.leaderboard_outlined),
          ],
        ),
        const SizedBox(height: VSPSpacing.xl),

        _buildLabel(l10n.maxTeamsLabel),
        _buildDropdown(['4', '8', '16', '32'], _selectedTeams, (v) => setState(() => _selectedTeams = v!)),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildSystemOption(String value, String label, IconData icon) {
    final isSelected = _selectedType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(VSPSpacing.md),
          decoration: BoxDecoration(
            color: isSelected ? VSPColors.accent.withValues(alpha: 0.1) : VSPColors.surface,
            borderRadius: BorderRadius.circular(VSPRadius.lg),
            border: Border.all(
              color: isSelected ? VSPColors.accent : VSPColors.divider,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? VSPColors.accent : VSPColors.textSecondary, size: 32),
              const SizedBox(height: VSPSpacing.sm),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? VSPColors.accent : VSPColors.textPrimary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── STEP 3: Scheduling ─────────────────────────
  Widget _buildStep3() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      key: const ValueKey('step3'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(l10n.startDateLabel),
        GestureDetector(
          onTap: () => _selectDate(true),
          child: _buildDateChip(_startDate),
        ),
        const SizedBox(height: VSPSpacing.md),

        _buildLabel(l10n.endDateLabel),
        GestureDetector(
          onTap: () => _selectDate(false),
          child: _buildDateChip(_endDate),
        ),
        const SizedBox(height: VSPSpacing.md),

        _buildLabel(l10n.matchDurationLabel),
        _buildTextField(_durationController, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
        const SizedBox(height: VSPSpacing.md),

        _buildLabel(l10n.grandPrizeLabel),
        _buildTextField(_prizeController, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildDateChip(DateTime date) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.md),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('${date.day}/${date.month}/${date.year}', style: Theme.of(context).textTheme.bodyMedium),
          const Icon(Icons.calendar_today, color: VSPColors.accent, size: 18),
        ],
      ),
    );
  }

  // ── Shared Helpers ─────────────────────────────
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: VSPSpacing.xs, left: 4),
      child: Text(text, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildTextField(TextEditingController controller, {
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool autofocus = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.md),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        autofocus: autofocus,
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: InputDecoration(
          border: InputBorder.none,
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: 14),
          isDense: true,
          hintText: hint,
          hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary.withValues(alpha: 0.5)),
        ),
      ),
    );
  }

  Widget _buildDropdown(List<String> items, String value, Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.md),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          dropdownColor: VSPColors.surface,
          icon: const Icon(Icons.keyboard_arrow_down, color: VSPColors.textSecondary),
          isExpanded: true,
          style: Theme.of(context).textTheme.bodyMedium,
          items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
