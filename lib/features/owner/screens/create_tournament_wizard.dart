import 'owner_tournament_dashboard_screen.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/tournament_repository.dart';
import '../../../core/repositories/stadium_repository.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../data/models.dart';

/// Quick Template preset data
class _TournamentTemplate {
  final String nameAr;
  final String nameEn;
  final String icon;
  final String type;
  final String sport;
  final int teams;
  final double fee;
  final double prize;
  final int durationMinutes;

  const _TournamentTemplate({
    required this.nameAr,
    required this.nameEn,
    required this.icon,
    required this.type,
    required this.sport,
    required this.teams,
    required this.fee,
    required this.prize,
    required this.durationMinutes,
  });

  String name(bool isAr) => isAr ? nameAr : nameEn;
}

const _quickTemplates = [
  _TournamentTemplate(
    nameAr: 'كأس رمضان',
    nameEn: 'Ramadan Cup',
    icon: '🌙',
    type: 'Cup',
    sport: 'Football',
    teams: 16,
    fee: 500,
    prize: 5000,
    durationMinutes: 25,
  ),
  _TournamentTemplate(
    nameAr: 'بطولة خماسية سريعة',
    nameEn: 'Fast 5s Tournament',
    icon: '⚡',
    type: 'Cup',
    sport: 'Football',
    teams: 8,
    fee: 300,
    prize: 3000,
    durationMinutes: 20,
  ),
  _TournamentTemplate(
    nameAr: 'دوري المحترفين',
    nameEn: 'Pro League',
    icon: '🏆',
    type: 'League',
    sport: 'Football',
    teams: 8,
    fee: 400,
    prize: 4000,
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
    }
  }

  void _loadOwnerSports() {
    final uid = Provider.of<AuthProvider>(context, listen: false).currentUser?.uid;
    if (uid != null) {
      StadiumRepository().getOwnerStadiums(uid).listen((stadiums) {
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
    _nameController.dispose();
    _feeController.dispose();
    _durationController.dispose();
    _prizeController.dispose();
    super.dispose();
  }

  void _applyTemplate(_TournamentTemplate t) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final name = t.name(isAr);
    setState(() {
      _selectedTemplateName = name;
      _nameController.text = name;
      _selectedSport = t.sport;
      _feeController.text = t.fee.toStringAsFixed(0);
      _selectedType = t.type;
      _selectedTeams = t.teams.toString();
      _durationController.text = t.durationMinutes.toString();
      _prizeController.text = t.prize.toStringAsFixed(0);
    });
    VSPFeedback.showSuccess(context, isAr ? 'تم تطبيق القالب: $name' : 'Template applied: $name');
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
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    if (_nameController.text.trim().isEmpty) {
      VSPFeedback.showError(context, isAr ? 'يرجى إدخال اسم البطولة' : 'Please enter tournament name');
      return;
    }
    if (_feeController.text.trim().isEmpty) {
      VSPFeedback.showError(context, isAr ? 'يرجى إدخال رسوم الاشتراك في البطولة' : 'Please enter tournament entry fee');
      return;
    }
    if (_prizeController.text.trim().isEmpty) {
      VSPFeedback.showError(context, isAr ? 'يرجى إدخال قيمة الجائزة الكبرى' : 'Please enter grand prize amount');
      return;
    }
    if (!_endDate.isAfter(_startDate)) { 
      VSPFeedback.showError(context, isAr ? 'تاريخ الانتهاء يجب أن يكون بعد تاريخ البدء!' : 'End date must be strictly after start date!'); 
      return; 
    }
    final maxTeamsNum = int.tryParse(_selectedTeams) ?? 0;
    if (maxTeamsNum != 4 && maxTeamsNum != 8 && maxTeamsNum != 16 && maxTeamsNum != 32) {
      VSPFeedback.showError(context, isAr ? 'عدد الفرق يجب أن يكون (4، 8، 16، 32) فقط!' : 'Number of teams must be a power of 2 (4, 8, 16, 32)!');
      return;
    }
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
        'ownerId': auth.userModel?.uid,
        'image': widget.tournament?.imageUrl ?? '',
        'teamsCount': int.parse(_selectedTeams),
        'maxTeams': int.parse(_selectedTeams),
        'grandPrize': double.tryParse(_prizeController.text.trim()) ?? 0.0,
        'entryFee': double.tryParse(_feeController.text.trim()) ?? 0.0,
        'number_of_groups': _numberOfGroups,
        'numberOfGroups': _numberOfGroups,
        'qualifying_per_group': _qualifyingPerGroup,
        'qualifyingPerGroup': _qualifyingPerGroup,
        'is_two_legs': _isTwoLegs,
        'isTwoLegs': _isTwoLegs,
        'rules': widget.tournament?.rules ?? '',
        'paymentMethods': widget.tournament?.paymentMethods ?? ['cash'],
        'settings': {
          'maxPlayers': widget.tournament?.maxPlayersPerTeam ?? 11,
          'minPlayers': widget.tournament?.minPlayersPerTeam ?? 5,
          'winningPoints': widget.tournament?.winningPoints ?? 3,
          'drawPoints': widget.tournament?.drawPoints ?? 1,
          'lossPoints': widget.tournament?.lossPoints ?? 0,
          'matchDuration': int.tryParse(_durationController.text.trim()) ?? 30,
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
        } else if (!success && mounted) {
          VSPFeedback.showError(context, 'فشل تعديل البطولة. يرجى المحاولة مرة أخرى.');
        }
      } else {
        // CREATE
        final id = await TournamentRepository().createChampionship(champData);
        if (id != null && mounted) {
          Navigator.pop(context);
          VSPFeedback.showSuccess(context, 'Tournament created successfully! 🏆');
          
          try {
            final newChampList = await TournamentRepository().getChampionshipsStream(sportType: _selectedSport).first;
            final newChamp = newChampList.firstWhere((c) => c.id == id);
            if (mounted) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => OwnerTournamentDashboardScreen(championship: newChamp)));
            }
          } catch (e) {
            // Fallback
          }
        } else if (id == null && mounted) {
          VSPFeedback.showError(context, 'فشل إنشاء البطولة. يرجى التحقق من دورك والاتصال بالإنترنت.');
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
          icon: Icon(Icons.adaptive.arrow_back, color: VSPColors.textPrimary),
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
      padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.lg, vertical: VSPSpacing.md),
      child: Row(
        children: [
          // Step 1
          _buildStepNode(0, labels[0]),
          // Line 1-2
          Expanded(child: _buildStepLine(1)),
          // Step 2
          _buildStepNode(1, labels[1]),
          // Line 2-3
          Expanded(child: _buildStepLine(2)),
          // Step 3
          _buildStepNode(2, labels[2]),
        ],
      ),
    );
  }

  Widget _buildStepNode(int i, String label) {
    final isActive = i <= _currentStep;
    final isCurrent = i == _currentStep;
    return SizedBox(
      width: 75,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? VSPColors.accent : const Color(0xFF1E2620),
              border: Border.all(
                color: isActive ? VSPColors.accent : const Color(0xFF3A473E),
                width: 2,
              ),
            ),
            child: Center(
              child: i < _currentStep
                  ? const Icon(Icons.check, color: Colors.black, size: 16)
                  : Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: isActive ? Colors.black : Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isCurrent
                  ? VSPColors.accent
                  : (isActive ? Colors.white70 : const Color(0xFFB0BEC5)),
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepLine(int nextStepIndex) {
    final isActive = nextStepIndex <= _currentStep;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      height: 2,
      color: isActive ? VSPColors.accent : VSPColors.divider,
    );
  }

  // ── STEP 1: Basics ──────────────────────────────
  Widget _buildStep1() {
    final l10n = AppLocalizations.of(context)!;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Column(
      key: const ValueKey('step1'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick Templates
        Text(l10n.quickTemplates, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        Text(l10n.choosePresetSubtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
        const SizedBox(height: VSPSpacing.md),
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            itemCount: _quickTemplates.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final t = _quickTemplates[i];
              final tName = t.name(isAr);
              final isSelected = _selectedTemplateName == tName;
              return GestureDetector(
                onTap: () => _applyTemplate(t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 155,
                  padding: const EdgeInsets.all(VSPSpacing.sm),
                  decoration: BoxDecoration(
                    color: isSelected ? VSPColors.accent.withValues(alpha: 0.12) : VSPColors.surface,
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    border: Border.all(
                      color: isSelected ? VSPColors.accent : VSPColors.divider,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: VSPColors.accent.withValues(alpha: 0.25),
                              blurRadius: 8,
                              spreadRadius: 1,
                            )
                          ]
                        : [],
                  ),
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(t.icon, style: const TextStyle(fontSize: 22)),
                          const SizedBox(height: 4),
                          Text(
                            tName,
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isSelected ? VSPColors.accent : VSPColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${t.teams} ${l10n.teams} • ${t.fee.toStringAsFixed(0)} ${isAr ? 'ج.م' : 'EGP'}',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: isSelected ? VSPColors.accent.withValues(alpha: 0.9) : Colors.white60, 
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      if (isSelected)
                        Positioned(
                          top: 0,
                          right: isAr ? null : 0,
                          left: isAr ? 0 : null,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: VSPColors.accent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, size: 10, color: Colors.black),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 28),

        _buildLabel(l10n.tournamentNameLabel),
        _buildTextField(_nameController, hint: isAr ? 'مثال: كأس الأبطال' : 'e.g. Star Cup', autofocus: widget.tournament == null),
        const SizedBox(height: VSPSpacing.md),

        _buildLabel(l10n.sportTypeLabel),
        _buildDropdown(_availableSports, _selectedSport, (v) => setState(() => _selectedSport = v!)),
        const SizedBox(height: VSPSpacing.md),

        _buildLabel(l10n.entryFeeLabel),
        _buildTextField(
          _feeController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          suffixText: isAr ? 'ج.م' : 'EGP',
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  // ── STEP 2: Tournament System ───────────────────
  Widget _buildStep2() {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return Column(
      key: const ValueKey('step2'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isArabic ? 'اختر نظام البطولة 🏆' : 'Choose Tournament Format 🏆',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        
        // 1. خروج المغلوب (Cup)
        _buildFormatOptionCard(
          type: 'Cup',
          title: isArabic ? 'خروج المغلوب (الكأس)' : 'Knockout (Cup)',
          subtitle: isArabic ? 'الخاسر يخرج فوراً. أعداد الفرق: 4، 8، 16، 32' : 'Single elimination. 4, 8, 16, 32 teams.',
          icon: LucideIcons.trophy,
        ),
        const SizedBox(height: 10),

        // 2. دوري كامل (League)
        _buildFormatOptionCard(
          type: 'League',
          title: isArabic ? 'دوري نقاط كامل (League)' : 'Full League (Points)',
          subtitle: isArabic ? 'كل الفرق تلعب ضد بعضها. الترتيب بأعلى النقاط' : 'Round-Robin system. Winner with most points.',
          icon: LucideIcons.award,
        ),
        const SizedBox(height: 10),

        // 3. مجموعات وتصفيات (Groups + Knockout)
        _buildFormatOptionCard(
          type: 'GroupsAndKnockout',
          title: isArabic ? 'مجموعات ثم تصفيات (كأس العالم)' : 'Groups + Knockout',
          subtitle: isArabic ? 'تقسيم لمجموعات ثم تصعيد المتأهلين للتصفيات' : 'Group stage followed by Knockout bracket.',
          icon: LucideIcons.shieldCheck,
        ),

        const SizedBox(height: 20),

        _buildLabel(AppLocalizations.of(context)!.maxTeamsLabel),
        _buildDropdown(['4', '8', '16', '32'], _selectedTeams, (v) => setState(() => _selectedTeams = v!)),
        const SizedBox(height: 16),

        // إعدادات خاصة بالمجموعات والدوري
        if (_selectedType == 'GroupsAndKnockout') ...[
          _buildLabel(isArabic ? 'عدد المجموعات:' : 'Number of Groups:'),
          _buildDropdown(['2', '4', '8'], _numberOfGroups.toString(), (v) => setState(() => _numberOfGroups = int.parse(v!))),
          const SizedBox(height: 12),
          _buildLabel(isArabic ? 'المتأهلين من كل مجموعة:' : 'Qualifiers per Group:'),
          _buildDropdown(['1', '2'], _qualifyingPerGroup.toString(), (v) => setState(() => _qualifyingPerGroup = int.parse(v!))),
          const SizedBox(height: 12),
        ],

        if (_selectedType == 'League') ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(isArabic ? 'ذهاب وإياد (دورين)' : 'Home & Away (Two Legs)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Switch.adaptive(
                value: _isTwoLegs,
                onChanged: (v) => setState(() => _isTwoLegs = v),
                activeColor: VSPColors.accent,
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildFormatOptionCard({
    required String type,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedType == type;
    return InkWell(
      onTap: () => setState(() => _selectedType = type),
      borderRadius: BorderRadius.circular(VSPRadius.lg),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? VSPColors.accent.withValues(alpha: 0.12) : VSPColors.surface,
          borderRadius: BorderRadius.circular(VSPRadius.lg),
          border: Border.all(
            color: isSelected ? VSPColors.accent : VSPColors.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? VSPColors.accent : VSPColors.textSecondary, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: isSelected ? VSPColors.accent : Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            if (isSelected)
              const Icon(LucideIcons.checkCircle, color: VSPColors.accent, size: 18),
          ],
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
      height: VSPSize.inputHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.input),
        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.15), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('${date.day}/${date.month}/${date.year}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
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
    String? suffixText,
  }) {
    return Container(
      height: VSPSize.inputHeight,
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.input),
        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.15), width: 1),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        autofocus: autofocus,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          border: InputBorder.none,
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: 14),
          isDense: true,
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
          suffixIcon: suffixText != null
              ? UnconstrainedBox(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: VSPColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: VSPColors.accent.withValues(alpha: 0.4), width: 0.5),
                    ),
                    child: Text(
                      suffixText,
                      style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildDropdown(List<String> items, String value, Function(String?) onChanged) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Container(
      height: VSPSize.inputHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.input),
        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.15), width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          dropdownColor: VSPColors.surface,
          icon: const Icon(Icons.keyboard_arrow_down, color: VSPColors.accent),
          isExpanded: true,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
          items: items.map((item) {
            String label = item;
            if (isAr) {
              if (item == 'Football') {
                label = 'كرة القدم';
              } else if (item == 'Basketball') {
                label = 'كرة السلة';
              } else if (item == 'Padel') {
                label = 'بادل';
              } else if (item == 'Volleyball') {
                label = 'كرة الطائرة';
              } else if (item == 'Tennis') {
                label = 'تنس';
              }
            }
            return DropdownMenuItem(value: item, child: Text(label));
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
