import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models.dart';

class OwnerBookedScreen extends StatefulWidget {
  const OwnerBookedScreen({super.key});

  @override
  State<OwnerBookedScreen> createState() => _OwnerBookedScreenState();
}

class _OwnerBookedScreenState extends State<OwnerBookedScreen> {
  int _selectedDayIndex = 0; // Default to today

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isAuthenticated) {
        Provider.of<BookingProvider>(context, listen: false).loadOwnerBookings(auth.firebaseUser!.uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text(
          'Booked',
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
          // 1. Month Picker Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2C),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[800]!),
                  ),
                  child: Row(
                    children: const [
                      Text(
                        'January, 2025',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.calendar_today_outlined, color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Horizontal Calendar Strip
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 7, // Current Week
              itemBuilder: (context, index) {
                final date = DateTime.now().add(Duration(days: index));
                bool isSelected = index == _selectedDayIndex;
                String dayName = DateFormat('EEE').format(date).toUpperCase();

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDayIndex = index;
                    });
                  },
                  child: Container(
                    width: 60,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.neonGreen : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppTheme.neonGreen : Colors.grey[800]!,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            color: isSelected ? Colors.black : Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dayName,
                          style: TextStyle(
                            color: isSelected ? Colors.black : Colors.grey[600],
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 10),
          const Divider(color: Colors.white10, thickness: 1),
          
          // 3. Time Slots List
          Expanded(
            child: Consumer<BookingProvider>(
               builder: (context, bookingProvider, _) {
                 final selectedDate = DateTime.now().add(Duration(days: _selectedDayIndex));
                 final startOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
                 final endOfDay = startOfDay.add(const Duration(days: 1));

                 final dayBookings = bookingProvider.userBookings.where((b) => 
                    b.startTime.isAfter(startOfDay) && b.startTime.isBefore(endOfDay)
                 ).toList();

                 // Generate time slots from 12 PM to 11 PM
                 List<Map<String, dynamic>> slots = [];
                 for (int i = 12; i <= 23; i++) {
                   final hour = i > 12 ? i - 12 : i;
                   final period = i >= 12 ? 'PM' : 'AM';
                   final timeStr = '$hour$period';
                   
                   final booking = dayBookings.firstWhere(
                     (b) => b.startTime.hour == i,
                     orElse: () => Booking(
                       id: 'none',
                       stadiumId: '',
                       stadiumName: '',
                       ownerId: '',
                       startTime: DateTime.now(),
                       endTime: DateTime.now(),
                       totalPrice: 0,
                       status: BookingStatus.confirmed,
                       createdAt: DateTime.now(),
                       bookingType: BookingType.personal,
                       createdByUserId: '',
                       isPrivate: false,
                       rentBall: false,
                       paymentMethod: 'cash',
                     ),
                   );

                   if (booking.id == 'none') {
                     slots.add({'time': timeStr, 'type': 'empty'});
                   } else {
                     slots.add({
                       'time': timeStr,
                       'type': booking.playerTeamName != null ? 'team' : 'individual',
                       'name': booking.playerTeamName ?? 'Individual Player',
                       'subtitle': booking.bookingType == BookingType.challenge ? 'Challenge' : 'Match',
                       'image': 'https://images.unsplash.com/photo-1543351611-58f69d79443?w=150&h=150&fit=crop&q=80',
                       'logo': 'https://images.unsplash.com/photo-1543351611-58f69d79443?w=150&h=150&fit=crop&q=80',
                       'isManaged': true,
                     });
                   }
                 }

                 return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: slots.length,
                    separatorBuilder: (c, i) => const SizedBox(height: 20),
                    itemBuilder: (context, index) {
                      final slot = slots[index];
                      return _buildTimeSlotRow(slot);
                    },
                  );
               },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSlotRow(Map<String, dynamic> slot) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Time Label (Left Aligned)
        SizedBox(
          width: 50,
          child: Padding(
            padding: const EdgeInsets.only(top: 18.0), // Optical alignment
            child: Text(
              slot['time'],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Agency FB',
              ),
            ),
          ),
        ),
        
        // Slot Content
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (slot['type'] == 'empty') {
                 _showBookingModal(isEdit: false, slot: slot);
              } else if (slot['isManaged'] == true) {
                 _showBookingModal(isEdit: true, slot: slot);
              }
            },
            child: _buildSlotCard(slot),
          ),
        ),
      ],
    );
  }

  Widget _buildSlotCard(Map<String, dynamic> slot) {
    if (slot['type'] == 'empty') {
      return Container(
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          // No border for empty? Or maybe subtle?
          // Prompt says: "State A: Empty Slot: Show a large Neon Green button with '+ -' text."
          // Usually buttons have background. Let's make it a solid button button as shown in image 3 (green square)
          // Wait, Image 3 shows a small square green button "+-" next to the time? Or the whole row?
          // "State A: Empty Slot: Show a large Neon Green button with '+ -' text."
          // Image 3 shows: Time on left, then a Green Square Button with "+ -" inside it. It doesn't stretch.
          // Let's look at Image 3 provided in conversation... It's obscured.
          // But strict instruction says: "Below the calendar, create a vertical list of time slots... Slot Design: Each row should have the time label on the left and a large Neon Green '+ -' Button on the right."
          // And "State A: Empty Slot: Show a large Neon Green button...".
          // I will make a button that looks like the one described.
        ),
        alignment: Alignment.centerLeft,
        child: Container(
          width: 60,
          height: 50,
          decoration: BoxDecoration(
             color: AppTheme.neonGreen,
             borderRadius: BorderRadius.circular(15),
          ),
          alignment: Alignment.center,
          child: const Text(
            '+ -',
            style: TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }
    
    // Booked State
    bool isManaged = slot['isManaged'] ?? false;
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Dark card bg
        borderRadius: BorderRadius.circular(15),
        border: isManaged ? Border.all(color: AppTheme.neonGreen, width: 1.5) : Border.all(color: Colors.grey[800]!, width: 0.5),
      ),
      child: Row(
        children: [
          // Avatar/Logo
          if (slot['type'] == 'team')
            Container(
               width: 40, height: 40,
               decoration: BoxDecoration(
                 shape: BoxShape.circle,
                 image: DecorationImage(image: NetworkImage(slot['logo']), fit: BoxFit.cover),
               ),
            )
          else
             Container(
               width: 40, height: 40,
               decoration: BoxDecoration(
                 shape: BoxShape.circle,
                 image: DecorationImage(image: NetworkImage(slot['image']), fit: BoxFit.cover),
               ),
            ),
          
          const SizedBox(width: 12),
          
          // Name & Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  slot['name'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold, // Condensed bold implied
                    fontFamily: 'Agency FB',
                  ),
                ),
                Text(
                  slot['subtitle'], // 'Team', 'GK', etc
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Edit Actions or Team Stack
          if (slot['type'] == 'team')
             SizedBox(
               width: 60,
               height: 30,
               child: Stack(
                 children: [
                    _buildMiniAvatar(0, Colors.red),
                    _buildMiniAvatar(1, Colors.blue),
                    _buildMiniAvatar(2, AppTheme.neonGreen),
                 ],
               ),
             ),
             
          if (isManaged)
             const Icon(Icons.edit_outlined, color: AppTheme.neonGreen, size: 20),
        ],
      ),
    );
  }

  Widget _buildMiniAvatar(int index, Color color) {
     return Positioned(
       left: index * 15.0,
       child: CircleAvatar(
         radius: 10,
         backgroundColor: color,
         child: const Icon(Icons.person, size: 10, color: Colors.white), // Placeholder for stacked players
       ),
     );
  }

  void _showBookingModal({required bool isEdit, required Map<String, dynamic> slot}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildBookingSheet(isEdit, slot),
    );
  }

  Widget _buildBookingSheet(bool isEdit, Map<String, dynamic> slot) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75, // Tall modal
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E), // Dark Grey/Black
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle Bar
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          
          // Title
          Center(
            child: Text(
              isEdit ? 'Booked' : 'Add booking',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'Agency FB',
              ),
            ),
          ),
           const SizedBox(height: 30),

          // Date Field
          _buildInputLabel('Date'),
          _buildPillInput(initialValue: '2025/1/18'),
          const SizedBox(height: 15),

          // Time Fields
          _buildInputLabel('Time'),
          Row(
            children: [
               Expanded(child: _buildPillInput(initialValue: slot['time'] ?? '2 pm')),
               const SizedBox(width: 15),
               Expanded(child: _buildPillInput(initialValue: '3 pm')),
            ],
          ),
          const SizedBox(height: 15),

          // Name
          _buildInputLabel('Name'),
          _buildPillInput(initialValue: isEdit ? (slot['name'] ?? 'Mohamed') : ''),
          const SizedBox(height: 15),

          // Number
          _buildInputLabel('Number'),
          _buildPillInput(initialValue: isEdit ? '0111000222' : ''),
          const SizedBox(height: 15),

          // Payment
          _buildInputLabel('Payment'),
          _buildPillInput(initialValue: isEdit ? 'Payment Made' : ''),
          
          const Spacer(),
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: SizedBox(
                   height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                       // Delete or Cancel
                       Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isEdit ? Colors.red : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: Text(
                      isEdit ? 'Delete' : 'Cancel',
                      style: TextStyle(
                        color: isEdit ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Agency FB',
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // In a real app, logic to update sched here
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.neonGreen,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Agency FB',
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
           const SizedBox(height: 20), // Bottom Safe Area space
        ],
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPillInput({String? initialValue}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(15), // Pill shape
      ),
      child: TextFormField(
        initialValue: initialValue,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          isDense: true,
        ),
      ),
    );
  }
}
