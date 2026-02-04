import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shimmer_image.dart';

class MatchResultModal extends StatefulWidget {
  final VoidCallback onConfirm;

  const MatchResultModal({super.key, required this.onConfirm});

  @override
  State<MatchResultModal> createState() => _MatchResultModalState();
}

class _MatchResultModalState extends State<MatchResultModal> {
  int _selectedResult = -1; // -1: None, 0: Team A, 1: Team B, 2: Draw

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E), // Dark card background
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Confirm Match Result',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Please Confirm The Final Match Outcome',
                      style: TextStyle(
                        color: AppTheme.neonGreen,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Match Info Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  // Teams
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildTeamInfo('Your Team', 'https://images.unsplash.com/photo-1543351611-58f69d7c1781?w=150&h=150&fit=crop&q=80'),
                      const Text(
                        'VS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      _buildTeamInfo('Real Madrid', 'https://images.unsplash.com/photo-1517466787929-bc90951d0974?w=150&h=150&fit=crop&q=80'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.grey, height: 1),
                  const SizedBox(height: 16),
                  // Details
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildDetailItem('Date', 'August 6th / pm7 to pm9'),
                      _buildDetailItem('Stadium', 'Sal Acd'),
                      _buildDetailItem('Pay', '120 eg'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Selection Buttons
            _buildSelectionButton(0, 'Team Aswan FC Win'),
            const SizedBox(height: 12),
            _buildSelectionButton(1, 'Team Real Madrid Win'),
            const SizedBox(height: 12),
            _buildSelectionButton(2, 'Draw'),

            const SizedBox(height: 24),
            const Divider(color: Colors.grey, height: 1),
            const SizedBox(height: 24),

            // Continue Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _selectedResult != -1 ? widget.onConfirm : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.neonGreen,
                  disabledBackgroundColor: Colors.grey[800],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Continue',
                  style: TextStyle(
                    color: _selectedResult != -1 ? Colors.black : Colors.white38,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamInfo(String name, String imageUrl) {
    return Column(
      children: [
        ShimmerImage(
          imageUrl: imageUrl,
          width: 60,
          height: 60,
          borderRadius: 30,
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12, // Small for fits
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionButton(int value, String text) {
    final isSelected = _selectedResult == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedResult = value;
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.grey[600] : const Color(0xFF2C2C2E), // Highlight or default
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: Colors.white) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
