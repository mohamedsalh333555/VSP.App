import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../screens/booking_confirmation_screen.dart';
import '../../services/book_tonight_service.dart';

/// لوحة الساعات الشاغرة الليلة - اختصار قرار الحجز للاعب من 4 دقائق إلى 30 ثانية
class BookTonightSheet extends StatefulWidget {
  final List<Stadium> stadiums;
  final BookTonightService? service;
  final DateTime? currentTime;
  final Function(int, {Map<String, dynamic>? arguments})? onNavigate;

  const BookTonightSheet({
    super.key,
    required this.stadiums,
    this.service,
    this.currentTime,
    this.onNavigate,
  });

  static Future<void> show(
    BuildContext context, {
    required List<Stadium> stadiums,
    BookTonightService? service,
    DateTime? currentTime,
    Function(int, {Map<String, dynamic>? arguments})? onNavigate,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BookTonightSheet(
        stadiums: stadiums,
        service: service,
        currentTime: currentTime,
        onNavigate: onNavigate,
      ),
    );
  }

  @override
  State<BookTonightSheet> createState() => _BookTonightSheetState();
}

class _BookTonightSheetState extends State<BookTonightSheet> {
  late final BookTonightService _service;
  bool _isLoading = true;
  List<TonightStadiumOffer> _offers = [];

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? BookTonightService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadTonightSlots();
    });
  }

  Future<void> _loadTonightSlots() async {
    final isArabic = mounted ? Localizations.localeOf(context).languageCode == 'ar' : true;
    final results = await _service.findTonightOffers(
      stadiums: widget.stadiums,
      isArabic: isArabic,
      currentTime: widget.currentTime,
    );
    if (mounted) {
      setState(() {
        _offers = results;
        _isLoading = false;
      });
    }
  }

  void _onSlotSelected(TonightStadiumOffer offer, TonightMatchSlot slot) {
    HapticFeedback.mediumImpact();
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingConfirmationScreen(
          stadium: offer.stadium,
          selectedDate: offer.operationalDate,
          initialSelectedSlots: slot.slotKeys,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: VSPColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Iconsax.flash_1_copy, color: VSPColors.accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'ساعات الليلة الشاغرة' : 'Open Slots Tonight',
                        style: const TextStyle(
                          color: VSPColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isArabic
                            ? 'اختر الساعة المناسبة واحجز مباشرة بدون انتظار'
                            : 'Pick your slot and confirm instantly in seconds',
                        style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: VSPColors.divider, height: 16),
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _offers.isEmpty
                    ? _buildEmptyState(isArabic)
                    : _buildOffersList(isArabic),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40.0),
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(VSPColors.accent),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isArabic) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.calendar_tick_copy, color: VSPColors.textSecondary.withValues(alpha: 0.4), size: 56),
            const SizedBox(height: 16),
            Text(
              isArabic ? 'ملاعب الليلة مكتملة الحجز بالكامل!' : 'All Pitches Fully Booked Tonight!',
              style: const TextStyle(color: VSPColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isArabic
                  ? 'جميع الساعات محجوزة الليلة في منطقتك. يمكنك استكشاف مباريات عامة بحاجة للاعبين أو حجز موعد للغد.'
                  : 'No open slots left tonight in your area. Join open matches or reserve for tomorrow.',
              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (widget.onNavigate != null)
              PrimaryButton(
                text: isArabic ? 'استكشف مباريات تحتاج لاعبين' : 'Explore Open Matches',
                onPressed: () {
                  Navigator.pop(context);
                  widget.onNavigate!(1); // Switch to Matches tab
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOffersList(bool isArabic) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _offers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final offer = _offers[index];
        final std = offer.stadium;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: VSPColors.surfaceAlt,
            borderRadius: BorderRadius.circular(VSPRadius.lg),
            border: Border.all(color: VSPColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      std.name,
                      style: const TextStyle(
                        color: VSPColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${std.basePrice.toInt()} ${isArabic ? 'ج.م' : 'EGP'} / ${isArabic ? 'ساعة' : 'hr'}',
                    style: const TextStyle(
                      color: VSPColors.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${std.location.isNotEmpty ? std.location : (std.governorate ?? '')} • ${std.size.isNotEmpty ? std.size : '5v5'}',
                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: offer.availableSlots.map((slot) {
                  return InkWell(
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    onTap: () => _onSlotSelected(offer, slot),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: VSPColors.surface,
                        borderRadius: BorderRadius.circular(VSPRadius.md),
                        border: Border.all(
                          color: VSPColors.accent.withValues(alpha: 0.45),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Iconsax.clock_copy, size: 14, color: VSPColors.accent),
                          const SizedBox(width: 6),
                          Text(
                            slot.displayTime,
                            style: const TextStyle(
                              color: VSPColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}
