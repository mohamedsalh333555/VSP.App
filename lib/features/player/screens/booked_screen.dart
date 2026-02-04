import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shimmer_image.dart';
import '../../../data/models.dart';
import '../../../core/services/database_service.dart';
import '../widgets/match_result_modal.dart';

class BookedScreen extends StatelessWidget {
  const BookedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock Data
    final upcomingBookings = [
      Team(
        id: '1',
        name: 'Your Team',
        captainName: 'Mohamed Salah',
        captainImageUrl: 'https://images.unsplash.com/photo-1579952363873-27f3bade9f55?w=150&h=150&fit=crop&q=80',
        date: 'August 6th / pm7 to pm9',
        stadium: 'Sal Acd',
        pricePerPerson: 140,
        currentPlayers: 3,
        maxPlayers: 12,
        playerImages: [
          'https://images.unsplash.com/photo-1543326727-cf6c39e8f84c?w=150&h=150&fit=crop&q=80',
          'https://images.unsplash.com/photo-1518020382113-a71843b51b3c?w=150&h=150&fit=crop&q=80',
          'https://images.unsplash.com/photo-1552318975-27db210dbff4?w=150&h=150&fit=crop&q=80',
        ],
      ),
      Team(
        id: 'personal',
        name: 'Mohamed Salah',
        captainName: 'GK',
        captainImageUrl: 'https://images.unsplash.com/photo-1560272564-c83b66b1ad12?w=150&h=150&fit=crop&q=80',
        date: 'August 6th / pm7 to pm9',
        stadium: 'Sal Acd',
        pricePerPerson: 120,
        currentPlayers: 0,
        maxPlayers: 0,
        playerImages: [],
      ),
    ];

    final historyBookings = [
      Team(
        id: '1',
        name: 'Your Team',
        captainName: 'Mohamed Salah',
        captainImageUrl: 'https://images.unsplash.com/photo-1517466787929-bc90951d0974?w=150&h=150&fit=crop&q=80',
        date: 'August 6th / pm7 to pm9',
        stadium: 'Sal Acd',
        pricePerPerson: 100,
        currentPlayers: 0,
        maxPlayers: 0,
        playerImages: [],
      ),
    ];

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          'Booked',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Upcoming Section
          const Text(
            'Upcoming',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...upcomingBookings.map((booking) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _BookedCard(booking: booking, isHistory: false),
              )),

          const SizedBox(height: 24),

          // History Section
          const Text(
            'History',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...historyBookings.map((booking) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _BookedCard(booking: booking, isHistory: true),
              )),
        ],
      ),
    );
  }
}

class _BookedCard extends StatelessWidget {
  final Team booking;
  final bool isHistory;

  const _BookedCard({
    required this.booking,
    required this.isHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF2D4B15), // Premium Deep Green
        borderRadius: BorderRadius.circular(15), // Standard 15.0 radius
        boxShadow: [
           BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // 1. Header: Avatar + Title + Actions
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              Container(
                width: 48, 
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: ShimmerImage(
                    imageUrl: booking.captainImageUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.name, // "Your Team" or "Mohamed Salah"
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16, 
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Agency FB',
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      booking.captainName, // "Mohamed Salah" or "GK"
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),

              // Action Buttons (Upcoming only) or Result Button (History)
              if (!isHistory) ...[
                // Edit Button
                _buildActionButton(Icons.edit, const Color(0xFF39FF14), () {}), 
                const SizedBox(width: 8),
                // Group Button
                _buildActionButton(Icons.groups, Colors.white, () {}),
              ] else ...[
                 GestureDetector(
                   onTap: () {
                     showDialog(
                       context: context,
                       builder: (context) => MatchResultModal(
                         onConfirm: () async {
                           // 1. Close Modal
                           Navigator.pop(context);
                           
                           // 2. Call Database Service
                           try {
                             // Assuming booking.id maps to a Match ID
                             // In this mock, we are using Team ID simulation
                             await DatabaseService().updateMatchResult(
                                 'match_${booking.id}', // Fake match ID for demo
                                 booking.id, // Winner ID
                             );
                             
                             if (context.mounted) {
                               ScaffoldMessenger.of(context).showSnackBar(
                                 const SnackBar(
                                   content: Text('Result Confirmed! Points Updated.'),
                                   backgroundColor: AppTheme.neonGreen,
                                 ),
                               );
                             }
                           } catch (e) {
                              if (context.mounted) {
                               ScaffoldMessenger.of(context).showSnackBar(
                                 SnackBar(
                                   content: Text('Error: $e'),
                                   backgroundColor: Colors.red,
                                 ),
                               );
                             }
                           }
                         },
                       ),
                     );
                   },
                   child: Container(
                     padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                     decoration: BoxDecoration(
                       color: const Color(0xFF39FF14),
                       borderRadius: BorderRadius.circular(20),
                     ),
                     child: const Text(
                       'Confirm Result',
                       style: TextStyle(
                         color: Colors.black,
                         fontWeight: FontWeight.bold,
                         fontSize: 12,
                       ),
                     ),
                   ),
                 ),
              ],
            ],
          ),

          const SizedBox(height: 16),
          
          // 2. Info Grid (3 Columns)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
               color: Colors.black.withOpacity(0.2), 
               borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 _buildInfoColumn('Date', _formatDate(booking.date)), // "Aug 6"
                 Container(width: 1, height: 24, color: Colors.white.withOpacity(0.1)),
                 _buildInfoColumn('Stadium', _shortenName(booking.stadium)), // "Sal Acd"
                 if (booking.pricePerPerson > 0) ...[
                    Container(width: 1, height: 24, color: Colors.white.withOpacity(0.1)),
                    _buildInfoColumn('Price', '${booking.pricePerPerson.toInt()} eg'),
                 ],
               ],
            ),
          ),

          if (booking.playerImages.isNotEmpty) ...[
             const SizedBox(height: 16),
             // 3. Footer: Avatars + Remaining
             Row(
               children: [
                 SizedBox(
                   width: 90,
                   height: 30,
                   child: Stack(
                     children: List.generate(
                       booking.playerImages.length > 3 ? 3 : booking.playerImages.length, // Limit to 3 visual
                       (index) => Positioned(
                         left: index * 20.0,
                         child: Container(
                           width: 30,
                           height: 30,
                           decoration: BoxDecoration(
                             border: Border.all(color: const Color(0xFF2D4B15), width: 2), // Match bg
                             shape: BoxShape.circle,
                           ),
                           child: ClipRRect(
                             borderRadius: BorderRadius.circular(15),
                             child: ShimmerImage(
                               imageUrl: booking.playerImages[index],
                               width: 30, 
                               height: 30,
                               fit: BoxFit.cover,
                             ),
                           ),
                         ),
                       ),
                     ),
                   ),
                 ),
                 if (booking.maxPlayers > 0)
                 Expanded(
                   child: RichText(
                     text: TextSpan(
                       style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                       children: [
                         const TextSpan(text: 'Remaining '),
                         TextSpan(
                           text: '${booking.maxPlayers - booking.currentPlayers}', // Calculate remaining
                           style: const TextStyle(
                             color: Colors.white,
                             fontWeight: FontWeight.bold,
                           ),
                         ),
                         TextSpan(text: ' of ${booking.maxPlayers}'),
                       ],
                     ),
                     overflow: TextOverflow.ellipsis,
                   ),
                 ),
               ],
             )
          ]
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
       child: Container(
         width: 36, 
         height: 36,
         decoration: BoxDecoration(
           color: Colors.white.withOpacity(0.1),
           shape: BoxShape.circle,
         ),
         child: Icon(icon, color: color, size: 18),
       ),
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _formatDate(String fullDate) {
    // Mock parsing: "August 6th / pm7 to pm9" -> "Aug 6"
    // In real app, use DateFormat
    if (fullDate.contains('August')) return 'Aug ${fullDate.split(' ')[1].replaceAll('th', '')}';
    return fullDate.split(' ')[0]; 
  }

  String _shortenName(String name) {
    if (name.length > 7) {
       return '${name.substring(0, 5)}..';
    }
    return name;
  }
}
