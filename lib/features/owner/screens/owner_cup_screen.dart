import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class OwnerCupScreen extends StatefulWidget {
  const OwnerCupScreen({super.key});

  @override
  State<OwnerCupScreen> createState() => _OwnerCupScreenState();
}

class _OwnerCupScreenState extends State<OwnerCupScreen> {
  int _selectedTab = 0; // 0: Coming, 1: Ongoing, 2: Finished
  String _selectedSport = 'Football';
  String _selectedCategory = 'Cup';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        automaticallyImplyLeading: false, // Root tab, no back button
        centerTitle: true,
        title: const Text(
          'Cup',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            fontFamily: 'Agency FB',
          ),
        ),
      ),
      body: Column(
        children: [
          // 1. Custom Tab Bar (Pill Design)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2C), // Dark Grey bg
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                children: [
                  _buildTabButton('Coming', 0),
                  _buildTabButton('Ongoing', 1),
                  _buildTabButton('Finished', 2),
                ],
              ),
            ),
          ),

          // 2. Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end, // Align to right if constrained, but Expanded fills width
              children: [
                Expanded(
                  child: _buildFilterDropdown(
                    ['Football', 'Basketball', 'Volleyball', 'Padel'], 
                    _selectedSport, 
                    (v) => setState(() => _selectedSport = v!)
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildFilterDropdown(
                    ['Cup', 'League'], 
                    _selectedCategory, 
                    (v) => setState(() => _selectedCategory = v!)
                  ),
                ),
              ],
            ),
          ),

           const SizedBox(height: 20),

          // 3. List of Tournaments
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: 2, // Mock items
              itemBuilder: (context, index) {
                return _buildTournamentCard();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String text, int index) {
    bool isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTab = index;
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.neonGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.grey[400],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterDropdown(List<String> items, String value, Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(8), // 8.0 radius as requested
        border: Border.all(color: AppTheme.neonGreen, width: 1), // Green border as per image
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          dropdownColor: const Color(0xFF2C2C2C),
          icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.neonGreen),
          style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Inter'),
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

  Widget _buildTournamentCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Deep Grey
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Logo, Title, Actions
          Row(
            children: [
              // Logo
              Container(
                width: 45,
                height: 45,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: NetworkImage('https://upload.wikimedia.org/wikipedia/en/thumb/f/f2/Al_Hilal_SFC_logo.svg/1200px-Al_Hilal_SFC_logo.svg.png'), // Real Logo
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Title & Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sal acd',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Agency FB',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Football • League',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Owner Actions
              Row(
                children: [
                   // Edit Button
                   InkWell(
                     onTap: () {
                       // Navigate to Edit
                     },
                     borderRadius: BorderRadius.circular(20),
                     child: Container(
                       width: 36,
                       height: 36,
                       decoration: BoxDecoration(
                         color: AppTheme.neonGreen.withValues(alpha: 0.1),
                         shape: BoxShape.circle,
                         border: Border.all(color: AppTheme.neonGreen.withValues(alpha: 0.3)),
                       ),
                       child: const Icon(Icons.edit_outlined, color: AppTheme.neonGreen, size: 18),
                     ),
                   ),
                   const SizedBox(width: 8),
                   // Share Button
                   InkWell(
                     onTap: () {
                       // Share logic
                     },
                     borderRadius: BorderRadius.circular(20),
                     child: Container(
                       width: 36,
                       height: 36,
                       decoration: BoxDecoration(
                         color: const Color(0xFF2C2C2C),
                         shape: BoxShape.circle,
                         border: Border.all(color: Colors.grey[800]!),
                       ),
                       child: const Icon(Icons.share_outlined, color: Colors.grey, size: 18),
                     ),
                   ),
                ],
              )
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Info Grid (Date, Entry Fee, Grand Prize)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoColumn('Date', 'Aug 6 - Sep 30'),
              _buildInfoColumn('Entry Fee', '900 eg'),
              _buildInfoColumn('Grand Prize', '2000 eg'),
            ],
          ),
          
           const SizedBox(height: 20),
           
           // Footer: Teams Joined
           Row(
             children: [
               SizedBox(
                 width: 120, // Enough for 5 avatars
                 height: 30,
                 child: Stack(
                   children: [
                      _buildAvatar(0, 'https://upload.wikimedia.org/wikipedia/en/thumb/4/47/FC_Barcelona_%28crest%29.svg/1200px-FC_Barcelona_%28crest%29.svg.png'),
                      _buildAvatar(1, 'https://upload.wikimedia.org/wikipedia/en/thumb/5/56/Real_Madrid_CF.svg/1200px-Real_Madrid_CF.svg.png'),
                      _buildAvatar(2, 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1b/FC_Bayern_M%C3%BCnchen_logo_%282017%29.svg/1024px-FC_Bayern_M%C3%BCnchen_logo_%282017%29.svg.png'),
                      _buildAvatar(3, 'https://upload.wikimedia.org/wikipedia/en/thumb/c/cc/Chelsea_FC.svg/1200px-Chelsea_FC.svg.png'),
                      _buildAvatar(4, 'https://upload.wikimedia.org/wikipedia/en/thumb/7/7a/Manchester_United_FC_crest.svg/1024px-Manchester_United_FC_crest.svg.png'),
                   ],
                 ),
               ),
               const SizedBox(width: 8),
               Text(
                 'Teams Joined: 9 / 12',
                 style: TextStyle(
                   color: Colors.grey[400],
                   fontSize: 12,
                   fontWeight: FontWeight.w500,
                 ),
               ),
             ],
           )
        ],
      ),
    );
  }
  
  Widget _buildAvatar(int index, String url) {
    return Positioned(
      left: index * 22.0, // Slight overlap
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF1E1E1E), width: 2), // Ring effect to separate
          image: DecorationImage(
            image: NetworkImage(url),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label, 
          style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w500)
        ),
        const SizedBox(height: 4),
        Text(
          value, 
          style: const TextStyle(
            color: Colors.white, 
            fontWeight: FontWeight.bold, 
            fontSize: 15, // Slightly bigger for emphasis
            fontFamily: 'Agency FB' // Condensed if possible
          )
        ),
      ],
    );
  }
}

