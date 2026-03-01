import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models.dart';

class MatchResultModal extends StatefulWidget {
  final Booking booking;
  final Function(MatchOutcome outcome, double? rating, String? review) onConfirm;

  const MatchResultModal({
    super.key, 
    required this.booking,
    required this.onConfirm,
  });

  @override
  State<MatchResultModal> createState() => _MatchResultModalState();
}

class _MatchResultModalState extends State<MatchResultModal> {
  int _selectedIndex = -1; // -1: None, 0: We Won, 1: Draw, 2: We Lost
  double _rating = 0;
  final TextEditingController _reviewController = TextEditingController();

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

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
                      _buildTeamDisplay(widget.booking.playerTeamName ?? 'Your Team'),
                      const Text(
                        'VS',
                        style: TextStyle(
                          color: AppTheme.neonGreen, 
                          fontSize: 20, 
                          fontWeight: FontWeight.bold,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      _buildTeamDisplay(widget.booking.opponentTeamName ?? 'Opponent'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.grey, height: 1),
                  const SizedBox(height: 16),
                  // Details
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildDetailItem('Date', widget.booking.formattedDate),
                      _buildDetailItem('Stadium', widget.booking.stadiumName),
                      _buildDetailItem('Price', '${widget.booking.totalPrice.toInt()} ${widget.booking.currency}'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Selection Options
            _buildSelectionOption(0, 'We Won', Icons.emoji_events_outlined, Colors.amber),
            const SizedBox(height: 12),
            _buildSelectionOption(1, 'Draw', Icons.sync_alt, Colors.blue),
            const SizedBox(height: 12),
            _buildSelectionOption(2, 'We Lost', Icons.sentiment_very_dissatisfied, Colors.red),

            const SizedBox(height: 24),
            const Divider(color: Colors.white10),
            const SizedBox(height: 24),

            // Rating Section
            _buildRatingSection(),

            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _selectedIndex == -1 ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.neonGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  disabledBackgroundColor: Colors.white10,
                ),
                child: Text(
                  'Submit Result',
                  style: TextStyle(
                    color: _selectedIndex == -1 ? Colors.white24 : Colors.black,
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

  void _handleSubmit() {
    late MatchOutcome outcome;

    final myTeamId = widget.booking.playerTeamId ?? 'team_1';
    final isHome = myTeamId == widget.booking.playerTeamId;

    if (_selectedIndex == 0) { // We Won
      outcome = isHome ? MatchOutcome.homeWin : MatchOutcome.awayWin;
    } else if (_selectedIndex == 1) { // Draw
      outcome = MatchOutcome.draw;
    } else { // We Lost
      outcome = isHome ? MatchOutcome.awayWin : MatchOutcome.homeWin;
    }

    widget.onConfirm(
      outcome,
      _rating > 0 ? _rating : null,
      _reviewController.text.trim().isNotEmpty ? _reviewController.text.trim() : null,
    );
    
    // Trigger rating update logic (could be passed back via the callback in a future iteration,
    // but for now, we assume the callback handles the outcome and the provider handles the rating)
  }

  Widget _buildRatingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rate the Stadium (Optional)',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  _rating = index + 1.0;
                });
              },
              child: Icon(
                index < _rating ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 32,
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _reviewController,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Write a review...',
            hintStyle: const TextStyle(color: Colors.white24),
            filled: true,
            fillColor: const Color(0xFF2C2C2E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionOption(int index, String label, IconData icon, Color activeColor) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.2) : const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : Colors.white10,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? activeColor : Colors.white54),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(Icons.check_circle, color: activeColor),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamDisplay(String name) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white10,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24),
          ),
          child: const Icon(Icons.sports_soccer, color: Colors.white24),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 80,
          child: Text(
            name,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
