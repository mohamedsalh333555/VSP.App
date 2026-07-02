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
import '../../../shared/widgets/vsp_empty_state.dart';
import '../../../data/models.dart';
import '../../../core/utils/phone_utils.dart';

class OwnerBookingsScreen extends StatefulWidget {
  const OwnerBookingsScreen({super.key});

  @override
  State<OwnerBookingsScreen> createState() => _OwnerBookingsScreenState();
}

class _OwnerBookingsScreenState extends State<OwnerBookingsScreen> {
  int _selectedDayIndex = 0; 
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

  String _formatHourMin(int h, int m) {
    final hour = hour12(h);
    final period = h >= 12 ? 'PM' : 'AM';
    final minute = m.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  int hour12(int h) {
    if (h == 0) return 12;
    if (h > 12) return h - 12;
    return h;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        automaticallyImplyLeading: true,
        leading: Navigator.canPop(context) 
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: VSPColors.textPrimary),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        centerTitle: true,
        title: Text(
          l10n.bookedTitle,
          style: Theme.of(context).textTheme.displayMedium,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(VSPSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Consumer<StadiumProvider>(
                    builder: (context, stadiumProvider, _) {
                      final stadiums = stadiumProvider.stadiums;
                      if (stadiums.isEmpty) return const SizedBox.shrink();
                      
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
                          DateFormat('MMMM, yyyy', Localizations.localeOf(context).toString()).format(_baseDate.add(Duration(days: _selectedDayIndex))),
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

          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md),
              physics: const BouncingScrollPhysics(),
              itemCount: 14, 
              itemBuilder: (context, index) {
                final date = _baseDate.add(Duration(days: index));
                bool isSelected = index == _selectedDayIndex;
                String dayName = DateFormat('E', Localizations.localeOf(context).toString()).format(date).toUpperCase();

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
          
          Expanded(
            child: Consumer2<BookingProvider, StadiumProvider>(
               builder: (context, bookingProvider, stadiumProvider, _) {
                 final stadiums = stadiumProvider.stadiums;
                 final selectedStadium = stadiums.any((s) => s.id == _selectedStadium?.id)
                     ? stadiums.firstWhere((s) => s.id == _selectedStadium?.id)
                     : (stadiums.isNotEmpty ? stadiums.first : null);

                 if (selectedStadium == null) {
                    return VSPEmptyState(
                      icon: Icons.stadium_outlined,
                      title: l10n.stadiumsEmptyTitle,
                      subtitle: l10n.stadiumsEmptySubtitle,
                    );
                 }

                 final selectedDate = _baseDate.add(Duration(days: _selectedDayIndex));
                 final startOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
                 final endOfDay = startOfDay.add(const Duration(days: 1));

                  final dayBookings = bookingProvider.userBookings.where((b) => 
                    b.stadiumId == selectedStadium.id &&
                    !b.startTime.isBefore(startOfDay) && b.startTime.isBefore(endOfDay)
                  ).toList();

                  List<Map<String, dynamic>> slots = [];
                  try {
                    final int startH = _parseTimeToHour(selectedStadium.openingTime);
                    final int endH = _parseTimeToHour(selectedStadium.closingTime);
                    final int breakStartH = selectedStadium.isSplitShift ? _parseTimeToHour(selectedStadium.breakStartTime) : -1;
                    final int breakEndH = selectedStadium.isSplitShift ? _parseTimeToHour(selectedStadium.breakEndTime) : -1;
                    
                    int currentH = startH;
                    int currentM = 0;
                    int safeguard = 0;
                    bool is24h = (startH == endH && safeguard == 0);
                    
                    while (safeguard < 48) { 
                      final timeStr = _formatHourMin(currentH, currentM);
                      if (safeguard > 0 && currentH == endH && currentM == 0 && !is24h) break;
                      
                      bool isBreak = false;
                      if (selectedStadium.isSplitShift && breakStartH != -1 && breakEndH != -1) {
                         if (breakStartH < breakEndH) {
                           isBreak = currentH >= breakStartH && currentH < breakEndH;
                         } else {
                           isBreak = currentH >= breakStartH || currentH < breakEndH;
                         }
                      }

                      final slotTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, currentH, currentM);
                      final booking = dayBookings.cast<Booking?>().firstWhere(
                        (b) => b != null && (slotTime.isAtSameMomentAs(b.startTime) || (slotTime.isAfter(b.startTime) && slotTime.isBefore(b.endTime))),
                        orElse: () => null,
                      );

                      if (isBreak) {
                        slots.add({'time': timeStr, 'hour': currentH, 'minute': currentM, 'type': 'break'});
                      } else if (booking == null) {
                        slots.add({'time': timeStr, 'hour': currentH, 'minute': currentM, 'type': 'empty'});
                      } else {
                        final bool isManual = booking.paymentTransactionId?.contains('MANUAL') ?? false;
                        slots.add({
                          'time': timeStr,
                          'hour': currentH,
                          'minute': currentM,
                          'type': isManual ? 'manual' : (booking.playerTeamName != null ? 'team' : 'individual'),
                          'name': booking.playerTeamName ?? l10n.individualPlayerLabel,
                          'subtitle': isManual ? l10n.bookedManually : booking.bookingType.name.toUpperCase(),
                          'isManaged': true,
                          'isManual': isManual,
                          'booking': booking,
                        });
                      }
                      
                      currentM += 30;
                      if (currentM >= 60) {
                        currentM = 0;
                        currentH = (currentH + 1) % 24;
                      }
                      safeguard++;
                    }
                  } catch (e) {
                    slots.clear();
                  }

                  if (slots.isEmpty) {
                    return VSPEmptyState(
                      icon: Icons.access_time,
                      title: l10n.noWorkingHoursTitle,
                      subtitle: l10n.noWorkingHoursSubtitle,
                    );
                  }

                 return ListView.separated(
                    padding: EdgeInsets.fromLTRB(VSPSpacing.md, VSPSpacing.md, VSPSpacing.md, MediaQuery.of(context).padding.bottom + 110),
                    physics: const AlwaysScrollableScrollPhysics(),
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
    final l10n = AppLocalizations.of(context)!;
    if (slot['type'] == 'empty' || slot['type'] == 'break') {
      final bool isBreak = slot['type'] == 'break';
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
            Icon(isBreak ? Icons.block : Icons.add_circle, color: VSPColors.textSecondary, size: 24),
            const SizedBox(width: 12),
            Text(
              isBreak ? l10n.breakTime : l10n.addManualBooking,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: VSPColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isBreak 
                    ? VSPColors.textSecondary.withValues(alpha: 0.1)
                    : VSPColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(VSPRadius.sm),
              ),
              child: Text(
                isBreak ? l10n.closedBadge : l10n.openBadge,
                style: TextStyle(
                  color: isBreak ? VSPColors.textSecondary : VSPColors.accent, 
                  fontSize: 10, 
                  fontWeight: FontWeight.bold
                ),
              ),
            ),
          ],
        ),
      );
    }
    
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
                        isCompleted ? l10n.collectedSticker : l10n.pendingSticker,
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
          data: ThemeData.dark().copyWith(
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
      builder: (context) => _BookingSheetContent(
        isEdit: isEdit,
        slot: slot,
        selectedStadium: _selectedStadium,
        baseDate: _baseDate,
        selectedDayIndex: _selectedDayIndex,
        parentContext: this.context,
      ),
    );
  }
}

class _BookingSheetContent extends StatefulWidget {
  final bool isEdit;
  final Map<String, dynamic> slot;
  final Stadium? selectedStadium;
  final DateTime baseDate;
  final int selectedDayIndex;
  final BuildContext parentContext;

  const _BookingSheetContent({
    required this.isEdit,
    required this.slot,
    required this.selectedStadium,
    required this.baseDate,
    required this.selectedDayIndex,
    required this.parentContext,
  });

  @override
  State<_BookingSheetContent> createState() => _BookingSheetContentState();
}

class _BookingSheetContentState extends State<_BookingSheetContent> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _noteController;
  bool _isSaving = false;
  bool _isDeleting = false;
  int _selectedMinutes = 60;
  bool _isManualDepositReceived = false;

  @override
  void initState() {
    super.initState();
    final booking = widget.slot['booking'] as Booking?;
    _nameController = TextEditingController(text: widget.isEdit ? (widget.slot['name'] ?? '') : '');
    _phoneController = TextEditingController(text: widget.isEdit ? (booking?.playerPhone ?? '') : '');
    _noteController = TextEditingController(text: widget.isEdit ? (booking?.notes ?? '') : '');

    if (widget.isEdit && booking != null) {
      _selectedMinutes = booking.endTime.difference(booking.startTime).inMinutes;
      _isManualDepositReceived = booking.isDepositPaid;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  DateTime _parseTimeToDateTime(DateTime date, String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return date;
    try {
      final clean = timeStr.trim();
      final format = DateFormat('hh:mm a');
      final parsedTime = format.parse(clean);
      return DateTime(date.year, date.month, date.day, parsedTime.hour, parsedTime.minute);
    } catch (e) {
      try {
        final parts = timeStr.trim().split(' ');
        final timeParts = parts[0].split(':');
        int hour = int.parse(timeParts[0]);
        int minute = timeParts.length > 1 ? int.parse(timeParts[1]) : 0;
        final period = parts[1].toUpperCase();
        if (period == 'PM' && hour != 12) hour += 12;
        if (period == 'AM' && hour == 12) hour = 0;
        return DateTime(date.year, date.month, date.day, hour, minute);
      } catch (_) {
        return date;
      }
    }
  }

  Widget _buildDurationSelector() {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final options = [
      {'label': isArabic ? 'ساعة' : '1 Hour', 'value': 60},
      {'label': isArabic ? 'ساعة ونصف' : '1.5 Hours', 'value': 90},
      {'label': isArabic ? 'ساعتين' : '2 Hours', 'value': 120},
    ];

    return Row(
      children: options.map((opt) {
        final isSelected = _selectedMinutes == opt['value'];
        return Expanded(
          child: GestureDetector(
            onTap: widget.isEdit ? null : () {
              setState(() {
                _selectedMinutes = opt['value'] as int;
              });
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? VSPColors.accent : VSPColors.surfaceAlt,
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(
                  color: isSelected ? VSPColors.accent : VSPColors.divider,
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  opt['label'] as String,
                  style: TextStyle(
                    color: isSelected ? VSPColors.background : VSPColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDepositToggleCard() {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final depositAmount = widget.selectedStadium?.depositAmount ?? 0.0;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VSPColors.surfaceAlt,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.divider, width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.handshake_outlined, color: VSPColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? "تم استلام العربون يدوياً" : "Manual Deposit Received",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: VSPColors.textPrimary),
                ),
                Text(
                  isArabic
                      ? "قيمة العربون: ${depositAmount.toInt()} ج.م"
                      : "Deposit amount: ${depositAmount.toInt()} EGP",
                  style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          Switch(
            value: _isManualDepositReceived,
            onChanged: (val) {
              setState(() {
                _isManualDepositReceived = val;
              });
            },
            activeColor: VSPColors.accent,
            activeTrackColor: VSPColors.accentSoft,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final booking = widget.slot['booking'] as Booking?;
    final bool isCompleted = booking != null && booking.endTime.isBefore(DateTime.now());

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(VSPSpacing.md),
        decoration: const BoxDecoration(
          color: VSPColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(VSPRadius.xl),
            topRight: Radius.circular(VSPRadius.xl),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
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
                  widget.isEdit ? l10n.bookingDetailsTitle : l10n.manualBookingTitle,
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                if (widget.isEdit)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: VSPColors.error),
                    onPressed: _isDeleting ? null : () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: VSPColors.surface,
                          title: Text(l10n.cancelBooking),
                          content: Text(l10n.cancelBookingConfirm),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancelBtn)),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.confirmBtn, style: const TextStyle(color: VSPColors.error))),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        setState(() => _isDeleting = true);
                        await Provider.of<BookingProvider>(widget.parentContext, listen: false).cancelBooking(booking!.id);
                        if (!mounted) return;
                        Navigator.pop(context);
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
                    _buildInputLabel(l10n.timeAndStadium),
                    _buildPillInput(initialValue: '${widget.slot['time']} - ${widget.selectedStadium?.name ?? "Stadium"}', enabled: false),
                    const SizedBox(height: 15),

                    _buildInputLabel(isArabic ? "مدة الحجز" : "Booking Duration"),
                    _buildDurationSelector(),
                    const SizedBox(height: 15),

                    _buildInputLabel(l10n.customerName),
                    _buildPillTextField(controller: _nameController, hint: l10n.enterNameHint),
                    const SizedBox(height: 15),

                    _buildInputLabel(l10n.phoneNumber),
                    _buildPillTextField(controller: _phoneController, hint: l10n.phoneOptionalHint),
                    const SizedBox(height: 15),

                    _buildInputLabel(l10n.internalNotes),
                    _buildPillTextField(controller: _noteController, hint: l10n.internalNotesHint),
                    const SizedBox(height: 15),

                    _buildInputLabel(isArabic ? "العربون" : "Deposit"),
                    _buildDepositToggleCard(),
                    const SizedBox(height: 20),

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
                                Text(l10n.paymentStatus, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text(_isManualDepositReceived ? (isArabic ? 'مدفوع جزئياً' : 'Partially Paid') : (isCompleted ? l10n.collectedStatusAuto : l10n.pendingStatusAuto), style: TextStyle(color: (isCompleted || _isManualDepositReceived) ? VSPColors.success : VSPColors.warning, fontSize: 11)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: (isCompleted || _isManualDepositReceived) ? VSPColors.success.withValues(alpha: 0.1) : VSPColors.warning.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(VSPRadius.sm),
                            ),
                            child: Text(
                              _isManualDepositReceived ? (isArabic ? 'مدفوع جزئياً' : 'Partially Paid') : (isCompleted ? l10n.collectedSticker : l10n.pendingSticker),
                              style: TextStyle(
                                color: (isCompleted || _isManualDepositReceived) ? VSPColors.success : VSPColors.warning,
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
                        l10n.cancelBtn,
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
                    text: widget.isEdit ? l10n.update : l10n.confirmBtn,
                    isLoading: _isSaving,
                    onPressed: _isSaving ? () {} : () async {
                      if (_nameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.enterCustomerNameError)));
                        return;
                      }

                      setState(() => _isSaving = true);

                      try {
                        final bookingProvider = Provider.of<BookingProvider>(widget.parentContext, listen: false);
                        
                        if (widget.isEdit) {
                          final success = await bookingProvider.updateManualBooking(
                            bookingId: booking!.id,
                            name: _nameController.text.trim(),
                            phone: PhoneUtils.normalize(_phoneController.text.trim()),
                            notes: _noteController.text.trim(),
                            isDepositPaid: _isManualDepositReceived,
                            depositPaid: _isManualDepositReceived ? (widget.selectedStadium?.depositAmount ?? 0.0) : 0.0,
                            paymentStatus: _isManualDepositReceived ? 'partially_paid' : 'unpaid',
                          );
                          if (!success) throw Exception("Failed to update booking");
                        } else {
                          final stadiumProvider = Provider.of<StadiumProvider>(widget.parentContext, listen: false);
                          final authProvider = Provider.of<AuthProvider>(widget.parentContext, listen: false);
                          final uid = authProvider.firebaseUser!.uid;
                          final stadium = stadiumProvider.stadiums.firstWhere((s) => s.id == widget.selectedStadium?.id, orElse: () => stadiumProvider.stadiums.first);

                          final selectedDate = widget.baseDate.add(Duration(days: widget.selectedDayIndex));
                          final startTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, widget.slot['hour'] as int, widget.slot['minute'] as int);
                          final endTime = startTime.add(Duration(minutes: _selectedMinutes));

                          // Overlap Validation
                          final startOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
                          final endOfDay = startOfDay.add(const Duration(days: 1));
                          final bookings = bookingProvider.userBookings.where((b) => 
                            b.stadiumId == stadium.id &&
                            b.status != BookingStatus.cancelled &&
                            !b.startTime.isBefore(startOfDay) && b.startTime.isBefore(endOfDay)
                          ).toList();

                          bool hasOverlap = false;
                          for (final b in bookings) {
                            if (startTime.isBefore(b.endTime) && endTime.isAfter(b.startTime)) {
                              hasOverlap = true;
                              break;
                            }
                          }
                          if (hasOverlap) {
                            throw Exception(isArabic 
                              ? "هذا الوقت متداخل مع حجز آخر نشط ⚠️" 
                              : "This time slot overlaps with another active booking ⚠️");
                          }

                          // Break overlap check
                          if (stadium.isSplitShift && stadium.breakStartTime != null && stadium.breakEndTime != null) {
                            var breakStartDt = _parseTimeToDateTime(selectedDate, stadium.breakStartTime);
                            var breakEndDt = _parseTimeToDateTime(selectedDate, stadium.breakEndTime);
                            if (breakEndDt.isBefore(breakStartDt)) {
                              breakEndDt = breakEndDt.add(const Duration(days: 1));
                            }
                            if (startTime.isBefore(breakEndDt) && endTime.isAfter(breakStartDt)) {
                              throw Exception(isArabic
                                  ? "لا يمكن الحجز خلال فترة الراحة للملعب ⚠️"
                                  : "Cannot book during stadium break time ⚠️");
                            }
                          }

                          // Working hours check
                          var openDt = _parseTimeToDateTime(selectedDate, stadium.openingTime);
                          var closeDt = _parseTimeToDateTime(selectedDate, stadium.closingTime);
                          if (closeDt.isBefore(openDt) || closeDt.isAtSameMomentAs(openDt)) {
                            closeDt = closeDt.add(const Duration(days: 1));
                          }
                          if (startTime.isBefore(openDt) || endTime.isAfter(closeDt)) {
                            throw Exception(isArabic
                                ? "وقت الحجز يقع خارج ساعات العمل الرسمية للملعب ⚠️"
                                : "Booking time falls outside stadium working hours ⚠️");
                          }

                          final totalPrice = stadium.pricePerHour * (_selectedMinutes / 60.0);

                          final draft = BookingDraft(
                            stadiumId: stadium.id, stadiumName: stadium.name, stadiumImageUrl: stadium.imageUrl,
                            ownerId: uid, startTime: startTime, endTime: endTime,
                            bookingType: BookingType.personal, playerTeamName: _nameController.text,
                            playerPhone: PhoneUtils.normalize(_phoneController.text), notes: _noteController.text,
                            isPrivate: true, rentBall: false,
                            totalPrice: totalPrice,
                            isPaid: false, 
                            isDepositPaid: _isManualDepositReceived,
                            depositPaid: _isManualDepositReceived ? stadium.depositAmount : 0.0,
                            paymentStatus: _isManualDepositReceived ? 'partially_paid' : 'unpaid',
                            paymentMethod: 'cash', paymentTransactionId: 'MANUAL_${DateTime.now().millisecondsSinceEpoch}',
                            needsDeposit: false,
                          );

                          await bookingProvider.createBooking(draft, uid);
                        }
                        
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        if (context.mounted) {
                          final cleanErr = e.toString().replaceAll('Exception:', '').trim();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(cleanErr)));
                        }
                      } finally {
                        if (mounted) setState(() => _isSaving = false);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
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
        style: const TextStyle(color: VSPColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildPillInput({required String initialValue, bool enabled = true}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: enabled ? VSPColors.background : VSPColors.surfaceAlt,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.divider, width: 0.5),
      ),
      child: Text(
        initialValue,
        style: TextStyle(
          color: enabled ? VSPColors.textPrimary : VSPColors.textSecondary,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: VSPColors.textSecondary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
