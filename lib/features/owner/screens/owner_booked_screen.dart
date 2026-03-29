import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/providers/stadium_provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/vsp_animated_button.dart';
import '../../../shared/widgets/vsp_fade_in_item.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
        final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
        bookingProvider.loadOwnerBookings(uid);
        Provider.of<StadiumProvider>(context, listen: false).listenToOwnerStadiums(uid);
      }
    });
  }

  int _parseTimeToHour(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return 8;
    try {
      final parts = timeStr.trim().split(' ');
      if (parts.length != 2) return 8;
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      final period = parts[1].toUpperCase();
      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      return hour;
    } catch (e) {
      return 8;
    }
  }

  String _formatHour(int h) {
    final hour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final period = (h >= 12 && h < 24) ? 'PM' : 'AM';
    return '$hour:00 $period';
  }

  String _formatHourMin(int h, int m) {
    final hour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final period = (h >= 12 && h < 24) ? 'PM' : 'AM';
    final minute = m.toString().padLeft(2, '0');
    return '$hour:$minute $period';
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
            child: Consumer2<BookingProvider, StadiumProvider>(
               builder: (context, bookingProvider, stadiumProvider, _) {
                 final stadiums = stadiumProvider.stadiums;
                 final selectedStadium = stadiums.any((s) => s.id == _selectedStadium?.id)
                     ? stadiums.firstWhere((s) => s.id == _selectedStadium?.id)
                     : (stadiums.isNotEmpty ? stadiums.first : null);

                 final selectedDate = _baseDate.add(Duration(days: _selectedDayIndex));
                 final startOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
                 final endOfDay = startOfDay.add(const Duration(days: 1));

                  final dayBookings = bookingProvider.userBookings.where((b) => 
                    b.stadiumId == selectedStadium?.id &&
                    b.startTime.isAfter(startOfDay) && b.startTime.isBefore(endOfDay)
                  ).toList();

                  // Generate time slots based on stadium hours (30-minute intervals)
                  List<Map<String, dynamic>> slots = [];
                  if (selectedStadium != null) {
                    try {
                      final int startH = _parseTimeToHour(selectedStadium.openingTime);
                      final int endH = _parseTimeToHour(selectedStadium.closingTime);
                      final int breakStartH = selectedStadium.isSplitShift ? _parseTimeToHour(selectedStadium.breakStartTime) : -1;
                      final int breakEndH = selectedStadium.isSplitShift ? _parseTimeToHour(selectedStadium.breakEndTime) : -1;
                      
                      int currentH = startH;
                      int currentM = 0;
                      int safeguard = 0;
                      
                      // Handle 24h as a special case where start == end
                      bool is24h = startH == endH;
                      
                      while (safeguard < 48) { // max 48 half-hour slots in a day
                        final timeStr = _formatHourMin(currentH, currentM);
                        
                        // Check if we've reached the end
                        if (safeguard > 0 && currentH == endH && currentM == 0 && !is24h) break;
                        
                        // Check if in break range
                        bool isBreak = false;
                        if (selectedStadium.isSplitShift && breakStartH != -1 && breakEndH != -1) {
                           if (breakStartH < breakEndH) {
                             isBreak = currentH >= breakStartH && currentH < breakEndH;
                           } else {
                             // Over-night break
                             isBreak = currentH >= breakStartH || currentH < breakEndH;
                           }
                        }

                        // Match booking by checking if the slot falls within any booking's time range
                        final slotTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, currentH, currentM);
                        final booking = dayBookings.firstWhere(
                          (b) => slotTime.isAtSameMomentAs(b.startTime) || (slotTime.isAfter(b.startTime) && slotTime.isBefore(b.endTime)),
                          orElse: () => Booking(
                            id: 'none', stadiumId: '', stadiumName: '', ownerId: '',
                            startTime: DateTime.now(), endTime: DateTime.now(), totalPrice: 0,
                            status: BookingStatus.confirmed, createdAt: DateTime.now(),
                            bookingType: BookingType.personal, createdByUserId: '',
                            isPrivate: false, rentBall: false, paymentMethod: 'cash',
                          ),
                        );

                        if (isBreak) {
                          slots.add({'time': timeStr, 'hour': currentH, 'minute': currentM, 'type': 'break'});
                        } else if (booking.id == 'none') {
                          slots.add({'time': timeStr, 'hour': currentH, 'minute': currentM, 'type': 'empty'});
                        } else {
                          final bool isManual = booking.paymentTransactionId != null && booking.paymentTransactionId!.contains('MANUAL');
                          slots.add({
                            'time': timeStr,
                            'hour': currentH,
                            'minute': currentM,
                            'type': isManual ? 'manual' : (booking.playerTeamName != null ? 'team' : 'individual'),
                            'name': booking.playerTeamName ?? 'Individual Player',
                            'subtitle': isManual ? 'BOOKED MANUALLY' : booking.bookingType.name.toUpperCase(),
                            'image': '',
                            'logo': '',
                            'isManaged': true,
                            'isManual': isManual,
                            'booking': booking,
                          });
                        }
                        
                        // Increment by 30 minutes
                        currentM += 30;
                        if (currentM >= 60) {
                          currentM = 0;
                          currentH = (currentH + 1) % 24;
                        }
                        safeguard++;
                      }
                    } catch (e) {
                      debugPrint('Error generating slots: $e');
                      slots.clear();
                    }
                  }

                  if (slots.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(VSPSpacing.xl),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: VSPColors.error),
                            const SizedBox(height: 16),
                            Text(
                              selectedStadium == null ? 'Please select a stadium' : 'Please check your working hours settings or set them first',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    );
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
            const Icon(Icons.add_circle, color: VSPColors.textSecondary, size: 24),
            const SizedBox(width: 12),
            Text(
              'Add Manual Booking',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: VSPColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (slot['type'] == 'break') 
                    ? VSPColors.textSecondary.withValues(alpha: 0.1)
                    : VSPColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(VSPRadius.sm),
              ),
              child: Text(
                (slot['type'] == 'break') ? 'CLOSED / BREAK' : 'OPEN',
                style: TextStyle(
                  color: (slot['type'] == 'break') ? VSPColors.textSecondary : VSPColors.accent, 
                  fontSize: 10, 
                  fontWeight: FontWeight.bold
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    // Booked State
    final booking = slot['booking'] as Booking?;
    bool isManual = slot['isManual'] ?? false;
    final now = DateTime.now();
    final bool isCompleted = booking != null && booking.endTime.isBefore(now);

    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isManual ? VSPColors.surface : VSPColors.background,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(
          color: isManual ? Colors.blueAccent.withValues(alpha: 0.5) : VSPColors.divider, 
          width: 1,
        ),
        boxShadow: isManual ? [
          BoxShadow(
            color: Colors.blueAccent.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ] : null,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isManual ? Colors.blueAccent.withValues(alpha: 0.1) : VSPColors.surfaceAlt,
            ),
            child: Icon(
              isManual ? Icons.edit_note : Icons.sports_soccer, 
              size: 22, 
              color: isManual ? Colors.blueAccent : VSPColors.accent
            ),
          ),
          
          const SizedBox(width: 14),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  slot['name'] ?? '',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold, 
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      slot['subtitle'] ?? '',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: VSPColors.textSecondary,
                        fontSize: 11
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isCompleted ? VSPColors.success.withValues(alpha: 0.1) : VSPColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isCompleted ? 'COLLECTED' : 'PENDING',
                        style: TextStyle(
                          color: isCompleted ? VSPColors.success : VSPColors.warning,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const Icon(Icons.arrow_forward_ios, color: VSPColors.textSecondary, size: 14),
        ],
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
    final booking = slot['booking'] as Booking?;
    final nameController = TextEditingController(text: isEdit ? (slot['name'] ?? '') : '');
    final phoneController = TextEditingController(text: isEdit ? (booking?.playerPhone ?? '') : '');
    final noteController = TextEditingController(text: isEdit ? (booking?.notes ?? '') : '');
    bool isSaving = false;
    bool isDeleting = false;

    return StatefulBuilder(
      builder: (context, setModalState) {
        bool isPaid = booking?.isPaid ?? false;
        final bool isCompleted = booking != null && booking.endTime.isBefore(DateTime.now());

        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
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
              const SizedBox(height: 16),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEdit ? 'Booking Details' : 'Manual Booking',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  if (isEdit)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: VSPColors.error),
                      onPressed: isDeleting ? null : () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: VSPColors.surface,
                            title: const Text('Cancel Booking?'),
                            content: const Text('Are you sure you want to remove this booking? This action cannot be undone.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('NO')),
                              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('YES', style: TextStyle(color: VSPColors.error))),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          setModalState(() => isDeleting = true);
                          if (!mounted) return;
                          await Provider.of<BookingProvider>(this.context, listen: false).cancelBooking(booking!.id);
                          if (!mounted) return;
                          Navigator.pop(this.context);
                        }
                      },
                    ),
                ],
              ),
               const SizedBox(height: 20),

              Expanded(
                child: SingleChildScrollView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInputLabel('Time & Stadium'),
                      _buildPillInput(initialValue: '${slot['time']} - ${_selectedStadium?.name ?? "Stadium"}', enabled: false),
                      const SizedBox(height: 15),

                      _buildInputLabel('Customer Name'),
                      _buildPillTextField(controller: nameController, hint: 'Enter name'),
                      const SizedBox(height: 15),

                      _buildInputLabel('Phone Number'),
                      _buildPillTextField(controller: phoneController, hint: '01xxxxxxxxx (Optional)'),
                      const SizedBox(height: 15),

                      _buildInputLabel('Internal Notes'),
                      _buildPillTextField(controller: noteController, hint: 'e.g. Paid deposit, special request...'),
                      const SizedBox(height: 20),

                      // Payment Indicator (Read-only)
                      Container(
                        padding: const EdgeInsets.all(VSPSpacing.md),
                        decoration: BoxDecoration(
                          color: VSPColors.background,
                          borderRadius: BorderRadius.circular(VSPRadius.md),
                          border: Border.all(color: VSPColors.divider, width: 0.5),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.payments_outlined, color: VSPColors.accent),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Payment Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text(isCompleted ? 'COLLECTED (Automated)' : 'PENDING (Automated)', style: TextStyle(color: isCompleted ? VSPColors.success : VSPColors.warning, fontSize: 11)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isCompleted ? VSPColors.success.withValues(alpha: 0.1) : VSPColors.warning.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(VSPRadius.sm),
                              ),
                              child: Text(
                                isCompleted ? 'COLLECTED' : 'PENDING',
                                style: TextStyle(
                                  color: isCompleted ? VSPColors.success : VSPColors.warning,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
              
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
                          'Close',
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
                      text: isEdit ? 'Update' : 'Confirm',
                      isLoading: isSaving,
                      onPressed: isSaving ? () {} : () async {
                        if (nameController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter customer name')));
                          return;
                        }

                        setModalState(() => isSaving = true);

                        try {
                          final bookingProvider = Provider.of<BookingProvider>(this.context, listen: false);
                          
                          if (isEdit) {
                            // Update existing (Manual or Real)
                            await FirebaseFirestore.instance.collection('bookings').doc(booking!.id).update({
                              'playerTeamName': nameController.text.trim(),
                              'playerPhone': phoneController.text.trim(),
                              'notes': noteController.text.trim(),
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                          } else {
                            // Create New Manual
                            final stadiumProvider = Provider.of<StadiumProvider>(this.context, listen: false);
                            final authProvider = Provider.of<AuthProvider>(this.context, listen: false);
                            final uid = authProvider.firebaseUser!.uid;
                            final stadium = stadiumProvider.stadiums.firstWhere((s) => s.id == _selectedStadium?.id, orElse: () => stadiumProvider.stadiums.first);

                            final selectedDate = _baseDate.add(Duration(days: _selectedDayIndex));
                            final startTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, slot['hour'] as int);
                            final endTime = startTime.add(const Duration(hours: 1));

                            final draft = BookingDraft(
                              stadiumId: stadium.id, stadiumName: stadium.name, stadiumImageUrl: stadium.imageUrl,
                              ownerId: uid, startTime: startTime, endTime: endTime,
                              bookingType: BookingType.personal, playerTeamName: nameController.text,
                              playerPhone: phoneController.text, notes: noteController.text,
                              isPrivate: true, rentBall: false,
                              totalPrice: stadium.pricePerHour.toDouble(),
                              isPaid: false, // Default to false, reconciled later
                              paymentMethod: 'cash', paymentTransactionId: 'MANUAL_${DateTime.now().millisecondsSinceEpoch}',
                            );

                            await bookingProvider.createBooking(draft, uid);
                          }
                          
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        } finally {
                          setModalState(() => isSaving = false);
                        }
                      },
                    ),
                  ),
                ],
              ),
               const SizedBox(height: 10),
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
