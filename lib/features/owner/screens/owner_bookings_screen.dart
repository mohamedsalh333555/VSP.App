import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/providers/stadium_provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/vsp_empty_state.dart';
import '../../../data/models.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../shared/widgets/primary_button.dart';

class OwnerBookingsScreen extends StatefulWidget {
  const OwnerBookingsScreen({super.key});

  @override
  State<OwnerBookingsScreen> createState() => _OwnerBookingsScreenState();
}

class _OwnerBookingsScreenState extends State<OwnerBookingsScreen> {
  int _selectedDayIndex = 0; 
  Stadium? _selectedStadium;
  DateTime _baseDate = DateTime.now();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final uid = auth.currentUser?.uid ?? auth.firebaseUser?.uid;
      if (uid != null) {
        final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
        bookingProvider.loadOwnerBookings(uid);
        Provider.of<StadiumProvider>(context, listen: false).listenToOwnerStadiums(uid);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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

  int _parseTimeToMinutes(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return 0;
    try {
      final clean = timeStr.trim();
      final format = DateFormat('hh:mm a');
      final parsedTime = format.parse(clean);
      return parsedTime.hour * 60 + parsedTime.minute;
    } catch (e) {
      try {
        final RegExp timeRegex = RegExp(r'(\d+)(?::(\d+))?\s*(AM|PM)?', caseSensitive: false);
        final match = timeRegex.firstMatch(timeStr);
        if (match == null) return 0;
        int hour = int.parse(match.group(1)!);
        int minute = match.group(2) != null ? int.parse(match.group(2)!) : 0;
        String? period = match.group(3)?.toUpperCase();
        if (period == 'PM' && hour != 12) hour += 12;
        if (period == 'AM' && hour == 12) hour = 0;
        return hour * 60 + minute;
      } catch (_) {
        return 0;
      }
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

  Stadium? _getEffectiveStadium(List<Stadium> stadiums) {
    if (stadiums.isEmpty) return null;
    if (_selectedStadium != null && stadiums.any((s) => s.id == _selectedStadium!.id)) {
      return stadiums.firstWhere((s) => s.id == _selectedStadium!.id);
    }
    return stadiums.first;
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
                icon: Icon(LucideIcons.chevronLeft, color: VSPColors.textPrimary),
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
                      
                      Stadium? effectiveValue = _getEffectiveStadium(stadiums);

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
                            icon: Icon(LucideIcons.chevronDown, color: VSPColors.textSecondary, size: 18),
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
                        Icon(LucideIcons.calendar, color: VSPColors.textSecondary, size: 16),
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
                 final selectedStadium = _getEffectiveStadium(stadiums);

                 if (selectedStadium == null) {
                    return VSPEmptyState(
                      icon: LucideIcons.building,
                      title: l10n.stadiumsEmptyTitle,
                      subtitle: l10n.stadiumsEmptySubtitle,
                    );
                 }

                 final selectedDate = _baseDate.add(Duration(days: _selectedDayIndex));
                 
                 final dayBookings = bookingProvider.userBookings.where((b) {
                    final bStartLocal = b.startTime.toLocal();
                    return b.stadiumId.toLowerCase().trim() == selectedStadium.id.toLowerCase().trim() &&
                           b.status != BookingStatus.cancelled &&
                           bStartLocal.year == selectedDate.year &&
                           bStartLocal.month == selectedDate.month &&
                           bStartLocal.day == selectedDate.day;
                  }).toList();

                  List<Map<String, dynamic>> slots = [];
                  try {
                    final int startH = _parseTimeToHour(selectedStadium.openingTime);
                    final int endH = _parseTimeToHour(selectedStadium.closingTime);
                    final int breakStartMin = selectedStadium.isSplitShift ? _parseTimeToMinutes(selectedStadium.breakStartTime) : -1;
                    final int breakEndMin = selectedStadium.isSplitShift ? _parseTimeToMinutes(selectedStadium.breakEndTime) : -1;
                    
                    int currentH = startH;
                    int currentM = 0;
                    int safeguard = 0;
                    bool is24h = (startH == endH && safeguard == 0);
                    
                    while (safeguard < 48) { 
                      final timeStr = _formatHourMin(currentH, currentM);
                      if (safeguard > 0 && currentH == endH && currentM == 0 && !is24h) break;
                      
                      bool isBreak = false;
                      if (selectedStadium.isSplitShift && breakStartMin != -1 && breakEndMin != -1) {
                         final int currentSlotMin = currentH * 60 + currentM;
                         if (breakStartMin < breakEndMin) {
                           isBreak = currentSlotMin >= breakStartMin && currentSlotMin < breakEndMin;
                         } else {
                           isBreak = currentSlotMin >= breakStartMin || currentSlotMin < breakEndMin;
                         }
                      }

                      final slotTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, currentH, currentM);
                      final currentSlotMin = currentH * 60 + currentM;

                      final booking = dayBookings.cast<Booking?>().firstWhere(
                        (b) {
                          if (b == null) return false;
                          final bStart = b.startTime.toLocal();
                          final bEnd = b.endTime.toLocal();
                          final bStartMin = bStart.hour * 60 + bStart.minute;
                          final bEndMin = bEnd.hour * 60 + bEnd.minute;
                          return currentSlotMin >= bStartMin && currentSlotMin < bEndMin;
                        },
                        orElse: () => null,
                      );

                      final now = DateTime.now();
                      final bool isToday = _selectedDayIndex == 0;
                      final bool isMoreThan10MinsPast = isToday && now.isAfter(slotTime.add(const Duration(minutes: 10)));

                      if (isBreak) {
                        if (!isMoreThan10MinsPast) {
                          slots.add({'time': timeStr, 'hour': currentH, 'minute': currentM, 'type': 'break', 'slotTime': slotTime});
                        }
                      } else if (booking == null) {
                        if (!isMoreThan10MinsPast) {
                          slots.add({'time': timeStr, 'hour': currentH, 'minute': currentM, 'type': 'empty', 'slotTime': slotTime});
                        }
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
                          'slotTime': slotTime,
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
                      icon: LucideIcons.clock,
                      title: l10n.noWorkingHoursTitle,
                      subtitle: l10n.noWorkingHoursSubtitle,
                    );
                  }

                  return ListView.separated(
                    controller: _scrollController,
                    padding: VSPScrollPadding.forList(context, hasFloatingNavBar: true, top: VSPSpacing.md, horizontal: VSPSpacing.md),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: slots.length,
                    separatorBuilder: (c, i) => const SizedBox(height: VSPSpacing.md),
                    itemBuilder: (context, index) {
                      final slot = slots[index];
                      return _buildTimeSlotRow(slot, selectedStadium);
                    },
                  );
               },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSlotRow(Map<String, dynamic> slot, Stadium selectedStadium) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (slot['type'] == 'empty') {
           _showBookingModal(isEdit: false, slot: slot, stadium: selectedStadium);
        } else if (slot['isManaged'] == true) {
           _showBookingModal(isEdit: true, slot: slot, stadium: selectedStadium);
        }
      },
      child: Row(
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
            child: _buildSlotCard(slot),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotCard(Map<String, dynamic> slot) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final now = DateTime.now();
    final DateTime? slotTime = slot['slotTime'] as DateTime?;
    final bool isToday = _selectedDayIndex == 0;
    final bool isPast = isToday && slotTime != null && slotTime.isBefore(now.subtract(const Duration(minutes: 30)));
    final bool isNowSlot = isToday && slotTime != null &&
        slotTime.isAfter(now.subtract(const Duration(minutes: 30))) &&
        slotTime.isBefore(now.add(const Duration(minutes: 30)));

    if (slot['type'] == 'empty' || slot['type'] == 'break') {
      final bool isBreak = slot['type'] == 'break';
      final Color badgeColor = isBreak
          ? VSPColors.textSecondary
          : (isNowSlot
              ? VSPColors.accent
              : (isPast ? VSPColors.textSecondary.withValues(alpha: 0.5) : VSPColors.accent));

      final String badgeText = isBreak
          ? l10n.closedBadge
          : (isNowSlot
              ? (isAr ? '⚡ الآن' : '⚡ NOW')
              : (isPast ? (isAr ? 'منقضي' : 'Past') : l10n.openBadge));

      return Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isNowSlot ? VSPColors.accent.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(VSPRadius.md),
          border: Border.all(
            color: isNowSlot ? VSPColors.accent.withValues(alpha: 0.5) : (isPast ? VSPColors.divider.withValues(alpha: 0.3) : VSPColors.divider),
            width: isNowSlot ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isBreak ? LucideIcons.ban : (isPast ? LucideIcons.history : LucideIcons.plusCircle),
              color: isPast ? VSPColors.textSecondary.withValues(alpha: 0.5) : (isNowSlot ? VSPColors.accent : VSPColors.textSecondary),
              size: 22,
            ),
            const SizedBox(width: 12),
            Text(
              isBreak ? l10n.breakTime : l10n.addManualBooking,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isPast ? VSPColors.textSecondary.withValues(alpha: 0.5) : VSPColors.textSecondary,
                fontWeight: isNowSlot ? FontWeight.bold : FontWeight.w600,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: isPast ? 0.08 : 0.15),
                borderRadius: BorderRadius.circular(VSPRadius.sm),
                border: isNowSlot ? Border.all(color: VSPColors.accent.withValues(alpha: 0.4)) : null,
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  color: badgeColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    final booking = slot['booking'] as Booking?;
    bool isManual = slot['isManual'] ?? false;
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
              isManual ? LucideIcons.fileSignature : LucideIcons.trophy, 
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
                    Builder(builder: (context) {
                      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
                      final String paymentStatus = booking?.paymentStatus ?? 'pending';
                      final double depositPaid = booking?.depositPaid ?? 0.0;
                      final double totalPrice = booking?.totalPrice ?? 0.0;
                      final bool isPaidInFull = (booking?.isPaid ?? false) || paymentStatus == 'paid' || (totalPrice > 0 && depositPaid >= totalPrice);
                      final bool isPartiallyPaid = !isPaidInFull && (paymentStatus == 'partially_paid' || (booking?.isDepositPaid ?? false) || depositPaid > 0);

                      final double remaining = totalPrice - depositPaid;
                      final String badgeLabel;
                      final Color badgeColor;
                      if (isPaidInFull) {
                        badgeLabel = isArabic ? 'تم الدفع' : 'Paid';
                        badgeColor = VSPColors.success;
                      } else if (isCompleted) {
                        badgeLabel = isArabic ? 'محصل' : 'Collected';
                        badgeColor = VSPColors.success;
                      } else if (isPartiallyPaid) {
                        badgeLabel = isArabic 
                            ? 'متبقي ${remaining.toStringAsFixed(0)} ج.م' 
                            : 'Remaining ${remaining.toStringAsFixed(0)} EGP';
                        badgeColor = Colors.amber;
                      } else {
                        badgeLabel = isArabic ? 'غير مدفوع' : 'Unpaid';
                        badgeColor = VSPColors.warning;
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badgeLabel,
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
          
          Builder(builder: (context) {
            final isArabic = Localizations.localeOf(context).languageCode == 'ar';
            final double rawPrice = booking?.totalPrice ?? 0.0;
            final double rawDeposit = booking?.depositPaid ?? 0.0;
            final double cardPrice = rawPrice > 0 ? rawPrice : (rawDeposit > 0 ? rawDeposit : 0.0);

            if (cardPrice <= 0) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '${cardPrice.toInt()} ${isArabic ? "ج.م" : "EGP"}',
                style: const TextStyle(
                  color: VSPColors.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            );
          }),
          Icon(LucideIcons.chevronRight, color: VSPColors.textSecondary, size: 14),
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
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final difference = picked.difference(_baseDate).inDays;
      if (difference >= 0 && difference < 7) {
        setState(() => _selectedDayIndex = difference);
      }
    }
  }

  void _showBookingModal({required bool isEdit, required Map<String, dynamic> slot, required Stadium stadium}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: _BookingSheetContent(
          isEdit: isEdit,
          slot: slot,
          selectedStadium: stadium,
          baseDate: _baseDate,
          selectedDayIndex: _selectedDayIndex,
          parentContext: context,
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }
}

class _BookingSheetContent extends StatefulWidget {
  final bool isEdit;
  final Map<String, dynamic> slot;
  final Stadium selectedStadium;
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
  late final TextEditingController _collectedAmountController;
  bool _isSaving = false;
  bool _isDeleting = false;
  int _selectedMinutes = 60;

  @override
  void initState() {
    super.initState();
    final booking = widget.slot['booking'] as Booking?;
    _nameController = TextEditingController(text: widget.isEdit ? (widget.slot['name'] ?? '') : '');
    _phoneController = TextEditingController(text: widget.isEdit ? (booking?.playerPhone ?? '') : '');
    _noteController = TextEditingController(text: widget.isEdit ? (booking?.notes ?? '') : '');

    double initialAmount = 0.0;
    if (widget.isEdit && booking != null) {
      initialAmount = booking.depositPaid > 0 ? booking.depositPaid : (booking.isPaid ? booking.totalPrice : 0.0);
    } else if (widget.selectedStadium.needsDeposit) {
      initialAmount = widget.selectedStadium.depositAmount;
    }
    _collectedAmountController = TextEditingController(text: initialAmount == 0.0 ? '' : initialAmount.toStringAsFixed(0));

    if (widget.isEdit && booking != null) {
      _selectedMinutes = booking.endTime.difference(booking.startTime).inMinutes;
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final booking = widget.slot['booking'] as Booking?;
    final stadium = widget.selectedStadium;

    final double systemBottomPadding = MediaQuery.of(context).padding.bottom;
    final double keyboardPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.fromLTRB(
        VSPSpacing.md,
        VSPSpacing.md,
        VSPSpacing.md,
        systemBottomPadding + keyboardPadding + 16,
      ),
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
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: VSPColors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
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
                  icon: const Icon(LucideIcons.trash2, color: VSPColors.error),
                  onPressed: _isDeleting ? null : () async {
                    final parentCtx = widget.parentContext;
                    final nav = Navigator.of(context);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: VSPColors.surface,
                        title: Text(l10n.cancelBooking),
                        content: Text(l10n.cancelBookingConfirm),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancelBtn)),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(l10n.confirmBtn, style: const TextStyle(color: VSPColors.error)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && mounted) {
                      setState(() => _isDeleting = true);
                      if (parentCtx.mounted) {
                        final success = await Provider.of<BookingProvider>(parentCtx, listen: false).cancelBooking(booking!.id);
                        if (!success) {
                          if (mounted) {
                            final err = Provider.of<BookingProvider>(parentCtx, listen: false).errorMessage;
                            VSPFeedback.showError(
                              context,
                              err ?? (isArabic ? 'عذراً، تعذر إلغاء الحجز ⚠️' : 'Failed to cancel booking ⚠️'),
                            );
                          }
                          return;
                        }
                        final uid = Provider.of<AuthProvider>(parentCtx, listen: false).currentUser?.uid;
                        if (uid != null) {
                          await Provider.of<BookingProvider>(parentCtx, listen: false).loadOwnerBookings(uid);
                        }
                      }
                      if (mounted) nav.pop();
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInputLabel(l10n.timeAndStadium),
                  _buildPillInput(
                    initialValue: '${widget.slot['time']} - ${stadium.name}',
                    enabled: false,
                  ),
                  const SizedBox(height: 14),

                  _buildInputLabel(isArabic ? "مدة الحجز" : "Booking Duration"),
                  _buildDurationSelector(),
                  const SizedBox(height: 14),

                  _buildInputLabel(l10n.customerName),
                  _buildPillTextField(
                    controller: _nameController, 
                    hint: isArabic ? 'أدخل اسم العميل' : 'Enter customer name',
                    keyboardType: TextInputType.name,
                  ),
                  const SizedBox(height: 14),

                  _buildInputLabel(l10n.phoneNumber),
                  _buildPillTextField(
                    controller: _phoneController,
                    hint: isArabic ? 'رقم الهاتف (اختياري)' : 'Phone Number (Optional)',
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 14),

                  _buildInputLabel(l10n.internalNotes),
                  _buildPillTextField(
                    controller: _noteController, 
                    hint: isArabic ? 'أدخل أي ملاحظات إضافية عن الحجز...' : 'Enter internal notes...',
                    keyboardType: TextInputType.text,
                  ),
                  const SizedBox(height: 14),

                  _buildInputLabel(isArabic ? "المبلغ المحصل (ج.م)" : "Collected Amount (EGP)"),
                  _buildPillTextField(
                    controller: _collectedAmountController,
                    hint: isArabic ? "أدخل المبلغ المحصل (0 للإيجار غير المدفوع)" : "Enter amount (0 for unpaid)",
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VSPColors.surfaceAlt,
                      foregroundColor: VSPColors.textPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                    ),
                    child: Text(
                      l10n.cancelBtn,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: PrimaryButton(
                    text: widget.isEdit ? l10n.update : l10n.confirmBtn,
                    isLoading: _isSaving,
                    onPressed: _isSaving ? null : () => _handleConfirmBooking(l10n, isArabic),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleConfirmBooking(AppLocalizations l10n, bool isArabic) async {
    final String customerName = _nameController.text.trim().isNotEmpty 
        ? _nameController.text.trim() 
        : (isArabic ? 'حجز يدوي' : 'Manual Booking');

    setState(() => _isSaving = true);

    try {
      final bookingProvider = Provider.of<BookingProvider>(widget.parentContext, listen: false);
      final authProvider = Provider.of<AuthProvider>(widget.parentContext, listen: false);
      
      final uid = authProvider.currentUser?.uid ?? authProvider.firebaseUser?.uid;
      if (uid == null) {
        throw Exception(isArabic ? 'انتهت الجلسة، يرجى إعادة تسجيل الدخول' : 'Session expired');
      }

      final stadium = widget.selectedStadium;
      final customerPhone = _phoneController.text.trim();
      final notes = _noteController.text.trim();
      final double collectedAmount = double.tryParse(_collectedAmountController.text.trim()) ?? 0.0;

      if (!widget.isEdit) {
        final selectedDate = widget.baseDate.add(Duration(days: widget.selectedDayIndex));
        final startTime = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          widget.slot['hour'] as int,
          widget.slot['minute'] as int,
        );
        final endTime = startTime.add(Duration(minutes: _selectedMinutes));

        final bookings = bookingProvider.userBookings.where((b) {
          final bStartLocal = b.startTime.toLocal();
          return b.stadiumId.toLowerCase().trim() == stadium.id.toLowerCase().trim() &&
                 b.status != BookingStatus.cancelled &&
                 bStartLocal.year == selectedDate.year &&
                 bStartLocal.month == selectedDate.month &&
                 bStartLocal.day == selectedDate.day;
        }).toList();

        bool hasOverlap = false;
        for (final b in bookings) {
          final bStartLocal = b.startTime.toLocal();
          final bEndLocal = b.endTime.toLocal();
          if (startTime.isBefore(bEndLocal) && endTime.isAfter(bStartLocal)) {
            hasOverlap = true;
            break;
          }
        }
        if (hasOverlap) {
          throw Exception(isArabic ? "هذا الوقت متداخل مع حجز آخر نشط ⚠️" : "Time slot overlaps with another booking ⚠️");
        }

        final double calculatedPrice = stadium.pricePerHour * (_selectedMinutes / 60.0);
        final double totalPrice = calculatedPrice > 0 ? calculatedPrice : (collectedAmount > 0 ? collectedAmount : stadium.basePrice);

        final draft = BookingDraft(
          stadiumId: stadium.id,
          stadiumName: stadium.name,
          stadiumImageUrl: stadium.imageUrl,
          ownerId: stadium.ownerId.isNotEmpty ? stadium.ownerId : uid,
          startTime: startTime,
          endTime: endTime,
          bookingType: BookingType.personal,
          playerTeamName: customerName,
          playerPhone: customerPhone.isNotEmpty ? PhoneUtils.normalize(customerPhone) : '',
          notes: notes,
          isPrivate: true,
          rentBall: false,
          totalPrice: totalPrice,
          isPaid: collectedAmount >= totalPrice,
          depositPaid: collectedAmount,
          isDepositPaid: collectedAmount > 0,
          paymentStatus: collectedAmount >= totalPrice ? 'paid' : (collectedAmount > 0 ? 'partially_paid' : 'pending'),
          paymentMethod: 'cash',
          paymentTransactionId: 'MANUAL_${DateTime.now().millisecondsSinceEpoch}',
          needsDeposit: false,
        );

        final createdBooking = await bookingProvider.createBooking(draft, uid);
        if (createdBooking == null) {
          final errMsg = bookingProvider.errorMessage ?? (isArabic ? 'عذراً، فشل حفظ الحجز في قاعدة البيانات' : 'Failed to save booking');
          throw Exception(errMsg);
        }
        await bookingProvider.loadOwnerBookings(uid);
      }

      if (mounted) {
        final parentCtx = widget.parentContext;
        final nav = Navigator.of(context);
        nav.pop();
        if (parentCtx.mounted) {
          VSPFeedback.showSuccess(
            parentCtx,
            isArabic ? 'تم تأكيد الحجز اليدوي بنجاح ⚽' : 'Manual booking confirmed successfully',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        String cleanErr = e.toString();
        final lower = cleanErr.toLowerCase();
        if (lower.contains('prevent_double_booking') || lower.contains('duplicate key value')) {
          cleanErr = isArabic ? '⚠️ هذا الموعد محجوز بالفعل على الملعب! يرجى اختيار موعد آخر.' : '⚠️ Time slot is already booked on this stadium!';
        } else if (lower.contains('overlap')) {
          cleanErr = isArabic ? '⚠️ مدة الحجز تتداخل مع حجز آخر نشط على الملعب! يرجى تقليل المدة أو اختيار موعد آخر.' : '⚠️ Booking duration overlaps with another active booking!';
        } else {
          cleanErr = cleanErr.replaceAll('Exception:', '').replaceAll('PostgrestException', '').replaceAll('(message:', '').replaceAll('Failed to create booking:', '').trim();
        }
        final targetCtx = widget.parentContext.mounted ? widget.parentContext : context;
        VSPFeedback.showError(targetCtx, cleanErr);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildPillTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: VSPColors.background,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.divider, width: 0.5),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
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