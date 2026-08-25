import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/providers/stadium_provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/vsp_empty_state.dart';
import '../../../data/models.dart';
import '../../../core/utils/app_date_formatter.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../widgets/owner_booking_sheet.dart';
import '../widgets/quick_phone_booking_modal.dart';
export '../widgets/owner_booking_sheet.dart';

/// شاشة جدول حجوزات المالك (Clean Full Height Slots Schedule)
class OwnerBookingsScreen extends StatefulWidget {
  const OwnerBookingsScreen({super.key});

  @override
  State<OwnerBookingsScreen> createState() => _OwnerBookingsScreenState();
}

class _OwnerBookingsScreenState extends State<OwnerBookingsScreen> {
  int _selectedDayIndex = 0; 
  Stadium? _selectedStadium;
  
  DateTime get _baseDate {
    final now = DateTime.now();
    try {
      final stadiumProvider = Provider.of<StadiumProvider>(context, listen: false);
      final selectedStadium = _getEffectiveStadium(stadiumProvider.stadiums);
      if (selectedStadium != null) {
        final int startH = _parseTimeToHour(selectedStadium.openingTime);
        final int endH = _parseTimeToHour(selectedStadium.closingTime);
        if (startH > endH && now.hour < endH) {
          final prev = now.subtract(const Duration(days: 1));
          return DateTime(prev.year, prev.month, prev.day);
        }
      }
    } catch (_) {}
    return AppDateFormatter.getOperationalDate(now);
  }

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
    return AppDateFormatter.parseTimeToHour(timeStr);
  }

  String _formatHourMin(int h, int m, bool isArabic) {
    return AppDateFormatter.formatHourMin(h, m, isArabic);
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
        automaticallyImplyLeading: false,
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
                          borderRadius: BorderRadius.circular(VSPRadius.lg),
                          border: Border.all(color: VSPColors.divider, width: 0.5),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<Stadium>(
                            value: effectiveValue,
                            dropdownColor: VSPColors.surface,
                            icon: const Icon(Iconsax.arrow_down_1_copy, color: VSPColors.accent, size: 16),
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
                        const Icon(Iconsax.calendar_1_copy, color: VSPColors.textSecondary, size: 16),
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
                    icon: Iconsax.building_copy,
                    title: l10n.stadiumsEmptyTitle,
                    subtitle: l10n.stadiumsEmptySubtitle,
                  );
                }

                DateTime getEffectiveOperationalBaseDate() {
                  final now = DateTime.now();
                  final int startH = _parseTimeToHour(selectedStadium.openingTime);
                  final int endH = _parseTimeToHour(selectedStadium.closingTime);
                  if (startH > endH && now.hour < endH) {
                    final prev = now.subtract(const Duration(days: 1));
                    return DateTime(prev.year, prev.month, prev.day);
                  }
                  return DateTime(now.year, now.month, now.day);
                }

                final baseDate = getEffectiveOperationalBaseDate();
                final selectedDate = baseDate.add(Duration(days: _selectedDayIndex));
                final selectedDateOnly = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
                final int startH = _parseTimeToHour(selectedStadium.openingTime);

                DateTime getShiftDate(DateTime dt, int openingHour) {
                  final local = dt.toLocal();
                  if (local.hour < openingHour && local.hour < 12) {
                    final prev = local.subtract(const Duration(days: 1));
                    return DateTime(prev.year, prev.month, prev.day);
                  }
                  return DateTime(local.year, local.month, local.day);
                }

                final dayBookings = bookingProvider.userBookings.where((b) {
                  if (b.stadiumId.toLowerCase().trim() != selectedStadium.id.toLowerCase().trim() ||
                      b.status == BookingStatus.cancelled) {
                    return false;
                  }
                  final bShiftDate = b.operationalDate ?? getShiftDate(b.startTime, startH);
                  return bShiftDate.year == selectedDateOnly.year &&
                      bShiftDate.month == selectedDateOnly.month &&
                      bShiftDate.day == selectedDateOnly.day;
                }).toList();

                List<Map<String, dynamic>> slots = [];
                try {
                  final int startH = _parseTimeToHour(selectedStadium.openingTime);
                  final int endH = _parseTimeToHour(selectedStadium.closingTime);
                  final int breakStartMin = selectedStadium.isSplitShift ? AppDateFormatter.parseTimeToMinutes(selectedStadium.breakStartTime) : -1;
                  final int breakEndMin = selectedStadium.isSplitShift ? AppDateFormatter.parseTimeToMinutes(selectedStadium.breakEndTime) : -1;
                  
                  int currentH = startH;
                  int currentM = 0;
                  int safeguard = 0;
                  bool is24h = (startH == endH && safeguard == 0);
                  
                  final isArSlot = Localizations.localeOf(context).languageCode == 'ar';
                  while (safeguard < 48) { 
                    final timeStr = _formatHourMin(currentH, currentM, isArSlot);
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
                    bool isOvernightSlot = (startH > endH && (currentH < startH || currentH < 12));
                    DateTime slotDate = selectedDate;
                    if (isOvernightSlot && currentH < 12) {
                      slotDate = selectedDate.add(const Duration(days: 1));
                    }
                    String dayNameStr = DateFormat('EEEE', isArSlot ? 'ar' : 'en').format(slotDate);
                    String nightLabel = isOvernightSlot ? (isArSlot ? 'سهرة $dayNameStr' : '$dayNameStr Night') : '';

                    final slotTime = DateTime(slotDate.year, slotDate.month, slotDate.day, currentH, currentM);
                    final currentSlotMin = currentH * 60 + currentM;

                    final booking = dayBookings.cast<Booking?>().firstWhere(
                      (b) {
                        if (b == null) return false;
                        final bStart = b.startTime.toLocal();
                        final bEnd = b.endTime.toLocal();
                        final bStartMin = bStart.hour * 60 + bStart.minute;
                        int bEndMin = bEnd.hour * 60 + bEnd.minute;
                        // Normalize for overnight bookings (crossing midnight)
                        if (bEndMin <= bStartMin) bEndMin += 1440;
                        // Normalize currentSlotMin for post-midnight slots
                        int normalizedSlotMin = currentSlotMin;
                        if (normalizedSlotMin < bStartMin && bEndMin > 1440) {
                          normalizedSlotMin += 1440;
                        }
                        return normalizedSlotMin >= bStartMin && normalizedSlotMin < bEndMin;
                      },
                      orElse: () => null,
                    );
                    if (isBreak) {
                      slots.add({'time': timeStr, 'hour': currentH, 'minute': currentM, 'type': 'break', 'slotTime': slotTime, 'nightLabel': nightLabel});
                    } else if (booking == null) {
                      slots.add({'time': timeStr, 'hour': currentH, 'minute': currentM, 'type': 'empty', 'slotTime': slotTime, 'nightLabel': nightLabel});
                    } else {
                      final bool isManual = booking.paymentTransactionId?.contains('MANUAL') ?? false;
                      slots.add({
                        'time': timeStr,
                        'hour': currentH,
                        'minute': currentM,
                        'type': isManual ? 'manual' : 'player',
                        'name': booking.playerTeamName ?? (isArSlot ? 'حجز يدوي' : 'Manual Booking'),
                        'booking': booking,
                        'isManaged': true,
                        'slotTime': slotTime,
                        'nightLabel': nightLabel,
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
                    icon: Iconsax.clock_copy,
                    title: l10n.noWorkingHoursTitle,
                    subtitle: l10n.noWorkingHoursSubtitle,
                  );
                }

                // Merge consecutive slots of the same booking into one card
                final List<Map<String, dynamic>> mergedSlots = [];
                int si = 0;
                while (si < slots.length) {
                  final slot = slots[si];
                  final booking = slot['booking'] as Booking?;
                  if (booking == null) {
                    if (slot['type'] == 'break') {
                      int sj = si + 1;
                      while (sj < slots.length && slots[sj]['type'] == 'break') {
                        sj++;
                      }
                      if (sj > si + 1) {
                        final lastSlot = slots[sj - 1];
                        final endSlotTime = (lastSlot['slotTime'] as DateTime?)?.add(const Duration(minutes: 30));
                        final endHour = endSlotTime?.hour ?? 0;
                        final endMin = endSlotTime?.minute ?? 0;
                        final endH12 = endHour == 0 ? 12 : (endHour > 12 ? endHour - 12 : endHour);
                        final isAr = Localizations.localeOf(context).languageCode == 'ar';
                        final endPeriod = isAr ? (endHour >= 12 ? 'م' : 'ص') : (endHour >= 12 ? 'PM' : 'AM');
                        final endTimeStr = '$endH12:${endMin.toString().padLeft(2, '0')} $endPeriod';
                        
                        mergedSlots.add({
                          ...slot,
                          'merged': true,
                          'slotCount': sj - si,
                          'endTimeStr': endTimeStr,
                        });
                        si = sj;
                        continue;
                      }
                    }
                    mergedSlots.add(slot);
                    si++;
                    continue;
                  }
                  // Find all consecutive slots with same booking id
                  int sj = si + 1;
                  while (sj < slots.length) {
                    final next = slots[sj];
                    final nextBooking = next['booking'] as Booking?;
                    if (nextBooking != null && nextBooking.id == booking.id) {
                      sj++;
                    } else {
                      break;
                    }
                  }
                  final durationMins = (sj - si) * 30;
                  final lastSlot = slots[sj - 1];
                  final endSlotTime = lastSlot['slotTime'] as DateTime?;
                  DateTime? endDisplayTime;
                  if (endSlotTime != null) {
                    endDisplayTime = endSlotTime.add(const Duration(minutes: 30));
                  }
                  final endHour = endDisplayTime?.hour ?? 0;
                  final endMin = endDisplayTime?.minute ?? 0;
                  final endH12 = endHour == 0 ? 12 : (endHour > 12 ? endHour - 12 : endHour);
                  final isAr = Localizations.localeOf(context).languageCode == 'ar';
                  final endPeriod = isAr ? (endHour >= 12 ? 'م' : 'ص') : (endHour >= 12 ? 'PM' : 'AM');
                  final endTimeStr = '$endH12:${endMin.toString().padLeft(2, '0')} $endPeriod';

                  String durationLabel;
                  if (isAr) {
                    if (durationMins == 60) { durationLabel = 'ساعة'; }
                    else if (durationMins == 90) { durationLabel = 'ساعة ونصف'; }
                    else if (durationMins == 120) { durationLabel = 'ساعتين'; }
                    else if (durationMins % 60 == 0) { durationLabel = '${durationMins ~/ 60} ساعات'; }
                    else { durationLabel = '${durationMins ~/ 60}س ${durationMins % 60}د'; }
                  } else {
                    if (durationMins == 60) { durationLabel = '1 hr'; }
                    else if (durationMins == 90) { durationLabel = '1.5 hr'; }
                    else if (durationMins % 60 == 0) { durationLabel = '${durationMins ~/ 60} hrs'; }
                    else { durationLabel = '${durationMins ~/ 60}h ${durationMins % 60}m'; }
                  }

                  mergedSlots.add({
                    ...slot,
                    'merged': true,
                    'slotCount': sj - si,
                    'durationMins': durationMins,
                    'durationLabel': durationLabel,
                    'endTimeStr': endTimeStr,
                  });
                  si = sj;
                }

                return ListView.separated(
                  controller: _scrollController,
                  padding: VSPScrollPadding.forList(context, hasFloatingNavBar: true, top: VSPSpacing.md, horizontal: VSPSpacing.md),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: mergedSlots.length,
                  separatorBuilder: (c, i) => const SizedBox(height: VSPSpacing.md),
                  itemBuilder: (context, index) {
                    final slot = mergedSlots[index];
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
    final bool isMerged = slot['merged'] == true;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        if (slot['type'] == 'empty') {
          final selectedDate = _baseDate.add(Duration(days: _selectedDayIndex));
          final startTime = (slot['slotTime'] as DateTime?) ?? DateTime(
            selectedDate.year, selectedDate.month, selectedDate.day,
            slot['hour'] as int, slot['minute'] as int,
          );
          final endTime = startTime.add(const Duration(minutes: 60));

          final booked = await QuickPhoneBookingModal.show(
            context,
            stadium: selectedStadium,
            date: selectedDate,
            slotTime: slot['time'] as String? ?? '08:00 PM - 09:00 PM',
            startTime: startTime,
            endTime: endTime,
            defaultPrice: selectedStadium.pricePerHour,
          );

          if (booked == true && mounted) {
            final auth = Provider.of<AuthProvider>(context, listen: false);
            final uid = auth.currentUser?.uid ?? auth.firebaseUser?.uid;
            if (uid != null) {
              final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
              await bookingProvider.loadOwnerBookings(uid, forceRefresh: true);
            }
          }
        } else if (slot['isManaged'] == true) {
          _showBookingModal(isEdit: true, slot: slot, stadium: selectedStadium);
        }
      },
      onLongPress: () async {
        if (slot['type'] == 'empty') {
          HapticFeedback.mediumImpact();
          final isAr = Localizations.localeOf(context).languageCode == 'ar';
          final auth = Provider.of<AuthProvider>(context, listen: false);
          final uid = auth.currentUser?.uid ?? auth.firebaseUser?.uid;
          if (uid == null) return;

          final selectedDate = _baseDate.add(Duration(days: _selectedDayIndex));
          final startTime = (slot['slotTime'] as DateTime?) ?? DateTime(
            selectedDate.year, selectedDate.month, selectedDate.day,
            slot['hour'] as int, slot['minute'] as int,
          );
          final endTime = startTime.add(const Duration(minutes: 60));

          final draft = BookingDraft(
            stadiumId: selectedStadium.id,
            stadiumName: selectedStadium.name,
            stadiumImageUrl: selectedStadium.imageUrl,
            ownerId: selectedStadium.ownerId.isNotEmpty ? selectedStadium.ownerId : uid,
            startTime: startTime,
            endTime: endTime,
            bookingType: BookingType.personal,
            playerTeamName: isAr ? 'حجز تليفوني سريع' : 'Quick Phone Booking',
            isPrivate: true,
            rentBall: false,
            totalPrice: selectedStadium.pricePerHour,
            paymentMethod: 'cash',
            paymentTransactionId: 'MANUAL_${DateTime.now().millisecondsSinceEpoch}',
            isPaid: false,
          );

          final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
          final created = await bookingProvider.createBooking(draft, uid);
          if (created != null && mounted) {
            VSPFeedback.showSuccess(
              context,
              isAr ? 'تم تثبيت الحجز التليفوني السريع بنجاح.' : 'Quick phone booking confirmed successfully.',
            );
            await bookingProvider.loadOwnerBookings(uid, forceRefresh: true);
          }
        }
      },
      child: Row(
        crossAxisAlignment: isMerged ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 75,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  slot['time'].replaceAll(' ', ''),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: VSPColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (isMerged) ...([
                  const SizedBox(height: 2),
                  Text(
                    slot['endTimeStr'] as String,
                    style: const TextStyle(
                      color: VSPColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ]),
                if ((slot['nightLabel'] as String?)?.isNotEmpty ?? false) ...([
                  const SizedBox(height: 2),
                  Text(
                    slot['nightLabel'] as String,
                    style: const TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                ]),
              ],
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
              ? (isAr ? 'الآن' : 'NOW')
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
              isBreak ? Iconsax.close_circle_copy : (isPast ? Iconsax.rotate_left_copy : Iconsax.add_circle_copy),
              color: isPast ? VSPColors.textSecondary.withValues(alpha: 0.5) : (isNowSlot ? VSPColors.accent : VSPColors.textSecondary),
              size: 22,
            ),
            const SizedBox(width: 12),
            Text(
              isBreak ? l10n.breakTime : (isAr ? 'متاح للحجز' : 'Available'),
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
    final bool isMerged = slot['merged'] == true;
    bool isManual = slot['type'] == 'manual';
    final bool isCompleted = booking != null && booking.endTime.isBefore(now);
    final String? durationLabel = slot['durationLabel'] as String?;

    return Container(
      height: isMerged ? null : 70,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: isMerged ? 14 : 0),
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
              isManual ? Iconsax.document_text_copy : Iconsax.cup_copy, 
              size: 22, 
              color: isManual ? Colors.blueAccent : VSPColors.accent,
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
                    if (durationLabel != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: VSPColors.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          durationLabel,
                          style: const TextStyle(
                            color: VSPColors.accent,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    if ((slot['subtitle'] as String?)?.isNotEmpty ?? false) ...[
                      Flexible(
                        child: Text(
                          slot['subtitle'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: VSPColors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
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
                            : 'Rem. ${remaining.toStringAsFixed(0)} EGP';
                        badgeColor = Colors.amber;
                      } else {
                        badgeLabel = isArabic ? 'غير مدفوع' : 'Unpaid';
                        badgeColor = VSPColors.warning;
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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
          const Icon(Iconsax.arrow_right_1_copy, color: VSPColors.textSecondary, size: 14),
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
      builder: (pickerCtx, child) {
        return Theme(
          data: Theme.of(pickerCtx).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: VSPColors.accent,
              onPrimary: Colors.black,
              surface: VSPColors.surface,
              onSurface: VSPColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      final difference = picked.difference(_baseDate).inDays;
      if (difference >= 0 && difference < 7) {
        setState(() => _selectedDayIndex = difference);
      }
    }
  }

  void _showBookingModal({required bool isEdit, required Map<String, dynamic> slot, required Stadium stadium}) {
    if (!isEdit) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final status = auth.userModel?.verificationStatus;
      final isUnderReview = status == 'pending' || status == 'under_review';
      final isRejected = status == 'rejected';

      if (isUnderReview || isRejected) {
        VSPFeedback.showError(
          context,
          Localizations.localeOf(context).languageCode == 'ar'
              ? 'عذراً، حسابك قيد المراجعة والتوثيق من قِبل إدارة التطبيق. لا يمكن إضافة حجز جديد حتى يتم الاعتماد والتفعيل!'
              : 'Sorry, your account is under review. Bookings are disabled until admin approval!',
        );
        return;
      }
    }

    showOwnerBookingModal(
      context: context,
      isEdit: isEdit,
      slot: slot,
      selectedStadium: stadium,
      baseDate: _baseDate,
      selectedDayIndex: _selectedDayIndex,
      parentContext: context,
    ).then((_) {
      if (mounted) setState(() {});
    });
  }
}
