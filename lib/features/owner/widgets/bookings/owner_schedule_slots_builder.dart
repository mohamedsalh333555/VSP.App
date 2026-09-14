import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../../core/services/vsp_time_service.dart';
import '../../../../core/utils/app_date_formatter.dart';
import '../../../../data/models.dart';

/// Calculation engine for pitch schedule slots, handling split shifts, overnight bookings,
/// operational day boundary calculation, and slot merging.
class OwnerScheduleSlotsBuilder {
  static DateTime getOperationalBaseDate(Stadium? selectedStadium, BuildContext context) {
    final now = VSPTimeService.now;
    if (selectedStadium != null) {
      final int startH = AppDateFormatter.parseTimeToHour(selectedStadium.openingTime);
      final int endH = AppDateFormatter.parseTimeToHour(selectedStadium.closingTime);
      if (startH > endH && now.hour < endH) {
        final prev = now.subtract(const Duration(days: 1));
        return DateTime(prev.year, prev.month, prev.day);
      }
    }
    return AppDateFormatter.getOperationalDate(now);
  }

  static DateTime getShiftDate(DateTime dt, int openingHour) {
    final local = dt.toLocal();
    if (local.hour < openingHour && local.hour < 12) {
      final prev = local.subtract(const Duration(days: 1));
      return DateTime(prev.year, prev.month, prev.day);
    }
    return DateTime(local.year, local.month, local.day);
  }

  static List<Map<String, dynamic>> generateRawSlots({
    required Stadium selectedStadium,
    required DateTime selectedDate,
    required List<Booking> dayBookings,
    required BuildContext context,
  }) {
    List<Map<String, dynamic>> slots = [];
    try {
      final int startH = AppDateFormatter.parseTimeToHour(selectedStadium.openingTime);
      final int endH = AppDateFormatter.parseTimeToHour(selectedStadium.closingTime);
      final int breakStartMin = selectedStadium.isSplitShift
          ? AppDateFormatter.parseTimeToMinutes(selectedStadium.breakStartTime)
          : -1;
      final int breakEndMin = selectedStadium.isSplitShift
          ? AppDateFormatter.parseTimeToMinutes(selectedStadium.breakEndTime)
          : -1;

      int currentH = startH;
      int currentM = 0;
      int safeguard = 0;
      bool is24h = (startH == endH && safeguard == 0);

      final isArSlot = Localizations.localeOf(context).languageCode == 'ar';
      while (safeguard < 48) {
        final timeStr = AppDateFormatter.formatHourMin(currentH, currentM, isArSlot);
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
          slots.add({
            'time': timeStr,
            'hour': currentH,
            'minute': currentM,
            'type': 'break',
            'slotTime': slotTime,
            'nightLabel': nightLabel,
          });
        } else if (booking == null) {
          slots.add({
            'time': timeStr,
            'hour': currentH,
            'minute': currentM,
            'type': 'empty',
            'slotTime': slotTime,
            'nightLabel': nightLabel,
          });
        } else {
          final bool isManual = booking.paymentTransactionId?.contains('MANUAL') ?? false;
          slots.add({
            'time': timeStr,
            'hour': currentH,
            'minute': currentM,
            'type': isManual ? 'manual' : 'player',
            'name': (booking.playerTeamName?.trim().isNotEmpty == true
                    ? booking.playerTeamName
                    : (booking.hostName?.trim().isNotEmpty == true ? booking.hostName : null)) ??
                (isArSlot ? 'حجز يدوي' : 'Manual Booking'),
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
    } catch (_) {
      slots.clear();
    }
    return slots;
  }

  static List<Map<String, dynamic>> mergeConsecutiveSlots(
    List<Map<String, dynamic>> slots,
    BuildContext context,
  ) {
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
        if (durationMins == 60) {
          durationLabel = 'ساعة';
        } else if (durationMins == 90) {
          durationLabel = 'ساعة ونصف';
        } else if (durationMins == 120) {
          durationLabel = 'ساعتين';
        } else if (durationMins % 60 == 0) {
          durationLabel = '${durationMins ~/ 60} ساعات';
        } else {
          durationLabel = '${durationMins ~/ 60}س ${durationMins % 60}د';
        }
      } else {
        if (durationMins == 60) {
          durationLabel = '1 hr';
        } else if (durationMins == 90) {
          durationLabel = '1.5 hr';
        } else if (durationMins % 60 == 0) {
          durationLabel = '${durationMins ~/ 60} hrs';
        } else {
          durationLabel = '${durationMins ~/ 60}h ${durationMins % 60}m';
        }
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

    return mergedSlots;
  }
}
