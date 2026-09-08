import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/providers/stadium_provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/app_date_formatter.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../data/models.dart';
import '../../../shared/widgets/vsp_back_button.dart';
import '../../../shared/widgets/vsp_empty_state.dart';
import '../widgets/bookings/owner_bookings_filter_bar.dart';
import '../widgets/bookings/owner_schedule_slots_builder.dart';
import '../widgets/bookings/owner_time_slot_row.dart';
import '../widgets/owner_booking_sheet.dart';
export '../widgets/owner_booking_sheet.dart';

/// Pitch schedule and booking management screen for stadium owners.
/// Displays operational time slots, supports quick phone bookings, and manages roster states.
class OwnerBookingsScreen extends StatefulWidget {
  const OwnerBookingsScreen({super.key});

  @override
  State<OwnerBookingsScreen> createState() => _OwnerBookingsScreenState();
}

class _OwnerBookingsScreenState extends State<OwnerBookingsScreen> {
  int _selectedDayIndex = 0;
  Stadium? _selectedStadium;
  final ScrollController _scrollController = ScrollController();

  DateTime get _baseDate {
    try {
      final stadiumProvider = Provider.of<StadiumProvider>(context, listen: false);
      final selectedStadium = _getEffectiveStadium(stadiumProvider.stadiums);
      return OwnerScheduleSlotsBuilder.getOperationalBaseDate(selectedStadium, context);
    } catch (_) {
      return DateTime.now();
    }
  }

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
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        leading: Navigator.canPop(context) ? const VSPBackButton() : null,
        centerTitle: true,
        title: Text(
          isArabic ? 'جدول الحجوزات' : 'Pitch Schedule',
          style: Theme.of(context).textTheme.displayMedium,
        ),
      ),
      body: Consumer2<BookingProvider, StadiumProvider>(
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

          final baseDate = OwnerScheduleSlotsBuilder.getOperationalBaseDate(selectedStadium, context);
          final selectedDate = baseDate.add(Duration(days: _selectedDayIndex));
          final selectedDateOnly = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
          final int startH = AppDateFormatter.parseTimeToHour(selectedStadium.openingTime);

          final dayBookings = bookingProvider.userBookings.where((b) {
            if (b.stadiumId.toLowerCase().trim() != selectedStadium.id.toLowerCase().trim() ||
                b.status == BookingStatus.cancelled) {
              return false;
            }
            final bShiftDate = b.operationalDate ?? OwnerScheduleSlotsBuilder.getShiftDate(b.startTime, startH);
            return bShiftDate.year == selectedDateOnly.year &&
                bShiftDate.month == selectedDateOnly.month &&
                bShiftDate.day == selectedDateOnly.day;
          }).toList();

          final rawSlots = OwnerScheduleSlotsBuilder.generateRawSlots(
            selectedStadium: selectedStadium,
            selectedDate: selectedDate,
            dayBookings: dayBookings,
            context: context,
          );

          if (rawSlots.isEmpty) {
            return Column(
              children: [
                OwnerBookingsFilterBar(
                  stadiums: stadiums,
                  selectedStadium: selectedStadium,
                  baseDate: baseDate,
                  selectedDayIndex: _selectedDayIndex,
                  onStadiumChanged: (stadium) => setState(() => _selectedStadium = stadium),
                  onSelectDate: () => _selectDate(context, baseDate),
                  onDaySelected: (dayIdx) => setState(() => _selectedDayIndex = dayIdx),
                ),
                Expanded(
                  child: VSPEmptyState(
                    icon: Iconsax.clock_copy,
                    title: l10n.noWorkingHoursTitle,
                    subtitle: l10n.noWorkingHoursSubtitle,
                  ),
                ),
              ],
            );
          }

          final mergedSlots = OwnerScheduleSlotsBuilder.mergeConsecutiveSlots(rawSlots, context);

          return Column(
            children: [
              OwnerBookingsFilterBar(
                stadiums: stadiums,
                selectedStadium: selectedStadium,
                baseDate: baseDate,
                selectedDayIndex: _selectedDayIndex,
                onStadiumChanged: (stadium) => setState(() => _selectedStadium = stadium),
                onSelectDate: () => _selectDate(context, baseDate),
                onDaySelected: (dayIdx) => setState(() => _selectedDayIndex = dayIdx),
              ),
              Expanded(
                child: ListView.separated(
                  controller: _scrollController,
                  padding: VSPScrollPadding.forList(
                    context,
                    hasFloatingNavBar: true,
                    top: VSPSpacing.md,
                    horizontal: VSPSpacing.md,
                  ),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: mergedSlots.length,
                  separatorBuilder: (_, __) => const SizedBox(height: VSPSpacing.md),
                  itemBuilder: (context, index) {
                    final slot = mergedSlots[index];
                    return OwnerTimeSlotRow(
                      slot: slot,
                      selectedStadium: selectedStadium,
                      allRawSlots: rawSlots,
                      selectedDayIndex: _selectedDayIndex,
                      baseDate: baseDate,
                      onQuickBookingDone: () async {
                        final auth = Provider.of<AuthProvider>(context, listen: false);
                        final uid = auth.currentUser?.uid ?? auth.firebaseUser?.uid;
                        if (uid != null && mounted) {
                          await bookingProvider.loadOwnerBookings(uid, forceRefresh: true);
                        }
                      },
                      onShowBookingModal: _showBookingModal,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, DateTime baseDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: baseDate.add(Duration(days: _selectedDayIndex)),
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
      final difference = picked.difference(baseDate).inDays;
      if (difference >= 0 && difference < 14) {
        setState(() => _selectedDayIndex = difference);
      }
    }
  }

  void _showBookingModal({
    required bool isEdit,
    required Map<String, dynamic> slot,
    required Stadium stadium,
  }) {
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
