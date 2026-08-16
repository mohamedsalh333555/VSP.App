import 'owner_tournament_dashboard_screen.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/tournament_repository.dart';
import '../../../core/repositories/stadium_repository.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../data/models.dart';

class CreateTournamentWizard extends StatefulWidget {
  final Championship? tournament;
  final String? preselectedType;
  const CreateTournamentWizard({super.key, this.tournament, this.preselectedType});

  /// 🏆 إتاحة إنشاء البطولة لجميع الملاك بدون استثناء
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
    } else if (widget.preselectedType != null) {
      // Pre-fill type from FAB bottom sheet selection
      _selectedType = widget.preselectedType!;
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
      final currentUid = auth.currentUser?.uid ?? auth.firebaseUser?.uid ?? auth.userModel?.uid ?? Supabase.instance.client.auth.currentUser?.id ?? '';
      final currentGov = auth.governorate.trim().isNotEmpty 
          ? auth.governorate 
          : (auth.userModel?.governorate ?? 'القاهرة');

      final champData = {
        'name': _nameController.text.trim(),
        'type': _selectedType,
        'sportType': _selectedSport,
        'startDate': _startDate.toIso8601String(),
        'endDate': _endDate.toIso8601String(),
        'governorate': currentGov,
        'ownerId': currentUid,
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
          icon: Icon(
            Localizations.localeOf(context).languageCode == 'ar'
                ? Iconsax.arrow_right_3_copy
                : Iconsax.arrow_left_2_copy,
            color: VSPColors.textPrimary,
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            _prevStep();
          },
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Stack(
        children: [
          // Background Connecting Lines
          Positioned(
            left: 28 / 2 + 12,
            right: 28 / 2 + 12,
            top: 28 / 2 - 1,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 2,
                    color: _currentStep >= 1 ? VSPColors.accent : VSPColors.divider,
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 2,
                    color: _currentStep >= 2 ? VSPColors.accent : VSPColors.divider,
                  ),
                ),
              ],
            ),
          ),
          // Stepper Circles and Text
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(3, (i) {
              final isActive = i <= _currentStep;
              final isCurrent = i == _currentStep;
              return Column(
                mainAxisSize: MainAxisSize.min,
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
                          ? const Icon(Iconsax.tick_circle_copy, color: Colors.black, size: 16)
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
                          fontSize: 10,
                        ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── STEP 1: Basics ──────────────────────────────
  Widget _buildStep1() {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Column(
      key: const ValueKey('step1'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. اختيار نظام البطولة (أول شيء في الصفحة)
        Text(
          isAr ? 'اختر نظام البطولة 🏆' : 'Choose Tournament Format 🏆',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        
        // خروج المغلوب (Cup)
        _buildFormatOptionCard(
          type: 'Cup',
          title: isAr ? 'خروج المغلوب' : 'Knockout',
          subtitle: isAr ? 'الخاسر يخرج فوراً. أعداد الفرق: 4، 8، 16، 32' : 'Single elimination. 4, 8, 16, 32 teams.',
          icon: Iconsax.cup_copy,
        ),
        const SizedBox(height: 10),

        // دوري كامل (League)
        _buildFormatOptionCard(
          type: 'League',
          title: isAr ? 'دوري نقاط كامل' : 'Full League',
          subtitle: isAr ? 'كل الفرق تلعب ضد بعضها. الترتيب بأعلى النقاط' : 'Round-Robin system. Winner with most points.',
          icon: Iconsax.award_copy,
        ),
        const SizedBox(height: 10),

        // مجموعات وتصفيات (Groups + Knockout)
        _buildFormatOptionCard(
          type: 'GroupsAndKnockout',
          title: isAr ? 'مجموعات ثم تصفيات' : 'Groups & Knockout',
          subtitle: isAr ? 'تقسيم لمجموعات ثم تصعيد المتأهلين للتصفيات' : 'Group stage followed by Knockout bracket.',
          icon: Iconsax.security_safe_copy,
        ),

        const SizedBox(height: 24),
        const Divider(color: VSPColors.divider, height: 1),
        const SizedBox(height: 20),

        // 2. البيانات الأساسية للبطولة
        _buildLabel(isAr ? 'اسم البطولة' : 'Tournament Name'),
        _buildTextField(_nameController, hint: isAr ? 'مثال: كأس الأبطال' : 'e.g. Star Cup', autofocus: widget.tournament == null),
        const SizedBox(height: VSPSpacing.md),

        _buildLabel(isAr ? 'نوع الرياضة' : 'Sport Type'),
        _buildDropdown(_availableSports, _selectedSport, (v) => setState(() => _selectedSport = v!)),
        const SizedBox(height: VSPSpacing.md),

        _buildLabel(isAr ? 'رسوم الاشتراك (ج.م)' : 'Entry Fee (EGP)'),
        _buildTextField(
          _feeController,
          hint: isAr ? 'أدخل رسوم الاشتراك (مثال: 300)' : 'Enter entry fee (e.g. 300)',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          suffixText: isAr ? 'ج.م' : 'EGP',
        ),
        const SizedBox(height: 40),
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
          isArabic ? 'إعدادات وقواعد البطولة ⚙️' : 'Tournament Rules & Format ⚙️',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 16),

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
              Text(isArabic ? 'ذهاب وإياب' : 'Home & Away', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Switch.adaptive(
                value: _isTwoLegs,
                onChanged: (v) => setState(() => _isTwoLegs = v),
                activeColor: VSPColors.accent,
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 40),
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
              const Icon(Iconsax.tick_circle_copy, color: VSPColors.accent, size: 18),
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
    return SizedBox(
      height: VSPSize.inputHeight,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textDirection: (keyboardType == TextInputType.phone ||
                keyboardType == TextInputType.number ||
                (keyboardType != null && keyboardType.toString().contains('number')))
            ? TextDirection.ltr
            : null,
        inputFormatters: inputFormatters,
        autofocus: autofocus,
        cursorColor: VSPColors.accent,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          filled: true,
          fillColor: VSPColors.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          counterText: '',
          isDense: true,
          hintText: hint,
          hintStyle: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(VSPRadius.lg),
            borderSide: const BorderSide(color: VSPColors.divider, width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(VSPRadius.lg),
            borderSide: const BorderSide(color: VSPColors.accent, width: 1.0),
          ),
          suffixIcon: suffixText != null
              ? UnconstrainedBox(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      suffixText,
                      style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 12),
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
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: VSPColors.divider, width: 0.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          dropdownColor: VSPColors.surface,
          icon: const Icon(Iconsax.arrow_down_1_copy, color: VSPColors.accent, size: 16),
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
