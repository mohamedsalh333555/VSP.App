import 'owner_tournament_dashboard_screen.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/ui/components/vsp_section_title.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/tournament_repository.dart';
import '../../../core/repositories/stadium_repository.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../shared/widgets/custom_text_field.dart';

class CreateTournamentScreen extends StatefulWidget {
  const CreateTournamentScreen({super.key});

  @override
  State<CreateTournamentScreen> createState() => _CreateTournamentScreenState();
}

class _CreateTournamentScreenState extends State<CreateTournamentScreen> {
  // Controllers
  final _nameController = TextEditingController();
  final _winningPointsController = TextEditingController();
  final _breakEvenPointsController = TextEditingController();
  final _lossPointsController = TextEditingController();
  final _durationController = TextEditingController();
  final _feesController = TextEditingController();
  final _prizeController = TextEditingController();
  final _instructionsController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _winningPointsController.dispose();
    _breakEvenPointsController.dispose();
    _lossPointsController.dispose();
    _durationController.dispose();
    _feesController.dispose();
    _prizeController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  // State Variables
  String _selectedTypeTournament = 'Cup';
  String _selectedSport = 'Football';
  String _selectedNumTeams = '16'; // 🟢 Default to a valid power of 2
  String _selectedMaxPlayers = '11';
  String _selectedMinPlayers = '5';
  String _selectedBackForth = 'Yes';
  String _selectedPitch = 'Pitch 1';
  String _selectedRounds = '1';
  String _selectedYellowCards = '1';
  
  bool _trophyMedals = true;
  bool _redCardSuspension = true;
  bool _fairPlayScoring = false;
  String _selectedPaymentMethod = 'Cash';
  bool _isLoading = false;
  List<String> _availableSports = ['Football'];

  DateTime _startDate = DateTime.now().add(const Duration(days: 7));
  DateTime _endDate = DateTime.now().add(const Duration(days: 37));

  @override
  void initState() {
    super.initState();
    _loadOwnerSports();
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

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: VSPColors.accent,
              onPrimary: Colors.black,
              surface: VSPColors.surface,
              onSurface: VSPColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
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

  Future<void> _handleCreateTournament() async {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    if (_nameController.text.trim().isEmpty) {
      VSPFeedback.showError(context, isAr ? 'يرجى إدخال اسم البطولة' : 'Please enter a tournament name');
      return;
    }

    if (!_endDate.isAfter(_startDate)) {
      VSPFeedback.showError(context, isAr ? 'تاريخ الانتهاء يجب أن يكون بعد تاريخ البدء!' : 'End date must be strictly after start date!');
      return;
    }

    final maxTeamsNum = int.tryParse(_selectedNumTeams) ?? 0;
    if (maxTeamsNum != 4 && maxTeamsNum != 8 && maxTeamsNum != 16 && maxTeamsNum != 32) {
      VSPFeedback.showError(context, isAr ? 'عدد الفرق يجب أن يكون (4، 8، 16، 32) فقط!' : 'Number of teams must be a power of 2 (4, 8, 16, 32)!');
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      
      List<String> payments = [];
      if (_selectedPaymentMethod == 'Cash') {
        payments = ['cash'];
      } else if (_selectedPaymentMethod == 'Online') {
        payments = ['online'];
      } else {
        payments = ['cash', 'online'];
      }

      final champData = {
        'name': _nameController.text.trim(),
        'type': _selectedTypeTournament,
        'sportType': _selectedSport,
        'startDate': _startDate.toIso8601String(),
        'endDate': _endDate.toIso8601String(),
        'governorate': auth.governorate,
        'ownerId': auth.userModel?.uid,
        'image': '', // Removed fake tournament image
        'teamsCount': int.parse(_selectedNumTeams),
        'maxTeams': int.parse(_selectedNumTeams),
        'joinedTeams': [],
        'grandPrize': double.tryParse(_prizeController.text.trim()) ?? 5000.0,
        'entryFee': double.tryParse(_feesController.text.trim()) ?? 500.0,
        'rules': _instructionsController.text.trim(),
        'paymentMethods': payments,
        'settings': {
          'maxPlayers': _selectedMaxPlayers,
          'minPlayers': _selectedMinPlayers,
          'winningPoints': int.tryParse(_winningPointsController.text.trim()) ?? 3,
          'drawPoints': int.tryParse(_breakEvenPointsController.text.trim()) ?? 1,
          'lossPoints': int.tryParse(_lossPointsController.text.trim()) ?? 0,
          'matchDuration': int.tryParse(_durationController.text.trim()) ?? 30,
          'isBackAndForth': _selectedBackForth == 'Yes',
          'trophyMedals': _trophyMedals,
          'redCardSuspension': _redCardSuspension,
          'fairPlayScoring': _fairPlayScoring,
        }
      };

      final id = await TournamentRepository().createChampionship(champData);
      
      if (id != null && mounted) {
        Navigator.pop(context);
        VSPFeedback.showSuccess(context, 'Tournament Created Successfully!');
        
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
    } catch (e) {
      if (mounted) {
        VSPFeedback.showError(context, 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: VSPColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'Create a tournament',
          style: Theme.of(context).textTheme.displaySmall,
        ),
      ),
      body: SingleChildScrollView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
        padding: const EdgeInsets.only(bottom: 100),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Basic Info ---
              const VSPSectionTitle('Basic Info'),
              _buildInputLabel('Name Tournament'),
              _buildTextField(_nameController, hint: 'Sal Cup', maxLength: 50),
              const SizedBox(height: 16),
              _buildInputLabel('Type Tournament'),
              _buildDropdown(['Cup', 'League'], _selectedTypeTournament, (v) => setState(() => _selectedTypeTournament = v!)),
              const SizedBox(height: 16),
              _buildInputLabel('Type Sport'),
              _buildDropdown(_availableSports, _selectedSport, (v) => setState(() => _selectedSport = v!)),
              const SizedBox(height: 24),

              // --- Dates ---
              const VSPSectionTitle('Tournament Dates'),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInputLabel('Start Date'),
                        GestureDetector(
                          onTap: () => _selectDate(context, true),
                          child: _buildDateDisplay(_startDate),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInputLabel('End Date'),
                        GestureDetector(
                          onTap: () => _selectDate(context, false),
                          child: _buildDateDisplay(_endDate),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // --- Upload Cover ---
              _buildInputLabel('Upload Tournament Cover'),
              Text('Recommended Size: 1920x1080', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary)),
              const SizedBox(height: VSPSpacing.xs),
              Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: VSPColors.surface,
                  borderRadius: BorderRadius.circular(VSPRadius.md),
                  border: Border.all(color: VSPColors.divider, style: BorderStyle.solid), 
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.camera, color: VSPColors.accent, size: 32),
                    const SizedBox(height: VSPSpacing.xs),
                    Text('Upload Image', style: Theme.of(context).textTheme.titleSmall),
                    Text('JPG, JPEG, PNG Less Than 10MB', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- League Settings ---
              const VSPSectionTitle('League Settings'),
              _buildInputLabel('Number Of Teams'),
              _buildDropdown(['4', '8', '16', '32'], _selectedNumTeams, (v) => setState(() => _selectedNumTeams = v!)), // 🟢 FIXED: Only Powers of 2 for Knockout Algorithm
              const SizedBox(height: 16),
              _buildInputLabel('Maximum Number Of Players Per Team'),
              _buildDropdown(['5', '7', '11', '15'], _selectedMaxPlayers, (v) => setState(() => _selectedMaxPlayers = v!)),
              const SizedBox(height: 16),
              _buildInputLabel('Minimum Number Of Players Per Team'),
              _buildDropdown(['5', '7', '11'], _selectedMinPlayers, (v) => setState(() => _selectedMinPlayers = v!)),
              const SizedBox(height: 24),

              // --- Scoring Rules ---
              const VSPSectionTitle('Scoring Rules'),
              _buildInputLabel('Winning Points'),
              _buildTextField(_winningPointsController, hint: 'e.g. 3', maxLength: 2, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
              const SizedBox(height: 16),
              _buildInputLabel('Break-Even Points'),
              _buildTextField(_breakEvenPointsController, hint: 'e.g. 1', maxLength: 2, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
              const SizedBox(height: 16),
              _buildInputLabel('Loss Points'),
              _buildTextField(_lossPointsController, hint: 'e.g. 0', maxLength: 2, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
              const SizedBox(height: 24),

              // --- Match Settings ---
              const VSPSectionTitle('Match Settings'),
              _buildInputLabel('Duration Of The Match'),
              _buildTextField(_durationController, hint: 'e.g. 30', maxLength: 3, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly]), // Could be dropdown or text with suffix
               const SizedBox(height: 16),
              _buildInputLabel('Back And Forth'),
              _buildDropdown(['Yes', 'No'], _selectedBackForth, (v) => setState(() => _selectedBackForth = v!)),
              const SizedBox(height: 16),
              _buildInputLabel('Determine The Pitch'),
              _buildDropdown(['Pitch 1', 'Pitch 2'], _selectedPitch, (v) => setState(() => _selectedPitch = v!)),
              const SizedBox(height: 16),
              _buildInputLabel('Number Of Rounds'),
               _buildDropdown(['1', '2', '3'], _selectedRounds, (v) => setState(() => _selectedRounds = v!)),
              const SizedBox(height: 24),

              // --- Fees & Prize ---
              const VSPSectionTitle('Fees & Prize'),
              _buildInputLabel('Team Subscription Fees'),
              _buildTextField(_feesController, hint: 'e.g. 1000', maxLength: 7, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
              const SizedBox(height: 16),
              _buildInputLabel('Grand Prize'),
              _buildTextField(_prizeController, hint: 'e.g. 5000', maxLength: 7, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
              const SizedBox(height: 16),
              _buildInputLabel('Payment Method'),
              _buildDropdown(['Cash', 'Online', 'Both'], _selectedPaymentMethod, (v) => setState(() => _selectedPaymentMethod = v!)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Trophy/Medals', style: Theme.of(context).textTheme.bodyMedium),
                  Switch(
                    value: _trophyMedals, 
                    onChanged: (v) => setState(() => _trophyMedals = v),
                    activeColor: VSPColors.accent,
                  )
                ],
              ),
              const SizedBox(height: 24),

              // --- Rules & Regulations ---
              const VSPSectionTitle('Rules & Regulations'),
              _buildInputLabel('Yellow Cards Before Suspension'),
              _buildDropdown(['1', '2', '3'], _selectedYellowCards, (v) => setState(() => _selectedYellowCards = v!)),
              const SizedBox(height: 16),
               Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text('Red Cards Automatic Suspension', style: Theme.of(context).textTheme.bodyMedium),
                   Switch(
                    value: _redCardSuspension,
                    onChanged: (v) => setState(() => _redCardSuspension = v),
                    activeColor: VSPColors.accent,
                  )
                ],
              ),
               const SizedBox(height: 8),
               Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text('Fair-Play Scoring', style: Theme.of(context).textTheme.bodyMedium),
                   Switch(
                    value: _fairPlayScoring,
                    onChanged: (v) => setState(() => _fairPlayScoring = v),
                    activeColor: VSPColors.accent,
                  )
                ],
              ),
              const SizedBox(height: 24),
              
              _buildInputLabel('Championship instructions'),
                Container(
                  height: 120,
                   decoration: BoxDecoration(
                    color: VSPColors.surface,
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                  ),
                  child: TextField(
                    controller: _instructionsController,
                    maxLines: 5,
                    maxLength: 500,
                    style: Theme.of(context).textTheme.bodySmall,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      counterText: "",
                      contentPadding: const EdgeInsets.all(VSPSpacing.md),
                      hintText: 'Welcome everyone, Before We Begin The Tournament I Would Like To Clarify Some Important Instructions To Ensure Fair Competition...',
                      hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.textSecondary),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(VSPSpacing.md, VSPSpacing.md, VSPSpacing.md, MediaQuery.of(context).padding.bottom + VSPSpacing.md),
        color: VSPColors.background,
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: PrimaryButton(
            text: 'Confirm',
            isLoading: _isLoading,
            onPressed: _isLoading ? () {} : _handleCreateTournament,
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: VSPSpacing.xs, left: 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, {
    String? hint, 
    int? maxLength,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return CustomTextField(
      controller: controller,
      hintText: hint,
      maxLength: maxLength,
      keyboardType: keyboardType ?? TextInputType.text,
      inputFormatters: inputFormatters,
    );
  }

  Widget _buildDropdown(List<String> items, String value, Function(String?) onChanged) {
    return Container(
      height: VSPSize.inputHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.input),
        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          dropdownColor: VSPColors.surface,
          icon: Icon(LucideIcons.chevronDown, color: VSPColors.textSecondary),
          isExpanded: true,
          style: Theme.of(context).textTheme.bodyMedium,
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildDateDisplay(DateTime date) {
    return Container(
      height: VSPSize.inputHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.input),
        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "${date.day}/${date.month}/${date.year}",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Icon(LucideIcons.calendar, color: VSPColors.accent, size: 18),
        ],
      ),
    );
  }
}
