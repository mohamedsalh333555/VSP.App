import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shimmer_image.dart';

class MyTeamScreen extends StatefulWidget {
  const MyTeamScreen({super.key});

  @override
  State<MyTeamScreen> createState() => _MyTeamScreenState();
}

class _MyTeamScreenState extends State<MyTeamScreen> {
  final TextEditingController _teamNameController = TextEditingController(text: 'El Mokatm');
  final TextEditingController _sportsTypeController = TextEditingController(text: 'Football');

  final List<String> _members = [
    'Mohamed Awad',
    'Mohamed Ahmed',
    'Mohamed Abdo',
    'Mohamed Salah',
    'Mohamed Awad',
    'Mohamed Alaa',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Team',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatCard('9', 'Rank your team', isRedArrow: true, width: 80),
                _buildStatCard('8', 'Team number', width: 80),
                _buildStatCard('3', 'Stadiums I played in', width: 85),
                _buildStatCard('1', 'Championships won', width: 85),
              ],
            ),
            
            const SizedBox(height: 24),

            // Team Name
            const Text(
              'Team Name',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 8),
            _buildTextField(_teamNameController),

            const SizedBox(height: 16),

            // Sports Type
            const Text(
              'Sports Type',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 8),
            _buildTextField(_sportsTypeController),

            const SizedBox(height: 24),

            // Team Logo & Upload
            Row(
              children: [
                ShimmerImage(
                  imageUrl: 'https://images.unsplash.com/photo-1543351611-58f69d7c1781?w=150&h=150&fit=crop&q=80', // Real team logo/player portrait
                  width: 50,
                  height: 50,
                  borderRadius: 25,
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.cloud_upload_outlined, color: Colors.black),
                  label: const Text('Upload Photo', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.neonGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Members
            Text(
              'Add Team Members (${_members.length}) Of (8)',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _members.map((member) => _buildMemberChip(member)).toList(),
              ),
            ),

            const SizedBox(height: 40),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.neonGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Done', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String value, String label, {bool isRedArrow = false, required double width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.neonGreen),
      ),
      child: Column(
        children: [
           Row(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               if (isRedArrow) const Icon(Icons.arrow_drop_down, color: Colors.red, size: 20),
               Text(
                 value, 
                 style: const TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w300, fontFamily: 'AgencyFB'),
               ),
             ],
           ),
           Text(
             label,
             textAlign: TextAlign.center,
             style: paramTextStyle(fontSize: 9),
           )
        ],
      ),
    );
  }

  TextStyle paramTextStyle({required double fontSize}) => TextStyle(color: AppTheme.textSecondary, fontSize: fontSize);

  Widget _buildTextField(TextEditingController controller) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildMemberChip(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
           ShimmerImage(
             imageUrl: 'https://images.unsplash.com/photo-1552674605-db6ffd4facb5?w=50&h=50&fit=crop&q=80',
             width: 24,
             height: 24,
             borderRadius: 12,
           ),
           const SizedBox(width: 8),
           Text(name, style: const TextStyle(color: Colors.white, fontSize: 12)),
           const SizedBox(width: 8),
           const Icon(Icons.close, color: Colors.white, size: 16),
        ],
      ),
    );
  }
}
