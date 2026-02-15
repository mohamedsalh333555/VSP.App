import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class CreateTournamentScreen extends StatefulWidget {
  const CreateTournamentScreen({super.key});

  @override
  State<CreateTournamentScreen> createState() => _CreateTournamentScreenState();
}

class _CreateTournamentScreenState extends State<CreateTournamentScreen> {
  // Controllers
  final _nameController = TextEditingController();
  final _winningPointsController = TextEditingController(text: '3');
  final _breakEvenPointsController = TextEditingController(text: '1');
  final _lossPointsController = TextEditingController(text: '0');
  final _durationController = TextEditingController(text: '30');
  final _feesController = TextEditingController(text: '1000');
  final _prizeController = TextEditingController(text: '5000');
  final _instructionsController = TextEditingController();

  // State Variables
  String _selectedTypeTournament = 'Cup';
  String _selectedSport = 'Football';
  String _selectedNumTeams = '12';
  String _selectedMaxPlayers = '11';
  String _selectedMinPlayers = '5';
  String _selectedBackForth = 'Yes';
  String _selectedPitch = 'Pitch 1';
  String _selectedRounds = '1';
  String _selectedYellowCards = '1';
  
  bool _trophyMedals = true;
  bool _redCardSuspension = true;
  bool _fairPlayScoring = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Create a tournament',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'Agency FB',
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Basic Info ---
              _buildSectionTitle('Basic Info'),
              _buildInputLabel('Name Tournament'),
              _buildTextField(_nameController, hint: 'Sal Cup'),
              const SizedBox(height: 16),
              _buildInputLabel('Type Tournament'),
              _buildDropdown(['Cup', 'League'], _selectedTypeTournament, (v) => setState(() => _selectedTypeTournament = v!)),
              const SizedBox(height: 16),
              _buildInputLabel('Type Sport'),
              _buildDropdown(['Football', 'Basketball', 'Tennis'], _selectedSport, (v) => setState(() => _selectedSport = v!)),
              const SizedBox(height: 24),

              // --- Upload Cover ---
              _buildInputLabel('Upload Tournament Cover'),
              const Text('Recommended Size: 1920x1080', style: TextStyle(color: Colors.grey, fontSize: 10)),
              const SizedBox(height: 8),
              Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3), style: BorderStyle.solid), // Dashed border simulation needed? Solid looks cleaner for now or use dedicated package
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.camera_alt_outlined, color: AppTheme.neonGreen, size: 32),
                    SizedBox(height: 8),
                    Text('Upload Image', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text('JPG, JPEG, PNG Less Than 10MB', style: TextStyle(color: Colors.grey, fontSize: 10)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- League Settings ---
              _buildSectionTitle('League Settings'),
              _buildInputLabel('Number Of Teams'),
              _buildDropdown(['8', '12', '16', '20'], _selectedNumTeams, (v) => setState(() => _selectedNumTeams = v!)),
              const SizedBox(height: 16),
              _buildInputLabel('Maximum Number Of Players Per Team'),
              _buildDropdown(['5', '7', '11', '15'], _selectedMaxPlayers, (v) => setState(() => _selectedMaxPlayers = v!)),
              const SizedBox(height: 16),
              _buildInputLabel('Minimum Number Of Players Per Team'),
              _buildDropdown(['5', '7', '11'], _selectedMinPlayers, (v) => setState(() => _selectedMinPlayers = v!)),
              const SizedBox(height: 24),

              // --- Scoring Rules ---
              _buildSectionTitle('Scoring Rules'),
              _buildInputLabel('Winning Points'),
              _buildTextField(_winningPointsController),
              const SizedBox(height: 16),
              _buildInputLabel('Break-Even Points'),
              _buildTextField(_breakEvenPointsController),
              const SizedBox(height: 16),
              _buildInputLabel('Loss Points'),
              _buildTextField(_lossPointsController),
              const SizedBox(height: 24),

              // --- Match Settings ---
              _buildSectionTitle('Match Settings'),
              _buildInputLabel('Duration Of The Match'),
              _buildTextField(_durationController), // Could be dropdown or text with suffix
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
              _buildSectionTitle('Fees & Prize'),
              _buildInputLabel('Team Subscription Fees'),
              _buildTextField(_feesController),
              const SizedBox(height: 16),
              _buildInputLabel('Grand Prize'),
              _buildTextField(_prizeController),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Trophy/Medals', style: TextStyle(color: Colors.white, fontSize: 14)),
                  Switch(
                    value: _trophyMedals, 
                    onChanged: (v) => setState(() => _trophyMedals = v),
                    activeColor: AppTheme.neonGreen,
                  )
                ],
              ),
              const SizedBox(height: 24),

              // --- Rules & Regulations ---
              _buildSectionTitle('Rules & Regulations'),
              _buildInputLabel('Yellow Cards Before Suspension'),
              _buildDropdown(['1', '2', '3'], _selectedYellowCards, (v) => setState(() => _selectedYellowCards = v!)),
              const SizedBox(height: 16),
               Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   const Text('Red Cards Automatic Suspension', style: TextStyle(color: Colors.white, fontSize: 14)),
                   Switch(
                    value: _redCardSuspension,
                    onChanged: (v) => setState(() => _redCardSuspension = v),
                    activeColor: AppTheme.neonGreen,
                  )
                ],
              ),
               const SizedBox(height: 8),
               Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   const Text('Fair-Play Scoring', style: TextStyle(color: Colors.white, fontSize: 14)),
                   Switch(
                    value: _fairPlayScoring,
                    onChanged: (v) => setState(() => _fairPlayScoring = v),
                    activeColor: AppTheme.neonGreen,
                  )
                ],
              ),
              const SizedBox(height: 24),
              
               _buildInputLabel('Championship instructions'),
               Container(
                 height: 120,
                  decoration: BoxDecoration(
                   color: const Color(0xFF2C2C2C),
                   borderRadius: BorderRadius.circular(12),
                 ),
                 child: TextField(
                   controller: _instructionsController,
                   maxLines: 5,
                   style: const TextStyle(color: Colors.white, fontSize: 12),
                   decoration: const InputDecoration(
                     border: InputBorder.none,
                     contentPadding: EdgeInsets.all(16),
                     hintText: 'Welcome everyone, Before We Begin The Tournament I Would Like To Clarify Some Important Instructions To Ensure Fair Competition...',
                     hintStyle: TextStyle(color: Colors.grey),
                   ),
                 ),
               ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        color: const Color(0xFF121212),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.neonGreen,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Confirm',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: 'Agency FB',
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, {String? hint}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          isDense: true,
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildDropdown(List<String> items, String value, Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          dropdownColor: const Color(0xFF2C2C2C),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          isExpanded: true,
          style: const TextStyle(color: Colors.white),
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
}
