import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/providers/stadium_provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/vsp_animated_button.dart';
import '../../../shared/widgets/vsp_fade_in_item.dart';
import '../../../data/models.dart';

class OwnerBookedScreen extends StatefulWidget {
  const OwnerBookedScreen({super.key});

  @override
  State<OwnerBookedScreen> createState() => _OwnerBookedScreenState();
}

class _OwnerBookedScreenState extends State<OwnerBookedScreen> {
  int _selectedDayIndex = 0; // Default to today
  Stadium? _selectedStadium;
  DateTime _baseDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isAuthenticated) {
        final uid = auth.firebaseUser!.uid;
        Provider.of<BookingProvider>(context, listen: false).loadOwnerBookings(uid);
        Provider.of<StadiumProvider>(context, listen: false).listenToOwnerStadiums(uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        automaticallyImplyLeading: true,
        centerTitle: true,
        title: Text(
          'Booked',
          style: Theme.of(context).textTheme.displayMedium,
        ),
      ),
      body: Column(
        children: [
          // 1. Stadium Picker & Month Selector
          Padding(
            padding: const EdgeInsets.all(VSPSpacing.md),
            child: Row(
              children: [
                // Stadium Selection Pill
                Expanded(
                  child: Consumer<StadiumProvider>(
                    builder: (context, stadiumProvider, _) {
                      final stadiums = stadiumProvider.stadiums;
                      if (stadiums.isEmpty) return const SizedBox.shrink();
                      
                      // Identify the matching stadium instance from the current list to avoid reference mismatch
                      Stadium? effectiveValue;
                      if (stadiums.isNotEmpty) {
                        effectiveValue = stadiums.any((s) => s.id == _selectedStadium?.id)
                            ? stadiums.firstWhere((s) => s.id == _selectedStadium?.id)
                            : stadiums.first;
                      }

                      return Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md),
                        decoration: BoxDecoration(
                          color: VSPColors.surface,
                          borderRadius: BorderRadius.circular(VSPRadius.md),
                          border: Border.all(color: VSPColors.divider, width: 0.5),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<Stadium>(
                            value: effectiveValue,
                            dropdownColor: VSPColors.surface,
                            icon: const Icon(Icons.keyboard_arrow_down, color: VSPColors.textSecondary, size: 18),
                            isExpanded: true,
                            items: stadiums.map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(
                                s.name, 
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold, 
                                  color: VSPColors.textPrimary,
                                  fontSize: 13,
                                ),
                              ),
                            )).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedStadium = val;
                                });
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Month Display / Date Picker Trigger
                InkWell(
                  onTap: () => _selectDate(context),
                  borderRadius: BorderRadius.circular(VSPRadius.md),
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md),
                    decoration: BoxDecoration(
                      color: VSPColors.surface,
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                      border: Border.all(color: VSPColors.divider, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        Text(
                          DateFormat('MMMM, yyyy').format(_baseDate.add(Duration(days: _selectedDayIndex))),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: VSPColors.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.calendar_month_outlined, color: VSPColors.textSecondary, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Horizontal Calendar Strip (Aligned with Player UI)
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md),
              physics: const BouncingScrollPhysics(),
              itemCount: 14, // Extended to match player flow (2 weeks)
              itemBuilder: (context, index) {
                final date = _baseDate.add(Duration(days: index));
                bool isSelected = index == _selectedDayIndex;
                String dayName = DateFormat('E').format(date).toUpperCase();

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDayIndex = index;
                    });
                  },
                  child: Container(
                    width: 60,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? VSPColors.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                      border: Border.all(
                        color: isSelected ? VSPColors.accent : VSPColors.divider,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            color: isSelected ? VSPColors.background : VSPColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dayName,
                          style: TextStyle(
                            color: isSelected ? VSPColors.background : VSPColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
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
          const Divider(color: VSPColors.divider, thickness: 1),
          
          // 3. Time Slots List
          Expanded(
            child: Consumer<BookingProvider>(
               builder: (context, bookingProvider, _) {
                 final selectedDate = _baseDate.add(Duration(days: _selectedDayIndex));
                 final startOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
                 final endOfDay = startOfDay.add(const Duration(days: 1));

                  final dayBookings = bookingProvider.userBookings.where((b) => 
                    b.stadiumId == _selectedStadium?.id &&
                    b.startTime.isAfter(startOfDay) && b.startTime.isBefore(endOfDay)
                  ).toList();

                  // Generate time slots from 8 AM to 12 AM
                  List<Map<String, dynamic>> slots = [];
                  for (int i = 8; i <= 24; i++) {
                    final hourStr = i > 12 ? (i - 12).toString() : i.toString();
                    final period = i >= 12 && i < 24 ? 'PM' : (i == 24 ? 'AM' : 'AM');
                    final timeStr = '$hourStr:00 $period';
                    
                    final booking = dayBookings.firstWhere(
                      (b) => b.startTime.hour == i,
                      orElse: () => Booking(
                        id: 'none', stadiumId: '', stadiumName: '', ownerId: '',
                        startTime: DateTime.now(), endTime: DateTime.now(), totalPrice: 0,
                        status: BookingStatus.confirmed, createdAt: DateTime.now(),
                        bookingType: BookingType.personal, createdByUserId: '',
                        isPrivate: false, rentBall: false, paymentMethod: 'cash',
                      ),
                    );

                    if (booking.id == 'none') {
                      slots.add({'time': timeStr, 'hour': i, 'type': 'empty'});
                    } else {
                      slots.add({
                        'time': timeStr,
                        'hour': i,
                        'type': booking.playerTeamName != null ? 'team' : 'individual',
                        'name': booking.playerTeamName ?? 'Individual Player',
                        'subtitle': booking.bookingType.name.toUpperCase(),
                        'image': '',
                        'logo': '',
                        'isManaged': true,
                        'booking': booking,
                      });
                    }
                  }

                 return ListView.separated(
                    padding: EdgeInsets.fromLTRB(VSPSpacing.md, VSPSpacing.md, VSPSpacing.md, MediaQuery.of(context).padding.bottom + 110),
                    physics: const BouncingScrollPhysics(),
                    itemCount: slots.length,
                    separatorBuilder: (c, i) => const SizedBox(height: VSPSpacing.md),
                    itemBuilder: (context, index) {
                      final slot = slots[index];
                      return VSPFadeInItem(
                        index: index,
                        child: _buildTimeSlotRow(slot),
                      );
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Time Label
        SizedBox(
          width: 65,
          child: Text(
            slot['time'].replaceAll(' ', ''),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: VSPColors.textSecondary,
              fontSize: 12,
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
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(VSPRadius.md),
          border: Border.all(color: VSPColors.divider, width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.add_circle_outline, color: VSPColors.textSecondary, size: 20),
            const SizedBox(width: 12),
            Text(
              'Available Slot',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: VSPColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: VSPColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(VSPRadius.sm),
              ),
              child: const Text(
                'OPEN',
                style: TextStyle(color: VSPColors.accent, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }
    
    // Booked State
    bool isManaged = slot['isManaged'] ?? false;
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(
          color: isManaged ? VSPColors.accent.withValues(alpha: 0.5) : VSPColors.divider, 
          width: isManaged ? 1.5 : 1,
        ),
        boxShadow: isManaged ? [
          BoxShadow(
            color: VSPColors.accent.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ] : null,
      ),
      child: Row(
        children: [
          // Avatar/Logo with Fallback
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: VSPColors.surfaceAlt,
              border: Border.all(color: VSPColors.divider, width: 1),
            ),
            child: const Icon(Icons.person_outline, size: 20, color: VSPColors.textSecondary),
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
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  slot['subtitle'],
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ],
            ),
          ),
          
          if (isManaged) ...[
             const Icon(Icons.more_horiz, color: VSPColors.textSecondary, size: 20),
          ],
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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _baseDate.add(Duration(days: _selectedDayIndex)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: VSPColors.accent,
              onPrimary: VSPColors.background,
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
        _baseDate = DateTime(picked.year, picked.month, picked.day);
        _selectedDayIndex = 0;
      });
    }
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
    final nameController = TextEditingController(text: isEdit ? (slot['name'] ?? '') : '');
    final phoneController = TextEditingController(text: isEdit ? '0111000222' : '');
    bool isSaving = false;

    return StatefulBuilder(
      builder: (context, setModalState) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(VSPSpacing.md),
          decoration: BoxDecoration(
            color: VSPColors.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(VSPRadius.xl),
              topRight: Radius.circular(VSPRadius.xl),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: VSPColors.textSecondary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              
              Center(
                child: Text(
                  isEdit ? 'Booking Details' : 'Manual Booking',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ),
               const SizedBox(height: 30),

              _buildInputLabel('Stadium'),
              _buildPillInput(initialValue: _selectedStadium?.name ?? 'No Stadium Selected', enabled: false),
              const SizedBox(height: 15),

              _buildInputLabel('Date'),
              _buildPillInput(initialValue: DateFormat('yyyy/MM/dd').format(_baseDate.add(Duration(days: _selectedDayIndex))), enabled: false),
              const SizedBox(height: 15),

              _buildInputLabel('Time Slot'),
              _buildPillInput(initialValue: '${slot['time']} - ${slot['hour'] + 1}:00', enabled: false),
              const SizedBox(height: 15),

              _buildInputLabel('Customer Name'),
              _buildPillTextField(controller: nameController, hint: 'Enter name'),
              const SizedBox(height: 15),

              _buildInputLabel('Phone Number'),
              _buildPillTextField(controller: phoneController, hint: '01xxxxxxxxx'),
              const SizedBox(height: 15),

              const Spacer(),
              
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                       height: 50,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VSPColors.surfaceAlt,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                        ),
                        child: Text(
                          'Cancel',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: VSPColors.textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: VSPAnimatedButton(
                      text: 'Confirm',
                      isLoading: isSaving,
                      onPressed: isSaving ? () {} : () async {
                        if (nameController.text.isEmpty || _selectedStadium == null) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter name and select stadium')));
                          return;
                        }

                        setModalState(() => isSaving = true);

                        try {
                          final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
                          final authProvider = Provider.of<AuthProvider>(context, listen: false);
                          final uid = authProvider.firebaseUser!.uid;

                          final selectedDate = _baseDate.add(Duration(days: _selectedDayIndex));
                          final startTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, slot['hour'] as int);
                          final endTime = startTime.add(const Duration(hours: 1));

                          final draft = BookingDraft(
                            stadiumId: _selectedStadium!.id,
                            stadiumName: _selectedStadium!.name,
                            stadiumImageUrl: _selectedStadium!.imageUrl,
                            ownerId: uid,
                            startTime: startTime,
                            endTime: endTime,
                            bookingType: BookingType.personal,
                            playerTeamName: nameController.text,
                            isPrivate: true,
                            rentBall: false,
                            totalPrice: _selectedStadium!.pricePerHour.toDouble(),
                            paymentMethod: 'cash',
                            paymentTransactionId: 'MANUAL_${DateTime.now().millisecondsSinceEpoch}',
                          );

                          await bookingProvider.createBooking(draft, uid); // Use owner UID as creator for manual
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                        } finally {
                          setModalState(() => isSaving = false);
                        }
                      },
                    ),
                  ),
                ],
              ),
               const SizedBox(height: 20),
            ],
          ),
        );
      }
    );
  }

  Widget _buildPillTextField({required TextEditingController controller, required String hint}) {
    return Container(
      decoration: BoxDecoration(
        color: VSPColors.background,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.divider, width: 0.5),
      ),
      child: TextField(
        controller: controller,
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: VSPColors.textSecondary.withValues(alpha: 0.5)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
      ),
    );
  }

  Widget _buildPillInput({String? initialValue, bool enabled = true}) {
    return Container(
      decoration: BoxDecoration(
        color: VSPColors.background,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.divider, width: 0.5),
      ),
      child: TextFormField(
        initialValue: initialValue,
        enabled: enabled,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: enabled ? VSPColors.textPrimary : VSPColors.textSecondary,
            ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          isDense: true,
        ),
      ),
    );
  }
}
