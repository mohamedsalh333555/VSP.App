import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/providers/stadium_provider.dart';
import '../../../core/models/user_model.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/app_date_formatter.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../data/models.dart';
import '../../../shared/widgets/vsp_back_button.dart';
import '../../../shared/widgets/vsp_empty_state.dart';
import 'add_stadium_wizard.dart';
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
      final uid = auth.currentUser?.id;
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
    final userModel = Provider.of<AuthProvider>(context).userModel;
    final bool isVerified = userModel?.isVerifiedForOperations == true;

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
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: VSPColors.accent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Iconsax.building_copy, color: VSPColors.accent, size: 32),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isArabic ? 'لم تقم بإضافة ملعب بعد' : 'No Stadium Added Yet',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isArabic
                          ? 'أضف بيانات ملعبك الأول لبدء إعداد جدول التشغيل واستقبال الحجوزات بعد اعتماد المنشأة.'
                          : 'Add your first pitch to configure schedules and accept bookings once verified.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AddStadiumWizard()),
                        ),
                        icon: const Icon(Iconsax.add_circle_copy, size: 18),
                        label: Text(
                          isArabic ? 'إضافة ملعب جديد' : 'Add New Stadium',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VSPColors.accent,
                          foregroundColor: Colors.black,
                          shape: const StadiumBorder(),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
                if (!isVerified) _buildUnverifiedBookingsBanner(context, isArabic, userModel),
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
              if (!isVerified) _buildUnverifiedBookingsBanner(context, isArabic, userModel),
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
                        final uid = auth.currentUser?.id;
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

  Widget _buildUnverifiedBookingsBanner(BuildContext context, bool isArabic, UserModel? user) {
    final status = user?.verificationStatus;
    final isRejected = status == 'rejected';
    final isUnderReview = status == 'under_review';

    final text = isArabic
        ? (isRejected
            ? 'تم رفض توثيق المنشأة. يرجى إعادة رفع المستندات لتفعيل ظهور الملاعب للاعبين.'
            : (isUnderReview
                ? 'مستندات منشأتك قيد المراجعة. سيبدأ استقبال حجوزات اللاعبين أونلاين فور الاعتماد.'
                : 'منشأتك غير معتمدة تشغيلياً بعد. لن تظهر ملاعبك للاعبين حتى يتم اعتماد وثائق المنشأة.'))
        : (isRejected
            ? 'Verification rejected. Please re-upload docs so players can book.'
            : (isUnderReview
                ? 'Documents under review. Online player bookings will activate upon approval.'
                : 'Facility is pending verification. Stadiums are hidden from players until approved.'));

    final Color color = isRejected ? VSPColors.error : VSPColors.warning;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(VSPRadius.card),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(isRejected ? Iconsax.close_circle_copy : Iconsax.info_circle_copy, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 12, height: 1.4, fontWeight: FontWeight.w600),
            ),
          ),
          if (!isUnderReview)
            TextButton(
              onPressed: () => context.push('/documentation'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(
                isArabic ? 'توثيق' : 'Verify',
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  void _showBookingModal({
    required bool isEdit,
    required Map<String, dynamic> slot,
    required Stadium stadium,
  }) {
    if (!isEdit) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final isVerified = auth.userModel?.isVerifiedForOperations == true;

      if (!isVerified) {
        VSPFeedback.showError(
          context,
          Localizations.localeOf(context).languageCode == 'ar'
              ? 'عذراً، حسابك بانتظار التوثيق والاعتماد من قِبل إدارة التطبيق. لا يمكن إضافة حجز جديد حتى يتم الاعتماد والتفعيل!'
              : 'Sorry, your account is awaiting verification. Bookings are disabled until admin approval!',
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
