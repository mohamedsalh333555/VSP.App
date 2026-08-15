import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/repositories/booking_repository.dart';
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
    return DateTime(now.year, now.month, now.day);
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
        SupabaseBookingRepository().autoReconcilePastBookings(uid);
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
    if (timeStr == null || timeStr.isEmpty) return 16;
    try {
      final clean = timeStr.trim();
      final RegExp timeRegex = RegExp(r'(\d+)(?::(\d+))?\s*(AM|PM|ص|م)?', caseSensitive: false);
      final match = timeRegex.firstMatch(clean);
      if (match == null) return 16;
      int hour = int.parse(match.group(1)!);
      String? period = match.group(3)?.toUpperCase();
      if ((period == 'PM' || period == 'م') && hour != 12) hour += 12;
      if ((period == 'AM' || period == 'ص') && hour == 12) hour = 0;
      return hour;
    } catch (_) {
      return 16;
    }
  }

  int _parseTimeToMinutes(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return 0;
    try {
      final clean = timeStr.trim();
      final RegExp timeRegex = RegExp(r'(\d+)(?::(\d+))?\s*(AM|PM|ص|م)?', caseSensitive: false);
      final match = timeRegex.firstMatch(clean);
      if (match == null) return 0;
      int hour = int.parse(match.group(1)!);
      int minute = match.group(2) != null ? int.parse(match.group(2)!) : 0;
      String? period = match.group(3)?.toUpperCase();
      if ((period == 'PM' || period == 'م') && hour != 12) hour += 12;
      if ((period == 'AM' || period == 'ص') && hour == 12) hour = 0;
      return hour * 60 + minute;
    } catch (_) {
      return 0;
    }
  }

  String _formatHourMin(int h, int m, bool isArabic) {
    final hour = hour12(h);
    final period = isArabic ? (h >= 12 ? 'م' : 'ص') : (h >= 12 ? 'PM' : 'AM');
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
                icon: Icon(Localizations.localeOf(context).languageCode == 'ar' ? Iconsax.arrow_right_3_copy : Iconsax.arrow_left_2_copy, color: VSPColors.textPrimary),
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
                        Icon(Iconsax.calendar_1_copy, color: VSPColors.textSecondary, size: 16),
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
                    final bShiftDate = getShiftDate(b.startTime, startH);
                    return bShiftDate.year == selectedDateOnly.year &&
                           bShiftDate.month == selectedDateOnly.month &&
                           bShiftDate.day == selectedDateOnly.day;
                  }).toList();

                  final bool isArabicLocale = Localizations.localeOf(context).languageCode == 'ar';

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
                    // Compute end time label
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

                  return Column(
                    children: [
                      _buildOwnerFinancialSummaryBox(dayBookings, isArabicLocale),
                      Expanded(
                        child: ListView.separated(
                          controller: _scrollController,
                          padding: VSPScrollPadding.forList(context, hasFloatingNavBar: true, top: VSPSpacing.md, horizontal: VSPSpacing.md),
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: mergedSlots.length,
                          separatorBuilder: (c, i) => const SizedBox(height: VSPSpacing.md),
                          itemBuilder: (context, index) {
                            final slot = mergedSlots[index];
                            return _buildTimeSlotRow(slot, selectedStadium);
                          },
                        ),
                      ),
                    ],
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
      onTap: () {
        if (slot['type'] == 'empty') {
           _showBookingModal(isEdit: false, slot: slot, stadium: selectedStadium);
        } else if (slot['isManaged'] == true) {
           _showBookingModal(isEdit: true, slot: slot, stadium: selectedStadium);
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
                    '🌙 ${slot['nightLabel']}',
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
          Icon(Iconsax.arrow_right_3_copy, color: VSPColors.textSecondary, size: 14),
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
              onPrimary: Colors.black,
              surface: VSPColors.surface,
              onSurface: VSPColors.textPrimary,
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

  Widget _buildOwnerFinancialSummaryBox(List<Booking> dayBookings, bool isArabic) {
    double onlineCollected = 0.0;
    double pitchCashCollected = 0.0;
    double pendingCash = 0.0;

    for (final b in dayBookings) {
      if (b.status == BookingStatus.cancelled) continue;
      final double price = b.totalPrice;
      final double dep = b.depositPaid;
      final bool isCashMethod = b.paymentMethod == 'cash' || (b.paymentTransactionId?.startsWith('MANUAL') == true);

      if (!isCashMethod && (b.isPaid || b.paymentStatus == 'paid')) {
        onlineCollected += price;
      } else if (!isCashMethod && (b.isDepositPaid || dep > 0)) {
        onlineCollected += dep;
        if (price > dep) {
          pendingCash += (price - dep);
        }
      } else if (isCashMethod && (b.isPaid || b.paymentStatus == 'paid')) {
        pitchCashCollected += price;
      } else {
        pendingCash += price;
      }
    }

    final double totalDayRevenue = onlineCollected + pitchCashCollected + pendingCash;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3), width: 1.2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Iconsax.card_pos_copy, color: VSPColors.accent, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    isArabic ? 'الحصيلة المالية اليومية 💰' : 'Daily Financial Box 💰',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: VSPColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isArabic ? '${dayBookings.length} حجوزات' : '${dayBookings.length} Bookings',
                  style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 10.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildFinancialMetricTile(
                  title: isArabic ? 'أونلاين ⚡' : 'Online ⚡',
                  amount: '${onlineCollected.toInt()} ${isArabic ? "ج.م" : "EGP"}',
                  color: VSPColors.accent,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildFinancialMetricTile(
                  title: isArabic ? 'كاش بالملعب 💵' : 'Pitch Cash 💵',
                  amount: '${(pitchCashCollected + pendingCash).toInt()} ${isArabic ? "ج.م" : "EGP"}',
                  color: Colors.amber,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildFinancialMetricTile(
                  title: isArabic ? 'إجمالي اليوم 📊' : 'Total 📊',
                  amount: '${totalDayRevenue.toInt()} ${isArabic ? "ج.م" : "EGP"}',
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialMetricTile({
    required String title,
    required String amount,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: VSPColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 3),
          Text(
            amount,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

Future<void> showOwnerBookingModal({
  required BuildContext context,
  required bool isEdit,
  required Map<String, dynamic> slot,
  required Stadium selectedStadium,
  DateTime? baseDate,
  int? selectedDayIndex,
  required BuildContext parentContext,
}) {
  final now = DateTime.now();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (modalContext) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: _BookingSheetContent(
        isEdit: isEdit,
        slot: slot,
        selectedStadium: selectedStadium,
        baseDate: baseDate ?? now,
        selectedDayIndex: selectedDayIndex ?? 0,
        parentContext: parentContext,
      ),
    ),
  );
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
  int _playerCount = 1;

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
      _playerCount = booking.currentPlayers;
    }
    _collectedAmountController = TextEditingController(text: initialAmount == 0.0 ? '' : initialAmount.toStringAsFixed(0));

    if (widget.isEdit && booking != null) {
      _selectedMinutes = booking.endTime.difference(booking.startTime).inMinutes;
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
        final RegExp timeRegex = RegExp(r'(\d+)(?::(\d+))?\s*(AM|PM|ص|م)?', caseSensitive: false);
        final match = timeRegex.firstMatch(timeStr);
        if (match == null) return 0;
        int hour = int.parse(match.group(1)!);
        int minute = match.group(2) != null ? int.parse(match.group(2)!) : 0;
        String? period = match.group(3)?.toUpperCase();
        if ((period == 'PM' || period == 'م') && hour != 12) hour += 12;
        if ((period == 'AM' || period == 'ص') && hour == 12) hour = 0;
        return hour * 60 + minute;
      } catch (_) {
        return 0;
      }
    }
  }

  int _getMaxAvailableMinutes() {
    final stadium = widget.selectedStadium;
    final slotTime = widget.slot['slotTime'] as DateTime?;
    if (slotTime == null) return 720; // 12 hours max

    final int slotMin = slotTime.hour * 60 + slotTime.minute;
    int maxMins = 720;

    // 1. Closing time constraint
    final int closingMin = _parseTimeToMinutes(stadium.closingTime);
    final int openingMin = _parseTimeToMinutes(stadium.openingTime);
    if (openingMin != closingMin) {
      int minsToClosing;
      if (closingMin > slotMin) {
        minsToClosing = closingMin - slotMin;
      } else {
        minsToClosing = (closingMin + 24 * 60) - slotMin;
      }
      if (minsToClosing > 0 && minsToClosing < maxMins) {
        maxMins = minsToClosing;
      }
    }

    // 2. Break time constraint
    if (stadium.isSplitShift) {
      final int bStartMin = _parseTimeToMinutes(stadium.breakStartTime);
      final int bEndMin = _parseTimeToMinutes(stadium.breakEndTime);
      if (bStartMin != bEndMin) {
        int minsToBreak;
        if (bStartMin > slotMin) {
          minsToBreak = bStartMin - slotMin;
        } else {
          minsToBreak = (bStartMin + 24 * 60) - slotMin;
        }
        if (minsToBreak > 0 && minsToBreak < maxMins) {
          maxMins = minsToBreak;
        }
      }
    }

    // 3. Existing active bookings constraint
    try {
      final bookingProvider = Provider.of<BookingProvider>(widget.parentContext, listen: false);
      final bookings = bookingProvider.userBookings.where((b) {
        final bStartLocal = b.startTime.toLocal();
        return b.stadiumId.toLowerCase().trim() == stadium.id.toLowerCase().trim() &&
               b.status != BookingStatus.cancelled &&
               bStartLocal.year == slotTime.year &&
               bStartLocal.month == slotTime.month &&
               bStartLocal.day == slotTime.day;
      }).toList();

      for (final b in bookings) {
        if (widget.isEdit && b.id == (widget.slot['booking'] as Booking?)?.id) continue;
        final bStartLocal = b.startTime.toLocal();
        final int bStartMin = bStartLocal.hour * 60 + bStartLocal.minute;
        if (bStartMin > slotMin) {
          final minsToBooking = bStartMin - slotMin;
          if (minsToBooking < maxMins) {
            maxMins = minsToBooking;
          }
        }
      }
    } catch (_) {}

    return maxMins.clamp(30, 720);
  }

  Future<void> _launchWhatsAppSupport(Booking b, bool isArabic) async {
    final player = (b.playerTeamName != null && b.playerTeamName!.isNotEmpty) ? b.playerTeamName! : 'لاعب';
    final id = b.id;
    final dateStr = DateFormat('yyyy/MM/dd hh:mm a').format(b.startTime.toLocal());
    final msg = isArabic
        ? "مرحباً دعم VSP، أريد الإبلاغ عن صاحب الحجز (عدم حضور / مشكلة بالحجز).\nرقم الحجز: $id\nاسم صاحب الحجز: $player\nموعد الحجز: $dateStr"
        : "Hi VSP Support, I would like to report the booking holder (no-show / dispute).\nBooking ID: $id\nPlayer Name: $player\nSlot: $dateStr";
    final url = 'https://wa.me/201100229462?text=${Uri.encodeComponent(msg)}';
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch WhatsApp: $e');
    }
  }

  Future<void> _sendWhatsAppReceipt(Booking b, bool isArabic) async {
    final refCode = '#BK-${b.id.substring(0, b.id.length >= 6 ? 6 : b.id.length).toUpperCase()}';
    final customerName = (b.playerTeamName != null && b.playerTeamName!.isNotEmpty)
        ? b.playerTeamName!
        : (b.hostName != null && b.hostName!.isNotEmpty ? b.hostName! : (isArabic ? 'عميل VSP' : 'VSP Customer'));
    
    final stadiumName = b.stadiumName.isNotEmpty ? b.stadiumName : (isArabic ? 'ملعب VSP' : 'VSP Pitch');
    final dateStr = DateFormat('yyyy/MM/dd').format(b.startTime.toLocal());
    final startTimeStr = DateFormat('hh:mm a').format(b.startTime.toLocal());
    final endTimeStr = DateFormat('hh:mm a').format(b.endTime.toLocal());
    
    final totalPrice = b.totalPrice > 0 ? b.totalPrice : b.depositPaid;
    final depositPaid = b.depositPaid > 0 ? b.depositPaid : 0.0;
    final remainingCash = (totalPrice - depositPaid).clamp(0.0, 999999.0);

    final String receiptText = isArabic
        ? '''
📄 *وصل حجز إلكتروني رسمي - VSP Sports*
═════════════════════════
🏷️ *كود الحجز:* $refCode
👤 *اسم العميل:* $customerName
🏟️ *الملعب:* $stadiumName
📅 *التاريخ:* $dateStr
⏰ *التوقيت:* من $startTimeStr إلى $endTimeStr
💰 *إجمالي المبلغ:* ${totalPrice.toInt()} ج.م
💳 *العربون المدفوع أونلاين:* ${depositPaid.toInt()} ج.م
💵 *المتبقي كاش بالملعب:* ${remainingCash.toInt()} ج.م
═════════════════════════
📍 *موقع الملعب على الخريطة:*
https://maps.google.com/?q=${Uri.encodeComponent(stadiumName)}

نتمنى لكم مباراة ممتعة! ⚽🔥
'''
        : '''
📄 *Official Digital Booking Receipt - VSP Sports*
═════════════════════════
🏷️ *Booking Ref:* $refCode
👤 *Customer Name:* $customerName
🏟️ *Stadium:* $stadiumName
📅 *Date:* $dateStr
⏰ *Time:* $startTimeStr - $endTimeStr
💰 *Total Price:* ${totalPrice.toInt()} EGP
💳 *Deposit Paid Online:* ${depositPaid.toInt()} EGP
💵 *Remaining Cash Due:* ${remainingCash.toInt()} EGP
═════════════════════════
📍 *Location:*
https://maps.google.com/?q=${Uri.encodeComponent(stadiumName)}

Enjoy your match! ⚽🔥
''';

    final String whatsappUrl = 'https://wa.me/?text=${Uri.encodeComponent(receiptText)}';
    try {
      await launchUrl(Uri.parse(whatsappUrl), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) VSPFeedback.showError(context, 'تعذر فتح الواتساب: $e');
    }
  }

  void _updateDuration(int newMins) {
    setState(() {
      _selectedMinutes = newMins;
    });
  }

  String _formatDurationLabel(int mins, bool isArabic) {
    final double hours = mins / 60.0;
    if (hours == 0.5) return isArabic ? '30 دقيقة' : '30 Mins';
    if (hours == 1.0) return isArabic ? 'ساعة واحدة' : '1 Hour';
    if (hours == 1.5) return isArabic ? 'ساعة ونصف' : '1.5 Hours';
    if (hours == 2.0) return isArabic ? 'ساعتين' : '2 Hours';
    if (hours == 2.5) return isArabic ? 'ساعتين ونصف' : '2.5 Hours';
    if (hours == 3.0) return isArabic ? '3 ساعات' : '3 Hours';
    if (hours == 4.0) return isArabic ? '4 ساعات' : '4 Hours';
    if (hours.remainder(1.0) == 0) {
      return isArabic ? '${hours.toInt()} ساعات' : '${hours.toInt()} Hours';
    }
    return isArabic ? '${hours.toStringAsFixed(1)} ساعة' : '$hours Hours';
  }

  Widget _buildDurationSelector() {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final int maxMins = _getMaxAvailableMinutes();

    final allOptions = [
      {'label': isArabic ? 'ساعة' : '1 Hr', 'value': 60},
      {'label': isArabic ? 'ساعة ونصف' : '1.5 Hrs', 'value': 90},
      {'label': isArabic ? 'ساعتين' : '2 Hrs', 'value': 120},
      {'label': isArabic ? 'ساعتين ونصف' : '2.5 Hrs', 'value': 150},
      {'label': isArabic ? '3 ساعات' : '3 Hrs', 'value': 180},
      {'label': isArabic ? '4 ساعات' : '4 Hrs', 'value': 240},
    ];

    final booking = widget.slot['booking'] as Booking?;
    final bool isCompletedBooking = widget.isEdit && booking != null && (DateTime.now().isAfter(booking.endTime) || booking.status == BookingStatus.completed);

    final availableOptions = allOptions.where((opt) => (opt['value'] as int) <= maxMins).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Scrollable Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: availableOptions.map((opt) {
              final val = opt['value'] as int;
              final isSelected = _selectedMinutes == val;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(opt['label'] as String),
                  selected: isSelected,
                  onSelected: isCompletedBooking ? null : (_) {
                    _updateDuration(val);
                  },
                  selectedColor: VSPColors.accent,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : VSPColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  backgroundColor: VSPColors.surfaceAlt,
                  shape: const StadiumBorder(),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),

        // 2. Custom Duration Stepper (+ / - 30 mins)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isArabic ? 'مدة مخصصة:' : 'Custom Duration:',
              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
            ),
            Container(
              decoration: BoxDecoration(
                color: VSPColors.surfaceAlt,
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(color: VSPColors.divider, width: 0.5),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Iconsax.minus_cirlce_copy, size: 16, color: VSPColors.textPrimary),
                    onPressed: (isCompletedBooking || _selectedMinutes <= 30) ? null : () {
                      _updateDuration(_selectedMinutes - 30);
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      _formatDurationLabel(_selectedMinutes, isArabic),
                      style: const TextStyle(
                        color: VSPColors.accent,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Iconsax.add_circle_copy, size: 16, color: VSPColors.textPrimary),
                    onPressed: (isCompletedBooking || _selectedMinutes + 30 > maxMins) ? null : () {
                      _updateDuration(_selectedMinutes + 30);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),

        if (maxMins < 720) ...[
          const SizedBox(height: 6),
          Text(
            isArabic
                ? '⚠️ الحد الأقصى المتاح حتى الموعد القادم/الإغلاق: ${_formatDurationLabel(maxMins, isArabic)}'
                : '⚠️ Max available until next booking/closing: ${_formatDurationLabel(maxMins, isArabic)}',
            style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ],
    );
  }

  Future<void> _handleConfirmCashPayment(Booking booking, bool isArabic) async {
    setState(() => _isSaving = true);
    try {
      final parentCtx = widget.parentContext;
      final totalPrice = booking.totalPrice > 0 ? booking.totalPrice : widget.selectedStadium.basePrice;
      await Supabase.instance.client
          .from('bookings')
          .update({
            'is_paid': true,
            'payment_status': 'paid',
            'deposit_paid': totalPrice,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', booking.id);

      if (mounted) {
        VSPFeedback.showSuccess(
          context,
          isArabic ? 'تم تأكيد استلام المبلغ بالملعب واكتمال الحجز 💵' : 'Cash payment confirmed at pitch 💵',
        );
      }
      if (parentCtx.mounted) {
        final authProvider = Provider.of<AuthProvider>(parentCtx, listen: false);
        final uid = authProvider.currentUser?.uid ?? authProvider.firebaseUser?.uid;
        if (uid != null) {
          await Provider.of<BookingProvider>(parentCtx, listen: false).loadOwnerBookings(uid, forceRefresh: true);
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        VSPFeedback.showError(context, '${isArabic ? "تعذر تأكيد الدفع:" : "Failed to confirm cash:"} $e');
      }
    }
  }

  Future<void> _handleExtendOngoingMatch(Booking booking, bool isArabic) async {
    final parentCtx = widget.parentContext;
    final newEndTime = booking.endTime.add(const Duration(minutes: 30));

    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client
          .from('bookings')
          .update({
            'end_time': newEndTime.toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', booking.id);

      if (mounted) {
        VSPFeedback.showSuccess(
          context,
          isArabic ? 'تم تمديد المباراة 30 دقيقة إضافية بنجاح ⏱️' : 'Match extended by +30 mins ⏱️',
        );
      }
      if (parentCtx.mounted) {
        final authProvider = Provider.of<AuthProvider>(parentCtx, listen: false);
        final uid = authProvider.currentUser?.uid ?? authProvider.firebaseUser?.uid;
        if (uid != null) {
          await Provider.of<BookingProvider>(parentCtx, listen: false).loadOwnerBookings(uid, forceRefresh: true);
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        VSPFeedback.showError(context, '${isArabic ? "تعذر تمديد المباراة:" : "Failed to extend match:"} $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final booking = widget.slot['booking'] as Booking?;
    final now = DateTime.now();

    // 🏆 5-STATE MODAL LOGIC MATRIX EVALUATION
    final bool isEdit = widget.isEdit && booking != null;

    // STATE 1: PAST / COMPLETED
    final bool isPastCompleted = isEdit && (now.isAfter(booking.endTime) || booking.status == BookingStatus.completed);

    // Manual vs Online Classification
    final bool isManualBooking = isEdit && (booking.paymentTransactionId?.startsWith('MANUAL') == true || (booking.paymentMethod == 'cash' && booking.createdByUserId == booking.ownerId));
    final bool isOnlinePaid = isEdit && !isManualBooking && (booking.isPaid || booking.paymentStatus == 'paid');

    // STATE 2: UPCOMING ONLINE PAID
    final bool isUpcomingOnlinePaid = isEdit && isOnlinePaid && !isPastCompleted;

    // STATE 3: OWNER MANUAL BOOKING
    final bool isOwnerManual = isEdit && isManualBooking;

    // STATE 4: UPCOMING PENDING CASH FROM PLAYER
    final bool isUpcomingPendingCash = isEdit && !isOnlinePaid && !isPastCompleted && !isOwnerManual;

    // STATE 5: NEW EMPTY SLOT
    final bool isNewSlot = !widget.isEdit || booking == null;

    // Ongoing Active Match (+30m extension)
    final bool isOngoingActiveMatch = isEdit && !isPastCompleted && now.isAfter(booking.startTime) && now.isBefore(booking.endTime);

    // Read-Only Locking (Past matches & Online Paid matches protected from manual field edits)
    final bool isReadOnly = isPastCompleted || isUpcomingOnlinePaid;

    String modalTitle;
    if (isNewSlot) {
      modalTitle = l10n.manualBookingTitle;
    } else if (isPastCompleted) {
      modalTitle = isArabic ? 'تفاصيل الحجز (مكتمل)' : 'Booking Details (Completed)';
    } else if (isUpcomingOnlinePaid) {
      modalTitle = isArabic ? 'تفاصيل الحجز (أونلاين مؤكد ⚡)' : 'Booking Details (Online Paid ⚡)';
    } else if (isUpcomingPendingCash) {
      modalTitle = isArabic ? 'تفاصيل الحجز (كاش معلق 💵)' : 'Booking Details (Pending Cash 💵)';
    } else {
      modalTitle = isArabic ? 'تفاصيل الحجز اليدوي' : 'Manual Booking Details';
    }

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
                modalTitle,
                style: Theme.of(context).textTheme.displaySmall,
              ),
              if (isOwnerManual && !isPastCompleted || isUpcomingPendingCash)
                IconButton(
                  icon: const Icon(Iconsax.trash_copy, color: VSPColors.error),
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
                      if (!parentCtx.mounted) return;
                      final success = await Provider.of<BookingProvider>(parentCtx, listen: false).cancelBooking(booking.id);
                      if (!success) {
                        if (!context.mounted) return;
                        final err = Provider.of<BookingProvider>(context, listen: false).errorMessage;
                        VSPFeedback.showError(
                          context,
                          err ?? (isArabic ? 'عذراً، تعذر إلغاء الحجز ⚠️' : 'Failed to cancel booking ⚠️'),
                        );
                        return;
                      }
                      if (!parentCtx.mounted) return;
                      final uid = Provider.of<AuthProvider>(parentCtx, listen: false).currentUser?.uid;
                      if (uid != null) {
                        await Provider.of<BookingProvider>(parentCtx, listen: false).loadOwnerBookings(uid, forceRefresh: true);
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
                  // ⚡ TOP ACTIONS: Render ONLY for State 2 (Upcoming Online Paid)
                  if (isUpcomingOnlinePaid) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.amber,
                              side: const BorderSide(color: Colors.amber),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            icon: const Icon(Iconsax.clock_copy, size: 16),
                            label: Text(
                              isArabic ? 'ترحيل موعد 🔄' : 'Reschedule 🔄',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                            onPressed: () async {
                              final pickedDate = await showDatePicker(
                                context: context,
                                initialDate: booking.startTime.add(const Duration(days: 1)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 60)),
                              );
                              if (pickedDate == null || !context.mounted) return;
                              final pickedTime = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.fromDateTime(booking.startTime),
                              );
                              if (pickedTime == null || !context.mounted) return;
                              final newStart = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
                              final duration = booking.endTime.difference(booking.startTime);
                              final newEnd = newStart.add(duration);

                              final ok = await Provider.of<BookingProvider>(context, listen: false).requestReschedule(
                                bookingId: booking.id,
                                newStartTime: newStart,
                                newEndTime: newEnd,
                              );
                              if (ok && context.mounted) {
                                VSPFeedback.showSuccess(context, isArabic ? 'تم إرسال اقتراح الموعد الجديد للاعب بنجاح 🔄' : 'Reschedule proposal sent to player 🔄');
                                if (booking.playerPhone != null && booking.playerPhone!.isNotEmpty) {
                                  launchUrl(Uri.parse('tel:${booking.playerPhone}'));
                                }
                                Navigator.pop(context);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: VSPColors.error,
                              side: const BorderSide(color: VSPColors.error),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            icon: const Icon(Iconsax.danger_copy, size: 16),
                            label: Text(
                              isArabic ? 'إغلاق طارئ 🚨' : 'Emergency Close 🚨',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                            onPressed: () async {
                              final res = await Provider.of<BookingProvider>(context, listen: false).requestEmergencyClosure(
                                stadiumId: booking.stadiumId,
                                ownerId: booking.ownerId,
                                reason: 'عطل طارئ وصيانة بالملعب',
                                durationHours: 24,
                              );
                              if (context.mounted) {
                                if (res['success'] == true) {
                                  VSPFeedback.showSuccess(context, isArabic ? 'تم إغلاق الملعب مؤقتاً وتحويل طلبات الاسترداد للأدمن 🚨' : 'Stadium temporarily closed for emergency 🚨');
                                  Navigator.pop(context);
                                } else {
                                  VSPFeedback.showError(context, res['message'] ?? 'فشل طلب الإغلاق الطارئ');
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],

                  // ⏱️ LIVE ONGOING MATCH (+30m Extension Button)
                  if (isOngoingActiveMatch) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: VSPColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(VSPRadius.md),
                        border: Border.all(color: VSPColors.accent, width: 1.0),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Iconsax.timer_start_copy, color: VSPColors.accent, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                isArabic ? 'المباراة جارية الآن ⚽' : 'Match Ongoing Now ⚽',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: _isSaving ? null : () => _handleExtendOngoingMatch(booking, isArabic),
                            icon: const Icon(Iconsax.add_circle_copy, size: 14),
                            label: Text(
                              isArabic ? 'تمديد (+30د) ⏱️' : 'Extend (+30m) ⏱️',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: VSPColors.accent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  _buildInputLabel(l10n.timeAndStadium),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: VSPColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                      border: Border.all(color: VSPColors.divider, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Iconsax.clock_copy, color: VSPColors.accent, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.isEdit && booking != null
                                ? '${DateFormat('hh:mm a').format(booking.startTime.toLocal())} - ${DateFormat('EEEE').format(booking.startTime.toLocal())}'
                                : '${DateFormat('hh:mm a').format(widget.baseDate.add(Duration(days: widget.selectedDayIndex)).add(Duration(hours: widget.slot['hour'] as int, minutes: widget.slot['minute'] as int)))} - ${DateFormat('EEEE').format(widget.baseDate.add(Duration(days: widget.selectedDayIndex)))}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  _buildInputLabel(isArabic ? "مدة الحجز" : "Booking Duration"),
                  _buildDurationSelector(),
                  const SizedBox(height: 14),

                  _buildInputLabel(isArabic ? "عدد اللاعبين الحاضرين (تليفون / خارجي)" : "Joined Players Count"),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: VSPColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                      border: Border.all(color: VSPColors.divider, width: 0.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Iconsax.user_tag_copy, color: VSPColors.accent, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              isArabic ? "إجمالي اللاعبين:" : "Total Players:",
                              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Iconsax.minus_cirlce_copy, size: 20, color: VSPColors.textPrimary),
                              onPressed: (isReadOnly || _playerCount <= 1) ? null : () {
                                setState(() => _playerCount--);
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                '$_playerCount',
                                style: const TextStyle(
                                  color: VSPColors.accent,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Iconsax.add_circle_copy, size: 20, color: VSPColors.textPrimary),
                              onPressed: (isReadOnly || _playerCount >= (widget.selectedStadium.playersPerTeam * 2)) ? null : () {
                                setState(() => _playerCount++);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  _buildInputLabel(l10n.customerName),
                  _buildPillTextField(
                    controller: _nameController, 
                    hint: isArabic ? 'اسم الفريق / اللاعب' : 'Customer / Team Name',
                    keyboardType: TextInputType.name,
                    enabled: !isReadOnly,
                  ),
                  const SizedBox(height: 14),

                  _buildInputLabel(isArabic ? "رقم الهاتف" : "Phone Number"),
                  _buildPillTextField(
                    controller: _phoneController,
                    hint: isArabic ? "رقم الهاتف (اختياري)" : "Phone Number (Optional)",
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    enabled: !isReadOnly,
                  ),
                  const SizedBox(height: 14),

                  _buildInputLabel(l10n.internalNotes),
                  _buildPillTextField(
                    controller: _noteController, 
                    hint: isArabic ? 'أدخل أي ملاحظات إضافية عن الحجز...' : 'Enter internal notes...',
                    keyboardType: TextInputType.text,
                    enabled: !isReadOnly,
                  ),
                  const SizedBox(height: 14),

                  _buildInputLabel(isArabic ? "المبلغ المحصل (ج.م)" : "Collected Amount (EGP)"),
                  _buildPillTextField(
                    controller: _collectedAmountController,
                    hint: isArabic ? "أدخل المبلغ المحصل (0 للإيجار غير المدفوع)" : "Enter amount (0 for unpaid)",
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))],
                    enabled: !isReadOnly,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          
          // ===== STATE-SPECIFIC BOTTOM ACTIONS =====
          if (isPastCompleted) ...[
            // STATE 1: Past / Completed
            if (!booking.isPaid && booking.depositPaid < booking.totalPrice) ...[
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () => _launchWhatsAppSupport(booking, isArabic),
                  icon: const Icon(Iconsax.user_remove_copy, size: 16),
                  label: Text(
                    isArabic ? 'تسجيل عدم حضور اللاعب (No-Show) ⚠️' : 'Report Player No-Show ⚠️',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.withValues(alpha: 0.15),
                    foregroundColor: Colors.amber,
                    side: const BorderSide(color: Colors.amber, width: 1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                ...[
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () => _sendWhatsAppReceipt(booking, isArabic),
                        icon: const Icon(Iconsax.document_text_copy, size: 16),
                        label: Text(
                          isArabic ? 'إرسال الوصل 📄' : 'Send Receipt 📄',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.withValues(alpha: 0.15),
                          foregroundColor: Colors.green,
                          side: const BorderSide(color: Colors.green, width: 1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: PrimaryButton(
                      text: isArabic ? 'إغلاق ✖' : 'Close ✖',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (isUpcomingPendingCash) ...[
            // STATE 4: Upcoming Pending Cash From Player
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : () => _handleConfirmCashPayment(booking, isArabic),
                icon: const Icon(Iconsax.money_send_copy, size: 18),
                label: Text(
                  isArabic ? 'تأكيد استلام الكاش بالملعب 💵' : 'Confirm Cash Payment at Pitch 💵',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                  elevation: 2,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final phone = booking.playerPhone ?? '';
                        if (phone.isNotEmpty) {
                          launchUrl(Uri.parse('https://wa.me/${phone.replaceAll('+', '').replaceAll(' ', '')}'));
                        } else {
                          _launchWhatsAppSupport(booking, isArabic);
                        }
                      },
                      icon: const Icon(Iconsax.message_copy, size: 16),
                      label: Text(
                        isArabic ? 'تأكيد عبر واتساب 💬' : 'Confirm via WhatsApp 💬',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF38BDF8),
                        side: const BorderSide(color: Color(0xFF38BDF8)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
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
                          if (!parentCtx.mounted) return;
                          final success = await Provider.of<BookingProvider>(parentCtx, listen: false).cancelBooking(booking.id);
                          if (success && parentCtx.mounted) {
                            final uid = Provider.of<AuthProvider>(parentCtx, listen: false).currentUser?.uid;
                            if (uid != null) {
                              await Provider.of<BookingProvider>(parentCtx, listen: false).loadOwnerBookings(uid, forceRefresh: true);
                            }
                          }
                          if (mounted) nav.pop();
                        }
                      },
                      icon: const Icon(Iconsax.close_circle_copy, size: 16),
                      label: Text(
                        isArabic ? 'إلغاء الحجز ❌' : 'Cancel Slot ❌',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: VSPColors.error,
                        side: const BorderSide(color: VSPColors.error),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // STATE 2 (Upcoming Online Paid), STATE 3 (Owner Manual), STATE 5 (New Slot)
            if (isEdit) ...[
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () => _sendWhatsAppReceipt(booking, isArabic),
                  icon: const Icon(Iconsax.document_text_copy, size: 16),
                  label: Text(
                    isArabic ? 'إرسال وصل الحجز الإلكتروني 📄' : 'Send WhatsApp Digital Receipt 📄',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.withValues(alpha: 0.15),
                    foregroundColor: Colors.green,
                    side: const BorderSide(color: Colors.green, width: 1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: PrimaryButton(
                      text: (isEdit && isUpcomingOnlinePaid)
                          ? (isArabic ? 'إبلاغ الدعم (واتساب)' : 'Report Issue')
                          : l10n.cancelBtn,
                      color: VSPColors.surfaceAlt,
                      textColor: (isEdit && isUpcomingOnlinePaid) ? Colors.amber : VSPColors.textPrimary,
                      onPressed: _isSaving
                          ? null
                          : () {
                              if (isEdit && isUpcomingOnlinePaid) {
                                _launchWhatsAppSupport(booking, isArabic);
                              } else {
                                Navigator.pop(context);
                              }
                            },
                    ),
                  ),
                ),
                if (!isUpcomingOnlinePaid) ...[
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
              ],
            ),
          ],
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

        if (stadium.isSplitShift) {
          final int breakStartMin = _parseTimeToMinutes(stadium.breakStartTime);
          final int breakEndMin = _parseTimeToMinutes(stadium.breakEndTime);
          final int startMin = startTime.hour * 60 + startTime.minute;
          final int endMin = endTime.hour * 60 + endTime.minute;
          bool overlapsBreak = false;
          if (breakStartMin < breakEndMin) {
            overlapsBreak = (startMin < breakEndMin && endMin > breakStartMin);
          } else if (breakStartMin != breakEndMin) {
            overlapsBreak = (startMin >= breakStartMin || endMin > breakStartMin);
          }
          if (overlapsBreak) {
            throw Exception(isArabic ? "عذراً، هذا الموعد يتعارض مع فترة استراحة الملعب ⚠️" : "Booking overlaps with stadium break time ⚠️");
          }
        }

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
          currentPlayers: _playerCount,
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
      } else {
        // 🔄 UPDATE EXISTING BOOKING (DURATION EXTENSION / NOTES / PAYMENTS)
        final booking = widget.slot['booking'] as Booking?;
        if (booking != null) {
          final startTime = booking.startTime.toLocal();
          final endTime = startTime.add(Duration(minutes: _selectedMinutes));

          // Check overlap with OTHER active bookings for the same stadium
          final bookings = bookingProvider.userBookings.where((b) {
            final bStartLocal = b.startTime.toLocal();
            return b.id != booking.id &&
                   b.stadiumId.toLowerCase().trim() == stadium.id.toLowerCase().trim() &&
                   b.status != BookingStatus.cancelled &&
                   bStartLocal.year == startTime.year &&
                   bStartLocal.month == startTime.month &&
                   bStartLocal.day == startTime.day;
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
            throw Exception(isArabic ? "مدة الحجز المعدلة تتداخل مع حجز آخر نشط ⚠️" : "Updated duration overlaps with another active booking ⚠️");
          }

          final double calculatedPrice = stadium.pricePerHour * (_selectedMinutes / 60.0);
          final bool isManual = booking.paymentTransactionId?.contains('MANUAL') ?? false;
          final double finalTotal = isManual 
              ? (calculatedPrice > 0 ? calculatedPrice : booking.totalPrice) 
              : (calculatedPrice > booking.totalPrice ? calculatedPrice : booking.totalPrice);

          final updateMap = <String, dynamic>{
            'end_time': endTime.toUtc().toIso8601String(),
            'player_team_name': customerName,
            'notes': notes,
            'current_players': _playerCount,
            'deposit_paid': collectedAmount,
            'is_deposit_paid': collectedAmount > 0,
            'is_paid': collectedAmount >= finalTotal,
            'payment_status': collectedAmount >= finalTotal ? 'paid' : (collectedAmount > 0 ? 'partially_paid' : 'pending'),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          };

          if (customerPhone.isNotEmpty) {
            updateMap['player_phone'] = PhoneUtils.normalize(customerPhone);
          }

          if (finalTotal != booking.totalPrice) {
            updateMap['total_price'] = finalTotal;
          }

          await Supabase.instance.client
              .from('bookings')
              .update(updateMap)
              .eq('id', booking.id);

          await bookingProvider.loadOwnerBookings(uid);
        }
      }

      if (mounted) {
        final parentCtx = widget.parentContext;
        final nav = Navigator.of(context);
        nav.pop();
        if (parentCtx.mounted) {
          VSPFeedback.showSuccess(
            parentCtx,
            widget.isEdit
                ? (isArabic ? 'تم تحديث تفاصيل وزيادة مدة الحجز بنجاح ⚽' : 'Booking duration updated successfully')
                : (isArabic ? 'تم تأكيد الحجز اليدوي بنجاح ⚽' : 'Manual booking confirmed successfully'),
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
        if (!context.mounted) return;
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
    List<TextInputFormatter>? inputFormatters,
    bool enabled = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: VSPColors.surfaceAlt,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.divider, width: 1),
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: TextStyle(
          color: enabled ? Colors.white : VSPColors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
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