import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/constants/egypt_governorates.dart';
import '../../../core/providers/stadium_provider.dart';

class FilterBottomSheet extends StatefulWidget {
 final Map<String, dynamic>? initialFilters;
 const FilterBottomSheet({super.key, this.initialFilters});

 @override
 State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
 String _selectedCategory = 'Sports';

 final Map<String, bool> _sportsFilters = {};
 bool _sportsInitialized = false;

 String? _selectedGov;

 final Map<String, bool> _sizeFilters = {
 '5 VS 5': false,
 '7 VS 7': false,
 '11 VS 11': false,
 };

 bool _noDepositOnly = false;

 late RangeValues _priceRange;
 bool _priceInitialized = false;

 final Map<String, bool> _amenitiesFilters = {
 'دش وحمام': false,
 'غرف تغيير ملابس': false,
 'كافتيريا ومشروبات': false,
 'جراج سيارات': false,
 'كشافات إضاءة ليلاً': false,
 'كرة': false,
 'مقاعد': false,
 };

 @override
 void didChangeDependencies() {
 super.didChangeDependencies();
 final stadiumProvider = context.watch<StadiumProvider>();
 
 if (!_sportsInitialized) {
 final availableSports = stadiumProvider.availableSportTypes;
 final List<dynamic> initSports = widget.initialFilters?['sports'] is List
 ? widget.initialFilters!['sports'] as List
 : [];
 for (final sport in availableSports) {
 _sportsFilters[sport] = initSports.contains(sport);
 }
 _sportsInitialized = true;
 }

 if (!_priceInitialized) {
 final maxPriceFromDb = stadiumProvider.maxStadiumPrice;
 final double startPrice = (widget.initialFilters?['minPrice'] as num?)?.toDouble() ?? 0.0;
 final double endPrice = (widget.initialFilters?['maxPrice'] as num?)?.toDouble() ?? maxPriceFromDb;
 _priceRange = RangeValues(
 startPrice.clamp(0.0, maxPriceFromDb),
 endPrice.clamp(0.0, maxPriceFromDb),
 );
 _priceInitialized = true;
 }

 if (widget.initialFilters != null) {
 if (_selectedGov == null && widget.initialFilters!['location'] is String) {
 _selectedGov = widget.initialFilters!['location'] as String?;
 }
 if (widget.initialFilters!['noDepositOnly'] is bool) {
 _noDepositOnly = widget.initialFilters!['noDepositOnly'] as bool;
 }
 if (widget.initialFilters!['sizes'] is List) {
 final List<dynamic> initSizes = widget.initialFilters!['sizes'] as List;
 for (final key in _sizeFilters.keys) {
 if (initSizes.contains(key)) _sizeFilters[key] = true;
 }
 }
 if (widget.initialFilters!['amenities'] is List) {
 final List<dynamic> initAmenities = widget.initialFilters!['amenities'] as List;
 for (final key in _amenitiesFilters.keys) {
 if (initAmenities.contains(key)) _amenitiesFilters[key] = true;
 }
 }
 }
 }

 int getCategoryBadgeCount(String categoryKey) {
 final maxDb = context.read<StadiumProvider>().maxStadiumPrice;
 switch (categoryKey) {
 case 'Sports':
 return _sportsFilters.values.where((v) => v).length;
 case 'Location':
 return _selectedGov != null ? 1 : 0;
 case 'Pitch Specs':
 return _sizeFilters.values.where((v) => v).length;
 case 'Price & Deposit':
 int c = _noDepositOnly ? 1 : 0;
 if (_priceRange.start > 0 || _priceRange.end < maxDb) c++;
 return c;
 case 'Amenities':
 return _amenitiesFilters.values.where((v) => v).length;
 default:
 return 0;
 }
 }

 int get _activeFiltersCount {
 int count = 0;
 count += _sportsFilters.values.where((v) => v).length;
 count += _sizeFilters.values.where((v) => v).length;
 count += _amenitiesFilters.values.where((v) => v).length;
 if (_selectedGov != null) count++;
 if (_noDepositOnly) count++;
 final maxDb = context.read<StadiumProvider>().maxStadiumPrice;
 if (_priceRange.start > 0 || _priceRange.end < maxDb) count++;
 return count;
 }

 void _resetAll() {
 final maxDb = context.read<StadiumProvider>().maxStadiumPrice;
 setState(() {
 _sportsFilters.updateAll((key, value) => false);
 _sizeFilters.updateAll((key, value) => false);
 _amenitiesFilters.updateAll((key, value) => false);
 _selectedGov = null;
 _noDepositOnly = false;
 _priceRange = RangeValues(0, maxDb);
 });
 }

 @override
 Widget build(BuildContext context) {
 final l10n = AppLocalizations.of(context)!;
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';
 final bottomPadding = MediaQuery.of(context).padding.bottom;
 final maxDbPrice = context.watch<StadiumProvider>().maxStadiumPrice;
 final activeCount = _activeFiltersCount;

 final Map<String, String> categoryTitles = {
 'Sports': isArabic ? 'نوع الرياضة' : 'Sport',
 'Location': isArabic ? 'الموقع' : 'Location',
 'Pitch Specs': isArabic ? 'سعة الملعب' : 'Pitch Capacity',
 'Price & Deposit': isArabic ? 'السعر والحجز' : 'Price & Booking',
 'Amenities': isArabic ? 'المرافق والخدمات' : 'Amenities',
 };

 return Container(
 constraints: BoxConstraints(
 maxHeight: MediaQuery.of(context).size.height * 0.72,
 ),
 decoration: const BoxDecoration(
 color: VSPColors.surface,
 borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
 ),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 // ── 1. Header & Handle Bar ──
 Padding(
 padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
 child: Column(
 children: [
 Center(
 child: Container(
 width: 40,
 height: 4,
 decoration: BoxDecoration(
 color: VSPColors.divider,
 borderRadius: BorderRadius.circular(2),
 ),
 ),
 ),
 const SizedBox(height: 14),
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Row(
 children: [
 Text(
 isArabic ? 'تصفية الملاعب' : 'Filter Stadiums',
 style: Theme.of(context).textTheme.displaySmall?.copyWith(
 fontSize: 18,
 fontWeight: FontWeight.bold,
 ),
 ),
 if (activeCount > 0) ...[
 const SizedBox(width: 8),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
 decoration: BoxDecoration(
 color: VSPColors.accent,
 borderRadius: BorderRadius.circular(10),
 ),
 child: Text(
 '$activeCount',
 style: const TextStyle(
 color: Colors.black,
 fontSize: 11,
 fontWeight: FontWeight.w900,
 ),
 ),
 ),
 ],
 ],
 ),
 IconButton(
 visualDensity: VisualDensity.compact,
 onPressed: () => Navigator.pop(context),
 icon: const Icon(
 Iconsax.close_circle_copy,
 color: VSPColors.textSecondary,
 size: 20,
 ),
 ),
 ],
 ),
 ],
 ),
 ),
 const Divider(color: VSPColors.divider, height: 1),

 // ── 2. Flexible Content (Side Tabs + Dynamic Panel Height) ──
 Flexible(
 child: IntrinsicHeight(
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.stretch,
 children: [
 // Dynamic Sidebar (Right side in Arabic RTL)
 Container(
 width: isArabic ? 135 : 125,
 decoration: const BoxDecoration(
 color: VSPColors.surfaceAlt,
 border: BorderDirectional(
 end: BorderSide(
 color: VSPColors.divider,
 width: 1,
 ),
 ),
 ),
 child: SingleChildScrollView(
 physics: const BouncingScrollPhysics(),
 child: Column(
 children: [
 _buildCategoryTab('Sports', categoryTitles['Sports']!, Iconsax.cup_copy),
 _buildCategoryTab('Location', categoryTitles['Location']!, Iconsax.location_copy),
 _buildCategoryTab('Pitch Specs', categoryTitles['Pitch Specs']!, Iconsax.maximize_copy),
 _buildCategoryTab('Price & Deposit', categoryTitles['Price & Deposit']!, Iconsax.wallet_1_copy),
 _buildCategoryTab('Amenities', categoryTitles['Amenities']!, Iconsax.magic_star_copy),
 ],
 ),
 ),
 ),

 // Left Active Content Panel (No empty space!)
 Expanded(
 child: Container(
 padding: const EdgeInsets.all(16),
 child: SingleChildScrollView(
 physics: const BouncingScrollPhysics(),
 child: _buildCategoryContent(isArabic, l10n, maxDbPrice),
 ),
 ),
 ),
 ],
 ),
 ),
 ),

 // ── 3. Fixed Bottom Action Buttons ──
 Container(
 padding: EdgeInsets.fromLTRB(
 16,
 12,
 16,
 bottomPadding > 0 ? bottomPadding + 8 : 16,
 ),
 decoration: const BoxDecoration(
 color: VSPColors.surface,
 border: Border(
 top: BorderSide(
 color: VSPColors.divider,
 width: 1,
 ),
 ),
 ),
 child: Row(
 children: [
 Expanded(
 flex: 1,
 child: PrimaryButton(
 text: l10n.reset,
 height: 46,
 onPressed: _resetAll,
 color: VSPColors.surfaceAlt,
 textColor: Colors.white,
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 flex: 2,
 child: PrimaryButton(
 text: activeCount > 0
 ? (isArabic ? 'تطبيق ($activeCount)' : 'Apply ($activeCount)')
 : l10n.apply,
 height: 46,
 onPressed: () {
 final filters = {
 'sports': _sportsFilters.entries.where((e) => e.value).map((e) => e.key).toList(),
 'location': _selectedGov,
 'sizes': _sizeFilters.entries.where((e) => e.value).map((e) => e.key).toList(),
 'noDepositOnly': _noDepositOnly,
 'minPrice': _priceRange.start,
 'maxPrice': _priceRange.end,
 'amenities': _amenitiesFilters.entries.where((e) => e.value).map((e) => e.key).toList(),
 };
 Navigator.pop(context, filters);
 },
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildCategoryTab(String key, String title, IconData icon) {
 final isSelected = _selectedCategory == key;
 final badgeCount = getCategoryBadgeCount(key);

 return InkWell(
 onTap: () => setState(() => _selectedCategory = key),
 child: AnimatedContainer(
 duration: const Duration(milliseconds: 180),
 padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
 decoration: BoxDecoration(
 color: isSelected ? VSPColors.surface : Colors.transparent,
 border: BorderDirectional(
 start: BorderSide(
 color: isSelected ? VSPColors.accent : Colors.transparent,
 width: 3.5,
 ),
 ),
 ),
 child: Row(
 children: [
 Icon(
 icon,
 color: isSelected ? VSPColors.accent : VSPColors.textSecondary,
 size: 18,
 ),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 title,
 style: TextStyle(
 color: isSelected ? VSPColors.accent : VSPColors.textSecondary,
 fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
 fontSize: 12,
 ),
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 ),
 ),
 if (badgeCount > 0) ...[
 const SizedBox(width: 4),
 Container(
 width: 7,
 height: 7,
 decoration: const BoxDecoration(
 color: VSPColors.accent,
 shape: BoxShape.circle,
 ),
 ),
 ],
 ],
 ),
 ),
 );
 }

 Widget _buildCategoryContent(bool isArabic, AppLocalizations l10n, double maxDbPrice) {
 switch (_selectedCategory) {
 case 'Sports':
 return _buildSportsPanel(isArabic);
 case 'Location':
 return _buildLocationPanel(isArabic);
 case 'Pitch Specs':
 return _buildSpecsPanel(isArabic);
 case 'Price & Deposit':
 return _buildPricePanel(isArabic, l10n, maxDbPrice);
 case 'Amenities':
 return _buildAmenitiesPanel(isArabic);
 default:
 return const SizedBox.shrink();
 }
 }

 Widget _buildSportsPanel(bool isArabic) {
 if (_sportsFilters.isEmpty) {
 return Padding(
 padding: const EdgeInsets.symmetric(vertical: 20),
 child: Text(
 isArabic ? 'جاري تحميل أنواع الرياضات...' : 'Loading sports...',
 style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
 ),
 );
 }

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Wrap(
 spacing: 8,
 runSpacing: 8,
 children: _sportsFilters.entries.map((entry) {
 final isSelected = entry.value;
 final String rawName = entry.key;
 final String label = rawName.toLowerCase() == 'football'
 ? (isArabic ? 'كرة القدم ' : 'Football ')
 : rawName.toLowerCase() == 'padel'
 ? (isArabic ? 'بادل ' : 'Padel ')
 : rawName;

 return ChoiceChip(
 label: Text(label),
 selected: isSelected,
 onSelected: (selected) => setState(() => _sportsFilters[entry.key] = selected),
 selectedColor: VSPColors.accent.withValues(alpha: 0.15),
 checkmarkColor: VSPColors.accent,
 side: BorderSide(color: isSelected ? VSPColors.accent : VSPColors.divider),
 labelStyle: TextStyle(
 color: isSelected ? VSPColors.accent : Colors.white,
 fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
 fontSize: 12.5,
 ),
 backgroundColor: VSPColors.surfaceAlt,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
 );
 }).toList(),
 ),
 ],
 );
 }

 Widget _buildLocationPanel(bool isArabic) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 isArabic ? 'اختر المحافظة' : 'Select Governorate',
 style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
 ),
 const SizedBox(height: 12),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 14),
 height: 48,
 decoration: BoxDecoration(
 color: VSPColors.surfaceAlt,
 borderRadius: BorderRadius.circular(12),
 border: Border.all(
 color: _selectedGov != null ? VSPColors.accent : VSPColors.divider,
 ),
 ),
 child: DropdownButtonHideUnderline(
 child: DropdownButton<String>(
 value: _selectedGov,
 hint: Text(
 isArabic ? 'عرض كل المحافظات ' : 'All Governorates ',
 style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
 ),
 dropdownColor: VSPColors.surfaceAlt,
 icon: const Icon(Iconsax.arrow_down_1_copy, color: VSPColors.accent, size: 16),
 isExpanded: true,
 style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
 onChanged: (val) => setState(() => _selectedGov = val),
 items: [
 DropdownMenuItem<String>(
 value: null,
 child: Text(
 isArabic ? 'كل المحافظات' : 'All Governorates',
 style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white, fontSize: 13),
 ),
 ),
 ...EgyptGovernorates.allGovernorates.map((gov) {
 return DropdownMenuItem<String>(
 value: gov,
 child: Text(
 gov,
 style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white, fontSize: 13),
 ),
 );
 }),
 ],
 ),
 ),
 ),
 ],
 );
 }

 Widget _buildSpecsPanel(bool isArabic) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(isArabic ? 'سعة الملعب' : 'Pitch Capacity', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5)),
 const SizedBox(height: 8),
 Wrap(
 spacing: 8, runSpacing: 8,
 children: _sizeFilters.entries.map((entry) {
 final isSelected = entry.value;
 final label = isArabic ? (entry.key == '5 VS 5' ? 'خماسي (5v5)' : (entry.key == '7 VS 7' ? 'سباعي (7v7)' : '11v11')) : entry.key;
 return ChoiceChip(
 label: Text(label),
 selected: isSelected,
 onSelected: (val) => setState(() => _sizeFilters[entry.key] = val),
 selectedColor: VSPColors.accent.withValues(alpha: 0.15),
 checkmarkColor: VSPColors.accent,
 side: BorderSide(color: isSelected ? VSPColors.accent : VSPColors.divider),
 labelStyle: TextStyle(color: isSelected ? VSPColors.accent : Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, fontSize: 12),
 backgroundColor: VSPColors.surfaceAlt,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
 );
 }).toList(),
 ),
 ],
 );
 }

 Widget _buildPricePanel(bool isArabic, AppLocalizations l10n, double maxDbPrice) {
 final effectiveMax = maxDbPrice > 0 ? maxDbPrice : 2000.0;

 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text(isArabic ? 'السعر بالساعة' : 'Price / Hour', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5)),
 Text(
 '${_priceRange.start.round()} - ${_priceRange.end.round()} ${l10n.egCurrency}',
 style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.w900, fontSize: 13),
 ),
 ],
 ),
 const SizedBox(height: 4),
 Text(
 isArabic ? 'الحد الأقصى يعتمد على أعلى سعر مسجل (${effectiveMax.round()} ج.م)' : 'Max based on registered stadiums (${effectiveMax.round()} EGP)',
 style: const TextStyle(color: VSPColors.textSecondary, fontSize: 10.5),
 ),
 const SizedBox(height: 8),
 SliderTheme(
 data: SliderTheme.of(context).copyWith(
 activeTrackColor: VSPColors.accent,
 inactiveTrackColor: Colors.white10,
 thumbColor: VSPColors.accent,
 overlayColor: VSPColors.accent.withValues(alpha: 0.2),
 rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 8),
 ),
 child: RangeSlider(
 values: RangeValues(
 _priceRange.start.clamp(0, effectiveMax),
 _priceRange.end.clamp(0, effectiveMax),
 ),
 min: 0,
 max: effectiveMax,
 divisions: (effectiveMax / 50).clamp(1, 100).toInt(),
 labels: RangeLabels(
 _priceRange.start.round().toString(),
 _priceRange.end.round().toString(),
 ),
 onChanged: (vals) => setState(() => _priceRange = vals),
 ),
 ),
 const SizedBox(height: 16),
 const Divider(color: VSPColors.divider),
 const SizedBox(height: 12),
 Row(
 children: [
 Checkbox(
 value: _noDepositOnly,
 activeColor: VSPColors.accent,
 checkColor: Colors.black,
 onChanged: (val) => setState(() => _noDepositOnly = val ?? false),
 ),
 Expanded(
 child: GestureDetector(
 onTap: () => setState(() => _noDepositOnly = !_noDepositOnly),
 child: Text(
 isArabic ? 'ملاعب بدون عربون (دفع نقدي مباشر)' : 'No Deposit Required (Cash On Arrival)',
 style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w500),
 ),
 ),
 ),
 ],
 ),
 ],
 );
 }

 Widget _buildAmenitiesPanel(bool isArabic) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 isArabic ? 'المرافق المتاحة بالملعب' : 'Available Amenities',
 style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
 ),
 const SizedBox(height: 12),
 Wrap(
 spacing: 8,
 runSpacing: 8,
 children: _amenitiesFilters.entries.map((entry) {
 final isSelected = entry.value;
 return FilterChip(
 label: Text(entry.key),
 selected: isSelected,
 onSelected: (val) => setState(() => _amenitiesFilters[entry.key] = val),
 selectedColor: VSPColors.accent.withValues(alpha: 0.15),
 checkmarkColor: VSPColors.accent,
 side: BorderSide(color: isSelected ? VSPColors.accent : VSPColors.divider),
 labelStyle: TextStyle(
 color: isSelected ? VSPColors.accent : Colors.white,
 fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
 fontSize: 12,
 ),
 backgroundColor: VSPColors.surfaceAlt,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
 );
 }).toList(),
 ),
 ],
 );
 }
}


